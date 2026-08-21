#import "../symbols.typ": df, dphi, drho, dt, du, dx
#import "../template.typ": equation-scope, figure-scope

#pagebreak(weak: true)
#heading(level: 1, numbering: none, outlined: true)[符号索引] <symbol-index>
#equation-scope("S")
#figure-scope("S")
#set heading(numbering: none, outlined: false)

本章收录跨段落反复使用或容易混淆的符号。局部求和指标和临时变量仍在首次出现处说明。每条末尾给出首次正式定义的页码。校对时应同时检查字体、粗细、上下标和符号所在的理论层次；字母相同不表示物理含义相同。

#text(size: 9pt, fill: luma(75))[字形约定：普通数学字形用于标量、索引、分布函数、分量或算子；粗体用于向量、张量或矩阵。每个符号的类型同时标在旁边。]

#let source(target) = ref(target, form: "page")
#let typed-symbol(value, kind) = [
  #value
  #h(0.35em)
  #text(size: 6.5pt, fill: luma(100))[#kind]
]
#let symbols(..cells) = {
  let cells = cells.pos()
  let items = range(0, cells.len())
    .filter(index => calc.rem(index, 4) == 0)
    .map(index => terms.item(
      box(
        width: 5em,
        align(center, text(weight: "regular", cells.at(index))),
      ),
      [
        #strong(cells.at(index + 1))。
        #cells.at(index + 2)
        #h(0.4em)
        #box(
          width: 3.4em,
          align(right, text(size: 8.5pt, fill: luma(90))[(#cells.at(index + 3))]),
        )
      ],
    ))
  terms(
    tight: false,
    indent: 0pt,
    hanging-indent: 5.8em,
    separator: h(0.8em),
    spacing: 0.55em,
    ..items,
  )
}

== 通用记号

#symbols(
  [#typed-symbol([$d$], [标量])], [空间维数], [取 1、2 或 3；D$d$Q$Q$ 中的 D 后数字也表示空间维数。], [#source(<sym-dimension>)],
  [#typed-symbol([$Q$], [标量])], [离散速度数], [一个格点保存的离散分布分量数。], [#source(<sym-velocity-count>)],
  [#typed-symbol([$i$], [索引])], [离散速度下标], [对 $i$ 的求和显式写出，不使用 Einstein 求和约定。], [#source(<sym-discrete-index>)],
  [#typed-symbol([$alpha, beta, gamma$], [索引])], [Cartesian 分量下标], [重复的 Greek 分量下标默认求和。], [#source(<sym-cartesian-indices>)],
  [#typed-symbol([$bold(x)$], [向量])], [位置向量], [无粗体的 $x$ 表示 Cartesian 坐标或横坐标。], [#source(<sym-position>)],
  [#typed-symbol([$t$], [标量])], [物理时间], [连续方程和离散演化共用该符号。], [#source(<sym-time>)],
  [#typed-symbol([$#dt$], [标量])], [有限时间增量], [连续推导中两个时刻之间的有限时间间隔。], [#source(<sym-time-increment>)],
  [#typed-symbol([$#dx$], [标量])], [格距], [规则格子相邻格点之间的物理距离；作为一个完整数学原子排版。], [#source(<sym-lattice-spacing>)],
  [#typed-symbol([$#dt$], [标量])], [时间步], [一次离散状态更新对应的物理时间增量；作为一个完整数学原子排版。], [#source(<sym-time-step>)],
  [#typed-symbol([$#dphi$], [标量])], [标量有限增量], [第一章推导物质导数时，表示标量 $phi$ 在有限时间内的变化。], [#source(<sym-scalar-increment>)],
)

== 连续介质与无量纲量

#symbols(
  [#typed-symbol([$rho$], [标量])], [密度], [质量密度；$rho_0$ 表示参考密度。], [#source(<sym-density>)],
  [#typed-symbol([$bold(u)$], [向量])], [宏观速度], [$u_alpha$ 是其 Cartesian 分量，$U$ 是特征速度尺度。], [#source(<sym-macroscopic-velocity>)],
  [#typed-symbol([$p$], [标量])], [压力], [连续介质中的机械压力；等温 LBM 中满足 $p=rho c_s^2$。], [#source(<sym-pressure>)],
  [#typed-symbol([$T$], [标量])], [温度], [热力学温度；等温 LBM 不演化该变量。], [#source(<sym-temperature>)],
  [#typed-symbol([$bold(g)$], [向量])], [单位质量体力], [量纲为加速度，例如重力加速度。], [#source(<sym-body-acceleration>)],
  [#typed-symbol([$bold(F)$], [向量])], [力密度], [单位体积所受的力，$bold(F)=rho bold(g)$。], [#source(<sym-force-density>)],
  [#typed-symbol([$bold(sigma)$], [张量])], [Cauchy 应力张量], [满足 $bold(sigma)=-p bold(I)+bold(tau)$。], [#source(<sym-cauchy-stress>)],
  [#typed-symbol([$bold(tau)$], [张量])], [黏性应力张量], [不要与松弛时间 $tau_k$ 或 $overline(tau)$ 混用。], [#source(<sym-viscous-stress>)],
  [#typed-symbol([$mu$], [标量])], [动力黏度], [牛顿流体黏性应力的系数。], [#source(<sym-dynamic-viscosity>)],
  [#typed-symbol([$nu$], [标量])], [运动黏度], [定义为 $nu=mu/rho$。], [#source(<sym-kinematic-viscosity>)],
  [#typed-symbol([$lambda_v$], [标量])], [第二黏度系数], [出现在可压缩牛顿流体的体积变形项中。], [#source(<sym-second-viscosity>)],
  [#typed-symbol([$L$], [标量])], [特征长度], [用于定义无量纲数和尺度分析。], [#source(<sym-characteristic-length>)],
  [#typed-symbol([$lambda$], [标量])], [平均自由程], [不要与第二黏度系数 $lambda_v$ 混用。], [#source(<sym-mean-free-path>)],
  [#typed-symbol([$"Kn"$], [标量])], [Knudsen 数], [定义为 $lambda/L$，衡量连续介质近似的适用程度。], [#source(<sym-knudsen-number>)],
  [#typed-symbol([$"Re"$], [标量])], [Reynolds 数], [定义为 $U L/nu$，比较惯性与黏性效应。], [#source(<sym-reynolds-number>)],
  [#typed-symbol([$c_s$], [标量])], [声速], [连续介质中压力扰动的传播速度。], [#source(<sym-sound-speed>)],
  [#typed-symbol([$"Ma"$], [标量])], [Mach 数], [定义为 $U/c_s$，比较流速与声速。], [#source(<sym-mach-number>)],
)

== 连续动力学

#symbols(
  [#typed-symbol([$bold(xi)$], [向量])], [连续微观速度], [连续速度空间中的积分变量；不要写成离散速度 $bold(c)_i$。], [#source(<sym-microscopic-velocity>)],
  [#typed-symbol([$bold(C)$], [向量])], [涨落速度], [定义为 $bold(xi)-bold(u)$。], [#source(<sym-peculiar-velocity>)],
  [#typed-symbol([$f$], [分布函数])], [连续分布函数], [本书采用质量分布函数，依赖 $bold(x)$、$bold(xi)$ 和 $t$。], [#source(<sym-continuous-distribution>)],
  [#typed-symbol([$Omega_B$], [算子])], [Boltzmann 碰撞算子], [在同一位置重新分配微观速度。], [#source(<sym-boltzmann-collision>)],
  [#typed-symbol([$tau_k$], [标量])], [物理松弛时间], [连续 BGK 方程中的松弛尺度；不要与离散 $overline(tau)$ 混用。], [#source(<sym-physical-relaxation-time>)],
  [#typed-symbol([$f^("eq")$], [分布函数])], [连续局部平衡分布], [由局部密度、速度和温度确定的 Maxwell 分布。], [#source(<sym-continuous-equilibrium>)],
  [#typed-symbol([$bold(P)$], [张量])], [动力学压力张量], [分布函数的二阶涨落速度矩。], [#source(<sym-pressure-tensor>)],
  [#typed-symbol([$bold(q)$], [向量])], [热流], [分布函数的三阶涨落速度矩。], [#source(<sym-heat-flux>)],
  [#typed-symbol([$epsilon$], [标量])], [尺度分离参数], [Chapman–Enskog 展开中的形式小参数，通常取 $O("Kn")$。], [#source(<sym-scale-separation>)],
  [#typed-symbol([$#drho$], [标量])], [密度扰动], [弱可压缩极限中相对参考密度的小扰动。], [#source(<sym-density-perturbation>)],
)

#pagebreak(weak: true)
== 格子模型与离散演化

#symbols(
  [#typed-symbol([$bold(e)_i$], [向量])], [整数速度向量], [描述规则格子上的离散方向与步长。], [#source(<sym-integer-velocity>)],
  [#typed-symbol([$c$], [标量])], [格子速度尺度], [定义为 $#dx/#dt$；不要与离散速度向量 $bold(c)_i$ 混用。], [#source(<sym-lattice-speed>)],
  [#typed-symbol([$bold(c)_i$], [向量])], [物理离散速度], [定义为 $c bold(e)_i$；与连续微观速度 $bold(xi)$ 分属不同层次。], [#source(<sym-discrete-velocity>)],
  [#typed-symbol([$w_i$], [标量])], [格子权重], [离散速度求积权重，满足归一化和各向同性矩条件。], [#source(<sym-lattice-weight>)],
  [#typed-symbol([$c_s$], [标量])], [格子声速], [标准等温格子满足 $c_s^2=c^2/3$。], [#source(<sym-lattice-sound-speed>)],
  [#typed-symbol([$f_i$], [分布分量])], [离散分布函数], [沿第 $i$ 个离散速度携带的分布分量。], [#source(<sym-discrete-distribution>)],
  [#typed-symbol([$f_i^("eq")$], [分布分量])], [离散平衡分布], [离散分布函数在局部平衡条件下的第 $i$ 个分量。], [#source(<sym-discrete-equilibrium>)],
  [#typed-symbol([$overline(f)_i$], [分布分量])], [变换后离散分布], [二阶时间积分后实际存储和演化的变量。], [#source(<sym-transformed-distribution>)],
  [#typed-symbol([$overline(f)_i^star$], [分布分量])], [碰撞后分布], [碰撞完成、迁移尚未发生时的中间状态。], [#source(<sym-post-collision-distribution>)],
  [#typed-symbol([$omega$], [标量])], [离散松弛率], [SRT／BGK 碰撞参数，$omega=#dt/overline(tau)$。], [#source(<sym-relaxation-rate>)],
  [#typed-symbol([$overline(tau)$], [标量])], [离散松弛时间], [满足 $overline(tau)=tau_k+#dt/2$。], [#source(<sym-discrete-relaxation-time>)],
  [#typed-symbol([$S_i$], [源项分量])], [离散外力源项], [第 $i$ 个离散速度上的源项分量。], [#source(<sym-forcing-source>)],
  [#typed-symbol([$#du$], [向量])], [平衡速度偏移], [某些外力方案中施加于平衡速度的有限改变量。], [#source(<sym-velocity-shift>)],
  [#typed-symbol([$#df$], [向量])], [分布扰动向量], [线性稳定分析中相对均匀状态的小扰动。], [#source(<sym-distribution-perturbation>)],
  [#typed-symbol([$bold(M)$], [矩阵])], [矩变换矩阵], [把离散分布映射到矩空间。], [#source(<sym-moment-transform>)],
  [#typed-symbol([$bold(S)$], [矩阵])], [矩空间松弛矩阵], [通常为对角矩阵；不要与源项 $S_i$ 混用。], [#source(<sym-relaxation-matrix>)],
  [#typed-symbol([$s_nu$], [标量])], [剪切模态松弛率], [MRT 中决定运动黏度的松弛率。], [#source(<sym-shear-relaxation>)],
  [#typed-symbol([$bold(k)$], [向量])], [波数向量], [线性稳定分析中的空间 Fourier 模态参数。], [#source(<sym-wave-vector>)],
  [#typed-symbol([$bold(A)$], [矩阵])], [一步放大矩阵], [描述给定波数下分布扰动的一步线性更新。], [#source(<sym-amplification-matrix>)],
)

#pagebreak()
