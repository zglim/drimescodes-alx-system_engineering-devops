#!/bin/bash
# Regression tests for 11-directories_permissions
# Covers: file unchanged, top-level dir, nested dir, hidden dir, symlink safe, empty dir

set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/11-directories_permissions"
TMPDIR_BASE="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

assert_perm() {
    local path="$1" expected="$2" label="$3"
    local actual
    actual="$(stat -f '%Lp' "$path" 2>/dev/null || stat -c '%a' "$path" 2>/dev/null)"
    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $label (got $actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (expected $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

# --- Test 1: Regular file permissions unchanged ---
echo "[Test 1] Regular file permissions unchanged"
td="$TMPDIR_BASE/t1"; mkdir -p "$td"
touch "$td/file.txt"; chmod 644 "$td/file.txt"
(cd "$td" && bash "$SCRIPT")
assert_perm "$td/file.txt" "644" "regular file stays 644"

# --- Test 2: Top-level directory gets execute permission ---
echo "[Test 2] Top-level directory gets execute permission"
td="$TMPDIR_BASE/t2"; mkdir -p "$td/subdir"
chmod 600 "$td/subdir"
(cd "$td" && bash "$SCRIPT")
assert_perm "$td/subdir" "711" "top-level dir gets a+x (600->711)"

# --- Test 3: Nested directory gets execute permission ---
echo "[Test 3] Nested directory gets execute permission"
td="$TMPDIR_BASE/t3"; mkdir -p "$td/a/b/c"
chmod 600 "$td/a/b/c"
chmod 700 "$td/a/b"
chmod 700 "$td/a"
(cd "$td" && bash "$SCRIPT")
assert_perm "$td/a/b/c" "711" "nested dir a/b/c gets a+x"

# --- Test 4: Hidden directory is processed ---
echo "[Test 4] Hidden directory is processed"
td="$TMPDIR_BASE/t4"; mkdir -p "$td/.hidden_dir"
chmod 600 "$td/.hidden_dir"
(cd "$td" && bash "$SCRIPT")
assert_perm "$td/.hidden_dir" "711" "hidden dir .hidden_dir gets a+x"

# --- Test 5: Symlink not modified ---
echo "[Test 5] Symlink not modified"
td="$TMPDIR_BASE/t5"; mkdir -p "$td/realdir"
chmod 755 "$td/realdir"
ln -s "$td/realdir" "$td/linkdir"
touch "$td/realfile"; chmod 644 "$td/realfile"
ln -s "$td/realfile" "$td/linkfile"
(cd "$td" && bash "$SCRIPT")
# The symlink target (realfile) should remain 644
assert_perm "$td/realfile" "644" "symlink target file unchanged"
# realdir already had execute, should still be 755
assert_perm "$td/realdir" "755" "symlink target dir unchanged from 755"

# --- Test 6: Empty directory scenario ---
echo "[Test 6] Empty directory - script exits cleanly"
td="$TMPDIR_BASE/t6"; mkdir -p "$td"
if (cd "$td" && bash "$SCRIPT"); then
    echo "  PASS: empty directory exits 0"
    PASS=$((PASS + 1))
else
    echo "  FAIL: empty directory exited non-zero"
    FAIL=$((FAIL + 1))
fi

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
