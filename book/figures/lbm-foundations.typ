#import "@preview/cetz:0.4.2": canvas, draw
#import "components.typ": collision, diagram-note, guide, ink, muted, panel-title, transport

#let d2q9-data = csv("../assets/generated/d2q9-equilibrium.csv").slice(1)

#let d1q3 = {
  grid(
    columns: (1fr, 1fr),
    gutter: 14pt,
    align: center + top,
    [
      #panel-title("a", [离散速度])
      #v(3pt)
      #align(center)[
        #canvas(length: 10mm, {
          import draw: *
          set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.7, fill: ink))

          line((-2.5, 0), (2.5, 0), stroke: guide + 0.6pt)
          for x in range(-2, 3) {
            circle((x, 0), radius: 0.07, fill: if x == 0 { ink } else { white }, stroke: ink + 0.7pt)
          }
          line((0, 0.18), (-1.65, 0.18), stroke: transport + 1pt, mark: (end: "stealth", fill: transport))
          line((0, -0.18), (1.65, -0.18), stroke: transport + 1pt, mark: (end: "stealth", fill: transport))
          circle((0, 0), radius: 0.14, stroke: ink + 1pt)

          content((-1.65, 0.52), text(size: 9pt, fill: transport)[$e_- = -1$], anchor: "south")
          content((0, 0.52), text(size: 9pt)[$e_0 = 0$], anchor: "south")
          content((1.65, 0.52), text(size: 9pt, fill: transport)[$e_+ = 1$], anchor: "south")
          content((0, -0.48), text(size: 9pt)[$x$], anchor: "north")
        })
      ]
    ],
    [
      #panel-title("b", [静止平衡分布])
      #v(3pt)
      #align(center)[
        #canvas(length: 10mm, {
          import draw: *
          set-style(stroke: (thickness: 0.75pt, cap: "round"), mark: (scale: 0.65, fill: ink))

          line((-1.65, 0), (1.8, 0), stroke: ink + 0.8pt, mark: (end: "stealth"))
          line((-1.45, 0), (-1.45, 1.95), stroke: ink + 0.8pt, mark: (end: "stealth"))
          for (x, height, label) in ((-1.0, 0.42, $1/6$), (0.0, 1.65, $2/3$), (1.0, 0.42, $1/6$)) {
            line((x, 0), (x, height), stroke: transport + 1.3pt)
            circle((x, height), radius: 0.10, fill: white, stroke: transport + 1pt)
            content((x, height + 0.18), text(size: 9pt)[#label], anchor: "south")
          }
          for (x, label) in ((-1.0, $-$), (0.0, $0$), (1.0, $+$)) {
            content((x, -0.15), text(size: 9pt)[$i = #label$], anchor: "north")
          }
          content((1.86, 0), text(size: 9pt)[$i$], anchor: "west")
          content((-1.45, 2.02), text(size: 9pt)[$f_i^"eq" / rho$], anchor: "south")
        })
      ]
    ],
  )
  diagram-note([速度箭头长度只表示一次迁移的格距；右图用独立纵轴表示分布量，避免混淆两个物理量。])
}

#let local-stencil(color: transport, outgoing: false) = canvas(length: 6.3mm, {
  import draw: *
  set-style(stroke: (thickness: 0.8pt, cap: "round"), mark: (scale: 0.6, fill: color))
  grid((-1, -1), (1, 1), step: 1, stroke: guide + 0.4pt)
  for x in range(-1, 2) {
    for y in range(-1, 2) {
      circle((x, y), radius: 0.055, fill: ink)
    }
  }
  if outgoing {
    for target in ((1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, 1), (-1, -1), (1, -1)) {
      line((0, 0), target, stroke: color + 0.8pt, mark: (end: "stealth"))
    }
  } else {
    for start in ((1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, 1), (-1, -1), (1, -1)) {
      line(start, (0, 0), stroke: color + 0.8pt, mark: (end: "stealth"))
    }
  }
  circle((0, 0), radius: 0.10, fill: white, stroke: ink + 0.9pt)
})

#let lbm-step = {
  grid(
    columns: (1fr, 1fr, 1fr, 1fr),
    gutter: 9pt,
    align: center + top,
    [
      #panel-title("a", [求宏观量])
      #v(4pt)
      #align(center)[#local-stencil()]
      #v(4pt)
      #align(center)[#text(size: 9pt)[$rho = sum_i f_i$]]
      #align(center)[#text(size: 9pt)[$rho bold(u) = sum_i f_i bold(e)_i$]]
    ],
    [
      #panel-title("b", [求平衡分布])
      #v(4pt)
      #align(center)[
        #canvas(length: 6.3mm, {
          import draw: *
          circle((0, 0), radius: 0.12, fill: ink)
          for (angle, radius) in ((0deg, 0.95), (45deg, 0.68), (90deg, 0.78), (135deg, 0.55), (180deg, 0.62), (225deg, 0.48), (270deg, 0.70), (315deg, 0.58)) {
            line((0, 0), (angle, radius), stroke: guide + 2.2pt, cap: "round")
            circle((angle, radius), radius: 0.07, fill: white, stroke: ink + 0.7pt)
          }
          content((0, -1.25), text(size: 9pt)[$f_i^"eq" = f_i^"eq"(rho, bold(u))$], anchor: "north")
        })
      ]
    ],
    [
      #panel-title("c", [局部碰撞])
      #v(4pt)
      #align(center)[
        #canvas(length: 6.3mm, {
          import draw: *
          set-style(mark: (scale: 0.65, fill: collision))
          content((-0.9, 0), text(size: 10pt)[$f_i$], anchor: "center")
          line((-0.55, 0), (0.55, 0), stroke: collision + 1pt, mark: (end: "stealth"))
          content((0.9, 0), text(size: 10pt)[$f_i^star$], anchor: "center")
          content((0, -0.55), text(size: 9pt)[$sum_i f_i^star = sum_i f_i$], anchor: "north")
          content((0, 0.55), text(size: 9pt, fill: collision)[同一格点], anchor: "south")
        })
      ]
    ],
    [
      #panel-title("d", [沿格线迁移])
      #v(4pt)
      #align(center)[#local-stencil(outgoing: true)]
      #v(4pt)
      #align(center)[#text(size: 9pt)[$x arrow.r x + bold(e)_i$]]
    ],
  )
  v(5pt)
  {
    set math.equation(numbering: none)
    align(center)[$
      underbrace((rho, bold(u)) arrow.r f_i^"eq", "局部状态")
      quad arrow.r quad
      underbrace(f_i^star, "碰撞")
      quad arrow.r quad
      underbrace(f_i(x + bold(e)_i, t + 1), "迁移")
    $]
  }
  diagram-note([碰撞只在一个格点内重分配离散分布；迁移才把碰撞后的分布送往相邻格点。])
}

#let d2q9 = {
  align(center)[
    #canvas(length: 12mm, {
      import draw: *
      set-style(
        stroke: (thickness: 0.75pt, cap: "round"),
        mark: (scale: 0.68, fill: ink),
        content: (padding: 1.5pt),
      )

      grid((-2, -2), (2, 2), step: 1, stroke: guide + 0.45pt)
      for x in range(-2, 3) {
        for y in range(-2, 3) {
          circle((x, y), radius: 0.045, fill: muted)
        }
      }
      line((-2.35, -2.25), (2.45, -2.25), stroke: ink + 0.7pt, mark: (end: "stealth"))
      line((-2.25, -2.35), (-2.25, 2.45), stroke: ink + 0.7pt, mark: (end: "stealth"))
      content((2.5, -2.25), text(size: 9pt)[$x$], anchor: "west")
      content((-2.25, 2.5), text(size: 9pt)[$y$], anchor: "south")

      for row in d2q9-data {
        let index = int(row.at(0))
        let cx = int(row.at(1))
        let cy = int(row.at(2))
        if index == 0 {
          circle((0, 0), radius: 0.12, fill: white, stroke: ink + 1.1pt)
          content((0.16, 0.17), text(size: 9pt, weight: "bold")[$i = 0$], anchor: "south-west")
        } else {
          let color = if index <= 4 { transport } else { collision }
          line((0, 0), (cx * 0.92, cy * 0.92), stroke: color + 1pt, mark: (end: "stealth", fill: color))
          let lx = cx * 1.18
          let ly = cy * 1.18
          content((lx, ly), text(size: 9pt, weight: "bold", fill: color)[$#index$], anchor: "center")
        }
      }

      content((2.75, 1.15), text(size: 9pt, fill: transport)[轴向：$w_i = 1/9$], anchor: "west")
      line((2.25, 0.72), (2.65, 0.72), stroke: transport + 1pt, mark: (end: "stealth", fill: transport))
      content((2.75, 0.72), text(size: 9pt, fill: collision)[对角：$w_i = 1/36$], anchor: "west")
      line((2.25, 0.29), (2.65, 0.29), stroke: collision + 1pt, mark: (end: "stealth", fill: collision))
      circle((2.45, -0.14), radius: 0.10, fill: white, stroke: ink + 1pt)
      content((2.75, -0.14), text(size: 9pt)[静止：$w_0 = 4/9$], anchor: "west")
    })
  ]
  diagram-note([箭头端点落在相邻格点上；索引和离散速度由 Rust 生成的 CSV 决定。])
}
