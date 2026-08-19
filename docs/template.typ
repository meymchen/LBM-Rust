#let project(title: none, subtitle: none, authors: (), body) = {
  set document(title: title, author: authors)
  set page(
    paper: "a4",
    margin: (x: 24mm, y: 22mm),
    numbering: "1 / 1",
  )
  set text(
    font: ("Noto Serif CJK SC", "Noto Serif"),
    lang: "zh",
    size: 10.5pt,
  )
  set par(justify: true, leading: 0.75em)
  set heading(numbering: "1.1")
  show raw.where(block: true): content => block(
    fill: rgb("f5f7fa"),
    inset: 10pt,
    radius: 4pt,
    width: 100%,
    content,
  )

  align(center)[
    #v(30mm)
    #text(size: 28pt, weight: "bold")[#title]
    #v(6mm)
    #text(size: 15pt, fill: rgb("465568"))[#subtitle]
    #v(24mm)
    #text(size: 11pt)[#authors.join(" · ")]
    #v(1fr)
    #text(size: 9pt, fill: gray)[Apache-2.0 · Rust + Typst]
  ]

  pagebreak()
  outline(title: [目录], indent: auto)
  pagebreak()
  body
}
