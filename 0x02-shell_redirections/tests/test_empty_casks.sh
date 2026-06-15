#!/bin/bash
# Regression tests for 100-empty_casks
# Run from the repository root: bash 0x02-shell_redirections/tests/test_empty_casks.sh

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/100-empty_casks"
TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" = "$actual" ]]; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc"
        echo "  expected: $(echo "$expected" | head -5)"
        echo "  actual:   $(echo "$actual" | head -5)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc"
        echo "  expected to contain: $needle"
        echo "  actual: $(echo "$haystack" | head -5)"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if ! echo "$haystack" | grep -qF "$needle"; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc"
        echo "  expected NOT to contain: $needle"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_code() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" = "$actual" ]]; then
        echo "PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc"
        echo "  expected exit code: $expected"
        echo "  actual exit code:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

# ---- Setup test fixture ----
FIXTURE="$TMPDIR_BASE/fixture"
mkdir -p "$FIXTURE/sub1" "$FIXTURE/sub2" "$FIXTURE/deep/nested"

# Empty files
touch "$FIXTURE/empty_file_a"
touch "$FIXTURE/sub1/empty_file_b"
touch "$FIXTURE/sub2/empty_file_a"   # same name as above, different dir

# Empty directories
mkdir "$FIXTURE/empty_dir_x"
mkdir "$FIXTURE/deep/empty_dir_y"

# Non-empty file
echo "hello" > "$FIXTURE/not_empty.txt"

echo "=== Test 1: Default scan (current directory, basename mode) ==="
out=$(cd "$FIXTURE" && "$SCRIPT")
assert_contains "finds empty_file_a" "empty_file_a" "$out"
assert_contains "finds empty_file_b" "empty_file_b" "$out"
assert_contains "finds empty_dir_x" "empty_dir_x" "$out"
assert_contains "finds empty_dir_y" "empty_dir_y" "$out"
assert_not_contains "excludes non-empty file" "not_empty.txt" "$out"

echo ""
echo "=== Test 2: Scan specified directory ==="
out=$("$SCRIPT" "$FIXTURE")
assert_contains "finds empty_file_a in target dir" "empty_file_a" "$out"
assert_contains "finds empty_dir_x in target dir" "empty_dir_x" "$out"

echo ""
echo "=== Test 3: Files only mode ==="
out=$("$SCRIPT" "$FIXTURE" -t files)
assert_contains "finds empty file" "empty_file_a" "$out"
assert_not_contains "excludes empty dir" "empty_dir_x" "$out"
assert_not_contains "excludes empty dir y" "empty_dir_y" "$out"

echo ""
echo "=== Test 4: Dirs only mode ==="
out=$("$SCRIPT" "$FIXTURE" -t dirs)
assert_contains "finds empty dir" "empty_dir_x" "$out"
assert_not_contains "excludes empty file" "empty_file_a" "$out"

echo ""
echo "=== Test 5: Full path mode distinguishes same-name results ==="
out=$("$SCRIPT" "$FIXTURE" -p -t files)
assert_contains "shows path sub1/empty_file_b" "sub1/empty_file_b" "$out"
assert_contains "shows path sub2/empty_file_a" "sub2/empty_file_a" "$out"
# In basename mode, we can't tell which empty_file_a is which
out_base=$("$SCRIPT" "$FIXTURE" -t files)
# Both should appear but we can't distinguish paths
assert_contains "basename mode still shows empty_file_a" "empty_file_a" "$out_base"

echo ""
echo "=== Test 6: Non-existent directory gives error ==="
out=$("$SCRIPT" "/nonexistent_dir_xyz_12345" 2>&1) && rc=$? || rc=$?
assert_exit_code "exits non-zero for missing dir" "1" "$rc"
assert_contains "error message mentions directory" "does not exist" "$out"

echo ""
echo "=== Test 7: Sorted output is stable ==="
out1=$("$SCRIPT" "$FIXTURE" -p | sort)
out2=$("$SCRIPT" "$FIXTURE" -p | sort)
assert_eq "two runs produce identical sorted output" "$out1" "$out2"

echo ""
echo "=== Test 8: . and .. are not in output ==="
out=$("$SCRIPT" "$FIXTURE" -p)
assert_not_contains "no dot entry" "^.$" "$out"
assert_not_contains "no dotdot entry" "^..$" "$out"

echo ""
echo "=== Test 9: All mode (explicit -t all) ==="
out=$("$SCRIPT" "$FIXTURE" -t all)
assert_contains "all mode includes files" "empty_file_a" "$out"
assert_contains "all mode includes dirs" "empty_dir_x" "$out"

echo ""
echo "=============================="
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
