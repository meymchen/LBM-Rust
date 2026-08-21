#import "../figures/lbm-foundations.typ": d1q3, d2q9, d3q-comparison, lbm-step
#import "../symbols.typ": df, dt, du, dx

#pagebreak(weak: true)
= 格子模型与离散演化 <lbm>

LBM 用有限个离散速度 $bold(c)_i$ 代替连续微观速度 $bold(xi)$，在每个格点保存离散分布 $f_i$。模型名称写成 D$d$Q$Q$：$d$ 是物理空间维数，$Q$ 是离散速度数目。维数决定能表示的几何方向，速度数目决定能准确匹配哪些速度矩；$Q$ 较大不自动意味着所有问题都更准确。
#metadata("sym-velocity-count") <sym-velocity-count>
#metadata("sym-discrete-distribution") <sym-discrete-distribution>

本章先介绍一维、二维和三维常用模型，再给出统一的平衡、碰撞和迁移公式。具体算例与数据结构留到代码实践中讨论。

LBM 的形成经历了从格子气自动机到离散分布演化的转变。Frisch、Hasslacher 与 Pomeau 证明了具有足够格子对称性的格子气自动机能够恢复 Navier–Stokes 方程 @frisch1986；McNamara 与 Zanetti 随后直接演化相应的 Boltzmann 分布，避开逐次统计布尔粒子占据数的做法 @mcnamara1988。Qian、d'Humières 与 Lallemand 给出的格子 BGK 模型则确立了后来常用的单松弛时间离散形式 @qian1992。本章从这些历史结果所形成的现代离散速度表述出发，不再展开格子气自动机的布尔碰撞规则。

== 先认识一维、二维和三维模型 <lattice-families>

设格距和时间步分别为 $#dx$ 与 $#dt$，格子速度尺度为
#metadata("sym-lattice-spacing") <sym-lattice-spacing>

$ c = #dx/#dt. $
#metadata("sym-lattice-speed") <sym-lattice-speed>

标准等温格子的声速满足 $c_s^2=c^2/3$。常用速度集合可以由整数向量 $bold(e)_i$ 表示，物理离散速度为 $bold(c)_i=c bold(e)_i$。
#metadata("sym-lattice-sound-speed") <sym-lattice-sound-speed>
#metadata("sym-integer-velocity") <sym-integer-velocity>

#table(
  columns: (auto, auto, 1fr, 1fr),
  inset: 5pt,
  align: (center, center, left, left),
  [模型], [维数／速度数], [典型用途], [主要限制],
  [D1Q3], [1／3], [一维输运、声学扰动、算法教学], [不能表示横向剪切与多维几何],
  [D2Q9], [2／9], [二维等温弱可压缩流动], [三阶对角矩退化，高马赫数误差明显],
  [D3Q19], [3／19], [三维等温流动，存储与计算量较低], [不是完整张量积，部分高阶各向同性弱于 D3Q27],
  [D3Q27], [3／27], [三维等温流动、高阶平衡与矩空间操作], [每格点存储和迁移量较大],
)

一维模型适合检验守恒、索引和传播方向；二维模型适合建立边界条件与验证流程；三维模型才包含真实三维涡量伸展和三维几何。它们共享同一套碰撞与迁移结构，但不能把一维或二维算例的物理结论直接外推到三维。

== D1Q3：最小的格子模型 <d1q3>

D1Q3 的整数速度为

$ e_0=0, quad e_1=1, quad e_2=-1, $

权重为

$ w_0=2/3, quad w_1=w_2=1/6. $
#metadata("sym-lattice-weight") <sym-lattice-weight>

#figure(
  d1q3,
  caption: [概念示意图：D1Q3 的离散速度与静止平衡分布。],
) <d1q3-diagram>

每个格点保存三个分布。宏观量由

$ rho=sum_(i=0)^2 f_i, quad rho u=sum_(i=0)^2 c_i f_i $

恢复。静止分布留在原格，另两个分布在每个时间步分别移动到左右相邻格点。D1Q3 能表达沿一条坐标轴的压缩与传播，但没有横向自由度，不是二维或三维 Navier–Stokes 方程的廉价替代品。

== D2Q9：二维标准张量积 <d2q9>

D2Q9 由两个 D1Q3 集合做 Cartesian 张量积得到：

$ bold(e)_i in { (a,b) : a,b in {-1,0,1} }. $

它包含一个静止方向、四个轴向方向和四个对角方向。权重按 $bold(e)_i^2$ 分组：

$
w_i = cases(
  4/9 & bold(e)_i^2=0,
  1/9 & bold(e)_i^2=1,
  1/36 & bold(e)_i^2=2.
)
$

#figure(
  d2q9,
  caption: [概念示意图：D2Q9 的索引、离散速度与权重。],
) <d2q9-diagram>

二维密度和动量仍由统一矩公式恢复：

$
rho=sum_(i=0)^8 f_i, quad
rho bold(u)=sum_(i=0)^8 bold(c)_i f_i.
$

轴向与对角方向共同保证到四阶的必要各向同性。只有四个轴向速度的 D2Q5 可以用于某些标量扩散方程，却不足以作为标准二维 Navier–Stokes 流体格子。

== D3Q19 与 D3Q27：三维模型

#figure(
  d3q-comparison,
  caption: [概念示意图：D3Q19 与 D3Q27 离散速度的等轴投影。],
) <d3q-comparison-diagram>

@d3q-comparison-diagram 把三类移动速度分开编码。两种模型都有 6 个轴向速度和 12 个面对角速度；D3Q27 还包含 8 个体对角速度。图中的投影长度不表示 $abs(bold(c)_i)$，速度长度仍由三维整数向量计算。

=== D3Q27：完整张量积 <d3q27>

D3Q27 是三个 D1Q3 集合的完整张量积：

$ bold(e)_i in { (a,b,c_z) : a,b,c_z in {-1,0,1} }. $

它的权重也可由一维权重相乘得到，按速度长度分组为

$
w_i = cases(
  8/27 & bold(e)_i^2=0,
  2/27 & bold(e)_i^2=1,
  1/54 & bold(e)_i^2=2,
  1/216 & bold(e)_i^2=3.
)
$

=== D3Q19：删去体对角方向 <d3q19>

D3Q19 从 D3Q27 去掉八个体对角方向，只保留 $bold(e)_i^2<=2$ 的速度。其权重为

$
w_i = cases(
  1/3 & bold(e)_i^2=0,
  1/18 & bold(e)_i^2=1,
  1/36 & bold(e)_i^2=2.
)
$

两者都有 $c_s^2=c^2/3$，都能构造常用的二阶等温平衡分布。D3Q19 每格点少保存八个分布，常被用作三维基线；D3Q27 的张量积结构更完整，做高阶 Hermite 展开、中心矩碰撞或研究旋转各向同性时通常更方便。选择时应比较目标矩、边界误差、稳定性和实际吞吐量，而不是只比较 $Q$。

== 离散平衡与宏观量 <equilibrium>

对 D1Q3、D2Q9、D3Q19 和 D3Q27，常用的二阶等温平衡分布可以统一写成

$
f_i^("eq") = w_i rho [
1 + (bold(c)_i dot bold(u))/c_s^2
+ (bold(c)_i dot bold(u))^2/(2c_s^4)
- bold(u)^2/(2c_s^2)
].
$ <second-order-equilibrium>
#metadata("sym-discrete-equilibrium") <sym-discrete-equilibrium>

它是局部 Maxwell 分布关于 $bold(u)/c_s$ 的二阶截断，而不是独立的经验公式。离散速度与权重满足相应各向同性关系时，平衡矩为

$
sum_i f_i^("eq") &= rho, \
sum_i bold(c)_i f_i^("eq") &= rho bold(u), \
sum_i bold(c)_i ⊗ bold(c)_i f_i^("eq")
&= rho c_s^2 bold(I)+rho bold(u) ⊗ bold(u).
$ <discrete-equilibrium-moments>

于是等温状态方程为

$ p=rho c_s^2. $ <lbm-equation-of-state>

LBM 通过小幅密度变化表达压力，属于弱可压缩方法。若参考密度为 $rho_0$，不可压缩极限中的动力压力可写成 $p^prime=c_s^2(rho-rho_0)$；把全部 $rho c_s^2$ 当成需要与不可压缩压力绝对值逐点比较的量，通常没有意义。

== 碰撞、迁移与松弛时间 <collision-streaming>

先忽略外力。连续离散速度 BGK 方程沿特征线作二阶时间积分后，实际存储的是经过变量变换的分布 $overline(f)_i$。单松弛时间碰撞写为
#metadata("sym-transformed-distribution") <sym-transformed-distribution>

$
overline(f)_i^star
= overline(f)_i - omega [overline(f)_i-f_i^("eq")], quad
omega=#dt/overline(tau).
$ <srt-collision>
#metadata("sym-post-collision-distribution") <sym-post-collision-distribution>
#metadata("sym-relaxation-rate") <sym-relaxation-rate>

随后沿格线迁移：

$
overline(f)_i (bold(x)+bold(c)_i #dt,t+#dt)
= overline(f)_i^star (bold(x),t).
$ <lattice-streaming>

#figure(
  lbm-step,
  caption: [概念示意图：求矩、求平衡、碰撞和迁移组成一个时间步。],
) <lbm-step-diagram>

物理 BGK 松弛时间 $tau_k$ 与离散松弛时间的关系是

$ overline(tau)=tau_k+#dt/2. $ <relaxation-shift>

因此运动黏度为

$
nu=c_s^2 tau_k
=c_s^2[overline(tau)-#dt/2]
=c_s^2 #dt (1/omega-1/2).
$ <derived-viscosity>

在格子单位 $#dx=#dt=1$ 下，$c=1$、$c_s^2=1/3$，于是

$ nu=1/3(1/omega-1/2)=1/3[overline(tau)-1/2]. $

正黏度要求 $0<omega<2$，等价于 $overline(tau)>#dt/2$。这只是必要条件，不是稳定性保证。过大的局部速度、负平衡分布、边界重构误差和未解析的网格尺度都可能在这个区间内导致发散。

== 手工走过 D1Q3 的一步 <d1q3-step>

以格子单位中的 D1Q3 为例，一个时间步是：

1. 用 $rho=sum_i overline(f)_i$ 和 $rho u=sum_i c_i overline(f)_i$ 计算宏观量。
2. 用@second-order-equilibrium 计算三个 $f_i^("eq")$。
3. 用@srt-collision 完成本地碰撞。
4. 把三个碰撞后分布按 $c_i$ 迁移到相邻格点。

均匀静止状态满足 $overline(f)_i=f_i^("eq")=w_i rho_0$。碰撞差为零，迁移只交换相同数值，所以状态应保持不变。这个测试能同时检查权重、速度索引、碰撞符号和周期迁移。

== 外力项与物理速度 <lbm-forcing>

设 $bold(F)$ 为单位体积的力。带离散源项的更新可写成

$
overline(f)_i (bold(x)+bold(c)_i #dt,t+#dt)
=overline(f)_i (bold(x),t)
-omega[overline(f)_i-f_i^("eq")]
+#dt S_i.
$ <forced-lbe>
#metadata("sym-forcing-source") <sym-forcing-source>

二阶一致的常用选择是 Guo 型源项：

$
S_i = w_i [1-#dt/(2 overline(tau))]
[
(bold(c)_i-bold(u))/c_s^2
+ ((bold(c)_i dot bold(u))bold(c)_i)/c_s^4
] dot bold(F).
$ <guo-force>

用于平衡分布和输出的物理速度包含半时间步冲量：

$
rho bold(u)
=sum_i bold(c)_i overline(f)_i + #dt/2 bold(F).
$ <force-corrected-velocity>

@guo-force 与 @force-corrected-velocity 是一组，不能只取其中一个。若已知的是单位质量体力 $bold(g)$，先用 $bold(F)=rho bold(g)$ 转成力密度。不同外力方案对高阶矩的误差不同；强力、强密度梯度或多相问题不能仅凭“速度加偏移”判断一致性 @hosseini2023。

常见替代方案还包括把平衡速度平移 $#du=overline(tau)bold(F)/rho$ 的 Shan–Chen 形式，以及用两个平衡分布之差表示冲量的 exact difference method。它们都能恢复目标的一阶力矩，但二阶矩和 $bold(F) ⊗ bold(F)$ 型高阶误差不同。弱力极限下看似相同的方案，在强力或非均匀力场中未必等价。
#metadata("sym-velocity-shift") <sym-velocity-shift>

== 边界条件是离散模型的一部分 <lbm-boundaries>

迁移后，来自计算域外的某些分布未知，边界条件要重构这些入射分布。宏观条件与离散规则之间不是一一对应，必须结合格子、碰撞模型和边界位置解释误差。

- 周期边界把离开一侧的同方向分布送入另一侧，适合无端点的代表性区域，也最适合先检查全局守恒。
- 半格反弹把撞向静止固壁的碰撞后分布沿反方向送回。若反向索引满足 $bold(c)_(overline(i))=-bold(c)_i$，基本关系是 $overline(f)_(overline(i))(bold(x)_f,t+#dt)=overline(f)_i^star (bold(x)_f,t)$。在直壁、规则网格和适当碰撞参数下，它把无滑移壁面放在流体节点与固体节点之间。
- 速度或压力边界通过已知宏观矩与已迁移分布重构未知方向。给定密度在等温 LBM 中等价于给定压力，因为 $p=rho c_s^2$。入口与出口离得太近时，重构误差会污染整个流场。
- 曲面边界通常需要插值反弹、浸入边界或体素化几何。几何阶数、守恒和局部稳定性要分别验证。

边界误差可能高于体内离散误差。报告“二阶 LBM”时，必须说明二阶指平衡截断、时空离散还是包含边界后的整体收敛阶。

== 碰撞模型与稳定性 <collision-models>

SRT／BGK 把所有非守恒模态用同一个 $omega$ 松弛，接口最简单，但黏度和高阶模态阻尼被绑在一起。其他常用碰撞模型改变的是非守恒子空间中的松弛方式：

- TRT 把关于反向速度的偶部与奇部分开松弛，可以在保持目标剪切黏度的同时调节边界相关模态。
- MRT 先把分布映射到矩空间，再给不同矩指定松弛率。守恒矩的松弛率为零，剪切矩的松弛率决定黏度，其余速率用于控制非流体模态。
- 中心矩方法使用 $bold(c)_i-bold(u)$ 构造矩，碰撞更贴近随流参考系，但变换和高阶平衡更复杂。
- 正则化方法从允许的低阶 Hermite 系数重建非平衡分布，过滤格子不能可靠表示的高阶分量。
- 熵型方法用离散凸熵限制碰撞路径，关注正性与熵单调性；它不是把 $f_i<0$ 在更新后直接截成零。

稳定性至少受四类条件约束：平衡分布与碰撞后分布的正性、线性扰动谱、离散速度矩的一致性，以及边界和外力造成的非正规增长。$overline(tau)>#dt/2$ 只保证名义黏度为正。对标准二阶平衡，保持 $"Ma"=abs(bold(u))/c_s$ 足够小，同时做网格与时间尺度收敛，仍是最可靠的起点。

== 验证顺序与 Rust 基线 <rust-implementation>

建议按维数和物理难度逐层验证：

1. D1Q3 周期数组：均匀状态、单个分布迁移和总质量。
2. D2Q9 周期区域：平衡矩、方向索引和全局动量。
3. D2Q9 平直通道：反弹位置、Poiseuille 解析解和网格收敛。
4. D2Q9 方腔或涡衰减：二维惯性、黏度与时间精度。
5. D3Q19／D3Q27：三维索引、各向同性以及与二维退化解的一致性。

LBM-Rust 当前以 D2Q9 平衡分布作为确定性数据示例。在 $rho=1$、$bold(u)=(0.08,0.02)$ 时，Rust 程序计算九个 $f_i^("eq")$；完整输出见#ref(<reproducible-data>)。

#figure(
  image("../assets/generated/d2q9-equilibrium.svg", width: 92%),
  caption: [数据图：$rho=1$、$bold(u)=(0.08,0.02)$ 时的 D2Q9 平衡分布、静止权重及二者偏差。子图 b 以零为基线，蓝色标出非负偏差，棕红色标出负偏差。数据由 `examples/d2q9-equilibrium` 生成。],
) <d2q9-equilibrium-plot>

这张图只显示给定输入下的确定性结果。质量与动量恢复由数值测试验证，不能凭曲线外观代替不变量检查。维护者可运行 `make regenerate` 更新数据，再用 `make check-generated` 检查代码与文档资产是否一致。

== 进阶阅读：Hermite 展开与 Gauss–Hermite 求积 <advanced-hermite-quadrature>

令 Gaussian 权函数为

$
omega(bold(xi))
=1/(2pi c_s^2)^(d/2)
 exp[-bold(xi)^2/(2c_s^2)].
$

张量 Hermite 多项式定义为

$
bold(H)^(n)(bold(xi))
=(-c_s^2)^n/omega(bold(xi))
nabla_bold(xi)^n omega(bold(xi)).
$

前几阶为

$
bold(H)^(0)&=1, \
bold(H)^(1)&=bold(xi), \
bold(H)^(2)&=bold(xi) ⊗ bold(xi)-c_s^2 bold(I).
$

在相应加权函数空间中，分布可展开成

$
f(bold(xi))=omega(bold(xi))
sum_(n=0)^infinity 1/(n! c_s^(2n))
bold(a)^(n):bold(H)^(n)(bold(xi)),
$ <hermite-expansion>

其中冒号表示同阶张量的全缩并，系数 $bold(a)^(n)$ 是相应 Hermite 矩。等温 Maxwell 平衡的系数满足

$ bold(a)_eq^(n)=rho underbrace(bold(u) ⊗ dots ⊗ bold(u))_n. $

截断到 $n=2$ 就得到@second-order-equilibrium 的多项式部分。截断只控制保留了哪些 Hermite 模态；还必须选择足够精确的求积，才能用有限求和恢复这些模态的矩。

若 $(bold(c)_i,w_i)$ 是 Gaussian 权下的求积点与权重，则定义离散分布

$ f_i = w_i f(bold(c)_i)/omega(bold(c)_i). $

对求积代数精度以内的多项式，有

$ integral omega(bold(xi)) P(bold(xi)) dif bold(xi)=sum_i w_i P(bold(c)_i). $

标准等温 Navier–Stokes 恢复至少要求离散权重满足

$
sum_i w_i &=1, \
sum_i w_i c_(i alpha)&=0, \
sum_i w_i c_(i alpha)c_(i beta)&=c_s^2 delta_(alpha beta), \
sum_i w_i c_(i alpha)c_(i beta)c_(i gamma)&=0, \
sum_i w_i c_(i alpha)c_(i beta)c_(i gamma)c_(i delta)
&=c_s^4(
delta_(alpha beta)delta_(gamma delta)
+delta_(alpha gamma)delta_(beta delta)
+delta_(alpha delta)delta_(beta gamma)).
$ <isotropy-relations>

这些等式比“速度图看起来对称”更强。它们说明离散集合在目标矩阶数内没有偏爱的 Cartesian 方向。

== 进阶阅读：矩匹配、乘积平衡与熵平衡 <advanced-equilibria>

构造离散平衡的另一条路线是直接匹配目标矩。对等温 Navier–Stokes 方程，需要正确恢复零阶、一阶、二阶以及进入黏性应力的一部分三阶平衡矩：

$
Pi_(alpha beta)^("eq")
&=rho u_alpha u_beta+rho c_s^2 delta_(alpha beta), \
Pi_(alpha beta gamma)^("eq")
&=rho u_alpha u_beta u_gamma
+rho c_s^2(
u_alpha delta_(beta gamma)
+u_beta delta_(alpha gamma)
+u_gamma delta_(alpha beta)).
$ <continuous-equilibrium-tensors>

对完整的 D$d$Q$3^d$ 张量积格子，可定义一维因子

$
Psi_0(xi,zeta)&=1-zeta, \
Psi_1(xi,zeta)&=(zeta+xi)/2, \
Psi_(-1)(xi,zeta)&=(zeta-xi)/2,
$

并写出乘积平衡

$
f_i^("eq")=rho product_(alpha=1)^d
Psi_(e_(i alpha))
(u_alpha/c, c_s^2/c^2+u_alpha^2/c^2).
$ <product-equilibrium>

它在 D2Q9 和 D3Q27 上自然成立，展开到 $O("Ma"^2)$ 后回到@second-order-equilibrium；保留乘积形式则包含部分更高阶速度项。

熵型平衡不先指定所有高阶矩，而是在质量和动量约束下最小化离散凸泛函

$
H(bold(f))=sum_i f_i ln(f_i/w_i),
$

$
sum_i f_i=rho, quad sum_i bold(c)_i f_i=rho bold(u).
$

Lagrange 乘子给出 $f_i^("eq")=w_i exp(lambda_0+bold(lambda) dot bold(c)_i)$。这类平衡关注正性和离散熵结构，代价是某些二阶或三阶矩不再与连续 Maxwell 矩完全相同。多项式平衡、乘积平衡和熵平衡解决的是不同约束，不能只按公式长度判断优劣。

== 进阶阅读：沿特征线的二阶积分 <advanced-characteristics>

相空间离散后，连续方程为

$
partial_t f_i+bold(c)_i dot nabla f_i
=Omega_i, quad
Omega_i=-1/tau_k (f_i-f_i^("eq")).
$

沿第 $i$ 条特征线从 $t$ 积分到 $t+#dt$：

$
f_i (bold(x)+bold(c)_i #dt,t+#dt)-f_i (bold(x),t)
=integral_t^(t+#dt) Omega_i (t^prime) dif t^prime.
$

梯形公式给出

$
integral_t^(t+#dt) Omega_i dif t^prime
=#dt/2[Omega_i (t)+Omega_i (t+#dt)]
+O(#dt^3),
$

但右端包含新时刻碰撞项。定义变换后的分布

$ overline(f)_i=f_i-#dt/2 Omega_i. $ <population-transform>

碰撞守恒使其低阶矩保持不变：

$
sum_i overline(f)_i=sum_i f_i=rho, quad
sum_i bold(c)_i overline(f)_i=sum_i bold(c)_i f_i=rho bold(u).
$

由 $overline(tau)=tau_k+#dt/2$ 可将碰撞项改写成

$
Omega_i=1/overline(tau)[f_i^("eq")-overline(f)_i].
$

代回梯形公式后，隐式项消失，得到@srt-collision 与 @lattice-streaming。于是经典 collide–stream 不是对连续 BGK 碰撞作一次简单的显式 Euler 积分；它可以由梯形积分和变量变换得到二阶时间一致性。半时间步位移也由此进入@derived-viscosity。

许多代码把存储的 $overline(f)_i$ 仍命名为 `f_i`。这在实现中很方便，但文档与推导必须说明变量变换，否则连续 $tau_k$、离散 $overline(tau)$ 和程序参数会互相混淆。

== 进阶阅读：离散 Chapman–Enskog 展开 <advanced-lattice-ce>

无外力时，把格子方程左侧沿特征线 Taylor 展开：

$
#dt D_i overline(f)_i
+#dt^2/2 D_i^2 overline(f)_i
=-omega[overline(f)_i-f_i^("eq")]+O(#dt^3),
quad D_i=partial_t+bold(c)_i dot nabla.
$ <lbe-taylor>

引入多尺度

$
overline(f)_i&=f_i^("eq")+epsilon f_i^(1)+epsilon^2 f_i^(2)+dots, \
nabla&=epsilon nabla_1, \
partial_t&=epsilon partial_(t_1)+epsilon^2 partial_(t_2),
$

并施加

$ sum_i f_i^(n)=0, quad sum_i bold(c)_i f_i^(n)=bold(0), quad n>=1. $

在 $O(epsilon)$ 上，记 $D_(1i)=partial_(t_1)+bold(c)_i dot nabla_1$，有

$ f_i^(1)=-#dt/omega D_(1i)f_i^("eq"). $ <lattice-first-nonequilibrium>

取零阶与一阶矩并使用@discrete-equilibrium-moments，得到等温 Euler 尺度方程。$O(epsilon^2)$ 上的 $D_(1i)^2$ 项与 $f_i^(1)$ 合并，黏性系数中出现 $1/omega-1/2$。恢复到物理尺度后，

$ partial_t rho+nabla ⋅ (rho bold(u))=0, $

$
partial_t (rho bold(u))
+nabla ⋅ (rho bold(u) ⊗ bold(u))
=-nabla p
+nabla ⋅ {rho nu[nabla bold(u)+(nabla bold(u))^T]}
+O("Ma"^3,#dt^2),
$ <recovered-navier-stokes>

其中 $p=rho c_s^2$，$nu$ 由@derived-viscosity 给出。上式按弱可压缩、近似零散度条件写出；纵向声学模态的体黏性以及不同碰撞模型的高阶修正需要另行分析。

== 进阶阅读：Galilean 不变性与格子退化 <advanced-galilean-invariance>

连续 Maxwell 平衡的三阶矩由@continuous-equilibrium-tensors 给出。标准一阶邻居格子满足逐分量恒等式

$ c_(i alpha)^3=c^2 c_(i alpha). $

因此离散三阶对角矩退化为一阶矩：

$ sum_i c_(i alpha)^3 f_i^("eq")=c^2 rho u_alpha. $

它无法同时表示连续矩中的 $rho u_alpha^3+3rho c_s^2 u_alpha$。当 $c^2=3c_s^2$ 时，线性项正确，但 $rho u_alpha^3$ 丢失。这个误差是 $O("Ma"^3)$，会使有效黏性随参考速度变化，即产生 Galilean 不变性误差。

提高平衡分布的 Hermite 阶数可以修复部分非对角三阶矩，却不能解除 $c_(i alpha)^3=c^2c_(i alpha)$ 造成的对角退化。可选办法包括加入修正源项、使用更多离散速度或采用离格求积。每种办法都会改变计算量、边界实现或守恒性质。

MRT 的一般碰撞形式可以写成

$
bold(f)^star=bold(f)-bold(M)^(-1)bold(S)
[bold(m)-bold(m)^("eq")], quad bold(m)=bold(M)bold(f),
$

其中 $bold(M)$ 是矩变换，$bold(S)$ 通常为对角松弛矩阵。质量和动量对应的对角元取零；剪切模态取 $s_nu$，并满足
#metadata("sym-moment-transform") <sym-moment-transform>
#metadata("sym-relaxation-matrix") <sym-relaxation-matrix>
#metadata("sym-shear-relaxation") <sym-shear-relaxation>

$ nu=c_s^2 #dt (1/s_nu-1/2). $

其余松弛率只能在保持目标宏观矩与稳定性的前提下调整。线性稳定域、分布正性和非线性边界行为是不同问题；只优化其中一个指标，不能保证完整求解器稳定。更系统的理想流体 LBM 离散、外力和稳定性讨论可参阅 @hosseini2023、@krueger2017 与 @succi2018。

线性稳定分析先在均匀状态 $bold(f)_0$ 附近令 $bold(f)=bold(f)_0+#df$，再对空间扰动作 Fourier 分解。对波数 $bold(k)$，一步更新写成
#metadata("sym-distribution-perturbation") <sym-distribution-perturbation>
#metadata("sym-wave-vector") <sym-wave-vector>

$
hat(#df)(bold(k),t+#dt)
=bold(A)(bold(k))hat(#df)(bold(k),t).
$
#metadata("sym-amplification-matrix") <sym-amplification-matrix>

所有可解析波数上 $rho[bold(A)(bold(k))]<=1$ 是线性谱稳定的必要条件，其中 $rho[dot]$ 表示谱半径。若放大矩阵非正规，特征值位于单位圆内仍可能出现显著瞬态增长；边界、非线性平衡与有限精度还会引入均匀 Fourier 分析看不到的失稳途径。
