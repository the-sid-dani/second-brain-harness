#!/usr/bin/env bash
# readiness.sh — Score project readiness across 27 criteria / 7 categories.
# Usage: bash readiness.sh <project_dir>
# Output: JSON to stdout with detected stack, per-criterion pass/fail,
#         category scores, overall pass rate, and a level (1-5).

set -u

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || { echo "{\"error\":\"bad path\"}"; exit 1; }
cd "$ROOT" || exit 1

# ---------- helpers ----------
has_file() { [ -f "$ROOT/$1" ]; }
has_any()  { for f in "$@"; do [ -f "$ROOT/$f" ] && return 0; done; return 1; }
has_dir()  { [ -d "$ROOT/$1" ]; }
has_glob() { compgen -G "$ROOT/$1" >/dev/null 2>&1; }
file_has() { [ -f "$ROOT/$1" ] && grep -q -- "$2" "$ROOT/$1" 2>/dev/null; }
any_has()  { local pat="$1"; shift; for f in "$@"; do file_has "$f" "$pat" && return 0; done; return 1; }

# ---------- detect language / framework ----------
LANG="unknown"
FRAMEWORK="unknown"
PKG_MGR="unknown"

if has_file pyproject.toml || has_file setup.py || has_file requirements.txt; then
  LANG="python"
  if has_file uv.lock; then PKG_MGR="uv"
  elif has_file poetry.lock; then PKG_MGR="poetry"
  elif has_file Pipfile.lock; then PKG_MGR="pipenv"
  else PKG_MGR="pip"
  fi
  if file_has pyproject.toml "fastmcp" || file_has pyproject.toml "mcp\\[" || grep -rq "from mcp" "$ROOT/src" 2>/dev/null || grep -rq "FastMCP" "$ROOT/src" 2>/dev/null; then
    FRAMEWORK="mcp"
  elif file_has pyproject.toml "fastapi"; then FRAMEWORK="fastapi"
  elif file_has pyproject.toml "django"; then FRAMEWORK="django"
  elif file_has pyproject.toml "flask"; then FRAMEWORK="flask"
  fi
elif has_file package.json; then
  LANG="javascript"
  if has_file pnpm-lock.yaml; then PKG_MGR="pnpm"
  elif has_file yarn.lock; then PKG_MGR="yarn"
  elif has_file bun.lockb || has_file bun.lock; then PKG_MGR="bun"
  else PKG_MGR="npm"
  fi
  if file_has package.json '"typescript"'; then LANG="typescript"; fi
  if file_has package.json '"next"'; then FRAMEWORK="nextjs"
  elif file_has package.json '"react"'; then FRAMEWORK="react"
  elif file_has package.json '"express"'; then FRAMEWORK="express"
  elif file_has package.json '"@modelcontextprotocol/sdk"'; then FRAMEWORK="mcp"
  fi
elif has_file Cargo.toml; then LANG="rust"; PKG_MGR="cargo"
elif has_file go.mod;     then LANG="go";   PKG_MGR="gomod"
fi

# ---------- 27 criteria across 7 categories ----------
# Each criterion: name|category|pass-test
# Categories: env, lint, types, tests, ci, docs, ops
declare -a CRITERIA
declare -a RESULTS
declare -a REASONS

check() {
  local id="$1" cat="$2" passed="$3" reason="$4"
  CRITERIA+=("$id|$cat")
  RESULTS+=("$passed")
  REASONS+=("$reason")
}

ok()   { check "$1" "$2" 1 "$3"; }
fail() { check "$1" "$2" 0 "$3"; }

# --- Category: env (4) ---
if has_any pyproject.toml package.json Cargo.toml go.mod requirements.txt; then
  ok manifest env "found project manifest"
else
  fail manifest env "no pyproject.toml/package.json/Cargo.toml/go.mod"
fi

if has_any uv.lock poetry.lock Pipfile.lock package-lock.json pnpm-lock.yaml yarn.lock bun.lockb bun.lock Cargo.lock go.sum; then
  ok lockfile env "lockfile present"
else
  fail lockfile env "no lockfile committed"
fi

if has_file .gitignore; then ok gitignore env ".gitignore present"
else fail gitignore env ".gitignore missing"; fi

if has_any .env.example .env.template .env.sample; then
  ok env_example env "env example file present"
elif has_file .env && ! has_any .env.example .env.template .env.sample; then
  fail env_example env ".env present but no .env.example template"
else
  fail env_example env "no .env.example template"
fi

# --- Category: lint (4) ---
case "$LANG" in
  python)
    if has_file ruff.toml || file_has pyproject.toml "\\[tool.ruff" || has_file .ruff.toml; then
      ok linter lint "ruff configured"
    elif file_has pyproject.toml "flake8" || has_file .flake8; then
      ok linter lint "flake8 configured"
    else
      fail linter lint "no python linter config"
    fi
    if file_has pyproject.toml "\\[tool.ruff.format" || file_has pyproject.toml "\\[tool.black" || has_file .black.toml; then
      ok formatter lint "formatter configured"
    elif file_has pyproject.toml "\\[tool.ruff\\]"; then
      ok formatter lint "ruff format available via [tool.ruff]"
    else
      fail formatter lint "no formatter config"
    fi
    ;;
  javascript|typescript)
    if has_any .eslintrc .eslintrc.js .eslintrc.json .eslintrc.cjs eslint.config.js eslint.config.mjs eslint.config.cjs; then
      ok linter lint "eslint configured"
    else
      fail linter lint "no eslint config"
    fi
    if has_any .prettierrc .prettierrc.json .prettierrc.js prettier.config.js prettier.config.cjs .prettierrc.yml .prettierrc.yaml || file_has package.json '"prettier"'; then
      ok formatter lint "prettier configured"
    else
      fail formatter lint "no prettier config"
    fi
    ;;
  rust)
    if has_file rustfmt.toml || has_file .rustfmt.toml; then ok formatter lint "rustfmt config"
    else ok formatter lint "rustfmt available via toolchain (default)"; fi
    if file_has Cargo.toml "clippy" || true; then ok linter lint "clippy ships with rust"; fi
    ;;
  go)
    ok linter lint "go vet ships with toolchain"
    if has_file .golangci.yml || has_file .golangci.yaml; then ok formatter lint "golangci-lint configured"
    else fail formatter lint "no golangci-lint config"; fi
    ;;
  *)
    fail linter lint "unknown language - no linter detected"
    fail formatter lint "unknown language - no formatter detected"
    ;;
esac

if has_file .editorconfig; then ok editorconfig lint ".editorconfig present"
else fail editorconfig lint "no .editorconfig"; fi

if has_file .pre-commit-config.yaml || has_file .husky/pre-commit || file_has package.json '"husky"' || file_has package.json '"lint-staged"'; then
  ok pre_commit_hooks lint "pre-commit hooks configured"
else
  fail pre_commit_hooks lint "no pre-commit hooks"
fi

# --- Category: types (3) ---
case "$LANG" in
  python)
    if file_has pyproject.toml "\\[tool.mypy" || has_file mypy.ini || has_file .mypy.ini; then
      ok type_checker types "mypy configured"
    elif file_has pyproject.toml "\\[tool.pyright" || has_file pyrightconfig.json; then
      ok type_checker types "pyright configured"
    else
      fail type_checker types "no python type checker config"
    fi
    if grep -rq "def .*->.*:" "$ROOT/src" 2>/dev/null || grep -rq ": [A-Z][a-zA-Z]*" "$ROOT/src" 2>/dev/null; then
      ok type_annotations types "type annotations found in src/"
    else
      fail type_annotations types "no type annotations in src/"
    fi
    if file_has pyproject.toml "strict" || any_has "strict = true" mypy.ini pyproject.toml; then
      ok strict_types types "strict typing enabled"
    else
      fail strict_types types "strict typing not enabled"
    fi
    ;;
  typescript)
    if has_file tsconfig.json; then ok type_checker types "tsconfig.json present"
    else fail type_checker types "no tsconfig.json"; fi
    ok type_annotations types "typescript provides annotations natively"
    if file_has tsconfig.json '"strict": true'; then ok strict_types types "strict mode on"
    else fail strict_types types "tsconfig strict mode off"; fi
    ;;
  javascript)
    fail type_checker types "JS project — no type checker"
    fail type_annotations types "no type annotations (JS)"
    fail strict_types types "no strict typing (JS)"
    ;;
  rust|go)
    ok type_checker types "$LANG ships a static type checker"
    ok type_annotations types "$LANG requires explicit types"
    ok strict_types types "$LANG type system is strict by default"
    ;;
  *)
    fail type_checker types "unknown language"
    fail type_annotations types "unknown language"
    fail strict_types types "unknown language"
    ;;
esac

# --- Category: tests (5) ---
if has_dir tests || has_dir test || has_dir __tests__ || has_glob "**/*_test.go" || has_glob "src/**/*.test.ts"; then
  ok unit_tests tests "tests directory present"
else
  fail unit_tests tests "no tests directory"
fi

case "$LANG" in
  python)
    if file_has pyproject.toml "\\[tool.pytest" || has_file pytest.ini || has_file pyproject.toml && file_has pyproject.toml "pytest"; then
      ok test_runner tests "pytest configured"
    else
      fail test_runner tests "no pytest config"
    fi
    if has_file .coveragerc || file_has pyproject.toml "\\[tool.coverage" || file_has pyproject.toml "coverage"; then
      ok coverage tests "coverage configured"
    else
      fail coverage tests "no coverage config"
    fi
    ;;
  javascript|typescript)
    if file_has package.json '"jest"' || file_has package.json '"vitest"' || file_has package.json '"mocha"' || file_has package.json '"ava"'; then
      ok test_runner tests "test runner present"
    else
      fail test_runner tests "no test runner in package.json"
    fi
    if file_has package.json '"coverage"' || has_file .nycrc; then ok coverage tests "coverage configured"
    else fail coverage tests "no coverage config"; fi
    ;;
  rust|go)
    ok test_runner tests "$LANG ships a test runner"
    if has_glob "**/coverage*"; then ok coverage tests "coverage outputs present"
    else fail coverage tests "no coverage configured"; fi
    ;;
  *)
    fail test_runner tests "unknown language"
    fail coverage tests "unknown language"
    ;;
esac

# integration tests heuristic
if has_dir tests/integration || has_dir tests/e2e || has_dir test/integration || has_glob "tests/integration_*" || has_glob "tests/test_*_integration*" || has_glob "tests/test_*_live*" || has_glob "scripts/test_*_live*"; then
  ok integration_tests tests "integration/e2e tests present"
else
  fail integration_tests tests "no integration/e2e tests"
fi

# fixtures / mocks / conftest
if has_glob "tests/conftest.py" || has_dir tests/fixtures || has_glob "tests/**/__mocks__" || has_glob "tests/fixtures.*"; then
  ok test_fixtures tests "fixtures or conftest present"
else
  fail test_fixtures tests "no test fixtures/mocks"
fi

# --- Category: ci (4) ---
if has_dir .github/workflows || has_file .gitlab-ci.yml || has_file .circleci/config.yml || has_file azure-pipelines.yml; then
  ok ci_pipeline ci "CI workflow present"
else
  fail ci_pipeline ci "no CI workflow"
fi

if has_glob ".github/workflows/*.yml" || has_glob ".github/workflows/*.yaml"; then
  if grep -lq "test\|pytest\|jest\|cargo test\|go test" "$ROOT"/.github/workflows/*.y*ml 2>/dev/null; then
    ok ci_runs_tests ci "CI runs tests"
  else
    fail ci_runs_tests ci "CI doesn't run tests"
  fi
elif has_file .gitlab-ci.yml && grep -q "test" "$ROOT/.gitlab-ci.yml"; then
  ok ci_runs_tests ci "CI runs tests"
else
  fail ci_runs_tests ci "no CI test step found"
fi

if has_glob ".github/workflows/*.yml" || has_glob ".github/workflows/*.yaml"; then
  if grep -lq "lint\|ruff\|eslint\|clippy\|golangci\|black\|prettier" "$ROOT"/.github/workflows/*.y*ml 2>/dev/null; then
    ok ci_runs_lint ci "CI runs linter"
  else
    fail ci_runs_lint ci "CI doesn't run linter"
  fi
else
  fail ci_runs_lint ci "no CI lint step found"
fi

if has_file .github/dependabot.yml || has_file .github/renovate.json || has_file renovate.json; then
  ok dependency_updates ci "dependency update bot configured"
else
  fail dependency_updates ci "no dependency update bot"
fi

# --- Category: docs (4) ---
if has_file README.md || has_file README.rst; then ok readme docs "README present"
else fail readme docs "no README"; fi

if has_file README.md; then
  if grep -qiE "(install|setup|prerequisite)" "$ROOT/README.md"; then
    ok readme_install docs "README has install section"
  else
    fail readme_install docs "README lacks install/setup section"
  fi
  if grep -qiE "(run|usage|build|start)" "$ROOT/README.md"; then
    ok build_cmd_doc docs "README documents build/run"
  else
    fail build_cmd_doc docs "README lacks run/build instructions"
  fi
else
  fail readme_install docs "no README"
  fail build_cmd_doc docs "no README"
fi

if has_file LICENSE || has_file LICENSE.md || has_file LICENSE.txt; then
  ok license docs "LICENSE present"
else
  fail license docs "no LICENSE file"
fi

# --- Category: ops (3) ---
if has_file Makefile || file_has package.json '"scripts"' || has_file justfile || has_file Justfile || has_file Taskfile.yml; then
  ok single_cmd_setup ops "single-command runner present"
else
  fail single_cmd_setup ops "no Makefile/scripts/justfile"
fi

if has_glob "Dockerfile*" || has_file docker-compose.yml || has_file compose.yaml; then
  ok containerized ops "Dockerfile/compose present"
else
  fail containerized ops "no Dockerfile"
fi

if has_dir .github/ISSUE_TEMPLATE || has_file .github/PULL_REQUEST_TEMPLATE.md || has_file .github/pull_request_template.md || has_file CONTRIBUTING.md; then
  ok contribution_templates ops "issue/PR templates or CONTRIBUTING present"
else
  fail contribution_templates ops "no issue/PR templates"
fi

# ---------- aggregate (bash 3.2-compatible: no associative arrays) ----------
TOTAL=${#CRITERIA[@]}
PASSED=0
# Per-category counters (env, lint, types, tests, ci, docs, ops)
CT_env=0; CP_env=0
CT_lint=0; CP_lint=0
CT_types=0; CP_types=0
CT_tests=0; CP_tests=0
CT_ci=0; CP_ci=0
CT_docs=0; CP_docs=0
CT_ops=0; CP_ops=0
for i in "${!CRITERIA[@]}"; do
  IFS='|' read -r _id ccat <<< "${CRITERIA[$i]}"
  r="${RESULTS[$i]}"
  case "$ccat" in
    env)   CT_env=$((CT_env+1));   [ "$r" = "1" ] && CP_env=$((CP_env+1));;
    lint)  CT_lint=$((CT_lint+1)); [ "$r" = "1" ] && CP_lint=$((CP_lint+1));;
    types) CT_types=$((CT_types+1)); [ "$r" = "1" ] && CP_types=$((CP_types+1));;
    tests) CT_tests=$((CT_tests+1)); [ "$r" = "1" ] && CP_tests=$((CP_tests+1));;
    ci)    CT_ci=$((CT_ci+1));    [ "$r" = "1" ] && CP_ci=$((CP_ci+1));;
    docs)  CT_docs=$((CT_docs+1)); [ "$r" = "1" ] && CP_docs=$((CP_docs+1));;
    ops)   CT_ops=$((CT_ops+1));  [ "$r" = "1" ] && CP_ops=$((CP_ops+1));;
  esac
  [ "$r" = "1" ] && PASSED=$((PASSED+1))
done

PCT=0
[ "$TOTAL" -gt 0 ] && PCT=$(( PASSED * 100 / TOTAL ))

# Level rubric: 1 <40%, 2 40-59, 3 60-74, 4 75-89, 5 >=90
LEVEL=1
if [ "$PCT" -ge 90 ]; then LEVEL=5
elif [ "$PCT" -ge 75 ]; then LEVEL=4
elif [ "$PCT" -ge 60 ]; then LEVEL=3
elif [ "$PCT" -ge 40 ]; then LEVEL=2
fi

# error surface = number of failures
ESURF=$(( TOTAL - PASSED ))

# ---------- emit JSON ----------
{
  printf '{\n'
  printf '  "language": "%s",\n' "$LANG"
  printf '  "framework": "%s",\n' "$FRAMEWORK"
  printf '  "package_manager": "%s",\n' "$PKG_MGR"
  printf '  "total": %d,\n' "$TOTAL"
  printf '  "passed": %d,\n' "$PASSED"
  printf '  "failed": %d,\n' "$ESURF"
  printf '  "pass_rate": %d,\n' "$PCT"
  printf '  "level": %d,\n' "$LEVEL"
  printf '  "error_surface": %d,\n' "$ESURF"
  printf '  "categories": {\n'
  printf '    "env":   {"passed": %d, "total": %d},\n' "$CP_env" "$CT_env"
  printf '    "lint":  {"passed": %d, "total": %d},\n' "$CP_lint" "$CT_lint"
  printf '    "types": {"passed": %d, "total": %d},\n' "$CP_types" "$CT_types"
  printf '    "tests": {"passed": %d, "total": %d},\n' "$CP_tests" "$CT_tests"
  printf '    "ci":    {"passed": %d, "total": %d},\n' "$CP_ci" "$CT_ci"
  printf '    "docs":  {"passed": %d, "total": %d},\n' "$CP_docs" "$CT_docs"
  printf '    "ops":   {"passed": %d, "total": %d}\n' "$CP_ops" "$CT_ops"
  printf '  },\n'
  printf '  "criteria": [\n'
  for i in "${!CRITERIA[@]}"; do
    IFS='|' read -r id cat <<< "${CRITERIA[$i]}"
    r="${RESULTS[$i]}"; reason="${REASONS[$i]}"
    pass="false"; [ "$r" = "1" ] && pass="true"
    sep=","; [ "$i" -eq $((TOTAL-1)) ] && sep=""
    # escape quotes/backslashes in reason
    reason_esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '    {"id": "%s", "category": "%s", "passed": %s, "reason": "%s"}%s\n' \
      "$id" "$cat" "$pass" "$reason_esc" "$sep"
  done
  printf '  ],\n'
  printf '  "failing": [\n'
  ffirst=1
  for i in "${!CRITERIA[@]}"; do
    IFS='|' read -r id cat <<< "${CRITERIA[$i]}"
    [ "${RESULTS[$i]}" = "0" ] || continue
    [ "$ffirst" -eq 1 ] && ffirst=0 || printf ',\n'
    printf '    "%s"' "$id"
  done
  printf '\n  ]\n'
  printf '}\n'
}
