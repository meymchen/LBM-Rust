SHELL := /bin/bash
.ONESHELL:
.DEFAULT_GOAL := help

PDF := build/lbm-rust.pdf
GENERATED_DATA := docs/assets/generated/d2q9-equilibrium.csv

.PHONY: help pdf regenerate rust-check punctuation-check check-generated check

help:
	@echo "可用目标："
	@echo "  make pdf             使用现有数据生成 PDF"
	@echo "  make regenerate      重新生成文档数据"
	@echo "  make rust-check      检查格式、Clippy 与测试"
	@echo "  make punctuation-check 检查中文标点"
	@echo "  make check-generated 检查生成数据是否最新"
	@echo "  make check           执行全部检查"

pdf:
	set -eu
	mkdir -p build
	typst compile --root . docs/main.typ "$(PDF)"

regenerate:
	set -eu
	mkdir -p build
	cargo run --quiet -p d2q9-equilibrium > build/d2q9-equilibrium.csv
	mv build/d2q9-equilibrium.csv "$(GENERATED_DATA)"

rust-check:
	set -eu
	cargo fmt --all --check
	cargo clippy --workspace --all-targets -- -D warnings
	cargo test --workspace

punctuation-check:
	set -eu
	if rg --line-number '[\p{Han}][,;:!?()]|[,;:!?()][\p{Han}]' \
		README.md CONTRIBUTING.md docs crates examples \
		--glob '*.md' --glob '*.typ' --glob '*.rs'; then
		echo "检测到与中文字符相邻的半角标点。" >&2
		exit 1
	fi

check-generated:
	set -eu
	mkdir -p build
	cargo run --quiet -p d2q9-equilibrium > build/d2q9-equilibrium.csv
	diff -u "$(GENERATED_DATA)" build/d2q9-equilibrium.csv

check: rust-check punctuation-check check-generated pdf
