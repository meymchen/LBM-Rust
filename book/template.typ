#let equation-prefix = state("equation-prefix", none)
#let figure-prefix = state("figure-prefix", none)
#let book-figure = figure.where(kind: "book-figure")

#let equation-scope(prefix) = {
  equation-prefix.update(prefix)
  counter(math.equation).update(0)
}

#let figure-scope(prefix) = {
  figure-prefix.update(prefix)
  counter(book-figure).update(0)
}

// 按章固定公式与图编号前缀。闭包在章作用域内绑定字面前缀，
// 因此跨章 ref 渲染的是目标公式所在章的编号，而非引用处的编号。
#let chapter-body(prefix, body) = {
  counter(math.equation).update(0)
  counter(book-figure).update(0)
  set math.equation(numbering: number => [(#prefix.#number)])
  set figure(
    kind: "book-figure",
    supplement: [图],
    numbering: number => [#prefix\-#number],
  )
  body
}

#let chapter(body) = context chapter-body(
  str(counter(heading).get().first() + 1),
  body,
)

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
  set figure(
    kind: "book-figure",
    supplement: [图],
    numbering: number => context {
      let prefix = figure-prefix.get()
      if prefix == none {
        panic("图所在的无编号区域未定义图编号前缀")
      }
      [#(prefix)-#number]
    },
  )
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
      figure-prefix.update(none)
      counter(math.equation).update(0)
      counter(book-figure).update(0)
    } else {
      let prefix = numbering(it.numbering, ..counter(heading).get())
      equation-prefix.update(prefix)
      figure-prefix.update(prefix)
      counter(math.equation).update(0)
      counter(book-figure).update(0)
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
