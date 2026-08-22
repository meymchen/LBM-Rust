//! 面向 Rust 语言实践与高性能实验的 Lattice Boltzmann Method 基础组件。
//!
//! 当前版本提供 D1Q3 与 D2Q9 格子定义和平衡分布函数。后续求解器、碰撞模型与边界条件
//! 可以在这些经过验证的基础组件之上扩展。

mod d1q3;
mod d2q9;

pub use d1q3::{D1Q3, diffusion_equilibrium};
pub use d2q9::{D2Q9, equilibrium};
