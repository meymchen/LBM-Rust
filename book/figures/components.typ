#let ink = rgb("171d24")
#let muted = rgb("59636f")
#let guide = rgb("c9ced5")
#let transport = rgb("1f5a91")
#let collision = rgb("a74428")
#let field = rgb("e8f0f7")

#let diagram-note(body) = block(
  width: 100%,
  inset: (top: 5pt),
  align(center, text(size: 9pt, fill: muted, body)),
)

#let panel-title(label, title) = align(center)[
  #text(size: 9.5pt, weight: "bold", fill: ink)[(#label)　#title]
]
