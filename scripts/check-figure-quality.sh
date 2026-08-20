#!/usr/bin/env bash

set -euo pipefail

minimum_size=8.5
status=0

while IFS=: read -r file line_number size; do
  if awk -v size="$size" -v minimum="$minimum_size" 'BEGIN { exit !(size < minimum) }'; then
    printf '%s:%s: 图中文字 %.1fpt 小于 %.1fpt\n' \
      "$file" "$line_number" "$size" "$minimum_size" >&2
    status=1
  fi
done < <(
  rg --line-number --no-heading --only-matching 'size: [0-9]+([.][0-9]+)?pt' book/figures \
    | sed -E 's/:size: /:/' \
    | sed -E 's/pt$//'
)

if rg --line-number '[←→↑↓↖↗↘↙⇢]' book/figures --glob '*.typ' >&2; then
  printf '%s\n' '技术图使用了字符箭头，应改用具有统一线宽和箭头尺寸的矢量路径。' >&2
  status=1
fi

exit "$status"
