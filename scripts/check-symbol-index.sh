#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

index_file="book/chapters/symbol-index.typ"
expected="$(mktemp)"
actual="$(mktemp)"
trap 'rm -f "$expected" "$actual"' EXIT

if rg --line-number 'table(\.header)?\(' "$index_file"; then
  echo "符号索引不得使用会约束行内公式高度的表格布局。" >&2
  exit 1
fi

if ! rg --quiet '普通数学字形用于标量、索引、分布函数、分量或算子；粗体用于向量、张量或矩阵' "$index_file"; then
  echo "符号索引必须明确说明常规体与粗体的语义。" >&2
  exit 1
fi

rg --no-filename -o '#source\(<sym-[a-z0-9-]+>\)' "$index_file" \
  | sed -E 's/^#source\(<(sym-[a-z0-9-]+)>\)$/\1/' \
  | sort > "$expected"

if [[ ! -s "$expected" ]]; then
  echo "符号索引没有引用任何首次正式定义锚点。" >&2
  exit 1
fi

typed_symbol_count="$(rg --no-filename -o '#typed-symbol\(' "$index_file" | wc -l)"
indexed_symbol_count="$(wc -l < "$expected")"
if [[ "$typed_symbol_count" -ne "$indexed_symbol_count" ]]; then
  echo "每个符号索引条目都必须使用可见的类型标识。" >&2
  exit 1
fi

duplicate_refs="$(uniq -d "$expected")"
if [[ -n "$duplicate_refs" ]]; then
  echo "符号索引重复引用了以下锚点：" >&2
  echo "$duplicate_refs" >&2
  exit 1
fi

typst eval 'query(metadata).map(it => it.value)' \
  --in book/main.typ --root . --pretty \
  | sed -nE 's/^  "(sym-[a-z0-9-]+)",?$/\1/p' \
  | sort > "$actual"

duplicate_anchors="$(uniq -d "$actual")"
if [[ -n "$duplicate_anchors" ]]; then
  echo "正文重复定义了以下符号锚点：" >&2
  echo "$duplicate_anchors" >&2
  exit 1
fi

if ! diff -u "$expected" "$actual"; then
  echo "符号索引引用与正文首次正式定义锚点不一致。" >&2
  exit 1
fi
