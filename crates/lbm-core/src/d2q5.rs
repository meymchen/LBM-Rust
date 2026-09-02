//! 二维五速（D2Q5）离散速度模型与标量扩散平衡分布。

/// 二维五速（D2Q5）离散速度模型。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct D2Q5;

impl D2Q5 {
    /// 离散速度的数量。
    pub const Q: usize = 5;

    /// 离散速度，顺序为静止、东、北、西、南。
    pub const VELOCITIES: [[i8; 2]; Self::Q] = [[0, 0], [1, 0], [0, 1], [-1, 0], [0, -1]];

    /// 与 [`Self::VELOCITIES`] 一一对应的格子权重。
    pub const WEIGHTS: [f64; Self::Q] = [1.0 / 3.0, 1.0 / 6.0, 1.0 / 6.0, 1.0 / 6.0, 1.0 / 6.0];

    /// 格子声速的平方。
    pub const SPEED_OF_SOUND_SQUARED: f64 = 1.0 / 3.0;
}

/// 与 [`D2Q5::VELOCITIES`] 一一对应的反向离散速度索引，即 `c[OPPOSITE[i]] == -c[i]`。
pub const OPPOSITE: [usize; D2Q5::Q] = [0, 3, 4, 1, 2];

/// 计算 D2Q5 的标量扩散平衡分布，即各方向分布等于权重乘以标量。
///
/// `scalar` 是格点上的扩散标量（浓度或温度）。
#[must_use]
#[inline]
pub fn diffusion_equilibrium(scalar: f64) -> [f64; D2Q5::Q] {
    D2Q5::WEIGHTS.map(|weight| weight * scalar)
}
