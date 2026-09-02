//! 面向 Rust 语言实践与高性能实验的 Lattice Boltzmann Method 基础组件。
//!
//! 当前版本提供 D1Q3 与 D2Q9 格子定义、扩散平衡分布与流动平衡分布。后续求解器、
//! 碰撞模型与边界条件可以在这些经过验证的基础组件之上扩展。
//!
//! 平衡分布函数按格子分模块提供。同一名称在不同格子下含义相同、维数不同，
//! 因此用模块路径而非名称前缀区分，例如 [`d1q3::diffusion_equilibrium`] 与
//! [`d2q9::diffusion_equilibrium`]。格子类型本身在根部重导出。

pub mod d1q3;
pub mod d2q9;

pub use d1q3::D1Q3;
pub use d2q9::D2Q9;
