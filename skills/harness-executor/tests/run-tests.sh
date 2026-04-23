#!/bin/bash
# harness-executor 脚本测试
# 用法: ./tests/run-tests.sh

set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)/scripts"
STATE="$SCRIPTS_DIR/harness-state"
GATE="$SCRIPTS_DIR/harness-gate"

PASS=0 FAIL=0 TOTAL=0

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ✗ $1"; }

assert_eq() {
  local desc="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$desc"; else fail "$desc (got '$got', want '$want')"; fi
}

assert_has() {
  local desc="$1" file="$2" pattern="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then pass "$desc"; else fail "$desc ($pattern not in $file)"; fi
}

assert_in() {
  local desc="$1" text="$2" pattern="$3"
  if echo "$text" | grep -q "$pattern" 2>/dev/null; then pass "$desc"; else fail "$desc ($pattern not found)"; fi
}

assert_file() {
  local desc="$1" file="$2"
  if [ -f "$file" ]; then pass "$desc"; else fail "$desc ($file missing)"; fi
}

assert_nofile() {
  local desc="$1" file="$2"
  if [ ! -f "$file" ]; then pass "$desc"; else fail "$desc ($file still exists)"; fi
}

exit_code() {
  local desc="$1" want="$2"; shift 2
  local rc=0; "$@" >/dev/null 2>&1 || rc=$?
  assert_eq "$desc" "$rc" "$want"
}

# ── Setup ──
TD=$(mktemp -d); trap "rm -rf $TD" EXIT
cd "$TD"; mkdir -p harness/state

J="harness/state/t.json"
T="harness/state/t.trace.md"

# ════════════════════════════════════════
echo "=== harness-state ==="

echo "--- init ---"
$STATE init t
assert_file "creates JSON" "$J"
assert_file "creates trace" "$T"
assert_eq "task name" "$(jq -r .task $J)" "t"
assert_eq "current_step 0" "$(jq -r .current_step $J)" "0"
assert_eq "steps empty" "$(jq -r '.steps_completed | length' $J)" "0"

echo "--- init duplicate ---"
exit_code "fails if exists" 1 $STATE init t

echo "--- advance ---"
$STATE advance t 3 complexity=medium reason="test"
assert_eq "step updated" "$(jq -r .current_step $J)" "3"
assert_eq "complexity set" "$(jq -r .complexity $J)" "medium"
assert_has "trace step header" "$T" "## Step 3"
assert_has "trace k=v pair" "$T" "complexity=medium"
assert_has "trace reason" "$T" "reason=test"

echo "--- advance skip ---"
OUT=$($STATE advance t 3 2>&1)
assert_in "reports skip" "$OUT" "已标记完成"

echo "--- advance accumulation ---"
$STATE advance t 5 files_changed="+A.swift" drift=PASS
$STATE advance t 7 validation_build=passed self_repair_attempts=0
STEP_N=$(grep -c "^## Step" $T)
assert_eq "3 steps in trace" "$STEP_N" "3"
assert_has "step 5 content" "$T" "files_changed"
assert_has "step 7 repair" "$T" "self_repair_attempts=0"

echo "--- advance without init ---"
exit_code "fails on missing" 1 $STATE advance no-such-task 1

echo "--- check ---"
OUT=$($STATE check t)
assert_in "check shows task" "$OUT" "t"
assert_in "check shows step" "$OUT" "3"

echo "--- reset ---"
$STATE reset t
assert_nofile "removes JSON" "$J"
assert_nofile "removes trace" "$T"

echo "--- reset idempotent ---"
$STATE reset t  # no error = pass
pass "reset on missing ok"

# ════════════════════════════════════════
echo ""
echo "=== harness-gate ==="

J="harness/state/g.json"

echo "--- step 1: no prereq ---"
$STATE init g
exit_code "step 1 passes" 0 $GATE g 1

echo "--- step 2: needs 1 ---"
exit_code "step 2 blocked" 1 $GATE g 2
$STATE advance g 1
exit_code "step 2 passes" 0 $GATE g 2

echo "--- step 3: needs 2 ---"
exit_code "step 3 blocked" 1 $GATE g 3
$STATE advance g 2
exit_code "step 3 passes" 0 $GATE g 3

echo "--- step 4: skip for simple ---"
$STATE advance g 3 complexity=simple
exit_code "step 4 skips" 2 $GATE g 4

echo "--- step 4: pass for medium ---"
$STATE reset g; $STATE init g
$STATE advance g 1; $STATE advance g 2
$STATE advance g 3 complexity=medium
exit_code "step 4 passes" 0 $GATE g 4

echo "--- step 5: simple path (needs 3) ---"
$STATE reset g; $STATE init g
$STATE advance g 1; $STATE advance g 2
$STATE advance g 3 complexity=simple
exit_code "step 5 simple ok" 0 $GATE g 5

echo "--- step 5: medium needs plan file ---"
$STATE reset g; $STATE init g
$STATE advance g 1; $STATE advance g 2
$STATE advance g 3 complexity=medium
$STATE advance g 4 plan_path=docs/missing.md
exit_code "step 5 blocked (no file)" 1 $GATE g 5
mkdir -p docs; touch docs/missing.md
exit_code "step 5 passes (file exists)" 0 $GATE g 5

echo "--- step 6: skip for simple ---"
$STATE reset g; $STATE init g
$STATE advance g 1; $STATE advance g 2
$STATE advance g 3 complexity=simple
$STATE advance g 5
exit_code "step 6 skips" 2 $GATE g 6

echo "--- step 6: medium needs 5 ---"
$STATE reset g; $STATE init g
$STATE advance g 1; $STATE advance g 2
$STATE advance g 3 complexity=medium
mkdir -p docs; touch docs/p.md
$STATE advance g 4 plan_path=docs/p.md
$STATE advance g 5
exit_code "step 6 passes" 0 $GATE g 6

echo "--- step 7: simple needs 5 ---"
$STATE reset g; $STATE init g
$STATE advance g 1; $STATE advance g 2
$STATE advance g 3 complexity=simple
$STATE advance g 5
exit_code "step 7 simple ok" 0 $GATE g 7

echo "--- step 7: medium needs 6 ---"
$STATE reset g; $STATE init g
$STATE advance g 1; $STATE advance g 2
$STATE advance g 3 complexity=medium
mkdir -p docs; touch docs/p.md
$STATE advance g 4 plan_path=docs/p.md
$STATE advance g 5; $STATE advance g 6 review_result=pass
exit_code "step 7 medium ok" 0 $GATE g 7

echo "--- step 8: blocks on failed validation ---"
$STATE reset g; $STATE init g
$STATE advance g 1; $STATE advance g 2
$STATE advance g 3 complexity=simple
$STATE advance g 5
$STATE advance g 7 validation_build=failed
exit_code "step 8 blocked" 1 $GATE g 8

echo "--- step 8: passes when valid ---"
$STATE reset g; $STATE init g
$STATE advance g 1; $STATE advance g 2
$STATE advance g 3 complexity=simple
$STATE advance g 5
$STATE advance g 7 validation_build=passed
exit_code "step 8 passes" 0 $GATE g 8

# ════════════════════════════════════════
echo ""
echo "=== full trace lifecycle ==="
$STATE reset g; $STATE init lifeycle
$STATE advance lifeycle 1
$STATE advance lifeycle 2
$STATE advance lifeycle 3 complexity=simple reason="typo"
$STATE advance lifeycle 5 files_changed="M README.md" drift=PASS
$STATE advance lifeycle 7 validation_build=passed validation_test=passed self_repair_attempts=0

LT="harness/state/lifeycle.trace.md"
assert_eq "5 steps recorded" "$(grep -c '^## Step' $LT)" "5"
assert_has "has reason" "$LT" "reason=typo"
assert_has "has files" "$LT" "files_changed=M README.md"
assert_has "has repair count" "$LT" "self_repair_attempts=0"

# ════════════════════════════════════════
echo ""
echo "============================="
echo " $PASS/$TOTAL passed, $FAIL failed"
echo "============================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
