//! 生成真实 D2Q9 二维扩散场的 VTK 时间序列。

use std::{env, io, path::PathBuf};

fn main() -> io::Result<()> {
    let output = env::args_os()
        .nth(1)
        .map_or_else(|| PathBuf::from("build/d2q9-diffusion-vtk"), PathBuf::from);
    d2q9_diffusion::generate_vtk_run(output)
}
