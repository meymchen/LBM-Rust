//! 为文档生成确定性的有限差分与 D1Q3 LBM 一维扩散对比数据与数据图。

use std::{
    env, fs,
    io::{self, Write},
    path::{Path, PathBuf},
};

use d1q3_diffusion::{
    ConvergenceRow, convergence_study, profile_comparison, render_comparison_svg,
};

fn main() -> io::Result<()> {
    let output_directory = env::args_os()
        .nth(1)
        .map_or_else(|| PathBuf::from("book/assets/generated"), PathBuf::from);
    fs::create_dir_all(&output_directory)?;

    let (positions, profiles) = profile_comparison();
    write_profiles_csv(
        &output_directory.join("d1q3-diffusion-profiles.csv"),
        &positions,
        &profiles,
    )?;

    let rows = convergence_study(&[16, 32, 64, 128, 256]);
    write_convergence_csv(
        &output_directory.join("d1q3-diffusion-convergence.csv"),
        &rows,
    )?;

    fs::write(
        output_directory.join("d1q3-diffusion.svg"),
        render_comparison_svg(&positions, &profiles, &rows),
    )
}

fn write_profiles_csv(path: &Path, positions: &[f64], profiles: &[Vec<f64>]) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);

    writeln!(output, "x,analytic,fdm,lbm_omega1,lbm_omega1p5")?;
    for (index, position) in positions.iter().enumerate() {
        writeln!(
            output,
            "{position:.0},{:.12},{:.12},{:.12},{:.12}",
            profiles[0][index], profiles[1][index], profiles[2][index], profiles[3][index],
        )?;
    }

    Ok(())
}

fn write_convergence_csv(path: &Path, rows: &[ConvergenceRow]) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);

    writeln!(
        output,
        "n,steps,error_fdm,error_lbm_omega1,error_lbm_omega1p5"
    )?;
    for row in rows {
        writeln!(
            output,
            "{},{},{:.12e},{:.12e},{:.12e}",
            row.length, row.steps, row.error_fdm, row.error_lbm_omega1, row.error_lbm_omega3half,
        )?;
    }

    Ok(())
}
