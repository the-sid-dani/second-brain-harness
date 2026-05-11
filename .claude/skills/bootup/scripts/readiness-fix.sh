#!/usr/bin/env bash
# readiness-fix.sh — Fill in missing configs (linters, formatters, type-checkers,
# editorconfig, gitignore, etc.) for the detected stack. Does NOT touch source code.
# Usage: bash readiness-fix.sh <project_dir>
# Output: One line per file: "created <path>" or "exists <path>".

set -u

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || { echo "bad path"; exit 1; }
cd "$ROOT" || exit 1

CREATED=()
EXISTS=()

write_if_missing() {
  local path="$1"; shift
  local body="$*"
  if [ -e "$ROOT/$path" ]; then
    EXISTS+=("$path"); echo "exists  $path"
  else
    mkdir -p "$ROOT/$(dirname "$path")"
    printf '%s' "$body" > "$ROOT/$path"
    CREATED+=("$path"); echo "created $path"
  fi
}

# Detect language (mirror of readiness.sh)
LANG="unknown"
if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f requirements.txt ]; then LANG="python"
elif [ -f package.json ]; then
  LANG="javascript"
  if grep -q '"typescript"' package.json 2>/dev/null; then LANG="typescript"; fi
elif [ -f Cargo.toml ]; then LANG="rust"
elif [ -f go.mod ]; then LANG="go"
fi

# ---------- universal scaffolds ----------

# .editorconfig
write_if_missing ".editorconfig" "root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{js,jsx,ts,tsx,json,yml,yaml,md}]
indent_size = 2

[Makefile]
indent_style = tab
"

# .gitignore (only if missing)
if [ ! -f .gitignore ]; then
  case "$LANG" in
    python) write_if_missing ".gitignore" "# Python
__pycache__/
*.py[cod]
*\$py.class
*.egg-info/
.eggs/
build/
dist/
.venv/
venv/
env/
.env
.env.local

# Tooling caches
.mypy_cache/
.ruff_cache/
.pytest_cache/
.coverage
htmlcov/
coverage.xml
.tox/

# IDE
.vscode/
.idea/
*.swp
.DS_Store
" ;;
    javascript|typescript) write_if_missing ".gitignore" "node_modules/
dist/
build/
.next/
out/
coverage/
.env
.env.local
*.log
.DS_Store
.vscode/
.idea/
" ;;
    rust) write_if_missing ".gitignore" "target/
**/*.rs.bk
Cargo.lock.bak
.env
.DS_Store
" ;;
    go) write_if_missing ".gitignore" "*.exe
*.test
*.out
vendor/
.env
.DS_Store
" ;;
    *) write_if_missing ".gitignore" ".env
.DS_Store
node_modules/
__pycache__/
" ;;
  esac
else
  EXISTS+=(".gitignore"); echo "exists  .gitignore"
fi

# .env.example (only if a .env exists without an example)
if [ -f .env ] && [ ! -f .env.example ] && [ ! -f .env.template ] && [ ! -f .env.sample ]; then
  # generate example by stripping values
  awk -F= '/^[A-Za-z_]/ {print $1"="}' .env > "$ROOT/.env.example"
  CREATED+=(".env.example"); echo "created .env.example"
elif [ ! -f .env.example ] && [ ! -f .env.template ] && [ ! -f .env.sample ]; then
  write_if_missing ".env.example" "# Copy to .env and fill in values
# EXAMPLE_API_KEY=
"
else
  EXISTS+=(".env.example"); echo "exists  .env.example (or .env.template)"
fi

# ---------- python ----------
if [ "$LANG" = "python" ]; then

  # pyproject.toml: add tool sections if missing
  if [ -f pyproject.toml ]; then
    if ! grep -q "^\[tool.ruff\]" pyproject.toml; then
      cat >> pyproject.toml <<'EOF'

[tool.ruff]
line-length = 100
target-version = "py311"
EOF
      CREATED+=("pyproject.toml [tool.ruff]"); echo "created pyproject.toml [tool.ruff]"
    fi
    if ! grep -q "^\[tool.ruff.lint\]" pyproject.toml; then
      cat >> pyproject.toml <<'EOF'

[tool.ruff.lint]
select = ["E", "F", "W", "I", "B", "UP"]
EOF
      CREATED+=("pyproject.toml [tool.ruff.lint]"); echo "created pyproject.toml [tool.ruff.lint]"
    fi
    if ! grep -q "^\[tool.ruff.format\]" pyproject.toml; then
      cat >> pyproject.toml <<'EOF'

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
EOF
      CREATED+=("pyproject.toml [tool.ruff.format]"); echo "created pyproject.toml [tool.ruff.format]"
    fi
    if ! grep -q "^\[tool.mypy" pyproject.toml; then
      cat >> pyproject.toml <<'EOF'

[tool.mypy]
python_version = "3.11"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = false
ignore_missing_imports = true
EOF
      CREATED+=("pyproject.toml [tool.mypy]"); echo "created pyproject.toml [tool.mypy]"
    fi
    if ! grep -q "^\[tool.pytest" pyproject.toml; then
      cat >> pyproject.toml <<'EOF'

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
addopts = "-v --tb=short"
EOF
      CREATED+=("pyproject.toml [tool.pytest]"); echo "created pyproject.toml [tool.pytest]"
    fi
    if ! grep -q "^\[tool.coverage" pyproject.toml; then
      cat >> pyproject.toml <<'EOF'

[tool.coverage.run]
source = ["src"]
omit = ["tests/*", "*/__init__.py"]

[tool.coverage.report]
show_missing = true
skip_covered = false
EOF
      CREATED+=("pyproject.toml [tool.coverage]"); echo "created pyproject.toml [tool.coverage]"
    fi
  fi

  # .pre-commit-config.yaml
  write_if_missing ".pre-commit-config.yaml" "repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
"

  # tests/conftest.py — minimal pytest fixture scaffolding
  if [ -d tests ] && [ ! -f tests/conftest.py ]; then
    write_if_missing "tests/conftest.py" "\"\"\"Shared pytest fixtures.

Add fixtures here to make them available to all tests under tests/.
See https://docs.pytest.org/en/stable/reference/fixtures.html
\"\"\"
import pytest


@pytest.fixture
def anyio_backend():
    \"\"\"Run async tests on asyncio by default.\"\"\"
    return \"asyncio\"
"
  elif [ ! -d tests ]; then
    write_if_missing "tests/conftest.py" "\"\"\"Shared pytest fixtures.\"\"\"
import pytest
"
    write_if_missing "tests/__init__.py" ""
    write_if_missing "tests/test_smoke.py" "def test_smoke():
    assert True
"
  else
    EXISTS+=("tests/conftest.py"); echo "exists  tests/conftest.py"
  fi
fi

# ---------- javascript / typescript ----------
if [ "$LANG" = "javascript" ] || [ "$LANG" = "typescript" ]; then
  write_if_missing ".prettierrc.json" '{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100
}
'
  write_if_missing "eslint.config.mjs" "import js from '@eslint/js';
export default [
  js.configs.recommended,
  { ignores: ['dist', 'build', 'node_modules', 'coverage'] },
];
"
  if [ "$LANG" = "typescript" ] && [ ! -f tsconfig.json ]; then
    write_if_missing "tsconfig.json" '{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "outDir": "dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
'
  fi
  write_if_missing ".pre-commit-config.yaml" "repos:
  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v4.0.0-alpha.8
    hooks:
      - id: prettier
        types_or: [javascript, typescript, json, yaml, markdown]
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
"
fi

# ---------- rust ----------
if [ "$LANG" = "rust" ]; then
  write_if_missing "rustfmt.toml" "edition = \"2021\"
max_width = 100
"
fi

# ---------- go ----------
if [ "$LANG" = "go" ]; then
  write_if_missing ".golangci.yml" "linters:
  enable:
    - gofmt
    - govet
    - errcheck
    - staticcheck
    - unused
    - ineffassign
"
fi

# ---------- CI ----------
if [ ! -d .github/workflows ]; then
  mkdir -p .github/workflows
fi

case "$LANG" in
  python)
    write_if_missing ".github/workflows/ci.yml" "name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v3
      - name: Set up Python
        run: uv python install 3.11
      - name: Install dependencies
        run: uv sync --all-extras --dev
      - name: Lint
        run: uv run ruff check .
      - name: Format check
        run: uv run ruff format --check .
      - name: Type check
        run: uv run mypy src || true
      - name: Test
        run: uv run pytest
"
    ;;
  javascript|typescript)
    write_if_missing ".github/workflows/ci.yml" "name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run lint --if-present
      - run: npm test --if-present
"
    ;;
  rust)
    write_if_missing ".github/workflows/ci.yml" "name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - run: cargo fmt -- --check
      - run: cargo clippy --all-targets -- -D warnings
      - run: cargo test
"
    ;;
  go)
    write_if_missing ".github/workflows/ci.yml" "name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: go vet ./...
      - run: go test ./...
"
    ;;
esac

# Dependabot
case "$LANG" in
  python)               DEPBOT_ECO="pip" ;;
  javascript|typescript) DEPBOT_ECO="npm" ;;
  rust)                 DEPBOT_ECO="cargo" ;;
  go)                   DEPBOT_ECO="gomod" ;;
  *)                    DEPBOT_ECO="" ;;
esac

DEPBOT_BODY='version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
'
if [ -n "$DEPBOT_ECO" ]; then
  DEPBOT_BODY="${DEPBOT_BODY}  - package-ecosystem: \"${DEPBOT_ECO}\"
    directory: \"/\"
    schedule:
      interval: \"weekly\"
"
fi
write_if_missing ".github/dependabot.yml" "$DEPBOT_BODY"

# PR template
write_if_missing ".github/pull_request_template.md" "## Summary
<!-- One or two sentences on what this PR does and why. -->

## Changes
-

## Test plan
- [ ]

## Checklist
- [ ] Tests added or updated
- [ ] Lint passes
- [ ] Docs updated if behavior changed
"

# Issue templates
write_if_missing ".github/ISSUE_TEMPLATE/bug_report.md" "---
name: Bug report
about: Report a defect
labels: bug
---

**Describe the bug**

**Steps to reproduce**
1.

**Expected behavior**

**Environment**
- OS:
- Version:
"

write_if_missing ".github/ISSUE_TEMPLATE/feature_request.md" "---
name: Feature request
about: Suggest an enhancement
labels: enhancement
---

**Problem**

**Proposed solution**

**Alternatives considered**
"

# LICENSE (MIT placeholder)
if [ ! -f LICENSE ] && [ ! -f LICENSE.md ] && [ ! -f LICENSE.txt ]; then
  YEAR=$(date +%Y)
  write_if_missing "LICENSE" "MIT License

Copyright (c) ${YEAR}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the \"Software\"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"
else
  EXISTS+=("LICENSE"); echo "exists  LICENSE"
fi

# Makefile (only if no Makefile and no scripts in package.json)
if [ ! -f Makefile ] && [ ! -f justfile ] && [ ! -f Justfile ]; then
  case "$LANG" in
    python)
      write_if_missing "Makefile" ".PHONY: install dev test lint format typecheck

install:
\tuv sync

dev:
\tuv run python -m app

test:
\tuv run pytest

lint:
\tuv run ruff check .

format:
\tuv run ruff format .

typecheck:
\tuv run mypy src
" ;;
    javascript|typescript)
      write_if_missing "Makefile" ".PHONY: install dev test lint build

install:
\tnpm ci

dev:
\tnpm run dev

test:
\tnpm test

lint:
\tnpm run lint

build:
\tnpm run build
" ;;
    rust)
      write_if_missing "Makefile" ".PHONY: build test lint fmt

build:
\tcargo build

test:
\tcargo test

lint:
\tcargo clippy --all-targets

fmt:
\tcargo fmt
" ;;
    go)
      write_if_missing "Makefile" ".PHONY: build test lint fmt

build:
\tgo build ./...

test:
\tgo test ./...

lint:
\tgo vet ./...

fmt:
\tgo fmt ./...
" ;;
  esac
fi

# CONTRIBUTING.md
write_if_missing "CONTRIBUTING.md" "# Contributing

Thanks for your interest in contributing!

## Development

\`\`\`bash
make install
make test
make lint
\`\`\`

## Pull requests

1. Fork and create a feature branch.
2. Make your changes with tests.
3. Run \`make lint\` and \`make test\`.
4. Open a PR using the template.
"

# ---------- summary ----------
echo
echo "----"
echo "created: ${#CREATED[@]}"
echo "exists:  ${#EXISTS[@]}"
