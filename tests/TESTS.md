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

#### T-101 — `\n` newline

**Input:** `get("escape_newline")`  
**Expected:** `Line 1` + LF + `Line 2`

---

#### T-102 — `\t` tab

**Input:** `get("escape_tab")`  
**Expected:** `Col1` + TAB + `Col2`

---

#### T-103 — `\\` backslash

**Input:** `get("escape_backslash")`  
**Expected:** `C:\Program Files\Lexis`

---

#### T-104 — `\"` double quote

**Input:** `get("escape_quote")`  
**Expected:** `She said "hello"`

---

#### T-105 — `\r` carriage return

**Input:** `get("escape_carriage_return")`  
**Expected:** `before` + CR + `after`

---

#### T-106 — `\b` backspace

**Input:** `get("escape_backspace")`  
**Expected:** `before` + BS + `after`

---

#### T-107 — `\v` vertical tab

**Input:** `get("escape_vertical_tab")`  
**Expected:** `before` + VT + `after`

---

#### T-108 — Unknown escape passes through literally

**Input:** `get("escape_unknown")`  
**Expected:** `unknown \q escape passes through`  
**Notes:** `\q` is not a recognized sequence and must remain unchanged.

---

#### T-109 — Trailing backslash is literal

**Input:** `get("escape_trailing_backslash")`  
**Expected:** `trailing backslash is literal\`

---

#### T-110 — Combined escapes with placeholders

**Input:** `get("escape_combined", "Alice", 99)`  
**Expected:** `Name:` + TAB + `Alice` + LF + `Score:` + TAB + `99`

---

### Placeholders

---

#### T-201 — `%s` string

**Input:** `get("placeholder_string", "Alice")`  
**Expected:** `Hello Alice`

---

#### T-202 — `%d` integer

**Input:** `get("placeholder_integer", 3)`  
**Expected:** `You have 3 messages`

---

#### T-203 — `%f` float

**Input:** `get("placeholder_float", 3.75)`  
**Expected:** `Rating: 3.750000` *(default float precision)*

---

#### T-204 — `%x` hexadecimal

**Input:** `get("placeholder_hex", 255)`  
**Expected:** `Hex value: ff`

---

#### T-205 — `%o` octal

**Input:** `get("placeholder_octal", 8)`  
**Expected:** `Octal value: 10`

---

#### T-206 — `%c` character

**Input:** `get("placeholder_char", 65)`  
**Expected:** `Char: A`

---

#### T-207 — `%%` literal percent

**Input:** `get("placeholder_percent")`  
**Expected:** `100% completed`  
**Notes:** `%%` must produce a single `%`. No args needed.

---

#### T-208 — Multiple placeholders

**Input:** `get("placeholder_multiple", "Alice", 10, 4.5)`  
**Expected:** `User Alice has 10 points and rating 4.50`

---

### Edge Cases

---

#### T-301 — Value starting with `#` is not a comment

**Input:** `get("not_a_comment")`  
**Expected:** `#not a comment`

---

#### T-302 — Double `::` in value

**Input:** `get("double_colon")`  
**Expected:** `key::value with double colon in value`

---

#### T-303 — Triple `::` in value

**Input:** `get("triple_colon")`  
**Expected:** `key:::value with triple colon`

---

## Conformance Tests

These tests verify runtime behavior beyond key lookup.

---

#### T-401 — Missing key raises error

**Input:** `get("nonexistent_key")`  
**Expected:** raises `LexKeyNotFoundError`

---

#### T-402 — Missing key with default

**Input:** `get_or_default("nonexistent_key", "fallback")`  
**Expected:** `fallback`

---

#### T-403 — Missing key with default and args

**Input:** `get_or_default("nonexistent_key", "Hello %s", "Alice")`  
**Expected:** `Hello Alice`

---

#### T-404 — Locale fallback (default)

**Setup:** Request a locale with no `.lex` file (e.g. `fr`), default fallback is `"en"`
**Expected:** Runtime loads the fallback locale file without error

---

#### T-405 — Locale fallback (custom)

**Setup:** Request a locale with no `.lex` file, custom fallback `fallback_locale="pt"`
**Expected:** Runtime loads `pt.lex` and updates locale to `"pt"`

---

#### T-406 — Reload switches locale

**Setup:**
1. Load locale `es`
2. Call `get("welcome", "Alice")` → verify Spanish output
3. Call `reload("en")`
4. Call `get("welcome", "Alice")` → verify English output

**Expected:** Output changes after reload.

---

#### T-407 — Reload changes fallback locale

**Setup:**
1. Load locale `en` with fallback `en`
2. Call `reload(fallback_locale="es")`
3. Verify `fallback_locale` is now `"es"`

**Expected:** Fallback locale changes after reload.

---

#### T-408 — Reload rollback on failure

**Setup:**
1. Load a valid locale
2. Call `reload("nonexistent_locale_xyz")`

**Expected:** Previous translations remain available after the failed reload.

---

#### T-409 — Load with custom fallback

**Setup:** Call `load(lang_dir, "fr", fallback_locale="pt")` where only `pt.lex` exists
**Expected:** `fallback_locale` is set to `"pt"` and `pt.lex` is loaded

---

#### T-410 — Duplicate key raises error

**Setup:** Load a `.lex` file containing:

```text
hello::First
hello::Second
```

**Expected:** `LexParseError` is raised.

---

#### T-411 — Malformed line raises error

**Setup:** Load a `.lex` file containing:

```text
this line has no separator
```

**Expected:** `LexParseError` is raised.

---

#### T-412 — Empty key raises error

**Setup:** Load a `.lex` file containing:

```text
::value with no key
```

**Expected:** `LexParseError` is raised.

---

#### T-413 — File not found raises error

**Setup:** Call `load("nonexistent/path", "en")`  
**Expected:** `LexFileNotFoundError` is raised.

---

#### T-414 — Lazy caching: escape processed only once

**Setup:**
1. Call `get("escape_newline")` — first access
2. Call `get("escape_newline")` — second access

**Expected:** Both calls return identical output. `_unescape` is called exactly once.
**Notes:** The runtime must not re-process escapes on subsequent calls.

---

## Compliance Checklist

| Category         | Range             | Tests |
| ---------------- | ----------------- | ----- |
| Parsing          | `T-001` – `T-011` | 11    |
| Escape sequences | `T-101` – `T-110` | 10    |
| Placeholders     | `T-201` – `T-208` | 8     |
| Edge cases       | `T-301` – `T-303` | 3     |
| Conformance      | `T-401` – `T-414` | 14    |

A runtime is **fully compliant** when all cases pass.

---

*Lexis — Una ley, muchos lenguajes.*