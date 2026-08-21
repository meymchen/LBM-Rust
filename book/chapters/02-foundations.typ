#import "../symbols.typ": drho, dt

#pagebreak(weak: true)
= 从 Boltzmann 方程到流体力学 <boltzmann-equation>

连续介质力学把密度、速度和压力当作基本未知量。动力学理论换了一个观察尺度：它记录粒子在位置与速度空间中的统计分布，再用速度矩恢复宏观量。这个中间层次正是 LBM 的理论起点。

本章先约定符号，再讨论输运、碰撞、局部平衡和矩方程。正文给出后续建模必须掌握的结构，章末进阶阅读补全碰撞积分、$H$ 定理和 Chapman–Enskog 展开。这里讨论的是理想单组分气体；非理想相互作用不在本章范围内。

== 符号与描述层次 <kinetic-notation>

空间维数记为 $d$，位置、微观速度和宏观流速分别写成 $bold(x)$、$bold(xi)$ 和 $bold(u)$。连续速度使用 $bold(xi)$，下一章的离散速度使用 $bold(c)_i$；二者不混用。Cartesian 分量用 Greek 下标表示，例如 $xi_alpha$、$u_alpha$。重复的 Greek 下标默认求和，而离散速度下标 $i$ 的求和始终显式写出。
#metadata("sym-dimension") <sym-dimension>
#metadata("sym-microscopic-velocity") <sym-microscopic-velocity>
#metadata("sym-discrete-velocity") <sym-discrete-velocity>
#metadata("sym-cartesian-indices") <sym-cartesian-indices>
#metadata("sym-discrete-index") <sym-discrete-index>

本书采用质量分布函数 $f(bold(x), bold(xi), t)$。因此 $f dif bold(xi)$ 是单位物理体积内、微观速度落在 $dif bold(xi)$ 中的质量，宏观密度和动量为
#metadata("sym-continuous-distribution") <sym-continuous-distribution>

$
rho = integral f dif bold(xi), quad
rho bold(u) = integral bold(xi) f dif bold(xi).
$ <continuous-moments>

速度积分覆盖整个 $RR^d$。定义涨落速度（peculiar velocity）

$ bold(C) = bold(xi) - bold(u). $
#metadata("sym-peculiar-velocity") <sym-peculiar-velocity>

由于 $bold(u)$ 已是质量加权平均速度，必有 $integral bold(C) f dif bold(xi) = bold(0)$。这个恒等式会消去许多一阶中心矩。

需要区分三类时间尺度。$tau_k$ 表示连续 BGK 方程中的物理松弛时间；$#dt$ 是数值时间步；下一章的 $overline(tau)$ 是梯形积分后出现在碰撞公式中的离散松弛时间。把它们都写成 $tau$ 会掩盖半时间步修正，也是许多黏度公式错误的来源。
#metadata("sym-physical-relaxation-time") <sym-physical-relaxation-time>
#metadata("sym-time-step") <sym-time-step>
#metadata("sym-discrete-relaxation-time") <sym-discrete-relaxation-time>

== 自由输运与碰撞 <kinetic-transport>

没有外力时，Boltzmann 输运方程写作

$ partial_t f + bold(xi) dot nabla_bold(x) f = Omega_B [f]. $ <continuous-boltzmann>

左侧是自由输运。若暂时令碰撞项为零，分布沿特征线 $bold(x)(t)=bold(x)_0+bold(xi)t$ 保持不变。右侧的 $Omega_B$ 是碰撞算子，它在同一空间位置重新分配微观速度。
#metadata("sym-boltzmann-collision") <sym-boltzmann-collision>

存在单位质量体力 $bold(g)$ 时，粒子在速度空间中也发生平移：

$
partial_t f + bold(xi) dot nabla_bold(x) f
+ bold(g) dot nabla_bold(xi) f = Omega_B [f].
$ <forced-boltzmann>

这里 $bold(g)$ 的量纲是加速度，力密度为 $bold(F)=rho bold(g)$。后续离散外力项必须恢复 $bold(F)$ 的一阶矩；仅在平衡速度中随意加一个偏移，通常不能保证二阶精度。
#metadata("sym-force-density") <sym-force-density>

稀薄单原子气体的 Boltzmann 碰撞算子建立在五项假设上：二体碰撞、碰撞在时空上局部、弹性碰撞、微观动力学可逆，以及碰撞前两个粒子的速度不相关，即分子混沌假设。碰撞改变单个粒子的速度，却保持碰撞对的质量、动量和动能。

完整碰撞积分较昂贵。BGK 模型用单一松弛过程替代它 @bgk1954：

$
partial_t f + bold(xi) dot nabla_bold(x) f
= -1/tau_k [f - f^("eq")], quad tau_k > 0.
$ <continuous-bgk>

$f^("eq")$ 不是任意目标函数。它必须与 $f$ 具有相同的质量、动量和能量，否则碰撞会产生这些守恒量。BGK 模型保留了通向流体方程所需的低阶矩结构，但用一个松弛时间控制所有非守恒模态，因此对热流动会固定 Prandtl 数为 1。

== 碰撞不变量与守恒律 <collision-invariants>

若某个微观量 $phi(bold(xi))$ 在每次弹性二体碰撞前后满足

$ phi + phi_1 = phi^prime + phi_1^prime, $

它就是碰撞不变量。对无内部自由度的单原子粒子，所有碰撞不变量都属于

$ "span" {1, bold(xi), bold(xi)^2}. $

因此 Boltzmann 碰撞算子满足

$
integral Omega_B dif bold(xi) = 0, quad
integral bold(xi) Omega_B dif bold(xi) = bold(0), quad
integral 1/2 bold(xi)^2 Omega_B dif bold(xi) = 0.
$ <collision-conservation>

分别对@continuous-boltzmann 取这三个矩，便得到质量、动量和总能量的局部守恒。由此可见，宏观守恒律不是离散算法额外施加的修补，而是碰撞算子的零空间在宏观尺度上的投影。

== 局部 Maxwell 平衡 <maxwell-equilibrium>

对理想单原子气体，给定 $rho$、$bold(u)$ 和温度 $T$ 后，局部平衡分布为

$
f^("eq")(bold(xi))
= rho/(2 pi R T)^(d/2)
  exp[-bold(C)^2/(2 R T)].
$ <maxwell-boltzmann>
#metadata("sym-continuous-equilibrium") <sym-continuous-equilibrium>

$R$ 是比气体常数。称它为“局部平衡”，是因为 $rho(bold(x),t)$、$bold(u)(bold(x),t)$ 和 $T(bold(x),t)$ 仍可随时空变化。此时碰撞项为零，但自由输运项一般不为零；只有这些参数均匀且稳定时，$f^("eq")$ 才是全局平衡解。

Maxwell 分布的低阶矩为

$
integral f^("eq") dif bold(xi) &= rho, \
integral bold(xi) f^("eq") dif bold(xi) &= rho bold(u), \
integral bold(C) ⊗ bold(C) f^("eq") dif bold(xi) &= rho R T bold(I).
$ <maxwell-moments>

因此理想气体状态方程为 $p=rho R T$。在等温模型中，$R T$ 是常数，下一章把它记为格子声速平方 $c_s^2$。

== 矩、通量与封闭问题 <moment-hierarchy>

定义二阶中心矩，即动力学压力张量，

$ bold(P) = integral bold(C) ⊗ bold(C) f dif bold(xi), $
#metadata("sym-pressure-tensor") <sym-pressure-tensor>

以及热流

$ bold(q) = integral 1/2 bold(C)^2 bold(C) f dif bold(xi). $
#metadata("sym-heat-flux") <sym-heat-flux>

总能量密度为

$
rho E=integral 1/2 bold(xi)^2 f dif bold(xi)
=rho e+1/2 rho bold(u)^2,
$

单原子理想气体的比内能为 $e=d R T/2$。在三维中，$rho$、$rho bold(u)$、对称的 $bold(P)$ 和 $bold(q)$ 合计 13 个独立场，这就是 Grad 13 矩描述所使用的变量组。

把压力张量分解为

$ bold(P) = p bold(I) + bold(Pi)^("neq"), $

其中 $bold(Pi)^("neq")$ 是非平衡压力。使用@collision-conservation，可以从动力学方程精确得到

$ partial_t rho + nabla ⋅ (rho bold(u)) = 0, $ <kinetic-continuity>

$
partial_t (rho bold(u))
+ nabla ⋅ [rho bold(u) ⊗ bold(u) + bold(P)]
= rho bold(g).
$ <kinetic-momentum>

总能量方程为

$
partial_t (rho E)
+nabla ⋅ [
(rho E+p)bold(u)
+bold(Pi)^("neq") dot bold(u)
+bold(q)]
=rho bold(g) dot bold(u).
$ <kinetic-energy>

这些方程尚未封闭，因为 $bold(P)$ 和 $bold(q)$ 取决于完整分布 $f$。若继续对更高阶速度矩写方程，又会出现更高一阶的矩。动力学理论因此形成矩层级：低阶场的演化依赖高阶通量。

直接令 $f=f^("eq")$ 时，$bold(Pi)^("neq")=bold(0)$ 且 $bold(q)=bold(0)$，得到可压缩 Euler 方程。黏性和热传导都来自偏离局部平衡的第一阶修正。Chapman–Enskog 方法正是按尺度分离计算这个修正。

== 流体动力学极限 <hydrodynamic-limit>

平均自由程 $lambda$ 与宏观特征长度 $L$ 的比值

$ "Kn" = lambda/L $

衡量非平衡程度。$"Kn" << 1$ 时，碰撞把分布快速拉回局部平衡，而宏观场在更长的尺度上缓慢变化。分布可以写成

$ f = f^("eq") + epsilon f^(1) + epsilon^2 f^(2) + dots, quad epsilon = O("Kn"). $
#metadata("sym-scale-separation") <sym-scale-separation>

零阶近似产生 Euler 方程；一阶非平衡部分给出 Newton 黏性定律和 Fourier 导热定律。对连续 BGK 模型，三维单原子理想气体有

$
bold(Pi)^("neq")
&= -mu [nabla bold(u) + (nabla bold(u))^T
- 2/3 (nabla ⋅ bold(u)) bold(I)], \
bold(q) &= -kappa nabla T, \
mu &= p tau_k, quad kappa = c_p p tau_k.
$ <bgk-transport-coefficients>

所以 $"Pr"=c_p mu/kappa=1$。真实单原子稀薄气体的 Prandtl 数接近 $2/3$，这说明单松弛 BGK 对热流动并不充分。等温、低马赫数 LBM 不演化温度和热流，通常只保留第一行所代表的黏性输运。

把这些本构关系代回@kinetic-continuity、@kinetic-momentum 与 @kinetic-energy，就得到可压缩 Navier–Stokes–Fourier 方程。这里的 $bold(Pi)^("neq")$ 与第一章的黏性 Cauchy 应力符号相反：动力学压力张量出现在动量通量左侧，而 Cauchy 应力出现在力项右侧，因此 $bold(tau)=-bold(Pi)^("neq")$。明确这个符号关系可以避免把黏性扩散项写反。

连续介质极限还要说明马赫数采用哪种缩放。可压缩极限通常取 $"Kn" << 1$ 而 $"Ma"=O(1)$；弱可压缩 LBM 则取 $"Ma" << 1$，密度扰动满足 $#drho/rho_0=O("Ma"^2)$。低马赫数不是一句模糊的“速度较小”，而是平衡分布截断与不可压缩极限成立的渐近条件。
#metadata("sym-density-perturbation") <sym-density-perturbation>

== 进阶阅读：Boltzmann 碰撞积分 <advanced-collision-integral>

以下推导使用简写

$
f &= f(bold(xi),bold(x),t), quad
f_1 = f(bold(xi)_1,bold(x),t), \
f^prime &= f(bold(xi)^prime,bold(x),t), quad
f_1^prime = f(bold(xi)_1^prime,bold(x),t).
$

对弹性二体碰撞，碰撞前速度为 $bold(xi),bold(xi)_1$，碰撞后速度为 $bold(xi)^prime,bold(xi)_1^prime$。动量和动能守恒给出

$
bold(xi)+bold(xi)_1
&= bold(xi)^prime+bold(xi)_1^prime, \
bold(xi)^2+bold(xi)_1^2
&= (bold(xi)^prime)^2+(bold(xi)_1^prime)^2.
$

在分子混沌假设下，碰撞对的联合分布分解为 $f f_1$。利用微观可逆性，增益项和损失项可以写进同一个积分。Boltzmann 对稀薄气体碰撞输运与趋近平衡的原始论述见 @boltzmann1872：

$
Omega_B [f](bold(xi))
= integral integral
  (f^prime f_1^prime - f f_1)
  B(g,theta)
  dif bold(Omega) dif bold(xi)_1,
$ <boltzmann-collision-integral>

其中 $g=abs(bold(xi)_1-bold(xi))$ 是相对速度，$theta$ 是散射偏转角，$B$ 把相对速度与微分散射截面合并。积分中的二次非线性对应二体碰撞；$bold(x)$ 和 $t$ 只是参数，体现碰撞在宏观时空尺度上近似局部。

任取微观量 $phi(bold(xi))$，碰撞产生率为

$ R_phi = integral phi Omega_B [f] dif bold(xi). $

交换粒子编号，并对正、逆碰撞作变量替换，可得对称形式

$
R_phi = 1/4 integral integral integral
(phi + phi_1 - phi^prime - phi_1^prime)
(f^prime f_1^prime - f f_1)
B dif bold(Omega) dif bold(xi)_1 dif bold(xi).
$ <boltzmann-transport-theorem>

若 $phi$ 是碰撞不变量，第一个括号恒为零，@collision-conservation 随即成立。这就是 Boltzmann 输运定理把微观碰撞守恒连接到宏观守恒的方式。

== 进阶阅读：$H$ 定理与平衡分布 <advanced-h-theorem>

定义局部 $H$ 泛函

$ H[f] = integral f ln(f/f_("ref")) dif bold(xi), $

其中常数 $f_("ref")$ 只负责使对数自变量无量纲，不影响导数。将 $phi=ln(f/f_("ref"))+1$ 代入@boltzmann-transport-theorem，碰撞产生率为

$
sigma_H = 1/4 integral integral integral
ln[(f f_1)/(f^prime f_1^prime)]
(f^prime f_1^prime-f f_1)
B dif bold(Omega) dif bold(xi)_1 dif bold(xi) <= 0.
$ <h-production>

不等式来自 $(Y-X)ln(X/Y)<=0$。在周期边界或无 $H$ 通量边界下，对空间再积分便有 $(dif H_("tot")) / (dif t)<=0$。热力学熵与 $-H_("tot")$ 成正比，因此熵不会因碰撞而减少。

等号成立要求详细平衡

$ f^prime f_1^prime = f f_1. $

取对数后，$ln f$ 必须是碰撞不变量的线性组合：

$ ln f^("eq") = a + bold(b) dot bold(xi) + c bold(xi)^2. $

可积性要求 $c<0$。再用质量、动量和能量矩确定 $a$、$bold(b)$ 和 $c$，便得到@maxwell-boltzmann。Maxwell 分布不是凭经验选取的 Gaussian；它由碰撞不变量、详细平衡和给定守恒矩共同确定。

== 进阶阅读：Chapman–Enskog 展开 <advanced-continuous-ce>

把宏观尺度与平均自由程之比写成小参数 $epsilon$，连续 BGK 方程可无量纲化为

$
partial_t f + bold(xi) dot nabla f
= -1/(epsilon tau_k) (f-f^("eq")).
$

作多尺度展开

$
f &= f^(0)+epsilon f^(1)+epsilon^2 f^(2)+dots, \
partial_t &= partial_t^(0)+epsilon partial_t^(1)+dots.
$

为了让 $rho$、$rho bold(u)$ 和能量始终由 $f^(0)$ 携带，对 $n>=1$ 施加可解性条件

$
integral {1,bold(xi),1/2 bold(xi)^2} f^(n) dif bold(xi)
= {0,bold(0),0}.
$ <ce-solvability>

$O(epsilon^(-1))$ 给出 $f^(0)=f^("eq")$。$O(1)$ 给出

$
f^(1) = -tau_k
[partial_t^(0)+bold(xi) dot nabla]f^("eq").
$ <continuous-first-nonequilibrium>

对零阶方程取守恒矩，可以用 Euler 方程消去 $f^("eq")$ 时间导数。令 $bold(C)=bold(xi)-bold(u)$，整理后的一阶修正只含速度梯度和温度梯度：

$
f^(1) = -tau_k f^("eq") [
1/(2 R T)
(C_alpha C_beta-1/d bold(C)^2 delta_(alpha beta))
(partial_alpha u_beta+partial_beta u_alpha)
+ (bold(C) dot nabla T)/T
(bold(C)^2/(2 R T)-(d+2)/2)
].
$ <bgk-first-correction>

上式第一部分是二阶无迹 Hermite 模态，产生黏性应力；第二部分是三阶奇模态，产生热流。对它分别取二阶和三阶中心矩，并使用 Gaussian 积分，得到@bgk-transport-coefficients。

这个推导也说明了矩封闭的层次。局部 Maxwell 投影只保留守恒场，得到 Euler 方程；加入 $f^(1)$ 得到 Navier–Stokes–Fourier 方程；Grad 方法则把非平衡应力和热流也当作独立变量，形成 13 矩系统。更高阶 Burnett 修正或 R13 正则化用于更强的非平衡，但不能直接当成基础等温 LBM 的精度承诺。关于这些投影、修正和动力学提升之间的关系，可参阅 @hosseini2023。

下一章把连续速度积分改成有限求和，并把沿特征线的输运变成格点间的精确迁移。相空间离散必须保留本章用到的低阶矩，否则即使碰撞与迁移代码完全正确，也不能恢复目标流体方程。
