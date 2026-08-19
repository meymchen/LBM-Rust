#import "template.typ": project

#show: project.with(
  title: [格子玻尔兹曼方法——基础与计算机实践（Rust 语言描述）],
  subtitle: [LBM-Rust],
  authors: ("LBM-Rust Contributors",),
)

#include "chapters/preface.typ"
#counter(heading).update(0)
#include "chapters/01-introduction.typ"
#include "chapters/02-foundations.typ"
#include "chapters/appendix-reproducibility.typ"
#include "chapters/references.typ"
#include "chapters/index.typ"
