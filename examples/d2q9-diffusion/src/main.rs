//! 为文档生成确定性的二维扩散对比数据与数据图。

use std::{
    env, fs,
    io::{self, Write},
    path::{Path, PathBuf},
};

use d2q9_diffusion::{
    CONVERGENCE_LENGTHS, ConvergenceRow, FieldComparison, convergence_study, field_comparison,
    render_comparison_svg,
};

fn main() -> io::Result<()> {
    let output_directory = env::args_os()
        .nth(1)
        .map_or_else(|| PathBuf::from("book/assets/generated"), PathBuf::from);
    fs::create_dir_all(&output_directory)?;

    let comparison = field_comparison();
    write_profiles_csv(
        &output_directory.join("d2q9-diffusion-profiles.csv"),
        &comparison,
    )?;

    let rows = convergence_study(&CONVERGENCE_LENGTHS);
    write_convergence_csv(
        &output_directory.join("d2q9-diffusion-convergence.csv"),
        &rows,
    )?;

    // 误差场只进入 SVG，不单独版本化：整场 CSV 在评审中不可读，
    // 而型线与收敛表已经承载全部定量结论。
    fs::write(
        output_directory.join("d2q9-diffusion.svg"),
        render_comparison_svg(&comparison, &rows),
    )
}

fn write_profiles_csv(path: &Path, comparison: &FieldComparison) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);

    writeln!(
        output,
        "x,analytic,ftcs,lbm_anti_bounce_back,lbm_equilibrium"
    )?;
    for (index, position) in comparison.positions.iter().enumerate() {
        writeln!(
            output,
            "{position:.1},{:.12},{:.12},{:.12},{:.12}",
            comparison.profiles[0][index],
            comparison.profiles[1][index],
            comparison.profiles[2][index],
            comparison.profiles[3][index],
        )?;
    }

    Ok(())
}

fn write_convergence_csv(path: &Path, rows: &[ConvergenceRow]) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);

    writeln!(
        output,
        "n,steps,error_ftcs,error_lbm_omega1,error_lbm_omega1p5,error_lbm_equilibrium"
    )?;
    for row in rows {
        writeln!(
            output,
            "{},{},{:.12e},{:.12e},{:.12e},{:.12e}",
            row.length,
            row.steps,
            row.error_ftcs,
            row.error_lbm_omega1,
            row.error_lbm_omega1p5,
            row.error_lbm_equilibrium,
        )?;
    }

    Ok(())
}
