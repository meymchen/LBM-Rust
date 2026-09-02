//! 一维三速（D1Q3）离散速度模型与标量扩散平衡分布。

/// 一维三速（D1Q3）离散速度模型。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct D1Q3;

impl D1Q3 {
    /// 离散速度的数量。
    pub const Q: usize = 3;

    /// 离散速度，顺序为静止、正向和负向速度。
    pub const VELOCITIES: [i8; Self::Q] = [0, 1, -1];

    /// 与 [`Self::VELOCITIES`] 一一对应的格子权重。
    pub const WEIGHTS: [f64; Self::Q] = [2.0 / 3.0, 1.0 / 6.0, 1.0 / 6.0];

    /// 格子声速的平方。
    pub const SPEED_OF_SOUND_SQUARED: f64 = 1.0 / 3.0;
}

/// 计算 D1Q3 的标量扩散平衡分布，即各方向分布等于权重乘以标量。
///
/// `scalar` 是格点上的扩散标量（浓度或温度）。扩散模型只守恒零阶矩，
/// 平衡分布不携带通量；扩散通量完全由非平衡一阶矩给出。
#[must_use]
#[inline]
pub fn diffusion_equilibrium(scalar: f64) -> [f64; D1Q3::Q] {
    D1Q3::WEIGHTS.map(|weight| weight * scalar)
}

#[cfg(test)]
mod tests {
    use super::{D1Q3, diffusion_equilibrium};

    const TOLERANCE: f64 = 1.0e-12;

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < TOLERANCE,
            "expected {expected:.16e}, got {actual:.16e}"
        );
    }

    #[test]
    fn weights_form_a_normalized_symmetric_lattice() {
        assert_close(D1Q3::WEIGHTS.iter().sum(), 1.0);
        assert_eq!(D1Q3::VELOCITIES[1], -D1Q3::VELOCITIES[2]);
        assert_close(D1Q3::WEIGHTS[1], D1Q3::WEIGHTS[2]);
    }

    #[test]
    fn diffusion_equilibrium_recovers_scalar_moments() {
        let scalar = 1.31;
        let distributions = diffusion_equilibrium(scalar);

        assert_close(distributions.iter().sum(), scalar);

        let first_moment: f64 = distributions
            .iter()
            .zip(D1Q3::VELOCITIES)
            .map(|(distribution, velocity)| distribution * f64::from(velocity))
            .sum();
        assert_close(first_moment, 0.0);

        let second_moment: f64 = distributions
            .iter()
            .zip(D1Q3::VELOCITIES)
            .map(|(distribution, velocity)| {
                distribution * f64::from(velocity) * f64::from(velocity)
            })
            .sum();
        assert_close(second_moment, D1Q3::SPEED_OF_SOUND_SQUARED * scalar);
    }
}
