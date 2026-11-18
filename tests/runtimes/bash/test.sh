#!/usr/bin/env bash
# test.sh - Official Test Suite for LEXIS Bash Runtime
# Based on TESTS.md (T-001 to T-437). Retired IDs are not tested.
#
# A Bash argument is always text and the runtime is a single global instance,
# so the cases that need a typed argument (booleans, null, a float that is
# not a string) or several instances are reported as SKIP with the reason.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
FIXTURES_DIR="${ROOT_DIR}/tests/fixtures"
LOCALES_DIR="${FIXTURES_DIR}/locales"
source "${ROOT_DIR}/runtimes/bash/lexis.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Copy of the fixtures where names with "_" get a short alias: a locale such as
# cr_inside would be normalized to cr_INSIDE and not found on a case-sensitive
# file system.
STANDALONE="${WORK}/fixtures"
cp -r "$FIXTURES_DIR" "$STANDALONE"
for pair in crlf:cr crlf_trailing:ct cr_inside:ci duplicate_key:dk malformed_line:ml \
            empty_key:ek empty:em invalid_utf8:iv reserved_keys:rk test:ts; do
    [[ -f "${STANDALONE}/${pair%%:*}.lex" ]] && cp "${STANDALONE}/${pair%%:*}.lex" "${STANDALONE}/${pair##*:}.lex"
done

# --- Helpers -----------------------------------------------------------------

pass() { PASSED=$((PASSED + 1)); }

fail() {
    FAILED=$((FAILED + 1))
    printf '%bFAIL%b %s\n  expected: %q\n  actual:   %q\n' "$RED" "$NC" "$1" "$2" "$3"
}

skip() {
    SKIPPED=$((SKIPPED + 1))
    printf '%bSKIP%b %s - %s\n' "$YELLOW" "$NC" "$1" "$2"
}

section() { printf '\n%s\n' "$1"; }

assert_eq() {
    local id="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then pass; else fail "$id" "$expected" "$actual"; fi
}

# Run a command in the current shell (the lazy cache is kept) and capture
# its stdout, without losing trailing newlines, in OUT and its code in RC.
# assert_eq "ID" "expected" "$(lexis_get key ...)" is the usual form; run + $RC
# is used where a return code or the cache state is what is being checked.
run() {
    local file="${WORK}/out"
    "$@" >"$file" 2>/dev/null
    RC=$?
    OUT="$(cat "$file"; printf x)"
    OUT="${OUT%x}"
}

# load DIR [LOCALE] [FALLBACK] [NAME]: lexis_load without output
load() { lexis_load "$@" >/dev/null 2>&1; }

if ! load "$STANDALONE" ts; then
    echo "Cannot load tests/fixtures/test.lex" >&2
    exit 2
fi

# --- Parsing: T-001 to T-026 --------------------------------------------------
section "Parsing (T-001 to T-026)"
assert_eq "T-001" "Hello World" "$(lexis_get simple)"
assert_eq "T-002" "" "$(lexis_get empty_value)"
assert_eq "T-003" "Value with spaces around key" "$(lexis_get key_trimmed)"
assert_eq "T-004" "uppercase key test" "$(lexis_get UPPERCASE_KEY)"
assert_eq "T-005" "mixed case key test" "$(lexis_get mixed_Case_Key)"
assert_eq "T-006" "#this value starts with hash" "$(lexis_get value_with_hash)"
assert_eq "T-007" "value :: contains :: separators" "$(lexis_get value_with_separator)"
assert_eq "T-008" "leading spaces are trimmed" "$(lexis_get value_leading_spaces)"
assert_eq "T-009" "trailing spaces are preserved   " "$(lexis_get value_trailing_spaces)"
assert_eq "T-010" "Hello 👋 World" "$(lexis_get value_unicode)"
assert_eq "T-011" "Héllo Wörld — ñoño" "$(lexis_get value_utf8)"

# T-012: CRLF line endings (the fixture must really use CRLF; git can normalize it)
assert_eq "T-012 (fixture has CRLF)" "yes" "$([[ "$(<"${FIXTURES_DIR}/crlf.lex")" == *$'\r'* ]] && echo yes || echo no)"
load "$STANDALONE" cr
assert_eq "T-012" "value without trailing carriage return" "$(lexis_get crlf_entry)"
load "$STANDALONE" ts

# T-013 and T-015: indented comments and whitespace-only lines are skipped
mkdir -p "${WORK}/t013"
printf '  # indented comment\n   \n\t\nk::v\n' >"${WORK}/t013/en.lex"
load "${WORK}/t013" en
assert_eq "T-013/T-015 (only the entry is loaded)" "k" "$(lexis_keys)"
load "$STANDALONE" ts

assert_eq "T-014" "value_space" "$(lexis_get key_space)"
assert_eq "T-016" "Family: 👨‍👩‍👧‍👦" "$(lexis_get emoji_sequence)"
assert_eq "T-017" "correct string$(printf '%10000s' '')" "$(lexis_get huge_spaces)"

load "$FIXTURES_DIR" bom
assert_eq "T-018" "first_value" "$(lexis_get first_key)"
assert_eq "T-019" "last_value" "$(lexis_get last_key)"
assert_eq "T-020" $'prefix_\xEF\xBB\xBF_suffix' "$(lexis_get mid_bom)"
load "$STANDALONE" ts

lexis_has comment; assert_eq "T-021 (has comment)" "1" "$?"
lexis_has hidden; assert_eq "T-022 (has hidden)" "1" "$?"
lexis_has '#hidden'; assert_eq "T-022 (has #hidden)" "1" "$?"
assert_eq "T-023" ":tail" "$(lexis_get colon_run)"
assert_eq "T-024" "Home page" "$(lexis_get "url:home")"

assert_eq "T-025 (fixture has CRLF)" "yes" "$([[ "$(<"${FIXTURES_DIR}/crlf_trailing.lex")" == *$'\r'* ]] && echo yes || echo no)"
load "$STANDALONE" ct
assert_eq "T-025" "value  " "$(lexis_get crlf_trailing)"
load "$STANDALONE" ci
assert_eq "T-026" $'a\rb' "$(lexis_get cr_inside)"
load "$STANDALONE" ts

# --- Escape sequences: T-101 to T-114 ------------------------------------------
section "Escape sequences (T-101 to T-114)"
assert_eq "T-101" $'Line 1\nLine 2' "$(lexis_get escape_newline)"
assert_eq "T-102" $'Col1\tCol2' "$(lexis_get escape_tab)"
assert_eq "T-103" 'C:\Program Files\Lexis' "$(lexis_get escape_backslash)"
assert_eq "T-104" 'She said "hello"' "$(lexis_get escape_quote)"
assert_eq "T-105" $'before\rafter' "$(lexis_get escape_carriage_return)"
assert_eq "T-106" $'before\bafter' "$(lexis_get escape_backspace)"
assert_eq "T-107" $'before\vafter' "$(lexis_get escape_vertical_tab)"
assert_eq "T-108" 'unknown \q escape passes through' "$(lexis_get escape_unknown)"
assert_eq "T-109" 'trailing backslash is literal\' "$(lexis_get escape_trailing_backslash)"
assert_eq "T-110" $'Name:\tAlice\nScore:\t99' "$(lexis_get escape_combined Alice 99)"
assert_eq "T-111" 'before\0after' "$(lexis_get escape_null)"
assert_eq "T-112" 'literal \n character' "$(lexis_get escape_escaped_n)"
assert_eq "T-113" 'Hello a\nb' "$(lexis_get passthrough_arg 'a\nb')"
assert_eq "T-114" '\x' "$(lexis_get escape_then_percent x)"

# --- Placeholders: T-201 to T-286 ----------------------------------------------
section "Placeholders (T-201 to T-286)"
assert_eq "T-201" 'Hello Alice' "$(lexis_get placeholder_string 'Alice')"
assert_eq "T-202" 'You have 3 messages' "$(lexis_get placeholder_integer '3')"
assert_eq "T-203" 'Rating: 3.75' "$(lexis_get placeholder_float '3.75')"
assert_eq "T-204" 'Hex value: ff' "$(lexis_get placeholder_hex '255')"
assert_eq "T-205" 'Octal value: 10' "$(lexis_get placeholder_octal '8')"
assert_eq "T-206" 'Char: A' "$(lexis_get placeholder_char '65')"
assert_eq "T-207" '100% completed' "$(lexis_get placeholder_percent)"
assert_eq "T-208" 'User Alice has 10 points and rating 4.50' "$(lexis_get placeholder_multiple 'Alice' '10' '4.5')"
assert_eq "T-211" '-0042' "$(lexis_get pad_neg_int '-42')"
assert_eq "T-212" '00003.14' "$(lexis_get float_prec '3.14159')"
assert_eq "T-213" '-2a' "$(lexis_get neg_hex '-42')"
assert_eq "T-215" 'Value: %q' "$(lexis_get invalid_specifier 'test')"
assert_eq "T-217" 'Rating: 1000000000000000000' "$(lexis_get placeholder_float '1000000000000000000')"
assert_eq "T-218" 'You have 9223372036854775807 messages' "$(lexis_get placeholder_integer '9223372036854775807')"
assert_eq "T-219" '%%s Alice' "$(lexis_get adjacent_percent 'Alice')"
assert_eq "T-220" 'Hello Alice' "$(lexis_get one_placeholder 'Alice' 'extra_arg')"
assert_eq "T-221" '3.1' "$(lexis_get float_default_prec '3.1')"
assert_eq "T-222" '3' "$(lexis_get float_zero_prec '2.5')"
assert_eq "T-223a" '   Hi' "$(lexis_get string_width_right 'Hi')"
assert_eq "T-223b" 'Hi   ' "$(lexis_get string_width_left 'Hi')"
assert_eq "T-224" '   Hi' "$(lexis_get string_zero_pad 'Hi')"
assert_eq "T-225" 'Hello Alice, code 10' "$(lexis_get pos_test 'Alice' '10')"
assert_eq "T-226" 'Hello %s%d' "$(lexis_get placeholder_string '%s%d')"
assert_eq "T-227" 'Value ends with %' "$(lexis_get trailing_percent)"
assert_eq "T-229" 'Char: €' "$(lexis_get placeholder_char '8364')"
assert_eq "T-230" 'Count: 42' "$(lexis_get i_spec '42')"
assert_eq "T-231" '%u %X %e %g %b %n %p' "$(lexis_get unknown_specs 'x')"
assert_eq "T-232" 'Hello %1$s' "$(lexis_get positional_attempt_2 'Alice')"
assert_eq "T-233" '    ñ' "$(lexis_get width_codepoint 'ñ')"
assert_eq "T-234" '42' "$(lexis_get numeric_string '42')"
assert_eq "T-236" '-3' "$(lexis_get float_zero_prec '-2.5')"
assert_eq "T-237" '1.00' "$(lexis_get float_two_prec '1.005')"
skip T-240 "a float argument is plain text in Bash"
assert_eq "T-242" '%+d|% d|%#x' "$(lexis_get lit_flags '5' '5' '255')"
assert_eq "T-243" '%ld|%lld|%hd|%zu' "$(lexis_get lit_length '5')"
assert_eq "T-244" '%*d|%.*f' "$(lexis_get lit_star '5' '2' '3.14')"
assert_eq "T-245" '%.3s|%.2d' "$(lexis_get lit_prec_s 'abcdef' '5')"
assert_eq "T-246" '%.f' "$(lexis_get lit_prec_empty '3.5')"
assert_eq "T-247" '%0-5d' "$(lexis_get lit_flag_order '5')"
assert_eq "T-248" '50% discount' "$(lexis_get lit_percent_space)"
assert_eq "T-249a" 'Width cut off %5' "$(lexis_get lit_cut_off_width)"
assert_eq "T-249b" 'Flags cut off %-0' "$(lexis_get lit_cut_off_flags)"
assert_eq "T-250" '%qx' "$(lexis_get lit_then_real 'x')"
assert_eq "T-251" "$(printf '%1023s1' '')" "$(lexis_get width_max '1')"
assert_eq "T-252" '%1025d' "$(lexis_get width_over '1')"
assert_eq "T-253" '%99999999999999999999d' "$(lexis_get width_overflow '1')"
assert_eq "T-254" '0.100000000000000' "$(lexis_get prec_max '0.1')"
assert_eq "T-255a" '%.16f' "$(lexis_get prec_over '0.1')"
assert_eq "T-255b" '%.99999999999999999999f' "$(lexis_get prec_overflow '1')"
assert_eq "T-256" '42   |' "$(lexis_get pad_left_zero '42')"
assert_eq "T-257" '  A|' "$(lexis_get pad_char_zero '65')"
assert_eq "T-258" '-0003.14' "$(lexis_get pad_neg_float '-3.14159')"
assert_eq "T-259" '-002a' "$(lexis_get pad_neg_hex '-42')"
assert_eq "T-260" '3.14    |' "$(lexis_get pad_left_float '3.14159')"
assert_eq "T-261" '12345' "$(lexis_get pad_no_truncate '12345')"
assert_eq "T-262" '    👋|' "$(lexis_get width_emoji '👋')"
assert_eq "T-263" '   é|' "$(lexis_get width_combining 'é')"
assert_eq "T-264a" '-42' "$(lexis_get s_int '-42')"
assert_eq "T-264b" '-9223372036854775808' "$(lexis_get s_int_min '-9223372036854775808')"
assert_eq "T-265a" '3.14' "$(lexis_get s_float '3.14')"
skip T-265b "a float argument is plain text in Bash"
skip T-265c "a float argument is plain text in Bash"
assert_eq "T-270" '-9223372036854775808' "$(lexis_get d_int_min '-9223372036854775808')"
assert_eq "T-273a" '0' "$(lexis_get hex_zero '0')"
assert_eq "T-273b" '-8000000000000000' "$(lexis_get hex_int_min '-9223372036854775808')"
assert_eq "T-273c" '-10' "$(lexis_get oct_neg '-8')"
assert_eq "T-276a" '👋' "$(lexis_get char_astral '128075')"
assert_eq "T-276b" '􏿿' "$(lexis_get char_max '1114111')"
assert_eq "T-276c" 'A' "$(lexis_get char_numstr '65')"
assert_eq "T-278a" '3' "$(lexis_get f_def_int_valued '3.0')"
assert_eq "T-278b" '100' "$(lexis_get f_def_hundred '100.0')"
assert_eq "T-278c" '0.3' "$(lexis_get f_def_sum '0.30000000000000004')"
assert_eq "T-278d" '0.333333' "$(lexis_get f_def_third '0.3333333333333333')"
assert_eq "T-278e" '1.234568' "$(lexis_get f_def_round '1.23456789')"
assert_eq "T-278f" '1234567.891' "$(lexis_get f_def_big '1234567.891')"
assert_eq "T-278g" '3' "$(lexis_get f_def_intarg '3')"
assert_eq "T-279a" '0' "$(lexis_get f_def_tiny '0.0000004')"
assert_eq "T-279b" '0' "$(lexis_get f_def_tiny_neg '-0.0000004')"
assert_eq "T-279c" '0' "$(lexis_get f_def_negzero '-0.0')"
assert_eq "T-279d" '0.000001' "$(lexis_get f_def_edge '0.000001')"
assert_eq "T-280a" '0.0000004' "$(lexis_get f_prec_small '0.0000004')"
assert_eq "T-280b" '3.00' "$(lexis_get f_prec_pad '3.0')"
assert_eq "T-280c" '1.00' "$(lexis_get f_prec_intarg '1')"
assert_eq "T-280d" '3.10' "$(lexis_get f_prec_one '3.1')"
assert_eq "T-281a" '1' "$(lexis_get f_tie_half '0.5')"
assert_eq "T-281b" '2' "$(lexis_get f_tie_onehalf '1.5')"
assert_eq "T-282" '0.00' "$(lexis_get f_neg_tiny '-0.001')"
assert_eq "T-283" '3.14' "$(lexis_get f_str '3.14')"
assert_eq "T-284" '9000000000000000000.00' "$(lexis_get f_big_prec '9000000000000000000')"
assert_eq "T-286" '%s' "$(lexis_get pct_pct_s)"

# --- Placeholders that must fail with LexFormatError (code 5) --------------------
section "Placeholders that raise LexFormatError"
skip T-209 "a boolean is plain text in Bash"
skip T-210 "there is no null in Bash"
run lexis_get two_placeholders 'only_one_arg'; assert_eq "T-214 (return code)" "5" "$RC"
run lexis_get placeholder_float 'NaN'; assert_eq "T-216a (return code)" "5" "$RC"
run lexis_get placeholder_float 'Infinity'; assert_eq "T-216b (return code)" "5" "$RC"
run lexis_get placeholder_integer 'abc'; assert_eq "T-228 (return code)" "5" "$RC"
run lexis_get placeholder_float '-Infinity'; assert_eq "T-235 (return code)" "5" "$RC"
run lexis_get placeholder_float '9223372036854776000'; assert_eq "T-238a (return code)" "5" "$RC"
run lexis_get placeholder_float '10000000000000000000'; assert_eq "T-238b (return code)" "5" "$RC"
run lexis_get placeholder_float '1000000000000000000000'; assert_eq "T-238c (return code)" "5" "$RC"
run lexis_get placeholder_char '1114112'; assert_eq "T-239 (return code)" "5" "$RC"
run lexis_get placeholder_integer '3.7'; assert_eq "T-241 (return code)" "5" "$RC"
skip T-266 "a boolean is plain text in Bash"
skip T-267 "there is no null in Bash"
run lexis_get d_str_float '4.0'; assert_eq "T-269a (return code)" "5" "$RC"
run lexis_get d_str_plus '+5'; assert_eq "T-269b (return code)" "5" "$RC"
run lexis_get d_str_space ' 5'; assert_eq "T-269c (return code)" "5" "$RC"
run lexis_get d_str_empty ''; assert_eq "T-269d (return code)" "5" "$RC"
run lexis_get d_float_big '10000000000000000000'; assert_eq "T-271a (return code)" "5" "$RC"
run lexis_get d_str_big '9223372036854775808'; assert_eq "T-271b (return code)" "5" "$RC"
run lexis_get d_nan 'NaN'; assert_eq "T-272a (return code)" "5" "$RC"
run lexis_get d_inf 'Infinity'; assert_eq "T-272b (return code)" "5" "$RC"
run lexis_get hex_frac '3.5'; assert_eq "T-274a (return code)" "5" "$RC"
run lexis_get hex_bad_str 'zz'; assert_eq "T-274b (return code)" "5" "$RC"
run lexis_get char_zero '0'; assert_eq "T-275a (return code)" "5" "$RC"
run lexis_get char_neg '-1'; assert_eq "T-275b (return code)" "5" "$RC"
run lexis_get char_surr_lo '55296'; assert_eq "T-275c (return code)" "5" "$RC"
run lexis_get char_surr_hi '57343'; assert_eq "T-275d (return code)" "5" "$RC"
run lexis_get char_str 'A'; assert_eq "T-277 (return code)" "5" "$RC"
run lexis_get f_str_exp '1e5'; assert_eq "T-283a (return code)" "5" "$RC"
run lexis_get f_str_bad 'abc'; assert_eq "T-283b (return code)" "5" "$RC"
skip T-285 "a boolean is plain text in Bash"
run lexis_get s_bad_utf8 $'\xC3('; assert_eq "T-268 (return code)" "5" "$RC"

# --- Edge cases: T-303 (T-301 and T-302 are retired) -----------------------------
section "Edge cases (T-303)"
assert_eq "T-303" "key:::value with triple colon" "$(lexis_get triple_colon)"

# --- Conformance: T-401 to T-437 -------------------------------------------------
section "Conformance (T-401 to T-437)"
run lexis_get nonexistent_key; assert_eq "T-401 (return code)" "3" "$RC"
run lexis_get_or_default nonexistent_key fallback;          assert_eq T-402 "fallback" "$OUT"
run lexis_get_or_default nonexistent_key "Hello %s" Alice;  assert_eq T-403 "Hello Alice" "$OUT"

load "$FIXTURES_DIR" fr
assert_eq "T-404 (locale)" "en" "$_LEXIS_LOCALE"
assert_eq "T-404" "Welcome Alice" "$(lexis_get welcome Alice)"
load "$FIXTURES_DIR" fr pt
assert_eq "T-405 (fallback)" "pt" "$_LEXIS_FALLBACK_LOCALE"
assert_eq "T-405 (locale)" "pt" "$_LEXIS_LOCALE"
assert_eq "T-405" "Bem-vindo Alice" "$(lexis_get welcome Alice)"

load "$FIXTURES_DIR" es
assert_eq "T-406" "Bienvenido Alice" "$(lexis_get welcome Alice)"
lexis_reload en >/dev/null 2>&1
assert_eq "T-406" "Welcome Alice" "$(lexis_get welcome Alice)"

load "$FIXTURES_DIR" fr en
lexis_reload fr es >/dev/null 2>&1
assert_eq "T-407 (fallback)" "es" "$_LEXIS_FALLBACK_LOCALE"
assert_eq "T-407 (locale)" "es" "$_LEXIS_LOCALE"
load "$FIXTURES_DIR" en en
lexis_reload "" es >/dev/null 2>&1
assert_eq "T-407 (fallback, spec wording)" "es" "$_LEXIS_FALLBACK_LOCALE"

# T-408: only es.lex exists, so "xyz" and the fallback "en" both miss
mkdir -p "${WORK}/t408"; printf 'welcome::Hola\n' >"${WORK}/t408/es.lex"
load "${WORK}/t408" es
before="$(lexis_info)"
run lexis_reload xyz; assert_eq "T-408 (return code)" "2" "$RC"
assert_eq "T-408 (state unchanged)" "$before" "$(lexis_info)"
assert_eq "T-408" "Hola" "$(lexis_get welcome)"

run lexis_load "$STANDALONE" dk; assert_eq "T-410 (return code)" "4" "$RC"
run lexis_load "$STANDALONE" ml; assert_eq "T-411 (return code)" "4" "$RC"
run lexis_load "$STANDALONE" ek; assert_eq "T-412 (return code)" "4" "$RC"
run lexis_load "${WORK}/nonexistent/path" en; assert_eq "T-413 (return code)" "2" "$RC"

# T-414 (white-box, optional): _lexis_unescape runs once per key
eval "$(declare -f _lexis_unescape | sed '1s/^_lexis_unescape/_lexis_unescape_orig/')"
UNESCAPE_CALLS=0
_lexis_unescape() { UNESCAPE_CALLS=$((UNESCAPE_CALLS + 1)); _lexis_unescape_orig "$@"; }
load "$STANDALONE" ts
run lexis_get escape_newline; first="$OUT"
run lexis_get escape_newline
assert_eq "T-414 (same output)" "$first" "$OUT"
assert_eq "T-414 (unescaped once)" "1" "$UNESCAPE_CALLS"
eval "$(declare -f _lexis_unescape_orig | sed '1s/^_lexis_unescape_orig/_lexis_unescape/')"

# T-415: cache eviction on reload
mkdir -p "${WORK}/t415"
printf 'k1::value from locale A\n' >"${WORK}/t415/aa.lex"
printf 'k2::value from locale B\n' >"${WORK}/t415/bb.lex"
load "${WORK}/t415" aa
assert_eq "T-415" "value from locale A" "$(lexis_get k1)"
lexis_reload bb >/dev/null 2>&1
run lexis_get k1; assert_eq "T-415 (return code)" "3" "$RC"
assert_eq "T-415" "value from locale B" "$(lexis_get k2)"

# T-416: a failed reload leaves the loaded state untouched
cp "${STANDALONE}/ml.lex" "${WORK}/t415/xx.lex"
load "${WORK}/t415" aa
before="$(lexis_info)"
run lexis_reload xx; assert_eq "T-416 (return code)" "4" "$RC"
assert_eq "T-416 (state unchanged)" "$before" "$(lexis_info)"
assert_eq "T-416" "value from locale A" "$(lexis_get k1)"

load "$STANDALONE" ts
assert_eq "T-417" "value1" "$(lexis_get KEY)"
assert_eq "T-417" "value2" "$(lexis_get key)"

for code in es-ES es_ES ES; do
    load "$FIXTURES_DIR" "$code"
    assert_eq "T-418 ($code)" "es" "$_LEXIS_LOCALE"
done

run lexis_load "$STANDALONE" iv; assert_eq "T-419 (return code)" "4" "$RC"

load "$STANDALONE" rk
assert_eq "T-420" "mapped toString value" "$(lexis_get toString)"
assert_eq "T-420" "mapped valueOf value" "$(lexis_get valueOf)"
assert_eq "T-420" "mapped __proto__ value" "$(lexis_get __proto__)"
assert_eq "T-420" "mapped constructor value" "$(lexis_get constructor)"

skip T-421 "the Bash runtime is a single global instance"

load "$STANDALONE" em
assert_eq "T-422 (empty file)" "0" "$(lexis_len)"
mkdir -p "${WORK}/t422"; printf '# only\n\n  # comments\n' >"${WORK}/t422/en.lex"
load "${WORK}/t422" en
assert_eq "T-422 (comment-only file)" "0" "$(lexis_len)"

for code in '../secret' 'es/..' 'es\x' 'es.x' 'es_VE_X' 'es VE'; do
    run lexis_load "$LOCALES_DIR" "$code"; assert_eq "T-423/T-424 [$code] (return code)" "2" "$RC"
done
skip "T-424 [empty locale]" "an empty argument means 'not given' in Bash"
run lexis_load "$LOCALES_DIR" es "../x"; assert_eq "T-425 (return code)" "2" "$RC"
run lexis_load "$LOCALES_DIR" es en "../main"; assert_eq "T-425 (return code)" "2" "$RC"
run lexis_load "$LOCALES_DIR" es en "a/b"; assert_eq "T-425 (return code)" "2" "$RC"
skip "T-425 [empty name]" "an empty argument means 'not given' in Bash"

for code in es-VE es_ve ES_VE; do
    load "$LOCALES_DIR" "$code"
    assert_eq "T-426 ($code, welcome)" "es_VE" "$(lexis_get welcome)"
    assert_eq "T-426 ($code, locale)" "es_VE" "$_LEXIS_LOCALE"
done
load "$LOCALES_DIR" es_VE
assert_eq "T-427" "es_VE" "$(lexis_get welcome)"; assert_eq "T-427 (locale)" "es_VE" "$_LEXIS_LOCALE"
load "$LOCALES_DIR" es_AR
assert_eq "T-428" "es" "$(lexis_get welcome)";    assert_eq "T-428 (locale)" "es" "$_LEXIS_LOCALE"
load "$LOCALES_DIR" pt
assert_eq "T-429" "pt (main)" "$(lexis_get welcome)"
load "$LOCALES_DIR" pt en custom
assert_eq "T-430" "pt (custom)" "$(lexis_get welcome)"; assert_eq "T-430 (name)" "custom" "$_LEXIS_NAME"
load "$LOCALES_DIR" de
assert_eq "T-431" "de (file)" "$(lexis_get welcome)"
load "$LOCALES_DIR" fr_CA
assert_eq "T-432" "fr_CA (dir)" "$(lexis_get welcome)"
load "$LOCALES_DIR" ja es_VE
assert_eq "T-433" "es_VE" "$(lexis_get welcome)"; assert_eq "T-433 (locale)" "es_VE" "$_LEXIS_LOCALE"
load "$LOCALES_DIR" ja
assert_eq "T-434" "en" "$(lexis_get welcome)";    assert_eq "T-434 (locale)" "en" "$_LEXIS_LOCALE"

load "$LOCALES_DIR" pt en custom
lexis_reload pt >/dev/null 2>&1
assert_eq "T-435" "pt (custom)" "$(lexis_get welcome)"
run lexis_reload "../x"; assert_eq "T-435 (return code)" "2" "$RC"
assert_eq "T-435" "pt (custom)" "$(lexis_get welcome)"
assert_eq "T-435 (name)" "custom" "$_LEXIS_NAME"

load "$LOCALES_DIR" es_VE
lexis_reload "" en >/dev/null 2>&1
assert_eq "T-436" "es_VE" "$(lexis_get welcome)"; assert_eq "T-436 (locale)" "es_VE" "$_LEXIS_LOCALE"

# T-437 (optional): locale auto-detection from LANG
for pair in 'es_VE.UTF-8:es_VE' 'es_VE@euro:es_VE' 'C.UTF-8:en' 'POSIX:en' ':en' 'zh_Hans_CN.UTF-8:en'; do
    LANG="${pair%%:*}" lexis_load "$LOCALES_DIR" >/dev/null 2>&1
    assert_eq "T-437 [${pair%%:*}] (locale)" "${pair##*:}" "$_LEXIS_LOCALE"
    assert_eq "T-437 [${pair%%:*}]" "${pair##*:}" "$(lexis_get welcome)"
done

# --- Additional tests: public API that TESTS.md does not number -------------------
section "Additional tests"
load "$STANDALONE" ts
lexis_has simple;      assert_eq "has (existing key)" "0" "$?"
lexis_has nonexistent; assert_eq "has (missing key)" "1" "$?"
assert_eq "len equals the number of keys" "$(lexis_keys | wc -l | tr -d ' ')" "$(lexis_len)"
[[ "$(lexis_keys)" == *simple* ]]; assert_eq "keys lists a known key" "0" "$?"
info="$(lexis_info)"
for field in "locale='ts'" "fallback_locale='en'" "lang_dir='" "name='main'" "filepath='" "keys=" "cached_keys="; do
    [[ "$info" == *"$field"* ]]; assert_eq "info has $field" "0" "$?"
done
run lexis_get simple
cached_before="${#_LEXIS_CACHE_TRANSLATIONS[@]}"
lexis_clear
assert_eq "clear empties the cache" "0" "${#_LEXIS_CACHE_TRANSLATIONS[@]}"
assert_eq "clear keeps the translations" "Hello World" "$(lexis_get simple)"
(( cached_before >= 1 )); assert_eq "cache was filled before clear" "0" "$?"
run lexis_get_or_default zz "%d" abc; assert_eq "get_or_default fails (5) on a bad argument (return code)" "5" "$RC"
run lexis_get_or_default simple "unused"; assert_eq "get_or_default (existing key)" "Hello World" "$OUT"

# --- Summary --------------------------------------------------------------------
printf '\n%bPassed: %d%b  %bFailed: %d%b  %bSkipped: %d%b\n' \
    "$GREEN" "$PASSED" "$NC" "$RED" "$FAILED" "$NC" "$YELLOW" "$SKIPPED" "$NC"
(( FAILED == 0 ))