= 构建与贡献

本地构建需要稳定版 Rust、Typst、GNU Make，以及 Noto Serif CJK 字体。常用命令如下：

```sh
make rust-check
make regenerate
make pdf
make check
```

PDF 输出到 `build/lbm-rust.pdf`，不会纳入版本控制。持续集成会重复执行 Rust 检查、数据漂移检查和 PDF 构建，并上传 PDF 构件。

贡献新模型、案例或优化时，应提供自动化验证、对应文档和可复现的发布模式基准；缺乏直接证据的结论应标记为待验证。
