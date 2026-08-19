= 流体流动基础 <fluid-flow>

流体流动描述液体或气体随时间和空间发生的运动。格子玻尔兹曼方法最终要恢复的密度、速度和压力，都是流体力学中的宏观量。本章从连续介质假设出发，给出理解后续 LBM 模型所需的最小概念集合。更完整的经典论述可参考 @batchelor1967 和 @chorin1993。

== 连续介质与流场 <continuum>

当观察尺度远大于分子平均自由程时，可以忽略单个分子的运动，把流体视为连续介质。欧拉描述在固定空间位置 $bold(x)$ 上定义随时间 $t$ 变化的场：密度 $rho(bold(x), t)$、速度 $bold(u)(bold(x), t)$、压力 $p(bold(x), t)$ 和温度 $T(bold(x), t)$。

流体微团沿速度场运动时，物理量 $phi$ 的变化由物质导数（material derivative）描述：

$ (D phi) / (D t) = partial_t phi + bold(u) dot nabla phi. $

右侧第一项是固定位置的局部变化，第二项是微团穿过非均匀流场产生的对流变化。

== 质量与动量守恒 <conservation>

质量守恒的微分形式是连续性方程：

$ partial_t rho + nabla dot (rho bold(u)) = 0. $

动量守恒可写成柯西动量方程：

$ rho (partial_t bold(u) + bold(u) dot nabla bold(u)) = nabla dot bold(sigma) + rho bold(g), $

其中 $bold(sigma)$ 是应力张量，$bold(g)$ 是单位质量所受的体力。对各向同性的牛顿流体，应力由压力和速度梯度确定。若动力黏度 $mu$ 为常数，并采用不可压缩条件 $nabla dot bold(u) = 0$，则得到不可压缩 Navier–Stokes 方程：

$ partial_t bold(u) + bold(u) dot nabla bold(u) = -1/rho nabla p + nu nabla^2 bold(u) + bold(g), $

其中 $nu = mu / rho$ 是运动黏度。

== 初始条件与边界条件 <fluid-boundaries>

守恒方程只有配合初始条件和边界条件才构成确定的问题。常见边界包括给定速度的入口、给定压力的出口、周期边界，以及满足无滑移条件的固壁。对静止固壁，无滑移条件为 $bold(u) = bold(0)$；在 LBM 中，这类宏观条件需要转换为未知分布函数的重构或反弹规则。

== 无量纲量 <dimensionless>

无量纲参数用于比较不同尺度的流动，并判断模型假设是否成立。设特征速度为 $U$、特征长度为 $L$，则雷诺数为

$ "Re" = (U L) / nu. $

$"Re"$ 衡量惯性效应与黏性效应的相对强弱。马赫数 $"Ma" = U / c_s$ 衡量流速相对于声速 $c_s$ 的大小；后续采用的弱可压缩 LBM 通常要求 $"Ma"$ 足够小。努森数 $"Kn" = lambda / L$ 则比较分子平均自由程 $lambda$ 与宏观长度尺度；连续介质方程对应 $"Kn"$ 很小的区域。

这些量构成宏观流体力学与介观 LBM 之间的桥梁：数值参数不能只在格子单位下选取，还必须使目标 $"Re"$ 得到保持，并让 $"Ma"$ 和离散误差处于可接受范围。
