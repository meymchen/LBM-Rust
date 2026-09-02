//! D2Q5 离散速度模型的公共接口回归测试。

use lbm_core::{
    D2Q5,
    d2q5::{OPPOSITE, diffusion_equilibrium},
};

const TOLERANCE: f64 = 1.0e-12;

fn assert_close(actual: f64, expected: f64) {
    assert!(
        (actual - expected).abs() < TOLERANCE,
        "expected {expected:.16e}, got {actual:.16e}"
    );
}

#[test]
fn d2q5_recovers_the_required_diffusion_moments() {
    let scalar = 1.31;
    let distributions = diffusion_equilibrium(scalar);

    assert_close(D2Q5::WEIGHTS.iter().sum(), 1.0);
    assert_close(distributions.iter().sum(), scalar);

    for (index, opposite) in OPPOSITE.iter().copied().enumerate() {
        assert_eq!(
            D2Q5::VELOCITIES[index],
            D2Q5::VELOCITIES[opposite].map(|component| -component)
        );
        assert_close(D2Q5::WEIGHTS[index], D2Q5::WEIGHTS[opposite]);
    }

    for row in 0..2 {
        for column in 0..2 {
            let moment: f64 = distributions
                .iter()
                .zip(D2Q5::VELOCITIES)
                .map(|(distribution, velocity)| {
                    distribution * f64::from(velocity[row]) * f64::from(velocity[column])
                })
                .sum();
            let expected = if row == column {
                D2Q5::SPEED_OF_SOUND_SQUARED * scalar
            } else {
                0.0
            };
            assert_close(moment, expected);
        }
    }
}
