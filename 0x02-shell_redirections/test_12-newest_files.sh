#!/bin/bash

# Regression tests for 12-newest_files

SCRIPT="$(cd "$(dirname "$0")" && pwd)/12-newest_files"
PASS=0
FAIL=0

assert_exit_code() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" -eq "$actual" ]; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc (expected exit=$expected, got exit=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_line_count() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" -eq "$actual" ]; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc (expected $expected lines, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc (expected to contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if ! echo "$haystack" | grep -qF "$needle"; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc (expected NOT to contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

# Setup temp test directory
TESTDIR=$(mktemp -d)
trap "rm -rf $TESTDIR" EXIT

# Create test files with staggered modification times
for i in $(seq 1 12); do
    touch -t "202501010000.$(printf '%02d' $i)" "$TESTDIR/file_$i.txt"
done

# Create hidden files
touch -t "202501010001.00" "$TESTDIR/.hidden_a"
touch -t "202501010002.00" "$TESTDIR/.hidden_b"

echo "=== Test 1: Default output 10 lines ==="
OUTPUT=$("$SCRIPT" -d "$TESTDIR")
LINES=$(echo "$OUTPUT" | wc -l | tr -d ' ')
assert_line_count "default outputs 10 lines" 10 "$LINES"

echo ""
echo "=== Test 2: Custom count with -n ==="
OUTPUT=$("$SCRIPT" -d "$TESTDIR" -n 5)
LINES=$(echo "$OUTPUT" | wc -l | tr -d ' ')
assert_line_count "-n 5 outputs 5 lines" 5 "$LINES"

echo ""
echo "=== Test 3: Custom directory with -d ==="
OUTPUT=$("$SCRIPT" -d "$TESTDIR" -n 3)
LINES=$(echo "$OUTPUT" | wc -l | tr -d ' ')
assert_line_count "-d DIR -n 3 outputs 3 lines" 3 "$LINES"

echo ""
echo "=== Test 4: Hidden files excluded by default ==="
OUTPUT=$("$SCRIPT" -d "$TESTDIR" -n 20)
assert_not_contains "hidden files excluded by default" "$OUTPUT" ".hidden_a"

echo ""
echo "=== Test 5: Hidden files included with -a ==="
OUTPUT=$("$SCRIPT" -d "$TESTDIR" -n 20 -a)
assert_contains "hidden files included with -a" "$OUTPUT" ".hidden_a"
assert_contains "second hidden file also present" "$OUTPUT" ".hidden_b"

echo ""
echo "=== Test 6: Invalid count returns error ==="
OUTPUT=$("$SCRIPT" -n abc 2>&1)
RC=$?
assert_exit_code "invalid count exits non-zero" 1 "$RC"
assert_contains "error message mentions positive integer" "$OUTPUT" "positive integer"

echo ""
echo "=== Test 7: Zero count returns error ==="
OUTPUT=$("$SCRIPT" -n 0 2>&1)
RC=$?
assert_exit_code "zero count exits non-zero" 1 "$RC"

echo ""
echo "=== Test 8: Negative count returns error ==="
OUTPUT=$("$SCRIPT" -n -3 2>&1)
RC=$?
assert_exit_code "negative count exits non-zero" 1 "$RC"

echo ""
echo "=== Test 9: Non-existent directory returns error ==="
OUTPUT=$("$SCRIPT" -d /nonexistent_dir_xyz 2>&1)
RC=$?
assert_exit_code "nonexistent dir exits non-zero" 1 "$RC"
assert_contains "error message mentions directory" "$OUTPUT" "does not exist"

echo ""
echo "=== Test 10: Newest file appears first ==="
OUTPUT=$("$SCRIPT" -d "$TESTDIR" -n 1)
assert_contains "newest file first" "$OUTPUT" "file_12.txt"

echo ""
echo "=============================="
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
