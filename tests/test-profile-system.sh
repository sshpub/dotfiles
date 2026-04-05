#!/usr/bin/env bash
# tests/test-profile-system.sh — Profile system tests
# Usage: bash tests/test-profile-system.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Results tracked via temp file so subshell results propagate
RESULTS_FILE="$(mktemp)"
trap 'rm -f "$RESULTS_FILE"' EXIT
echo "0 0 0" > "$RESULTS_FILE"

_record() {
  local run passed failed
  read -r run passed failed < "$RESULTS_FILE"
  echo "$1 $2 $3" | awk -v r="$run" -v p="$passed" -v f="$failed" \
    '{print r+$1, p+$2, f+$3}' > "$RESULTS_FILE"
}

pass() {
  _record 1 1 0
  echo "  PASS: $1"
}

fail() {
  _record 1 0 1
  echo "  FAIL: $1 — $2"
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc" "expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ " $haystack " == *" $needle "* ]]; then
    pass "$desc"
  else
    fail "$desc" "'$needle' not found in '$haystack'"
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    pass "$desc"
  else
    fail "$desc" "file not found: $path"
  fi
}

# --- Test Groups ---
# Each test group runs in a subshell to isolate state

test_data_dir_resolution() {
  echo "=== Data directory resolution ==="

  # Test: env var override takes priority
  (
    export DOTFILES_DATA_DIR="/tmp/dotfiles-test-data-override"
    mkdir -p "$DOTFILES_DATA_DIR"
    source "${DOTFILES_DIR}/core/platform.sh"
    assert_eq "env var override" "/tmp/dotfiles-test-data-override" "$DOTFILES_DATA_DIR"
    assert_eq "cache dir derives from data dir" "/tmp/dotfiles-test-data-override/cache" "$DOTFILES_CACHE_DIR"
    rm -rf "$DOTFILES_DATA_DIR"
  )

  # Test: falls back to ~/.dotfiles/ when it exists
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-home-$$"
    mkdir -p "${test_home}/.dotfiles"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    assert_eq "fallback to ~/.dotfiles" "${test_home}/.dotfiles" "$DOTFILES_DATA_DIR"
    rm -rf "$test_home"
  )

  # Test: creates ~/.dotfiles/ as default when nothing exists
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-home-empty-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    assert_eq "default to ~/.dotfiles when nothing exists" "${test_home}/.dotfiles" "$DOTFILES_DATA_DIR"
    rm -rf "$test_home"
  )
}

test_default_profile() {
  echo "=== Default profile (no cache, no profile) ==="

  # Test: discovers all bundled modules when no cache exists
  (
    unset DOTFILES_DATA_DIR
    local test_home="/tmp/dotfiles-test-default-$$"
    mkdir -p "$test_home"
    HOME="$test_home" source "${DOTFILES_DIR}/core/platform.sh"
    HOME="$test_home" source "${DOTFILES_DIR}/core/loader.sh"

    # Should find all modules that have module.json
    local expected_count
    expected_count=$(find "${DOTFILES_DIR}/modules" -name module.json -maxdepth 2 | wc -l)
    assert_eq "discovers all modules" "$expected_count" "${#DOTFILES_ENABLED_MODULES[@]}"

    # git should be in the list
    assert_contains "git in enabled modules" "git" "${DOTFILES_ENABLED_MODULES[*]}"

    # No disabled sections by default
    assert_eq "no disabled sections" "0" "${#DOTFILES_DISABLED_SECTIONS[@]}"

    # Default minimal mode exists
    assert_contains "minimal in mode names" "minimal" "${DOTFILES_MODE_NAMES[*]}"
    assert_contains "CLAUDE_CODE in minimal triggers" "CLAUDE_CODE" "${DOTFILES_MODE_minimal_TRIGGERS[*]}"

    rm -rf "$test_home"
  )
}

test_mode_resolution() {
  echo "=== Mode resolution ==="
  echo "(placeholder — Task 4 adds tests here)"
}

test_bash_profile_integration() {
  echo "=== .bash_profile integration ==="
  echo "(placeholder — Task 6 adds tests here)"
}

test_generate_cache() {
  echo "=== Cache generator ==="
  echo "(placeholder — Task 8 adds tests here)"
}

# --- Run ---

test_data_dir_resolution
test_default_profile
test_mode_resolution
test_bash_profile_integration
test_generate_cache

echo ""
read -r TESTS_RUN TESTS_PASSED TESTS_FAILED < "$RESULTS_FILE"
echo "Results: $TESTS_RUN run, $TESTS_PASSED passed, $TESTS_FAILED failed"
[[ "$TESTS_FAILED" -eq 0 ]]
