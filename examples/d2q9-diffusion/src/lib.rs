//! 二维扩散方程的显式有限差分与 D2Q9 格子 Boltzmann 对比基准。
//!
//! 主算例是正方形区域上四壁齐次 Dirichlet 的单模态瞬态衰减，解析解为
//! `sin(pi x / L) sin(pi y / L) exp(-2 D (pi / L)^2 t)`。格点位于
//! `x = (j + 1/2) dx`，壁面落在首末格点外半格距处，因此区域边长为 `L = N dx`。
//! 该算例同时覆盖壁面重构、角点、各向同性与松弛率到扩散系数的映射。
//!
//! 两种求解器都工作在格子单位下（格距与时间步均为一）。固定松弛率、步数随格点数
//! 平方增长即扩散标度，各分辨率停在同一无量纲时刻。

// 格点数与步数远小于 2^53，usize 到 f64 的转换不会损失精度。
#![allow(clippy::cast_precision_loss)]

use kuva::{
    backend::svg::SvgBackend,
    prelude::{ColorMap, Heatmap, Layout, LinePlot, LineStyle, Plot, ScatterPlot},
    render::figure::Figure,
};
use lbm_core::{D2Q5, D2Q9, d2q5, d2q9};

/// 网格收敛研究使用的格点数序列。
///
/// 代价随格点数四次方增长（格点数平方乘步数平方），因此止于 128；
/// 再加一档会让生成资产检查无法在常规构建中完成。
pub const CONVERGENCE_LENGTHS: [usize; 4] = [16, 32, 64, 128];

/// 型线与误差场对比使用的格点数。
pub const PROFILE_LENGTH: usize = 64;

/// 型线与误差场对比使用的演化步数（松弛率为一时）。
///
/// 取值使振幅衰减到初值的约五分之一，壁面附近的误差结构才可分辨。
pub const PROFILE_STEPS: usize = 2048;

/// 由松弛率计算格子单位下的扩散系数，即声速平方乘以（一除以松弛率减二分之一）。
#[must_use]
pub fn lattice_diffusivity(omega: f64) -> f64 {
    D2Q9::SPEED_OF_SOUND_SQUARED * (1.0 / omega - 0.5)
}

/// 齐次 Dirichlet 算例的单模态初值与解析解。
///
/// `decay` 是该时刻的振幅；取一得到初值。
#[must_use]
pub fn dirichlet_mode(length: usize, decay: f64) -> Vec<f64> {
    let wave_number = std::f64::consts::PI / length as f64;
    let mut field = vec![0.0; length * length];
    for row in 0..length {
        for column in 0..length {
            let x = (column as f64 + 0.5) * wave_number;
            let y = (row as f64 + 0.5) * wave_number;
            field[row * length + column] = decay * x.sin() * y.sin();
        }
    }
    field
}

/// 齐次 Dirichlet 算例在给定步数后的解析振幅。
///
/// 模态波数在两个方向相同，衰减率因此是 `2 D k^2` 而非一维的 `D k^2`。
#[must_use]
pub fn dirichlet_amplitude(length: usize, diffusivity: f64, steps: usize) -> f64 {
    let wave_number = std::f64::consts::PI / length as f64;
    (-2.0 * diffusivity * wave_number * wave_number * steps as f64).exp()
}

/// 周期算例的单模态初值与解析解，波数为二倍圆周率除以格点数。
#[must_use]
pub fn periodic_mode(length: usize, decay: f64) -> Vec<f64> {
    let wave_number = 2.0 * std::f64::consts::PI / length as f64;
    let mut field = vec![0.0; length * length];
    for row in 0..length {
        for column in 0..length {
            let x = column as f64 * wave_number;
            let y = row as f64 * wave_number;
            field[row * length + column] = decay * x.sin() * y.sin();
        }
    }
    field
}

/// 周期算例在给定步数后的解析振幅。
#[must_use]
pub fn periodic_amplitude(length: usize, diffusivity: f64, steps: usize) -> f64 {
    let wave_number = 2.0 * std::f64::consts::PI / length as f64;
    (-2.0 * diffusivity * wave_number * wave_number * steps as f64).exp()
}

/// 计算相对归一化 L2 误差，即逐点误差平方和除以格点数、开方后再除以该时刻的解析振幅。
///
/// 齐次 Dirichlet 下场整体衰减到零，绝对误差会随所选终止时刻任意缩放；
/// 除以瞬时振幅后数值才可解释。它与一维算例的绝对误差定义不同，不可直接比较大小。
#[must_use]
pub fn relative_l2(numerical: &[f64], analytic: &[f64], amplitude: f64) -> f64 {
    let squared: f64 = numerical
        .iter()
        .zip(analytic)
        .map(|(numerical, analytic)| (numerical - analytic).powi(2))
        .sum();
    (squared / numerical.len() as f64).sqrt() / amplitude
}

/// 由相邻两档格点数的误差计算实测收敛阶。
#[must_use]
pub fn convergence_order(coarse_error: f64, fine_error: f64) -> f64 {
    (coarse_error / fine_error).log2()
}

/// 齐次 Dirichlet 壁面的入射分布重构方式。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Reconstruction {
    /// 反弹跳：出射与入射之和固定零阶矩，把边界值放在格点外半格距处。
    AntiBounceBack,
    /// 平衡覆盖：入射分布直接取边界值的平衡分布，实现最简单但壁面位置不同。
    Equilibrium,
}

/// 二维格子 Boltzmann 求解器的边界条件。
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Boundary {
    /// 四壁给定标量值。
    Dirichlet {
        /// 壁面标量值。
        scalar: f64,
        /// 入射分布的重构方式。
        reconstruction: Reconstruction,
    },
    /// 四壁周期。
    Periodic,
    /// 四壁绝热，即普通反弹，法向一阶矩为零。
    Adiabatic,
}

#[derive(Clone, Copy)]
struct LatticeDescriptor<const Q: usize> {
    velocities: [[i8; 2]; Q],
    weights: [f64; Q],
    opposite: [usize; Q],
}

const D2Q5_DESCRIPTOR: LatticeDescriptor<{ D2Q5::Q }> = LatticeDescriptor {
    velocities: D2Q5::VELOCITIES,
    weights: D2Q5::WEIGHTS,
    opposite: d2q5::OPPOSITE,
};

const D2Q9_DESCRIPTOR: LatticeDescriptor<{ D2Q9::Q }> = LatticeDescriptor {
    velocities: D2Q9::VELOCITIES,
    weights: D2Q9::WEIGHTS,
    opposite: d2q9::OPPOSITE,
};

struct ScalarDiffusionSolver2d<const Q: usize> {
    length: usize,
    omega: f64,
    boundary: Boundary,
    lattice: LatticeDescriptor<Q>,
    distributions: Vec<[f64; Q]>,
    post_collision: Vec<[f64; Q]>,
}

impl<const Q: usize> ScalarDiffusionSolver2d<Q> {
    fn from_scalar(
        phi: &[f64],
        length: usize,
        omega: f64,
        boundary: Boundary,
        lattice: LatticeDescriptor<Q>,
    ) -> Self {
        assert_eq!(phi.len(), length * length, "标量场必须是正方形区域");
        Self {
            length,
            omega,
            boundary,
            lattice,
            distributions: phi
                .iter()
                .map(|&scalar| lattice.weights.map(|weight| weight * scalar))
                .collect(),
            post_collision: vec![[0.0; Q]; length * length],
        }
    }

    fn step(&mut self) {
        for (site, cell) in self.distributions.iter().enumerate() {
            let scalar: f64 = cell.iter().sum();
            let target = self.lattice.weights.map(|weight| weight * scalar);
            for direction in 0..Q {
                self.post_collision[site][direction] =
                    cell[direction] - self.omega * (cell[direction] - target[direction]);
            }
        }

        let length = self.length;
        for row in 0..length {
            for column in 0..length {
                let site = row * length + column;
                for direction in 0..Q {
                    let velocity = self.lattice.velocities[direction];
                    let source = upstream(column, velocity[0], length).zip(upstream(
                        row,
                        velocity[1],
                        length,
                    ));
                    let value = match source {
                        Some((source_column, source_row)) => {
                            self.post_collision[source_row * length + source_column][direction]
                        }
                        None => self.reconstruct(site, direction, column, row),
                    };
                    self.distributions[site][direction] = value;
                }
            }
        }
    }

    fn reconstruct(&self, site: usize, direction: usize, column: usize, row: usize) -> f64 {
        match self.boundary {
            Boundary::Periodic => {
                let velocity = self.lattice.velocities[direction];
                let source_column = wrapped_upstream(column, velocity[0], self.length);
                let source_row = wrapped_upstream(row, velocity[1], self.length);
                self.post_collision[source_row * self.length + source_column][direction]
            }
            // 入射等于出射使法向一阶矩为零，把零通量放在半格距壁面处。
            Boundary::Adiabatic => self.post_collision[site][self.lattice.opposite[direction]],
            Boundary::Dirichlet {
                scalar,
                reconstruction,
            } => match reconstruction {
                Reconstruction::AntiBounceBack => {
                    2.0 * self.lattice.weights[direction] * scalar
                        - self.post_collision[site][self.lattice.opposite[direction]]
                }
                Reconstruction::Equilibrium => self.lattice.weights[direction] * scalar,
            },
        }
    }

    fn scalar(&self) -> Vec<f64> {
        self.distributions
            .iter()
            .map(|cell| cell.iter().sum())
            .collect()
    }
}

/// 二维单松弛 D2Q5 标量扩散求解器。
///
/// 分布函数按 `AoS` 布局存放，并复用与 D2Q9 相同的碰撞、迁移和边界重构内核。
pub struct D2q5Solver(ScalarDiffusionSolver2d<{ D2Q5::Q }>);

impl D2q5Solver {
    /// 用平衡分布从给定标量场初始化。
    ///
    /// # Panics
    ///
    /// 当 `phi` 的长度不是 `length` 的平方时触发。
    #[must_use]
    pub fn from_scalar(phi: &[f64], length: usize, omega: f64, boundary: Boundary) -> Self {
        Self(ScalarDiffusionSolver2d::from_scalar(
            phi,
            length,
            omega,
            boundary,
            D2Q5_DESCRIPTOR,
        ))
    }

    /// 推进一个时间步，先本地碰撞再沿格线迁移。
    pub fn step(&mut self) {
        self.0.step();
    }

    /// 返回当前标量场，即逐格点的零阶矩。
    #[must_use]
    pub fn scalar(&self) -> Vec<f64> {
        self.0.scalar()
    }
}

/// 二维单松弛 D2Q9 标量扩散求解器。
///
/// 分布函数按 `AoS` 布局存放。这是有意保留的待优化基线：布局对比属于性能实践，
/// 需要先有可比较的标量基线和一组固定的正确性测试。
pub struct D2q9Solver(ScalarDiffusionSolver2d<{ D2Q9::Q }>);

impl D2q9Solver {
    /// 用平衡分布从给定标量场初始化。
    ///
    /// # Panics
    ///
    /// 当 `phi` 的长度不是 `length` 的平方时触发。
    #[must_use]
    pub fn from_scalar(phi: &[f64], length: usize, omega: f64, boundary: Boundary) -> Self {
        Self(ScalarDiffusionSolver2d::from_scalar(
            phi,
            length,
            omega,
            boundary,
            D2Q9_DESCRIPTOR,
        ))
    }

    /// 推进一个时间步，先本地碰撞再沿格线迁移。
    ///
    /// 迁移采用拉取（pull）方式：每个格点从上游取分布，缺失的入射分布在同一循环内
    /// 按连接（link-wise）重构。这样角点不需要单独分支，凸角与直壁走同一条代码路径。
    pub fn step(&mut self) {
        self.0.step();
    }

    /// 返回当前标量场，即逐格点的零阶矩。
    #[must_use]
    pub fn scalar(&self) -> Vec<f64> {
        self.0.scalar()
    }
}

/// D2Q5 每格点保存一组离散分布函数所需的字节数。
pub const D2Q5_DISTRIBUTION_BYTES_PER_SITE: usize = std::mem::size_of::<[f64; D2Q5::Q]>();

/// D2Q9 每格点保存一组离散分布函数所需的字节数。
pub const D2Q9_DISTRIBUTION_BYTES_PER_SITE: usize = std::mem::size_of::<[f64; D2Q9::Q]>();

/// 当前 D2Q5 求解器双缓冲每格点所需的字节数，不含固定大小的求解器元数据。
pub const D2Q5_WORKING_BYTES_PER_SITE: usize = 2 * D2Q5_DISTRIBUTION_BYTES_PER_SITE;

/// 当前 D2Q9 求解器双缓冲每格点所需的字节数，不含固定大小的求解器元数据。
pub const D2Q9_WORKING_BYTES_PER_SITE: usize = 2 * D2Q9_DISTRIBUTION_BYTES_PER_SITE;

/// 一个二维问题规模下的 D2Q5 与 D2Q9 性能统计。
pub struct LatticePerformanceRow {
    /// 正方形区域的单边格点数。
    pub length: usize,
    /// 每个计时样本包含的演化步数。
    pub steps: usize,
    /// 每种格子的计时样本数。
    pub samples: usize,
    /// D2Q5 每格点每步耗时的中位数，单位为纳秒。
    pub d2q5_nanoseconds_per_site_step: f64,
    /// D2Q5 每格点每步耗时的中位绝对偏差，单位为纳秒。
    pub d2q5_mad_nanoseconds_per_site_step: f64,
    /// D2Q9 每格点每步耗时的中位数，单位为纳秒。
    pub d2q9_nanoseconds_per_site_step: f64,
    /// D2Q9 每格点每步耗时的中位绝对偏差，单位为纳秒。
    pub d2q9_mad_nanoseconds_per_site_step: f64,
}

impl LatticePerformanceRow {
    /// 区域中的格点总数。
    #[must_use]
    pub const fn sites(&self) -> usize {
        self.length * self.length
    }

    /// D2Q5 吞吐量，单位为百万格点更新每秒。
    #[must_use]
    pub fn d2q5_mlups(&self) -> f64 {
        1_000.0 / self.d2q5_nanoseconds_per_site_step
    }

    /// D2Q9 吞吐量，单位为百万格点更新每秒。
    #[must_use]
    pub fn d2q9_mlups(&self) -> f64 {
        1_000.0 / self.d2q9_nanoseconds_per_site_step
    }

    /// 当前实现中 D2Q5 相对 D2Q9 的吞吐加速比。
    #[must_use]
    pub fn d2q5_speedup_over_d2q9(&self) -> f64 {
        self.d2q9_nanoseconds_per_site_step / self.d2q5_nanoseconds_per_site_step
    }
}

/// 上游格点坐标；越出区域时返回 `None`，交由边界重构处理。
fn upstream(coordinate: usize, component: i8, length: usize) -> Option<usize> {
    coordinate
        .checked_add_signed(-isize::from(component))
        .filter(|source| *source < length)
}

/// 周期区域的上游格点坐标。先加一个周期再回退，整个计算保持在非负范围内。
fn wrapped_upstream(coordinate: usize, component: i8, length: usize) -> usize {
    (coordinate + length).wrapping_add_signed(-isize::from(component)) % length
}

/// 二维有限差分求解器的边界条件。
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FdmBoundary {
    /// 四壁给定标量值，用反对称虚拟格点实现，边界落在格点外半格距处。
    Dirichlet(f64),
    /// 四壁周期。
    Periodic,
}

/// 二维显式 FTCS 有限差分求解器。
///
/// 二维显式格式的稳定条件是扩散数不超过四分之一，比一维的二分之一更严格。
pub struct FtcsSolver {
    length: usize,
    diffusion_number: f64,
    boundary: FdmBoundary,
    phi: Vec<f64>,
    scratch: Vec<f64>,
}

impl FtcsSolver {
    /// 以给定初值、扩散数和边界条件构造求解器。
    ///
    /// # Panics
    ///
    /// 当 `phi` 的长度不是 `length` 的平方时触发。
    #[must_use]
    pub fn new(phi: Vec<f64>, length: usize, diffusion_number: f64, boundary: FdmBoundary) -> Self {
        assert_eq!(phi.len(), length * length, "标量场必须是正方形区域");
        Self {
            length,
            diffusion_number,
            boundary,
            scratch: vec![0.0; phi.len()],
            phi,
        }
    }

    /// 推进一个时间步。
    pub fn step(&mut self) {
        let length = self.length;
        for row in 0..length {
            for column in 0..length {
                let site = row * length + column;
                let mut laplacian = -4.0 * self.phi[site];
                for (offset_column, offset_row) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    laplacian += self.neighbour(column, row, offset_column, offset_row);
                }
                self.scratch[site] = self.phi[site] + self.diffusion_number * laplacian;
            }
        }
        std::mem::swap(&mut self.phi, &mut self.scratch);
    }

    /// 邻居取值；越出区域时按边界条件给出虚拟格点的值。
    fn neighbour(&self, column: usize, row: usize, offset_column: i8, offset_row: i8) -> f64 {
        let length = self.length;
        let neighbour = column
            .checked_add_signed(isize::from(offset_column))
            .filter(|value| *value < length)
            .zip(
                row.checked_add_signed(isize::from(offset_row))
                    .filter(|value| *value < length),
            );

        match neighbour {
            Some((neighbour_column, neighbour_row)) => {
                self.phi[neighbour_row * length + neighbour_column]
            }
            None => match self.boundary {
                // 反对称延拓：虚拟值与格点值的平均恰为边界值，边界因此落在半格距处，
                // 与格子 Boltzmann 的反弹跳放置壁面的方式一致。
                FdmBoundary::Dirichlet(scalar) => 2.0 * scalar - self.phi[row * length + column],
                FdmBoundary::Periodic => {
                    let wrapped_column = wrapped_upstream(column, -offset_column, length);
                    let wrapped_row = wrapped_upstream(row, -offset_row, length);
                    self.phi[wrapped_row * length + wrapped_column]
                }
            },
        }
    }

    /// 返回当前标量场。
    #[must_use]
    pub fn phi(&self) -> &[f64] {
        &self.phi
    }
}

/// 一组格点数下的 Dirichlet 算例收敛数据。
pub struct ConvergenceRow {
    /// 格点数。
    pub length: usize,
    /// 有限差分与松弛率为一的 LBM 使用的步数；松弛率为一点五时为三倍。
    pub steps: usize,
    /// 有限差分的相对归一化 L2 误差。
    pub error_ftcs: f64,
    /// 松弛率为一、反弹跳边界的相对归一化 L2 误差。
    pub error_lbm_omega1: f64,
    /// 松弛率为一点五、反弹跳边界的相对归一化 L2 误差。
    pub error_lbm_omega1p5: f64,
    /// 松弛率为一点五、平衡覆盖边界的相对归一化 L2 误差。
    pub error_lbm_equilibrium: f64,
}

/// 一组格点数下的周期区域体内收敛数据。
pub struct BulkOrderRow {
    /// 格点数。
    pub length: usize,
    /// 演化步数。
    pub steps: usize,
    /// 有限差分的相对归一化 L2 误差。
    pub error_ftcs: f64,
    /// 松弛率为一的 LBM 的相对归一化 L2 误差。
    pub error_lbm_omega1: f64,
}

/// 一个波矢下的实测扩散系数。
pub struct IsotropyRow {
    /// 以二倍圆周率除以格点数为单位的整数波矢。
    pub wave_vector: [i32; 2],
    /// 由实测衰减率反推的扩散系数。
    pub measured_diffusivity: f64,
}

/// 演化一个 D2Q9 算例并返回终态标量场。
fn evolve(phi: &[f64], length: usize, omega: f64, boundary: Boundary, steps: usize) -> Vec<f64> {
    let mut solver = D2q9Solver::from_scalar(phi, length, omega, boundary);
    for _ in 0..steps {
        solver.step();
    }
    solver.scalar()
}

/// 演化一个有限差分算例并返回终态标量场。
fn evolve_ftcs(
    phi: Vec<f64>,
    length: usize,
    diffusion_number: f64,
    boundary: FdmBoundary,
    steps: usize,
) -> Vec<f64> {
    let mut solver = FtcsSolver::new(phi, length, diffusion_number, boundary);
    for _ in 0..steps {
        solver.step();
    }
    solver.phi().to_vec()
}

/// 齐次 Dirichlet 算例的边界条件，壁面值为零。
fn homogeneous(reconstruction: Reconstruction) -> Boundary {
    Boundary::Dirichlet {
        scalar: 0.0,
        reconstruction,
    }
}

/// 在扩散标度下执行齐次 Dirichlet 算例的网格收敛研究。
///
/// 松弛率为一点五时扩散系数为松弛率为一时的三分之一，步数取三倍以停在同一物理时刻，
/// 四条曲线因此对应同一个解析振幅。
#[must_use]
pub fn convergence_study(lengths: &[usize]) -> Vec<ConvergenceRow> {
    lengths
        .iter()
        .map(|&length| {
            let steps = length * length / 8;
            let initial = dirichlet_mode(length, 1.0);

            let fast_diffusivity = lattice_diffusivity(1.0);
            let amplitude = dirichlet_amplitude(length, fast_diffusivity, steps);
            let analytic = dirichlet_mode(length, amplitude);

            let ftcs = evolve_ftcs(
                initial.clone(),
                length,
                fast_diffusivity,
                FdmBoundary::Dirichlet(0.0),
                steps,
            );
            let lbm_omega1 = evolve(
                &initial,
                length,
                1.0,
                homogeneous(Reconstruction::AntiBounceBack),
                steps,
            );

            let slow_steps = 3 * steps;
            let lbm_omega1p5 = evolve(
                &initial,
                length,
                1.5,
                homogeneous(Reconstruction::AntiBounceBack),
                slow_steps,
            );
            let lbm_equilibrium = evolve(
                &initial,
                length,
                1.5,
                homogeneous(Reconstruction::Equilibrium),
                slow_steps,
            );

            ConvergenceRow {
                length,
                steps,
                error_ftcs: relative_l2(&ftcs, &analytic, amplitude),
                error_lbm_omega1: relative_l2(&lbm_omega1, &analytic, amplitude),
                error_lbm_omega1p5: relative_l2(&lbm_omega1p5, &analytic, amplitude),
                error_lbm_equilibrium: relative_l2(&lbm_equilibrium, &analytic, amplitude),
            }
        })
        .collect()
}

/// 在周期区域上执行体内收敛研究，用于把格式本身的精度与壁面重构的影响分开。
#[must_use]
pub fn bulk_order_study(lengths: &[usize]) -> Vec<BulkOrderRow> {
    lengths
        .iter()
        .map(|&length| {
            let steps = length * length / 8;
            let initial = periodic_mode(length, 1.0);
            let diffusivity = lattice_diffusivity(1.0);
            let amplitude = periodic_amplitude(length, diffusivity, steps);
            let analytic = periodic_mode(length, amplitude);

            let ftcs = evolve_ftcs(
                initial.clone(),
                length,
                diffusivity,
                FdmBoundary::Periodic,
                steps,
            );
            let lbm = evolve(&initial, length, 1.0, Boundary::Periodic, steps);

            BulkOrderRow {
                length,
                steps,
                error_ftcs: relative_l2(&ftcs, &analytic, amplitude),
                error_lbm_omega1: relative_l2(&lbm, &analytic, amplitude),
            }
        })
        .collect()
}

/// 在周期区域上按平面波模态测量扩散系数。
///
/// 波矢取模长相同、取向不同的整数组合，测得扩散系数的差异才只反映各向异性，
/// 而不混入波长不同带来的离散误差。
#[must_use]
pub fn isotropy_study(
    length: usize,
    omega: f64,
    steps: usize,
    wave_vectors: &[[i32; 2]],
) -> Vec<IsotropyRow> {
    let unit = 2.0 * std::f64::consts::PI / length as f64;

    wave_vectors
        .iter()
        .map(|&wave_vector| {
            let phase = |column: usize, row: usize| {
                unit * (f64::from(wave_vector[0]) * column as f64
                    + f64::from(wave_vector[1]) * row as f64)
            };

            let mut initial = vec![0.0; length * length];
            for row in 0..length {
                for column in 0..length {
                    initial[row * length + column] = phase(column, row).sin();
                }
            }

            let evolved = evolve(&initial, length, omega, Boundary::Periodic, steps);

            // 投影回初始模态读出振幅；单一平面波的正弦平方和为格点数的一半。
            let mut projection = 0.0;
            for row in 0..length {
                for column in 0..length {
                    projection += evolved[row * length + column] * phase(column, row).sin();
                }
            }
            let amplitude = 2.0 * projection / (length * length) as f64;

            let wave_squared = (unit * f64::from(wave_vector[0])).powi(2)
                + (unit * f64::from(wave_vector[1])).powi(2);
            let rate = -amplitude.ln() / steps as f64;

            IsotropyRow {
                wave_vector,
                measured_diffusivity: rate / wave_squared,
            }
        })
        .collect()
}

/// 型线与误差场对比的数据。
pub struct FieldComparison {
    /// 格点数。
    pub length: usize,
    /// 该时刻的解析振幅，用于把误差归一化为相对量。
    pub amplitude: f64,
    /// 中心线格点坐标。
    pub positions: Vec<f64>,
    /// 中心线剖面，依次为解析解、有限差分、反弹跳 LBM、平衡覆盖 LBM。
    pub profiles: Vec<Vec<f64>>,
    /// 反弹跳 LBM 的相对误差场，已除以该时刻的解析振幅。
    pub relative_error_field: Vec<f64>,
}

impl FieldComparison {
    /// 某条中心线剖面相对解析解的误差，已除以该时刻的解析振幅。
    ///
    /// `index` 与 [`Self::profiles`] 的顺序一致；取零得到全零序列。
    #[must_use]
    pub fn relative_centerline_error(&self, index: usize) -> Vec<f64> {
        self.profiles[index]
            .iter()
            .zip(&self.profiles[0])
            .map(|(numerical, analytic)| (numerical - analytic) / self.amplitude)
            .collect()
    }
}

/// 生成型线与误差场对比的数据，四条曲线停在同一物理时刻。
#[must_use]
pub fn field_comparison() -> FieldComparison {
    let length = PROFILE_LENGTH;
    let initial = dirichlet_mode(length, 1.0);
    let fast_diffusivity = lattice_diffusivity(1.0);
    let amplitude = dirichlet_amplitude(length, fast_diffusivity, PROFILE_STEPS);
    let analytic = dirichlet_mode(length, amplitude);

    let ftcs = evolve_ftcs(
        initial.clone(),
        length,
        fast_diffusivity,
        FdmBoundary::Dirichlet(0.0),
        PROFILE_STEPS,
    );
    let slow_steps = 3 * PROFILE_STEPS;
    let anti_bounce_back = evolve(
        &initial,
        length,
        1.5,
        homogeneous(Reconstruction::AntiBounceBack),
        slow_steps,
    );
    let equilibrium = evolve(
        &initial,
        length,
        1.5,
        homogeneous(Reconstruction::Equilibrium),
        slow_steps,
    );

    let centerline = length / 2;
    let row = |field: &[f64]| field[centerline * length..(centerline + 1) * length].to_vec();
    let positions = (0..length).map(|index| index as f64 + 0.5).collect();

    let relative_error_field = anti_bounce_back
        .iter()
        .zip(&analytic)
        .map(|(numerical, analytic)| (numerical - analytic) / amplitude)
        .collect();

    FieldComparison {
        length,
        amplitude,
        positions,
        profiles: vec![
            row(&analytic),
            row(&ftcs),
            row(&anti_bounce_back),
            row(&equilibrium),
        ],
        relative_error_field,
    }
}

/// 使用 Kuva 生成误差场、中心线误差与网格收敛数据图。
#[must_use]
pub fn render_comparison_svg(comparison: &FieldComparison, rows: &[ConvergenceRow]) -> String {
    let (error_plots, error_layout) = error_field_panel(comparison);
    let (centerline_plots, centerline_layout) = centerline_error_panel(comparison);
    let (convergence_plots, convergence_layout) = convergence_panel(rows);

    let scene = Figure::new(2, 2)
        .with_structure(vec![vec![0, 1], vec![2], vec![3]])
        .with_plots(vec![error_plots, centerline_plots, convergence_plots])
        .with_layouts(vec![error_layout, centerline_layout, convergence_layout])
        .with_labels_lowercase()
        .with_cell_size(430.0, 400.0)
        .with_row_height(0, 500.0)
        .render();
    let svg = SvgBackend.render_scene(&scene);
    let description = "二维方形域齐次 Dirichlet 扩散的有限差分与 D2Q9 LBM 对比。\
        子图 a 单独列在第一行，横纵坐标按一比一显示反弹跳边界下的相对误差场：\
        误差符号处处一致，峰值在区域中部，\
        壁面一圈反而最小，说明反弹跳没有产生边界层误差，残差来自体内截断误差；\
        子图 b 是同一物理时刻的中心线相对误差，反弹跳与有限差分衰减偏快而误差为负，\
        平衡覆盖把有效壁面推到格点外约零点六格距、衰减偏慢而误差为正且高一个量级；\
        子图 c 是扩散标度下的网格收敛，平衡覆盖为一阶，反弹跳为二阶，\
        松弛率为一时体内的九点四阶格式被二阶壁面拉低到三阶。";

    add_accessibility_metadata(svg, "二维扩散的有限差分与 D2Q9 LBM 对比", description)
}

/// 使用 Kuva 生成 D2Q5 与 D2Q9 当前实现的单线程吞吐量数据图。
#[must_use]
pub fn render_lattice_performance_svg(rows: &[LatticePerformanceRow], environment: &str) -> String {
    let throughput = |select: fn(&LatticePerformanceRow) -> f64| -> Vec<(f64, f64)> {
        rows.iter()
            .map(|row| (row.sites() as f64, select(row)))
            .collect()
    };
    let d2q5 = LinePlot::new()
        .with_data(throughput(LatticePerformanceRow::d2q5_mlups))
        .with_color("#2c7a4b")
        .with_stroke_width(2.0)
        .with_legend("D2Q5");
    let d2q9 = LinePlot::new()
        .with_data(throughput(LatticePerformanceRow::d2q9_mlups))
        .with_color("#a74428")
        .with_stroke_width(2.0)
        .with_legend("D2Q9");
    let plots = vec![Plot::Line(d2q5), Plot::Line(d2q9)];
    let layout = Layout::auto_from_plots(&plots)
        .with_title("单线程发布构建吞吐量")
        .with_x_label("格点总数 N²")
        .with_y_label("吞吐量（MLUPS）")
        .with_log_scale();
    let scene = Figure::new(1, 1)
        .with_plots(vec![plots])
        .with_layouts(vec![layout])
        .with_cell_size(760.0, 420.0)
        .render();
    let svg = SvgBackend.render_scene(&scene);
    let description = format!(
        "D2Q5 与 D2Q9 当前 Rust 实现的单线程二维扩散吞吐量，单位为 MLUPS。\
         每格点一组离散分布分别占 {D2Q5_DISTRIBUTION_BYTES_PER_SITE} 与 \
         {D2Q9_DISTRIBUTION_BYTES_PER_SITE} 字节；当前双缓冲工作存储分别占 \
         {D2Q5_WORKING_BYTES_PER_SITE} 与 {D2Q9_WORKING_BYTES_PER_SITE} 字节。{environment}"
    );
    add_accessibility_metadata(svg, "D2Q5 与 D2Q9 二维扩散性能对比", &description)
}

fn error_field_panel(comparison: &FieldComparison) -> (Vec<Plot>, Layout) {
    let length = comparison.length;
    let grid: Vec<Vec<f64>> = (0..length)
        .map(|row| comparison.relative_error_field[row * length..(row + 1) * length].to_vec())
        .collect();

    // 误差符号处处一致，因此用顺序色图而非发散色图：
    // 发散色图会暗示存在零交叉，与数据不符。
    let heatmap = Heatmap::new()
        .with_data(grid)
        .with_color_map(ColorMap::Cividis)
        .with_x_range(0.0, length as f64)
        .with_y_range(0.0, length as f64)
        .with_legend("相对误差");
    let plots = vec![Plot::Heatmap(heatmap)];
    let layout = Layout::auto_from_plots(&plots)
        .with_title("相对误差场（反弹跳，ω = 1.5，N = 64）")
        .with_x_label("格点坐标 x/Δx")
        .with_y_label("格点坐标 y/Δx")
        .with_equal_aspect();
    (plots, layout)
}

fn centerline_error_panel(comparison: &FieldComparison) -> (Vec<Plot>, Layout) {
    // 画误差而不是剖面：四条剖面在这个分辨率下逐点重合，剖面图不承载信息。
    // 误差图则同时给出空间形状、量级排序和符号——反弹跳与有限差分衰减偏快，
    // 平衡覆盖因有效壁面外移而衰减偏慢，两者分列零线两侧。
    let series = |values: &[f64]| -> Vec<(f64, f64)> {
        comparison
            .positions
            .iter()
            .copied()
            .zip(values.iter().copied())
            .collect()
    };

    let ftcs = LinePlot::new()
        .with_data(series(&comparison.relative_centerline_error(1)))
        .with_color("#59636f")
        .with_stroke_width(1.8)
        .with_line_style(LineStyle::Dashed)
        .with_legend("FTCS：r = 1/6");
    let anti_bounce_back = LinePlot::new()
        .with_data(series(&comparison.relative_centerline_error(2)))
        .with_color("#a74428")
        .with_stroke_width(2.0)
        .with_legend("LBM 反弹跳（ω = 1.5）");
    let equilibrium = LinePlot::new()
        .with_data(series(&comparison.relative_centerline_error(3)))
        .with_color("#2c7a4b")
        .with_stroke_width(1.8)
        .with_line_style(LineStyle::DashDot)
        .with_legend("LBM 平衡覆盖（ω = 1.5）");
    let plots = vec![
        Plot::Line(ftcs),
        Plot::Line(anti_bounce_back),
        Plot::Line(equilibrium),
    ];
    let layout = Layout::auto_from_plots(&plots)
        .with_title("中心线相对误差（N = 64）")
        .with_x_label("格点坐标 x/Δx")
        .with_y_label("相对误差");
    (plots, layout)
}

fn convergence_panel(rows: &[ConvergenceRow]) -> (Vec<Plot>, Layout) {
    let lengths: Vec<f64> = rows.iter().map(|row| row.length as f64).collect();
    let errors = |select: fn(&ConvergenceRow) -> f64| -> Vec<(f64, f64)> {
        rows.iter()
            .map(|row| (row.length as f64, select(row)))
            .collect()
    };
    // 三条参考线分别锚定相应曲线在最少格点数处的误差。一阶对应平衡覆盖，
    // 二阶对应反弹跳，三阶对应松弛率为一——它体内是九点四阶，被二阶壁面拉低。
    let reference = |exponent: i32, anchor: f64| -> Vec<(f64, f64)> {
        rows.first().map_or_else(Vec::new, |row| {
            let scale = anchor * (row.length as f64).powi(exponent);
            lengths
                .iter()
                .map(|length| (*length, scale / length.powi(exponent)))
                .collect()
        })
    };

    let ftcs = LinePlot::new()
        .with_data(errors(|row| row.error_ftcs))
        .with_color("#59636f")
        .with_stroke_width(1.8)
        .with_legend("FTCS：r = 1/6");
    let omega1 = ScatterPlot::new()
        .with_data(errors(|row| row.error_lbm_omega1))
        .with_color("#a74428")
        .with_size(5.0)
        .with_legend("LBM 反弹跳（ω = 1）");
    let omega1p5 = LinePlot::new()
        .with_data(errors(|row| row.error_lbm_omega1p5))
        .with_color("#2c7a4b")
        .with_stroke_width(1.8)
        .with_legend("LBM 反弹跳（ω = 1.5）");
    let equilibrium = LinePlot::new()
        .with_data(errors(|row| row.error_lbm_equilibrium))
        .with_color("#8a5fb0")
        .with_stroke_width(1.8)
        .with_legend("LBM 平衡覆盖（ω = 1.5）");

    let first_order = LinePlot::new()
        .with_data(reference(
            1,
            rows.first().map_or(0.0, |row| row.error_lbm_equilibrium),
        ))
        .with_color("#1f5a91")
        .with_stroke_width(1.2)
        .with_line_style(LineStyle::Dotted)
        .with_legend("一阶参考线");
    let second_order = LinePlot::new()
        .with_data(reference(
            2,
            rows.first().map_or(0.0, |row| row.error_lbm_omega1p5),
        ))
        .with_color("#1f5a91")
        .with_stroke_width(1.2)
        .with_line_style(LineStyle::Dashed)
        .with_legend("二阶参考线");
    let third_order = LinePlot::new()
        .with_data(reference(
            3,
            rows.first().map_or(0.0, |row| row.error_lbm_omega1),
        ))
        .with_color("#1f5a91")
        .with_stroke_width(1.2)
        .with_line_style(LineStyle::DashDot)
        .with_legend("三阶参考线");

    let plots = vec![
        Plot::Line(ftcs),
        Plot::Scatter(omega1),
        Plot::Line(omega1p5),
        Plot::Line(equilibrium),
        Plot::Line(first_order),
        Plot::Line(second_order),
        Plot::Line(third_order),
    ];
    let layout = Layout::auto_from_plots(&plots)
        .with_title("固定扩散标度的网格收敛（t/t_D = 1/48）")
        .with_x_label("格点数")
        .with_y_label("相对归一化 L2 误差")
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

    /// 测试用的格点数序列。代价随格点数四次方增长，测试止于 64。
    const TEST_LENGTHS: [usize; 3] = [16, 32, 64];

    fn assert_order(measured: f64, lower: f64, upper: f64, label: &str) {
        assert!(
            measured > lower && measured < upper,
            "{label} 实测阶 {measured:.3} 不在 [{lower}, {upper}] 内"
        );
    }

    #[test]
    fn omega_one_update_is_exactly_the_nine_point_stencil() {
        // 松弛率为一时后碰撞恰为 w_i phi，迁移后 phi(x, t+1) = sum_i w_i phi(x - c_i)。
        // 这个恒等式是「体内为九点四阶各向同性格式」这一结论的前提，直接验证。
        let length = 12;
        let mut initial = vec![0.0; length * length];
        for row in 0..length {
            for column in 0..length {
                let x = column as f64;
                let y = row as f64;
                initial[row * length + column] = (0.7 * x).sin() + (0.3 * y).cos() + 0.01 * x * y;
            }
        }

        let evolved = evolve(&initial, length, 1.0, Boundary::Periodic, 1);

        for row in 0..length {
            for column in 0..length {
                let expected: f64 = (0..D2Q9::Q)
                    .map(|direction| {
                        let velocity = D2Q9::VELOCITIES[direction];
                        let source_column = wrapped_upstream(column, velocity[0], length);
                        let source_row = wrapped_upstream(row, velocity[1], length);
                        D2Q9::WEIGHTS[direction] * initial[source_row * length + source_column]
                    })
                    .sum();
                let actual = evolved[row * length + column];
                assert!(
                    (actual - expected).abs() < 1.0e-14,
                    "格点 ({column}, {row}) 期望 {expected:.16e}，实得 {actual:.16e}"
                );
            }
        }
    }

    #[test]
    fn adiabatic_walls_conserve_the_total_scalar() {
        // 普通反弹固定的是通量而不是值，四壁绝热时零阶矩必须逐步守恒。
        // 把反弹与反弹跳的符号写反会立刻在这里失败。
        let length = 32;
        let initial = dirichlet_mode(length, 1.0);
        let total: f64 = initial.iter().sum();

        let evolved = evolve(&initial, length, 1.3, Boundary::Adiabatic, 300);
        let current: f64 = evolved.iter().sum();

        let drift = (current - total).abs() / total.abs();
        assert!(drift < 1.0e-12, "守恒漂移 {drift:.3e}");
    }

    #[test]
    fn dirichlet_convergence_orders_match_the_reconstruction_scheme() {
        let rows = convergence_study(&TEST_LENGTHS);

        for pair in rows.windows(2) {
            assert_order(
                convergence_order(pair[0].error_ftcs, pair[1].error_ftcs),
                1.9,
                2.1,
                "FTCS",
            );
            assert_order(
                convergence_order(pair[0].error_lbm_omega1p5, pair[1].error_lbm_omega1p5),
                1.9,
                2.15,
                "反弹跳（ω = 1.5）",
            );
            // 体内四阶配二阶壁面在 L2 中混出三阶。该阶数只有实测依据，无推导。
            assert_order(
                convergence_order(pair[0].error_lbm_omega1, pair[1].error_lbm_omega1),
                2.8,
                3.15,
                "反弹跳（ω = 1）",
            );
            // 平衡覆盖的有效壁面位置偏离半格距，域长相对误差 O(dx/L) 传到衰减率。
            assert_order(
                convergence_order(pair[0].error_lbm_equilibrium, pair[1].error_lbm_equilibrium),
                0.85,
                1.15,
                "平衡覆盖（ω = 1.5）",
            );
        }
    }

    #[test]
    fn periodic_bulk_orders_match_the_truncation_analysis() {
        // 周期区域没有壁面，测到的是格式本身的精度。
        // 二维 FTCS 的截断误差含 r * d_x^2 d_y^2 项，五点空间误差无对应项，
        // 任何扩散数都消不掉，故为二阶——一维的 r = 1/6 魔数在二维不存在。
        // 松弛率为一的 D2Q9 则把整个 nabla^4 项精确抵消，故为四阶。
        let rows = bulk_order_study(&TEST_LENGTHS);

        for pair in rows.windows(2) {
            assert_order(
                convergence_order(pair[0].error_ftcs, pair[1].error_ftcs),
                1.9,
                2.1,
                "周期 FTCS",
            );
            assert_order(
                convergence_order(pair[0].error_lbm_omega1, pair[1].error_lbm_omega1),
                3.85,
                4.15,
                "周期 LBM（ω = 1）",
            );
        }
    }

    #[test]
    fn measured_diffusivity_is_isotropic_across_orientations() {
        // 三个波矢模长相同（波数平方均为二十五），差异因此只反映取向。
        let rows = isotropy_study(64, 1.5, 400, &[[5, 0], [4, 3], [3, 4]]);
        let axial = rows[0].measured_diffusivity;
        let oblique = rows[1].measured_diffusivity;
        let mirrored = rows[2].measured_diffusivity;

        // 交换两个分量是格子的精确对称性，结果必须逐位一致。
        assert!(
            (oblique - mirrored).abs() < 1.0e-12,
            "(4,3) 与 (3,4) 相差 {:.3e}",
            (oblique - mirrored).abs()
        );

        // 取向差远小于同一模长下共同的 k^4 离散偏差。
        let diffusivity = lattice_diffusivity(1.5);
        let spread = (axial - oblique).abs() / diffusivity;
        assert!(spread < 2.0e-3, "轴向与斜向的扩散系数相差 {spread:.3e} 倍");
    }

    #[test]
    fn rendered_data_plot_preserves_semantics_and_accessibility() {
        let comparison = field_comparison();
        let rows = convergence_study(&[16, 32]);
        let svg = render_comparison_svg(&comparison, &rows);

        for expected in [
            "<title id=\"plot-title\">二维扩散的有限差分与 D2Q9 LBM 对比</title>",
            "<desc id=\"plot-description\">",
            "role=\"img\"",
            "aria-labelledby=\"plot-title plot-description\"",
            "相对误差",
            "FTCS：r = 1/6",
            "LBM 反弹跳（ω = 1.5）",
            "LBM 平衡覆盖（ω = 1.5）",
            "一阶参考线",
            "二阶参考线",
            "三阶参考线",
        ] {
            assert!(svg.contains(expected), "missing SVG semantic: {expected}");
        }
    }
}
