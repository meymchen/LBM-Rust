//! 比较 D2Q5 与 D2Q9 二维扩散当前实现的单线程发布构建性能。

#![allow(clippy::cast_precision_loss)]

use std::{
    env, fs,
    hint::black_box,
    io::{self, Write},
    path::{Path, PathBuf},
    process::Command,
    time::{Duration, Instant},
};

use d2q9_diffusion::{
    Boundary, D2Q5_DISTRIBUTION_BYTES_PER_SITE, D2Q5_WORKING_BYTES_PER_SITE,
    D2Q9_DISTRIBUTION_BYTES_PER_SITE, D2Q9_WORKING_BYTES_PER_SITE, D2q5Solver, D2q9Solver,
    LatticePerformanceRow, periodic_mode, render_lattice_performance_svg,
};

const LENGTHS: [usize; 4] = [64, 128, 256, 512];
const MINIMUM_SITE_UPDATES: usize = 16 * 1024 * 1024;
const MINIMUM_STEPS: usize = 16;
const WARMUP_SAMPLES: usize = 2;
const MEASURED_SAMPLES: usize = 9;

fn main() -> io::Result<()> {
    let source_revision = command_output("git", &["rev-parse", "HEAD"]);
    let source_dirty = !command_output("git", &["status", "--porcelain"]).is_empty();
    let output_directory = env::args_os().nth(1).map_or_else(
        || PathBuf::from(".scratch/d2q5-d2q9-diffusion-benchmark"),
        PathBuf::from,
    );
    fs::create_dir_all(&output_directory)?;

    let rows: Vec<_> = LENGTHS.iter().copied().map(benchmark_length).collect();
    let environment = environment_summary();
    write_csv(
        &output_directory.join("d2q5-d2q9-diffusion-performance.csv"),
        &rows,
    )?;
    fs::write(
        output_directory.join("d2q5-d2q9-diffusion-performance.svg"),
        render_lattice_performance_svg(&rows, &environment),
    )?;
    write_metadata(
        &output_directory.join("d2q5-d2q9-diffusion-performance.toml"),
        &environment,
        &source_revision,
        source_dirty,
    )?;

    println!("{environment}");
    println!(
        "每格点分布存储：D2Q5 {D2Q5_DISTRIBUTION_BYTES_PER_SITE} B，D2Q9 {D2Q9_DISTRIBUTION_BYTES_PER_SITE} B"
    );
    println!(
        "当前双缓冲工作存储：D2Q5 {D2Q5_WORKING_BYTES_PER_SITE} B／格点，D2Q9 {D2Q9_WORKING_BYTES_PER_SITE} B／格点"
    );
    println!("N,sites,steps,D2Q5 MLUPS,D2Q9 MLUPS,D2Q5 speedup");
    for row in &rows {
        println!(
            "{},{},{},{:.3},{:.3},{:.3}",
            row.length,
            row.sites(),
            row.steps,
            row.d2q5_mlups(),
            row.d2q9_mlups(),
            row.d2q5_speedup_over_d2q9(),
        );
    }
    println!("输出目录：{}", output_directory.display());
    Ok(())
}

fn benchmark_length(length: usize) -> LatticePerformanceRow {
    let sites = length * length;
    let steps = MINIMUM_STEPS.max(MINIMUM_SITE_UPDATES.div_ceil(sites));
    let initial = periodic_mode(length, 1.0);

    for _ in 0..WARMUP_SAMPLES {
        black_box(time_d2q5(&initial, length, steps));
        black_box(time_d2q9(&initial, length, steps));
    }

    let mut d2q5 = Vec::with_capacity(MEASURED_SAMPLES);
    let mut d2q9 = Vec::with_capacity(MEASURED_SAMPLES);
    for sample in 0..MEASURED_SAMPLES {
        if sample % 2 == 0 {
            d2q5.push(time_d2q5(&initial, length, steps));
            d2q9.push(time_d2q9(&initial, length, steps));
        } else {
            d2q9.push(time_d2q9(&initial, length, steps));
            d2q5.push(time_d2q5(&initial, length, steps));
        }
    }

    let site_steps = (sites * steps) as f64;
    let d2q5_per_site_step: Vec<_> = d2q5
        .into_iter()
        .map(|duration| duration.as_secs_f64() * 1.0e9 / site_steps)
        .collect();
    let d2q9_per_site_step: Vec<_> = d2q9
        .into_iter()
        .map(|duration| duration.as_secs_f64() * 1.0e9 / site_steps)
        .collect();
    let d2q5_median = median(&d2q5_per_site_step);
    let d2q9_median = median(&d2q9_per_site_step);

    LatticePerformanceRow {
        length,
        steps,
        samples: MEASURED_SAMPLES,
        d2q5_nanoseconds_per_site_step: d2q5_median,
        d2q5_mad_nanoseconds_per_site_step: median_absolute_deviation(
            &d2q5_per_site_step,
            d2q5_median,
        ),
        d2q9_nanoseconds_per_site_step: d2q9_median,
        d2q9_mad_nanoseconds_per_site_step: median_absolute_deviation(
            &d2q9_per_site_step,
            d2q9_median,
        ),
    }
}

fn time_d2q5(initial: &[f64], length: usize, steps: usize) -> Duration {
    let mut solver = D2q5Solver::from_scalar(initial, length, 1.0, Boundary::Periodic);
    let start = Instant::now();
    for _ in 0..steps {
        solver.step();
    }
    let elapsed = start.elapsed();
    black_box(solver.scalar());
    elapsed
}

fn time_d2q9(initial: &[f64], length: usize, steps: usize) -> Duration {
    let mut solver = D2q9Solver::from_scalar(initial, length, 1.0, Boundary::Periodic);
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

fn write_csv(path: &Path, rows: &[LatticePerformanceRow]) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);
    writeln!(
        output,
        "n,sites,steps,samples,d2q5_ns_per_site_step,d2q5_mad_ns_per_site_step,d2q9_ns_per_site_step,d2q9_mad_ns_per_site_step,d2q5_mlups,d2q9_mlups,d2q5_speedup"
    )?;
    for row in rows {
        writeln!(
            output,
            "{},{},{},{},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6}",
            row.length,
            row.sites(),
            row.steps,
            row.samples,
            row.d2q5_nanoseconds_per_site_step,
            row.d2q5_mad_nanoseconds_per_site_step,
            row.d2q9_nanoseconds_per_site_step,
            row.d2q9_mad_nanoseconds_per_site_step,
            row.d2q5_mlups(),
            row.d2q9_mlups(),
            row.d2q5_speedup_over_d2q9(),
        )?;
    }
    Ok(())
}

fn write_metadata(
    path: &Path,
    environment: &str,
    source_revision: &str,
    source_dirty: bool,
) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);
    writeln!(output, "schema_version = 1")?;
    writeln!(
        output,
        "command = \"cargo run --release --quiet -p d2q9-diffusion --bin diffusion-benchmark -- <output-directory>\""
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
        "timed_scope = \"time stepping only; initialization and final scalar reconstruction excluded\""
    )?;
    writeln!(output, "boundary = \"periodic\"")?;
    writeln!(output, "omega = 1.0")?;
    writeln!(output, "layout = \"array of structures\"")?;
    writeln!(
        output,
        "d2q5_distribution_bytes_per_site = {D2Q5_DISTRIBUTION_BYTES_PER_SITE}"
    )?;
    writeln!(
        output,
        "d2q9_distribution_bytes_per_site = {D2Q9_DISTRIBUTION_BYTES_PER_SITE}"
    )?;
    writeln!(
        output,
        "d2q5_working_bytes_per_site = {D2Q5_WORKING_BYTES_PER_SITE}"
    )?;
    writeln!(
        output,
        "d2q9_working_bytes_per_site = {D2Q9_WORKING_BYTES_PER_SITE}"
    )?;
    writeln!(output, "frequency_control = \"not pinned or controlled\"")?;
    writeln!(
        output,
        "source_revision = \"{}\"",
        escape_toml(source_revision)
    )?;
    writeln!(output, "source_dirty = {source_dirty}")?;
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
