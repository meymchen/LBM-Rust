#import "../figures/fluid-foundations.typ": control-volume
#import "../symbols.typ": dphi, dt

= 流体流动基础 <fluid-flow>

在讨论格子玻尔兹曼方法之前，先要知道流体计算究竟在计算什么。水流过管道时，水的总量不会无故增减；流速发生变化时，必然有压力、黏性或外力改变了它的动量。前一句对应质量守恒，后一句对应动量守恒。几乎所有流体数值模型都从这两条规律出发，只是选择的状态变量和离散方式不同。

本章先建立连续介质和流场的概念，再从一个固定控制体推导质量与动量方程。随后介绍流动的物理分类、常见的方程简化和主要数值方法。读完本章后，读者应能回答三个问题：一个流动问题保留了哪些物理效应，计算机实际求解什么方程，以及 LBM 为什么属于一条不同于传统离散方法的技术路线。

== 从流体微团到流场 <continuum>

一杯水含有数量极大的分子。逐个记录分子的位置和速度，既没有必要，也远远超出通常的计算能力。工程流体力学把一个包含大量分子、但相对管道或叶片又足够小的体积称为流体微团。我们用微团内的平均量描述流动，例如密度 $rho$、速度 $bold(u)$、压力 $p$ 和温度 $T$。
#metadata("sym-density") <sym-density>
#metadata("sym-macroscopic-velocity") <sym-macroscopic-velocity>
#metadata("sym-pressure") <sym-pressure>
#metadata("sym-temperature") <sym-temperature>

只要问题的特征长度 $L$ 远大于分子平均自由程 $lambda$，相邻微团的平均量便可以看成连续变化。两者之比
#metadata("sym-characteristic-length") <sym-characteristic-length>
#metadata("sym-mean-free-path") <sym-mean-free-path>

$ "Kn" = lambda / L $
#metadata("sym-knudsen-number") <sym-knudsen-number>

称为努森数（Knudsen number）。当 $"Kn"$ 很小时，连续介质假设通常成立；当气体非常稀薄或通道小到微纳米尺度时，分子的非平衡效应变得明显，连续介质模型可能失效。

描述连续介质有两种视角。拉格朗日描述跟随同一个流体微团，像跟踪一片漂在水面的叶子；欧拉描述固定观察空间位置，像站在桥上记录桥下每一点的流速。数值流体力学常采用欧拉描述，把物理量写成位置 $bold(x)$ 和时间 $t$ 的函数：
#metadata("sym-position") <sym-position>
#metadata("sym-time") <sym-time>

$ rho = rho(bold(x), t), quad bold(u) = bold(u)(bold(x), t), quad p = p(bold(x), t). $

这些随空间和时间变化的量统称为场。一个跟随流动的微团经过非均匀流场时，即使某个固定位置的量不随时间改变，微团感受到的量也可能改变。设标量 $phi(bold(x),t)$ 表示温度或浓度。经过时间 $#dt$ 后，微团从 $bold(x)$ 移到 $bold(x) + bold(u) #dt$，于是
#metadata("sym-time-increment") <sym-time-increment>

$
#dphi = phi(bold(x) + bold(u) #dt, t + #dt) - phi(bold(x), t).
$
#metadata("sym-scalar-increment") <sym-scalar-increment>

对右侧作一阶展开并除以 $#dt$，令 $#dt arrow 0$，得到物质导数（material derivative）

$ (D phi) / (D t) = partial_t phi + bold(u) dot nabla phi. $

$partial_t phi$ 是固定位置观察到的局部变化，$bold(u) dot nabla phi$ 是微团移动到不同位置产生的对流变化。对速度场使用同一运算，$(D bold(u)) / (D t)$ 就是流体微团的加速度。

== 质量守恒：流入、流出与局部积累 <mass-conservation>

考虑空间中一个固定区域 $V$，边界记为 $partial V$，指向区域外的单位法向量为 $bold(n)$。区域中的总质量是

#figure(
  control-volume,
  caption: [概念示意图：固定控制体以外法向统一流入和流出的符号。],
) <control-volume-diagram>

@control-volume-diagram 的阅读顺序是先看外法向，再判断 $bold(u) dot bold(n)$ 的正负：负值表示流入，正值表示流出。因此，区域内的积累必须等于流入减去流出。这张图只解释符号和守恒关系，不表示某个具体流场或控制体形状。

$ M(t) = integral_V rho dif V. $

边界上一小块面积 $dif A$ 在单位时间内通过的体积为 $(bold(u) dot bold(n)) dif A$，相应质量流率为 $rho (bold(u) dot bold(n)) dif A$。当 $bold(u) dot bold(n) > 0$ 时，流体向外离开；小于零时，流体进入。因此，区域内质量的增加率等于净流出量的负值：

$ (dif)/(dif t) integral_V rho dif V = - integral_(partial V) rho bold(u) dot bold(n) dif A. $

这就是质量守恒的积分形式。利用散度定理

$ integral_(partial V) rho bold(u) dot bold(n) dif A = integral_V nabla ⋅ (rho bold(u)) dif V, $

并把时间导数移入固定积分区域，可得

$ integral_V [partial_t rho + nabla ⋅ (rho bold(u))] dif V = 0. $

因为控制体 $V$ 可以任意选取，方括号中的局部量必须处处为零：

$ partial_t rho + nabla ⋅ (rho bold(u)) = 0. $ <continuity-equation>

这就是连续性方程。它不要求流体不可压缩，也不要求流动稳定。把乘积展开后，方程还可写为

$ (D rho)/(D t) + rho nabla ⋅ bold(u) = 0. $

第一项表示跟随微团观察到的密度变化，第二项表示微团体积的膨胀或压缩。对于密度保持常数的不可压缩流体，连续性方程化为

$ nabla ⋅ bold(u) = 0. $ <incompressible-continuity>

“不可压缩”并不等于“速度处处相同”。它表示速度场的散度为零，也就是一个微小流体体积不会持续膨胀或收缩。

== 动量守恒：什么使流体加速 <momentum-conservation>

牛顿第二定律同样适用于流体：动量变化率等于所受合力。单位体积的动量是 $rho bold(u)$。固定控制体中的动量既会随时间积累，也会被流动带过边界，因此动量守恒的积分形式为

$
partial_t integral_V rho bold(u) dif V
+ integral_(partial V) rho bold(u) (bold(u) dot bold(n)) dif A
= integral_(partial V) bold(sigma) bold(n) dif A + integral_V rho bold(g) dif V.
$

左侧第一项是控制体内的动量变化，第二项是通过边界的净动量通量。右侧包含两类力：$bold(sigma) bold(n)$ 是周围流体通过表面施加的力，$rho bold(g)$ 是重力等作用于体积内部的体力。$bold(sigma)$ 称为柯西应力张量。
#metadata("sym-cauchy-stress") <sym-cauchy-stress>
#metadata("sym-body-acceleration") <sym-body-acceleration>

对动量通量和表面力使用散度定理，可得局部形式

$ partial_t (rho bold(u)) + nabla ⋅ [rho bold(u) ⊗ bold(u)] = nabla ⋅ bold(sigma) + rho bold(g). $

用连续性方程消去密度变化项后，左侧可以整理为 $rho (D bold(u)) / (D t)$：

$ rho [partial_t bold(u) + bold(u) dot nabla bold(u)] = nabla ⋅ bold(sigma) + rho bold(g). $ <cauchy-momentum>

到这里还没有指定流体材料如何响应变形。动量守恒适用于水、空气和非牛顿流体；不同材料的区别藏在应力 $bold(sigma)$ 与速度梯度的关系中，这种关系称为本构关系。

== 从应力到 Navier–Stokes 方程 <navier-stokes>

静止流体中的应力只有压力。压力总是垂直表面并指向内部，因此应力张量可分为压力部分和黏性部分：

$ bold(sigma) = -p bold(I) + bold(tau). $
#metadata("sym-viscous-stress") <sym-viscous-stress>

$bold(I)$ 是单位张量，$bold(tau)$ 是黏性应力。牛顿流体假设黏性应力与局部变形速率成正比。对各向同性流体，常用关系为

$ bold(tau) = mu [nabla bold(u) + (nabla bold(u))^T] + lambda_v (nabla ⋅ bold(u)) bold(I), $

其中 $mu$ 是动力黏度，$lambda_v$ 是第二黏度系数。把它代入动量方程，在 $mu$ 和 $lambda_v$ 为空间常数时得到可压缩 Navier–Stokes 动量方程
#metadata("sym-dynamic-viscosity") <sym-dynamic-viscosity>
#metadata("sym-second-viscosity") <sym-second-viscosity>

$
rho [partial_t bold(u) + bold(u) dot nabla bold(u)]
= -nabla p + mu nabla^2 bold(u)
+ (mu + lambda_v) nabla(nabla ⋅ bold(u)) + rho bold(g).
$

若密度为常数且 $nabla ⋅ bold(u) = 0$，最后一个黏性散度项消失。再定义运动黏度 $nu = mu / rho$，便得到本书后续主要关心的不可压缩 Navier–Stokes 方程：
#metadata("sym-kinematic-viscosity") <sym-kinematic-viscosity>

$
partial_t bold(u) + bold(u) dot nabla bold(u)
= -1/rho nabla p + nu nabla^2 bold(u) + bold(g),
quad nabla ⋅ bold(u) = 0.
$ <incompressible-ns>

方程左侧分别是局部加速度和对流加速度；右侧依次是压力梯度、黏性扩散和体力。压力在不可压缩模型中还有一个特殊作用：它会调整速度场，使 $nabla ⋅ bold(u) = 0$ 始终成立。这也是传统不可压缩求解器通常需要解压力泊松方程的原因。

== 怎样给一个流动问题分类 <flow-classification>

分类不是贴标签，而是决定哪些项可以忽略、哪些参数必须解析。一个问题常同时属于下面多个类别。

- 稳态与非稳态：若所有场量对时间的偏导数为零，流动是稳态；否则是非稳态。稳态流场中的单个微团仍可能因对流项而加速。
- 不可压缩与可压缩：若密度变化可以忽略，可采用不可压缩模型。气体流速远低于声速且温度变化不大时也常近似不可压缩。激波、喷管和高速气动问题必须考虑可压缩性。
- 无黏与黏性：当黏性只在很薄的近壁区起作用时，远离壁面处可用 Euler 方程；边界层、管流和阻力计算不能忽略黏性。
- 层流与湍流：层流中运动较规则，湍流包含跨越多个尺度的非定常脉动。分类取决于几何、扰动和雷诺数，不能只凭一张瞬时流线图判断。
- 牛顿与非牛顿：水和空气在常见条件下可视为牛顿流体；血液、聚合物溶液和泥浆的应力可能非线性依赖剪切速率，需要另外的本构关系。
- 连续与稀薄：当 $"Kn"$ 足够小时使用连续介质方程；$"Kn"$ 增大后，要考虑滑移边界、动力学方程甚至分子模拟。

其中最常用的判别参数是雷诺数。取特征速度 $U$ 和特征长度 $L$，比较 Navier–Stokes 方程中对流项的量级 $U^2/L$ 与黏性项的量级 $nu U/L^2$，两者之比为

$ "Re" = (U L) / nu. $
#metadata("sym-reynolds-number") <sym-reynolds-number>

低 $"Re"$ 表示黏性效应相对强，高 $"Re"$ 表示惯性效应相对强。雷诺数并不是层流与湍流之间普适且唯一的分界值；具体转捩位置还受几何和入口扰动影响。

马赫数

$ "Ma" = U / c_s $
#metadata("sym-sound-speed") <sym-sound-speed>
#metadata("sym-mach-number") <sym-mach-number>

比较流速 $U$ 与声速 $c_s$。当 $"Ma"$ 较小时，压力扰动传播得比流体运动快，密度变化通常较弱。本书使用的等温 LBM 是弱可压缩模型：它通过微小密度变化表达压力，因此实际计算既要匹配目标 $"Re"$，也要把 $"Ma"$ 控制在低速范围。

== 守恒方程的常见简化模型 <reduced-models>

Navier–Stokes 方程不是每个问题都要原样求解。根据量级分析删去次要项，可以得到更便宜、也更容易分析的模型。

- Euler 方程：令黏度 $nu = 0$，保留惯性、压力和体力。它适合描述远离固壁的高雷诺数流动，但不能满足黏性流体在固壁上的无滑移条件。
- Stokes 流：当 $"Re" << 1$ 时忽略对流惯性，稳态方程变为 $0 = -nabla p + mu nabla^2 bold(u) + rho bold(g)$。微流动、颗粒缓慢沉降常属于这一类。
- 势流：对无黏、无旋流动令 $bold(u) = nabla phi$，不可压缩条件给出 $nabla^2 phi = 0$。它能快速估计外部流动，却不能直接给出黏性阻力。
- 润滑近似：当流道厚度远小于长度时，沿厚度方向的黏性梯度占主导。三维问题可约化为压力沿长方向变化的一维或二维方程。
- 浅水方程：当水平尺度远大于水深时，对深度方向积分守恒方程，以水深和深度平均速度为未知量。河流、潮汐和溃坝问题常用此模型。
- Reynolds 平均方程：工程湍流计算可把速度分成平均量和脉动量。平均后会出现新的 Reynolds 应力，需要湍流模型封闭。大涡模拟则解析大尺度涡，只模拟较小尺度的影响。

简化模型是否成立，必须由尺度比、无量纲数和验证结果支持。少算一个物理项会降低成本，也可能删掉问题中真正重要的机制。

== 计算机怎样求解流体方程 <numerical-models>

连续方程包含任意位置和任意时刻的未知函数，计算机只能保存有限个数。数值方法因此要做两件事：选择有限的自由度，再规定这些自由度如何近似微分、积分或输运。常见方法可按计算对象分为以下几类。

- 有限差分法（FDM）直接用相邻网格点的差商近似导数。它结构简单，在规则网格上效率很高，但处理复杂边界较麻烦。
- 有限体积法（FVM）对每个控制体积分守恒方程，通过面通量更新单元平均值。相邻单元共享同一通量，因此天然保持离散守恒，是工程计算流体力学中的主流方法之一。
- 有限元法（FEM）把方程写成弱形式，用分片基函数展开未知场。它适合非结构网格和复杂几何，也便于处理多物理场耦合。
- 谱方法用全局高阶基函数表示解。对于光滑解和简单区域，它能用较少自由度达到很高精度；不连续结构和复杂几何会降低其便利性。
- 粒子法用移动的计算点跟随物质，例如光滑粒子流体动力学。自由表面和大变形较自然，但邻域搜索、一致性和边界处理需要额外设计。
- 动力学方法演化粒子速度分布，再由分布的矩恢复密度和动量。离散速度法和 LBM 属于这一类。LBM 仍在固定格点上计算，但它离散的是介观分布方程，而不是直接对 Navier–Stokes 方程的空间导数作差分。

还可以按网格是否随流体运动分为 Euler 网格、Lagrange 网格和任意 Lagrange–Euler 网格；按时间推进分为显式和隐式方法；按离散量所在位置分为同位网格和交错网格。这些分类描述的是数值组织方式，与前一节的物理分类并不冲突。

传统方法从宏观守恒方程出发，重点是准确构造对流通量、黏性通量以及压力与速度耦合。LBM 选择另一组状态变量：每个格点保存各离散速度对应的离散分布函数。离散分布先在本地碰撞，再沿格线迁移；质量和动量通过求和恢复。规则的数据访问和局部碰撞使它特别适合并行计算，也使复杂固体边界的某些处理较直接。代价是低马赫数限制、参数稳定区间以及边界误差都需要认真控制。

== 初始条件、边界条件与封闭关系 <fluid-boundaries>

守恒方程本身还不能唯一决定一个流场。完整问题至少需要以下信息：

- 初始条件给出 $t = 0$ 时区域内的密度、速度或温度；
- 边界条件规定入口速度、出口压力、固壁速度、周期连接或自由表面行为；
- 本构关系给出应力如何依赖速度梯度，传热问题还要给出热流与温度梯度的关系；
- 状态方程连接压力、密度和温度。不可压缩模型常把密度视为常数；可压缩理想气体则使用 $p = rho R T$。

边界条件必须与方程类型和已知信息匹配。对静止黏性固壁，常用无滑移条件 $bold(u) = bold(0)$；无黏模型只能施加不可穿透条件 $bold(u) dot bold(n) = 0$。在 LBM 中，这些宏观条件最终要转换成未知离散速度所对应的分布规则。反弹、速度重构和压力重构不是绘图时补上的设置，而是离散模型的一部分。

== 进阶阅读：从控制体到无量纲方程 <advanced-fluid-derivation>

本节把前面的推导连成一条完整链路，并说明 $"Re"$ 为什么自然出现在方程中。第一次阅读可以先掌握结论，之后再回来逐行核对。

=== 一般守恒量的输运公式

设单位质量携带某个量 $phi$。固定控制体内该量的总和为 $integral_V rho phi dif V$，通过边界向外的通量为 $rho phi bold(u) dot bold(n)$。若单位体积存在源项 $s_phi$，守恒关系为

$
partial_t integral_V rho phi dif V
+ integral_(partial V) rho phi bold(u) dot bold(n) dif A
= integral_V s_phi dif V.
$

用散度定理并利用控制体的任意性，得到

$ partial_t (rho phi) + nabla ⋅ (rho phi bold(u)) = s_phi. $

展开左侧：

$
partial_t (rho phi) + nabla ⋅ (rho phi bold(u))
= rho [partial_t phi + bold(u) dot nabla phi]
+ phi [partial_t rho + nabla ⋅ (rho bold(u))].
$

第二个方括号由连续性方程知为零，所以一般输运式化为

$ rho (D phi)/(D t) = s_phi. $

令 $phi = 1$ 且没有质量源，便恢复连续性方程。令 $phi = bold(u)$，源项取表面力散度与体力之和，便得到柯西动量方程。质量守恒和动量守恒不是两套无关的公式，而是同一输运结构对不同守恒量的应用。

=== 牛顿流体黏性项的化简

把牛顿流体本构关系代入 $nabla ⋅ bold(sigma)$：

$
nabla ⋅ bold(sigma)
= -nabla p
+ nabla ⋅ {mu [nabla bold(u) + (nabla bold(u))^T]}
+ nabla [lambda_v (nabla ⋅ bold(u))].
$

当黏度为常数时，逐项求散度得到

$
nabla ⋅ bold(sigma)
= -nabla p + mu nabla^2 bold(u)
+ (mu + lambda_v) nabla(nabla ⋅ bold(u)).
$

不可压缩条件使 $nabla ⋅ bold(u) = 0$，因此最后一项为零。再除以常密度 $rho$，就得到@incompressible-ns。这里每一个简化都有明确前提：常黏度、常密度和零速度散度。若温度导致黏度显著变化，$mu$ 不能移出导数；若流体可压缩，散度项也不能直接删掉。

=== 无量纲化与主导项

引入无量纲变量

$
bold(x) = L bold(x)^star, quad
t = L/U t^star, quad
bold(u) = U bold(u)^star, quad
p = rho U^2 p^star.
$

由链式法则，$nabla = 1/L nabla^star$，$partial_t = U/L partial_(t^star)$。忽略体力，把这些关系代入不可压缩 Navier–Stokes 方程：

$
U^2/L [partial_(t^star) bold(u)^star
+ bold(u)^star dot nabla^star bold(u)^star]
= -U^2/L nabla^star p^star
+ nu U/L^2 (nabla^star)^2 bold(u)^star.
$

两侧同除以 $U^2/L$：

$
partial_(t^star) bold(u)^star
+ bold(u)^star dot nabla^star bold(u)^star
= -nabla^star p^star
+ 1/"Re" (nabla^star)^2 bold(u)^star,
quad nabla^star dot bold(u)^star = 0.
$ <dimensionless-ns>

因此，几何形状和边界条件相似的两个不可压缩流动，只要 $"Re"$ 相同，它们的无量纲方程就相同。这是模型实验、网格计算与真实装置之间能够比较的基础。$"Re" << 1$ 时，黏性项相对显著，适当缩放后可得到 Stokes 近似；$"Re"$ 很大时，区域内部的黏性项可能较小，但固壁附近仍会形成速度梯度很大的边界层，不能据此在整个区域删除黏性。

本章的连续介质、守恒方程和尺度分析可与 @batchelor1967、@chorin1993 对照阅读；这些文献用于扩展深度，不是理解下一章的先决条件。下一章将换一个观察层次：不再直接更新 $rho$ 和 $bold(u)$，而是更新一组离散速度上的分布函数，并证明这些分布的低阶矩仍满足本章建立的守恒关系。
