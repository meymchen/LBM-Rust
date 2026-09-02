//! D2Q9 数据布局的公共接口回归测试。

#![allow(clippy::cast_precision_loss)]

use d2q9_diffusion::{
    Boundary, D2q9BlockedSolver, D2q9LayoutPerformanceRow, D2q9SoaSolver, D2q9Solver,
    Reconstruction, dirichlet_mode, render_d2q9_layout_performance_svg,
};

#[test]
fn optimized_layouts_are_bitwise_identical_to_the_aos_baseline() {
    let length = 7;
    let initial = dirichlet_mode(length, 1.0);
    let boundaries = [
        Boundary::Periodic,
        Boundary::Adiabatic,
        Boundary::Dirichlet {
            scalar: 0.0,
            reconstruction: Reconstruction::AntiBounceBack,
        },
        Boundary::Dirichlet {
            scalar: 0.0,
            reconstruction: Reconstruction::Equilibrium,
        },
    ];

    for boundary in boundaries {
        let mut aos = D2q9Solver::from_scalar(&initial, length, 1.3, boundary);
        let mut soa = D2q9SoaSolver::from_scalar(&initial, length, 1.3, boundary);
        let mut blocked = D2q9BlockedSolver::from_scalar(&initial, length, 1.3, boundary);

        for step in 1..=9 {
            aos.step();
            soa.step();
            blocked.step();

            let baseline = aos.scalar();
            assert_eq!(soa.scalar(), baseline, "SoA 在第 {step} 步改变了 IEEE 结果");
            assert_eq!(
                blocked.scalar(),
                baseline,
                "分块布局在第 {step} 步改变了 IEEE 结果"
            );
        }
    }
}

fn assert_layouts_match(
    initial: &[f64],
    length: usize,
    omega: f64,
    boundary: Boundary,
    steps: usize,
) {
    let mut aos = D2q9Solver::from_scalar(initial, length, omega, boundary);
    let mut soa = D2q9SoaSolver::from_scalar(initial, length, omega, boundary);
    let mut blocked = D2q9BlockedSolver::from_scalar(initial, length, omega, boundary);
    for _ in 0..steps {
        aos.step();
        soa.step();
        blocked.step();
    }
    let baseline = aos.scalar();
    assert_eq!(soa.scalar(), baseline, "SoA 改变了 #2 回归结果");
    assert_eq!(blocked.scalar(), baseline, "分块布局改变了 #2 回归结果");
}

#[test]
fn optimized_layouts_pass_all_numerical_workloads_from_issue_two() {
    let initial = dirichlet_mode(32, 1.0);
    assert_layouts_match(&initial, 32, 1.3, Boundary::Adiabatic, 300);

    for length in [16, 32, 64] {
        let initial = dirichlet_mode(length, 1.0);
        let steps = length * length / 8;
        assert_layouts_match(
            &initial,
            length,
            1.0,
            Boundary::Dirichlet {
                scalar: 0.0,
                reconstruction: Reconstruction::AntiBounceBack,
            },
            steps,
        );
        for reconstruction in [Reconstruction::AntiBounceBack, Reconstruction::Equilibrium] {
            assert_layouts_match(
                &initial,
                length,
                1.5,
                Boundary::Dirichlet {
                    scalar: 0.0,
                    reconstruction,
                },
                3 * steps,
            );
        }

        let periodic = d2q9_diffusion::periodic_mode(length, 1.0);
        assert_layouts_match(&periodic, length, 1.0, Boundary::Periodic, steps);
    }

    let length = 64;
    let unit = 2.0 * std::f64::consts::PI / length as f64;
    for wave_vector in [[5, 0], [4, 3], [3, 4]] {
        let initial: Vec<_> = (0..length)
            .flat_map(|row| {
                (0..length).map(move |column| {
                    let phase = unit
                        * (f64::from(wave_vector[0]) * column as f64
                            + f64::from(wave_vector[1]) * row as f64);
                    phase.sin()
                })
            })
            .collect();
        assert_layouts_match(&initial, length, 1.5, Boundary::Periodic, 400);
    }
}

#[test]
fn layout_performance_report_exposes_throughput_and_speedup() {
    let row = D2q9LayoutPerformanceRow {
        length: 64,
        steps: 100,
        samples: 9,
        aos_nanoseconds_per_site_step: 10.0,
        aos_mad_nanoseconds_per_site_step: 0.2,
        soa_nanoseconds_per_site_step: 5.0,
        soa_mad_nanoseconds_per_site_step: 0.1,
        blocked_nanoseconds_per_site_step: 4.0,
        blocked_mad_nanoseconds_per_site_step: 0.1,
    };

    assert_eq!(row.sites(), 4096);
    assert!((row.aos_mlups() - 100.0).abs() < f64::EPSILON);
    assert!((row.soa_mlups() - 200.0).abs() < f64::EPSILON);
    assert!((row.blocked_mlups() - 250.0).abs() < f64::EPSILON);
    assert!((row.soa_speedup_over_aos() - 2.0).abs() < f64::EPSILON);
    assert!((row.blocked_speedup_over_aos() - 2.5).abs() < f64::EPSILON);

    let svg = render_d2q9_layout_performance_svg(&[row], "测试硬件与工具链");
    for expected in [
        "<title id=\"plot-title\">D2Q9 数据布局性能对比</title>",
        "AoS",
        "SoA",
        "分块",
        "MLUPS",
        "测试硬件与工具链",
    ] {
        assert!(svg.contains(expected), "missing SVG semantic: {expected}");
    }
}
