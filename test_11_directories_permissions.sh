#!/bin/bash
# Regression tests for 0x01-shell_permissions/11-directories_permissions

SCRIPT="$(cd "$(dirname "$0")" && pwd)/0x01-shell_permissions/11-directories_permissions"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

setup() {
    TESTDIR=$(mktemp -d)
    cd "$TESTDIR" || exit 1
}

teardown() {
    cd /
    rm -rf "$TESTDIR"
}

# ---------- Test 1: regular file permissions unchanged ----------
echo "Test 1: regular file permissions unchanged"
setup
touch file1.txt
chmod 644 file1.txt
bash "$SCRIPT" >/dev/null 2>&1
perm=$(stat -f '%Lp' file1.txt 2>/dev/null || stat -c '%a' file1.txt 2>/dev/null)
if [ "$perm" = "644" ]; then
    pass "file1.txt stayed 644"
else
    fail "file1.txt changed to $perm (expected 644)"
fi
teardown

# ---------- Test 2: top-level directory gets execute permission ----------
echo "Test 2: top-level directory gets execute permission"
setup
mkdir topdir
chmod 644 topdir
bash "$SCRIPT" >/dev/null 2>&1
# Check that execute bit is set for owner
if [ -x topdir ]; then
    pass "topdir gained execute permission"
else
    fail "topdir did not gain execute permission"
fi
teardown

# ---------- Test 3: nested directory gets execute permission ----------
echo "Test 3: nested directory gets execute permission"
setup
mkdir -p a/b/c
chmod 644 a/b/c a/b a
bash "$SCRIPT" >/dev/null 2>&1
ok=true
for d in a a/b a/b/c; do
    if [ ! -x "$d" ]; then
        ok=false
        break
    fi
done
if $ok; then
    pass "nested directories all gained execute permission"
else
    fail "$d did not gain execute permission"
fi
teardown

# ---------- Test 4: hidden directory is processed ----------
echo "Test 4: hidden directory is processed"
setup
mkdir .hidden_dir
chmod 644 .hidden_dir
bash "$SCRIPT" >/dev/null 2>&1
if [ -x .hidden_dir ]; then
    pass ".hidden_dir gained execute permission"
else
    fail ".hidden_dir did not gain execute permission"
fi
teardown

# ---------- Test 5: symlink is not modified ----------
echo "Test 5: symlink is not modified"
setup
mkdir realdir
touch realfile
ln -s realdir link_to_dir
ln -s realfile link_to_file
chmod 644 realdir
# Record symlink target perms before
before_dir=$(stat -f '%Lp' realdir 2>/dev/null || stat -c '%a' realdir 2>/dev/null)
bash "$SCRIPT" >/dev/null 2>&1
# The symlink itself should still be a symlink (not converted)
if [ -L link_to_dir ] && [ -L link_to_file ]; then
    pass "symlinks remain symlinks"
else
    fail "symlinks were altered"
fi
teardown

# ---------- Test 6: empty directory scenario runs cleanly ----------
echo "Test 6: empty directory scenario runs cleanly"
setup
# TESTDIR is already empty
output=$(bash "$SCRIPT" 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
    pass "script exits 0 on empty directory"
else
    fail "script exited with $rc on empty directory"
fi
teardown

# ---------- Test 7: only regular files, no subdirectories ----------
echo "Test 7: only regular files, no subdirectories"
setup
touch a.txt b.txt c.txt
chmod 600 a.txt b.txt c.txt
bash "$SCRIPT" >/dev/null 2>&1
rc=$?
perm_a=$(stat -f '%Lp' a.txt 2>/dev/null || stat -c '%a' a.txt 2>/dev/null)
perm_b=$(stat -f '%Lp' b.txt 2>/dev/null || stat -c '%a' b.txt 2>/dev/null)
if [ $rc -eq 0 ] && [ "$perm_a" = "600" ] && [ "$perm_b" = "600" ]; then
    pass "files unchanged and script exits 0"
else
    fail "rc=$rc, a.txt=$perm_a, b.txt=$perm_b"
fi
teardown

# ---------- Summary ----------
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
    exit 1
fi
exit 0
