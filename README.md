# 格子玻尔兹曼方法——基础与计算机实践（Rust 语言描述）

LBM-Rust 使用 Rust 学习和实现 Lattice Boltzmann Method（LBM），并使用 Typst 编写可复现的中文技术文档。与已有的 Fortran 和 C++ 教程互补，本仓库重点展示 Rust 的语言特性、工程最佳实践和计算生态如何支持可靠且高效的 LBM 实验，而不是仅仅复刻传统实现。

本仓库主要面向高年级本科生、研究生，以及只有少量数学和物理基础但希望用 LBM 解决实际问题的工程师和普通读者。书稿从一维模型和可手工检查的计算步骤开始，再逐步进入二维流动、工程验证和性能优化。

## 项目定位

- 用所有权、借用、类型系统、泛型和零成本抽象表达数值模型的不变量；
- 研究适合 LBM 的数据布局、内存访问模式、并行策略和向量化方法；
- 评估 Rayon、ndarray、GPU 计算等 Rust 生态方案，并通过可选功能保持核心边界清晰；
- 用基准测试、性能剖析和可复现实验数据判断优化效果；
- 同时维护清晰的标量基线，确保加速实现能够验证正确性并量化收益。

当前仓库是可扩展的计算实践脚手架，包含：

- D2Q9 离散速度、权重和平衡分布函数；
- 验证归一化、对称性、质量与动量恢复的 Rust 测试；
- 从 Rust 程序生成确定性文档数据的示例；
- 可生成完整 PDF 样书的模块化 Typst 源码；
- 同时检查代码、数据和文档的 GitHub Actions。

## 环境要求

- 当前稳定版 Rust，包含 `rustfmt` 与 `clippy`；
- [Typst](https://typst.app/) CLI；
- GNU Make；
- ripgrep，用于检查中文标点；
- Noto Serif CJK SC 字体。

Ubuntu／Debian 可以通过系统包 `fonts-noto-cjk` 安装所需中文字体。仓库根目录的 `rust-toolchain.toml` 会为 Rust 工具链声明必要组件。

## 快速开始

```sh
make rust-check
make pdf
```

生成的文档位于 `build/lbm-rust.pdf`。

文档使用仓库中已经生成的数据，因此普通 PDF 构建不会重新运行数值程序。需要更新数据时运行：

```sh
make regenerate
make check-generated
```

执行所有检查：

```sh
make check
```

## 仓库结构

- `crates/lbm-core`：可复用的 LBM 基础库；
- `examples/d2q9-equilibrium`：确定性数据生成程序；
- `book`：可完整出版的 Typst 书稿、章节和生成数据；
- `docs`：项目维护与代理协作文档；
- `build`：本地 PDF 与临时输出，不纳入版本控制。

## 许可证

本仓库全部内容采用 [Apache License 2.0](LICENSE) 授权。
