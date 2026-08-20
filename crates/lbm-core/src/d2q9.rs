/// 二维九速（D2Q9）离散速度模型。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct D2Q9;

impl D2Q9 {
    /// 离散速度的数量。
    pub const Q: usize = 9;

    /// 离散速度，顺序为静止、轴向和对角速度。
    pub const VELOCITIES: [[i8; 2]; Self::Q] = [
        [0, 0],
        [1, 0],
        [0, 1],
        [-1, 0],
        [0, -1],
        [1, 1],
        [-1, 1],
        [-1, -1],
        [1, -1],
    ];

    /// 与 [`Self::VELOCITIES`] 一一对应的格子权重。
    pub const WEIGHTS: [f64; Self::Q] = [
        4.0 / 9.0,
        1.0 / 9.0,
        1.0 / 9.0,
        1.0 / 9.0,
        1.0 / 9.0,
        1.0 / 36.0,
        1.0 / 36.0,
        1.0 / 36.0,
        1.0 / 36.0,
    ];

    /// 格子声速的平方。
    pub const SPEED_OF_SOUND_SQUARED: f64 = 1.0 / 3.0;
}

/// 计算 D2Q9 的二阶低马赫数平衡分布。
///
/// `density` 是密度，`velocity` 是格子单位下的二维宏观速度。
/// 返回值使用固定长度数组，计算过程不进行堆分配，可作为并行化与向量化实现的标量基线。
#[must_use]
#[inline]
pub fn equilibrium(density: f64, velocity: [f64; 2]) -> [f64; D2Q9::Q] {
    let velocity_squared = velocity[0].mul_add(velocity[0], velocity[1] * velocity[1]);

    std::array::from_fn(|index| {
        let discrete_velocity = D2Q9::VELOCITIES[index];
        let direction_dot_velocity = f64::from(discrete_velocity[0])
            .mul_add(velocity[0], f64::from(discrete_velocity[1]) * velocity[1]);

        D2Q9::WEIGHTS[index]
            * density
            * (1.0 + 3.0 * direction_dot_velocity + 4.5 * direction_dot_velocity.powi(2)
                - 1.5 * velocity_squared)
    })
}

#[cfg(test)]
mod tests {
    use super::{D2Q9, equilibrium};

    const TOLERANCE: f64 = 1.0e-12;

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < TOLERANCE,
            "expected {expected:.16e}, got {actual:.16e}"
        );
    }

    #[test]
    fn weights_form_a_normalized_symmetric_lattice() {
        assert_close(D2Q9::WEIGHTS.iter().sum(), 1.0);

        for (left, right) in [(1, 3), (2, 4), (5, 7), (6, 8)] {
            assert_eq!(
                D2Q9::VELOCITIES[left],
                D2Q9::VELOCITIES[right].map(|component| -component)
            );
            assert_close(D2Q9::WEIGHTS[left], D2Q9::WEIGHTS[right]);
        }
    }

    #[test]
    fn equilibrium_recovers_density_and_momentum() {
        let density = 1.17;
        let velocity = [0.08, -0.03];
        let distributions = equilibrium(density, velocity);

        assert_close(distributions.iter().sum(), density);

        for (axis, expected_velocity) in velocity.iter().enumerate() {
            let momentum: f64 = distributions
                .iter()
                .zip(D2Q9::VELOCITIES)
                .map(|(distribution, velocity)| distribution * f64::from(velocity[axis]))
                .sum();
            assert_close(momentum, density * expected_velocity);
        }
    }

    #[test]
    fn equilibrium_at_rest_is_isotropic() {
        let density = 0.93;
        let distributions = equilibrium(density, [0.0, 0.0]);

        for (distribution, weight) in distributions.iter().zip(D2Q9::WEIGHTS) {
            assert_close(*distribution, density * weight);
        }
    }
}
