#!/bin/bash
# test-claim-audit.sh — verification harness for claim-audit.sh
# Builds synthetic transcripts, pipes them through claim-audit.sh, asserts exit codes.
# Run manually: ./test-claim-audit.sh

set -uo pipefail

HOOK="$HOME/.claude/hooks/claim-audit.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0
FAIL_NAMES=()

# Build a synthetic transcript at $TMPDIR/transcript-$N.jsonl from the args:
#   $1: case name
#   $2: user prompt text
#   $3: JSON array of tool calls — each {name, target, result}; "" for empty
#   $4: assistant final text
build_transcript() {
  local name="$1" user="$2" tools_json="$3" assistant="$4"
  local file="$TMPDIR/transcript-$name.jsonl"
  : >"$file"
  jq -nc --arg c "$user" '{type:"user", message:{role:"user", content:$c}}' >>"$file"
  echo "$tools_json" | jq -c '.[]' | while IFS= read -r tool; do
    local tname tinput tresult uid
    tname=$(jq -r '.name' <<<"$tool")
    tinput=$(jq -c '
      if .name == "WebFetch" then {url: .target}
      elif .name == "Read" or .name == "Edit" or .name == "Write" or .name == "MultiEdit" then {file_path: .target}
      elif .name == "Grep" or .name == "Glob" then {pattern: "x", path: .target}
      else {target: .target}
      end' <<<"$tool")
    tresult=$(jq -r '.result' <<<"$tool")
    uid="toolu_$(date +%s%N)_$RANDOM"
    jq -nc --arg uid "$uid" --arg n "$tname" --argjson inp "$tinput" \
      '{type:"assistant", message:{role:"assistant", content:[{type:"tool_use", id:$uid, name:$n, input:$inp}]}}' >>"$file"
    jq -nc --arg uid "$uid" --arg t "$tresult" \
      '{type:"user", message:{role:"user", content:[{type:"tool_result", tool_use_id:$uid, content:$t}]}}' >>"$file"
  done
  jq -nc --arg t "$assistant" \
    '{type:"assistant", message:{role:"assistant", content:[{type:"text", text:$t}]}}' >>"$file"
  echo "$file"
}

# Run the hook with a synthetic transcript and assert exit code.
#   $1: name, $2: expected exit code, $3: transcript path, optional $4: must-contain in stderr
run_case() {
  local name="$1" expected="$2" transcript="$3" must_contain="${4:-}"
  local actual stderr stdout
  local input
  input=$(jq -nc --arg p "$transcript" '{transcript_path:$p, hook_event_name:"Stop", session_id:"test"}')
  stderr=$(mktemp)
  stdout=$("$HOOK" <<<"$input" 2>"$stderr")
  actual=$?
  local stderr_content
  stderr_content=$(cat "$stderr")
  rm -f "$stderr"

  local ok=1
  if [ "$actual" != "$expected" ]; then ok=0; fi
  if [ -n "$must_contain" ] && ! grep -qF -- "$must_contain" <<<"$stderr_content$stdout"; then ok=0; fi

  if [ "$ok" -eq 1 ]; then
    PASS=$((PASS + 1))
    echo "PASS: $name"
  else
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("$name (expected exit=$expected, got=$actual)")
    echo "FAIL: $name (expected exit=$expected, got=$actual)"
    echo "       stdout: $(head -c 300 <<<"$stdout")"
    echo "       stderr: $(head -c 400 <<<"$stderr_content")"
  fi
}

# ============================================================
# Layer 1 cases
# ============================================================

# 1: positive (verified URL with proper tag and matching tool call)
TRANSCRIPT=$(build_transcript "01-positive-url" \
  "tell me about https://foo.com" \
  '[{"name":"WebFetch","target":"https://foo.com","result":"This API returns 5 requests per 10 seconds. Other documentation here."}]' \
  '[VERIFIED:WebFetch@https://foo.com] "This API returns 5 requests per 10 seconds." That is the rate limit.')
run_case "01-positive-url" 0 "$TRANSCRIPT"

# 2: Tier A negative — fabricated URL claim, no WebFetch in transcript
TRANSCRIPT=$(build_transcript "02-fabricated-url" \
  "tell me about https://foo.com" \
  '[]' \
  'I checked https://foo.com and it allows unlimited requests.')
run_case "02-fabricated-url" 2 "$TRANSCRIPT" "https://foo.com"

# 3: Tier A negative — fabricated file claim
TRANSCRIPT=$(build_transcript "03-fabricated-file" \
  "look at src/auth.ts" \
  '[]' \
  'I read src/auth.ts; the validation is at line 42.')
run_case "03-fabricated-file" 2 "$TRANSCRIPT" "src/auth.ts"

# 4: Tier C — speculative phrasing should pass
TRANSCRIPT=$(build_transcript "04-speculative" \
  "what does the API do?" \
  '[]' \
  'The docs probably support pagination. I would expect rate limits exist.')
run_case "04-speculative" 0 "$TRANSCRIPT"

# 6: false-positive control — user mentions URL, assistant echoes without claim
TRANSCRIPT=$(build_transcript "06-echo-user-url" \
  "Could you save this for later? https://foo.com" \
  '[]' \
  'Saved your link to https://foo.com.')
run_case "06-echo-user-url" 0 "$TRANSCRIPT"

# ============================================================
# Layer 5 cases (quoted-evidence)
# ============================================================

# 7: Quote matches source
TRANSCRIPT=$(build_transcript "07-quote-matches" \
  "rate limit?" \
  '[{"name":"WebFetch","target":"https://foo.com","result":"This API returns 5 requests per 10 seconds. More text here."}]' \
  '[VERIFIED:WebFetch@https://foo.com] "This API returns 5 requests per 10 seconds." Got it.')
run_case "07-quote-matches" 0 "$TRANSCRIPT"

# 8: Fabricated quote — substring not in tool result
TRANSCRIPT=$(build_transcript "08-fabricated-quote" \
  "rate limit?" \
  '[{"name":"WebFetch","target":"https://foo.com","result":"This API has restrictions on usage."}]' \
  '[VERIFIED:WebFetch@https://foo.com] "the API allows unlimited concurrent connections forever".')
run_case "08-fabricated-quote" 2 "$TRANSCRIPT" "fabricated quote"

# ============================================================
# Layer 6 cases (untagged-claim)
# ============================================================

# 10: "According to URL" without fetch. Layer 1 Tier A — explicit reference
# to a source Claude never retrieved is a fabrication signal. Stays exit 2.
TRANSCRIPT=$(build_transcript "10-according-to-fabrication" \
  "" \
  '[]' \
  'According to https://docs.example.com/api the service exposes a webhook endpoint.')
run_case "10-according-to-fabrication" 2 "$TRANSCRIPT"

# 11: Tagged inference — legitimate honesty
TRANSCRIPT=$(build_transcript "11-tagged-inferred" \
  "" \
  '[]' \
  '[INFERRED] The YouTube transcript API likely has rate limits; I have not fetched the docs to confirm.')
run_case "11-tagged-inferred" 0 "$TRANSCRIPT"

# 12: Untagged file claim. Layer 6 → Tier B (logged, no block) — exit 0.
TRANSCRIPT=$(build_transcript "12-untagged-file-claim" \
  "" \
  '[]' \
  'The auth.ts file defines the JWT verification logic.')
run_case "12-untagged-file-claim" 0 "$TRANSCRIPT"

# ============================================================
# Layer 5b cases (quote length floor)
# ============================================================

# 13: Quote too short, no anchor. Layer 5b → Tier B (style, no block) — exit 0.
TRANSCRIPT=$(build_transcript "13-quote-too-short" \
  "" \
  '[{"name":"WebFetch","target":"https://foo.com","result":"foo bar"}]' \
  '[VERIFIED:WebFetch@https://foo.com] "foo bar".')
run_case "13-quote-too-short" 0 "$TRANSCRIPT"

# 14: Position marker substitute (line anchor)
TRANSCRIPT=$(build_transcript "14-line-anchor" \
  "" \
  '[{"name":"WebFetch","target":"https://foo.com","result":"5 req/10s"}]' \
  '[VERIFIED:WebFetch@https://foo.com line 14] "5 req/10s" got it.')
run_case "14-line-anchor" 0 "$TRANSCRIPT"

# ============================================================
# Layer 6b cases (external entity)
# ============================================================

# 15: Bare claim with external-entity trigger ("youtube" + content verb).
# Layer 6b is now silent (logs to ~/.claude/logs/claim-near-miss.jsonl,
# allows the stop). Verb "documents" is on the trimmed assertion list;
# "allows" was removed, so we use "documents" to actually exercise the layer.
TRANSCRIPT=$(build_transcript "15-bare-external-claim" \
  "" \
  '[]' \
  'The youtube transcript API documents a 5-requests-per-10-seconds rate limit.')
run_case "15-bare-external-claim" 0 "$TRANSCRIPT"

# 16: Tagged inference about external entity → no warn
TRANSCRIPT=$(build_transcript "16-tagged-external-inferred" \
  "" \
  '[]' \
  '[INFERRED] The YouTube transcript API likely supports pagination.')
run_case "16-tagged-external-inferred" 0 "$TRANSCRIPT"

# ============================================================
# Layer 10 cases (conclusion-marking)
# ============================================================

# 20: Unmarked conclusion drawing on multiple verified facts. Layer 10 is
# now silent (logs to ~/.claude/logs/claim-near-miss.jsonl, allows stop).
TRANSCRIPT=$(build_transcript "20-unmarked-conclusion" \
  "" \
  '[{"name":"WebFetch","target":"https://x.com","result":"X has rate limit five per ten seconds documented here."},{"name":"Read","target":"src/auth.ts","result":"function refresh() { /* concurrent-unsafe code */ }"}]' \
  '[VERIFIED:WebFetch@https://x.com] "X has rate limit five per ten seconds documented here." [VERIFIED:Read@src/auth.ts] "function refresh() { /* concurrent-unsafe code */ }". Therefore the system cannot handle concurrent token refresh under load.')
run_case "20-unmarked-conclusion" 0 "$TRANSCRIPT"

# 21: Properly marked conclusion
TRANSCRIPT=$(build_transcript "21-marked-conclusion" \
  "" \
  '[{"name":"WebFetch","target":"https://x.com","result":"X has rate limit five per ten seconds documented here."},{"name":"Read","target":"src/auth.ts","result":"function refresh() { /* concurrent-unsafe code */ }"}]' \
  '[VERIFIED:WebFetch@https://x.com] "X has rate limit five per ten seconds documented here." [VERIFIED:Read@src/auth.ts] "function refresh() { /* concurrent-unsafe code */ }". [CONCLUSION from: WebFetch@https://x.com, Read@src/auth.ts] The system cannot handle concurrent token refresh under load.')
run_case "21-marked-conclusion" 0 "$TRANSCRIPT"

# ============================================================
# ============================================================
# Regression cases (false positives caught in real use)
# ============================================================

# 22: Filename inside backticks with content verb in surrounding prose — should NOT fire
# (the file is referenced as a code identifier, not asserted-about as content).
TRANSCRIPT=$(build_transcript "22-backticked-filename" \
  "" \
  '[]' \
  'The existing `verify-before-stop.sh` was a soft hook; the new design replaces it.')
run_case "22-backticked-filename" 0 "$TRANSCRIPT"

# 23: "I read X" inside a fenced code block (illustrative example) — should NOT fire
TRANSCRIPT=$(build_transcript "23-tier-a-in-fence" \
  "" \
  '[]' \
  'Here is what the test case looks like:

```
I read src/auth.ts and the validation is at line 42.
```

That phrasing would block in real use.')
run_case "23-tier-a-in-fence" 0 "$TRANSCRIPT"

# 24: Documentation placeholder [VERIFIED:tool@target] in prose — should NOT fire
TRANSCRIPT=$(build_transcript "24-placeholder-tool-name" \
  "" \
  '[]' \
  'Citations follow the [VERIFIED:tool@target] format. This is a documentation example, not a real claim.')
run_case "24-placeholder-tool-name" 0 "$TRANSCRIPT"

# 25: [VERIFIED:WebFetch@<url>] placeholder — should NOT fire
TRANSCRIPT=$(build_transcript "25-placeholder-angle-bracket" \
  "" \
  '[]' \
  'The contract format is [VERIFIED:WebFetch@<url>] "<quoted snippet>" for verified web content.')
run_case "25-placeholder-angle-bracket" 0 "$TRANSCRIPT"

# 26: "real use" sentence with a path — "use" should not count as content verb
TRANSCRIPT=$(build_transcript "26-noun-use" \
  "" \
  '[]' \
  'After a week of real use, review `~/.claude/logs/claim-near-miss.jsonl` for entries.')
run_case "26-noun-use" 0 "$TRANSCRIPT"

# ============================================================
# Regression cases for fixes applied in the perfecting pass
# ============================================================

# Variant of run_case with stop_hook_active=true in the input. Used to verify
# the documented escape valve — when Claude is already in a continuation
# triggered by a previous Stop hook block, the hook MUST exit 0 regardless of
# what would normally fire. Without this, blocks loop forever.
run_case_active() {
  local name="$1" expected="$2" transcript="$3"
  local input stderr stdout actual
  input=$(jq -nc --arg p "$transcript" '{transcript_path:$p, hook_event_name:"Stop", session_id:"test", stop_hook_active:true}')
  stderr=$(mktemp)
  stdout=$("$HOOK" <<<"$input" 2>"$stderr")
  actual=$?
  rm -f "$stderr"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    echo "PASS: $name"
  else
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("$name (expected exit=$expected, got=$actual)")
    echo "FAIL: $name (expected=$expected, got=$actual)"
  fi
}

# 27: stop_hook_active=true short-circuits even on otherwise-Tier-A input.
# Reuses the fabricated-URL transcript from case 02 (which exits 2 normally).
TRANSCRIPT=$(build_transcript "27-active-shortcircuit" \
  "tell me about https://foo.com" \
  '[]' \
  'I checked https://foo.com and it allows unlimited requests.')
run_case_active "27-stop-hook-active-shortcircuit" 0 "$TRANSCRIPT"

# 28: Layer 5b — exactly 5 words, ≥30 chars. With the fixed word_count this
# should pass. Pre-fix, word_count returned 4 for a 5-word string and Layer 5b
# blocked legitimate quotes at the threshold.
TRANSCRIPT=$(build_transcript "28-five-word-quote" \
  "" \
  '[{"name":"WebFetch","target":"https://foo.com","result":"The configuration documents the access rules clearly here. More text follows."}]' \
  '[VERIFIED:WebFetch@https://foo.com] "configuration documents the access rules" — that is the doc.')
run_case "28-five-word-quote-passes-5b" 0 "$TRANSCRIPT"

# 29: Layer 5 — quote contains backticked tokens. Pre-fix, the strip-code
# step blanked the backticked spans before the substring grep, so legitimate
# quotes containing backticks failed the match. After fix, Layer 5 reads
# nonfenced_text (backticks preserved) and matches against raw tool result.
TRANSCRIPT=$(build_transcript "29-backtick-quote" \
  "" \
  '[{"name":"WebFetch","target":"https://docs.example.com/hooks","result":"Parse the `stop_hook_active` field from the JSON input and exit early when set."}]' \
  '[VERIFIED:WebFetch@https://docs.example.com/hooks] "Parse the `stop_hook_active` field from the JSON input"')
run_case "29-backtick-quote-matches-source" 0 "$TRANSCRIPT"

# 30: Self-edit safelist — file Read this session, then mentioned with a
# content verb in an untagged sentence. Pre-fix this was a Tier A Layer 6 block.
# After fix the safelist allows it, since Claude is operating on the file.
TRANSCRIPT=$(build_transcript "30-self-edit-safelist" \
  "" \
  '[{"name":"Read","target":"src/auth.ts","result":"export function verifyJWT(token) { /* ... */ }"}]' \
  'The auth.ts file defines the JWT verification logic that needs adjusting.')
run_case "30-self-edit-safelist-allows-claim" 0 "$TRANSCRIPT"

# 31: Self-edit safelist with basename mismatch — tool call uses src/auth.ts
# (full path), assistant prose mentions auth.ts (basename). New endswith match
# logic handles this case.
TRANSCRIPT=$(build_transcript "31-self-edit-basename" \
  "" \
  '[{"name":"Edit","target":"src/auth.ts","result":""}]' \
  'auth.ts now defines the refresh-token path explicitly.')
run_case "31-self-edit-basename-match" 0 "$TRANSCRIPT"

# 32: Path-match must NOT false-positive on substring collision. Tool target
# is src/auth.ts; assistant mentions src/myauth.ts (different file) with
# content verb and no tag. Layer 6 → Tier B → exit 0 (logged, no block).
TRANSCRIPT=$(build_transcript "32-path-collision-no-loop-block" \
  "" \
  '[{"name":"Read","target":"src/auth.ts","result":"export function verifyJWT(token) { /* ... */ }"}]' \
  'src/myauth.ts defines a different JWT verification path.')
run_case "32-path-collision-no-loop-block" 0 "$TRANSCRIPT"

# ============================================================
# Tests for the lighter citation contract (anchor-only form,
# bare-tag block, WebFetch fragment preservation).
# ============================================================

# 33: Anchor-only citation passes — Read on path, citation [VERIFIED:Read@path#L42-L58]
# with no quote. Structural reference form; quote not required.
TRANSCRIPT=$(build_transcript "33-anchor-only-passes" \
  "" \
  '[{"name":"Read","target":"src/auth.ts","result":"line1\nline2\nline3"}]' \
  'The verification logic lives at [VERIFIED:Read@src/auth.ts#L42-L58]. No quote needed.')
run_case "33-anchor-only-passes" 0 "$TRANSCRIPT"

# 34: URL-fragment anchor matches Read target after #L strip.
TRANSCRIPT=$(build_transcript "34-fragment-strip-matches-read" \
  "" \
  '[{"name":"Read","target":"C:\\file.ts","result":"some code here"}]' \
  'See [VERIFIED:Read@C:\file.ts#L1-L10] for the entry point.')
run_case "34-fragment-strip-matches-read" 0 "$TRANSCRIPT"

# 35: Anchor-only with no matching tool call → block.
TRANSCRIPT=$(build_transcript "35-anchor-only-no-tool-call" \
  "" \
  '[]' \
  'The logic is at [VERIFIED:Read@src/never_read.ts#L42-L58]. Should block.')
run_case "35-anchor-only-no-tool-call" 2 "$TRANSCRIPT" "no matching tool call"

# 36: Bare tag (no anchor, no quote). Tier B (style issue, logged) — exit 0.
TRANSCRIPT=$(build_transcript "36-bare-tag-tier-b" \
  "" \
  '[{"name":"Read","target":"src/auth.ts","result":"some code"}]' \
  'Look at [VERIFIED:Read@src/auth.ts]. Bare name-drop is style-only.')
run_case "36-bare-tag-tier-b" 0 "$TRANSCRIPT"

# 37: WebFetch URL containing #L42 must NOT be stripped — the URL itself is
# the target (e.g., a GitHub blob link). Tool-match preserves the fragment.
TRANSCRIPT=$(build_transcript "37-webfetch-fragment-preserved" \
  "" \
  '[{"name":"WebFetch","target":"https://github.com/foo/bar/blob/main/x.ts#L42","result":"function foo(arg) { return arg.bar.baz.qux; } more code"}]' \
  '[VERIFIED:WebFetch@https://github.com/foo/bar/blob/main/x.ts#L42] "function foo(arg) { return arg.bar.baz.qux; }"')
run_case "37-webfetch-fragment-preserved" 0 "$TRANSCRIPT"

# 38: Windows path with spaces + anchor citation passes.
TRANSCRIPT=$(build_transcript "38-windows-path-with-spaces-anchor" \
  "" \
  '[{"name":"Read","target":"C:\\path with spaces\\file.ts","result":"some content"}]' \
  '[VERIFIED:Read@C:\path with spaces\file.ts#L42-L58] is the relevant region.')
run_case "38-windows-path-with-spaces-anchor" 0 "$TRANSCRIPT"

# 39: Two tags in one sentence — both forms compose, no double-fire.
TRANSCRIPT=$(build_transcript "39-two-tags-one-sentence" \
  "" \
  '[{"name":"Read","target":"src/auth.ts","result":"function refresh() { return concurrent_unsafe_token; }"}]' \
  'The retry logic [VERIFIED:Read@src/auth.ts#L42-L58] returns the literal name [VERIFIED:Read@src/auth.ts] "function refresh() { return concurrent_unsafe_token; }".')
run_case "39-two-tags-one-sentence" 0 "$TRANSCRIPT"

# 40: Documentation-example placeholders — literal "path" / "url" / "target"
# in a tag are skipped as reserved-word placeholders. Without this, prose
# discussing the citation format would trigger Layer 5 since "path" is
# never a real tool target.
TRANSCRIPT=$(build_transcript "40-reserved-word-placeholder" \
  "" \
  '[]' \
  'The format is [VERIFIED:Read@path#L42-L58] for structural and [VERIFIED:WebFetch@url] "quote" for textual.')
run_case "40-reserved-word-placeholder" 0 "$TRANSCRIPT"

# 41: Windows backslash tool target + forward-slash citation should match.
# Real-world case: Read tool called with c:\Users\...\docker-compose.yml
# (backslashes), Claude cites with c:/Users/.../docker-compose.yml or just
# the basename. Path normalization in the match function handles both.
TRANSCRIPT=$(build_transcript "41-windows-backslash-tool-target" \
  "" \
  '[{"name":"Read","target":"c:\\Users\\Alessandro\\Desktop\\proj\\docker-compose.yml","result":"services:\n  ollama:\n    volumes:\n      - ollama-models:/root/.ollama"}]' \
  'See [VERIFIED:Read@docker-compose.yml#L57-L59] for the volume mount.')
run_case "41-windows-backslash-tool-target" 0 "$TRANSCRIPT"

# 42: Same with forward-slash citation matching backslash tool target.
TRANSCRIPT=$(build_transcript "42-mixed-separator-match" \
  "" \
  '[{"name":"Read","target":"c:\\Users\\Alessandro\\Desktop\\proj\\docker-compose.yml","result":"services:\n  ollama:\n    volumes:\n      - ollama-models:/root/.ollama"}]' \
  '[VERIFIED:Read@c:/Users/Alessandro/Desktop/proj/docker-compose.yml#L57-L59] is the relevant block.')
run_case "42-mixed-separator-match" 0 "$TRANSCRIPT"

echo
echo "============================================"
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  echo "Failures:"
  for n in "${FAIL_NAMES[@]}"; do echo "  - $n"; done
  exit 1
fi
echo "All cases passed."
