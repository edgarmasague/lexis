# Lexis · Test Cases

Generic conformance tests for any Lexis runtime implementation.

All runtimes **MUST** pass every case in this document. Retired and optional
cases are marked explicitly — see the Compliance Checklist at the end.  
Test input is `tests/test.lex` unless otherwise specified.

---

## How to Read This Document

Each test case follows this structure:

```
### T-XXX — Description

**Input:**    the call being made, (e.g. get(key, ...args))
**Source:**   the relevant .lex line the input is read from (when applicable)
**Expected:** output string or the error raised
**Notes:**    (optional clarification)
```

A runtime passes a test if `get(key, ...args)` returns exactly the expected output.

---

## Unit Tests

### Parsing

#### T-001 — Simple entry

**Input:** `get("simple")`  
**Source:** `simple::Hello World`  
**Expected:** `Hello World`

---

#### T-002 — Empty value

**Input:** `get("empty_value")`  
**Source:** `empty_value::`  
**Expected:** *(empty string)*

---

#### T-003 — Key is trimmed

**Input:** `get("key_trimmed")`  
**Source:** `key_trimmed ::Value with spaces around key`  
**Expected:** `Value with spaces around key`  
**Notes:** Key `key_trimmed ` (with trailing space) must be stored as `key_trimmed`.

---

#### T-004 — Uppercase key

**Input:** `get("UPPERCASE_KEY")` 
**Source:** `UPPERCASE_KEY::uppercase key test`  
**Expected:** `uppercase key test`

---

#### T-005 — Mixed case key

**Input:** `get("mixed_Case_Key")`  
**Source:** `mixed_Case_Key::mixed case key test`  
**Expected:** `mixed case key test`

---

#### T-006 — Value starting with `#`

**Input:** `get("value_with_hash")`  
**Source:** `value_with_hash::#this value starts with hash`  
**Expected:** `#this value starts with hash`  
**Notes:** `#` is only a comment marker at the start of a line, not inside a value.

---

#### T-007 — Value containing `::`

**Input:** `get("value_with_separator")`  
**Source:** `value_with_separator::value :: contains :: separators`  
**Expected:** `value :: contains :: separators`  
**Notes:** Only the first `::` is the separator. Everything after belongs to the value.

---

#### T-008 — Leading whitespace in value is trimmed

**Input:** `get("value_leading_spaces")`  
**Source:** `value_leading_spaces::   leading spaces are trimmed`  
**Expected:** `leading spaces are trimmed`

---

#### T-009 — Trailing whitespace in value is preserved

**Input:** `get("value_trailing_spaces")`  
**Source:** `value_trailing_spaces::trailing spaces are preserved   `  
**Expected:** `trailing spaces are preserved   ` *(3 trailing spaces)*

---

#### T-010 — Unicode value

**Input:** `get("value_unicode")`  
**Source:** `value_unicode::Hello 👋 World`  
**Expected:** `Hello 👋 World`

---

#### T-011 — UTF-8 extended characters

**Input:** `get("value_utf8")`  
**Source:** `value_utf8::Héllo Wörld — ñoño`  
**Expected:** `Héllo Wörld — ñoño`

---

#### T-012 — CRLF line endings

**Input:** `get("crlf_entry")`  
**Source:** `crlf_entry::value without trailing carriage return`  
**Expected:** `value without trailing carriage return`  
**Notes:** File saved with `\r\n` line endings.

---

#### T-013 — Indented comments

**Input:** Parse file  
**Source:** File containing `  # indented comment`.  
**Expected:** Line is ignored as a comment without raising `LexParseError`.

---

#### T-014 — Whitespace around separator

**Input:** `get("key_space")`  
**Source:** `key_space :: value_space`  
**Expected:** `value_space`

---

#### T-015 — Whitespace-only lines

**Input:** Parse file  
**Source:** Line with `"   "` (3 spaces) and another with \t (tab)  
**Expected:** Lines are treated as empty and skipped without raising `LexParseError`.

---

#### T-016 — Complex 4-byte UTF-8 sequences

**Input:** `get("emoji_sequence")`  
**Source:** `emoji_sequence::Family: 👨‍👩‍👧‍👦`  
**Expected:** `Family: 👨‍👩‍👧‍👦`

---

#### T-017 — Extreme trailing whitespace performance

**Input:** `get("huge_spaces")`  
**Source:** `huge_spaces::correct string` followed by 10,000 spaces  
**Expected:** "correct string" + 10,000 trailing spaces preserved  
**Notes:** Must be processed in linear time $O(N)$ without triggering catastrophic backtracking in regex.

---

#### T-018 — UTF-8 Byte Order Mark (BOM)

**Input:** `get("first_key")`  
**Source:** `first_key::first_value`, with the file starting with byte sequence
`0xEF, 0xBB, 0xBF`.   
**Expected:** `first_value`  
**Notes:** The BOM is stripped automatically because it's the very first thing in
the file. See spec decision 1.

---

#### T-019 — No trailing newline at end of file

**Input:** `get("last_key")`  
**Source:** `last_key::last_value`  
**Expected:** `last_value`  
**Notes:** File ends with `last_key::last_value` and no final `\n`.

---

#### T-020 — BOM appearing mid-file

**Input:** `get("mid_bom")`  
**Source:** `mid_bom::prefix_\xEF\xBB\xBF_suffix`, where `<BOM>` is the raw byte sequence
`0xEF, 0xBB, 0xBF` inserted inside the value — not Lexis escape syntax, just the
literal bytes on disk.  
**Expected:** `"prefix_\xEF\xBB\xBF_suffix"`, i.e. the three BOM bytes come back untouched.  
**Notes:** Byte sequence `0xEF, 0xBB, 0xBF` inserted inside a value, not at the start of the file.

---

### Escape Sequences

---

#### T-101 — `\n` newline

**Input:** `get("escape_newline")`  
**Source:** `escape_newline::Line 1\nLine 2`  
**Expected:** `Line 1` + LF + `Line 2`

---

#### T-102 — `\t` tab

**Input:** `get("escape_tab")`  
**Source:** `escape_tab::Col1\tCol2`  
**Expected:** `Col1` + TAB + `Col2`

---

#### T-103 — `\\` backslash

**Input:** `get("escape_backslash")`  
**Source:** `escape_backslash::C:\\Program Files\\Lexis`  
**Expected:** `C:\Program Files\Lexis`

---

#### T-104 — `\"` double quote

**Input:** `get("escape_quote")`  
**Source:** `escape_quote::She said \"hello\"`  
**Expected:** `She said "hello"`

---

#### T-105 — `\r` carriage return

**Input:** `get("escape_carriage_return")` 
**Source:** `escape_carriage_return::before\rafter`   
**Expected:** `before` + CR + `after`

---

#### T-106 — `\b` backspace

**Input:** `get("escape_backspace")`  
**Source:** `escape_backspace::before\bafter`  
**Expected:** `before` + BS + `after`

---

#### T-107 — `\v` vertical tab

**Input:** `get("escape_vertical_tab")`  
**Source:** `escape_vertical_tab::before\vafter`  
**Expected:** `before` + VT + `after`

---

#### T-108 — Unknown escape passes through literally

**Input:** `get("escape_unknown")`  
**Source:** `escape_unknown::unknown \q escape passes through`  
**Expected:** `unknown \q escape passes through`  
**Notes:** `\q` is not a recognized sequence and must remain unchanged.

---

#### T-109 — Trailing backslash is literal

**Input:** `get("escape_trailing_backslash")`  
**Source:** `escape_trailing_backslash::trailing backslash is literal\`  
**Expected:** `trailing backslash is literal\`

---

#### T-110 — Combined escapes with placeholders

**Input:** `get("escape_combined", "Alice", 99)`  
**Source:** `escape_combined::Name:\t%s\nScore:\t%d`  
**Expected:** `Name:` + TAB + `Alice` + LF + `Score:` + TAB + `99`

---

#### T-111 —  `\0` is not a recognized escape

**Input:** `get("escape_null")`  
**Source:** `escape_null::before\0after`  
**Expected:** `before\0after` (literal backslash + `0`, two characters — must not produce a NUL byte)

---

#### T-112 —  Escaped backslash before escape character

**Input:** `get("escape_escaped_n")`  
**Source:** `escape_escaped_n::literal \\n character`  
**Expected:** `literal \n character` (a literal backslash + `n`, NOT a line break)

---

#### T-113 —  An argument is never re-unescaped

**Input:** `get("passthrough_arg", "a\nb")` where the argument is the literal two characters `\` `n` (not a real newline)  
**Source:** `passthrough_arg::Hello %s`  
**Expected:** `Hello a\nb` — the `\n` inside the *argument* is passed through untouched; unescaping only ever applies to the template pulled from the `.lex` file, never to interpolated arguments.

---

### Placeholders

---

#### T-201 — `%s` string

**Input:** `get("placeholder_string", "Alice")`  
**Source:** `placeholder_string::Hello %s`  
**Expected:** `Hello Alice`

---

#### T-202 — `%d` integer

**Input:** `get("placeholder_integer", 3)`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** `You have 3 messages`

---

#### T-203 — `%f` float

**Input:** `get("placeholder_float", 3.75)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** `Rating: 3.750000` *(default float precision)*

---

#### T-204 — `%x` hexadecimal

**Input:** `get("placeholder_hex", 255)`  
**Source:** `placeholder_hex::Hex value: %x`  
**Expected:** `Hex value: ff`

---

#### T-205 — `%o` octal

**Input:** `get("placeholder_octal", 8)`  
**Source:** `placeholder_octal::Octal value: %o`  
**Expected:** `Octal value: 10`

---

#### T-206 — `%c` character

**Input:** `get("placeholder_char", 65)`  
**Source:** `placeholder_char::Char: %c`  
**Expected:** `Char: A`

---

#### T-207 — `%%` literal percent

**Input:** `get("placeholder_percent")`  
**Source:** `placeholder_percent::100%% completed`  
**Expected:** `100% completed`  
**Notes:** `%%` must produce a single `%`. No args needed.

---

#### T-208 — Multiple placeholders

**Input:** `get("placeholder_multiple", "Alice", 10, 4.5)`  
**Source:** `placeholder_multiple::User %s has %d points and rating %.2f`  
**Expected:** `User Alice has 10 points and rating 4.50`

---

#### T-209 — Boolean coercion

**Input:** `get("bool_spec", true, false)`  
**Source:** `bool_spec::Active: %d, Blocked: %d`  
**Expected:** `Active: 1, Blocked: 0`

---

#### T-210 — Null / Nil handling *(optional, requires a `null` type)*

**Input:** `get("null_spec", null)`  
**Source:** `null_spec::Value: %s`  
**Expected:** `Value: ` (coerced to empty string)

---

#### T-211 — Signed integer zero padding (`%05d`)

**Input:** `get("pad_neg_int", -42)`  
**Source:** `pad_neg_int::%05d`  
**Expected:** `-0042` (sign preserved before zero padding)

---

#### T-212 — Float precision (`%08.2f`)

**Input:** `get("float_prec", 3.14159)`  
**Source:** `float_prec::%08.2f`  
**Expected:** `00003.14`

---

#### T-213 — Negative hexadecimal (`%x`)

**Input:** `get("neg_hex", -42)`  
**Source:** `neg_hex::%x`  
**Expected:** `-2a` (signed magnitude — never two's complement)

---

#### T-214 — Argument count mismatch

**Input:** `get("two_placeholders", "only_one_arg")`  
**Source:** `two_placeholders::%s %s`  
**Expected:** Raises `LexFormatError`.

---

#### T-215 — Unsupported format specifier is literal  

**Input:** `get("invalid_specifier", "test")`  
**Source:** `invalid_specifier::Value: %q`   
**Expected:** `Value: %q` (the argument is simply unused — never an error)

---

#### T-216 — NaN and Infinity in float specifier, lowercase 

**Input:** `get("placeholder_float", NaN)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** `Rating: nan`
**Input:** `get("placeholder_float", Infinity)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** `Rating: inf`

---

#### T-217 — Large float, no scientific notation 

**Input:** `get("placeholder_float", 1e20)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** `Rating: 100000000000000000000.000000`

---

#### T-218 — 64-bit integer limit *(requires 64-bit / bigint support)* 

**Input:** `get("placeholder_integer", 9223372036854775807)`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** `You have 9223372036854775807 messages`  
**Notes:** Uses `2^63 - 1` rather than `2^53` so that precision loss in a `double`-backed implementation is actually detectable

---

#### T-219 — Adjacent percent tokens 

**Input:** `get("adjacent_percent", "Alice")`  
**Source:** `adjacent_percent::%%%%s %s`  
**Expected:** `%%s Alice` (two `%%` collapse to two literal `%`, followed by `%s` expanding)

---

#### T-220 — Extra arguments ignored 

**Input:** `get("one_placeholder", "Alice", "extra_arg")`  
**Source:** `one_placeholder::Hello %s`  
**Expected:** `Hello Alice`

---

#### T-221 — Default float precision 

**Input:** `get("float_default_prec", 3.1)`  
**Source:** `float_default_prec::%f`  
**Expected:** `3.100000` (unspecified precision defaults strictly to 6 decimal places)

---

#### T-222 — Rounding mode: positive tie (`%.0f`) 

**Input:** `get("float_zero_prec", 2.5)`  
**Source:** `float_zero_prec::%.0f`  
**Expected:** `3` (round half away from zero)

---

#### T-223 — String padding and alignment 

**Input:**  `get("string_width_right", "Hi")`  
**Source:** `string_width_right::%5s`  
**Expected:** `"   Hi"` 
**Input:** `get("string_width_left", "Hi")`  
**Source:** `string_width_left::%-5s`  
**Expected:** `"Hi   "`

---

#### T-224 — Zero padding on strings treated as space padding 

**Input:** `get("string_zero_pad", "Hi")`  
**Source:** `string_zero_pad::%05s`  
**Expected:** `"   Hi"` (the `0` flag is ignored for string specifiers, falls back to spaces)

---

#### T-225 — Strict sequential placeholder binding 

**Input:** `get("pos_test", "Alice", 10)`  
**Source:** `pos_test::Hello %s, code %d`  
**Expected:** `Hello Alice, code 10`

---

#### T-226 — Argument injection is never re-parsed 

**Input:** `get("placeholder_string", "%s%d")`  
**Source:** `placeholder_string::Hello %s`  
**Expected:** `Hello %s%d` (the injected argument's own `%` sequences are never interpreted)

---

#### T-227 — Trailing lone `%` at end of template is literal 

**Input:** `get("trailing_percent")`  
**Source:** `trailing_percent::Value ends with %`  
**Expected:** `Value ends with %`

---

#### T-228 — `%d` coercion with a non-numeric argument 

**Input:** `get("placeholder_integer", "abc")`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** Raises `LexFormatError`.

---

#### T-229 — `%c` with Unicode code points above 255 

**Input:** `get("placeholder_char", 8364)`  
**Source:** `placeholder_char::Char: %c`  
**Expected:** `Char: €`

---

#### T-230 — `%i` is an alias for `%d` 

**Input:** `get("i_spec", 42)`  
**Source:** `i_spec::Count: %i`  
**Expected:** `Count: 42`

---

#### T-231 — All unknown specifiers stay literal 

**Input:** `get("unknown_specs", "x")`  
**Source:** `unknown_specs::%u %X %e %g %b %n %p`  
**Expected:** `%u %X %e %g %b %n %p` (none of these are Lexis specifiers)

---

#### T-232 — `%1$s` positional syntax is not supported 

**Input:** `get("positional_attempt_2", "Alice")`  
**Source:** `positional_attempt_2::Hello %1$s`  
**Expected:** `Hello %1$s`

---

#### T-233 — Width is measured in code points, not bytes or UTF-16 units 

**Input:** `get("width_codepoint", "ñ")` (a single code point)  
**Source:** `width_codepoint::%5s`  
**Expected:** `"    ñ"` (4 spaces + 1 character)

---

#### T-234 — Numeric string is valid for `%d` 

**Input:** `get("numeric_string", "42")`  
**Source:** `numeric_string::%d`  
**Expected:** `42`

---

#### T-235 — Negative infinity 

**Input:** `get("placeholder_float", -Infinity)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** `Rating: -inf`

---

#### T-236 — Rounding mode: negative tie 

**Input:** `get("float_zero_prec", -2.5)`  
**Source:** `float_zero_prec::%.0f`  
**Expected:** `-3`

---

#### T-237 — Rounding against the exact binary value 

**Input:** `get("float_two_prec", 1.005)`  
**Source:** `float_two_prec::%.2f`  
**Expected:** `1.00`  
**Notes:** `1.005` is not exactly representable in binary floating point; it's actually slightly below `1.005`, so correct rounding gives `1.00`, not `1.01`.

---

#### T-238 — Float at or above 1e21 

**Input:** `get("placeholder_float", 1e21)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** `Rating: 1000000000000000000000.000000`  
**Notes:** Catches runtimes (e.g. JS `toFixed`) that fall back to exponential notation above this threshold.


---

#### T-239 — `%c` with an invalid code point 

**Input:** `get("placeholder_char", 1114112)` (`0x110000`, past the Unicode range)  
**Source:** `placeholder_char::Char: %c`  
**Expected:** Raises `LexFormatError`.

---

#### T-240 — `%d` with an integral float is valid 

**Input:** `get("placeholder_integer", 3.0)`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** `You have 3 messages`

---

#### T-241 — `%d` with a non-integral float is an error 

**Input:** `get("placeholder_integer", 3.7)`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** Raises `LexFormatError`.

---

### Edge Cases

---

#### T-301 — *retired* (duplicate of T-006)

---

#### T-302 — *retired* (duplicate of T-007)

---

#### T-303 — Triple `::` in value

**Input:** `get("triple_colon")`  
**Source:** `triple_colon::key:::value with triple colon`  
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

**Setup:** Request a locale with no `.lex` file (e.g. `fr`); the default fallback
is `"en"`.
**Expected:** Runtime loads `en.lex` without error.

---

#### T-405 — Load with custom fallback

**Setup:** Call `load(lang_dir, "fr", fallback_locale="pt")` where only `pt.lex`
exists.
**Expected:** `fallback_locale` is set to `"pt"` and `pt.lex` is loaded.

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

#### T-409 — *retired* (duplicate of T-405)

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

#### T-414 — Lazy caching: escape processed only once *(optional, white-box)*

**Setup:**
1. Call `get("escape_newline")` — first access
2. Call `get("escape_newline")` — second access

**Expected:** Both calls return identical output. `_unescape` is called exactly once.
**Notes:** The runtime must not re-process escapes on subsequent calls. This is
a white-box test — it requires instrumenting or inspecting the runtime's
internals, so it's optional for runtimes that can't expose that.

---

#### T-415 — Cache eviction on reload 

**Setup:** Load locale A with key `k1`. Reload to locale B where `k1` is omitted.  
**Input:** `get("k1")`  
**Expected:** Raises `LexKeyNotFoundError` (no stale entries from locale A).

---

#### T-416 — Memory state isolation on failed reload 

**Setup:** Load valid locale. Attempt loading a corrupt `.lex` file.   
**Expected:** Original memory cache remains fully operational and unchanged.

---

#### T-417 — Key case sensitivity 

**Setup:** Load a `.lex` file containing both `KEY::value1` and `key::value2`.  
**Input:** `get("KEY")` vs `get("key")`  
**Expected:** Evaluated as two independent, distinct keys.

---

#### T-418 — Locale code normalization 

**Setup:** Request `es-ES`, `es_ES` or `ES`.  
**Expected:** Normalized to load `es.lex`.

---

#### T-419 — Invalid UTF-8 byte sequence 

**Setup:** Load file containing invalid UTF-8 byte stream.   
**Expected:** Raises `LexParseError`.

---

#### T-420 — Reserved object property key collision *(optional, prototype-based languages only)* 

**Setup:** Load a `.lex` file with keys `toString`, `valueOf`, `__proto__`, and
`constructor`.  
**Input:** `get("toString")`  
**Expected:** Returns the mapped string value without prototype pollution.  
**Notes:** Only meaningful for runtimes whose key storage is a prototype-based
object (JS/TS). Not applicable to a plain hash map / dict.

---

#### T-421 — Multi-instance isolation 

**Setup:** Instantiate `client1` (`en`) and `client2` (`es`) in the same process.  
**Expected:** State and caches of `client1` and `client2` are fully isolated.

---

#### T-422 — Empty or comment-only file 

**Setup:** Load a `.lex` file that is completely empty or contains only comments and blank lines.  
**Expected:** Loads successfully without errors, resulting in an empty translation table (`size = 0`).

---

#### T-423 — Path traversal via locale code 

**Input:** `load(lang_dir, "../secret")`  
**Expected:**  Raises `LexFileNotFoundError`. The locale code fails validation before it ever
reaches the filesystem — the runtime must not reveal whether `../secret.lex` exists.

---

## Compliance Checklist

| Category         | Range             | Tests | Optional | Retired |
| ---------------- | ----------------- | ----- | -------- | ------- |
| Parsing          | `T-001` – `T-020` | 20    | 0        | 0       |
| Escape sequences | `T-101` – `T-113` | 13    | 0        | 0       |
| Placeholders     | `T-201` – `T-241` | 40    | 1        | 0       |
| Edge cases       | `T-301` – `T-303` | 1     | 0        | 2       |
| Conformance      | `T-401` – `T-423` | 20    | 2        | 1       |

A runtime is **fully compliant** when it passes every **Active** case, plus every
**Optional** case its language/environment is actually capable of expressing.
**Retired** IDs are kept as placeholders — they're intentionally not reassigned.

---

*Lexis — Una ley, muchos lenguajes.*