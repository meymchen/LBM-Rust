#pagebreak(weak: true)
= 格子玻尔兹曼方法（LBM） <lbm>

上一章从控制体出发，得到质量守恒和 Navier–Stokes 动量方程，也介绍了直接离散宏观方程的几类方法。本章改用介观视角：不直接把速度和压力作为全部状态，而是记录不同速度方向上有多少粒子。我们先说明这个计算对象如何来自玻尔兹曼方程，再用一维三速模型完成一个最小时间步，最后扩展到二维 D2Q9。章末的进阶阅读给出平衡分布、离散速度矩和黏度关系的推导；正文使用到的结论都能在本章内找到依据。

== 玻尔兹曼方程只表达两件事 <boltzmann-equation>

连续动力学理论用 $f(bold(x), bold(xi), t)$ 表示位置 $bold(x)$、微观速度 $bold(xi)$ 和时刻 $t$ 上的分布。忽略外力时，玻尔兹曼方程可简写为

$ partial_t f + bold(xi) dot nabla f = Omega(f). $

这条公式在这里不是推导题，只需读成一句话：左侧表示粒子携带分布穿过空间，右侧表示同一位置的粒子通过碰撞重新分配速度。LBM 将前者变成沿格线移动一步，将后者变成每个格子内的局部更新。

真实碰撞算子 $Omega$ 很复杂。BGK 模型用“当前分布向局部平衡分布靠近”代替完整碰撞细节 @bgk1954：

$ Omega(f) = -1/tau_c (f - f^("eq")). $

$f^("eq")$ 是由当前密度和速度决定的平衡分布，$tau_c$ 控制靠近平衡的快慢。现阶段可把它理解为混合强度；它与黏度的具体关系会在离散模型中给出。

连续分布与上一章宏观量之间的联系由速度矩给出。对全部微观速度积分，得到密度和动量：

$ rho = integral f dif bold(xi), quad rho bold(u) = integral bold(xi) f dif bold(xi). $

碰撞可以重新分配粒子的速度，却不能改变同一点的总质量；没有外力时也不能改变总动量。因此碰撞项必须满足

$ integral Omega dif bold(xi) = 0, quad integral bold(xi) Omega dif bold(xi) = bold(0). $

这两条矩约束是第一章守恒定律在介观描述中的表达。LBM 把连续速度积分换成有限方向求和，但仍保留相同约束。

== 为什么最后得到格子模型 <lbm-history>

LBM 的历史也可以看成一条不断简化计算对象的路线：

- 1872 年，Boltzmann 用分布函数和碰撞描述大量分子的统计演化 @boltzmann1872。
- 1954 年，Bhatnagar、Gross 和 Krook 用单一松弛过程近似复杂碰撞 @bgk1954。
- 1986 年，Frisch、Hasslacher 和 Pomeau 证明，在具有足够对称性的格子上迁移和碰撞简单粒子，可以恢复流体的宏观行为 @frisch1986。
- 1988 年，McNamara 和 Zanetti 不再逐个记录只能取“有”或“无”的格子粒子，而是直接演化每个方向上的平均数量，从而显著减少统计噪声 @mcnamara1988。
- 1992 年，Qian、d'Humières 和 Lallemand 给出了简洁的格子 BGK 模型族，其中包括今天常用模型的基本形式 @qian1992。

因此，“格子”让输运成为从一个格点到相邻格点的精确移动，“分布函数”避免逐个模拟粒子，“向平衡态松弛”则把复杂碰撞压缩为便于编程的局部公式。

== 第一个模型：一维三速 D1Q3 <d1q3>

D1Q3 中的 `D1` 表示一维空间，`Q3` 表示三个离散速度。取

$ e_0 = 0, quad e_+ = 1, quad e_- = -1. $

静止分布留在原格，另外两个分布每个时间步分别向右和向左移动一格。对应权重为

$ w_0 = 2/3, quad w_+ = w_- = 1/6. $

每格只需保存 $f_0$、$f_+$ 和 $f_-$。宏观量仍按上一章的方法计算：

$ rho = f_0 + f_+ + f_-, quad rho u = f_+ - f_-. $

在 $rho = 1$、$u = 0$ 的均匀静止状态下，平衡分布就是各权重本身：$f_0^("eq") = 2/3$，$f_+^("eq") = f_-^("eq") = 1/6$。这给出了一个很方便的第一项测试：初始化所有格子后，碰撞和迁移都不应改变均匀状态。

流体运动时，D1Q3 的平衡分布可直接按下面的配方计算：

$ f_i^("eq") = w_i rho [1 + 3 e_i u + 9/2 (e_i u)^2 - 3/2 u^2]. $

把 $i$ 依次换成 $0$、$+$ 和 $-$，并代入各自的速度与权重，就得到三个结果。先检查三个结果之和等于 $rho$、带方向求和后等于 $rho u$。二维模型会复用完全相同的结构；公式的低马赫数展开见本章进阶阅读。

== 手工走过一个时间步 <d1q3-step>

一个 LBM 时间步只有四个基本动作：

1. 求宏观量：把三个分布相加得到 $rho$，把左右分布相减得到 $rho u$。
2. 求平衡态：根据当前 $rho$ 和 $u$ 计算三个 $f_i^("eq")$。
3. 碰撞：让每个 $f_i$ 向对应的 $f_i^("eq")$ 靠近。
4. 迁移：$f_+$ 向右移动一格，$f_-$ 向左移动一格，$f_0$ 留在原格。

离散碰撞写成

$ f_i^star = f_i - 1/tau (f_i - f_i^("eq")), $

其中星号表示碰撞后、迁移前的值。当 $tau = 1$ 时，碰撞一步就到达平衡；当 $tau > 1$ 时，每一步只靠近一部分。随后执行

$ f_i(x + e_i, t + 1) = f_i^star(x, t). $

读者可以从一个周期边界的一维数组开始：所有格子初始化为静止平衡态，只提高中央一格的密度，然后观察扰动向左右传播。这个实验不需要复杂几何，却能暴露方向索引、周期边界、碰撞顺序和质量守恒中的大多数基础错误。

== 从一维扩展到二维 D2Q9 <d2q9>

D2Q9 只是把同一思路扩展到二维：一个静止方向、四个轴向方向和四个对角方向。在格子单位 $Delta x = Delta t = 1$ 下，九个速度为

$ bold(e)_0 = (0, 0), $
$ bold(e)_(1..4) = (1, 0), (0, 1), (-1, 0), (0, -1), $
$ bold(e)_(5..8) = (1, 1), (-1, 1), (-1, -1), (1, -1). $

权重为 $w_0 = 4/9$、$w_(1..4) = 1/9$、$w_(5..8) = 1/36$。密度和二维动量仍是简单求和：

$ rho = sum_i f_i, quad rho bold(u) = sum_i f_i bold(e)_i. $

与 D1Q3 相比，程序结构没有变化，只是每格保存的方向从三个增加到九个。轴向和对角方向的对称排列使模型在宏观尺度上不会偏爱某个格线方向。

== 把平衡分布当作可验证的计算配方 <equilibrium>

D2Q9 常用的等温、低马赫数平衡分布为

$ f_i^("eq") = w_i rho [1 + 3 (bold(e)_i dot bold(u)) + 9/2 (bold(e)_i dot bold(u))^2 - 3/2 bold(u)^2]. $

初学时可以先把它当作输入 $rho$ 和 $bold(u)$、输出九个平衡分布的计算配方。四项分别对应静止权重、速度的一阶影响、方向速度的二阶修正和总速度的二阶修正。实现后应立即验证

$ sum_i f_i^("eq") = rho, quad sum_i f_i^("eq") bold(e)_i = rho bold(u). $

这两个等式说明平衡化没有改变质量和动量，也是比目测流场更可靠的单元测试。该公式来自连续平衡分布的低速展开和离散速度求积，具体步骤见#ref(<advanced-lbm-derivation>)。

== 碰撞、迁移与黏度 <collision-streaming>

把局部碰撞和沿格线迁移合并，可写成

$ f_i(bold(x) + bold(e)_i, t + 1) = f_i(bold(x), t) - 1/tau [f_i(bold(x), t) - f_i^("eq")(bold(x), t)]. $

这就是前面一维时间步在二维中的写法。D2Q9 的格子声速满足 $c_s^2 = 1/3$，运动黏度为

$ nu = c_s^2 (tau - 1/2). $

因此 $tau$ 同时影响碰撞强度和宏观黏度。选择参数时先由目标雷诺数确定格子黏度，再由上式计算 $tau$；不要仅凭“哪个值能运行”来试选。

== 边界条件与逐级验证 <lbm-boundaries>

学习顺序应让每一步只增加一种困难：先用 D1Q3 周期数组检查迁移和守恒，再用 D2Q9 周期区域检查二维方向，随后加入平直固壁反弹，最后才处理入口、出口和复杂几何。

对实际流动，推荐依次验证：

- 均匀静止状态保持不变；
- 平衡分布恢复给定的密度和速度；
- 周期区域的总质量保持不变；
- 平直通道流与解析速度分布一致；
- 网格加密后误差按预期减小。

只有这些基础检查通过后，流场图片和性能数据才有解释价值。

== Rust 实现与可复现数据 <rust-implementation>

LBM-Rust 以清晰的标量实现作为正确性基线，再评估数据布局、多线程、SIMD 和加速后端。核心模型公开 D2Q9 离散速度、权重和平衡分布，并用同一组不变量测试基线与后续优化实现。

当前示例在 $rho = 1$、$bold(u) = (0.08, 0.02)$ 时计算九个方向的平衡分布。完整输出见#ref(<reproducible-data>)，原始 CSV 文件位于 `book/assets/generated/d2q9-equilibrium.csv`。

维护者可以运行 `make regenerate` 重新计算数据，再用 `make check-generated` 验证仓库中的结果是否与当前代码一致。生成程序位于 `examples/d2q9-equilibrium/src/main.rs`。耗时实验不隐式绑定到普通 PDF 构建，性能结论则应记录硬件、工具链、问题规模和统计方法。

== 进阶阅读：从连续分布到格子方程 <advanced-lbm-derivation>

这一节回答三个容易被入门材料略过的问题：二阶平衡分布从哪里来，为什么九个速度足以恢复质量和动量方程，以及黏度公式中的 $-1/2$ 为什么出现。推导针对等温、低马赫数、单松弛时间模型；热流动、多松弛时间和高阶格子需要更多速度矩，但推导方法相同。

=== 局部平衡分布的低速展开

等温气体在局部平衡时采用 Maxwell 分布。略去不影响后续矩关系的归一化细节，可写为

$
f^("eq")(bold(xi))
= rho omega(bold(xi))
  exp((bold(xi) dot bold(u))/c_s^2)
  exp(-bold(u)^2/(2 c_s^2)),
$

其中

$ omega(bold(xi)) = 1/(2 pi c_s^2)^(d/2) exp(-bold(xi)^2/(2 c_s^2)) $

是 $d$ 维、均值为零的 Gaussian 权函数，$c_s$ 是等温声速。低马赫数意味着 $abs(bold(u))/c_s$ 很小。分别展开两个含 $bold(u)$ 的指数函数：

$
exp((bold(xi) dot bold(u))/c_s^2)
= 1 + (bold(xi) dot bold(u))/c_s^2
+ (bold(xi) dot bold(u))^2/(2 c_s^4) + O("Ma"^3),
$

$ exp(-bold(u)^2/(2 c_s^2)) = 1 - bold(u)^2/(2 c_s^2) + O("Ma"^4). $

相乘并保留到速度的二阶项，得到

$
f^("eq")(bold(xi))
= rho omega(bold(xi)) [
  1 + (bold(xi) dot bold(u))/c_s^2
  + (bold(xi) dot bold(u))^2/(2 c_s^4)
  - bold(u)^2/(2 c_s^2)
] + O("Ma"^3).
$ <continuous-equilibrium-expansion>

这一步解释了离散平衡分布中的四项。它不是针对 D2Q9 猜出的多项式，而是连续平衡态在低速条件下的截断。

=== 用有限个速度替代速度积分

接下来要用有限求和近似带有权函数 $omega$ 的速度积分。离散速度 $bold(e)_i$ 和权重 $w_i$ 至少应满足以下各向同性关系：

$ sum_i w_i = 1, quad sum_i w_i e_(i alpha) = 0, $

$ sum_i w_i e_(i alpha) e_(i beta) = c_s^2 delta_(alpha beta), $

$ sum_i w_i e_(i alpha) e_(i beta) e_(i gamma) = 0, $

$
sum_i w_i e_(i alpha) e_(i beta) e_(i gamma) e_(i delta)
= c_s^4 [delta_(alpha beta) delta_(gamma delta)
+ delta_(alpha gamma) delta_(beta delta)
+ delta_(alpha delta) delta_(beta gamma)].
$ <isotropy-relations>

这里的 Greek 下标表示 Cartesian 分量，$delta_(alpha beta)$ 是 Kronecker 符号：两个下标相同时为 1，否则为 0。奇数阶矩为零来自速度集合的正负对称；二阶和四阶关系保证格子在这些矩上没有偏爱的方向。

把公式 @continuous-equilibrium-expansion 中的 $bold(xi)$ 换成 $bold(e)_i$，把连续权函数和求积权重合并为 $w_i$，得到一般形式

$
f_i^("eq") = w_i rho [
1 + (bold(e)_i dot bold(u))/c_s^2
+ (bold(e)_i dot bold(u))^2/(2 c_s^4)
- bold(u)^2/(2 c_s^2)].
$ <general-discrete-equilibrium>

D2Q9 的 $c_s^2 = 1/3$。代入 $1/c_s^2 = 3$ 和 $1/(2c_s^4) = 9/2$，便得到本章前面使用的平衡分布。

现在直接验证它的前三个矩。使用公式 @isotropy-relations，零阶矩为

$
sum_i f_i^("eq")
= rho [1 + bold(u)^2/(2c_s^2) - bold(u)^2/(2c_s^2)]
= rho.
$

一阶矩中，常数项和 $bold(u)^2$ 项乘上奇数阶速度矩后为零，线性项给出

$ sum_i e_(i alpha) f_i^("eq") = rho u_alpha. $

二阶矩使用二阶和四阶各向同性关系，结果是

$
Pi_(alpha beta)^("eq")
:= sum_i e_(i alpha) e_(i beta) f_i^("eq")
= rho c_s^2 delta_(alpha beta) + rho u_alpha u_beta.
$ <equilibrium-second-moment>

右侧第一项是各向同性压力，因而等温 LBM 的状态方程为

$ p = rho c_s^2. $ <lbm-equation-of-state>

第二项是宏观动量通量。零阶、一阶和二阶矩分别恢复质量、动量和压力加对流动量，这正是 D2Q9 能连接到宏观流体方程的原因。

=== 从 BGK 方程到碰撞和迁移

把连续速度限制为 $bold(e)_i$ 后，离散速度 BGK 方程为

$ partial_t f_i + bold(e)_i dot nabla f_i = -1/tau_c (f_i - f_i^("eq")). $

沿第 $i$ 个方向的特征线满足 $dif bold(x)/dif t = bold(e)_i$。因此左侧是沿该特征线的全导数：

$ (dif f_i)/(dif t) = partial_t f_i + bold(e)_i dot nabla f_i. $

在一个时间步 $Delta t$ 内显式积分碰撞项，并定义无量纲松弛时间 $tau = tau_c/Delta t$，得到

$
f_i(bold(x) + bold(e)_i Delta t, t + Delta t)
- f_i(bold(x), t)
= -1/tau [f_i(bold(x),t) - f_i^("eq")(bold(x),t)].
$

选择速度集合时让 $bold(e)_i Delta t$ 恰好连接相邻格点，左侧便不是近似的空间插值，而是从一个数组位置精确搬到另一个位置。右侧只依赖当前格点。于是一次更新自然拆成

$ f_i^star = f_i - 1/tau (f_i - f_i^("eq")) $

和

$ f_i(bold(x) + bold(e)_i Delta t,t + Delta t) = f_i^star(bold(x),t). $

前者是局部碰撞，后者是沿格线迁移。对碰撞式求零阶矩和一阶矩，并使用平衡态与当前态具有相同的 $rho$ 和 $rho bold(u)$，立即得到

$ sum_i f_i^star = sum_i f_i, quad sum_i bold(e)_i f_i^star = sum_i bold(e)_i f_i. $

因此碰撞严格保持局部质量和动量；迁移只在格点之间搬运这些量。在周期区域中，把所有格点再求和，进入一个格点的分布总能在相邻格点找到对应的流出项，所以全局质量也保持不变。

=== 宏观极限与黏度中的半个时间步

最后说明离散格子方程如何恢复 Navier–Stokes 方程。记沿特征线的微分算子为

$ D_i = partial_t + bold(e)_i dot nabla. $

对格子方程左侧在 $Delta t$ 上作 Taylor 展开到二阶：

$
Delta t D_i f_i + (Delta t^2)/2 D_i^2 f_i
= -1/tau (f_i - f_i^("eq")) + O(Delta t^3).
$ <lbe-taylor>

引入表示宏观尺度缓慢变化的参数 $epsilon$，作 Chapman–Enskog 多尺度展开：

$
f_i = f_i^("eq") + epsilon f_i^(1) + epsilon^2 f_i^(2) + dots,
quad nabla = epsilon nabla_1,
quad partial_t = epsilon partial_(t_1) + epsilon^2 partial_(t_2).
$

碰撞守恒要求非平衡修正不携带质量和动量：

$ sum_i f_i^(k) = 0, quad sum_i bold(e)_i f_i^(k) = bold(0), quad k >= 1. $

把展开代入公式 @lbe-taylor。记 $D_i^(1) = partial_(t_1) + bold(e)_i dot nabla_1$。$epsilon$ 的一阶项给出

$ Delta t D_i^(1) f_i^("eq") = -1/tau f_i^(1), $

所以

$ f_i^(1) = -tau Delta t D_i^(1) f_i^("eq"). $ <first-nonequilibrium>

对一阶方程分别求零阶矩和一阶矩，并使用平衡矩关系，可得宏观尺度上的 Euler 方程：

$ partial_(t_1) rho + nabla_1 dot (rho bold(u)) = 0, $

$
partial_(t_1)(rho bold(u))
+ nabla_1 dot [rho bold(u) bold(u) + rho c_s^2 bold(I)] = bold(0).
$

$epsilon^2$ 的项为

$
Delta t [partial_(t_2) f_i^("eq") + D_i^(1) f_i^(1)]
+ (Delta t^2)/2 (D_i^(1))^2 f_i^("eq")
= -1/tau f_i^(2).
$

用公式 @first-nonequilibrium 消去 $D_i^(1) f_i^("eq")$ 后，两个二阶导数项合并，系数变为 $tau - 1/2$。对该式求一阶矩，非平衡二阶矩产生黏性应力：

$
Pi_(alpha beta)^("neq")
= -rho c_s^2 (tau - 1/2) Delta t
  [partial_alpha u_beta + partial_beta u_alpha]
$

，其中略去了低马赫数下的高阶可压缩修正。把 $t_1$ 和 $t_2$ 两个时间尺度重新合并，便得到

$ partial_t rho + nabla dot(rho bold(u)) = 0, $

$
partial_t(rho bold(u))
+ nabla dot(rho bold(u) bold(u))
= -nabla p + nabla dot {
rho nu [nabla bold(u) + (nabla bold(u))^T]
},
$

其中

$ p = rho c_s^2, quad nu = c_s^2 (tau - 1/2) Delta t. $ <derived-viscosity>

在格子单位 $Delta x = Delta t = 1$ 下，这就是前文的 $nu = c_s^2(tau - 1/2)$。$-1/2$ 来自离散迁移的二阶 Taylor 项，而不是碰撞时间的经验修正。为得到正黏度必须有 $tau > 1/2$；但这只是必要条件，实际稳定性还受速度、网格、边界和流动状态影响。

这套推导还说明了基础 D2Q9-BGK 模型的适用边界：平衡分布截断到 $O("Ma"^2)$，宏观方程忽略了更高阶可压缩误差，压力由密度通过 $p = rho c_s^2$ 给出。因此它最自然地用于等温、低马赫数、近似不可压缩的流动。完整的 Chapman–Enskog 记号体系和高阶修正可与 @krueger2017、@succi2018 对照，但本书后续实现只使用本节已经推得的关系。
