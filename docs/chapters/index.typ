#import "../template.typ": equation-scope

#pagebreak(weak: true)
#heading(level: 1, numbering: none, outlined: true)[索引] <index>
#equation-scope("I")

#let index-entry(english, chinese, target) = {
  english
  [（]
  chinese
  [）]
  box(width: 1fr, repeat[.])
  ref(target, form: "page")
  linebreak()
}

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[B]
#index-entry([BGK collision], [BGK 碰撞], <collision-streaming>)
#index-entry([Boundary condition], [边界条件], <fluid-boundaries>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[C]
#index-entry([Continuity equation], [连续性方程], <conservation>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[D]
#index-entry([D2Q9], [D2Q9 离散速度模型], <d2q9>)
#index-entry([Distribution function], [分布函数], <distribution>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[E]
#index-entry([Equilibrium distribution], [平衡分布], <equilibrium>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[F]
#index-entry([Fluid flow], [流体流动], <fluid-flow>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[K]
#index-entry([Knudsen number], [努森数], <dimensionless>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[L]
#index-entry([Lattice Boltzmann Method], [格子玻尔兹曼方法], <lbm>)
#index-entry([Lattice unit], [格子单位], <d2q9>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[M]
#index-entry([Mach number], [马赫数], <dimensionless>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[N]
#index-entry([Navier–Stokes equation], [纳维–斯托克斯方程], <conservation>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[R]
#index-entry([Reproducible data], [可复现数据], <reproducible-data>)
#index-entry([Reynolds number], [雷诺数], <dimensionless>)
#index-entry([Rust implementation], [Rust 实现], <rust-implementation>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[S]
#index-entry([Streaming], [迁移], <collision-streaming>)
