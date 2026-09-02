//! 二维九速（D2Q9）离散速度模型、标量扩散平衡分布与流动平衡分布。

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

/// 与 [`D2Q9::VELOCITIES`] 一一对应的反向离散速度索引，即 `c[OPPOSITE[i]] == -c[i]`。
///
/// 反弹与反弹跳等按连接（link-wise）的边界重构需要成对访问出射与入射分布。
pub const OPPOSITE: [usize; D2Q9::Q] = [0, 3, 4, 1, 2, 7, 8, 5, 6];

/// 计算 D2Q9 的标量扩散平衡分布，即各方向分布等于权重乘以标量。
///
/// `scalar` 是格点上的扩散标量（浓度或温度）。扩散模型只守恒零阶矩，
/// 平衡分布不携带通量；扩散通量完全由非平衡一阶矩给出。
#[must_use]
#[inline]
pub fn diffusion_equilibrium(scalar: f64) -> [f64; D2Q9::Q] {
    D2Q9::WEIGHTS.map(|weight| weight * scalar)
}

/// 计算 D2Q9 的二阶低马赫数流动平衡分布。
///
/// `density` 是密度，`velocity` 是格子单位下的二维宏观速度。
/// 返回值使用固定长度数组，计算过程不进行堆分配，可作为并行化与向量化实现的标量基线。
#[must_use]
#[inline]
pub fn flow_equilibrium(density: f64, velocity: [f64; 2]) -> [f64; D2Q9::Q] {
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
    use super::{D2Q9, OPPOSITE, diffusion_equilibrium, flow_equilibrium};

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
    fn opposite_indices_reverse_every_discrete_velocity() {
        for (index, opposite) in OPPOSITE.iter().enumerate() {
            assert_eq!(
                D2Q9::VELOCITIES[index],
                D2Q9::VELOCITIES[*opposite].map(|component| -component)
            );
            assert_eq!(OPPOSITE[*opposite], index);
        }
    }

    #[test]
    fn diffusion_equilibrium_recovers_scalar_moments() {
        let scalar = 1.31;
        let distributions = diffusion_equilibrium(scalar);

        assert_close(distributions.iter().sum(), scalar);

        for axis in 0..2 {
            let first_moment: f64 = distributions
                .iter()
                .zip(D2Q9::VELOCITIES)
                .map(|(distribution, velocity)| distribution * f64::from(velocity[axis]))
                .sum();
            assert_close(first_moment, 0.0);
        }

        // 二阶矩必须是各向同性的 c_s^2 phi delta_(alpha beta)，
        // 否则 Chapman-Enskog 展开给不出各向同性的扩散系数。
        for row in 0..2 {
            for column in 0..2 {
                let second_moment: f64 = distributions
                    .iter()
                    .zip(D2Q9::VELOCITIES)
                    .map(|(distribution, velocity)| {
                        distribution * f64::from(velocity[row]) * f64::from(velocity[column])
                    })
                    .sum();
                let expected = if row == column {
                    D2Q9::SPEED_OF_SOUND_SQUARED * scalar
                } else {
                    0.0
                };
                assert_close(second_moment, expected);
            }
        }
    }

    #[test]
    fn flow_equilibrium_recovers_density_and_momentum() {
        let density = 1.17;
        let velocity = [0.08, -0.03];
        let distributions = flow_equilibrium(density, velocity);

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
    fn flow_equilibrium_at_rest_is_isotropic() {
        let density = 0.93;
        let distributions = flow_equilibrium(density, [0.0, 0.0]);

        for (distribution, weight) in distributions.iter().zip(D2Q9::WEIGHTS) {
            assert_close(*distribution, density * weight);
        }
    }
}
