#!/bin/bash
# claim-audit.sh — Stop hook
# Layers: 1 (claim verification), 5 (quoted evidence), 5b (quote length floor),
#         6 (untagged-claim block), 6b (external entity tag rule), 10 (conclusion marking).
#
# Reads stdin (Stop event payload), reads transcript JSONL, scans the just-completed
# assistant text against pattern config, blocks turn-end when claims aren't backed.
#
# Exit 2  → hard block (Tier A). Stderr explains the failure.
# Exit 0 + JSON {decision: "block", reason: ...} → soft block (Tier B). Forces Claude to address.
# Exit 0 silent → no issues.
#
# Off switch: CLAUDE_SKIP_CLAIM_AUDIT=1

set -uo pipefail

PATTERNS_FILE="$HOME/.claude/hooks/claim-patterns.json"
ENTITIES_FILE="$HOME/.claude/hooks/external-entities.txt"
NEAR_MISS_LOG="$HOME/.claude/logs/claim-near-miss.jsonl"

input=$(cat)

if [ "${CLAUDE_SKIP_CLAIM_AUDIT:-}" = "1" ]; then
  exit 0
fi

# Anthropic's documented escape valve. Without this, a single Tier A block
# can spiral into an infinite continuation loop because Claude's response to
# the block re-triggers the same patterns. Per
# https://code.claude.com/docs/en/hooks-guide ("Stop hook runs forever"):
# parse stop_hook_active and exit 0 when Claude is already in a continuation
# triggered by a previous Stop hook block.
if [ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ]; then
  exit 0
fi

transcript_path=$(jq -r '.transcript_path // empty' <<<"$input")
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  exit 0
fi

if [ ! -f "$PATTERNS_FILE" ]; then
  exit 0
fi

mkdir -p "$(dirname "$NEAR_MISS_LOG")"

# ---------- Extract from transcript -----------------------------------------

last_assistant_text=$(jq -rs '
  . as $all
  | ([$all | to_entries[]
      | select(.value.type == "user" and (.value.message.content | type) == "string")]
      | last | .key // -1) as $idx
  | [$all[($idx + 1):][]
      | select(.type == "assistant" and (.message.content | type) == "array")
      | .message.content[]?
      | select(.type == "text") | .text]
  | join("\n\n")
' "$transcript_path" 2>/dev/null)

if [ -z "$last_assistant_text" ]; then
  exit 0
fi

# Two views of the assistant text are needed for different layers:
#
#   nonfenced_text — fenced ```...``` blocks blanked out; backticked spans
#     PRESERVED. Used for Layer 5 tag-and-quote extraction so that quotes
#     like "Parse the `stop_hook_active` field" stay intact for substring
#     matching against the raw tool result. Tags inside code fences (which
#     are documentation examples, not real claims) are still skipped.
#
#   scanned_text — fenced blocks blanked AND inline `...` spans replaced
#     with whitespace. Used for per-sentence Layer 1 / 6 / 6b / 10 checks
#     where a filename inside backticks should be treated as a code
#     identifier, not a content assertion target.
nonfenced_text=$(printf '%s' "$last_assistant_text" \
  | awk 'BEGIN{infence=0}
         /^```/ { infence = 1 - infence; print ""; next }
         { if (infence) print ""; else print }')

scanned_text=$(printf '%s' "$nonfenced_text" | sed -E 's/`[^`]*`/ /g')

if [ -z "$scanned_text" ] && [ -z "$nonfenced_text" ]; then
  exit 0
fi

user_last_prompt=$(jq -rs '
  [.[] | select(.type == "user" and (.message.content | type) == "string") | .message.content] | last // ""
' "$transcript_path" 2>/dev/null)

# Tool pairs as a JSON array: [{name, target, result_text}]
tool_pairs_json=$(jq -s '
  . as $all
  | [$all[]
      | select(.type == "assistant" and (.message.content | type) == "array")
      | .message.content[]?
      | select(.type == "tool_use")
      | {use_id: .id, name: .name, input: .input}] as $uses
  | [$all[]
      | select(.type == "user" and (.message.content | type) == "array")
      | .message.content[]?
      | select(.type == "tool_result")
      | {use_id: .tool_use_id,
         text: (.content
                  | if type == "string" then .
                    elif type == "array" then (map(.text // "") | join("\n"))
                    else "" end)}] as $results
  | [$uses[]
      | . as $u
      | ($results | map(select(.use_id == $u.use_id)) | .[0].text // "") as $rt
      | {name: $u.name,
         target: (
           if $u.name == "WebFetch" then ($u.input.url // "")
           elif $u.name == "Read" or $u.name == "Edit" or $u.name == "Write" then ($u.input.file_path // "")
           elif $u.name == "Grep" or $u.name == "Glob" then ($u.input.path // "")
           else (($u.input.url // $u.input.file_path // $u.input.path // "") | tostring)
           end),
         result_text: $rt}]
' "$transcript_path" 2>/dev/null)

if [ -z "$tool_pairs_json" ]; then
  tool_pairs_json="[]"
fi

# ---------- Helpers ----------------------------------------------------------

# Match function shared by target_fetched_result and target_was_tool_target.
# Covers:
#   - exact match
#   - URL/path prefix in either direction (https://foo.com matches a fetch of
#     https://foo.com/page, and vice versa)
#   - file-path basename vs full path in either direction (a tool call on
#     src/auth.ts matches an in-prose mention of auth.ts, and vice versa) —
#     this uses endswith with a leading separator to avoid false matches like
#     "auth.ts" matching "myauth.ts".
TARGET_MATCH_JQ='
  def norm($s): $s | gsub("\\\\"; "/");
  def matches($t; $tool):
    $tool != ""
    and (norm($t) as $nt | norm($tool) as $ntool |
      $ntool == $nt
      or ($nt | startswith($ntool))
      or ($ntool | startswith($nt))
      or ($nt | endswith("/" + $ntool))
      or ($ntool | endswith("/" + $nt))
    );
'

# Was a target fetched/read in this session? Echoes result_text on success, empty on failure.
target_fetched_result() {
  local target="$1"
  [ -z "$target" ] && return 1
  jq -r --arg t "$target" "$TARGET_MATCH_JQ"'
    [ .[] | . as $r | select(matches($t; $r.target)) ]
    | .[0].result_text // ""
  ' <<<"$tool_pairs_json"
}

# Was a target the input of any tool call this session, regardless of result?
# Used for the self-edit safelist: sentences naming a file Claude has been
# operating on are working notes, not research claims requiring a tag.
target_was_tool_target() {
  local target="$1"
  [ -z "$target" ] && return 1
  jq -e --arg t "$target" "$TARGET_MATCH_JQ"'
    any(.[]; matches($t; .target))
  ' <<<"$tool_pairs_json" >/dev/null
}

# Sentence split: each sentence on its own line.
sentences_of() {
  local text="$1"
  printf '%s' "$text" \
    | tr '\r' ' ' \
    | sed -E 's/([.!?])[[:space:]]+([A-Z[])/\1\n\2/g' \
    | sed '/^[[:space:]]*$/d'
}

# Word count of a string. Counts whitespace-separated tokens directly with awk —
# avoids the wc -l undercount that happens when the input has no trailing newline
# (which makes a 5-word string return 4).
word_count() {
  local s="$1"
  [ -z "$s" ] && { echo 0; return; }
  awk 'BEGIN{n=0} {n+=NF} END{print n+0}' <<<"$s"
}

# Append a near-miss entry to the journal.
log_near_miss() {
  local sentence="$1" reason="$2"
  jq -nc --arg s "$sentence" --arg r "$reason" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{ts:$ts, reason:$r, sentence:$s}' >>"$NEAR_MISS_LOG" 2>/dev/null || true
}

# ---------- Load patterns ---------------------------------------------------

# Strip trailing \r from jq output on Windows (Git Bash) so regexes match cleanly.
mapfile -t TIER_A_PATTERNS < <(jq -r '.tier_a_explicit_claim.patterns[]' "$PATTERNS_FILE" 2>/dev/null | tr -d '\r')
mapfile -t TIER_B_PATTERNS < <(jq -r '.tier_b_content_claim.patterns[]' "$PATTERNS_FILE" 2>/dev/null | tr -d '\r')
mapfile -t TIER_C_PATTERNS < <(jq -r '.tier_c_speculative.patterns[]' "$PATTERNS_FILE" 2>/dev/null | tr -d '\r')
mapfile -t CONCLUSION_PHRASES < <(jq -r '.conclusion_verbs.phrases[]' "$PATTERNS_FILE" 2>/dev/null | tr -d '\r')

VERIFIED_RX=$(jq -r '.verified_tag_pattern.verified' "$PATTERNS_FILE" | tr -d '\r')
ANCHOR_RX=$(jq -r '.verified_tag_pattern.verified_with_anchor' "$PATTERNS_FILE" | tr -d '\r')
INFERRED_RX=$(jq -r '.verified_tag_pattern.inferred' "$PATTERNS_FILE" | tr -d '\r')
ASSUMED_RX=$(jq -r '.verified_tag_pattern.assumed' "$PATTERNS_FILE" | tr -d '\r')
CONCLUSION_RX=$(jq -r '.verified_tag_pattern.conclusion' "$PATTERNS_FILE" | tr -d '\r')
OPINION_RX=$(jq -r '.verified_tag_pattern.opinion' "$PATTERNS_FILE" | tr -d '\r')
CONTENT_VERBS_RX=$(jq -r '.content_assertion_verbs.regex' "$PATTERNS_FILE" | tr -d '\r')
QUOTE_MIN_CHARS=$(jq -r '.quote_thresholds.min_chars // 30' "$PATTERNS_FILE" | tr -d '\r')
QUOTE_MIN_WORDS=$(jq -r '.quote_thresholds.min_words // 5' "$PATTERNS_FILE" | tr -d '\r')

sentence_has_tag() {
  local s="$1"
  echo "$s" | grep -qE "$VERIFIED_RX|$INFERRED_RX|$ASSUMED_RX|$CONCLUSION_RX|$OPINION_RX"
}

sentence_is_speculative() {
  local s="$1" pat
  for pat in "${TIER_C_PATTERNS[@]}"; do
    if echo "$s" | grep -qiE "$pat"; then return 0; fi
  done
  return 1
}

target_in_user_prompt() {
  local target="$1"
  [ -z "$user_last_prompt" ] && return 1
  echo "$user_last_prompt" | grep -qF "$target"
}

# ---------- Run checks ------------------------------------------------------

declare -a TIER_A_FINDINGS=()
declare -a TIER_B_FINDINGS=()

# --- Layer 1 Tier A: explicit verb + concrete URL/path ---
# No safelist on the user prompt — explicit verb implies claim.
# Scan only the code-stripped text so backticked examples don't false-fire.
for pat in "${TIER_A_PATTERNS[@]}"; do
  matches=$(echo "$scanned_text" | grep -oiE "$pat" 2>/dev/null || true)
  [ -z "$matches" ] && continue
  while IFS= read -r match; do
    [ -z "$match" ] && continue
    target=$(echo "$match" | grep -oE '(https?://[^[:space:]"'\''`)<>]+|[A-Za-z0-9_./-]+\.(md|ts|tsx|js|jsx|py|rs|go|rb|sh|json|yml|yaml|toml|html|css|scss|sql|txt))' | head -1)
    [ -z "$target" ] && continue
    result=$(target_fetched_result "$target")
    if [ -z "$result" ]; then
      TIER_A_FINDINGS+=("Layer 1 Tier A (explicit-claim, no fetch): claim about \"$target\" without a corresponding Read/WebFetch/Grep tool call. Match: $(echo "$match" | head -c 200)")
    fi
  done <<<"$matches"
done

# --- Layer 5 + 5b: [VERIFIED:Tool@target] "quote" check ---
# Tool name restricted to known whitelist (placeholder docs like [VERIFIED:tool@...] do not trigger).
# Targets containing '<' are also placeholders ([VERIFIED:WebFetch@<url>]) — skipped.
# Iterate nonfenced_text (NOT scanned_text) so quotes containing backticked
# tokens like `stop_hook_active` keep those backticks intact for substring
# matching against the raw tool result. Fenced blocks are still blanked, so
# documentation examples in code fences won't false-fire.
while IFS= read -r line; do
  [ -z "$line" ] && continue
  echo "$line" | grep -qE "$VERIFIED_RX" || continue

  # Extract every tag-with-following-quote on the line.
  remainder="$line"
  while [[ "$remainder" =~ \[VERIFIED:(Read|WebFetch|Grep|Glob|Bash|Edit|Write|MultiEdit|mcp__[A-Za-z0-9_]+__[A-Za-z0-9_]+)@([^]]+)\]([[:space:]]*\"([^\"]+)\")? ]]; do
    full_match="${BASH_REMATCH[0]}"
    tool="${BASH_REMATCH[1]}"
    target_with_anchor="${BASH_REMATCH[2]}"
    quote="${BASH_REMATCH[4]:-}"

    # Skip placeholder targets (documentation showing the contract format).
    if [[ "$target_with_anchor" == *"<"* ]]; then
      remainder="${remainder#*"$full_match"}"
      continue
    fi

    # Strip any trailing anchor (line N, section X, ...) from the target.
    target=$(echo "$target_with_anchor" | sed -E 's/ (line|lines|section|sections|paragraph|chapter)( [0-9A-Za-z-]+)+$//')
    has_anchor=0
    if [ "$target" != "$target_with_anchor" ]; then has_anchor=1; fi

    # Strip URL-fragment anchor (#L42 / #L42-L58 / #L42:L58) — only for
    # line-addressable filesystem tools. WebFetch URLs may legitimately
    # contain #L42 (e.g., GitHub blob links); stripping there would mangle
    # the citation target. Bash/Edit/Write also keep the fragment.
    case "$tool" in
      Read|Grep|Glob|MultiEdit)
        target_no_frag=$(echo "$target" | sed -E 's/#L[0-9]+([-:]L[0-9]+)?$//')
        if [ "$target_no_frag" != "$target" ]; then
          has_anchor=1
          target="$target_no_frag"
        fi
        ;;
    esac

    # Skip reserved-word placeholder targets — documentation examples that
    # use literal stand-ins like "path", "url", "target" instead of angle-
    # bracket placeholders. Without this, prose discussing the citation
    # format (e.g., in CLAUDE.md or in a response explaining the contract)
    # triggers Layer 5 because a target named "path" is never a real tool
    # target. Angle-bracket placeholders are still preferred for clarity.
    case "$target" in
      path|url|target|file|source|n|m|N|M|line|lines|tool|Tool)
        remainder="${remainder#*"$full_match"}"
        continue
        ;;
    esac

    # Bare-tag check: citation with no anchor AND no quote. Style issue, not
    # fabrication — Tier B (logged, no block, no retry).
    if [ -z "$quote" ] && [ "$has_anchor" -eq 0 ]; then
      TIER_B_FINDINGS+=("Layer 5 (bare tag): [VERIFIED:$tool@$target] has no anchor (#L42 / line 42) and no quote. Use the structural form (anchor like #L42-L58) or the textual form (\"literal quote\").")
    else
      # Tool-call existence. Tier A: a tag asserting a tool call that didn't
      # happen is a false claim about Claude's own actions.
      result=$(target_fetched_result "$target")
      if [ -z "$result" ]; then
        TIER_A_FINDINGS+=("Layer 5 (verified tag without tool call): [VERIFIED:$tool@$target] but no matching tool call in transcript.")
      elif [ -n "$quote" ]; then
        # Length / word floor (Layer 5b). Style issue — Tier B.
        qlen=${#quote}
        qwc=$(word_count "$quote")
        if [ "$has_anchor" -eq 0 ] && { [ "$qlen" -lt "$QUOTE_MIN_CHARS" ] || [ "$qwc" -lt "$QUOTE_MIN_WORDS" ]; }; then
          TIER_B_FINDINGS+=("Layer 5b (quote too short): \"$quote\" (${qlen} chars, ${qwc} words) under threshold (${QUOTE_MIN_CHARS} chars, ${QUOTE_MIN_WORDS} words). Either quote more, or add a position anchor like 'line N'.")
        elif ! grep -qF -- "$quote" <<<"$result"; then
          # Tier A: fabricated content — quote isn't a substring of the
          # actual tool result, so Claude invented text from a real fetch.
          TIER_A_FINDINGS+=("Layer 5 (fabricated quote): \"$quote\" not found in tool result for $target. The tool was called but the quoted snippet was invented.")
        fi
      fi
    fi

    # Advance past this match.
    remainder="${remainder#*"$full_match"}"
  done
done <<<"$nonfenced_text"

# --- Per-sentence checks: Layers 6, 6b, 10 ---
sentences=$(sentences_of "$scanned_text")

# --- Layer 6: sentence with URL/path AND content claim AND no tag → block ---
while IFS= read -r sent; do
  [ -z "$sent" ] && continue
  sentence_is_speculative "$sent" && continue
  sentence_has_tag "$sent" && continue
  target=$(echo "$sent" | grep -oE '(https?://[^[:space:]"'\''`)<>]+|[A-Za-z0-9_./-]+\.(md|ts|tsx|js|jsx|py|rs|go|rb|sh|json|yml|yaml|toml))' | head -1)
  [ -z "$target" ] && continue
  # Self-edit / self-fetch safelist: if Claude has Read/Edit/Write/WebFetched
  # this target this session, sentences about it are working notes (Claude is
  # operating on the file), not research claims. Layer 5 still catches
  # fabricated [VERIFIED:Tool@target] "..." quotes for these targets.
  if target_was_tool_target "$target"; then
    continue
  fi
  # Safelist: if URL/path appears verbatim in user prompt AND there's no content verb → echo, skip.
  if target_in_user_prompt "$target"; then
    if ! echo "$sent" | grep -qiE "$CONTENT_VERBS_RX"; then
      continue
    fi
  fi
  if echo "$sent" | grep -qiE "$CONTENT_VERBS_RX"; then
    # Tier B (logged, no block) — could be a real fabrication or innocuous
    # working-notes; can't tell without context. Logging means the user
    # can review the journal; blocking creates duplicate-response loops.
    TIER_B_FINDINGS+=("Layer 6 (untagged source claim): sentence names \"$target\" with a content claim and no [VERIFIED:...]/[INFERRED]/[ASSUMED] tag. Sentence: $(echo "$sent" | head -c 200)")
  fi
done <<<"$sentences"

# --- Layer 6b: sentence with external entity trigger AND no tag → warn ---
if [ -f "$ENTITIES_FILE" ]; then
  ENTITIES_RX=$(grep -vE '^[[:space:]]*(#|$)' "$ENTITIES_FILE" \
    | sed -E 's/[][\\^$.*+?(){}|]/\\&/g' \
    | paste -sd '|' -)
  if [ -n "$ENTITIES_RX" ]; then
    while IFS= read -r sent; do
      [ -z "$sent" ] && continue
      sentence_is_speculative "$sent" && continue
      sentence_has_tag "$sent" && continue
      if echo "$sent" | grep -qiwE "$ENTITIES_RX"; then
        if echo "$sent" | grep -qiE "$CONTENT_VERBS_RX"; then
          TIER_B_FINDINGS+=("Layer 6b (untagged external-entity claim): sentence references an external system without a [VERIFIED:...]/[INFERRED]/[ASSUMED] tag. Sentence: $(echo "$sent" | head -c 200)")
          log_near_miss "$sent" "layer6b-untagged-entity"
        fi
      fi
    done <<<"$sentences"
  fi
fi

# --- Layer 10: conclusion verb + 2+ verified tags → require [CONCLUSION from:...] ---
verified_count=$(echo "$scanned_text" | grep -oE "$VERIFIED_RX" | wc -l | tr -d ' ')
if [ "$verified_count" -ge 2 ]; then
  while IFS= read -r sent; do
    [ -z "$sent" ] && continue
    sentence_is_speculative "$sent" && continue
    has_concl_verb=0
    for pat in "${CONCLUSION_PHRASES[@]}"; do
      if echo "$sent" | grep -qiE "$pat"; then has_concl_verb=1; break; fi
    done
    [ "$has_concl_verb" -eq 0 ] && continue
    if echo "$sent" | grep -qE "$CONCLUSION_RX|$OPINION_RX"; then continue; fi
    TIER_B_FINDINGS+=("Layer 10 (unmarked conclusion): sentence draws a conclusion in a response with multiple [VERIFIED:...] tags but isn't itself marked [CONCLUSION from:...] or [OPINION based on:...]. Sentence: $(echo "$sent" | head -c 200)")
  done <<<"$sentences"
fi

# ---------- Emit decision ---------------------------------------------------

if [ ${#TIER_A_FINDINGS[@]} -gt 0 ]; then
  {
    echo "claim-audit BLOCK (Tier A): unverified claims detected. Address before stopping."
    echo
    for f in "${TIER_A_FINDINGS[@]}"; do echo "- $f"; done
    echo
    echo "Required fix: call the appropriate retrieval tool (Read/WebFetch/Grep) on the named target, then re-state the claim with a [VERIFIED:Tool@target] \"<quoted snippet>\" tag, or mark the claim [INFERRED] / [ASSUMED]."
  } >&2
  exit 2
fi

if [ ${#TIER_B_FINDINGS[@]} -gt 0 ]; then
  # Tier B is a WARN, not a block. Hard-blocking on warns recreates the same
  # infinite-loop hazard Tier A guards against — Claude's continuation almost
  # always re-mentions the entity that triggered the warn, retriggering the
  # block. Findings are already journaled inline per-layer above (see
  # log_near_miss calls in Layer 6b). Tier B issues surface for review via
  # ~/.claude/logs/claim-near-miss.jsonl, not by forcing continuation.
  for f in "${TIER_B_FINDINGS[@]}"; do
    log_near_miss "$f" "tier-b-warn-allowed-stop"
  done
fi

exit 0
