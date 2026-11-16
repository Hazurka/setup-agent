# Shared helpers for the shell tests. Source this file; do not execute it.
# Variables here are used by the scripts that source this file.
# shellcheck disable=SC2034

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo "  ok   $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  FAIL $1"; }

# assert_contains <label> <haystack> <needle>
assert_contains() {
  case "$2" in
    *"$3"*) pass "$1" ;;
    *) fail "$1 (expected output to contain: $3)"; printf '%s\n' "$2" | sed 's/^/       | /' ;;
  esac
}

assert_not_contains() {
  case "$2" in
    *"$3"*) fail "$1 (did not expect: $3)" ;;
    *) pass "$1" ;;
  esac
}

# assert_true <label> <command...>: pass when the command succeeds.
assert_true() {
  local label="$1"
  shift
  if "$@"; then pass "$label"; else fail "$label"; fi
}

assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected '$3', got '$2')"; fi
}

# Run a command, capturing combined output in OUT and exit status in RC.
capture() {
  set +e
  OUT="$("$@" 2>&1)"
  RC=$?
  set -e
}

finish() {
  echo "  -- $PASSED passed, $FAILED failed"
  [ "$FAILED" -eq 0 ]
}
