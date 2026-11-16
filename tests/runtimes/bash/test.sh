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
run() {
    local file="${WORK}/out"
    "$@" >"$file" 2>/dev/null
    RC=$?
    OUT="$(cat "$file"; printf x)"
    OUT="${OUT%x}"
}

# t_get ID KEY EXPECTED [ARGS...]: lexis_get succeeds and prints EXPECTED
t_get() {
    local id="$1" key="$2" expected="$3"
    shift 3
    run lexis_get "$key" "$@"
    if (( RC == 0 )); then assert_eq "$id" "$expected" "$OUT"; else fail "$id" "$expected" "(error code $RC)"; fi
}

# t_err ID CODE KEY [ARGS...]: lexis_get fails with CODE
t_err() {
    local id="$1" code="$2"
    shift 2
    run lexis_get "$@"
    assert_eq "$id (return code)" "$code" "$RC"
}

# t_rc ID CODE COMMAND...: the command returns CODE
t_rc() {
    local id="$1" code="$2"
    shift 2
    run "$@"
    assert_eq "$id (return code)" "$code" "$RC"
}

# load DIR [LOCALE] [FALLBACK] [NAME]: lexis_load without output
load() { lexis_load "$@" >/dev/null 2>&1; }

if ! load "$STANDALONE" ts; then
    echo "Cannot load tests/fixtures/test.lex" >&2
    exit 2
fi

# --- Parsing: T-001 to T-026 --------------------------------------------------
section "Parsing (T-001 to T-026)"
t_get T-001 simple "Hello World"
t_get T-002 empty_value ""
t_get T-003 key_trimmed "Value with spaces around key"
t_get T-004 UPPERCASE_KEY "uppercase key test"
t_get T-005 mixed_Case_Key "mixed case key test"
t_get T-006 value_with_hash "#this value starts with hash"
t_get T-007 value_with_separator "value :: contains :: separators"
t_get T-008 value_leading_spaces "leading spaces are trimmed"
t_get T-009 value_trailing_spaces "trailing spaces are preserved   "
t_get T-010 value_unicode "Hello 👋 World"
t_get T-011 value_utf8 "Héllo Wörld — ñoño"

# T-012: CRLF line endings (the fixture must really use CRLF; git can normalize it)
assert_eq "T-012 (fixture has CRLF)" "yes" "$([[ "$(<"${FIXTURES_DIR}/crlf.lex")" == *$'\r'* ]] && echo yes || echo no)"
load "$STANDALONE" cr
t_get T-012 crlf_entry "value without trailing carriage return"
load "$STANDALONE" ts

# T-013 and T-015: indented comments and whitespace-only lines are skipped
mkdir -p "${WORK}/t013"
printf '  # indented comment\n   \n\t\nk::v\n' >"${WORK}/t013/en.lex"
load "${WORK}/t013" en
assert_eq "T-013/T-015 (only the entry is loaded)" "k" "$(lexis_keys)"
load "$STANDALONE" ts

t_get T-014 key_space "value_space"
t_get T-016 emoji_sequence "Family: 👨‍👩‍👧‍👦"
t_get T-017 huge_spaces "correct string$(printf '%10000s' '')"

load "$FIXTURES_DIR" bom
t_get T-018 first_key "first_value"
t_get T-019 last_key "last_value"
t_get T-020 mid_bom $'prefix_\xEF\xBB\xBF_suffix'
load "$STANDALONE" ts

lexis_has comment; assert_eq "T-021 (has comment)" "1" "$?"
lexis_has hidden; assert_eq "T-022 (has hidden)" "1" "$?"
lexis_has '#hidden'; assert_eq "T-022 (has #hidden)" "1" "$?"
t_get T-023 colon_run ":tail"
t_get T-024 "url:home" "Home page"

assert_eq "T-025 (fixture has CRLF)" "yes" "$([[ "$(<"${FIXTURES_DIR}/crlf_trailing.lex")" == *$'\r'* ]] && echo yes || echo no)"
load "$STANDALONE" ct
t_get T-025 crlf_trailing "value  "
load "$STANDALONE" ci
t_get T-026 cr_inside $'a\rb'
load "$STANDALONE" ts

# --- Escape sequences: T-101 to T-114 ------------------------------------------
section "Escape sequences (T-101 to T-114)"
t_get T-101 escape_newline $'Line 1\nLine 2'
t_get T-102 escape_tab $'Col1\tCol2'
t_get T-103 escape_backslash 'C:\Program Files\Lexis'
t_get T-104 escape_quote 'She said "hello"'
t_get T-105 escape_carriage_return $'before\rafter'
t_get T-106 escape_backspace $'before\bafter'
t_get T-107 escape_vertical_tab $'before\vafter'
t_get T-108 escape_unknown 'unknown \q escape passes through'
t_get T-109 escape_trailing_backslash 'trailing backslash is literal\'
t_get T-110 escape_combined $'Name:\tAlice\nScore:\t99' Alice 99
t_get T-111 escape_null 'before\0after'
t_get T-112 escape_escaped_n 'literal \n character'
t_get T-113 passthrough_arg 'Hello a\nb' 'a\nb'
t_get T-114 escape_then_percent '\x' x

# --- Placeholders: T-201 to T-286 ----------------------------------------------
section "Placeholders (T-201 to T-286)"
t_get T-201 placeholder_string 'Hello Alice' 'Alice'
t_get T-202 placeholder_integer 'You have 3 messages' '3'
t_get T-203 placeholder_float 'Rating: 3.75' '3.75'
t_get T-204 placeholder_hex 'Hex value: ff' '255'
t_get T-205 placeholder_octal 'Octal value: 10' '8'
t_get T-206 placeholder_char 'Char: A' '65'
t_get T-207 placeholder_percent '100% completed'
t_get T-208 placeholder_multiple 'User Alice has 10 points and rating 4.50' 'Alice' '10' '4.5'
t_get T-211 pad_neg_int '-0042' '-42'
t_get T-212 float_prec '00003.14' '3.14159'
t_get T-213 neg_hex '-2a' '-42'
t_get T-215 invalid_specifier 'Value: %q' 'test'
t_get T-217 placeholder_float 'Rating: 1000000000000000000' '1000000000000000000'
t_get T-218 placeholder_integer 'You have 9223372036854775807 messages' '9223372036854775807'
t_get T-219 adjacent_percent '%%s Alice' 'Alice'
t_get T-220 one_placeholder 'Hello Alice' 'Alice' 'extra_arg'
t_get T-221 float_default_prec '3.1' '3.1'
t_get T-222 float_zero_prec '3' '2.5'
t_get T-223a string_width_right '   Hi' 'Hi'
t_get T-223b string_width_left 'Hi   ' 'Hi'
t_get T-224 string_zero_pad '   Hi' 'Hi'
t_get T-225 pos_test 'Hello Alice, code 10' 'Alice' '10'
t_get T-226 placeholder_string 'Hello %s%d' '%s%d'
t_get T-227 trailing_percent 'Value ends with %'
t_get T-229 placeholder_char 'Char: €' '8364'
t_get T-230 i_spec 'Count: 42' '42'
t_get T-231 unknown_specs '%u %X %e %g %b %n %p' 'x'
t_get T-232 positional_attempt_2 'Hello %1$s' 'Alice'
t_get T-233 width_codepoint '    ñ' 'ñ'
t_get T-234 numeric_string '42' '42'
t_get T-236 float_zero_prec '-3' '-2.5'
t_get T-237 float_two_prec '1.00' '1.005'
skip T-240 "a float argument is plain text in Bash"
t_get T-242 lit_flags '%+d|% d|%#x' '5' '5' '255'
t_get T-243 lit_length '%ld|%lld|%hd|%zu' '5'
t_get T-244 lit_star '%*d|%.*f' '5' '2' '3.14'
t_get T-245 lit_prec_s '%.3s|%.2d' 'abcdef' '5'
t_get T-246 lit_prec_empty '%.f' '3.5'
t_get T-247 lit_flag_order '%0-5d' '5'
t_get T-248 lit_percent_space '50% discount'
t_get T-249a lit_cut_off_width 'Width cut off %5'
t_get T-249b lit_cut_off_flags 'Flags cut off %-0'
t_get T-250 lit_then_real '%qx' 'x'
t_get T-251 width_max "$(printf '%1023s1' '')" '1'
t_get T-252 width_over '%1025d' '1'
t_get T-253 width_overflow '%99999999999999999999d' '1'
t_get T-254 prec_max '0.100000000000000' '0.1'
t_get T-255a prec_over '%.16f' '0.1'
t_get T-255b prec_overflow '%.99999999999999999999f' '1'
t_get T-256 pad_left_zero '42   |' '42'
t_get T-257 pad_char_zero '  A|' '65'
t_get T-258 pad_neg_float '-0003.14' '-3.14159'
t_get T-259 pad_neg_hex '-002a' '-42'
t_get T-260 pad_left_float '3.14    |' '3.14159'
t_get T-261 pad_no_truncate '12345' '12345'
t_get T-262 width_emoji '    👋|' '👋'
t_get T-263 width_combining '   é|' 'é'
t_get T-264a s_int '-42' '-42'
t_get T-264b s_int_min '-9223372036854775808' '-9223372036854775808'
t_get T-265a s_float '3.14' '3.14'
skip T-265b "a float argument is plain text in Bash"
skip T-265c "a float argument is plain text in Bash"
t_get T-270 d_int_min '-9223372036854775808' '-9223372036854775808'
t_get T-273a hex_zero '0' '0'
t_get T-273b hex_int_min '-8000000000000000' '-9223372036854775808'
t_get T-273c oct_neg '-10' '-8'
t_get T-276a char_astral '👋' '128075'
t_get T-276b char_max '􏿿' '1114111'
t_get T-276c char_numstr 'A' '65'
t_get T-278a f_def_int_valued '3' '3.0'
t_get T-278b f_def_hundred '100' '100.0'
t_get T-278c f_def_sum '0.3' '0.30000000000000004'
t_get T-278d f_def_third '0.333333' '0.3333333333333333'
t_get T-278e f_def_round '1.234568' '1.23456789'
t_get T-278f f_def_big '1234567.891' '1234567.891'
t_get T-278g f_def_intarg '3' '3'
t_get T-279a f_def_tiny '0' '0.0000004'
t_get T-279b f_def_tiny_neg '0' '-0.0000004'
t_get T-279c f_def_negzero '0' '-0.0'
t_get T-279d f_def_edge '0.000001' '0.000001'
t_get T-280a f_prec_small '0.0000004' '0.0000004'
t_get T-280b f_prec_pad '3.00' '3.0'
t_get T-280c f_prec_intarg '1.00' '1'
t_get T-280d f_prec_one '3.10' '3.1'
t_get T-281a f_tie_half '1' '0.5'
t_get T-281b f_tie_onehalf '2' '1.5'
t_get T-282 f_neg_tiny '0.00' '-0.001'
t_get T-283 f_str '3.14' '3.14'
t_get T-284 f_big_prec '9000000000000000000.00' '9000000000000000000'
t_get T-286 pct_pct_s '%s'

# --- Placeholders that must fail with LexFormatError (code 5) --------------------
section "Placeholders that raise LexFormatError"
skip T-209 "a boolean is plain text in Bash"
skip T-210 "there is no null in Bash"
t_err T-214 5 two_placeholders 'only_one_arg'
t_err T-216a 5 placeholder_float 'NaN'
t_err T-216b 5 placeholder_float 'Infinity'
t_err T-228 5 placeholder_integer 'abc'
t_err T-235 5 placeholder_float '-Infinity'
t_err T-238a 5 placeholder_float '9223372036854776000'
t_err T-238b 5 placeholder_float '10000000000000000000'
t_err T-238c 5 placeholder_float '1000000000000000000000'
t_err T-239 5 placeholder_char '1114112'
t_err T-241 5 placeholder_integer '3.7'
skip T-266 "a boolean is plain text in Bash"
skip T-267 "there is no null in Bash"
t_err T-269a 5 d_str_float '4.0'
t_err T-269b 5 d_str_plus '+5'
t_err T-269c 5 d_str_space ' 5'
t_err T-269d 5 d_str_empty ''
t_err T-271a 5 d_float_big '10000000000000000000'
t_err T-271b 5 d_str_big '9223372036854775808'
t_err T-272a 5 d_nan 'NaN'
t_err T-272b 5 d_inf 'Infinity'
t_err T-274a 5 hex_frac '3.5'
t_err T-274b 5 hex_bad_str 'zz'
t_err T-275a 5 char_zero '0'
t_err T-275b 5 char_neg '-1'
t_err T-275c 5 char_surr_lo '55296'
t_err T-275d 5 char_surr_hi '57343'
t_err T-277 5 char_str 'A'
t_err T-283a 5 f_str_exp '1e5'
t_err T-283b 5 f_str_bad 'abc'
skip T-285 "a boolean is plain text in Bash"
t_err T-268 5 s_bad_utf8 $'\xC3('

# --- Edge cases: T-303 (T-301 and T-302 are retired) -----------------------------
section "Edge cases (T-303)"
t_get T-303 triple_colon "key:::value with triple colon"

# --- Conformance: T-401 to T-437 -------------------------------------------------
section "Conformance (T-401 to T-437)"
t_err T-401 3 nonexistent_key
run lexis_get_or_default nonexistent_key fallback;          assert_eq T-402 "fallback" "$OUT"
run lexis_get_or_default nonexistent_key "Hello %s" Alice;  assert_eq T-403 "Hello Alice" "$OUT"

load "$FIXTURES_DIR" fr
assert_eq "T-404 (locale)" "en" "$_LEXIS_LOCALE"
t_get T-404 welcome "Welcome Alice" Alice
load "$FIXTURES_DIR" fr pt
assert_eq "T-405 (fallback)" "pt" "$_LEXIS_FALLBACK_LOCALE"
assert_eq "T-405 (locale)" "pt" "$_LEXIS_LOCALE"
t_get T-405 welcome "Bem-vindo Alice" Alice

load "$FIXTURES_DIR" es
t_get T-406 welcome "Bienvenido Alice" Alice
lexis_reload en >/dev/null 2>&1
t_get T-406 welcome "Welcome Alice" Alice

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
t_rc T-408 2 lexis_reload xyz
assert_eq "T-408 (state unchanged)" "$before" "$(lexis_info)"
t_get T-408 welcome "Hola"

t_rc T-410 4 lexis_load "$STANDALONE" dk
t_rc T-411 4 lexis_load "$STANDALONE" ml
t_rc T-412 4 lexis_load "$STANDALONE" ek
t_rc T-413 2 lexis_load "${WORK}/nonexistent/path" en

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
t_get T-415 k1 "value from locale A"
lexis_reload bb >/dev/null 2>&1
t_err T-415 3 k1
t_get T-415 k2 "value from locale B"

# T-416: a failed reload leaves the loaded state untouched
cp "${STANDALONE}/ml.lex" "${WORK}/t415/xx.lex"
load "${WORK}/t415" aa
before="$(lexis_info)"
t_rc T-416 4 lexis_reload xx
assert_eq "T-416 (state unchanged)" "$before" "$(lexis_info)"
t_get T-416 k1 "value from locale A"

load "$STANDALONE" ts
t_get T-417 KEY "value1"
t_get T-417 key "value2"

for code in es-ES es_ES ES; do
    load "$FIXTURES_DIR" "$code"
    assert_eq "T-418 ($code)" "es" "$_LEXIS_LOCALE"
done

t_rc T-419 4 lexis_load "$STANDALONE" iv

load "$STANDALONE" rk
t_get T-420 toString "mapped toString value"
t_get T-420 valueOf "mapped valueOf value"
t_get T-420 __proto__ "mapped __proto__ value"
t_get T-420 constructor "mapped constructor value"

skip T-421 "the Bash runtime is a single global instance"

load "$STANDALONE" em
assert_eq "T-422 (empty file)" "0" "$(lexis_len)"
mkdir -p "${WORK}/t422"; printf '# only\n\n  # comments\n' >"${WORK}/t422/en.lex"
load "${WORK}/t422" en
assert_eq "T-422 (comment-only file)" "0" "$(lexis_len)"

for code in '../secret' 'es/..' 'es\x' 'es.x' 'es_VE_X' 'es VE'; do
    t_rc "T-423/T-424 [$code]" 2 lexis_load "$LOCALES_DIR" "$code"
done
skip "T-424 [empty locale]" "an empty argument means 'not given' in Bash"
t_rc T-425 2 lexis_load "$LOCALES_DIR" es "../x"
t_rc T-425 2 lexis_load "$LOCALES_DIR" es en "../main"
t_rc T-425 2 lexis_load "$LOCALES_DIR" es en "a/b"
skip "T-425 [empty name]" "an empty argument means 'not given' in Bash"

for code in es-VE es_ve ES_VE; do
    load "$LOCALES_DIR" "$code"
    assert_eq "T-426 ($code, welcome)" "es_VE" "$(lexis_get welcome)"
    assert_eq "T-426 ($code, locale)" "es_VE" "$_LEXIS_LOCALE"
done
load "$LOCALES_DIR" es_VE
t_get T-427 welcome "es_VE"; assert_eq "T-427 (locale)" "es_VE" "$_LEXIS_LOCALE"
load "$LOCALES_DIR" es_AR
t_get T-428 welcome "es";    assert_eq "T-428 (locale)" "es" "$_LEXIS_LOCALE"
load "$LOCALES_DIR" pt
t_get T-429 welcome "pt (main)"
load "$LOCALES_DIR" pt en custom
t_get T-430 welcome "pt (custom)"; assert_eq "T-430 (name)" "custom" "$_LEXIS_NAME"
load "$LOCALES_DIR" de
t_get T-431 welcome "de (file)"
load "$LOCALES_DIR" fr_CA
t_get T-432 welcome "fr_CA (dir)"
load "$LOCALES_DIR" ja es_VE
t_get T-433 welcome "es_VE"; assert_eq "T-433 (locale)" "es_VE" "$_LEXIS_LOCALE"
load "$LOCALES_DIR" ja
t_get T-434 welcome "en";    assert_eq "T-434 (locale)" "en" "$_LEXIS_LOCALE"

load "$LOCALES_DIR" pt en custom
lexis_reload pt >/dev/null 2>&1
t_get T-435 welcome "pt (custom)"
t_rc T-435 2 lexis_reload "../x"
t_get T-435 welcome "pt (custom)"
assert_eq "T-435 (name)" "custom" "$_LEXIS_NAME"

load "$LOCALES_DIR" es_VE
lexis_reload "" en >/dev/null 2>&1
t_get T-436 welcome "es_VE"; assert_eq "T-436 (locale)" "es_VE" "$_LEXIS_LOCALE"

# T-437 (optional): locale auto-detection from LANG
for pair in 'es_VE.UTF-8:es_VE' 'es_VE@euro:es_VE' 'C.UTF-8:en' 'POSIX:en' ':en' 'zh_Hans_CN.UTF-8:en'; do
    LANG="${pair%%:*}" lexis_load "$LOCALES_DIR" >/dev/null 2>&1
    assert_eq "T-437 [${pair%%:*}] (locale)" "${pair##*:}" "$_LEXIS_LOCALE"
    t_get "T-437 [${pair%%:*}]" welcome "${pair##*:}"
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
t_get "clear keeps the translations" simple "Hello World"
(( cached_before >= 1 )); assert_eq "cache was filled before clear" "0" "$?"
t_rc "get_or_default fails (5) on a bad argument" 5 lexis_get_or_default zz "%d" abc
run lexis_get_or_default simple "unused"; assert_eq "get_or_default (existing key)" "Hello World" "$OUT"

# --- Summary --------------------------------------------------------------------
printf '\n%bPassed: %d%b  %bFailed: %d%b  %bSkipped: %d%b\n' \
    "$GREEN" "$PASSED" "$NC" "$RED" "$FAILED" "$NC" "$YELLOW" "$SKIPPED" "$NC"
(( FAILED == 0 ))