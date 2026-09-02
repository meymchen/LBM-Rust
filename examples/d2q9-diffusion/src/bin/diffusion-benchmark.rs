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
    Boundary, D2Q5_DISTRIBUTION_BYTES_PER_SITE, D2Q5_WORKING_BYTES_PER_SITE, D2Q9_BLOCK_SIZE,
    D2Q9_DISTRIBUTION_BYTES_PER_SITE, D2Q9_WORKING_BYTES_PER_SITE, D2q5Solver, D2q9BlockedSolver,
    D2q9LayoutPerformanceRow, D2q9SoaSolver, D2q9Solver, LatticePerformanceRow, periodic_mode,
    render_d2q9_layout_performance_svg, render_lattice_performance_svg,
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

    let (rows, layout_rows): (Vec<_>, Vec<_>) =
        LENGTHS.iter().copied().map(benchmark_length).unzip();
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
    write_layout_csv(
        &output_directory.join("d2q9-layout-performance.csv"),
        &layout_rows,
    )?;
    fs::write(
        output_directory.join("d2q9-layout-performance.svg"),
        render_d2q9_layout_performance_svg(&layout_rows, &environment),
    )?;
    write_layout_metadata(
        &output_directory.join("d2q9-layout-performance.toml"),
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
    println!("N,sites,steps,AoS MLUPS,SoA MLUPS,blocked MLUPS,SoA speedup,blocked speedup");
    for row in &layout_rows {
        println!(
            "{},{},{},{:.3},{:.3},{:.3},{:.3},{:.3}",
            row.length,
            row.sites(),
            row.steps,
            row.aos_mlups(),
            row.soa_mlups(),
            row.blocked_mlups(),
            row.soa_speedup_over_aos(),
            row.blocked_speedup_over_aos(),
        );
    }
    println!("输出目录：{}", output_directory.display());
    Ok(())
}

fn benchmark_length(length: usize) -> (LatticePerformanceRow, D2q9LayoutPerformanceRow) {
    let sites = length * length;
    let steps = MINIMUM_STEPS.max(MINIMUM_SITE_UPDATES.div_ceil(sites));
    let initial = periodic_mode(length, 1.0);

    for _ in 0..WARMUP_SAMPLES {
        black_box(time_d2q5(&initial, length, steps));
        black_box(time_d2q9(&initial, length, steps));
        black_box(time_d2q9_soa(&initial, length, steps));
        black_box(time_d2q9_blocked(&initial, length, steps));
    }

    let mut d2q5 = Vec::with_capacity(MEASURED_SAMPLES);
    let mut d2q9 = Vec::with_capacity(MEASURED_SAMPLES);
    let mut d2q9_soa = Vec::with_capacity(MEASURED_SAMPLES);
    let mut d2q9_blocked = Vec::with_capacity(MEASURED_SAMPLES);
    for sample in 0..MEASURED_SAMPLES {
        if sample % 2 == 0 {
            d2q5.push(time_d2q5(&initial, length, steps));
            d2q9.push(time_d2q9(&initial, length, steps));
            d2q9_soa.push(time_d2q9_soa(&initial, length, steps));
            d2q9_blocked.push(time_d2q9_blocked(&initial, length, steps));
        } else {
            d2q9_blocked.push(time_d2q9_blocked(&initial, length, steps));
            d2q9_soa.push(time_d2q9_soa(&initial, length, steps));
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
    let d2q9_soa_per_site_step: Vec<_> = d2q9_soa
        .into_iter()
        .map(|duration| duration.as_secs_f64() * 1.0e9 / site_steps)
        .collect();
    let d2q9_blocked_per_site_step: Vec<_> = d2q9_blocked
        .into_iter()
        .map(|duration| duration.as_secs_f64() * 1.0e9 / site_steps)
        .collect();
    let d2q5_median = median(&d2q5_per_site_step);
    let d2q9_median = median(&d2q9_per_site_step);

    let d2q9_soa_median = median(&d2q9_soa_per_site_step);
    let d2q9_blocked_median = median(&d2q9_blocked_per_site_step);

    let lattice = LatticePerformanceRow {
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
    };
    let layouts = D2q9LayoutPerformanceRow {
        length,
        steps,
        samples: MEASURED_SAMPLES,
        aos_nanoseconds_per_site_step: d2q9_median,
        aos_mad_nanoseconds_per_site_step: median_absolute_deviation(
            &d2q9_per_site_step,
            d2q9_median,
        ),
        soa_nanoseconds_per_site_step: d2q9_soa_median,
        soa_mad_nanoseconds_per_site_step: median_absolute_deviation(
            &d2q9_soa_per_site_step,
            d2q9_soa_median,
        ),
        blocked_nanoseconds_per_site_step: d2q9_blocked_median,
        blocked_mad_nanoseconds_per_site_step: median_absolute_deviation(
            &d2q9_blocked_per_site_step,
            d2q9_blocked_median,
        ),
    };
    (lattice, layouts)
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

fn time_d2q9_soa(initial: &[f64], length: usize, steps: usize) -> Duration {
    let mut solver = D2q9SoaSolver::from_scalar(initial, length, 1.0, Boundary::Periodic);
    let start = Instant::now();
    for _ in 0..steps {
        solver.step();
    }
    let elapsed = start.elapsed();
    black_box(solver.scalar());
    elapsed
}

fn time_d2q9_blocked(initial: &[f64], length: usize, steps: usize) -> Duration {
    let mut solver = D2q9BlockedSolver::from_scalar(initial, length, 1.0, Boundary::Periodic);
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

fn write_layout_csv(path: &Path, rows: &[D2q9LayoutPerformanceRow]) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);
    writeln!(
        output,
        "n,sites,steps,samples,aos_ns_per_site_step,aos_mad_ns_per_site_step,soa_ns_per_site_step,soa_mad_ns_per_site_step,blocked_ns_per_site_step,blocked_mad_ns_per_site_step,aos_mlups,soa_mlups,blocked_mlups,soa_speedup,blocked_speedup"
    )?;
    for row in rows {
        writeln!(
            output,
            "{},{},{},{},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6}",
            row.length,
            row.sites(),
            row.steps,
            row.samples,
            row.aos_nanoseconds_per_site_step,
            row.aos_mad_nanoseconds_per_site_step,
            row.soa_nanoseconds_per_site_step,
            row.soa_mad_nanoseconds_per_site_step,
            row.blocked_nanoseconds_per_site_step,
            row.blocked_mad_nanoseconds_per_site_step,
            row.aos_mlups(),
            row.soa_mlups(),
            row.blocked_mlups(),
            row.soa_speedup_over_aos(),
            row.blocked_speedup_over_aos(),
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

fn write_layout_metadata(
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
    writeln!(output, "layouts = [\"AoS\", \"SoA\", \"blocked SoA\"]")?;
    writeln!(output, "block_size_sites = {D2Q9_BLOCK_SIZE}")?;
    writeln!(
        output,
        "numerical_equivalence = \"bitwise identical scalar fields across the regression suite\""
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
        .or_else(|| {
            let registry = command_output(
                "reg",
                &[
                    "query",
                    r"HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0",
                    "/v",
                    "ProcessorNameString",
                ],
            );
            registry
                .split_once("REG_SZ")
                .map(|(_, value)| value.trim().to_owned())
        })
        .or_else(|| env::var("PROCESSOR_IDENTIFIER").ok())
        .unwrap_or_else(|| "unknown CPU".to_owned());
    let logical_cpus = std::thread::available_parallelism().map_or(1, usize::from);
    let mut operating_system = command_output("uname", &["-sr"]);
    if operating_system == "unknown" {
        operating_system = command_output("cmd", &["/C", "ver"]);
    }
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
