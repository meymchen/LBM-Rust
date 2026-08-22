#import "template.typ": chapter, chapter-body, project

#show: project.with(
  document-title: [格子玻尔兹曼方法——基础与代码实践（Rust 语言描述）],
  title: [格子玻尔兹曼方法——基础与代码实践],
  subtitle: [（Rust 语言描述）],
  authors: ("LBM-Rust Contributors",),
)

#include "chapters/preface.typ"
#include "chapters/symbol-index.typ"
#counter(heading).update(0)
#chapter[#include "chapters/01-introduction.typ"]
#chapter[#include "chapters/02-foundations.typ"]
#chapter[#include "chapters/03-lattice-models.typ"]
#chapter[#include "chapters/04-practice-roadmap.typ"]
#chapter[#include "chapters/05-practice-diffusion.typ"]
#chapter-body("A")[#include "chapters/appendix-reproducibility.typ"]
#include "chapters/references.typ"
#include "chapters/index.typ"
