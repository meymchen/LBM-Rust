//! 生成 VTK／ParaView 互操作原型资产。

use std::{env, ffi::OsStr, io, path::PathBuf};

fn main() -> io::Result<()> {
    let mut arguments = env::args_os().skip(1);
    let first = arguments.next();
    let (force, output) = if first.as_deref() == Some(OsStr::new("--force")) {
        (true, arguments.next())
    } else {
        (false, first)
    };
    let output = output.map_or_else(|| PathBuf::from("build/vtk-interop"), PathBuf::from);
    if force {
        vtk_interop::regenerate_interop_assets(output)
    } else {
        vtk_interop::generate_interop_assets(output)
    }
}
