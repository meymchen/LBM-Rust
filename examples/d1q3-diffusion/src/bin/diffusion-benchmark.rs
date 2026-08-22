//! 比较一维 FTCS 与 D1Q3 LBM 当前实现的单线程发布构建性能。

use std::{
    env, fs,
    hint::black_box,
    io::{self, Write},
    path::{Path, PathBuf},
    process::Command,
    time::{Duration, Instant},
};

use d1q3_diffusion::{
    AMPLITUDE, BACKGROUND, D1q3Solver, FtcsSolver, PerformanceRow, lattice_diffusivity,
    render_performance_svg, sine_mode,
};

const LENGTHS: [usize; 4] = [1_024, 16_384, 262_144, 1_048_576];
const MINIMUM_SITE_UPDATES: usize = 16 * 1024 * 1024;
const MINIMUM_STEPS: usize = 16;
const WARMUP_SAMPLES: usize = 2;
const MEASURED_SAMPLES: usize = 9;

fn main() -> io::Result<()> {
    let output_directory = env::args_os().nth(1).map_or_else(
        || PathBuf::from(".scratch/d1q3-diffusion-benchmark"),
        PathBuf::from,
    );
    fs::create_dir_all(&output_directory)?;

    let rows: Vec<_> = LENGTHS.iter().copied().map(benchmark_length).collect();
    let environment = environment_summary();
    write_csv(
        &output_directory.join("d1q3-diffusion-performance.csv"),
        &rows,
    )?;
    fs::write(
        output_directory.join("d1q3-diffusion-performance.svg"),
        render_performance_svg(&rows, &environment),
    )?;
    write_metadata(
        &output_directory.join("d1q3-diffusion-performance.toml"),
        &environment,
    )?;

    println!("{environment}");
    println!("N,steps,FTCS MLUPS,D1Q3 LBM MLUPS,FTCS speedup");
    for row in &rows {
        println!(
            "{},{},{:.3},{:.3},{:.3}",
            row.length,
            row.steps,
            row.ftcs_mlups(),
            row.lbm_mlups(),
            row.ftcs_speedup_over_lbm(),
        );
    }
    println!("输出目录：{}", output_directory.display());
    Ok(())
}

fn benchmark_length(length: usize) -> PerformanceRow {
    let steps = MINIMUM_STEPS.max(MINIMUM_SITE_UPDATES.div_ceil(length));
    let initial = sine_mode(length, BACKGROUND, AMPLITUDE);
    let diffusion_number = lattice_diffusivity(1.0);

    for _ in 0..WARMUP_SAMPLES {
        black_box(time_ftcs(&initial, diffusion_number, steps));
        black_box(time_lbm(&initial, steps));
    }

    let mut ftcs = Vec::with_capacity(MEASURED_SAMPLES);
    let mut lbm = Vec::with_capacity(MEASURED_SAMPLES);
    for sample in 0..MEASURED_SAMPLES {
        if sample % 2 == 0 {
            ftcs.push(time_ftcs(&initial, diffusion_number, steps));
            lbm.push(time_lbm(&initial, steps));
        } else {
            lbm.push(time_lbm(&initial, steps));
            ftcs.push(time_ftcs(&initial, diffusion_number, steps));
        }
    }

    let site_steps = f64::from(
        u32::try_from(length * steps).expect("benchmark site-step count must fit in u32"),
    );
    let ftcs_per_site_step: Vec<_> = ftcs
        .into_iter()
        .map(|duration| duration.as_secs_f64() * 1.0e9 / site_steps)
        .collect();
    let lbm_per_site_step: Vec<_> = lbm
        .into_iter()
        .map(|duration| duration.as_secs_f64() * 1.0e9 / site_steps)
        .collect();
    let ftcs_median = median(&ftcs_per_site_step);
    let lbm_median = median(&lbm_per_site_step);

    PerformanceRow {
        length,
        steps,
        samples: MEASURED_SAMPLES,
        ftcs_nanoseconds_per_site_step: ftcs_median,
        ftcs_mad_nanoseconds_per_site_step: median_absolute_deviation(
            &ftcs_per_site_step,
            ftcs_median,
        ),
        lbm_nanoseconds_per_site_step: lbm_median,
        lbm_mad_nanoseconds_per_site_step: median_absolute_deviation(
            &lbm_per_site_step,
            lbm_median,
        ),
    }
}

fn time_ftcs(initial: &[f64], diffusion_number: f64, steps: usize) -> Duration {
    let mut solver = FtcsSolver::new(initial.to_vec(), diffusion_number);
    let start = Instant::now();
    for _ in 0..steps {
        solver.step();
    }
    let elapsed = start.elapsed();
    black_box(solver.phi());
    elapsed
}

fn time_lbm(initial: &[f64], steps: usize) -> Duration {
    let mut solver = D1q3Solver::from_scalar(initial, 1.0);
    let start = Instant::now();
    for _ in 0..steps {
        solver.step();
    }
    let elapsed = start.elapsed();
    black_box(solver.scalar());
    elapsed
}

fn median(values: &[f64]) -> f64 {
    let mut ordered = values.to_vec();
    ordered.sort_by(f64::total_cmp);
    ordered[ordered.len() / 2]
}

fn median_absolute_deviation(values: &[f64], center: f64) -> f64 {
    let deviations: Vec<_> = values.iter().map(|value| (value - center).abs()).collect();
    median(&deviations)
}

fn write_csv(path: &Path, rows: &[PerformanceRow]) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);
    writeln!(
        output,
        "n,steps,samples,ftcs_ns_per_site_step,ftcs_mad_ns_per_site_step,lbm_ns_per_site_step,lbm_mad_ns_per_site_step,ftcs_mlups,lbm_mlups,ftcs_speedup"
    )?;
    for row in rows {
        writeln!(
            output,
            "{},{},{},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6}",
            row.length,
            row.steps,
            row.samples,
            row.ftcs_nanoseconds_per_site_step,
            row.ftcs_mad_nanoseconds_per_site_step,
            row.lbm_nanoseconds_per_site_step,
            row.lbm_mad_nanoseconds_per_site_step,
            row.ftcs_mlups(),
            row.lbm_mlups(),
            row.ftcs_speedup_over_lbm(),
        )?;
    }
    Ok(())
}

fn write_metadata(path: &Path, environment: &str) -> io::Result<()> {
    let source_revision = command_output("git", &["rev-parse", "HEAD"]);
    let source_status = command_output("git", &["status", "--porcelain"]);
    let mut output = io::BufWriter::new(fs::File::create(path)?);
    writeln!(output, "schema_version = 1")?;
    writeln!(
        output,
        "command = \"cargo run --release --quiet -p d1q3-diffusion --bin diffusion-benchmark -- <output-directory>\""
    )?;
    writeln!(output, "profile = \"release\"")?;
    writeln!(output, "threads = 1")?;
    writeln!(output, "warmup_samples = {WARMUP_SAMPLES}")?;
    writeln!(output, "measured_samples = {MEASURED_SAMPLES}")?;
    writeln!(
        output,
        "minimum_site_updates_per_sample = {MINIMUM_SITE_UPDATES}"
    )?;
    writeln!(
        output,
        "statistic = \"median and median absolute deviation\""
    )?;
    writeln!(
        output,
        "timed_scope = \"time stepping only; initialization and final checksum excluded\""
    )?;
    writeln!(output, "frequency_control = \"not pinned or controlled\"")?;
    writeln!(
        output,
        "source_revision = \"{}\"",
        escape_toml(&source_revision)
    )?;
    writeln!(output, "source_dirty = {}", !source_status.is_empty())?;
    writeln!(output, "environment = \"{}\"", escape_toml(environment))?;
    Ok(())
}

fn environment_summary() -> String {
    let cpu = fs::read_to_string("/proc/cpuinfo")
        .ok()
        .and_then(|contents| {
            contents.lines().find_map(|line| {
                line.strip_prefix("model name\t:")
                    .map(str::trim)
                    .map(str::to_owned)
            })
        })
        .unwrap_or_else(|| "unknown CPU".to_owned());
    let logical_cpus = std::thread::available_parallelism().map_or(1, usize::from);
    let operating_system = command_output("uname", &["-sr"]);
    let rustc = command_output("rustc", &["--version"]);
    let host = command_output("rustc", &["-vV"])
        .lines()
        .find_map(|line| line.strip_prefix("host: "))
        .unwrap_or("unknown host")
        .to_owned();
    format!(
        "CPU：{cpu}；可用逻辑核：{logical_cpus}；系统：{operating_system}；工具链：{rustc}；目标：{host}"
    )
}

fn command_output(program: &str, arguments: &[&str]) -> String {
    Command::new(program)
        .args(arguments)
        .output()
        .ok()
        .filter(|output| output.status.success())
        .and_then(|output| String::from_utf8(output.stdout).ok())
        .map_or_else(|| "unknown".to_owned(), |output| output.trim().to_owned())
}

fn escape_toml(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}
