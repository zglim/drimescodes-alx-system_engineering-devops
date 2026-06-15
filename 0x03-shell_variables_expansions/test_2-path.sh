#!/bin/bash
# Regression tests for 2-path idempotent /action append
SCRIPT="$(cd "$(dirname "$0")" && pwd)/2-path"
PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

count_action() {
  echo "$1" | tr ':' '\n' | grep -cx '/action'
}

# 1. PATH without /action -> gets appended
PATH="/usr/bin:/usr/local/bin"; source "$SCRIPT"
assert_eq "append when missing" "/usr/bin:/usr/local/bin:/action" "$PATH"

# 2. PATH already has /action -> no change
PATH="/usr/bin:/action:/usr/local/bin"; source "$SCRIPT"
assert_eq "no change when present" "/usr/bin:/action:/usr/local/bin" "$PATH"

# 3. Run twice -> still only one /action
PATH="/usr/bin:/usr/local/bin"; source "$SCRIPT"; source "$SCRIPT"
assert_eq "idempotent after two runs" 1 "$(count_action "$PATH")"

# 4. /action at beginning of PATH
PATH="/action:/usr/bin"; source "$SCRIPT"
assert_eq "no dup when at beginning" "/action:/usr/bin" "$PATH"

# 5. /action in middle of PATH
PATH="/usr/bin:/action:/sbin"; source "$SCRIPT"
assert_eq "no dup when in middle" "/usr/bin:/action:/sbin" "$PATH"

# 6. Empty segments (::) preserved
PATH="/usr/bin::/usr/local/bin"; source "$SCRIPT"
assert_eq "empty segment preserved" "/usr/bin::/usr/local/bin:/action" "$PATH"

# 7. /action-extra should not be confused with /action
PATH="/usr/bin:/action-extra"; source "$SCRIPT"
assert_eq "partial match not confused" "/usr/bin:/action-extra:/action" "$PATH"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
