#import "@preview/cetz:0.4.2": canvas, draw
#import "../symbols.typ": dt, dx
#import "components.typ": collision, diagram-note, field, guide, ink, muted, panel-title, transport

// 章首抽象插图：标量团在三个时刻的扩散。
// 点子用低差异序列加 Box–Muller 变换按 Gaussian 密度布置，位置完全确定。
#let diffusion-hero = {
  align(center)[
    #canvas(length: 7.2mm, {
      import draw: *
      set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.7, fill: muted))

      for (cx, sigma, peak, tlabel) in (
        (0.0, 0.50, 1.50, $t_1$),
        (4.8, 0.71, 1.06, $t_2$),
        (9.6, 0.87, 0.87, $t_3$),
      ) {
        let envelope = range(49).map(i => {
          let offset = -3 * sigma + 6 * sigma * i / 48
          (cx + offset, 1.0 + peak * calc.exp(-offset * offset / (2 * sigma * sigma)))
        })
        line(..envelope, stroke: transport + 1pt)

        for k in range(46) {
          let u = k * 0.6180339887
          u = u - calc.floor(u)
          let v = k * 0.7548776662
          v = v - calc.floor(v)
          let radius = sigma * calc.sqrt(-2 * calc.ln(1 - u))
          let angle = 2 * calc.pi * v
          let density = calc.exp(-radius * radius / (2 * sigma * sigma))
          circle(
            (cx + radius * calc.cos(angle), 0.35 + 0.5 * radius * calc.sin(angle)),
            radius: 0.045 + 0.075 * density,
            fill: transport.transparentize(30% + 55% * (1 - density)),
            stroke: none,
          )
        }

        content((cx, -1.32), text(size: 9pt)[#tlabel], anchor: "north")
      }

      line((-0.4, -1.05), (10.9, -1.05), stroke: muted + 0.8pt, mark: (end: "stealth"))
      content((10.9, -1.05), text(size: 9pt, fill: muted)[时间], anchor: "north-west")
    })
  ]
  diagram-note([点子密度抽象表示标量浓度的高低，不表示粒子轨迹；包络峰值随时间下降，宽度按时间的平方根增长，而总量不变。])
}

// 一维问题：物理场、坐标系与边界条件。
#let diffusion-1d-problem = {
  grid(
    columns: (1fr, 1fr),
    gutter: 14pt,
    align: center + top,
    [
      #panel-title("a", [物理场、坐标与边界])
      #v(3pt)
      #align(center)[
        #canvas(length: 6mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: ink))

          for k in range(24) {
            let shade = (calc.sin(2 * calc.pi * (k + 0.5) / 24) + 1) / 2
            rect(
              (0.25 * k, 0.27),
              (0.25 * (k + 1), 0.93),
              fill: transport.transparentize(92% - 55% * shade),
              stroke: none,
            )
          }
          rect((0, 0.25), (6, 0.95), fill: none, stroke: ink + 0.9pt)

          let profile = range(61).map(i => {
            let x = 6 * i / 60
            (x, 1.7 + 0.75 * calc.sin(2 * calc.pi * x / 6))
          })
          line(..profile, stroke: transport + 1.1pt)
          content((6.12, 1.7), text(size: 9pt)[$phi(x,0)$], anchor: "west")

          for (start, end) in ((1.0, 0.4), (2.0, 2.6), (3.7, 4.3), (5.3, 4.7)) {
            line((start, 0.6), (end, 0.6), stroke: collision + 1pt, mark: (end: "stealth", fill: collision))
          }

          arc((6.45, 0.6), start: 86deg, stop: -86deg, radius: 0.3,
            stroke: muted + 0.9pt, mark: (end: "stealth", fill: muted))
          arc((-0.45, 0.6), start: 94deg, stop: 266deg, radius: 0.3,
            stroke: muted + 0.9pt, mark: (end: "stealth", fill: muted))
          content((-0.45, 1.02), text(size: 9pt, fill: muted)[周期], anchor: "south")
          content((6.45, 1.02), text(size: 9pt, fill: muted)[周期], anchor: "south")

          line((0, -0.35), (6.4, -0.35), stroke: ink + 0.8pt, mark: (end: "stealth"))
          content((6.42, -0.35), text(size: 9pt)[$x$], anchor: "north-west")
          line((0, -0.4), (0, -0.3), stroke: ink + 0.8pt)
          content((0, -0.42), text(size: 9pt)[$0$], anchor: "north")
          line((6, -0.4), (6, -0.3), stroke: ink + 0.8pt)
          content((6, -0.42), text(size: 9pt)[$L$], anchor: "north")

          content((3.0, -0.9), text(size: 9pt)[通量 $j = -D partial_x phi$ 由高处指向低处], anchor: "north")
        })
      ]
    ],
    [
      #panel-title("b", [初始条件与解析衰减])
      #v(3pt)
      #align(center)[
        #canvas(length: 6mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: ink))

          line((0, 0), (6.4, 0), stroke: ink + 0.8pt, mark: (end: "stealth"))
          content((6.4, 0), text(size: 9pt)[$x$], anchor: "north-west")
          line((0, -0.15), (0, 2.75), stroke: ink + 0.8pt, mark: (end: "stealth"))
          content((0, 2.75), text(size: 9pt)[$phi$], anchor: "south-west")

          let initial = range(61).map(i => {
            let x = 6 * i / 60
            (x, 1.3 + 0.95 * calc.sin(2 * calc.pi * x / 6))
          })
          line(..initial, stroke: transport + 1.1pt)
          let later = range(61).map(i => {
            let x = 6 * i / 60
            (x, 1.3 + 0.45 * calc.sin(2 * calc.pi * x / 6))
          })
          line(..later, stroke: muted + 1pt, dash: "dashed")

          line((1.5, 2.15), (1.5, 1.78), stroke: ink + 0.9pt, mark: (end: "stealth"))
          content((1.5, 1.62), text(size: 9pt)[指数衰减], anchor: "north")
        })
      ]
    ],
  )
  diagram-note([杆内色深表示标量高低；正弦初值的形状不变、振幅指数衰减，这为数值验证提供了解析基准。子图 b 实线为 $t=0$，虚线为 $t>0$。])
}

// 同一网格上两种方法的状态变量。
#let diffusion-1d-states = {
  grid(
    columns: (1fr, 1fr),
    gutter: 14pt,
    align: center + top,
    [
      #panel-title("a", [有限差分：每点一个标量])
      #v(3pt)
      #align(center)[
        #canvas(length: 5.2mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: ink))

          line((-0.3, 0), (5.9, 0), stroke: guide + 0.6pt)
          for (x, height) in ((0, 0.35), (1.4, 0.72), (2.8, 1.08), (4.2, 0.76), (5.6, 0.38)) {
            line((x, 0), (x, height), stroke: transport + 1.2pt)
            circle((x, height), radius: 0.09, fill: white, stroke: transport + 0.9pt)
            circle((x, 0), radius: 0.06, fill: ink)
          }
          content((2.8, -0.2), text(size: 9pt)[$phi_j$], anchor: "north")
          line((1.4, -0.78), (2.8, -0.78), stroke: muted + 0.8pt, mark: (start: "stealth", end: "stealth", fill: muted))
          content((2.1, -0.86), text(size: 9pt, fill: muted)[$#dx$], anchor: "north")
        })
      ]
    ],
    [
      #panel-title("b", [LBM：每点三个分布])
      #v(3pt)
      #align(center)[
        #canvas(length: 5.2mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: ink))

          line((-0.3, 0), (5.9, 0), stroke: guide + 0.6pt)
          for x in (0.4, 5.2) {
            circle((x, 0), radius: 0.06, fill: ink)
          }
          circle((2.8, 0), radius: 0.13, fill: white, stroke: ink + 0.9pt)
          line((2.65, 1.35), (0.85, 1.35), stroke: transport + 1pt, mark: (end: "stealth", fill: transport))
          line((2.95, 1.35), (4.75, 1.35), stroke: transport + 1pt, mark: (end: "stealth", fill: transport))

          for (x, height) in ((2.3, 0.4), (2.8, 1.05), (3.3, 0.4)) {
            line((x, 0), (x, height), stroke: transport + 1.2pt)
            circle((x, height), radius: 0.09, fill: white, stroke: transport + 0.9pt)
          }
          line((0.4, -0.78), (2.8, -0.78), stroke: muted + 0.8pt, mark: (start: "stealth", end: "stealth", fill: muted))
          content((1.6, -0.86), text(size: 9pt, fill: muted)[$#dx$], anchor: "north")
        })
      ]
      #v(4pt)
      #align(center)[#text(size: 9pt)[三个柱依次为左行 $overline(f)_2$、静止 $overline(f)_0$、右行 $overline(f)_1$。]]
    ],
  )
  diagram-note([同一套网格上，有限差分每点保存一个标量，LBM 每点保存三个分布；分布的一阶矩给出通量。])
}

// D1Q3 单步：从格点上的三个分布，到碰撞后的分布，再迁移到相邻格点。
#let diffusion-lbm-step = {
  grid(
    columns: (1fr, 1fr, 1fr),
    gutter: 10pt,
    align: center + top,
    [
      #panel-title("a", [恢复宏观量])
      #v(3pt)
      #align(center)[
        #canvas(length: 4.7mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: ink))

          line((-0.25, 0), (4.25, 0), stroke: guide + 0.6pt)
          circle((2, 0), radius: 0.08, fill: ink)
          for (x, height, label) in ((1.35, 0.55, $overline(f)_2$), (2, 1.35, $overline(f)_0$), (2.65, 0.78, $overline(f)_1$)) {
            line((x, 0), (x, height), stroke: transport + 1.2pt)
            circle((x, height), radius: 0.075, fill: white, stroke: transport + 0.9pt)
            content((x, height + 0.17), text(size: 8.5pt)[#label], anchor: "south")
          }
          content((2, -0.45), text(size: 9pt)[$phi = sum_i overline(f)_i$], anchor: "north")
        })
      ]
    ],
    [
      #panel-title("b", [本地碰撞])
      #v(3pt)
      #align(center)[
        #canvas(length: 4.7mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: collision))

          circle((2, 0), radius: 0.08, fill: ink)
          for (x, before, after) in ((1.35, 0.55, 0.68), (2, 1.35, 1.18), (2.65, 0.78, 0.72)) {
            line((x, 0), (x, before), stroke: guide + 1pt, dash: "dashed")
            line((x, 0), (x, after), stroke: collision + 1.3pt)
            circle((x, after), radius: 0.075, fill: white, stroke: collision + 0.9pt)
          }
          content((2, 1.78), text(size: 8.5pt)[$overline(f)_i^star = overline(f)_i - omega (overline(f)_i-f_i^("eq"))$], anchor: "south")
          content((2, -0.45), text(size: 9pt)[$sum_i overline(f)_i^star = phi$], anchor: "north")
        })
      ]
    ],
    [
      #panel-title("c", [迁移与周期回绕])
      #v(3pt)
      #align(center)[
        #canvas(length: 4.7mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: transport))

          line((-0.2, 0), (4.2, 0), stroke: guide + 0.6pt)
          for x in (0, 2, 4) {
            circle((x, 0), radius: 0.08, fill: ink)
          }
          line((1.85, 0.55), (0.25, 0.55), stroke: transport + 1.1pt, mark: (end: "stealth", fill: transport))
          line((2.15, 0.95), (3.75, 0.95), stroke: transport + 1.1pt, mark: (end: "stealth", fill: transport))
          line((2, 0.15), (2, 1.35), stroke: ink + 1.1pt)
          arc((4.35, 0.45), start: 90deg, stop: -90deg, radius: 0.38,
            stroke: muted + 0.9pt, mark: (end: "stealth", fill: muted))
          content((2, -0.45), text(size: 9pt)[目的格点由 $x+c_i #dt$ 决定], anchor: "north")
        })
      ]
    ],
  )
  diagram-note([图例：蓝色表示离散分布函数及其迁移，橙色表示碰撞后的值，灰色虚线表示碰撞前的值。碰撞只改写同一格点内的三个分量；迁移只搬运，不做浮点计算。])
}

// 二维区域的边界类型与半格距壁面的入射重构。
#let diffusion-2d-boundaries = {
  grid(
    columns: (1fr, 1fr),
    gutter: 14pt,
    align: center + top,
    [
      #panel-title("a", [区域与四类边界])
      #v(3pt)
      #align(center)[
        #canvas(length: 6.6mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: ink))

          rect((0, 0), (4, 4), fill: field.transparentize(35%), stroke: ink + 1pt)
          for x in (1.0, 2.0, 3.0) {
            for y in (1.0, 2.0, 3.0) {
              circle((x, y), radius: 0.045, fill: muted)
            }
          }
          content((2, 2.48), text(size: 9.5pt)[$partial_t phi = D nabla^2 phi$], anchor: "center")

          line((0, 4), (4, 4), stroke: ink + 1.8pt)
          content((2, 4.18), text(size: 9pt)[Dirichlet：$phi = phi_b$], anchor: "south")
          line((0, 0), (4, 0), stroke: muted + 1.8pt)
          content((2, -0.18), text(size: 9pt, fill: muted)[Neumann：$partial_n phi = 0$], anchor: "north")
          line((0, 0), (0, 4), stroke: transport + 1.1pt, dash: "dashed")
          line((4, 0), (4, 4), stroke: transport + 1.1pt, dash: "dashed")
          arc((-0.32, 2.0), start: 88deg, stop: 272deg, radius: 0.55,
            stroke: transport + 0.9pt, mark: (end: "stealth", fill: transport))
          arc((4.32, 2.0), start: 92deg, stop: -92deg, radius: 0.55,
            stroke: transport + 0.9pt, mark: (end: "stealth", fill: transport))
          content((-0.42, 2.0), text(size: 9pt, fill: transport)[周期], anchor: "east")
          content((4.42, 2.0), text(size: 9pt, fill: transport)[周期], anchor: "west")

          line((0.35, 0.35), (1.25, 0.35), stroke: ink + 0.8pt, mark: (end: "stealth"))
          content((1.3, 0.35), text(size: 9pt)[$x$], anchor: "west")
          line((0.35, 0.35), (0.35, 1.25), stroke: ink + 0.8pt, mark: (end: "stealth"))
          content((0.35, 1.3), text(size: 9pt)[$y$], anchor: "south")
        })
      ]
    ],
    [
      #panel-title("b", [半格距壁面与入射重构])
      #v(3pt)
      #align(center)[
        #canvas(length: 6.6mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: ink))

          rect((3.5, 0.3), (4.7, 2.1), fill: guide.transparentize(65%), stroke: none)
          content((4.1, 1.85), text(size: 9pt, fill: muted)[域外], anchor: "center")
          line((3.5, 0.3), (3.5, 2.1), stroke: muted + 0.9pt, dash: "dashed")

          line((-0.3, 1.2), (3.3, 1.2), stroke: guide + 0.6pt)
          for x in (0, 1.4, 2.8) {
            circle((x, 1.2), radius: 0.06, fill: ink)
          }
          content((2.8, 1.02), text(size: 9pt)[$bold(x)_f$], anchor: "north")

          line((2.87, 1.42), (3.66, 1.42), stroke: ink + 1pt, mark: (end: "stealth"))
          line((3.66, 0.98), (2.87, 0.98), stroke: transport + 1pt, mark: (end: "stealth", fill: transport))

          line((2.8, 1.78), (3.5, 1.78), stroke: muted + 0.8pt, mark: (start: "stealth", end: "stealth", fill: muted))
          content((3.15, 1.9), text(size: 9pt, fill: muted)[$#dx\/2$], anchor: "south")
        })
      ]
      #v(4pt)
      #align(center)[#text(size: 9pt)[壁面格点 $bold(x)_f$ 的出射 $overline(f)_(overline(i))^star$ 为深色箭头；入射 $overline(f)_i$ 为蓝色箭头，由边界条件重构。]]
    ],
  )
  diagram-note([宏观边界条件逐条翻译为入射分布的重构规则；壁面位于流体节点外侧半个格距处。])
}

// 三维立方体区域与 D3Q7 离散速度。
#let diffusion-3d-domain = {
  grid(
    columns: (1fr, 1fr),
    gutter: 14pt,
    align: center + top,
    [
      #panel-title("a", [立方体区域与边界元素])
      #v(3pt)
      #align(center)[
        #canvas(length: 5.8mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round", join: "round"), mark: (scale: 0.65, fill: ink))

          line((0, 2.4), (2.4, 2.4), (3.4, 3.3), (1.0, 3.3), close: true,
            fill: field.transparentize(15%), stroke: ink + 0.9pt)
          line((2.4, 0), (3.4, 0.9), (3.4, 3.3), (2.4, 2.4), close: true,
            fill: field.transparentize(45%), stroke: ink + 0.9pt)
          line((0, 0), (2.4, 0), (2.4, 2.4), (0, 2.4), close: true,
            fill: field.transparentize(30%), stroke: ink + 0.9pt)
          line((0, 0), (1.0, 0.9), (1.0, 3.3), stroke: ink + 0.9pt)
          line((1.0, 0.9), (3.4, 0.9), stroke: ink + 0.9pt)

          line((2.2, 2.85), (2.2, 3.75), stroke: ink + 0.9pt, mark: (end: "stealth"))
          content((2.32, 3.75), text(size: 9pt)[$bold(n)$], anchor: "west")

          line((-0.2, -0.2), (0.75, -0.2), stroke: ink + 0.8pt, mark: (end: "stealth"))
          content((0.8, -0.2), text(size: 9pt)[$x$], anchor: "west")
          line((-0.2, -0.2), (-0.2, 0.75), stroke: ink + 0.8pt, mark: (end: "stealth"))
          content((-0.2, 0.8), text(size: 9pt)[$y$], anchor: "south")
          line((-0.2, -0.2), (-0.74, -0.69), stroke: ink + 0.8pt, mark: (end: "stealth"))
          content((-0.78, -0.73), text(size: 9pt)[$z$], anchor: "north")

          content((-0.6, 0.9), text(size: 9pt)[面], anchor: "east")
          line((-0.55, 0.9), (0.85, 1.1), stroke: guide + 0.7pt)
          content((4.35, 1.45), text(size: 9pt)[棱], anchor: "west")
          line((4.3, 1.42), (2.45, 1.25), stroke: guide + 0.7pt)
          circle((2.4, 2.4), radius: 0.07, fill: ink)
          content((4.35, 2.75), text(size: 9pt)[角], anchor: "west")
          line((4.3, 2.72), (2.48, 2.44), stroke: guide + 0.7pt)
        })
      ]
    ],
    [
      #panel-title("b", [D3Q7 离散速度])
      #v(3pt)
      #align(center)[
        #canvas(length: 5.8mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.65, fill: transport))

          let directions = (
            (1.0, 0.0), (-1.0, 0.0),
            (0.0, 1.0), (0.0, -1.0),
            (0.62, 0.56), (-0.62, -0.56),
          )
          for direction in directions {
            let target = (direction.at(0) * 1.55, direction.at(1) * 1.55)
            line((0, 0), target, stroke: transport + 1pt, mark: (end: "stealth"))
          }
          circle((0, 0), radius: 0.14, fill: white, stroke: ink + 1pt)
          circle((0, 0), radius: 0.06, fill: ink)

          content((1.7, 0.25), text(size: 9pt)[轴向 $w = 1\/8$], anchor: "west")
          content((1.15, -1.2), text(size: 9pt)[静止 $w_0 = 1\/4$], anchor: "north")
        })
      ]
    ],
  )
  diagram-note([三维边界按面、棱、角分类处理；D3Q7 只保留六个轴向速度与一个静止速度。])
}
