#!/usr/bin/env bash
# tests/test-profile-system.sh — Profile system tests
# Usage: bash tests/test-profile-system.sh

set -euo pipefail

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() {
  ((TESTS_PASSED++))
  ((TESTS_RUN++))
  echo "  PASS: $1"
}

fail() {
  ((TESTS_FAILED++))
  ((TESTS_RUN++))
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
  echo "(placeholder — Task 2 adds tests here)"
}

test_default_profile() {
  echo "=== Default profile (no cache, no profile) ==="
  echo "(placeholder — Task 3 adds tests here)"
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
echo "Results: $TESTS_RUN run, $TESTS_PASSED passed, $TESTS_FAILED failed"
[[ "$TESTS_FAILED" -eq 0 ]]
