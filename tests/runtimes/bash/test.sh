#!/usr/bin/env bash
# test.sh - Official Test Suite for LEXIS Bash Runtime
# Based on TESTS.md
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../../runtimes/bash/lexis.sh"

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        ((FAILED++))
    fi
}

assert_fail() {
    local test_name="$1"
    local cmd="$2"
    if eval "$cmd" 2>/dev/null; then
        echo -e "${RED}✗${NC} $test_name (expected failure but succeeded)"
        ((FAILED++))
    else
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    fi
}

FIXTURES_DIR="$(cd "${SCRIPT_DIR}/../../fixtures" && pwd)"
lexis_load "$FIXTURES_DIR" "test" "en"

echo "=== Parsing T-001 to T-011 ==="
assert_eq "T-001 simple entry"           "Hello World" "$(lexis_get "simple")"
assert_eq "T-002 empty value"            "" "$(lexis_get "empty_value")"
assert_eq "T-003 key trimmed"          "Value with spaces around key" "$(lexis_get "key_trimmed")"
assert_eq "T-004 uppercase key"        "uppercase key test" "$(lexis_get "UPPERCASE_KEY")"
assert_eq "T-005 mixed case key"       "mixed case key test" "$(lexis_get "mixed_Case_Key")"
assert_eq "T-006 value with hash"       "#this value starts with hash" "$(lexis_get "value_with_hash")"
assert_eq "T-007 value with separator" "value :: contains :: separators" "$(lexis_get "value_with_separator")"
assert_eq "T-008 leading spaces trimmed"    "leading spaces are trimmed" "$(lexis_get "value_leading_spaces")"
assert_eq "T-009 trailing spaces preserved" "trailing spaces are preserved " "$(lexis_get "value_trailing_spaces")"
assert_eq "T-010 unicode"              "Hello 👋 World" "$(lexis_get "value_unicode")"
assert_eq "T-011 utf8 extended"        "Héllo Wörld — ñoño" "$(lexis_get "value_utf8")"

echo ""
echo "=== Escape Sequences T-101 to T-110 ==="
assert_eq "T-101 newline"              "Line 1"$'\n'"Line 2" "$(lexis_get "escape_newline")"
assert_eq "T-102 tab"                  "Col1"$'\t'"Col2" "$(lexis_get "escape_tab")"
assert_eq "T-103 backslash"            "C:\\Program Files\\Lexis" "$(lexis_get "escape_backslash")"
assert_eq "T-104 quote"                'She said "hello"' "$(lexis_get "escape_quote")"
assert_eq "T-105 carriage return"       "before"$'\r'"after" "$(lexis_get "escape_carriage_return")"
assert_eq "T-106 backspace"            "before"$'\b'"after" "$(lexis_get "escape_backspace")"
assert_eq "T-107 vertical tab"        "before"$'\v'"after" "$(lexis_get "escape_vertical_tab")"
assert_eq "T-108 unknown escape"       "unknown \\q escape passes through" "$(lexis_get "escape_unknown")"
assert_eq "T-109 trailing backslash"   "trailing backslash is literal\\" "$(lexis_get "escape_trailing_backslash")"
assert_eq "T-110 combined escapes with placeholders" "Name:"$'\t'"Alice"$'\n'"Score:"$'\t'"99" "$(lexis_get "escape_combined" "Alice" "99")"

echo ""
echo "=== Placeholders T-201 to T-208 ==="
assert_eq "T-201 string"               "Hello Alice" "$(lexis_get "placeholder_string" "Alice")"
assert_eq "T-202 integer"              "You have 3 messages" "$(lexis_get "placeholder_integer" "3")"
assert_eq "T-203 float"                "Rating: 3.750000" "$(lexis_get "placeholder_float" "3.75")"
assert_eq "T-204 hex"                  "Hex value: ff" "$(lexis_get "placeholder_hex" "255")"
assert_eq "T-205 octal"                "Octal value: 10" "$(lexis_get "placeholder_octal" "8")"
assert_eq "T-206 char"                 "Char: A" "$(lexis_get "placeholder_char" "65")"
assert_eq "T-207 literal percent"      "100% completed" "$(lexis_get "placeholder_percent")"
assert_eq "T-208 multiple placeholders" "User Alice has 10 points and rating 4.50" "$(lexis_get "placeholder_multiple" "Alice" "10" "4.5")"

echo ""
echo "=== Edge Cases T-301 to T-303 ==="
assert_eq "T-301 not a comment"        "#not a comment" "$(lexis_get "not_a_comment")"
assert_eq "T-302 double colon"        "key::value with double colon in value" "$(lexis_get "double_colon")"
assert_eq "T-303 triple colon"        "key:::value with triple colon" "$(lexis_get "triple_colon")"

echo ""
echo "=== Conformance T-401 to T-414 ==="
assert_fail "T-401 missing key raises" "lexis_get 'nonexistent_key'"
assert_eq "T-402 missing key with default" "fallback" "$(lexis_get_or_default "nonexistent_key" "fallback")"
assert_eq "T-403 missing key with default and args" "Hello Alice" "$(lexis_get_or_default "nonexistent_key" "Hello %s" "Alice")"

echo ""
echo "--- T-404 Locale fallback (default) ---"
TMPDIR=$(mktemp -d)
echo "welcome::Welcome" > "$TMPDIR/en.lex"
lexis_load "$TMPDIR" "fr"
assert_eq "T-404 fallback locale" "en" "$_LEXIS_LOCALE"
assert_eq "T-404 fallback value" "Welcome" "$(lexis_get "welcome")"

echo ""
echo "--- T-405 Locale fallback (custom) ---"
echo "welcome::Bem-vindo" > "$TMPDIR/pt.lex"
lexis_load "$TMPDIR" "fr" "pt"
assert_eq "T-405 custom fallback locale" "pt" "$_LEXIS_LOCALE"
assert_eq "T-405 custom fallback value" "Bem-vindo" "$(lexis_get "welcome")"
rm -rf "$TMPDIR"

echo ""
echo "--- T-406 Reload switches locale ---"
lexis_load "$FIXTURES_DIR" "es" "en"
lexis_reload "en"
assert_eq "T-406 reload locale" "en" "$_LEXIS_LOCALE"
assert_eq "T-406 reload value" "Welcome Alice" "$(lexis_get "welcome" "Alice")"

echo ""
echo "--- T-407 Reload changes fallback ---"
TMPDIR=$(mktemp -d)
echo "hello::Hola" > "$TMPDIR/es.lex"
echo "hello::Hello" > "$TMPDIR/en.lex"
lexis_load "$TMPDIR" "fr" "en"
lexis_reload "" "es"
assert_eq "T-407 fallback changed" "es" "$_LEXIS_FALLBACK_LOCALE"
rm -rf "$TMPDIR"

echo ""
echo "--- T-408 Reload rollback on failure ---"
lexis_load "$FIXTURES_DIR" "en" "en"
OLD_LOCALE="$_LEXIS_LOCALE"
OLD_KEYS=$(lexis_keys | wc -l)
if ! lexis_reload "nonexistent_xyz" "also_nonexistent" 2>/dev/null; then
    assert_eq "T-408 rollback locale" "$OLD_LOCALE" "$_LEXIS_LOCALE"
    assert_eq "T-408 rollback keys" "$OLD_KEYS" "$(lexis_keys | wc -l)"
    assert_eq "T-408 rollback works" "Welcome Alice" "$(lexis_get "welcome" "Alice")"
else
    echo -e "${RED}✗${NC} T-408 reload rollback (should have failed)"
    ((FAILED++))
fi

echo ""
echo "--- T-409 Load with custom fallback ---"
TMPDIR=$(mktemp -d)
echo "hello::Oi" > "$TMPDIR/pt.lex"
echo "hello::Hello" > "$TMPDIR/en.lex"
lexis_load "$TMPDIR" "fr" "pt"
assert_eq "T-409 custom fallback" "Oi" "$(lexis_get "hello")"
rm -rf "$TMPDIR"

echo ""
echo "--- T-410 to T-413 Error cases ---"
TMPDIR=$(mktemp -d)

echo -e "hello::First\nhello::Second" > "$TMPDIR/test.lex"
assert_fail "T-410 duplicate key raises" "lexis_load '$TMPDIR' 'test'"

echo -e "valid::ok\nthis line has no separator" > "$TMPDIR/test.lex"
assert_fail "T-411 malformed line raises" "lexis_load '$TMPDIR' 'test'"

echo -e "valid::ok\n::value with no key" > "$TMPDIR/test.lex"
assert_fail "T-412 empty key raises" "lexis_load '$TMPDIR' 'test'"

assert_fail "T-413 file not found raises" "lexis_load '$TMPDIR' 'en'"

rm -rf "$TMPDIR"

echo ""
echo "--- T-414 Lazy caching ---"
lexis_load "$FIXTURES_DIR" "test" "en"
VAL1="$(lexis_get "escape_newline")"
VAL2="$(lexis_get "escape_newline")"
assert_eq "T-414 lazy cache consistency" "$VAL1" "$VAL2"
assert_eq "T-414 lazy cache value" "Line 1"$'\n'"Line 2" "$VAL1"

echo ""
echo "========================================"
echo -e "${GREEN}PASSED: $PASSED${NC}"
echo -e "${RED}FAILED: $FAILED${NC}"
echo "========================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
