SHELL := /bin/bash
.ONESHELL:
.DEFAULT_GOAL := help

PDF := build/lbm-rust.pdf
GENERATED_DIR := book/assets/generated
CHECK_GENERATED_DIR := build/generated-check
GENERATED_FILES := d2q9-equilibrium.csv d2q9-equilibrium.svg

.PHONY: help pdf regenerate rust-check punctuation-check figure-check check-generated check

help:
	@echo "可用目标："
	@echo "  make pdf             使用现有数据生成 PDF"
	@echo "  make regenerate      重新生成文档数据与 SVG"
	@echo "  make rust-check      检查格式、Clippy 与测试"
	@echo "  make punctuation-check 检查中文标点"
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

rust-check:
	set -eu
	cargo fmt --all --check
	cargo clippy --workspace --all-targets -- -D warnings
	cargo test --workspace

punctuation-check:
	set -eu
	if rg --line-number '[\p{Han}][,;:!?()]|[,;:!?()][\p{Han}]' \
		README.md CONTRIBUTING.md book docs crates examples \
		--glob '*.md' --glob '*.typ' --glob '*.rs'; then
		echo "检测到与中文字符相邻的半角标点。" >&2
		exit 1
	fi

figure-check:
	bash scripts/check-figure-quality.sh

check-generated:
	set -eu
	mkdir -p "$(CHECK_GENERATED_DIR)"
	cargo run --quiet -p d2q9-equilibrium -- "$(CHECK_GENERATED_DIR)"
	for file in $(GENERATED_FILES); do
		diff -u "$(GENERATED_DIR)/$$file" "$(CHECK_GENERATED_DIR)/$$file"
	done

check: rust-check punctuation-check figure-check check-generated pdf
