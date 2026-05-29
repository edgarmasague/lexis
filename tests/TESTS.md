# Lexis · Test Cases

Generic conformance tests for any Lexis runtime implementation.

All runtimes **MUST** pass every case in this document.  
Test input is `tests/test.lex` unless otherwise specified.

---

## How to Read This Document

Each test case follows this structure:

```
### T-XXX — Description

**Input:**  key + optional args
**Expected:** output string
**Notes:** (optional clarification)
```

A runtime passes a test if `get(key, ...args)` returns exactly the expected output.

---

## Unit Tests

### Parsing

---

#### T-001 — Simple entry

**Input:** `get("simple")`  
**Expected:** `Hello World`

---

#### T-002 — Empty value

**Input:** `get("empty_value")`  
**Expected:** *(empty string)*

---

#### T-003 — Key is trimmed

**Input:** `get("key_trimmed")`  
**Expected:** `Value with spaces around key`  
**Notes:** Key `key_trimmed ` (with trailing space) must be stored as `key_trimmed`.

---

#### T-004 — Uppercase key

**Input:** `get("UPPERCASE_KEY")`  
**Expected:** `uppercase key test`

---

#### T-005 — Mixed case key

**Input:** `get("mixed_Case_Key")`  
**Expected:** `mixed case key test`

---

#### T-006 — Value starting with `#`

**Input:** `get("value_with_hash")`  
**Expected:** `#this value starts with hash`  
**Notes:** `#` is only a comment marker at the start of a line, not inside a value.

---

#### T-007 — Value containing `::`

**Input:** `get("value_with_separator")`  
**Expected:** `value :: contains :: separators`  
**Notes:** Only the first `::` is the separator. Everything after belongs to the value.

---

#### T-008 — Leading whitespace in value is trimmed

**Input:** `get("value_leading_spaces")`  
**Expected:** `leading spaces are trimmed`

---

#### T-009 — Trailing whitespace in value is preserved

**Input:** `get("value_trailing_spaces")`  
**Expected:** `trailing spaces are preserved   ` *(3 trailing spaces)*

---

#### T-010 — Unicode value

**Input:** `get("value_unicode")`  
**Expected:** `Hello 👋 World`

---

#### T-011 — UTF-8 extended characters

**Input:** `get("value_utf8")`  
**Expected:** `Héllo Wörld — ñoño`

---

### Escape Sequences

---

#### T-020 — `\n` newline

**Input:** `get("escape_newline")`  
**Expected:** `Line 1` + LF + `Line 2`

---

#### T-021 — `\t` tab

**Input:** `get("escape_tab")`  
**Expected:** `Col1` + TAB + `Col2`

---

#### T-022 — `\\` backslash

**Input:** `get("escape_backslash")`  
**Expected:** `C:\Program Files\Lexis`

---

#### T-023 — `\"` double quote

**Input:** `get("escape_quote")`  
**Expected:** `She said "hello"`

---

#### T-024 — `\r` carriage return

**Input:** `get("escape_carriage_return")`  
**Expected:** `before` + CR + `after`

---

#### T-025 — `\b` backspace

**Input:** `get("escape_backspace")`  
**Expected:** `before` + BS + `after`

---

#### T-026 — `\v` vertical tab

**Input:** `get("escape_vertical_tab")`  
**Expected:** `before` + VT + `after`

---

#### T-027 — Unknown escape passes through literally

**Input:** `get("escape_unknown")`  
**Expected:** `unknown \q escape passes through`  
**Notes:** `\q` is not a recognized sequence and must remain unchanged.

---

#### T-028 — Trailing backslash is literal

**Input:** `get("escape_trailing_backslash")`  
**Expected:** `trailing backslash is literal\`

---

#### T-029 — Combined escapes with placeholders

**Input:** `get("escape_combined", "Alice", 99)`  
**Expected:** `Name:` + TAB + `Alice` + LF + `Score:` + TAB + `99`

---

### Placeholders

---

#### T-030 — `%s` string

**Input:** `get("placeholder_string", "Alice")`  
**Expected:** `Hello Alice`

---

#### T-031 — `%d` integer

**Input:** `get("placeholder_integer", 3)`  
**Expected:** `You have 3 messages`

---

#### T-032 — `%f` float

**Input:** `get("placeholder_float", 3.75)`  
**Expected:** `Rating: 3.750000` *(default float precision)*

---

#### T-033 — `%x` hexadecimal

**Input:** `get("placeholder_hex", 255)`  
**Expected:** `Hex value: ff`

---

#### T-034 — `%o` octal

**Input:** `get("placeholder_octal", 8)`  
**Expected:** `Octal value: 10`

---

#### T-035 — `%c` character

**Input:** `get("placeholder_char", 65)`  
**Expected:** `Char: A`

---

#### T-036 — `%%` literal percent

**Input:** `get("placeholder_percent")`  
**Expected:** `100% completed`  
**Notes:** `%%` must produce a single `%`. No args needed.

---

#### T-037 — Multiple placeholders

**Input:** `get("placeholder_multiple", "Alice", 10, 4.5)`  
**Expected:** `User Alice has 10 points and rating 4.50`

---

### Edge Cases

---

#### T-038 — Value starting with `#` is not a comment

**Input:** `get("not_a_comment")`  
**Expected:** `#not a comment`

---

#### T-039 — Double `::` in value

**Input:** `get("double_colon")`  
**Expected:** `key::value with double colon in value`

---

#### T-040 — Triple `::` in value

**Input:** `get("triple_colon")`  
**Expected:** `key:::value with triple colon`

---

## Conformance Tests

These tests verify runtime behavior beyond key lookup.

---

#### T-041 — Missing key returns key itself

**Input:** `get("nonexistent_key")`  
**Expected:** `nonexistent_key` *(or raises `LexKeyNotFoundError`)*  
**Notes:** Returning the key is acceptable. Raising an error is also acceptable. Returning empty string is not.

---

#### T-042 — Missing key with default

**Input:** `get_or_default("nonexistent_key", "fallback")`  
**Expected:** `fallback`

---

#### T-043 — Missing key with default and args

**Input:** `get_or_default("nonexistent_key", "Hello %s", "Alice")`  
**Expected:** `Hello Alice`

---

#### T-044 — Locale fallback

**Setup:** Request a locale with no `.lex` file (e.g. `fr`)  
**Expected:** Runtime loads the fallback locale file without error  
**Notes:** The fallback locale is determined by the runtime configuration.

---

#### T-045 — Reload switches locale

**Setup:**
1. Load locale `es`
2. Call `get("welcome", "Alice")` → verify Spanish output
3. Call `reload("en")`
4. Call `get("welcome", "Alice")` → verify English output

**Expected:** Output changes after reload.

---

#### T-046 — Reload rollback on failure

**Setup:**
1. Load a valid locale
2. Call `reload("nonexistent_locale_xyz")`

**Expected:** Previous translations remain available after the failed reload.

---

#### T-047 — Duplicate key raises error

**Setup:** Load a `.lex` file containing:

```text
hello::First
hello::Second
```

**Expected:** `LexParseError` is raised.

---

#### T-048 — Malformed line raises error

**Setup:** Load a `.lex` file containing:

```text
this line has no separator
```

**Expected:** `LexParseError` is raised.

---

#### T-049 — Empty key raises error

**Setup:** Load a `.lex` file containing:

```text
::value with no key
```

**Expected:** `LexParseError` is raised.

---

#### T-050 — File not found raises error

**Setup:** Call `load("nonexistent/path", "en")`  
**Expected:** `LexFileNotFoundError` is raised.

---

#### T-051 — Lazy caching: escape processed only once

**Setup:**
1. Call `get("escape_newline")` — first access
2. Call `get("escape_newline")` — second access

**Expected:** Both calls return identical output.  
**Notes:** The runtime must not re-process escapes on subsequent calls.

---

## Compliance Checklist

- [ ] T-001 to T-011 — Parsing
- [ ] T-020 to T-029 — Escape sequences
- [ ] T-030 to T-037 — Placeholders
- [ ] T-038 to T-040 — Edge cases
- [ ] T-041 to T-051 — Conformance

A runtime is **fully compliant** when all cases pass.

---

*Lexis — Una ley, muchos lenguajes.*