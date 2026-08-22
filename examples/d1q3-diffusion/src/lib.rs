//! 一维扩散方程的显式有限差分与 D1Q3 格子 Boltzmann 对比基准。
//!
//! 基准算例是周期区域上的正弦模态衰减。两种求解器都工作在格子单位下
//! （格距与时间步均为一），扩散数固定时步数随格点数平方增长，
//! 用于检验守恒、松弛率映射与二阶收敛。

// 基准的格点数与步数远小于 2^53，usize 到 f64 的转换不会损失精度。
#![allow(clippy::cast_precision_loss)]

use kuva::{
    backend::svg::SvgBackend,
    prelude::{Layout, LinePlot, LineStyle, Plot, ScatterPlot},
    render::figure::Figure,
};
use lbm_core::{D1Q3, diffusion_equilibrium};

/// 基准初值的背景标量。
pub const BACKGROUND: f64 = 1.0;

/// 基准初值的正弦振幅。
pub const AMPLITUDE: f64 = 0.5;

/// 型线对比使用的格点数。
pub const PROFILE_LENGTH: usize = 64;

/// 型线对比使用的演化步数（扩散系数为六分之一时）。
pub const PROFILE_STEPS: usize = 500;

/// 由松弛率计算格子单位下的扩散系数，即声速平方乘以（一除以松弛率减二分之一）。
#[must_use]
pub fn lattice_diffusivity(omega: f64) -> f64 {
    D1Q3::SPEED_OF_SOUND_SQUARED * (1.0 / omega - 0.5)
}

/// 生成单模态正弦初值，波数为二倍圆周率除以格点数。
#[must_use]
pub fn sine_mode(length: usize, background: f64, amplitude: f64) -> Vec<f64> {
    (0..length)
        .map(|index| {
            let phase = 2.0 * std::f64::consts::PI * index as f64 / length as f64;
            background + amplitude * phase.sin()
        })
        .collect()
}

/// 单模态正弦初值在扩散方程下的解析解（格子单位）。
#[must_use]
pub fn sine_mode_analytic(
    length: usize,
    background: f64,
    amplitude: f64,
    diffusivity: f64,
    steps: usize,
) -> Vec<f64> {
    let wave_number = 2.0 * std::f64::consts::PI / length as f64;
    let decay = (-diffusivity * wave_number * wave_number * steps as f64).exp();
    sine_mode(length, background, amplitude * decay)
}

/// 计算归一化 L2 误差，即逐点误差平方和除以格点数后再开方。
#[must_use]
pub fn l2_error(numerical: &[f64], analytic: &[f64]) -> f64 {
    let squared: f64 = numerical
        .iter()
        .zip(analytic)
        .map(|(numerical, analytic)| (numerical - analytic).powi(2))
        .sum();
    (squared / numerical.len() as f64).sqrt()
}

/// 一维周期区域上的显式 FTCS 有限差分求解器。
pub struct FtcsSolver {
    phi: Vec<f64>,
    diffusion_number: f64,
}

impl FtcsSolver {
    /// 以给定初值和扩散数构造求解器。
    #[must_use]
    pub fn new(phi: Vec<f64>, diffusion_number: f64) -> Self {
        Self {
            phi,
            diffusion_number,
        }
    }

    /// 推进一个时间步。
    pub fn step(&mut self) {
        let length = self.phi.len();
        let previous = self.phi.clone();
        for (index, value) in self.phi.iter_mut().enumerate() {
            let laplacian = previous[(index + 1) % length] - 2.0 * previous[index]
                + previous[(index + length - 1) % length];
            *value = previous[index] + self.diffusion_number * laplacian;
        }
    }

    /// 返回当前标量场。
    #[must_use]
    pub fn phi(&self) -> &[f64] {
        &self.phi
    }
}

/// 一维周期区域上的 D1Q3 单松弛格子 Boltzmann 求解器。
pub struct D1q3Solver {
    distributions: Vec<[f64; D1Q3::Q]>,
    omega: f64,
}

impl D1q3Solver {
    /// 用平衡分布从给定标量场初始化。
    #[must_use]
    pub fn from_scalar(phi: &[f64], omega: f64) -> Self {
        Self {
            distributions: phi
                .iter()
                .map(|&scalar| diffusion_equilibrium(scalar))
                .collect(),
            omega,
        }
    }

    /// 推进一个时间步，先本地碰撞再沿格线迁移。
    pub fn step(&mut self) {
        let length = self.distributions.len();
        let mut streamed = vec![[0.0; D1Q3::Q]; length];
        for (index, cell) in self.distributions.iter().enumerate() {
            let scalar: f64 = cell.iter().sum();
            let equilibrium = diffusion_equilibrium(scalar);
            for (direction, (&velocity, &target)) in
                D1Q3::VELOCITIES.iter().zip(&equilibrium).enumerate()
            {
                let post_collision = cell[direction] - self.omega * (cell[direction] - target);
                let destination = match velocity {
                    0 => index,
                    1 => (index + 1) % length,
                    _ => (index + length - 1) % length,
                };
                streamed[destination][direction] = post_collision;
            }
        }
        self.distributions = streamed;
    }

    /// 返回当前标量场，即逐格点的零阶矩。
    #[must_use]
    pub fn scalar(&self) -> Vec<f64> {
        self.distributions
            .iter()
            .map(|cell| cell.iter().sum())
            .collect()
    }
}

/// 一组格点数下的收敛数据。
pub struct ConvergenceRow {
    /// 格点数。
    pub length: usize,
    /// 有限差分与松弛率为一的 LBM 使用的步数。
    pub steps: usize,
    /// 有限差分的归一化 L2 误差。
    pub error_fdm: f64,
    /// 松弛率为一的 LBM 的归一化 L2 误差。
    pub error_lbm_omega1: f64,
    /// 松弛率为一点五的 LBM 的归一化 L2 误差（步数为三倍以保持物理时间一致）。
    pub error_lbm_omega3half: f64,
}

/// 一个问题规模下的 FTCS 与 D1Q3 LBM 性能统计。
pub struct PerformanceRow {
    /// 格点数。
    pub length: usize,
    /// 每个计时样本包含的演化步数。
    pub steps: usize,
    /// 每种求解器的计时样本数。
    pub samples: usize,
    /// FTCS 每格点每步耗时的中位数，单位为纳秒。
    pub ftcs_nanoseconds_per_site_step: f64,
    /// FTCS 每格点每步耗时的中位绝对偏差，单位为纳秒。
    pub ftcs_mad_nanoseconds_per_site_step: f64,
    /// D1Q3 LBM 每格点每步耗时的中位数，单位为纳秒。
    pub lbm_nanoseconds_per_site_step: f64,
    /// D1Q3 LBM 每格点每步耗时的中位绝对偏差，单位为纳秒。
    pub lbm_mad_nanoseconds_per_site_step: f64,
}

impl PerformanceRow {
    /// FTCS 吞吐量，单位为百万格点更新每秒。
    #[must_use]
    pub fn ftcs_mlups(&self) -> f64 {
        1_000.0 / self.ftcs_nanoseconds_per_site_step
    }

    /// D1Q3 LBM 吞吐量，单位为百万格点更新每秒。
    #[must_use]
    pub fn lbm_mlups(&self) -> f64 {
        1_000.0 / self.lbm_nanoseconds_per_site_step
    }

    /// 当前实现中 FTCS 相对 D1Q3 LBM 的加速比。
    #[must_use]
    pub fn ftcs_speedup_over_lbm(&self) -> f64 {
        self.lbm_nanoseconds_per_site_step / self.ftcs_nanoseconds_per_site_step
    }
}

/// 在扩散数固定、步数随格点数平方增长的条件下执行网格收敛研究。
#[must_use]
pub fn convergence_study(lengths: &[usize]) -> Vec<ConvergenceRow> {
    lengths
        .iter()
        .map(|&length| {
            let initial = sine_mode(length, BACKGROUND, AMPLITUDE);

            let steps = length * length / 8;
            let diffusivity = lattice_diffusivity(1.0);
            let analytic = sine_mode_analytic(length, BACKGROUND, AMPLITUDE, diffusivity, steps);

            let mut fdm = FtcsSolver::new(initial.clone(), diffusivity);
            let mut lbm_omega1 = D1q3Solver::from_scalar(&initial, 1.0);
            for _ in 0..steps {
                fdm.step();
                lbm_omega1.step();
            }

            let steps_slow = 3 * steps;
            let diffusivity_slow = lattice_diffusivity(1.5);
            let analytic_slow =
                sine_mode_analytic(length, BACKGROUND, AMPLITUDE, diffusivity_slow, steps_slow);
            let mut lbm_omega3half = D1q3Solver::from_scalar(&initial, 1.5);
            for _ in 0..steps_slow {
                lbm_omega3half.step();
            }

            ConvergenceRow {
                length,
                steps,
                error_fdm: l2_error(fdm.phi(), &analytic),
                error_lbm_omega1: l2_error(&lbm_omega1.scalar(), &analytic),
                error_lbm_omega3half: l2_error(&lbm_omega3half.scalar(), &analytic_slow),
            }
        })
        .collect()
}

/// 生成型线对比使用的四组曲线，依次为解析解、有限差分、两种松弛率的 LBM。
#[must_use]
pub fn profile_comparison() -> (Vec<f64>, Vec<Vec<f64>>) {
    let initial = sine_mode(PROFILE_LENGTH, BACKGROUND, AMPLITUDE);
    let diffusivity = lattice_diffusivity(1.0);
    let analytic = sine_mode_analytic(
        PROFILE_LENGTH,
        BACKGROUND,
        AMPLITUDE,
        diffusivity,
        PROFILE_STEPS,
    );

    let mut fdm = FtcsSolver::new(initial.clone(), diffusivity);
    let mut lbm_omega1 = D1q3Solver::from_scalar(&initial, 1.0);
    for _ in 0..PROFILE_STEPS {
        fdm.step();
        lbm_omega1.step();
    }

    let mut lbm_omega3half = D1q3Solver::from_scalar(&initial, 1.5);
    for _ in 0..3 * PROFILE_STEPS {
        lbm_omega3half.step();
    }

    let positions = (0..PROFILE_LENGTH).map(|index| index as f64).collect();
    (
        positions,
        vec![
            analytic,
            fdm.phi().to_vec(),
            lbm_omega1.scalar(),
            lbm_omega3half.scalar(),
        ],
    )
}

/// 使用 Kuva 生成型线对比与网格收敛的双联数据图。
#[must_use]
pub fn render_comparison_svg(
    positions: &[f64],
    profiles: &[Vec<f64>],
    rows: &[ConvergenceRow],
) -> String {
    let (profile_plots, profile_layout) = profile_panel(positions, profiles);
    let (convergence_plots, convergence_layout) = convergence_panel(rows);

    let scene = Figure::new(1, 2)
        .with_plots(vec![profile_plots, convergence_plots])
        .with_layouts(vec![profile_layout, convergence_layout])
        .with_labels_lowercase()
        .with_cell_size(450.0, 420.0)
        .render();
    let svg = SvgBackend.render_scene(&scene);
    let description = "一维扩散正弦模态衰减的 FTCS 与 D1Q3 LBM 对比。\
        左图给出格点数为六十四时同一无量纲时刻的型线，右图给出扩散数固定时误差随格点数的下降。\
        扩散数为六分之一时 FTCS 实线与松弛率为一的 LBM 圆点重合，首项误差抵消而呈四阶收敛；\
        松弛率为一点五的 LBM 呈二阶收敛。";

    add_accessibility_metadata(svg, "一维扩散的有限差分与 LBM 对比", description)
}

/// 使用 Kuva 生成 FTCS 与 D1Q3 LBM 的单线程吞吐量数据图。
#[must_use]
pub fn render_performance_svg(rows: &[PerformanceRow], environment: &str) -> String {
    let throughput = |select: fn(&PerformanceRow) -> f64| -> Vec<(f64, f64)> {
        rows.iter()
            .map(|row| (row.length as f64, select(row)))
            .collect()
    };
    let ftcs = LinePlot::new()
        .with_data(throughput(PerformanceRow::ftcs_mlups))
        .with_color("#59636f")
        .with_stroke_width(2.0)
        .with_legend("FTCS");
    let lbm = LinePlot::new()
        .with_data(throughput(PerformanceRow::lbm_mlups))
        .with_color("#a74428")
        .with_stroke_width(2.0)
        .with_legend("D1Q3 LBM");
    let plots = vec![Plot::Line(ftcs), Plot::Line(lbm)];
    let layout = Layout::auto_from_plots(&plots)
        .with_title("单线程发布构建吞吐量")
        .with_x_label("格点数 N")
        .with_y_label("吞吐量（MLUPS）")
        .with_log_scale();
    let scene = Figure::new(1, 1)
        .with_plots(vec![plots])
        .with_layouts(vec![layout])
        .with_cell_size(760.0, 420.0)
        .render();
    let svg = SvgBackend.render_scene(&scene);
    let description = format!(
        "FTCS 与 D1Q3 LBM 当前 Rust 实现的单线程吞吐量。横轴为格点数，纵轴为百万格点更新每秒。{environment}"
    );
    add_accessibility_metadata(svg, "一维扩散求解器性能对比", &description)
}

fn profile_panel(positions: &[f64], profiles: &[Vec<f64>]) -> (Vec<Plot>, Layout) {
    let series = |values: &[f64]| -> Vec<(f64, f64)> {
        positions
            .iter()
            .copied()
            .zip(values.iter().copied())
            .collect()
    };

    let analytic = LinePlot::new()
        .with_data(series(&profiles[0]))
        .with_color("#1f5a91")
        .with_stroke_width(2.2)
        .with_legend("解析解");
    let fdm = LinePlot::new()
        .with_data(series(&profiles[1]))
        .with_color("#59636f")
        .with_stroke_width(1.6)
        .with_line_style(LineStyle::Dashed)
        .with_legend("FTCS：r = 1/6");
    let lbm_omega1 = ScatterPlot::new()
        .with_data(series(&profiles[2]))
        .with_color("#a74428")
        .with_size(4.0)
        .with_legend("LBM（ω = 1）");
    let lbm_omega3half = LinePlot::new()
        .with_data(series(&profiles[3]))
        .with_color("#2c7a4b")
        .with_stroke_width(1.6)
        .with_line_style(LineStyle::DashDot)
        .with_legend("LBM（ω = 1.5）");
    let plots = vec![
        Plot::Line(analytic),
        Plot::Line(fdm),
        Plot::Scatter(lbm_omega1),
        Plot::Line(lbm_omega3half),
    ];
    let layout = Layout::auto_from_plots(&plots)
        .with_title("正弦模态衰减（N = 64）")
        .with_x_label("格点坐标 x/Δx")
        .with_y_label("标量");
    (plots, layout)
}

fn convergence_panel(rows: &[ConvergenceRow]) -> (Vec<Plot>, Layout) {
    let lengths: Vec<f64> = rows.iter().map(|row| row.length as f64).collect();
    let errors = |select: fn(&ConvergenceRow) -> f64| -> Vec<(f64, f64)> {
        rows.iter()
            .map(|row| (row.length as f64, select(row)))
            .collect()
    };
    // r = 1/6 是 FTCS 的魔数，首项误差抵消而呈四阶；一般参数下两种方法都是二阶。
    // 两条参考线分别锚定相应曲线在最少格点数处的误差。
    let (second_order, fourth_order) = rows.first().map_or((Vec::new(), Vec::new()), |row| {
        let second = row.error_lbm_omega3half * row.length.pow(2) as f64;
        let fourth = row.error_fdm * row.length.pow(4) as f64;
        (
            lengths
                .iter()
                .map(|length| (*length, second / length.powi(2)))
                .collect(),
            lengths
                .iter()
                .map(|length| (*length, fourth / length.powi(4)))
                .collect(),
        )
    });

    let convergence_fdm = LinePlot::new()
        .with_data(errors(|row| row.error_fdm))
        .with_color("#59636f")
        .with_stroke_width(1.8)
        .with_legend("FTCS：r = 1/6");
    let convergence_omega1 = ScatterPlot::new()
        .with_data(errors(|row| row.error_lbm_omega1))
        .with_color("#a74428")
        .with_size(5.0)
        .with_legend("LBM（ω = 1）");
    let convergence_omega3half = LinePlot::new()
        .with_data(errors(|row| row.error_lbm_omega3half))
        .with_color("#2c7a4b")
        .with_stroke_width(1.8)
        .with_legend("LBM（ω = 1.5）");
    let convergence_reference2 = LinePlot::new()
        .with_data(second_order)
        .with_color("#1f5a91")
        .with_stroke_width(1.4)
        .with_line_style(LineStyle::Dashed)
        .with_legend("二阶参考线");
    let convergence_reference4 = LinePlot::new()
        .with_data(fourth_order)
        .with_color("#1f5a91")
        .with_stroke_width(1.4)
        .with_line_style(LineStyle::Dotted)
        .with_legend("四阶参考线");
    let plots = vec![
        Plot::Line(convergence_fdm),
        Plot::Scatter(convergence_omega1),
        Plot::Line(convergence_omega3half),
        Plot::Line(convergence_reference2),
        Plot::Line(convergence_reference4),
    ];
    let layout = Layout::auto_from_plots(&plots)
        .with_title("固定扩散数的网格收敛（t/t_D = 1/48）")
        .with_x_label("格点数")
        .with_y_label("归一化 L2 误差")
        .with_log_scale();
    (plots, layout)
}

fn add_accessibility_metadata(mut svg: String, title: &str, description: &str) -> String {
    let root_end = svg.find('>').expect("Kuva SVG must contain a root element");
    svg.insert_str(
        root_end,
        " role=\"img\" aria-labelledby=\"plot-title plot-description\"",
    );
    svg.insert_str(
        root_end + 1 + " role=\"img\" aria-labelledby=\"plot-title plot-description\"".len(),
        &format!(
            "\n<title id=\"plot-title\">{}</title>\n<desc id=\"plot-description\">{}</desc>",
            escape_xml(title),
            escape_xml(description)
        ),
    );
    svg
}

fn escape_xml(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

#[cfg(test)]
mod tests {
    use super::*;

    const TOLERANCE: f64 = 1.0e-12;

    #[test]
    fn ftcs_conserves_total_scalar() {
        let initial = sine_mode(32, BACKGROUND, AMPLITUDE);
        let total: f64 = initial.iter().sum();
        let mut solver = FtcsSolver::new(initial, 1.0 / 6.0);
        for _ in 0..100 {
            solver.step();
        }
        let current: f64 = solver.phi().iter().sum();
        assert!((current - total).abs() < 1.0e-10 * total.abs());
    }

    #[test]
    fn lbm_conserves_total_scalar() {
        let initial = sine_mode(32, BACKGROUND, AMPLITUDE);
        let total: f64 = initial.iter().sum();
        let mut solver = D1q3Solver::from_scalar(&initial, 1.3);
        for _ in 0..100 {
            solver.step();
        }
        let current: f64 = solver.scalar().iter().sum();
        assert!((current - total).abs() < 1.0e-10 * total.abs());
    }

    #[test]
    fn omega_one_lbm_is_algebraically_identical_to_ftcs() {
        let initial = sine_mode(48, BACKGROUND, AMPLITUDE);
        let mut fdm = FtcsSolver::new(initial.clone(), 1.0 / 6.0);
        let mut lbm = D1q3Solver::from_scalar(&initial, 1.0);
        for _ in 0..25 {
            fdm.step();
            lbm.step();
        }
        let difference: f64 = fdm
            .phi()
            .iter()
            .zip(lbm.scalar())
            .map(|(fdm, lbm)| (fdm - lbm).abs())
            .fold(0.0, f64::max);
        assert!(difference < TOLERANCE, "max difference {difference:.3e}");
    }

    #[test]
    fn measured_decay_rate_matches_analytic() {
        let length = 64;
        let initial = sine_mode(length, 0.0, AMPLITUDE);
        let mut solver = D1q3Solver::from_scalar(&initial, 1.0);
        let steps = 500;
        for _ in 0..steps {
            solver.step();
        }

        let wave_number = 2.0 * std::f64::consts::PI / length as f64;
        let amplitude: f64 = solver
            .scalar()
            .iter()
            .enumerate()
            .map(|(index, value)| value * (wave_number * index as f64).sin())
            .sum::<f64>()
            * 2.0
            / length as f64;
        let analytic = AMPLITUDE
            * (-lattice_diffusivity(1.0) * wave_number * wave_number * f64::from(steps)).exp();
        let relative = (amplitude - analytic).abs() / analytic;
        assert!(relative < 2.0e-3, "relative decay error {relative:.3e}");
    }

    #[test]
    fn convergence_orders_match_theory() {
        let rows = convergence_study(&[16, 32, 64]);
        for pair in rows.windows(2) {
            // r = 1/6 时 FTCS 首项误差抵消而呈四阶；omega = 1 的 LBM 与之代数等价。
            for ratio in [
                pair[0].error_fdm / pair[1].error_fdm,
                pair[0].error_lbm_omega1 / pair[1].error_lbm_omega1,
            ] {
                assert!(
                    (ratio - 16.0).abs() < 2.0,
                    "expected error ratio near 16, got {ratio:.3}"
                );
            }
            // 一般松弛率下 LBM 保持二阶。
            let ratio = pair[0].error_lbm_omega3half / pair[1].error_lbm_omega3half;
            assert!(
                (ratio - 4.0).abs() < 0.6,
                "expected error ratio near 4, got {ratio:.3}"
            );
        }
    }

    #[test]
    fn rendered_data_plot_preserves_semantics_and_accessibility() {
        let (positions, profiles) = profile_comparison();
        let rows = convergence_study(&[16, 32]);
        let svg = render_comparison_svg(&positions, &profiles, &rows);

        for expected in [
            "<title id=\"plot-title\">一维扩散的有限差分与 LBM 对比</title>",
            "<desc id=\"plot-description\">",
            "role=\"img\"",
            "aria-labelledby=\"plot-title plot-description\"",
            "解析解",
            "FTCS：r = 1/6",
            "LBM（ω = 1）",
            "LBM（ω = 1.5）",
            "二阶参考线",
            "四阶参考线",
        ] {
            assert!(svg.contains(expected), "missing SVG semantic: {expected}");
        }
    }

    #[test]
    fn rendered_performance_plot_preserves_semantics_and_accessibility() {
        let rows = [PerformanceRow {
            length: 1024,
            steps: 16,
            samples: 9,
            ftcs_nanoseconds_per_site_step: 2.0,
            ftcs_mad_nanoseconds_per_site_step: 0.1,
            lbm_nanoseconds_per_site_step: 6.0,
            lbm_mad_nanoseconds_per_site_step: 0.2,
        }];
        let svg = render_performance_svg(&rows, "测试环境");

        for expected in [
            "<title id=\"plot-title\">一维扩散求解器性能对比</title>",
            "<desc id=\"plot-description\">",
            "role=\"img\"",
            "FTCS",
            "D1Q3 LBM",
            "MLUPS",
            "测试环境",
        ] {
            assert!(svg.contains(expected), "missing SVG semantic: {expected}");
        }
    }
}
