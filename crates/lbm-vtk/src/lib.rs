//! 将二维格子场快照导出为 VTK XML `ImageData`。

use std::{error::Error, fmt, fmt::Write as _, fs, io, path::Path};

use vtkio::model::{
    Attribute, Attributes, ByteOrder, DataSet, Extent, ImageDataPiece, Piece, Version, Vtk,
};
use vtkio::xml::Compressor;

/// 稳定的格点区域类别编码。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum BoundaryKind {
    /// 流体格点。
    Fluid = 0,
    /// 固定或运动壁面格点。
    Wall = 1,
    /// 入口格点。
    Inlet = 2,
    /// 出口格点。
    Outlet = 3,
    /// 固体区域格点。
    Solid = 4,
}

/// 场快照不满足导出契约。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SnapshotError {
    /// 格子某一轴没有格点。
    EmptyDimension {
        /// 空轴索引。
        axis: usize,
    },
    /// 二维格点总数超过平台可以表达的范围。
    DimensionProductOverflow,
    /// 格子间距不是正数。
    InvalidSpacing {
        /// 无效间距所在轴。
        axis: usize,
    },
    /// 字段元素数量与格子尺寸不一致。
    FieldLength {
        /// 字段的稳定名称。
        field: &'static str,
        /// 格子要求的元素数量。
        expected: usize,
        /// 实际提供的元素数量。
        actual: usize,
    },
    /// 字段包含无法写入可移植场文件的非有限值。
    NonFiniteValue {
        /// 字段的稳定名称。
        field: &'static str,
        /// 非有限值在展平数组中的索引。
        index: usize,
    },
}

impl fmt::Display for SnapshotError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyDimension { axis } => {
                write!(formatter, "lattice dimension {axis} must be non-zero")
            }
            Self::DimensionProductOverflow => {
                formatter.write_str("lattice dimensions overflow usize")
            }
            Self::InvalidSpacing { axis } => {
                write!(formatter, "lattice spacing {axis} must be positive")
            }
            Self::FieldLength {
                field,
                expected,
                actual,
            } => write!(
                formatter,
                "field {field} contains {actual} values; expected {expected}"
            ),
            Self::NonFiniteValue { field, index } => {
                write!(
                    formatter,
                    "field {field} contains a non-finite value at {index}"
                )
            }
        }
    }
}

impl Error for SnapshotError {}

/// VTK 场文件写入失败。
#[derive(Debug)]
pub enum ExportError {
    /// 文件系统操作失败。
    Io(io::Error),
    /// vtkio 无法编码场数据。
    Vtk(vtkio::Error),
    /// vtkio 无法建立压缩的 XML 表示。
    VtkXml(vtkio::xml::Error),
    /// 格子尺寸超过 VTK XML extent 能表达的范围。
    DimensionTooLarge(usize),
    /// 时间序列包含非有限物理时间。
    NonFiniteTime(usize),
    /// 坐标或间距无法由 vtkio 的单精度元数据表示。
    CoordinateOutOfRange(f64),
}

impl fmt::Display for ExportError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(error) => error.fmt(formatter),
            Self::Vtk(error) => error.fmt(formatter),
            Self::VtkXml(error) => error.fmt(formatter),
            Self::DimensionTooLarge(value) => {
                write!(formatter, "lattice dimension {value} exceeds the VTK limit")
            }
            Self::NonFiniteTime(index) => {
                write!(formatter, "time-series entry {index} has a non-finite time")
            }
            Self::CoordinateOutOfRange(value) => {
                write!(
                    formatter,
                    "coordinate value {value} exceeds the VTK metadata range"
                )
            }
        }
    }
}

impl Error for ExportError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Io(error) => Some(error),
            Self::Vtk(error) => Some(error),
            Self::VtkXml(error) => Some(error),
            Self::DimensionTooLarge(_) | Self::NonFiniteTime(_) | Self::CoordinateOutOfRange(_) => {
                None
            }
        }
    }
}

impl From<io::Error> for ExportError {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

impl From<vtkio::Error> for ExportError {
    fn from(error: vtkio::Error) -> Self {
        Self::Vtk(error)
    }
}

impl From<vtkio::xml::Error> for ExportError {
    fn from(error: vtkio::xml::Error) -> Self {
        Self::VtkXml(error)
    }
}

/// 经验证的二维格子场快照只读视图。
#[derive(Debug)]
pub struct LatticeSnapshot2D<'a> {
    dimensions: [usize; 2],
    origin: [f64; 2],
    spacing: [f64; 2],
    fields: PointFields<'a>,
    step: u64,
    physical_time: f64,
}

#[derive(Debug)]
enum PointFields<'a> {
    Flow {
        density: &'a [f64],
        velocity: &'a [[f64; 2]],
        boundary_kind: &'a [BoundaryKind],
    },
    Scalar {
        scalar: &'a [f64],
        boundary_kind: &'a [BoundaryKind],
    },
}

/// `ParaView` 时间序列清单中的一个场快照。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TimeSeriesEntry<'a> {
    file_name: &'a str,
    physical_time: f64,
}

impl<'a> TimeSeriesEntry<'a> {
    /// 建立文件名与真实物理时间的对应关系。
    #[must_use]
    pub const fn new(file_name: &'a str, physical_time: f64) -> Self {
        Self {
            file_name,
            physical_time,
        }
    }
}

impl<'a> LatticeSnapshot2D<'a> {
    /// 验证所有字段都覆盖完整格子，并建立只读场快照。
    ///
    /// # Errors
    ///
    /// 字段长度与格子尺寸不一致，或数值字段包含非有限值时返回错误。
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        dimensions: [usize; 2],
        origin: [f64; 2],
        spacing: [f64; 2],
        density: &'a [f64],
        velocity: &'a [[f64; 2]],
        boundary_kind: &'a [BoundaryKind],
        step: u64,
        physical_time: f64,
    ) -> Result<Self, SnapshotError> {
        if let Some(axis) = dimensions.iter().position(|dimension| *dimension == 0) {
            return Err(SnapshotError::EmptyDimension { axis });
        }
        let expected = dimensions[0]
            .checked_mul(dimensions[1])
            .ok_or(SnapshotError::DimensionProductOverflow)?;
        validate_finite("origin", origin)?;
        validate_finite("spacing", spacing)?;
        validate_finite("physical_time", [physical_time])?;
        if let Some(axis) = spacing.iter().position(|value| *value <= 0.0) {
            return Err(SnapshotError::InvalidSpacing { axis });
        }
        validate_length("density", density.len(), expected)?;
        validate_length("velocity", velocity.len(), expected)?;
        validate_length("boundary_kind", boundary_kind.len(), expected)?;
        validate_finite("density", density.iter().copied())?;
        validate_finite(
            "velocity",
            velocity.iter().flat_map(|value| value.iter()).copied(),
        )?;

        Ok(Self {
            dimensions,
            origin,
            spacing,
            fields: PointFields::Flow {
                density,
                velocity,
                boundary_kind,
            },
            step,
            physical_time,
        })
    }

    /// 验证标量场和区域标记覆盖完整格子，并建立只读场快照。
    ///
    /// 标量扩散场以稳定字段名 `scalar` 导出，不冒充流动问题的密度或速度。
    ///
    /// # Errors
    ///
    /// 字段长度与格子尺寸不一致，或数值字段包含非有限值时返回错误。
    #[allow(clippy::too_many_arguments)]
    pub fn new_scalar(
        dimensions: [usize; 2],
        origin: [f64; 2],
        spacing: [f64; 2],
        scalar: &'a [f64],
        boundary_kind: &'a [BoundaryKind],
        step: u64,
        physical_time: f64,
    ) -> Result<Self, SnapshotError> {
        if let Some(axis) = dimensions.iter().position(|dimension| *dimension == 0) {
            return Err(SnapshotError::EmptyDimension { axis });
        }
        let expected = dimensions[0]
            .checked_mul(dimensions[1])
            .ok_or(SnapshotError::DimensionProductOverflow)?;
        validate_finite("origin", origin)?;
        validate_finite("spacing", spacing)?;
        validate_finite("physical_time", [physical_time])?;
        if let Some(axis) = spacing.iter().position(|value| *value <= 0.0) {
            return Err(SnapshotError::InvalidSpacing { axis });
        }
        validate_length("scalar", scalar.len(), expected)?;
        validate_length("boundary_kind", boundary_kind.len(), expected)?;
        validate_finite("scalar", scalar.iter().copied())?;

        Ok(Self {
            dimensions,
            origin,
            spacing,
            fields: PointFields::Scalar {
                scalar,
                boundary_kind,
            },
            step,
            physical_time,
        })
    }
}

fn validate_finite(
    field: &'static str,
    values: impl IntoIterator<Item = f64>,
) -> Result<(), SnapshotError> {
    if let Some((index, _)) = values
        .into_iter()
        .enumerate()
        .find(|(_, value)| !value.is_finite())
    {
        Err(SnapshotError::NonFiniteValue { field, index })
    } else {
        Ok(())
    }
}

/// 将场快照原子写成 VTK XML `ImageData`，并拒绝覆盖已有文件。
///
/// # Errors
///
/// 目标存在、元数据超出 VTK 范围，或文件编码与发布失败时返回错误。
pub fn write_vti(
    snapshot: &LatticeSnapshot2D<'_>,
    path: impl AsRef<Path>,
) -> Result<(), ExportError> {
    let path = path.as_ref();
    if path.exists() {
        return Err(io::Error::new(
            io::ErrorKind::AlreadyExists,
            format!("refusing to overwrite {}", path.display()),
        )
        .into());
    }

    let vtk = snapshot_to_vtk(snapshot)?;
    let encoded = vtk.try_into_xml_format(Compressor::ZLib, 6)?;
    let temporary_path = path.with_extension("tmp.vti");
    if let Err(error) = encoded.export(&temporary_path) {
        let _ = fs::remove_file(&temporary_path);
        return Err(error.into());
    }
    fs::rename(&temporary_path, path)?;
    Ok(())
}

/// 将小型审阅夹具原子写成 ASCII VTK XML `ImageData`。
///
/// # Errors
///
/// 目标存在、格子尺寸超出 VTK 范围，或文件发布失败时返回错误。
pub fn write_vti_ascii(
    snapshot: &LatticeSnapshot2D<'_>,
    path: impl AsRef<Path>,
) -> Result<(), ExportError> {
    let nx = i32::try_from(snapshot.dimensions[0])
        .map_err(|_| ExportError::DimensionTooLarge(snapshot.dimensions[0]))?;
    let ny = i32::try_from(snapshot.dimensions[1])
        .map_err(|_| ExportError::DimensionTooLarge(snapshot.dimensions[1]))?;
    let extent = format!("0 {} 0 {} 0 0", nx - 1, ny - 1);
    let mut xml = String::from("<?xml version=\"1.0\"?>\n");
    xml.push_str("<VTKFile type=\"ImageData\" version=\"1.0\" byte_order=\"LittleEndian\" header_type=\"UInt64\">\n");
    writeln!(
        xml,
        "  <ImageData WholeExtent=\"{extent}\" Origin=\"{} {} 0\" Spacing=\"{} {} 1\">",
        snapshot.origin[0], snapshot.origin[1], snapshot.spacing[0], snapshot.spacing[1]
    )
    .expect("writing to a String cannot fail");
    writeln!(xml, "    <Piece Extent=\"{extent}\">").expect("writing to a String cannot fail");
    match &snapshot.fields {
        PointFields::Flow {
            density, velocity, ..
        } => {
            xml.push_str("      <PointData Scalars=\"density\" Vectors=\"velocity\">\n");
            xml.push_str("        <DataArray type=\"Float64\" Name=\"density\" format=\"ascii\">");
            write_values(&mut xml, density.iter().copied());
            xml.push_str("</DataArray>\n");
            xml.push_str("        <DataArray type=\"Float64\" Name=\"velocity\" NumberOfComponents=\"3\" format=\"ascii\">");
            write_values(
                &mut xml,
                velocity.iter().flat_map(|value| [value[0], value[1], 0.0]),
            );
            xml.push_str("</DataArray>\n");
        }
        PointFields::Scalar { scalar, .. } => {
            xml.push_str("      <PointData Scalars=\"scalar\">\n");
            xml.push_str("        <DataArray type=\"Float64\" Name=\"scalar\" format=\"ascii\">");
            write_values(&mut xml, scalar.iter().copied());
            xml.push_str("</DataArray>\n");
        }
    }
    xml.push_str("        <DataArray type=\"UInt8\" Name=\"boundary_kind\" format=\"ascii\">");
    write_values(
        &mut xml,
        boundary_kind(&snapshot.fields)
            .iter()
            .map(|kind| u32::from(*kind as u8)),
    );
    xml.push_str("</DataArray>\n");
    xml.push_str(
        "      </PointData>\n      <CellData/>\n    </Piece>\n  </ImageData>\n</VTKFile>\n",
    );

    atomic_write(path.as_ref(), xml.as_bytes())
}

fn write_values<T: fmt::Display>(output: &mut String, values: impl IntoIterator<Item = T>) {
    for (index, value) in values.into_iter().enumerate() {
        if index > 0 {
            output.push(' ');
        }
        write!(output, "{value}").expect("writing to a String cannot fail");
    }
}

/// 原子写入 `ParaView` JSON 时间序列清单，并拒绝覆盖已有文件。
///
/// # Errors
///
/// 目标存在、物理时间非有限，或文件发布失败时返回错误。
pub fn write_time_series(
    entries: &[TimeSeriesEntry<'_>],
    path: impl AsRef<Path>,
) -> Result<(), ExportError> {
    let mut manifest = String::from("{\n  \"file-series-version\": \"1.0\",\n  \"files\": [\n");
    for (index, entry) in entries.iter().enumerate() {
        if !entry.physical_time.is_finite() {
            return Err(ExportError::NonFiniteTime(index));
        }
        writeln!(
            manifest,
            "    {{ \"name\": \"{}\", \"time\": {} }}{}",
            escape_json(entry.file_name),
            entry.physical_time,
            if index + 1 == entries.len() { "" } else { "," }
        )
        .expect("writing to a String cannot fail");
    }
    manifest.push_str("  ]\n}\n");

    atomic_write(path.as_ref(), manifest.as_bytes())
}

fn atomic_write(path: &Path, contents: &[u8]) -> Result<(), ExportError> {
    if path.exists() {
        return Err(io::Error::new(
            io::ErrorKind::AlreadyExists,
            format!("refusing to overwrite {}", path.display()),
        )
        .into());
    }
    let temporary_path = path.with_extension("tmp");
    fs::write(&temporary_path, contents)?;
    if let Err(error) = fs::rename(&temporary_path, path) {
        let _ = fs::remove_file(&temporary_path);
        return Err(error.into());
    }
    Ok(())
}

fn escape_json(text: &str) -> String {
    let mut escaped = String::with_capacity(text.len());
    for character in text.chars() {
        match character {
            '"' => escaped.push_str("\\\""),
            '\\' => escaped.push_str("\\\\"),
            '\n' => escaped.push_str("\\n"),
            '\r' => escaped.push_str("\\r"),
            '\t' => escaped.push_str("\\t"),
            control if control.is_control() => {
                write!(escaped, "\\u{:04x}", u32::from(control))
                    .expect("writing to a String cannot fail");
            }
            other => escaped.push(other),
        }
    }
    escaped
}

fn snapshot_to_vtk(snapshot: &LatticeSnapshot2D<'_>) -> Result<Vtk, ExportError> {
    let nx = i32::try_from(snapshot.dimensions[0])
        .map_err(|_| ExportError::DimensionTooLarge(snapshot.dimensions[0]))?;
    let ny = i32::try_from(snapshot.dimensions[1])
        .map_err(|_| ExportError::DimensionTooLarge(snapshot.dimensions[1]))?;
    let extent = Extent::Ranges([0..=nx - 1, 0..=ny - 1, 0..=0]);
    let boundary_kind = boundary_kind(&snapshot.fields)
        .iter()
        .map(|kind| *kind as u8)
        .collect::<Vec<_>>();
    let point = match &snapshot.fields {
        PointFields::Flow {
            density, velocity, ..
        } => {
            let velocity = velocity
                .iter()
                .flat_map(|value| [value[0], value[1], 0.0])
                .collect::<Vec<_>>();
            vec![
                Attribute::generic("density", 1).with_data(density.to_vec()),
                Attribute::generic("velocity", 3).with_data(velocity),
                Attribute::generic("boundary_kind", 1).with_data(boundary_kind),
            ]
        }
        PointFields::Scalar { scalar, .. } => vec![
            Attribute::generic("scalar", 1).with_data(scalar.to_vec()),
            Attribute::generic("boundary_kind", 1).with_data(boundary_kind),
        ],
    };
    let data = Attributes {
        point,
        cell: vec![],
    };
    let piece = ImageDataPiece {
        extent: extent.clone(),
        data,
    };

    Ok(Vtk {
        version: Version::new(),
        byte_order: ByteOrder::LittleEndian,
        title: format!(
            "LBM-Rust lattice snapshot: step {}, time {}",
            snapshot.step, snapshot.physical_time
        ),
        file_path: None,
        data: DataSet::ImageData {
            extent,
            origin: [
                vtk_coordinate(snapshot.origin[0])?,
                vtk_coordinate(snapshot.origin[1])?,
                0.0,
            ],
            spacing: [
                vtk_coordinate(snapshot.spacing[0])?,
                vtk_coordinate(snapshot.spacing[1])?,
                1.0,
            ],
            meta: None,
            pieces: vec![Piece::Inline(Box::new(piece))],
        },
    })
}

fn boundary_kind<'a>(fields: &'a PointFields<'_>) -> &'a [BoundaryKind] {
    match fields {
        PointFields::Flow { boundary_kind, .. } | PointFields::Scalar { boundary_kind, .. } => {
            boundary_kind
        }
    }
}

#[allow(clippy::cast_possible_truncation)]
fn vtk_coordinate(value: f64) -> Result<f32, ExportError> {
    let converted = value as f32;
    if converted.is_finite() {
        Ok(converted)
    } else {
        Err(ExportError::CoordinateOutOfRange(value))
    }
}

fn validate_length(
    field: &'static str,
    actual: usize,
    expected: usize,
) -> Result<(), SnapshotError> {
    if actual == expected {
        Ok(())
    } else {
        Err(SnapshotError::FieldLength {
            field,
            expected,
            actual,
        })
    }
}

#[cfg(test)]
mod tests {
    use std::{fs, process};

    use vtkio::model::{Attribute, DataSet, ElementType, IOBuffer};

    use super::{
        BoundaryKind, LatticeSnapshot2D, SnapshotError, TimeSeriesEntry, write_time_series,
        write_vti, write_vti_ascii,
    };

    #[test]
    fn snapshot_rejects_field_lengths_that_do_not_match_the_lattice() {
        let density = [1.0; 3];
        let velocity = [[0.0, 0.0]; 4];
        let boundary_kind = [BoundaryKind::Fluid; 4];

        let error = LatticeSnapshot2D::new(
            [2, 2],
            [0.0, 0.0],
            [1.0, 1.0],
            &density,
            &velocity,
            &boundary_kind,
            0,
            0.0,
        )
        .expect_err("density length must match dimensions");

        assert_eq!(
            error,
            SnapshotError::FieldLength {
                field: "density",
                expected: 4,
                actual: 3,
            }
        );
    }

    #[test]
    fn snapshot_rejects_non_finite_field_values() {
        let density = [1.0, f64::NAN, 1.0, 1.0];
        let velocity = [[0.0, 0.0]; 4];
        let boundary_kind = [BoundaryKind::Fluid; 4];

        let error = LatticeSnapshot2D::new(
            [2, 2],
            [0.0, 0.0],
            [1.0, 1.0],
            &density,
            &velocity,
            &boundary_kind,
            0,
            0.0,
        )
        .expect_err("field values must be finite");

        assert_eq!(
            error,
            SnapshotError::NonFiniteValue {
                field: "density",
                index: 1,
            }
        );
    }

    #[test]
    fn snapshot_rejects_an_empty_lattice_axis() {
        let error = LatticeSnapshot2D::new([0, 2], [0.0, 0.0], [1.0, 1.0], &[], &[], &[], 0, 0.0)
            .expect_err("lattice axes must be non-empty");

        assert_eq!(error, SnapshotError::EmptyDimension { axis: 0 });
    }

    #[test]
    fn snapshot_rejects_non_positive_spacing() {
        let density = [1.0; 4];
        let velocity = [[0.0, 0.0]; 4];
        let boundary_kind = [BoundaryKind::Fluid; 4];
        let error = LatticeSnapshot2D::new(
            [2, 2],
            [0.0, 0.0],
            [1.0, 0.0],
            &density,
            &velocity,
            &boundary_kind,
            0,
            0.0,
        )
        .expect_err("spacing must be finite and positive");

        assert_eq!(error, SnapshotError::InvalidSpacing { axis: 1 });
    }

    #[test]
    fn vti_round_trip_preserves_lattice_order_and_field_semantics() {
        let dimensions = [4, 3];
        let density: Vec<f64> = (0..12)
            .map(|index| 1.0 + f64::from(index) / 100.0)
            .collect();
        let velocity: Vec<[f64; 2]> = (0..12)
            .map(|index| [f64::from(index % 4), -f64::from(index / 4)])
            .collect();
        let boundary_kind = [
            BoundaryKind::Inlet,
            BoundaryKind::Wall,
            BoundaryKind::Wall,
            BoundaryKind::Outlet,
            BoundaryKind::Inlet,
            BoundaryKind::Fluid,
            BoundaryKind::Solid,
            BoundaryKind::Outlet,
            BoundaryKind::Inlet,
            BoundaryKind::Wall,
            BoundaryKind::Wall,
            BoundaryKind::Outlet,
        ];
        let snapshot = LatticeSnapshot2D::new(
            dimensions,
            [0.5, -1.0],
            [0.25, 0.5],
            &density,
            &velocity,
            &boundary_kind,
            7,
            0.35,
        )
        .unwrap();
        let path = std::env::temp_dir().join(format!("lbm-vtk-roundtrip-{}.vti", process::id()));
        let _ = fs::remove_file(&path);

        write_vti(&snapshot, &path).unwrap();
        let contents = fs::read_to_string(&path).unwrap();
        assert!(contents.contains("compressor=\"vtkZLibDataCompressor\""));
        let vtk = vtkio::Vtk::import(&path).unwrap();
        fs::remove_file(&path).unwrap();

        let DataSet::ImageData {
            extent,
            origin,
            spacing,
            pieces,
            ..
        } = vtk.data
        else {
            panic!("expected ImageData");
        };
        assert_eq!(extent.into_dims(), [4, 3, 1]);
        assert!(
            origin
                .iter()
                .zip([0.5, -1.0, 0.0])
                .all(|(actual, expected)| (*actual - expected).abs() <= f32::EPSILON)
        );
        assert!(
            spacing
                .iter()
                .zip([0.25, 0.5, 1.0])
                .all(|(actual, expected)| (*actual - expected).abs() <= f32::EPSILON)
        );

        let piece = pieces
            .into_iter()
            .next()
            .unwrap()
            .into_loaded_piece_data(None)
            .unwrap();
        assert_eq!(piece.extent.into_dims(), [4, 3, 1]);
        assert_eq!(piece.data.cell, vec![]);
        assert_array(&piece.data.point[0], "density", 1, &density);
        assert_array(
            &piece.data.point[1],
            "velocity",
            3,
            &velocity
                .iter()
                .flat_map(|value| [value[0], value[1], 0.0])
                .collect::<Vec<_>>(),
        );
        assert_eq!(piece.data.point[2].name(), "boundary_kind");
        let Attribute::DataArray(boundary_array) = &piece.data.point[2] else {
            panic!("expected boundary_kind data array");
        };
        assert_eq!(boundary_array.elem.num_comp(), 1);
        assert_eq!(
            boundary_array.data,
            IOBuffer::U8(vec![2, 1, 1, 3, 2, 0, 4, 3, 2, 1, 1, 3])
        );
    }

    #[test]
    fn time_series_manifest_preserves_file_order_and_physical_time() {
        let path =
            std::env::temp_dir().join(format!("lbm-vtk-series-{}.vti.series", process::id()));
        let _ = fs::remove_file(&path);
        let entries = [
            TimeSeriesEntry::new("step_000000.vti", 0.0),
            TimeSeriesEntry::new("step_000007.vti", 0.35),
        ];

        write_time_series(&entries, &path).unwrap();
        let manifest = fs::read_to_string(&path).unwrap();
        fs::remove_file(&path).unwrap();

        assert_eq!(
            manifest,
            concat!(
                "{\n",
                "  \"file-series-version\": \"1.0\",\n",
                "  \"files\": [\n",
                "    { \"name\": \"step_000000.vti\", \"time\": 0 },\n",
                "    { \"name\": \"step_000007.vti\", \"time\": 0.35 }\n",
                "  ]\n",
                "}\n",
            )
        );
    }

    #[test]
    fn ascii_vti_is_reviewable_and_readable_by_vtkio() {
        let density = [1.0, 1.1, 1.2, 1.3];
        let velocity = [[0.0, 0.0], [1.0, 0.0], [0.0, -1.0], [1.0, -1.0]];
        let boundary_kind = [
            BoundaryKind::Inlet,
            BoundaryKind::Wall,
            BoundaryKind::Fluid,
            BoundaryKind::Outlet,
        ];
        let snapshot = LatticeSnapshot2D::new(
            [2, 2],
            [0.0, 0.0],
            [1.0, 1.0],
            &density,
            &velocity,
            &boundary_kind,
            0,
            0.0,
        )
        .unwrap();
        let path = std::env::temp_dir().join(format!("lbm-vtk-ascii-{}.vti", process::id()));
        let _ = fs::remove_file(&path);

        write_vti_ascii(&snapshot, &path).unwrap();
        let contents = fs::read_to_string(&path).unwrap();
        let vtk = vtkio::Vtk::import(&path).unwrap();
        fs::remove_file(&path).unwrap();

        assert!(contents.contains("format=\"ascii\""));
        assert!(contents.contains(">1 1.1 1.2 1.3</DataArray>"));
        let DataSet::ImageData { extent, .. } = vtk.data else {
            panic!("expected ImageData");
        };
        assert_eq!(extent.into_dims(), [2, 2, 1]);
    }

    fn assert_array(attribute: &Attribute, name: &str, components: u32, expected: &[f64]) {
        let Attribute::DataArray(array) = attribute else {
            panic!("expected {name} data array");
        };
        assert_eq!(array.name, name);
        assert_eq!(array.elem, ElementType::Generic(components));
        assert_eq!(array.data, IOBuffer::F64(expected.to_vec()));
    }
}
