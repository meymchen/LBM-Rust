#pagebreak(weak: true)
= 可复现数据

当前示例在 $rho = 1$、$u = (0.08, 0.02)$ 时计算九个方向的平衡分布。以下 CSV 由 Rust 程序生成并纳入版本控制：

#figure(
  raw(
    read("../assets/generated/d2q9-equilibrium.csv"),
    block: true,
    lang: "csv",
  ),
  caption: [D2Q9 平衡分布的确定性输出],
)

普通文档构建直接读取该文件。维护者可以运行 `make regenerate` 重新计算，再用 `make check-generated` 验证仓库数据是否与当前代码一致。
