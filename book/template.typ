#let equation-prefix = state("equation-prefix", none)

#let equation-scope(prefix) = {
  equation-prefix.update(prefix)
  counter(math.equation).update(0)
}

#let project(document-title: none, title: none, subtitle: none, authors: (), body) = {
  set document(
    title: if document-title == none { title } else { document-title },
    author: authors,
  )
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
  set math.equation(numbering: number => context {
    let prefix = equation-prefix.get()
    if prefix == none {
      panic("公式块所在的无编号区域未定义公式编号前缀")
    }
    [(#prefix.#number)]
  })
  show heading.where(level: 1): it => context {
    if it.numbering == none {
      equation-prefix.update(none)
      counter(math.equation).update(0)
    } else {
      let prefix = numbering(it.numbering, ..counter(heading).get())
      equation-prefix.update(prefix)
      counter(math.equation).update(0)
    }
    it
  }
  show raw.where(block: true): content => block(
    fill: rgb("f5f7fa"),
    inset: 10pt,
    radius: 4pt,
    width: 100%,
    content,
  )

  align(center)[
    #v(30mm)
    #text(size: 22pt, weight: "bold")[#box[#title]]
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
