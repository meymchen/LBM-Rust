#import "../symbols.typ": dt, dx
#import "../figures/diffusion-practice.typ": diffusion-1d-problem, diffusion-1d-states, diffusion-2d-boundaries, diffusion-3d-domain, diffusion-hero, diffusion-lbm-step

#pagebreak(weak: true)
= 扩散问题实践：从一维到三维 <diffusion-practice>

扩散方程只守恒一个标量，因此很适合用来拆解 LBM 的参数映射、碰撞、迁移和验证。本章先用一维周期问题对照有限差分与 D1Q3 LBM，再把同一套构造扩展到源项、多维格子和边界条件。算法示例采用与本仓库一致的 Rust 数据结构。

与前面的流动问题相比，本章只守恒一个标量，不涉及动量和能量。这个简化让平衡分布和多尺度展开都能完整写出；同时，松弛时间公式中的半时间步修正与@derived-viscosity 的黏度公式同源，可以先在最简单的模型里看清它的来历。

在具体格式之前，先建立物理图像：扩散把一个局域的标量团抹平。峰值下降，分布展宽，总量不变。

#figure(
  diffusion-hero,
  caption: [概念示意图：同一标量团在三个时刻的扩散。蓝色包络为高斯型线，点的疏密只编码标量高低，不表示粒子轨迹。],
) <diffusion-hero-figure>

== 阅读路线 <diffusion-reading-route>

本章有两条读法。要先把程序跑起来，可以按@diffusion-1d-problem-figure 定义问题，读完有限差分格式、D1Q3 方案和两个算法示例后直接进入@diffusion-benchmark；要核对扩散系数中的半时间步修正，再回到@diffusion-ce。二维、三维部分不重复一维推导，只说明离散速度模型和边界如何扩展。

#table(
  columns: (1.1fr, 1.45fr, 1.65fr),
  inset: 6pt,
  align: (left, left, left),
  table.header([阶段], [读者要确定的量], [本章给出的证据]),
  [定义问题], [$D$、初值、边界、目标时刻], [控制方程与解析解],
  [映射参数], [$r$ 或 $omega$], [稳定性条件与@lattice-diffusion-number],
  [实现单步], [$phi$ 或 $overline(f)_i$ 的数组更新], [FTCS 与 D1Q3 Rust 算法示例],
  [验证结果], [守恒误差、型线误差、收敛阶], [可再生 CSV、数据图与测试],
  [测量成本], [每格点每步耗时、吞吐量], [发布构建微基准与运行元数据],
)

== 扩散方程简介 <diffusion-equation-intro>

考虑标量场 $phi(bold(x),t)$。它可以是溶质浓度、温度，或任何满足守恒律且通量由梯度驱动的量。
#metadata("sym-scalar-field") <sym-scalar-field>

守恒形式为

$ partial_t phi + nabla dot bold(j) = R, $ <scalar-conservation>

其中 $bold(j)$ 是通量，$R(bold(x),t)$ 是源（汇）强度，表示单位体积单位时间的产生（消耗）率；无源时 $R=0$。
#metadata("sym-source-term") <sym-source-term>

Fick 定律（热传导情形为 Fourier 定律）假设通量正比于负梯度：

$ bold(j) = -D nabla phi. $ <fick-law>

比例系数 $D>0$ 是扩散系数，量纲为 $L^2/T$。
#metadata("sym-diffusion-coefficient") <sym-diffusion-coefficient>

$D$ 为常数且 $R=0$ 时，代入@scalar-conservation 得到扩散方程

$ partial_t phi = D nabla^2 phi. $ <diffusion-equation>

一维情形下 $nabla^2 phi = partial_x^2 phi$。扩散方程有三个基本性质。第一，它保持总量：在周期边界或零通量边界下，$integral phi dif bold(x)$ 不随时间变化。第二，它抹平信息：$t=0$ 时刻集中在原点的单位质量，在无限区域上展开为方差随时间线性增长的 Gaussian

$ phi(x,t) = 1/sqrt(4 pi D t) exp(-x^2/(4 D t)). $ <diffusion-fundamental-solution>

初值的细节不可逆地丢失，方程不能沿时间反演。第三，它有内禀时间尺度：长度 $L$ 上的扩散时间为

$ t_D = L^2/D. $

任何数值格式的时间步都必须相对 $t_D$ 来说明；离开扩散尺度谈“收敛快”或“耗时长”没有意义。

定解还需要初始条件 $phi(bold(x),0)$ 和边界条件。常见选择是给定边界值的 Dirichlet 条件、给定通量的 Neumann 条件，以及无端点的周期条件。一维部分的验证讨论使用周期边界，因为它把边界重构误差排除在外，可以单独检验体内格式；多维部分再逐一面对各类边界。

@diffusion-1d-problem-figure 把一维问题汇总为物理场、坐标系与边界条件的示意：杆内色深表示标量高低，通量由高处指向低处，两端周期对接。

#figure(
  diffusion-1d-problem,
  caption: [概念示意图：一维扩散问题的物理场、坐标系与周期边界（子图 a），以及正弦初值的解析衰减（子图 b）。],
) <diffusion-1d-problem-figure>

子图 b 的正弦衰减是后文一维验证的解析基准：形状不变、振幅按指数下降，任何实现误差都会直接表现为型线或衰减率的偏差。

== 一维问题：有限差分格式 <fdm-diffusion>

把区域划成格距为 $#dx$ 的均匀网格 $x_j=j #dx$，时间步为 $#dt$，记 $phi_j^n approx phi(x_j,n #dt)$。时间用向前差分、空间用中心差分，@diffusion-equation 离散为

$ (phi_j^(n+1)-phi_j^n)/#dt
= D (phi_(j+1)^n - 2 phi_j^n + phi_(j-1)^n)/(#dx^2). $ <ftcs-scheme>

引入扩散数

$ r = D #dt / #dx^2, $

更新公式写成

$ phi_j^(n+1) = phi_j^n + r (phi_(j+1)^n - 2 phi_j^n + phi_(j-1)^n). $ <ftcs-update>

Taylor 展开表明，该格式对时间一阶、对空间二阶一致，局部截断误差为 $O(#dt, #dx^2)$。

稳定性是显式格式的核心限制。把单 Fourier 模态 $phi_j^n = G^n e^(upright(i) k x_j)$ 代入@ftcs-update，其中 $upright(i)$ 是虚数单位，增长因子为

$ G = 1 - 4 r sin^2(k #dx / 2). $ <von-neumann-growth>

要求所有可解析波数都有 $abs(G)<=1$，得到

$ r <= 1/2. $ <fdm-stability>

时间步因此受 $#dt <= #dx^2/(2D)$ 约束：格距减半，允许的时间步缩小到四分之一。这不是精度要求而是稳定性硬约束；它来自抛物方程的显式时间积分，与空间差分的阶数无关。Crank–Nicolson 等隐式格式可以解除该限制，代价是每步求解线性方程组。

@ftcs-update 还有一个直接的物理解读：新值是旧值与左右邻居的加权平均，三个权重 $r$、$1-2r$、$r$ 在 $r<=1/2$ 时全非负，格式等价于一个显式随机游走的转移规则。下面会看到，LBM 用完全不同的机制——局部碰撞加格间迁移——逼近同一个目标方程。

=== 算法示例：FTCS 单步 <ftcs-algorithm>

周期边界可以直接写进邻居索引。下面的实现先保留旧时刻数组，再逐点写入新时刻；若原地更新，右邻居可能已经属于 $n+1$ 时刻，格式就不再是@ftcs-update。

```rust
pub fn step(&mut self) {
    let n = self.phi.len();
    let previous = self.phi.clone();

    for (j, value) in self.phi.iter_mut().enumerate() {
        let laplacian = previous[(j + 1) % n] - 2.0 * previous[j]
            + previous[(j + n - 1) % n];
        *value = previous[j] + self.diffusion_number * laplacian;
    }
}
```

这里的 `diffusion_number` 就是 $r$。完整实现位于 `examples/d1q3-diffusion/src/lib.rs`；它与后面的 LBM 求解器使用同一初值和解析解，避免比较时混入问题设置的差别。

== 一维问题：D1Q3 格子 Boltzmann 方案 <lbm-diffusion-scheme>

现在构造扩散求解器。关键观察是：扩散方程只有一个守恒量，即标量 $phi$ 本身；不需要动量守恒，也不需要状态方程。取 D1Q3 格子，$c_i in {0, c, -c}$，$c=#dx/#dt$，每个格点保存三个（经二阶时间积分变换的）分布 $overline(f)_i$，宏观量只有

$ phi = sum_(i=0)^2 overline(f)_i. $ <scalar-moment>

演化仍是标准的碰撞加迁移：

$ overline(f)_i (x + c_i #dt, t + #dt)
= overline(f)_i (x, t)
- omega [overline(f)_i (x, t) - f_i^("eq") (x, t)],
quad omega = #dt/overline(tau). $ <lbe-diffusion>

碰撞保持零阶矩，所以 $phi$ 在碰撞前后不变；迁移把分布在格点间搬运，净效果是在宏观尺度上产生沿负梯度的输运。后文的 Chapman–Enskog 展开给出扩散系数

$ D = c_s^2 #dt (1/omega - 1/2)
= c_s^2 (overline(tau) - #dt/2), $ <diffusion-relaxation>

其中 $c_s^2=c^2/3$。它与黏度公式@derived-viscosity 形式完全相同：把其中的 $nu$ 换成 $D$，结论逐字成立。这不是巧合——黏性扩散与标量扩散在矩结构上是同一类过程。

物理参数到格子参数的映射也随之确定。给定物理的 $D$、$#dx$ 和 $#dt$，

$ overline(tau) = #dt/2 + D/c_s^2
= #dt/2 + 3 D #dt^2 / #dx^2, $

而格子扩散数与有限差分的 $r$ 直接对应：

$ r = D #dt/#dx^2 = c_s^2/c^2 (1/omega - 1/2) = 1/3 (1/omega - 1/2). $ <lattice-diffusion-number>

有限差分要求 $r<=1/2$，LBM 的名义正扩散系数要求 $0<omega<2$（即 $overline(tau)>#dt/2$）。$omega<1/2$ 时 $r$ 已超出显式差分的稳定限，但对均匀状态的线性分析表明，碰撞–迁移格式在 $0<omega<2$ 内仍可保持稳定，算子分裂结构提供了纯显式差分没有的阻尼机制。当然，$omega$ 接近 $2$（$overline(tau)$ 接近 $#dt/2$）时非平衡分量和边界误差可能增大；$0<omega<2$ 只是名义范围，不是所有初值与边界下的稳定性保证。

初始化用平衡分布 $overline(f)_i = w_i phi(x,0)$。周期边界直接对接；Dirichlet 边界需要重构入射分布，其格式是多维部分的主题。扩散 LBM 的更完整讨论可参阅 @mohamad2011 与 @krueger2017。

== 平衡分布函数 <diffusion-equilibrium-section>

扩散 D1Q3 模型的平衡分布是

$ f_i^("eq") = w_i phi, $ <diffusion-equilibrium-dist>

即 $f_0^("eq")=2phi/3$、$f_1^("eq")=f_2^("eq")=phi/6$。它简单到近乎平凡，但每一项都有明确理由。

扩散模型对平衡分布的要求是三个矩条件：

$ sum_i f_i^("eq") = phi, quad
sum_i c_i f_i^("eq") = 0, quad
sum_i c_i^2 f_i^("eq") = c_s^2 phi. $ <diffusion-equilibrium-moments>

第一条是守恒性的直接推论：碰撞只能在方向间重新分配 $phi$，所以平衡分布必须携带全部标量。第二条断言平衡态没有净通量。扩散通量不是守恒量，不能放进平衡分布——它完全由非平衡部分携带，这与 Navier–Stokes 恢复中动量属于守恒矩有本质区别。第三条给出碰撞的各向同性松弛目标；正是这个二阶矩在多尺度展开中产生梯度项，因此它决定扩散系数。

由 D1Q3 的各向同性关系@isotropy-relations，$sum_i w_i=1$、$sum_i w_i c_i=0$、$sum_i w_i c_i^2=c_s^2$，所以 $w_i phi$ 自动满足全部三个条件。

从 Hermite 展开看，@diffusion-equilibrium-dist 是零阶截断，只保留系数 $a^("eq",(0))=phi$。它与第三章的二阶等温平衡@second-order-equilibrium 一致：令 $bold(u)=bold(0)$、$rho=phi$，后者正好退化为 $w_i phi$。扩散模型没有引入新的平衡族，只是使用无对流速度时的退化形式。

还要澄清一个常见误解。$f_i^("eq")=w_i phi$ 不含速度，并不意味着模型“丢掉了通量信息”。通量 $j=sum_i c_i overline(f)_i$ 仍然存在，只是它等于非平衡一阶矩 $sum_i c_i f_i^(1)$；下一节会看到它正好恢复 Fick 定律@fick-law。

=== 算法示例：D1Q3 单步 <d1q3-algorithm>

@diffusion-lbm-step-figure 把一次更新拆成三个不会混淆的动作。先对每个格点求和得到 $phi$，再用同一个 $phi$ 计算三个平衡分布并完成碰撞，最后按离散速度把碰撞后分布写到目的格点。周期边界只出现在目的索引的回绕中。

#figure(
  diffusion-lbm-step,
  caption: [概念示意图：D1Q3 的一次“宏观量恢复—碰撞—迁移”更新。三幅子图分别对应下面 Rust 示例中的求和、`post_collision` 和 `destination`。],
) <diffusion-lbm-step-figure>

```rust
pub fn step(&mut self) {
    let n = self.distributions.len();
    let mut streamed = vec![[0.0; D1Q3::Q]; n];

    for (j, cell) in self.distributions.iter().enumerate() {
        let phi: f64 = cell.iter().sum();
        let equilibrium = diffusion_equilibrium(phi);

        for (i, (&velocity, &target)) in
            D1Q3::VELOCITIES.iter().zip(&equilibrium).enumerate()
        {
            let post_collision = cell[i] - self.omega * (cell[i] - target);
            let destination = match velocity {
                0 => j,
                1 => (j + 1) % n,
                _ => (j + n - 1) % n,
            };
            streamed[destination][i] = post_collision;
        }
    }
    self.distributions = streamed;
}
```

这段代码采用推式迁移（push streaming）：当前格点计算碰撞后分布，再写到相邻格点。若改成拉式迁移（pull streaming），循环会从邻居读取所需分布；两者可以实现同一离散方程，但边界处理和内存访问方向必须随之统一。

格子单位下取 $#dx=#dt=1$，若目标扩散系数为 $D=1/6$，由@lattice-diffusion-number 得 $omega=1$。于是最小算例的配置是：用 `sine_mode` 生成 $phi(x,0)$，以 $w_i phi$ 初始化三个分布，重复调用 `step`，最后用 `scalar` 求零阶矩。这个参数点还能逐步对照 FTCS，因为此时两种更新代数等价。

== Chapman–Enskog 展开 <diffusion-ce>

现在严格导出@diffusion-relaxation。对@lbe-diffusion 左侧沿特征线作 Taylor 展开，记 $D_i = partial_t + c_i partial_x$：

$ #dt D_i overline(f)_i + #dt^2/2 D_i^2 overline(f)_i
= -omega [overline(f)_i - f_i^("eq")] + O(#dt^3). $ <diffusion-lbe-taylor>

引入多尺度展开

$ overline(f)_i = f_i^("eq") + epsilon f_i^(1) + epsilon^2 f_i^(2) + dots,
quad partial_t = epsilon partial_(t_1) + epsilon^2 partial_(t_2),
quad partial_x = epsilon partial_(x_1), $

其中 $epsilon$ 是宏观梯度尺度与格子尺度之比。只有零阶矩守恒，可解性条件为

$ sum_i f_i^(n) = 0, quad n >= 1. $ <diffusion-solvability>

注意这里没有动量条件：一阶矩不受约束，它正是要计算的通量。

记 $D_(1i) = partial_(t_1) + c_i partial_(x_1)$。$O(epsilon)$ 阶方程为

$ D_(1i) f_i^("eq") = -omega/#dt f_i^(1). $ <diffusion-ce-order1>

对 $i$ 求和，由@diffusion-solvability 右端为零，得

$ partial_(t_1) phi + partial_(x_1) sum_i c_i f_i^("eq") = 0. $

平衡一阶矩为零，所以

$ partial_(t_1) phi = 0. $ <diffusion-ce-t1>

扩散不发生在快时间尺度上。这是与流动问题的重要区别：标量扩散整个过程位于 $t_2$ 慢时间尺度，正如黏性效应不进入 Euler 方程一样。

由@diffusion-ce-order1 解出非平衡分布

$ f_i^(1) = -#dt/omega D_(1i) f_i^("eq"), $ <diffusion-first-nonequilibrium>

其一阶矩即通量。用平衡矩@diffusion-equilibrium-moments 和@diffusion-ce-t1，得

$ j = sum_i c_i f_i^(1)
= -#dt/omega [
partial_(t_1) sum_i c_i f_i^("eq")
+ partial_(x_1) sum_i c_i^2 f_i^("eq")
]
= -#dt/omega c_s^2 partial_(x_1) phi. $ <diffusion-flux>

这已经具有 Fick 定律的形式，但系数 $#dt c_s^2/omega$ 还不是最终的扩散系数；剩余的修正在下一阶出现。

$O(epsilon^2)$ 阶方程为

$ partial_(t_2) f_i^("eq") + D_(1i) f_i^(1)
+ #dt/2 D_(1i)^2 f_i^("eq")
= -omega/#dt f_i^(2). $ <diffusion-ce-order2>

再次对 $i$ 求和，右端由@diffusion-solvability 为零：

$ partial_(t_2) phi + partial_(x_1) sum_i c_i f_i^(1)
+ #dt/2 sum_i D_(1i)^2 f_i^("eq") = 0. $

第三项展开为

$ sum_i D_(1i)^2 f_i^("eq")
= partial_(t_1)^2 phi
+ 2 partial_(t_1) partial_(x_1) sum_i c_i f_i^("eq")
+ partial_(x_1)^2 sum_i c_i^2 f_i^("eq")
= c_s^2 partial_(x_1)^2 phi, $

其中前两项分别因@diffusion-ce-t1 和平衡一阶矩为零而消失。代入@diffusion-flux，得

$ partial_(t_2) phi
= #dt c_s^2 (1/omega - 1/2) partial_(x_1)^2 phi. $ <diffusion-ce-t2>

把两个时间尺度按 $partial_t = epsilon partial_(t_1) + epsilon^2 partial_(t_2)$ 合并，取 $epsilon=1$ 恢复物理尺度，得到

$ partial_t phi = c_s^2 #dt (1/omega - 1/2) partial_x^2 phi. $ <recovered-diffusion>

这正是目标扩散方程@diffusion-equation 的一维形式，扩散系数由@diffusion-relaxation 给出。推导同时澄清了两件事。第一，$1/omega-1/2$ 中的 $-1/2$ 来自@diffusion-lbe-taylor 左侧的二阶项，即沿特征线积分的半时间步修正；它与黏度公式中的修正是同一个，不是扩散模型特有的。第二，比较@diffusion-flux 与@recovered-diffusion 可见，由一阶矩直接读出的通量系数 $#dt c_s^2/omega$ 与宏观扩散系数相差一个因子；把 $sum_i c_i overline(f)_i$ 当作物理通量输出时，需要注意这个差别，或改用包含相应修正的通量定义。

== 一维对比：FDM 与 LBM <diffusion-1d-comparison>

两种方法离散同一个目标方程，现在系统地比较它们的相同点与区别，并用数值基准验证这些论断。@diffusion-1d-states-figure 先给出最直观的差别：同一套网格上，两种方法保存的状态量不同。

#figure(
  diffusion-1d-states,
  caption: [概念示意图：同一套网格上有限差分与 LBM 保存的状态变量。有限差分每点一个标量（子图 a）；LBM 每点三个分布，一阶矩给出通量（子图 b）。],
) <diffusion-1d-states-figure>

状态量的差别决定了输出方式、边界重构和并行结构上的所有后续差别。

=== 相同点 <diffusion-comparison-shared>

- 目标方程与守恒性相同。两者都逼近@diffusion-equation，都在周期或零通量边界下严格保持总量 $sum_j phi_j$（FDM 由格式的保守形式保证，LBM 由碰撞守恒加迁移置换保证），且都按同一扩散数 $r = D #dt/#dx^2$ 参数化。
- 精度等级相同。在扩散尺度加密（$#dt prop #dx^2$，即固定 $r$）下，两者对光滑解通常都是二阶收敛。
- $omega=1$ 时二者不只是相近，而是代数等价。此时碰撞后分布就是平衡分布 $overline(f)_i^star = w_i phi$，迁移后新时刻的标量为

$ phi(x,t+#dt)
= 1/6 phi(x-#dx,t) + 2/3 phi(x,t) + 1/6 phi(x+#dx,t), $ <omega-one-update>

逐项展开@ftcs-update 在 $r=1/6$ 时的右端，正是同一表达式。因此 $omega=1$ 的 D1Q3 LBM 逐步等于 $r=1/6$ 的 FTCS，只有浮点运算次序带来的舍入差异。

=== 区别 <diffusion-comparison-differences>

- 状态变量不同。FDM 每格点只存 $phi$；LBM 每格点存三个分布，冗余部分携带非平衡信息，一阶矩给出通量（带@diffusion-flux 所示的系数差别），可用于输出和边界重构。
- 参数映射不同。$r$ 与 $omega$ 由@lattice-diffusion-number 联系，但不是同一参数：FTCS 的稳定限是 $r<=1/2$，LBM 的名义范围是 $0<omega<2$，对应的 $r$ 可以超出 $1/2$。
- 误差结构不同。FTCS 对波数 $k$ 的每步增长因子是@von-neumann-growth，其有效衰减率为

$ lambda_"num"
= -ln G/#dt
= D k^2 + D k^4 #dx^2 (r/2 - 1/12)
+ O(k^6 #dx^4). $ <ftcs-effective-rate>

一般 $r$ 下领先误差是 $O(#dx^2)$；但 $r=1/6$ 时括号为零，首项误差抵消，格式对该初值问题呈现四阶收敛——这是显式扩散格式著名的“魔数”时间步。LBM 的有效衰减率在 $omega != 1$ 时不具有@ftcs-effective-rate 的形式，只保证以 $O(#dx^2)$ 逼近 $D k^2$；$omega=1$ 时按等价性继承 FTCS 的全部误差结构，包括魔数抵消。四阶是参数巧合，不是 LBM 的固有性质，不能外推到其他 $omega$ 或其他问题。
- 边界机制不同。FDM 直接修改边界点的值或差分模板；LBM 重构迁移后缺失的入射分布，宏观条件与离散规则之间不是一一对应（见多维部分）。
- 实现结构不同。LBM 的碰撞完全局部、迁移模式固定，天然适合并行与向量化；高阶 FDM 模板更宽，边界与通信模式随格式阶数变化。一维小问题看不到这种差别，多维大规模计算中它决定数据结构的选择。

=== 数值基准 <diffusion-benchmark>

仓库示例 `examples/d1q3-diffusion` 在周期区域上用单模态正弦初值 $phi(x,0)=1+0.5 sin(2 pi x/N)$ 同时运行 FTCS 与 D1Q3 LBM，解析解为振幅按 $e^(-D k^2 t)$ 衰减的同形状型线。程序输出确定性 CSV 与数据图，由 `make regenerate` 再生成。

#figure(
  image("../assets/generated/d1q3-diffusion.svg", width: 92%),
  caption: [数据图：一维正弦模态衰减的 FTCS 与 D1Q3 LBM 对比。子图 a 使用 $N=64$；$omega=1$ 演化 $500$ 步，$omega=1.5$ 演化 $1500$ 步，使两组数据到达同一无量纲时刻。子图 b 固定扩散数并令步数随 $N^2$ 增长。实线与圆点的重合表示 $omega=1$ 时 LBM 与 FTCS 代数等价；$omega=1.5$ 的曲线与二阶参考线平行。原始 CSV 和 SVG 由 `examples/d1q3-diffusion` 生成。],
) <d1q3-diffusion-plot>

结果与前文的理论论断一一对应：

- 型线重合。相同物理时刻，解析解、FTCS 与两种松弛率的 LBM 型线在绘图精度内不可区分。
- 等价性成立。$omega=1$ 时 LBM 与 $r=1/6$ FTCS 的误差曲线在十二位有效数字内一致，残差仅来自浮点运算次序，证实@omega-one-update 的代数等价。
- 魔数成立。$r=1/6$ 时两条重合的误差曲线沿四阶参考线下降；$omega=1.5$ 的 LBM 沿二阶参考线下降，说明四阶是参数抵消而非方法属性。

这些检查同时在 `cargo test -p d1q3-diffusion` 中作为回归测试存在：总量守恒、$omega=1$ 等价性、实测衰减率与解析值的一致性，以及收敛阶。

=== 代码性能基准 <diffusion-performance-benchmark>

正确性等价并不意味着执行成本相同。仓库中的 `diffusion-benchmark` 在 $omega=1$、$r=1/6$ 下比较两个求解器的 `step`；这个参数点使两者逐步给出同一数值结果，因此计时差别来自当前代码路径，而不是精度或物理时间不同。

```sh
make diffusion-bench
```

基准使用单线程发布构建。初始化和最终校验不计时；每个样本至少推进 $2^24$ 次格点更新，先预热 $2$ 次，再交替采集每种求解器的 $9$ 个样本。CSV 报告每格点每步耗时的中位数和中位绝对偏差（MAD），吞吐量用每秒百万格点更新数（MLUPS）表示。参考运行没有绑核或锁定 CPU 频率，结果适合比较当前两个实现，不适合作为跨机器性能指标。

#figure(
  image("../assets/benchmarks/d1q3-diffusion-performance.svg", width: 86%),
  caption: [数据图：当前 FTCS 与 D1Q3 LBM Rust 实现的单线程吞吐量。参考运行使用 Intel Core i7-8550U、Linux 7.0.0、`rustc 1.97.1` 和 `x86_64-unknown-linux-gnu` 发布构建；每点为 $9$ 个样本的中位数。完整耗时、MAD、命令和计时范围见同目录 CSV 与 TOML 元数据。],
) <d1q3-diffusion-performance-plot>

#table(
  columns: (1fr, 1fr, 1fr, 1fr),
  inset: 6pt,
  align: (right, right, right, right),
  table.header([$N$], [FTCS／MLUPS], [D1Q3 LBM／MLUPS], [FTCS 加速比]),
  [1 024], [$252.3$], [$162.3$], [$1.55$],
  [16 384], [$254.5$], [$163.9$], [$1.55$],
  [262 144], [$181.0$], [$111.5$], [$1.62$],
  [1 048 576], [$176.6$], [$105.3$], [$1.68$],
)

这次参考运行中，FTCS 比 D1Q3 LBM 快 $1.55$ 至 $1.68$ 倍。当前 FTCS 单步保留标量数组及其副本，峰值工作存储约为 $16N$ 字节；D1Q3 LBM 同时保留三个离散分布函数及迁移数组，约为 $48N$ 字节，并执行三个离散速度的碰撞和地址计算。大规模算例的吞吐量较低，与工作集逐渐越过缓存容量的现象一致，但确认具体瓶颈仍需要硬件性能计数器。

这个结果只比较本章的标量、单线程基线，不能推出“有限差分总比 LBM 快”。多维边界、数据布局、缓冲区复用、向量化和并行迁移都会改变结果。基准代码把原始数据和运行元数据留在输出目录，后续优化必须在相同配置下重新测量，而不是沿用这里的加速比。

== 源项与汇 <diffusion-source>

许多实际问题带源或汇：化学反应消耗、内热源、放射性衰变等。方程回到@scalar-conservation 的一维形式

$ partial_t phi = D partial_x^2 phi + R. $ <diffusion-with-source>

有限差分离散最直接：在@ftcs-update 右端加 $#dt R_j^n$。对时间显式求值使源项只有一阶精度；若 $R$ 随时间或随 $phi$ 变化且需要二阶，应对源项也使用梯形或中点求值。

LBM 在更新中增加离散源项：

$ overline(f)_i (x + c_i #dt, t + #dt)
= overline(f)_i (x, t)
- omega [overline(f)_i (x, t) - f_i^("eq") (x, t)]
+ #dt S_i. $ <lbe-source>

源项只进入零阶矩，约束为

$ sum_i S_i = R, quad sum_i c_i S_i = 0. $ <source-constraints>

最简单的取法是 $S_i = w_i R$。与外力项@guo-force 同理，当 $R$ 依赖时间或依赖 $phi$ 时，简单取法只给出一阶时间一致性；二阶一致需要梯形处理，相应的宏观量读出也要带半步修正，$phi = sum_i overline(f)_i + #dt R\/2$。常数源或慢变源在验证算例的精度内通常可以直接使用简单取法，但报告精度结论时应说明所用变体 @krueger2017。

两个经典验证算例覆盖源与汇：

- 均匀源、双 Dirichlet 稳态。区间 $[0,L]$ 两端固定 $phi=phi_b$，$R$ 为常数。稳态解析解是抛物线

$ phi(x) = phi_b + (R x (L-x))/(2 D), $ <steady-source-solution>

它不依赖时间格式，专用于检验源项强度映射与 Dirichlet 边界重构的联合误差。
- 线性汇、周期瞬态。$R=-k_r phi$（$k_r$ 为反应速率）时，正弦模态振幅按 $exp[-(D k^2+k_r)t]$ 衰减。用实测衰减率同时反推 $D$ 与 $k_r$，可以分离空间离散误差与源项时间积分误差。

== 二维扩散：格子与边界条件 <diffusion-2d>

二维扩散方程 $partial_t phi = D nabla^2 phi$ 的 LBM 构造沿用同一原则：平衡分布仍是 $f_i^("eq") = w_i phi$，只要求格子满足到二阶的各向同性。两个常用选择是：

- D2Q9：直接使用第三章的权重，$c_s^2=c^2/3$。优点是与流动求解器共享数据结构、索引和边界代码路径；
- D2Q5：只保留静止与四个轴向速度，取 $w_0=1/3$、$w_(1 dots 4)=1/6$，同样有 $c_s^2=c^2/3$。每格点少存四个分布，适合纯扩散的大规模计算。

两者的 Chapman–Enskog 分析与一维逐字平行，扩散系数仍由@diffusion-relaxation 给出，且各向同性由权重条件保证，不依赖方向。对角模态 $phi prop sin(k x)sin(k y)$ 与轴向模态的实测衰减率一致，是验证各向同性的直接手段。

二维部分的重点从格式本身转向边界条件。迁移结束后，来自域外的入射分布未知，宏观边界条件必须翻译成这些分布的重构规则。给定边界值 $phi_b$ 的 Dirichlet 条件和给定法向通量的 Neumann 条件，最终都要落到壁面格点的入射分布上。@diffusion-2d-boundaries-figure 汇总区域中的边界类型与半格距壁面的重构机制。

#figure(
  diffusion-2d-boundaries,
  caption: [概念示意图：二维区域的边界类型（子图 a）与半格距壁面的出射–入射结构（子图 b）。],
) <diffusion-2d-boundaries-figure>

后续各小节逐一给出重构公式；子图 b 的出射–入射结构是它们共同的框架。

=== 周期边界 <bc-periodic>

离开一侧的同方向分布送入另一侧。它不含近似，适合先验证体内格式与各向同性，也适合测量有效扩散系数。

=== Dirichlet 边界：给定边界值 <bc-dirichlet>

设壁面格点 $bold(x)_f$ 外侧为边界 $phi=phi_b$，反向索引满足 $bold(c)_(overline(i)) = -bold(c)_i$。常用重构是反弹跳（anti-bounce-back）：

$ overline(f)_i (bold(x)_f, t+#dt)
= -overline(f)_(overline(i))^star (bold(x)_f, t)
+ 2 w_i phi_b. $ <anti-bounce-back>

它把边界放在流体节点外侧半个格距处：出射与入射分布之和固定零阶矩为 $phi_b$，对直壁具有二阶精度。注意与流动的对照关系——标量的 Dirichlet 条件对应反弹的“反”号；无滑移速度壁用普通反弹，是因为它要固定的是一阶矩（速度）而非零阶矩。把两套规则混用是扩散边界实现中最常见的错误。

替代方案包括平衡覆盖（把入射分布直接设为 $w_i phi_b$）和用边界值加本地梯度重构的格式。平衡覆盖实现最简单，但壁面位置与精度特性不同；选择后必须用解析解重新标定误差，不能假设与反弹跳同阶。

=== Neumann 边界：给定通量 <bc-neumann>

零通量（绝热）边界对应普通反弹：

$ overline(f)_i (bold(x)_f, t+#dt)
= overline(f)_(overline(i))^star (bold(x)_f, t). $ <bounce-back>

入射等于出射使法向一阶矩为零，把零法向梯度放在半格距壁面处。这正是“绝热壁”在扩散 LBM 中几乎零成本的原因，也说明普通反弹固定的是通量而不是值。

非零给定通量 $-D partial_n phi = g$ 时，可在反弹跳族格式中把 $2 w_i phi_b$ 换成与 $g$ 成正比的项，或用本地差分估计法向梯度后重构入射分布。这类格式的壁面位置与阶数随实现而变，必须用已知通量的解析解单独验证。

=== Robin 边界与角点 <bc-robin-corner>

Robin 条件 $a phi + b partial_n phi = c$ 混合了值与通量，可由上述两类规则组合构造，例如按本地估计的值与梯度共同确定入射分布。其精度对估计方式敏感，文献方案之间差异较大，使用前应在与目标问题同族的解析解上标定 @mohamad2011。

角点处一个格点可能同时缺少多个方向的入射分布。按连接（link-wise）的规则——反弹与反弹跳都属于此类——逐条处理即可自动覆盖角点；需要格点级信息的格式则要为凸角、凹角分别定义取值。角点处理是否与直壁一致，应作为边界验证的一部分。

=== 二维经典算例 <diffusion-2d-cases>

- 周期域模态衰减：$phi = sin(k_x x) sin(k_y y)$，分别取轴向与对角波数，检验各向同性与有效扩散系数。
- 双平板稳态导热：上下壁 Dirichlet，可加均匀源，解析型线分别为直线与抛物线@steady-source-solution，检验 Dirichlet 重构的壁面位置。
- 一绝热一恒温通道：一侧 Neumann、一侧 Dirichlet，稳态仍为线性型线，但总量守恒只在绝热侧成立，可同时检验两类边界。
- 带角点的区域：在上述算例中截出矩形域，检验角点与直壁的一致性。

=== D2Q5 与 D2Q9 性能对比 <diffusion-2d-performance>

`lbm-core` 同时提供 D2Q5 与 D2Q9 格子，二维扩散示例则让两个具体求解器复用同一套碰撞、迁移和边界重构内核。D2Q5 的正确性不是由性能结果代替：测试沿用本节的三组验证，分别确认齐次 Dirichlet 算例的二阶收敛、全绝热边界下的总量守恒，以及等模长轴向与斜向模态的实测扩散系数一致。

独立的 `diffusion-benchmark` 在周期边界、$omega=1$ 下比较两个 `AoS` 标量基线：

```sh
make diffusion-2d-bench
```

基准只计时演化步，不计初始化和最终标量重构；每个样本至少包含 $2^24$ 次格点更新，先预热 $2$ 次，再交替采集每种格子的 $9$ 个样本。CSV 报告每格点每步耗时的中位数与中位绝对偏差，TOML 记录完整命令、硬件、工具链、问题参数和存储定义。与一维性能资产相同，参考数据单独存放在 `book/assets/benchmarks/`，不由 `make regenerate` 覆盖。

#figure(
  image("../assets/benchmarks/d2q5-d2q9-diffusion-performance.svg", width: 86%),
  caption: [数据图：当前 D2Q5 与 D2Q9 二维扩散 Rust 实现的单线程吞吐量。参考运行使用 Intel Core i7-8550U、Linux 7.0.0、`rustc 1.98.0` 和 `x86_64-unknown-linux-gnu` 发布构建；每点为 $9$ 个样本的中位数。完整耗时、MAD、命令和计时范围见同目录 CSV 与 TOML 元数据。],
) <d2q5-d2q9-diffusion-performance-plot>

#table(
  columns: (1fr, 1fr, 1fr, 1fr),
  inset: 6pt,
  align: (right, right, right, right),
  table.header([$N$], [D2Q5／MLUPS], [D2Q9／MLUPS], [D2Q5 加速比]),
  [64], [$77.7$], [$21.1$], [$3.68$],
  [128], [$72.3$], [$19.3$], [$3.75$],
  [256], [$70.1$], [$18.4$], [$3.81$],
  [512], [$63.2$], [$19.4$], [$3.25$],
)

一组 D2Q5 分布函数占 $5 times 8=40$ 字节／格点，D2Q9 占 $9 times 8=72$ 字节／格点；当前求解器同时保留分布与碰撞后缓冲区，所以工作存储分别为 $80$ 与 $144$ 字节／格点，D2Q5 少 $44.4%$。参考运行中 D2Q5 达到 $63.2$ 至 $77.7$ MLUPS，D2Q9 达到 $18.4$ 至 $21.1$ MLUPS，前者快 $3.25$ 至 $3.81$ 倍。这个差距与更少的离散速度、算术和工作存储一致，但不能只凭墙钟时间判定具体瓶颈；缓存未命中与指令成本的归因仍需要硬件性能计数器。结果也只适用于当前单线程 `AoS` 标量实现，不能外推到 `SoA`、分块、向量化或并行版本。

== 三维扩散：格子与边界条件 <diffusion-3d>

三维扩散的常用格子是 D3Q7：静止速度加六个轴向速度，取 $w_0=1/4$、$w_(1 dots 6)=1/8$，则 $sum_i w_i=1$、$sum_i w_i c_(i alpha) c_(i beta)=c_s^2 delta_(alpha beta)$ 且 $c_s^2=c^2/4$。需要与流动代码共享结构时，也可用 D3Q19 或 D3Q27 配 $f_i^("eq")=w_i phi$（$c_s^2=c^2/3$）。平衡、碰撞、扩散系数公式与一维、二维完全相同；维数只改变索引、存储和边界集合的大小。@diffusion-3d-domain-figure 给出三维区域的几何元素与 D3Q7 的速度集合。

#figure(
  diffusion-3d-domain,
  caption: [概念示意图：三维立方体区域的面、棱、角与坐标系（子图 a），以及 D3Q7 的离散速度与权重（子图 b）。],
) <diffusion-3d-domain-figure>

边界条件的格式不变，复杂性来自几何：

- 面：每个壁面格点沿外法向缺少入射分布，直接套用@anti-bounce-back 或@bounce-back，法向由该连接的方向确定；
- 棱与角：一个格点可能同时缺少两个或三个法向族的多条入射连接。按连接的规则仍然逐条成立，但要确认每条连接用哪一侧的边界值或通量；格点级格式必须显式处理棱角的取值平均；
- 曲面：半格距解释不再精确，球面、柱面等需要插值型反弹跳或浸入边界类格式，几何阶数要单独收敛验证。

三维经典算例包括：立方体稳态 Dirichlet 问题（可加均匀源，分离变量级数解），球体内的瞬态冷却或加热（球对称级数解，检验曲面边界），以及三维 Gaussian 峰的周期衰减（检验各向同性与有效扩散系数）。这些算例的计算量随维数显著上升，数据结构（AoS、SoA、分块）和并行策略开始影响实际吞吐，是把第四章的工程方法付诸实践的第一站。

== 验证要点 <diffusion-verification>

扩散算例的验证可以直接使用解析解，不需要外部基准数据：

- 守恒检查：周期边界或全绝热边界下 $sum_j phi_j$ 应逐时间步保持不变，误差仅来自浮点舍入；带 Dirichlet 边界时总量按边界通量的积分变化，可用于检验通量输出。
- 单模态衰减：取初值 $phi(x,0)=phi_0+a sin(k x)$，解析解保持同形状，振幅按 $e^(-D k^2 t)$ 衰减。用数值衰减率反推有效扩散系数并与@diffusion-relaxation 对比，可以检验松弛时间映射是否正确，包括半时间步修正。
- 参数巧合要识别：$omega=1$（$r=1/6$）时 D1Q3 LBM 与 FTCS 等价且首项误差抵消，呈四阶收敛；验证收敛阶时应换用一般参数（如 $omega=1.5$），避免把魔数结果当成方法的普遍精度。这个巧合还依赖空间维数，不能外推：二维时间离散必然产生 $partial_x^2 partial_y^2$ 交叉项，而五点空间误差不含对应项，因此没有任何扩散数能让二维 FTCS 超过二阶；$omega=1$ 的 D2Q9 则等价于九点格式而非五点格式，体内误差整体抵消到四阶。同一个记号在不同维数下对应不同结论，报告精度时必须说明维数与格子。
- 网格收敛：固定 $D$ 与区域，同步细化 $#dx$ 与 $#dt$。有限差分若保持扩散数 $r$ 不变（$#dt prop #dx^2$），误差按 $#dx^2$ 下降；LBM 常用固定 $overline(tau)$ 的细化方式，并应分别报告 $#dx$ 与 $#dt$ 方向的收敛行为，因为二者的误差来源不同。
- 源项检查：均匀源稳态抛物线@steady-source-solution 检验源强映射；线性汇的指数衰减把源项时间积分误差从空间误差中分离出来。
- 边界逐项验证：每类边界用独立的解析解标定——Dirichlet 用双板稳态，Neumann 用绝热通道守恒与线性型线，角点用矩形域算例，曲面用球内扩散。报告“二阶”时必须说明是否包含边界。

这些检查都能在中等规模的问题上完成，适合作为任何 LBM 新实现的第一个算例系列：它比流动问题少了压力、速度和复杂边界重构的干扰，却同样能暴露权重、索引、松弛时间映射、源项和迁移方向上的实现错误。
