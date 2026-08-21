//! 为文档生成确定性的 D2Q9 平衡分布数据与数据图。

use std::{
    env, fs,
    io::{self, Write},
    path::{Path, PathBuf},
};

use d2q9_equilibrium::render_equilibrium_svg;
use lbm_core::{D2Q9, equilibrium};

fn main() -> io::Result<()> {
    let output_directory = env::args_os()
        .nth(1)
        .map_or_else(|| PathBuf::from("book/assets/generated"), PathBuf::from);
    fs::create_dir_all(&output_directory)?;

    let density = 1.0;
    let velocity = [0.08, 0.02];
    let distributions = equilibrium(density, velocity);

    write_csv(
        &output_directory.join("d2q9-equilibrium.csv"),
        &distributions,
    )?;
    fs::write(
        output_directory.join("d2q9-equilibrium.svg"),
        render_equilibrium_svg(density, velocity, &distributions),
    )
}

fn write_csv(path: &Path, distributions: &[f64; D2Q9::Q]) -> io::Result<()> {
    let mut output = io::BufWriter::new(fs::File::create(path)?);

    writeln!(output, "direction,cx,cy,weight,equilibrium")?;
    for (index, ((velocity, weight), distribution)) in D2Q9::VELOCITIES
        .iter()
        .zip(D2Q9::WEIGHTS)
        .zip(distributions)
        .enumerate()
    {
        writeln!(
            output,
            "{index},{},{},{weight:.12},{population:.12}",
            velocity[0],
            velocity[1],
            population = distribution,
        )?;
    }

    Ok(())
}
