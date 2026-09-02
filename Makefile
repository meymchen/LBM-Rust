SHELL := /bin/bash
.ONESHELL:
.DEFAULT_GOAL := help

PDF := build/lbm-rust.pdf
GENERATED_DIR := book/assets/generated
CHECK_GENERATED_DIR := build/generated-check
GENERATED_FILES := d2q9-equilibrium.csv d2q9-equilibrium.svg \
	d1q3-diffusion-profiles.csv d1q3-diffusion-convergence.csv d1q3-diffusion.svg \
	d2q9-diffusion-profiles.csv d2q9-diffusion-convergence.csv d2q9-diffusion.svg
VTK_FIXTURE_DIR := examples/vtk-interop/fixtures/reference
PARAVIEW_SMOKE_DIR := build/paraview-smoke

.PHONY: help pdf regenerate diffusion-bench diffusion-2d-bench diffusion-vtk rust-check vtk-smoke paraview-smoke punctuation-check math-notation-check symbol-index-check bibliography-check figure-check check-generated check

help:
	@echo "可用目标："
	@echo "  make pdf             使用现有数据生成 PDF"
	@echo "  make regenerate      重新生成文档数据与 SVG"
	@echo "  make diffusion-bench 以发布模式运行一维扩散性能基准"
	@echo "  make diffusion-2d-bench 以发布模式运行 D2Q5／D2Q9 二维扩散性能基准"
	@echo "  make diffusion-vtk   生成真实 D2Q9 二维扩散场的 VTK 时间序列"
	@echo "  make rust-check      检查格式、Clippy 与测试"
	@echo "  make vtk-smoke       验证 VTK 写入、读回和互操作资产"
	@echo "  make paraview-smoke  使用 pvpython 验证三个后处理流程"
	@echo "  make punctuation-check 检查中文标点"
	@echo "  make math-notation-check 检查易误排的数学记号"
	@echo "  make symbol-index-check 检查符号索引布局与首次定义锚点"
	@echo "  make bibliography-check 检查参考文献均在正文引用"
	@echo "  make figure-check     检查插图字号和矢量箭头"
	@echo "  make check-generated 检查生成资产是否最新"
	@echo "  make check           执行全部检查"

pdf:
	set -eu
	mkdir -p build
	typst compile --root . book/main.typ "$(PDF)"

regenerate:
	set -eu
	cargo run --quiet -p d2q9-equilibrium -- "$(GENERATED_DIR)"
	cargo run --quiet -p d1q3-diffusion -- "$(GENERATED_DIR)"
	# 二维收敛研究的代价随格点数四次方增长，未优化时无法在常规构建中完成。
	# 优化等级不改变 IEEE 语义，生成结果与未优化构建逐位相同。
	cargo run --release --quiet -p d2q9-diffusion -- "$(GENERATED_DIR)"
	cargo run --quiet -p vtk-interop -- --force "$(VTK_FIXTURE_DIR)"

diffusion-bench:
	set -eu
	cargo run --release --quiet -p d1q3-diffusion --bin diffusion-benchmark -- .scratch/d1q3-diffusion-benchmark

diffusion-2d-bench:
	set -eu
	cargo run --release --quiet -p d2q9-diffusion --bin diffusion-benchmark -- .scratch/d2q5-d2q9-diffusion-benchmark

diffusion-vtk:
	set -eu
	cargo run --release --quiet -p d2q9-diffusion --bin diffusion-snapshots -- build/d2q9-diffusion-vtk

rust-check:
	set -eu
	cargo fmt --all --check
	cargo clippy --workspace --all-targets -- -D warnings
	cargo test --workspace

vtk-smoke:
	set -eu
	cargo test -p lbm-vtk -p vtk-interop

paraview-smoke:
	set -eu
	cargo run --quiet -p vtk-interop -- --force build/vtk-smoke
	rm -rf "$(PARAVIEW_SMOKE_DIR)"
	pvpython scripts/paraview/vtk-interop.py build/vtk-smoke "$(PARAVIEW_SMOKE_DIR)"
	test -s "$(PARAVIEW_SMOKE_DIR)/speed.vti"
	test -s "$(PARAVIEW_SMOKE_DIR)/streamlines.vtp"
	rg --quiet '"density","speed","velocity:0"' "$(PARAVIEW_SMOKE_DIR)/centerline.csv"

punctuation-check:
	set -eu
	if rg --line-number '[\p{Han}][,;:!?()]|[,;:!?()][\p{Han}]' \
		README.md CONTRIBUTING.md book docs crates examples \
		--glob '*.md' --glob '*.typ' --glob '*.rs'; then
		echo "检测到与中文字符相邻的半角标点。" >&2
		exit 1
	fi

math-notation-check:
	set -eu
	if rg --line-number '\bdot[[:space:]]*\(' book --glob '*.typ'; then
		echo "检测到可能被 Typst 解释为重音函数的 dot(...) 记号。" >&2
		exit 1
	fi
	if rg --line-number '\b(Delta|delta)[[:space:]]+(bold\([^)]*\)|[A-Za-z])' book/chapters book/figures --glob '*.typ'; then
		echo "检测到未封装为单个数学原子的增量或扰动符号。" >&2
		exit 1
	fi

symbol-index-check:
	set -eu
	bash scripts/check-symbol-index.sh

bibliography-check:
	set -eu
	export LC_ALL=C
	bib_keys="$$(mktemp)"
	cited_keys="$$(mktemp)"
	trap 'rm -f "$$bib_keys" "$$cited_keys"' EXIT
	sed -n 's/^@[^{]*{\([^,]*\),/\1/p' book/references.bib | sort > "$$bib_keys"
	rg --no-filename -o '@[A-Za-z0-9:_-]+' book --glob '*.typ' \
		| sed 's/^@//' | sort -u > "$$cited_keys"
	unused="$$(comm -23 "$$bib_keys" "$$cited_keys")"
	if [[ -n "$$unused" ]]; then
		echo "检测到未在正文引用的参考文献：" >&2
		echo "$$unused" >&2
		exit 1
	fi

figure-check:
	bash scripts/check-figure-quality.sh

check-generated:
	set -eu
	mkdir -p "$(CHECK_GENERATED_DIR)"
	cargo run --quiet -p d2q9-equilibrium -- "$(CHECK_GENERATED_DIR)"
	cargo run --quiet -p d1q3-diffusion -- "$(CHECK_GENERATED_DIR)"
	cargo run --release --quiet -p d2q9-diffusion -- "$(CHECK_GENERATED_DIR)"
	cargo run --quiet -p vtk-interop -- --force "$(CHECK_GENERATED_DIR)/vtk-interop"
	for file in $(GENERATED_FILES); do
		diff -u "$(GENERATED_DIR)/$$file" "$(CHECK_GENERATED_DIR)/$$file"
	done
	diff -ru "$(VTK_FIXTURE_DIR)" "$(CHECK_GENERATED_DIR)/vtk-interop"

check: rust-check punctuation-check math-notation-check symbol-index-check bibliography-check figure-check check-generated pdf
