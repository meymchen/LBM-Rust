#pagebreak(weak: true)
#set heading(numbering: "A.1")
#counter(heading).update(0)
#heading(level: 1, supplement: [附录])[可复现数据] <reproducible-data>

本附录收录第二章 D2Q9 平衡分布示例的完整确定性输出。计算条件为 $rho = 1$、$bold(u) = (0.08, 0.02)$；数据由 Rust 示例程序生成，并作为回归检查的基准文件纳入版本控制。

#figure(
  raw(
    read("../assets/generated/d2q9-equilibrium.csv"),
    block: true,
    lang: "csv",
  ),
  caption: [D2Q9 平衡分布的完整确定性输出],
)

源文件：`book/assets/generated/d2q9-equilibrium.csv`。

生成程序：`examples/d2q9-equilibrium/src/main.rs`。
