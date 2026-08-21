#import "../template.typ": equation-scope, figure-scope

#pagebreak(weak: true)
#heading(level: 1, numbering: none, outlined: true)[索引] <index>
#equation-scope("I")
#figure-scope("I")

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
#index-entry([Boltzmann equation], [玻尔兹曼方程], <boltzmann-equation>)
#index-entry([Boundary condition], [边界条件], <fluid-boundaries>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[C]
#index-entry([Continuity equation], [连续性方程], <mass-conservation>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[D]
#index-entry([D1Q3], [D1Q3 一维三速模型], <d1q3>)
#index-entry([D2Q9], [D2Q9 离散速度模型], <d2q9>)
#index-entry([D3Q19], [D3Q19 三维十九速模型], <d3q19>)
#index-entry([D3Q27], [D3Q27 三维二十七速模型], <d3q27>)
#index-entry([Distribution function], [分布函数], <boltzmann-equation>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[E]
#index-entry([Equilibrium distribution], [平衡分布], <equilibrium>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[F]
#index-entry([Fluid flow], [流体流动], <fluid-flow>)
#index-entry([Flow classification], [流动分类], <flow-classification>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[G]
#index-entry([Gauss–Hermite quadrature], [Gauss–Hermite 求积], <advanced-hermite-quadrature>)
#index-entry([Galilean invariance], [Galilean 不变性], <advanced-galilean-invariance>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[H]
#index-entry([H-theorem], [$H$ 定理], <advanced-h-theorem>)
#index-entry([Hermite expansion], [Hermite 展开], <advanced-hermite-quadrature>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[L]
#index-entry([Lattice Boltzmann Method], [格子玻尔兹曼方法], <lbm>)
#index-entry([Lattice unit], [格子单位], <d2q9>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[M]
#index-entry([Mach number], [马赫数], <flow-classification>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[N]
#index-entry([Navier–Stokes equation], [纳维–斯托克斯方程], <navier-stokes>)
#index-entry([Numerical methods], [流体数值方法], <numerical-models>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[P]
#index-entry([Pressure tensor], [动力学压力张量], <moment-hierarchy>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[R]
#index-entry([Reproducible data], [可复现数据], <reproducible-data>)
#index-entry([Reduced model], [简化流动模型], <reduced-models>)
#index-entry([Reynolds number], [雷诺数], <flow-classification>)
#index-entry([Rust implementation], [Rust 实现], <rust-implementation>)

#heading(level: 2, numbering: none, outlined: false, bookmarked: false)[S]
#index-entry([Streaming], [迁移], <collision-streaming>)
