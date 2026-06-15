#!/bin/bash
# Regression tests for 0x03-shell_variables_expansions/2-path

SCRIPT="0x03-shell_variables_expansions/2-path"
TMPFILE=$(mktemp)
echo "0 0" > "$TMPFILE"

get_counts() { cat "$TMPFILE"; }
inc_pass() { local p f; read p f < "$TMPFILE"; echo "$((p+1)) $f" > "$TMPFILE"; }
inc_fail() { local p f; read p f < "$TMPFILE"; echo "$p $((f+1))" > "$TMPFILE"; }

assert_contains_exactly_n() {
  local path_val="$1"
  local target="$2"
  local expected="$3"
  local desc="$4"

  local count=0
  local old_ifs="$IFS"
  IFS=':'
  for seg in $path_val; do
    if [ "$seg" = "$target" ]; then
      count=$((count + 1))
    fi
  done
  IFS="$old_ifs"

  if [ "$count" -eq "$expected" ]; then
    echo "PASS: $desc"
    inc_pass
  else
    echo "FAIL: $desc (expected $expected occurrences of '$target', got $count in PATH='$path_val')"
    inc_fail
  fi
}

assert_match() {
  local path_val="$1"
  local pattern="$2"
  local desc_pass="$3"
  local desc_fail="$4"

  case "$path_val" in
    $pattern)
      echo "PASS: $desc_pass"
      inc_pass
      ;;
    *)
      echo "FAIL: $desc_fail (PATH='$path_val')"
      inc_fail
      ;;
  esac
}

# Test 1: PATH without /action -> should add it
export PATH="/usr/bin:/bin"
source "$SCRIPT"
assert_contains_exactly_n "$PATH" "/action" 1 "adds /action when not present"

# Test 2: PATH already has /action at end -> no duplicate
export PATH="/usr/bin:/bin:/action"
source "$SCRIPT"
assert_contains_exactly_n "$PATH" "/action" 1 "no duplicate when /action already at end"

# Test 3: PATH already has /action at beginning -> no duplicate
export PATH="/action:/usr/bin:/bin"
source "$SCRIPT"
assert_contains_exactly_n "$PATH" "/action" 1 "no duplicate when /action at beginning"

# Test 4: PATH already has /action in middle -> no duplicate
export PATH="/usr/bin:/action:/bin"
source "$SCRIPT"
assert_contains_exactly_n "$PATH" "/action" 1 "no duplicate when /action in middle"

# Test 5: Repeat execution twice -> still only one /action
export PATH="/usr/bin:/bin"
source "$SCRIPT"
source "$SCRIPT"
assert_contains_exactly_n "$PATH" "/action" 1 "idempotent after double source"

# Test 6: Repeat execution three times -> still only one /action
export PATH="/usr/bin:/bin"
source "$SCRIPT"
source "$SCRIPT"
source "$SCRIPT"
assert_contains_exactly_n "$PATH" "/action" 1 "idempotent after triple source"

# Test 7: PATH with empty segments (::) is preserved
export PATH="/usr/bin::/bin"
source "$SCRIPT"
assert_contains_exactly_n "$PATH" "/action" 1 "adds /action with empty segment in PATH"
assert_match "$PATH" *"::"* "empty segment (::) preserved" "empty segment (::) was destroyed"

# Test 8: PATH with leading empty segment (:...)
export PATH=":/usr/bin:/bin"
source "$SCRIPT"
assert_contains_exactly_n "$PATH" "/action" 1 "adds /action with leading empty segment"
assert_match "$PATH" ":"* "leading empty segment preserved" "leading empty segment was destroyed"

# Test 9: PATH with trailing empty segment (...:)
export PATH="/usr/bin:/bin:"
source "$SCRIPT"
assert_contains_exactly_n "$PATH" "/action" 1 "adds /action with trailing empty segment"

# Test 10: Other directories are not removed or reordered
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/bin"
source "$SCRIPT"
cleaned=$(echo "$PATH" | tr ':' '\n' | grep -v '^/action$' | tr '\n' ':' | sed 's/:$//')
if [ "$cleaned" = "/usr/local/bin:/usr/bin:/bin:/opt/bin" ]; then
  echo "PASS: original directories preserved in order"
  inc_pass
else
  echo "FAIL: original directories changed (got '$cleaned')"
  inc_fail
fi

echo ""
read p f < "$TMPFILE"
rm -f "$TMPFILE"
echo "Results: $p passed, $f failed"
[ "$f" -eq 0 ]
