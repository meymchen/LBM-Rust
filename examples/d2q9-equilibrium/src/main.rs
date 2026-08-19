//! 为文档生成确定性的 D2Q9 平衡分布数据。

use std::io::{self, Write};

use lbm_core::{D2Q9, equilibrium};

fn main() -> io::Result<()> {
    let density = 1.0;
    let velocity = [0.08, 0.02];
    let populations = equilibrium(density, velocity);
    let stdout = io::stdout();
    let mut output = io::BufWriter::new(stdout.lock());

    writeln!(output, "direction,cx,cy,weight,equilibrium")?;
    for (index, ((direction, weight), population)) in D2Q9::DIRECTIONS
        .iter()
        .zip(D2Q9::WEIGHTS)
        .zip(populations)
        .enumerate()
    {
        writeln!(
            output,
            "{index},{},{},{weight:.12},{population:.12}",
            direction[0], direction[1]
        )?;
    }

    Ok(())
}
