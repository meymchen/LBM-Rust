#import "@preview/cetz:0.4.2": canvas, draw
#import "components.typ": collision, diagram-note, field, guide, ink, muted, transport

#let control-volume = {
  align(center)[
    #canvas(length: 9mm, {
      import draw: *

      set-style(
        stroke: (thickness: 0.8pt, cap: "round", join: "round"),
        mark: (fill: ink, scale: 0.7),
        content: (padding: 1.5pt),
      )

      line((-1.0, 2.0), (1.2, 2.05), (3.5, 2.18), (5.7, 2.05), (8.0, 2.1),
        stroke: transport + 1.2pt,
        mark: (end: "stealth", fill: transport),
      )
      line((-1.0, 3.3), (1.1, 3.38), (3.7, 3.52), (5.8, 3.32), (8.0, 3.4),
        stroke: transport + 0.7pt,
        mark: (end: "stealth", fill: transport),
      )
      rect((1.6, 0.7), (5.7, 4.5), fill: field.transparentize(35%), stroke: ink + 1pt)
      content((3.65, 2.6), text(size: 12pt, weight: "bold")[$V$], anchor: "center")
      content((3.65, 0.55), text(size: 9pt, fill: muted)[$partial V$], anchor: "north")

      for (start, end, anchor, offset) in (
        ((1.6, 2.7), (0.85, 2.7), "east", (-0.12, 2.95)),
        ((5.7, 2.7), (6.45, 2.7), "west", (6.57, 2.95)),
        ((3.65, 4.5), (3.65, 5.25), "south", (3.88, 5.35)),
        ((3.65, 0.7), (3.65, -0.05), "north", (3.88, -0.12)),
      ) {
        line(start, end, stroke: ink + 0.9pt, mark: (end: "stealth"))
        content(offset, text(size: 9pt)[$bold(n)$], anchor: anchor)
      }

      line((0.0, 1.25), (1.35, 1.25), stroke: guide + 0.6pt, mark: (end: "stealth", fill: guide))
      content((0.65, 0.95), text(size: 9pt, fill: transport)[$bold(u) dot bold(n) < 0$], anchor: "north")
      content((0.65, 1.55), text(size: 9pt, weight: "bold", fill: transport)[流入], anchor: "south")

      line((5.95, 1.25), (7.3, 1.25), stroke: guide + 0.6pt, mark: (end: "stealth", fill: guide))
      content((6.62, 0.95), text(size: 9pt, fill: collision)[$bold(u) dot bold(n) > 0$], anchor: "north")
      content((6.62, 1.55), text(size: 9pt, weight: "bold", fill: collision)[流出], anchor: "south")

      content((3.65, 5.75), text(size: 9.5pt)[外法向决定通量的正负], anchor: "south")
    })
  ]
  v(3pt)
  {
    set math.equation(numbering: none)
    align(center)[$
      underbrace((dif)/(dif t) integral_V rho dif V, "控制体内的积累")
      = - underbrace(integral_(partial V) rho bold(u) dot bold(n) dif A, "通过边界的净流出")
    $]
  }
  diagram-note([蓝色曲线表示流线；控制体和外法向是几何定义，不随流动方向改变。])
}
