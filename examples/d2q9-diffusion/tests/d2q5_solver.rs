//! D2Q5 二维扩散求解器的公共接口回归测试。

#![allow(clippy::cast_precision_loss)]

use d2q9_diffusion::{
    Boundary, D2Q5_DISTRIBUTION_BYTES_PER_SITE, D2Q5_WORKING_BYTES_PER_SITE,
    D2Q9_DISTRIBUTION_BYTES_PER_SITE, D2Q9_WORKING_BYTES_PER_SITE, D2q5Solver,
    LatticePerformanceRow, Reconstruction, convergence_order, dirichlet_amplitude, dirichlet_mode,
    lattice_diffusivity, relative_l2, render_lattice_performance_svg,
};
use lbm_core::D2Q5;

const ISOTROPY_STEPS: usize = 400;

fn evolve(
    initial: &[f64],
    length: usize,
    omega: f64,
    boundary: Boundary,
    steps: usize,
) -> Vec<f64> {
    let mut solver = D2q5Solver::from_scalar(initial, length, omega, boundary);
    for _ in 0..steps {
        solver.step();
    }
    solver.scalar()
}

#[test]
fn omega_one_update_matches_the_d2q5_stencil() {
    let length = 12;
    let mut initial = vec![0.0; length * length];
    for row in 0..length {
        for column in 0..length {
            let x = column as f64;
            let y = row as f64;
            initial[row * length + column] = (0.7 * x).sin() + (0.3 * y).cos() + 0.01 * x * y;
        }
    }

    let mut solver = D2q5Solver::from_scalar(&initial, length, 1.0, Boundary::Periodic);
    solver.step();
    let evolved = solver.scalar();

    for row in 0..length {
        for column in 0..length {
            let expected: f64 = D2Q5::VELOCITIES
                .iter()
                .zip(D2Q5::WEIGHTS)
                .map(|(velocity, weight)| {
                    let source_column =
                        (column + length).wrapping_add_signed(-isize::from(velocity[0])) % length;
                    let source_row =
                        (row + length).wrapping_add_signed(-isize::from(velocity[1])) % length;
                    weight * initial[source_row * length + source_column]
                })
                .sum();
            let actual = evolved[row * length + column];
            assert!(
                (actual - expected).abs() < 1.0e-14,
                "格点（{column}，{row}）期望 {expected:.16e}，实得 {actual:.16e}"
            );
        }
    }
}

#[test]
fn adiabatic_walls_conserve_the_total_scalar() {
    let length = 32;
    let initial = dirichlet_mode(length, 1.0);
    let total: f64 = initial.iter().sum();

    let evolved = evolve(&initial, length, 1.3, Boundary::Adiabatic, 300);
    let current: f64 = evolved.iter().sum();
    let drift = (current - total).abs() / total.abs();

    assert!(drift < 1.0e-12, "守恒漂移 {drift:.3e}");
}

#[test]
fn dirichlet_solution_converges_at_second_order() {
    let errors: Vec<_> = [16, 32, 64]
        .into_iter()
        .map(|length| {
            let initial = dirichlet_mode(length, 1.0);
            let steps = 3 * length * length / 8;
            let diffusivity = lattice_diffusivity(1.5);
            let amplitude = dirichlet_amplitude(length, diffusivity, steps);
            let analytic = dirichlet_mode(length, amplitude);
            let numerical = evolve(
                &initial,
                length,
                1.5,
                Boundary::Dirichlet {
                    scalar: 0.0,
                    reconstruction: Reconstruction::AntiBounceBack,
                },
                steps,
            );
            relative_l2(&numerical, &analytic, amplitude)
        })
        .collect();

    for pair in errors.windows(2) {
        let order = convergence_order(pair[0], pair[1]);
        assert!(
            order > 1.9 && order < 2.15,
            "D2Q5 反弹跳实测阶 {order:.3} 不在 [1.9，2.15] 内"
        );
    }
}

fn measured_diffusivity(length: usize, wave_vector: [i32; 2]) -> f64 {
    let unit = 2.0 * std::f64::consts::PI / length as f64;
    let phase = |column: usize, row: usize| {
        unit * (f64::from(wave_vector[0]) * column as f64 + f64::from(wave_vector[1]) * row as f64)
    };
    let initial: Vec<_> = (0..length)
        .flat_map(|row| (0..length).map(move |column| phase(column, row).sin()))
        .collect();
    let evolved = evolve(&initial, length, 1.5, Boundary::Periodic, ISOTROPY_STEPS);
    let projection: f64 = evolved
        .iter()
        .enumerate()
        .map(|(site, scalar)| scalar * phase(site % length, site / length).sin())
        .sum();
    let amplitude = 2.0 * projection / (length * length) as f64;
    let wave_squared =
        (unit * f64::from(wave_vector[0])).powi(2) + (unit * f64::from(wave_vector[1])).powi(2);
    -amplitude.ln() / 400.0 / wave_squared
}

#[test]
fn measured_diffusivity_is_isotropic_across_orientations() {
    let axial = measured_diffusivity(64, [5, 0]);
    let oblique = measured_diffusivity(64, [4, 3]);
    let mirrored = measured_diffusivity(64, [3, 4]);

    assert!(
        (oblique - mirrored).abs() < 1.0e-12,
        "（4，3）与（3，4）相差 {:.3e}",
        (oblique - mirrored).abs()
    );

    let spread = (axial - oblique).abs() / lattice_diffusivity(1.5);
    assert!(spread < 2.0e-2, "轴向与斜向的扩散系数相差 {spread:.3e} 倍");
}

#[test]
fn performance_report_exposes_storage_and_throughput() {
    assert_eq!(D2Q5_DISTRIBUTION_BYTES_PER_SITE, 40);
    assert_eq!(D2Q9_DISTRIBUTION_BYTES_PER_SITE, 72);
    assert_eq!(D2Q5_WORKING_BYTES_PER_SITE, 80);
    assert_eq!(D2Q9_WORKING_BYTES_PER_SITE, 144);

    let row = LatticePerformanceRow {
        length: 64,
        steps: 100,
        samples: 9,
        d2q5_nanoseconds_per_site_step: 4.0,
        d2q5_mad_nanoseconds_per_site_step: 0.1,
        d2q9_nanoseconds_per_site_step: 10.0,
        d2q9_mad_nanoseconds_per_site_step: 0.2,
    };

    assert_eq!(row.sites(), 4096);
    assert!((row.d2q5_mlups() - 250.0).abs() < f64::EPSILON);
    assert!((row.d2q9_mlups() - 100.0).abs() < f64::EPSILON);
    assert!((row.d2q5_speedup_over_d2q9() - 2.5).abs() < f64::EPSILON);
}

#[test]
fn performance_plot_preserves_semantics_and_storage_context() {
    let rows = [LatticePerformanceRow {
        length: 64,
        steps: 100,
        samples: 9,
        d2q5_nanoseconds_per_site_step: 4.0,
        d2q5_mad_nanoseconds_per_site_step: 0.1,
        d2q9_nanoseconds_per_site_step: 10.0,
        d2q9_mad_nanoseconds_per_site_step: 0.2,
    }];
    let svg = render_lattice_performance_svg(&rows, "测试硬件与工具链");

    for expected in [
        "<title id=\"plot-title\">D2Q5 与 D2Q9 二维扩散性能对比</title>",
        "<desc id=\"plot-description\">",
        "role=\"img\"",
        "D2Q5",
        "D2Q9",
        "MLUPS",
        "双缓冲",
        "测试硬件与工具链",
    ] {
        assert!(svg.contains(expected), "missing SVG semantic: {expected}");
    }
}
