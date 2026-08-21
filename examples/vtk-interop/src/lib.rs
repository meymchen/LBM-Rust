//! 确定性的 VTK／ParaView 互操作原型资产生成。

use std::{
    ffi::OsStr,
    fs, io,
    path::{Component, Path},
};

use lbm_vtk::{
    BoundaryKind, LatticeSnapshot2D, TimeSeriesEntry, write_time_series, write_vti_ascii,
};

/// 原子生成非方形、双时间点的 VTK／ParaView 互操作原型。
///
/// # Errors
///
/// 目标目录已经存在，或任一资产无法完整写入并发布时返回错误。
pub fn generate_interop_assets(output: impl AsRef<Path>) -> io::Result<()> {
    let output = output.as_ref();
    if output.exists() {
        return Err(io::Error::new(
            io::ErrorKind::AlreadyExists,
            format!("refusing to overwrite {}", output.display()),
        ));
    }
    let temporary = output.with_extension("tmp");
    if temporary.exists() {
        return Err(io::Error::new(
            io::ErrorKind::AlreadyExists,
            format!(
                "temporary run directory already exists: {}",
                temporary.display()
            ),
        ));
    }
    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::create_dir(&temporary)?;

    let result = write_run_contents(&temporary);
    if let Err(error) = result {
        let _ = fs::remove_dir_all(&temporary);
        return Err(error);
    }
    fs::rename(temporary, output)
}

/// 显式替换已有互操作原型目录，用于维护版本化生成资产。
///
/// # Errors
///
/// 已有目录无法删除，或新资产无法完整生成并发布时返回错误。
pub fn regenerate_interop_assets(output: impl AsRef<Path>) -> io::Result<()> {
    let output = output.as_ref();
    if !is_safe_regeneration_target(output) {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "forced regeneration is limited to build/ and examples/vtk-interop/fixtures/",
        ));
    }
    if output.exists() {
        fs::remove_dir_all(output)?;
    }
    generate_interop_assets(output)
}

fn is_safe_regeneration_target(output: &Path) -> bool {
    let components = output.components().collect::<Vec<_>>();
    if components
        .iter()
        .any(|component| !matches!(component, Component::Normal(_)))
    {
        return false;
    }
    let names = components
        .iter()
        .filter_map(|component| match component {
            Component::Normal(name) => Some(*name),
            _ => None,
        })
        .collect::<Vec<_>>();

    (names.len() >= 2 && names.first() == Some(&OsStr::new("build")))
        || (names.len() >= 4
            && names.starts_with(&[
                OsStr::new("examples"),
                OsStr::new("vtk-interop"),
                OsStr::new("fixtures"),
            ]))
}

fn write_run_contents(directory: &Path) -> io::Result<()> {
    for (step, physical_time) in [(0, 0.0), (7, 0.35)] {
        let (density, velocity, boundary_kind) = synthetic_fields(physical_time);
        let snapshot = LatticeSnapshot2D::new(
            [4, 3],
            [0.0, 0.0],
            [1.0, 1.0],
            &density,
            &velocity,
            &boundary_kind,
            step,
            physical_time,
        )
        .map_err(io::Error::other)?;
        write_vti_ascii(&snapshot, directory.join(format!("step_{step:06}.vti")))
            .map_err(io::Error::other)?;
    }

    write_time_series(
        &[
            TimeSeriesEntry::new("step_000000.vti", 0.0),
            TimeSeriesEntry::new("step_000007.vti", 0.35),
        ],
        directory.join("interop.vti.series"),
    )
    .map_err(io::Error::other)?;
    fs::write(directory.join("run.toml"), run_metadata())
}

fn synthetic_fields(physical_time: f64) -> (Vec<f64>, Vec<[f64; 2]>, Vec<BoundaryKind>) {
    let mut density = Vec::with_capacity(12);
    let mut velocity = Vec::with_capacity(12);
    let mut boundary_kind = Vec::with_capacity(12);
    for y in 0..3 {
        for x in 0..4 {
            density.push(1.0 + 0.01 * f64::from(x + 10 * y) + 0.1 * physical_time);
            velocity.push([0.1 * f64::from(x) + physical_time, -0.05 * f64::from(y)]);
            boundary_kind.push(match (x, y) {
                (0, _) => BoundaryKind::Inlet,
                (3, _) => BoundaryKind::Outlet,
                (2, 1) => BoundaryKind::Solid,
                (_, 0 | 2) => BoundaryKind::Wall,
                _ => BoundaryKind::Fluid,
            });
        }
    }
    (density, velocity, boundary_kind)
}

fn run_metadata() -> &'static str {
    concat!(
        "schema_version = 1\n",
        "generator_version = \"",
        env!("CARGO_PKG_VERSION"),
        "\"\n",
        "case = \"vtk-interop-synthetic\"\n",
        "units = \"lattice\"\n",
        "dimensions = [4, 3]\n",
        "origin = [0.0, 0.0]\n",
        "spacing = [1.0, 1.0]\n",
        "steps = [0, 7]\n",
        "physical_times = [0.0, 0.35]\n",
        "fields = [\"density\", \"velocity\", \"boundary_kind\"]\n",
        "generator = \"cargo run -p vtk-interop -- <output-directory>\"\n",
        "purpose = \"format interoperability only; not CFD validation\"\n",
    )
}

#[cfg(test)]
mod tests {
    use std::{fs, process};

    use super::{generate_interop_assets, regenerate_interop_assets};

    #[test]
    fn generator_publishes_complete_two_step_run() {
        let output = std::env::temp_dir().join(format!("lbm-vtk-interop-{}", process::id()));
        let _ = fs::remove_dir_all(&output);

        generate_interop_assets(&output).unwrap();

        let names = fs::read_dir(&output)
            .unwrap()
            .map(|entry| entry.unwrap().file_name().into_string().unwrap())
            .collect::<Vec<_>>();
        let mut names = names;
        names.sort();
        assert_eq!(
            names,
            [
                "interop.vti.series",
                "run.toml",
                "step_000000.vti",
                "step_000007.vti",
            ]
        );
        let metadata = fs::read_to_string(output.join("run.toml")).unwrap();
        assert!(metadata.contains("schema_version = 1"));
        assert!(metadata.contains("generator_version = \"0.1.0\""));
        assert!(metadata.contains("dimensions = [4, 3]"));
        assert!(metadata.contains("units = \"lattice\""));
        assert!(metadata.contains("fields = [\"density\", \"velocity\", \"boundary_kind\"]"));
        fs::remove_dir_all(output).unwrap();
    }

    #[test]
    fn forced_regeneration_rejects_targets_outside_project_generated_directories() {
        let output = std::env::temp_dir().join(format!("lbm-vtk-unsafe-force-{}", process::id()));
        let _ = fs::remove_dir_all(&output);
        fs::create_dir(&output).unwrap();

        let error = regenerate_interop_assets(&output)
            .expect_err("force must not remove an arbitrary absolute directory");

        assert_eq!(error.kind(), std::io::ErrorKind::PermissionDenied);
        assert!(output.exists());
        fs::remove_dir_all(output).unwrap();
    }
}
