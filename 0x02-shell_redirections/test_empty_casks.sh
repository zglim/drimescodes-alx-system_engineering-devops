#!/bin/bash
# Regression tests for 100-empty_casks
SCRIPT="$(cd "$(dirname "$0")" && pwd)/100-empty_casks"
PASS=0
FAIL=0
TMPDIR=$(mktemp -d)

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label"
        echo "  expected: $(echo "$expected" | cat -A)"
        echo "  actual:   $(echo "$actual" | cat -A)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo "PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label"
        echo "  expected to contain: $needle"
        echo "  actual: $haystack"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit() {
    local label="$1" expected_code="$2"
    shift 2
    "$@" >/dev/null 2>&1
    local rc=$?
    if [ "$rc" -eq "$expected_code" ]; then
        echo "PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label (exit $rc, expected $expected_code)"
        FAIL=$((FAIL + 1))
    fi
}

# --- Setup test fixtures ---
# Structure:
#   $TMPDIR/
#     empty_file_a
#     empty_dir_a/
#     nonempty_file (has content)
#     sub1/
#       empty_file_a    (same name as top-level, for disambiguation test)
#       empty_dir_b/
#     sub2/
#       empty_file_c
touch "$TMPDIR/empty_file_a"
mkdir "$TMPDIR/empty_dir_a"
echo "content" > "$TMPDIR/nonempty_file"
mkdir -p "$TMPDIR/sub1"
touch "$TMPDIR/sub1/empty_file_a"
mkdir "$TMPDIR/sub1/empty_dir_b"
mkdir -p "$TMPDIR/sub2"
touch "$TMPDIR/sub2/empty_file_c"

# --- Test 1: Default scan of current directory ---
echo "=== Test 1: Default scan (current dir) ==="
OUT=$(cd "$TMPDIR" && bash "$SCRIPT")
# Should list basenames of all empty files and dirs, sorted
EXPECTED="empty_dir_a
empty_dir_b
empty_file_a
empty_file_a
empty_file_c"
assert_eq "default scan lists all empty entries as sorted basenames" "$EXPECTED" "$OUT"

# --- Test 2: Specified target directory ---
echo "=== Test 2: Specified target directory ==="
OUT=$(bash "$SCRIPT" "$TMPDIR/sub1")
EXPECTED="empty_dir_b
empty_file_a"
assert_eq "scan specified directory" "$EXPECTED" "$OUT"

# --- Test 3: Files-only mode ---
echo "=== Test 3: Files-only mode (-t f) ==="
OUT=$(bash "$SCRIPT" -t f "$TMPDIR")
EXPECTED="empty_file_a
empty_file_a
empty_file_c"
assert_eq "files-only mode" "$EXPECTED" "$OUT"

# --- Test 4: Dirs-only mode ---
echo "=== Test 4: Dirs-only mode (-t d) ==="
OUT=$(bash "$SCRIPT" -t d "$TMPDIR")
EXPECTED="empty_dir_a
empty_dir_b"
assert_eq "dirs-only mode" "$EXPECTED" "$OUT"

# --- Test 5: Full path mode distinguishes same-name entries ---
echo "=== Test 5: Full path mode (-p) ==="
OUT=$(bash "$SCRIPT" -t f -p "$TMPDIR")
# Full paths should let us tell the two empty_file_a apart
COUNT_A=$(echo "$OUT" | grep -c "empty_file_a")
assert_eq "full path mode shows two distinct empty_file_a paths" "2" "$COUNT_A"
# Each path should contain directory context
assert_contains "full path includes sub1 for nested file" "sub1/empty_file_a" "$OUT"

# --- Test 6: Non-existent directory gives error ---
echo "=== Test 6: Non-existent directory error ==="
ERR=$(bash "$SCRIPT" "/no/such/dir" 2>&1)
assert_exit "non-existent dir exits non-zero" 1 bash "$SCRIPT" "/no/such/dir"
assert_contains "error message mentions does not exist" "does not exist" "$ERR"

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
