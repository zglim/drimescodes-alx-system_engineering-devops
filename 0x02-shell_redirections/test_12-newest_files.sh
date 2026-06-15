#!/bin/bash
# Regression tests for 12-newest_files
set -e

SCRIPT="$(cd "$(dirname "$0")" && pwd)/12-newest_files"
PASS=0
FAIL=0
TMPDIR=""

cleanup() { [ -n "$TMPDIR" ] && rm -rf "$TMPDIR"; }
trap cleanup EXIT

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    expected: $(echo "$expected" | head -c 200)"
    echo "    actual:   $(echo "$actual" | head -c 200)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected to contain '$needle')"
    echo "    actual: $(echo "$haystack" | head -c 200)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if ! echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (should NOT contain '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_nonzero() {
  local label="$1"; shift
  local output
  if output=$("$@" 2>&1); then
    echo "  FAIL: $label (expected non-zero exit)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  fi
  echo "$output"
}

# --- Setup test directory with controlled mtimes ---
TMPDIR=$(mktemp -d)

# Create 12 regular files with staggered mtimes
for i in $(seq 1 12); do
  f="$TMPDIR/file_$(printf '%02d' $i)"
  touch "$f"
  # Use touch -t to set distinct mtimes (increasing)
  touch -t "202601$(printf '%02d' $i)1200" "$f"
done

# Create 2 hidden files
touch "$TMPDIR/.hidden_a"
touch -t 202601131200 "$TMPDIR/.hidden_a"
touch "$TMPDIR/.hidden_b"
touch -t 202601141200 "$TMPDIR/.hidden_b"

echo "=== Test 1: Default outputs 10 entries ==="
out=$("$SCRIPT" -d "$TMPDIR")
count=$(echo "$out" | wc -l | tr -d ' ')
assert_eq "default count is 10" "10" "$count"

echo "=== Test 2: Custom count (-n 3) ==="
out=$("$SCRIPT" -d "$TMPDIR" -n 3)
count=$(echo "$out" | wc -l | tr -d ' ')
assert_eq "custom count is 3" "3" "$count"

echo "=== Test 3: Results sorted newest first ==="
out=$("$SCRIPT" -d "$TMPDIR" -n 1)
assert_eq "newest file is file_12" "file_12" "$out"

echo "=== Test 4: Custom directory ==="
subdir="$TMPDIR/sub"
mkdir "$subdir"
touch -t 202602011200 "$subdir/alpha"
touch -t 202602021200 "$subdir/beta"
out=$("$SCRIPT" -d "$subdir")
first=$(echo "$out" | head -1)
assert_eq "custom dir newest" "beta" "$first"

echo "=== Test 5: Hidden entries excluded by default ==="
out=$("$SCRIPT" -d "$TMPDIR")
assert_not_contains "no .hidden_a by default" ".hidden_a" "$out"
assert_not_contains "no .hidden_b by default" ".hidden_b" "$out"

echo "=== Test 6: Hidden entries included with -a ==="
out=$("$SCRIPT" -d "$TMPDIR" -a -n 20)
assert_contains ".hidden_a present with -a" ".hidden_a" "$out"
assert_contains ".hidden_b present with -a" ".hidden_b" "$out"

echo "=== Test 7: Non-numeric count gives error ==="
err_out=$(assert_exit_nonzero "non-numeric count exits non-zero" "$SCRIPT" -n abc -d "$TMPDIR")
assert_contains "error message mentions count" "Count must be a positive integer" "$err_out"

echo "=== Test 8: Zero count gives error ==="
err_out=$(assert_exit_nonzero "zero count exits non-zero" "$SCRIPT" -n 0 -d "$TMPDIR")
assert_contains "error message for zero" "Count must be a positive integer" "$err_out"

echo "=== Test 9: Non-existent directory gives error ==="
err_out=$(assert_exit_nonzero "missing dir exits non-zero" "$SCRIPT" -d /no/such/dir)
assert_contains "error mentions directory" "does not exist" "$err_out"

echo ""
echo "=============================="
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
