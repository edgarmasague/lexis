# Lexis · Test Cases

Generic conformance tests for any Lexis runtime implementation.

All runtimes **MUST** pass every case in this document. Retired and optional
cases are marked explicitly — see the Compliance Checklist at the end.    
Test input is `tests/fixtures/test.lex` unless otherwise specified.  
Cases that need another fixture name it explicitly (for example `crlf_trailing.lex`, or the `tests/fixtures/locales/` tree).

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

## Unit Tests

### Parsing

#### T-001 — Simple entry

**Input:** `get("simple")`  
**Source:** `simple::Hello World`  
**Expected:** `Hello World`

#### T-002 — Empty value

**Input:** `get("empty_value")`  
**Source:** `empty_value::`  
**Expected:** *(empty string)*

#### T-003 — Key is trimmed

**Input:** `get("key_trimmed")`  
**Source:** `key_trimmed ::Value with spaces around key`  
**Expected:** `Value with spaces around key`  
> **Notes:** Key `key_trimmed ` (with trailing space) must be stored as `key_trimmed`.

#### T-004 — Uppercase key

**Input:** `get("UPPERCASE_KEY")` 
**Source:** `UPPERCASE_KEY::uppercase key test`  
**Expected:** `uppercase key test`

#### T-005 — Mixed case key

**Input:** `get("mixed_Case_Key")`  
**Source:** `mixed_Case_Key::mixed case key test`  
**Expected:** `mixed case key test`

#### T-006 — Value starting with `#`

**Input:** `get("value_with_hash")`  
**Source:** `value_with_hash::#this value starts with hash`  
**Expected:** `#this value starts with hash`  
> **Notes:** `#` is only a comment marker at the start of a line, not inside a value.

#### T-007 — Value containing `::`

**Input:** `get("value_with_separator")`  
**Source:** `value_with_separator::value :: contains :: separators`  
**Expected:** `value :: contains :: separators`  
> **Notes:** Only the first `::` is the separator. Everything after belongs to the value.

#### T-008 — Leading whitespace in value is trimmed

**Input:** `get("value_leading_spaces")`  
**Source:** `value_leading_spaces::   leading spaces are trimmed`  
**Expected:** `leading spaces are trimmed`

#### T-009 — Trailing whitespace in value is preserved

**Input:** `get("value_trailing_spaces")`  
**Source:** `value_trailing_spaces::trailing spaces are preserved   `  
**Expected:** `trailing spaces are preserved   ` *(3 trailing spaces)*

#### T-010 — Unicode value

**Input:** `get("value_unicode")`  
**Source:** `value_unicode::Hello 👋 World`  
**Expected:** `Hello 👋 World`

#### T-011 — UTF-8 extended characters

**Input:** `get("value_utf8")`  
**Source:** `value_utf8::Héllo Wörld — ñoño`  
**Expected:** `Héllo Wörld — ñoño`

#### T-012 — CRLF line endings

**Input:** `get("crlf_entry")`  
**Source:** `crlf_entry::value without trailing carriage return`  
**Expected:** `value without trailing carriage return`  
> **Notes:** File saved with `\r\n` line endings.

#### T-013 — Indented comments

**Input:** Parse file  
**Source:** File containing `  # indented comment`.  
**Expected:** Line is ignored as a comment without raising `LexParseError`.

#### T-014 — Whitespace around separator

**Input:** `get("key_space")`  
**Source:** `key_space :: value_space`  
**Expected:** `value_space`

#### T-015 — Whitespace-only lines

**Input:** Parse file  
**Source:** Line with `"   "` (3 spaces) and another with \t (tab)  
**Expected:** Lines are treated as empty and skipped without raising `LexParseError`.

#### T-016 — Complex 4-byte UTF-8 sequences

**Input:** `get("emoji_sequence")`  
**Source:** `emoji_sequence::Family: 👨‍👩‍👧‍👦`  
**Expected:** `Family: 👨‍👩‍👧‍👦`

#### T-017 — Extreme trailing whitespace performance

**Input:** `get("huge_spaces")`  
**Source:** `huge_spaces::correct string` followed by 10,000 spaces  
**Expected:** "correct string" + 10,000 trailing spaces preserved  
> **Notes:** Must be processed in linear time $O(N)$ without triggering catastrophic backtracking in regex.

#### T-018 — UTF-8 Byte Order Mark (BOM)

**Input:** `get("first_key")`  
**Source:** `first_key::first_value`, with the file starting with byte sequence
`0xEF, 0xBB, 0xBF`.   
**Expected:** `first_value`  
> **Notes:** The BOM is stripped automatically because it's the very first thing in the file. See `LEX_FORMAT_SPEC.md`, section 1 (Encoding).

#### T-019 — No trailing newline at end of file

**Input:** `get("last_key")`  
**Source:** `last_key::last_value`  
**Expected:** `last_value`  
> **Notes:** File ends with `last_key::last_value` and no final `\n`.

#### T-020 — BOM appearing mid-file

**Input:** `get("mid_bom")`  
**Source:** `mid_bom::prefix_\xEF\xBB\xBF_suffix`, where `<BOM>` is the raw byte sequence
`0xEF, 0xBB, 0xBF` inserted inside the value — not Lexis escape syntax, just the
literal bytes on disk.  
**Expected:** `"prefix_\xEF\xBB\xBF_suffix"`, i.e. the three BOM bytes come back untouched.  
> **Notes:** Byte sequence `0xEF, 0xBB, 0xBF` inserted inside a value, not at the start of the file.
 
#### T-021 — Comment containing `::` is a comment
 
**Input:** Parse file, then `has("comment")`  
**Source:** `# comment::with separator inside a comment`  
**Expected:** Loads without error. `has("comment")` is `false`.

#### T-022 — A line starting with `#` is never an entry
 
**Input:** Parse file, then `has("hidden")` and `has("#hidden")`  
**Source:** `#hidden::comment that looks like an entry`  
**Expected:** Loads without error. Both calls return `false`.
> **Notes:** A key cannot begin with `#`: the whole line is a comment.
 
#### T-023 — Three colons after the key
 
**Input:** `get("colon_run")`  
**Source:** `colon_run:::tail`  
**Expected:** `:tail`
> **Notes:** The first `::` is the separator, so the third colon belongs to the value. Compare T-303, where the three colons are inside the value.
 
#### T-024 — A single colon inside a key
 
**Input:** `get("url:home")`  
**Source:** `url:home::Home page`  
**Expected:** `Home page`
 
#### T-025 — Trailing whitespace before CRLF is preserved
 
**Input:** `get("crlf_trailing")`  
**Source:** `crlf_trailing::value` followed by two spaces, then CR LF (in `crlf_trailing.lex`)  
**Expected:** `"value  "` *(two trailing spaces, no CR)*
> **Notes:** Only the CR that directly precedes the LF is part of the line ending.
 
#### T-026 — A lone CR inside a line is content
 
**Input:** `get("cr_inside")`  
**Source:** `cr_inside::a`, a raw CR byte, `b`, then LF (in `cr_inside.lex`)  
**Expected:** `a` + CR + `b` *(three characters)*
> **Notes:** A CR that is not directly before an LF is not a line ending.


### Escape Sequences

#### T-101 — `\n` newline

**Input:** `get("escape_newline")`  
**Source:** `escape_newline::Line 1\nLine 2`  
**Expected:** `Line 1` + LF + `Line 2`

#### T-102 — `\t` tab

**Input:** `get("escape_tab")`  
**Source:** `escape_tab::Col1\tCol2`  
**Expected:** `Col1` + TAB + `Col2`

#### T-103 — `\\` backslash

**Input:** `get("escape_backslash")`  
**Source:** `escape_backslash::C:\\Program Files\\Lexis`  
**Expected:** `C:\Program Files\Lexis`

#### T-104 — `\"` double quote

**Input:** `get("escape_quote")`  
**Source:** `escape_quote::She said \"hello\"`  
**Expected:** `She said "hello"`

#### T-105 — `\r` carriage return

**Input:** `get("escape_carriage_return")`  
**Source:** `escape_carriage_return::before\rafter`   
**Expected:** `before` + CR + `after`

#### T-106 — `\b` backspace

**Input:** `get("escape_backspace")`  
**Source:** `escape_backspace::before\bafter`  
**Expected:** `before` + BS + `after`

#### T-107 — `\v` vertical tab

**Input:** `get("escape_vertical_tab")`  
**Source:** `escape_vertical_tab::before\vafter`  
**Expected:** `before` + VT + `after`

#### T-108 — Unknown escape passes through literally

**Input:** `get("escape_unknown")`  
**Source:** `escape_unknown::unknown \q escape passes through`  
**Expected:** `unknown \q escape passes through`  
> **Notes:** `\q` is not a recognized sequence and must remain unchanged.

#### T-109 — Trailing backslash is literal

**Input:** `get("escape_trailing_backslash")`  
**Source:** `escape_trailing_backslash::trailing backslash is literal\`  
**Expected:** `trailing backslash is literal\`

#### T-110 — Combined escapes with placeholders

**Input:** `get("escape_combined", "Alice", 99)`  
**Source:** `escape_combined::Name:\t%s\nScore:\t%d`  
**Expected:** `Name:` + TAB + `Alice` + LF + `Score:` + TAB + `99`

#### T-111 —  `\0` is not a recognized escape

**Input:** `get("escape_null")`  
**Source:** `escape_null::before\0after`  
**Expected:** `before\0after` (literal backslash + `0`, two characters — must not produce a NUL byte)

#### T-112 —  Escaped backslash before escape character

**Input:** `get("escape_escaped_n")`  
**Source:** `escape_escaped_n::literal \\n character`  
**Expected:** `literal \n character` (a literal backslash + `n`, NOT a line break)

#### T-113 —  An argument is never re-unescaped

**Input:** `get("passthrough_arg", "a\nb")` where the argument is the literal two characters `\` `n` (not a real newline)  
**Source:** `passthrough_arg::Hello %s`  
**Expected:** `Hello a\nb` — the `\n` inside the *argument* is passed through untouched; unescaping only ever applies to the template pulled from the `.lex` file, never to interpolated arguments.
 
#### T-114 — Escapes are processed before placeholders
 
**Input:** `get("escape_then_percent", "x")`  
**Source:** `escape_then_percent::\\%s`  
**Expected:** `\x` *(a backslash followed by `x`)*
> **Notes:** `\\` becomes one backslash first; then `%s` is formatted as a normal placeholder.


### Placeholders

#### T-201 — `%s` string

**Input:** `get("placeholder_string", "Alice")`  
**Source:** `placeholder_string::Hello %s`  
**Expected:** `Hello Alice`

#### T-202 — `%d` integer

**Input:** `get("placeholder_integer", 3)`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** `You have 3 messages`

#### T-203 — `%f` float

**Input:** `get("placeholder_float", 3.75)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** `Rating: 3.75` *(default float precision)*
> **Notes:** Without a precision, `%f` rounds to 6 decimals and removes trailing zeros (see T-221).

#### T-204 — `%x` hexadecimal

**Input:** `get("placeholder_hex", 255)`  
**Source:** `placeholder_hex::Hex value: %x`  
**Expected:** `Hex value: ff`

#### T-205 — `%o` octal

**Input:** `get("placeholder_octal", 8)`  
**Source:** `placeholder_octal::Octal value: %o`  
**Expected:** `Octal value: 10`

#### T-206 — `%c` character

**Input:** `get("placeholder_char", 65)`  
**Source:** `placeholder_char::Char: %c`  
**Expected:** `Char: A`

#### T-207 — `%%` literal percent

**Input:** `get("placeholder_percent")`  
**Source:** `placeholder_percent::100%% completed`  
**Expected:** `100% completed`  
> **Notes:** `%%` must produce a single `%`. No args needed.

#### T-208 — Multiple placeholders

**Input:** `get("placeholder_multiple", "Alice", 10, 4.5)`  
**Source:** `placeholder_multiple::User %s has %d points and rating %.2f`  
**Expected:** `User Alice has 10 points and rating 4.50`

#### T-209 — Boolean is not an integer

**Input:** `get("bool_spec", true, false)`  
**Source:** `bool_spec::Active: %d, Blocked: %d`  
**Expected:** Raises `LexFormatError`.  
> **Notes:** A boolean is never an integer for Lexis, even in languages where it is one (for example Python).

#### T-210 — Null / Nil is not a valid argument *(optional, requires a `null` type)*

**Input:** `get("null_spec", null)`  
**Source:** `null_spec::Value: %s`  
**Expected:** Raises `LexFormatError`.

#### T-211 — Signed integer zero padding (`%05d`)

**Input:** `get("pad_neg_int", -42)`  
**Source:** `pad_neg_int::%05d`  
**Expected:** `-0042` (sign preserved before zero padding)

#### T-212 — Float precision (`%08.2f`)

**Input:** `get("float_prec", 3.14159)`  
**Source:** `float_prec::%08.2f`  
**Expected:** `00003.14`

#### T-213 — Negative hexadecimal (`%x`)

**Input:** `get("neg_hex", -42)`  
**Source:** `neg_hex::%x`  
**Expected:** `-2a` (signed magnitude — never two's complement)

#### T-214 — Argument count mismatch

**Input:** `get("two_placeholders", "only_one_arg")`  
**Source:** `two_placeholders::%s %s`  
**Expected:** Raises `LexFormatError`.

#### T-215 — Unsupported format specifier is literal  

**Input:** `get("invalid_specifier", "test")`  
**Source:** `invalid_specifier::Value: %q`   
**Expected:** `Value: %q` (the argument is simply unused — never an error)

#### T-216 — NaN and Infinity in float specifier are errors
 
**Input:** `get("placeholder_float", NaN)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("placeholder_float", Infinity)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** Raises `LexFormatError`.

#### T-217 — Large float, no scientific notation
 
**Input:** `get("placeholder_float", 1e18)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** `Rating: 1000000000000000000`
>  **Notes:** `1e18` is below `2^63`, so it is valid. Values at or above `2^63` are errors (see T-238).

#### T-218 — 64-bit integer limit *(requires 64-bit / bigint support)* 

**Input:** `get("placeholder_integer", 9223372036854775807)`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** `You have 9223372036854775807 messages`  
> **Notes:** Uses `2^63 - 1` rather than `2^53` so that precision loss in a `double`-backed implementation is actually detectable

#### T-219 — Adjacent percent tokens 

**Input:** `get("adjacent_percent", "Alice")`  
**Source:** `adjacent_percent::%%%%s %s`  
**Expected:** `%%s Alice` (two `%%` collapse to two literal `%`, followed by `%s` expanding)

#### T-220 — Extra arguments ignored 

**Input:** `get("one_placeholder", "Alice", "extra_arg")`  
**Source:** `one_placeholder::Hello %s`  
**Expected:** `Hello Alice`

#### T-221 — Default float precision 

**Input:** `get("float_default_prec", 3.1)`  
**Source:** `float_default_prec::%f`  
**Expected:** `3.1`
> **Notes:** Unspecified precision rounds to 6 decimals, then removes trailing zeros and a trailing `.`.

#### T-222 — Rounding mode: positive tie (`%.0f`) 

**Input:** `get("float_zero_prec", 2.5)`  
**Source:** `float_zero_prec::%.0f`  
**Expected:** `3` (round half away from zero)

#### T-223 — String padding and alignment 

**Input:**  `get("string_width_right", "Hi")`  
**Source:** `string_width_right::%5s`  
**Expected:** `"   Hi"`   
**Input:** `get("string_width_left", "Hi")`  
**Source:** `string_width_left::%-5s`  
**Expected:** `"Hi   "`

#### T-224 — Zero padding on strings treated as space padding 

**Input:** `get("string_zero_pad", "Hi")`  
**Source:** `string_zero_pad::%05s`  
**Expected:** `"   Hi"` (the `0` flag is ignored for string specifiers, falls back to spaces)

#### T-225 — Strict sequential placeholder binding 

**Input:** `get("pos_test", "Alice", 10)`  
**Source:** `pos_test::Hello %s, code %d`  
**Expected:** `Hello Alice, code 10`

#### T-226 — Argument injection is never re-parsed 

**Input:** `get("placeholder_string", "%s%d")`  
**Source:** `placeholder_string::Hello %s`  
**Expected:** `Hello %s%d` (the injected argument's own `%` sequences are never interpreted)

#### T-227 — Trailing lone `%` at end of template is literal 

**Input:** `get("trailing_percent")`  
**Source:** `trailing_percent::Value ends with %`  
**Expected:** `Value ends with %`

#### T-228 — `%d` coercion with a non-numeric argument 

**Input:** `get("placeholder_integer", "abc")`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** Raises `LexFormatError`.

#### T-229 — `%c` with Unicode code points above 255 

**Input:** `get("placeholder_char", 8364)`  
**Source:** `placeholder_char::Char: %c`  
**Expected:** `Char: €`

#### T-230 — `%i` is an alias for `%d` 

**Input:** `get("i_spec", 42)`  
**Source:** `i_spec::Count: %i`  
**Expected:** `Count: 42`

#### T-231 — All unknown specifiers stay literal 

**Input:** `get("unknown_specs", "x")`  
**Source:** `unknown_specs::%u %X %e %g %b %n %p`  
**Expected:** `%u %X %e %g %b %n %p` (none of these are Lexis specifiers)

#### T-232 — `%1$s` positional syntax is not supported 

**Input:** `get("positional_attempt_2", "Alice")`  
**Source:** `positional_attempt_2::Hello %1$s`  
**Expected:** `Hello %1$s`

#### T-233 — Width is measured in code points, not bytes or UTF-16 units 

**Input:** `get("width_codepoint", "ñ")` (a single code point)  
**Source:** `width_codepoint::%5s`  
**Expected:** `"    ñ"` (4 spaces + 1 character)

#### T-234 — Numeric string is valid for `%d` 

**Input:** `get("numeric_string", "42")`  
**Source:** `numeric_string::%d`  
**Expected:** `42`

#### T-235 — Negative infinity is an error

**Input:** `get("placeholder_float", -Infinity)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** Raises `LexFormatError`.

#### T-236 — Rounding mode: negative tie 

**Input:** `get("float_zero_prec", -2.5)`  
**Source:** `float_zero_prec::%.0f`  
**Expected:** `-3`

#### T-237 — Rounding against the exact binary value 

**Input:** `get("float_two_prec", 1.005)`  
**Source:** `float_two_prec::%.2f`  
**Expected:** `1.00`  
> **Notes:** `1.005` is not exactly representable in binary floating point; it's actually slightly below `1.005`, so correct rounding gives `1.00`, not `1.01`.

#### T-238 — Float at or above 2^63 is an error
 
**Input:** `get("placeholder_float", 9223372036854775808.0)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("placeholder_float", 1e19)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("placeholder_float", 1e21)`  
**Source:** `placeholder_float::Rating: %f`  
**Expected:** Raises `LexFormatError`.
 > **Notes:** Replaces the old "no exponential notation at 1e21" case. Any `%f` argument with an absolute value of `2^63` or more raises `LexFormatError`.

#### T-239 — `%c` with an invalid code point 

**Input:** `get("placeholder_char", 1114112)` (`0x110000`, past the Unicode range)  
**Source:** `placeholder_char::Char: %c`  
**Expected:** Raises `LexFormatError`.

#### T-240 — `%d` with an integral float is valid 

**Input:** `get("placeholder_integer", 3.0)`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** `You have 3 messages`

#### T-241 — `%d` with a non-integral float is an error 

**Input:** `get("placeholder_integer", 3.7)`  
**Source:** `placeholder_integer::You have %d messages`  
**Expected:** Raises `LexFormatError`.

#### T-242 — Unsupported flags are literal

**Input:** `get("lit_flags", 5, 5, 255)`  
**Source:** `lit_flags::%+d|% d|%#x`  
**Expected:** `%+d|% d|%#x`

> **Notes:** `+`, space and `#` are not Lexis flags. The arguments are not consumed and nothing is raised.

#### T-243 — Length modifiers are literal

**Input:** `get("lit_length", 5)`  
**Source:** `lit_length::%ld|%lld|%hd|%zu`  
**Expected:** `%ld|%lld|%hd|%zu`

#### T-244 — `*` width and precision are literal

**Input:** `get("lit_star", 5, 2, 3.14)`  
**Source:** `lit_star::%*d|%.*f`  
**Expected:** `%*d|%.*f`
 
#### T-245 — Precision with a specifier other than `f` is literal
 
**Input:** `get("lit_prec_s", "abcdef", 5)`  
**Source:** `lit_prec_s::%.3s|%.2d`  
**Expected:** `%.3s|%.2d`
 
#### T-246 — Precision without digits is literal
 
**Input:** `get("lit_prec_empty", 3.5)`  
**Source:** `lit_prec_empty::%.f`  
**Expected:** `%.f`
 
#### T-247 — Flags in the wrong order are literal
 
**Input:** `get("lit_flag_order", 5)`  
**Source:** `lit_flag_order::%0-5d`  
**Expected:** `%0-5d`
 
#### T-248 — `% d` inside ordinary text is not a placeholder
 
**Input:** `get("lit_percent_space")`  
**Source:** `lit_percent_space::50% discount`  
**Expected:** `50% discount`
> **Notes:** No argument is passed and no error is raised.
 
#### T-249 — Placeholder cut off by the end of the value is literal
 
**Input:** `get("lit_cut_off_width")`  
**Source:** `lit_cut_off_width::Width cut off %5`  
**Expected:** `Width cut off %5`  
**Input:** `get("lit_cut_off_flags")`  
**Source:** `lit_cut_off_flags::Flags cut off %-0`  
**Expected:** `Flags cut off %-0`
 
#### T-250 — A literal sequence does not consume an argument
 
**Input:** `get("lit_then_real", "x")`  
**Source:** `lit_then_real::%q%s`  
**Expected:** `%qx`
 
#### T-251 — Width at `MAX_WIDTH`
 
**Input:** `get("width_max", 1)`  
**Source:** `width_max::%1024d`  
**Expected:** 1023 spaces followed by `1` *(1024 characters)*
 
#### T-252 — Width above `MAX_WIDTH` is literal
 
**Input:** `get("width_over", 1)`  
**Source:** `width_over::%1025d`  
**Expected:** `%1025d`

#### T-253 — A very long width does not overflow
 
**Input:** `get("width_overflow", 1)`  
**Source:** `width_overflow::%99999999999999999999d`  
**Expected:** `%99999999999999999999d`
> **Notes:** The limit must be checked while reading the digits. The runtime must not crash or wrap around.
 
#### T-254 — Precision at `MAX_PREC`
 
**Input:** `get("prec_max", 0.1)`  
**Source:** `prec_max::%.15f`  
**Expected:** `0.100000000000000`
 
#### T-255 — Precision above `MAX_PREC` is literal
 
**Input:** `get("prec_over", 0.1)`  
**Source:** `prec_over::%.16f`  
**Expected:** `%.16f`  
**Input:** `get("prec_overflow", 1)`  
**Source:** `prec_overflow::%.99999999999999999999f`  
**Expected:** `%.99999999999999999999f`
 
#### T-256 — `-` takes precedence over `0`
 
**Input:** `get("pad_left_zero", 42)`  
**Source:** `pad_left_zero::%-05d|`  
**Expected:** `42   |`
 
#### T-257 — `0` is ignored for `%c`
 
**Input:** `get("pad_char_zero", 65)`  
**Source:** `pad_char_zero::%03c|`  
**Expected:** `"  A|"`
 
#### T-258 — Zero padding with a negative float
 
**Input:** `get("pad_neg_float", -3.14159)`  
**Source:** `pad_neg_float::%08.2f`  
**Expected:** `-0003.14`
> **Notes:** Complements T-212 (positive value). The sign comes before the zeros.
 
#### T-259 — Zero padding with a negative hexadecimal
 
**Input:** `get("pad_neg_hex", -42)`  
**Source:** `pad_neg_hex::%05x`  
**Expected:** `-002a`
 
#### T-260 — Left-aligned float
 
**Input:** `get("pad_left_float", 3.14159)`  
**Source:** `pad_left_float::%-8.2f|`  
**Expected:** `3.14    |`
 
#### T-261 — A value longer than the width is not truncated
 
**Input:** `get("pad_no_truncate", 12345)`  
**Source:** `pad_no_truncate::%2d`  
**Expected:** `12345`

#### T-262 — Width counts a character outside the BMP as one
 
**Input:** `get("width_emoji", "👋")`  
**Source:** `width_emoji::%5s|`  
**Expected:** `"    👋|"`
> **Notes:** Catches runtimes that measure width in UTF-16 code units (JavaScript, Java, C#, Dart).
 
#### T-263 — Width counts code points, not grapheme clusters
 
**Input:** `get("width_combining", "é")` *(`e` followed by U+0301: two code points)*  
**Source:** `width_combining::%5s|`  
**Expected:** 3 spaces, `e`, U+0301, then `|`
> **Notes:** `e` followed by a combining acute accent is two code points, so three spaces are added.
 
#### T-264 — `%s` with an integer
 
**Input:** `get("s_int", -42)`  
**Source:** `s_int::%s`  
**Expected:** `-42`  
**Input:** `get("s_int_min", -9223372036854775808)`  
**Source:** `s_int_min::%s`  
**Expected:** `-9223372036854775808`

#### T-265 — `%s` with a float
 
**Input:** `get("s_float", 3.14)`  
**Source:** `s_float::%s`  
**Expected:** `3.14`  
**Input:** `get("s_float_int", 3.0)`  
**Source:** `s_float_int::%s`  
**Expected:** `3`  
**Input:** `get("s_float_tiny", 0.0000004)`  
**Source:** `s_float_tiny::%s`  
**Expected:** `0`
> **Notes:** A float is written exactly as `%f` without a precision would write it.

#### T-266 — `%s` with a boolean is an error
 
**Input:** `get("s_bool", true)`  
**Source:** `s_bool::%s`  
**Expected:** Raises `LexFormatError`.
 
#### T-267 — `%s` with null is an error *(optional, requires a `null` type)*
 
**Input:** `get("s_null", null)`  
**Source:** `s_null::%s`  
**Expected:** Raises `LexFormatError`.
 
#### T-268 — `%s` with a string that is not valid UTF-8 *(optional, only where such a value can be built)*
 
**Input:** `get("s_bad_utf8", <bytes 0xC3 0x28>)`  
**Source:** `s_bad_utf8::%s`  
**Expected:** Raises `LexFormatError`.
 
#### T-269 — `%d` rejects strings that are not plain integers
 
**Input:** `get("d_str_float", "4.0")`  
**Source:** `d_str_float::%d`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("d_str_plus", "+5")`  
**Source:** `d_str_plus::%d`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("d_str_space", " 5")`  
**Source:** `d_str_space::%d`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("d_str_empty", "")`  
**Source:** `d_str_empty::%d`  
**Expected:** Raises `LexFormatError`.
 
#### T-270 — `%d` at the lower 64-bit limit
 
**Input:** `get("d_int_min", -9223372036854775808)`  
**Source:** `d_int_min::%d`  
**Expected:** `-9223372036854775808`
 
#### T-271 — `%d` outside the 64-bit range is an error
 
**Input:** `get("d_float_big", 1e19)`  
**Source:** `d_float_big::%d`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("d_str_big", "9223372036854775808")`  
**Source:** `d_str_big::%d`  
**Expected:** Raises `LexFormatError`.
 
#### T-272 — `%d` with NaN or Infinity is an error
 
**Input:** `get("d_nan", NaN)`  
**Source:** `d_nan::%d`  
**Expected:** Raises `LexFormatError`.
**Input:** `get("d_inf", Infinity)`  
**Source:** `d_inf::%d`  
**Expected:** Raises `LexFormatError`.

#### T-273 — `%x` and `%o` edge values
 
**Input:** `get("hex_zero", 0)`  
**Source:** `hex_zero::%x`  
**Expected:** `0`  
**Input:** `get("hex_int_min", -9223372036854775808)`  
**Source:** `hex_int_min::%x`  
**Expected:** `-8000000000000000`  
**Input:** `get("oct_neg", -8)`  
**Source:** `oct_neg::%o`  
**Expected:** `-10`

#### T-274 — `%x` uses the same conversion errors as `%d`
 
**Input:** `get("hex_frac", 3.5)`  
**Source:** `hex_frac::%x`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("hex_bad_str", "zz")`  
**Source:** `hex_bad_str::%x`  
**Expected:** Raises `LexFormatError`.

#### T-275 — `%c` with an invalid code point is an error
 
**Input:** `get("char_zero", 0)`  
**Source:** `char_zero::%c`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("char_neg", -1)`  
**Source:** `char_neg::%c`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("char_surr_lo", 55296)`  
**Source:** `char_surr_lo::%c`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("char_surr_hi", 57343)`  
**Source:** `char_surr_hi::%c`  
**Expected:** Raises `LexFormatError`.
> **Notes:** `0` and the surrogates `0xD800`–`0xDFFF` are not valid. T-239 covers the upper limit.
 
#### T-276 — `%c` valid code points
 
**Input:** `get("char_astral", 128075)`  
**Source:** `char_astral::%c`  
**Expected:** `👋`  
**Input:** `get("char_max", 1114111)`  
**Source:** `char_max::%c`  
**Expected:** U+10FFFF  
**Input:** `get("char_numstr", "65")`  
**Source:** `char_numstr::%c`  
**Expected:** `A`
 
#### T-277 — `%c` with a one-character string is an error
 
**Input:** `get("char_str", "A")`  
**Source:** `char_str::%c`  
**Expected:** Raises `LexFormatError`.
 
#### T-278 — `%f` without a precision removes trailing zeros
 
**Input:** `get("f_def_int_valued", 3.0)`  
**Source:** `f_def_int_valued::%f`  
**Expected:** `3`  
**Input:** `get("f_def_hundred", 100.0)`  
**Source:** `f_def_hundred::%f`  
**Expected:** `100`  
**Input:** `get("f_def_sum", 0.30000000000000004)`  
**Source:** `f_def_sum::%f`  
**Expected:** `0.3`  
**Input:** `get("f_def_third", 0.3333333333333333)`  
**Source:** `f_def_third::%f`  
**Expected:** `0.333333`  
**Input:** `get("f_def_round", 1.23456789)`  
**Source:** `f_def_round::%f`  
**Expected:** `1.234568`  
**Input:** `get("f_def_big", 1234567.891)`  
**Source:** `f_def_big::%f`  
**Expected:** `1234567.891`  
**Input:** `get("f_def_intarg", 3)`  
**Source:** `f_def_intarg::%f`  
**Expected:** `3`
 
#### T-279 — `%f` without a precision: tiny values become `0`
 
**Input:** `get("f_def_tiny", 0.0000004)`  
**Source:** `f_def_tiny::%f`  
**Expected:** `0`  
**Input:** `get("f_def_tiny_neg", -0.0000004)`  
**Source:** `f_def_tiny_neg::%f`  
**Expected:** `0`  
**Input:** `get("f_def_negzero", -0.0)`  
**Source:** `f_def_negzero::%f`  
**Expected:** `0`  
**Input:** `get("f_def_edge", 0.000001)`  
**Source:** `f_def_edge::%f`  
**Expected:** `0.000001`
> **Notes:** Values with an absolute value below `0.0000005` are written as `0`, and never as `-0`.
 
#### T-280 — `%.Nf` keeps the requested decimals
 
**Input:** `get("f_prec_small", 0.0000004)`  
**Source:** `f_prec_small::%.7f`  
**Expected:** `0.0000004`  
**Input:** `get("f_prec_pad", 3.0)`  
**Source:** `f_prec_pad::%.2f`  
**Expected:** `3.00`  
**Input:** `get("f_prec_intarg", 1)`  
**Source:** `f_prec_intarg::%.2f`  
**Expected:** `1.00`  
**Input:** `get("f_prec_one", 3.1)`  
**Source:** `f_prec_one::%.2f`  
**Expected:** `3.10`

#### T-281 — Rounding: more ties away from zero
 
**Input:** `get("f_tie_half", 0.5)`  
**Source:** `f_tie_half::%.0f`  
**Expected:** `1`  
**Input:** `get("f_tie_onehalf", 1.5)`  
**Source:** `f_tie_onehalf::%.0f`  
**Expected:** `2`
> **Notes:** Complements T-222 and T-236.
 
#### T-282 — A negative value that rounds to zero has no minus sign
 
**Input:** `get("f_neg_tiny", -0.001)`  
**Source:** `f_neg_tiny::%.2f`  
**Expected:** `0.00`
 
#### T-283 — `%f` with a decimal string
 
**Input:** `get("f_str", "3.14")`  
**Source:** `f_str::%f`  
**Expected:** `3.14`  
**Input:** `get("f_str_exp", "1e5")`  
**Source:** `f_str_exp::%f`  
**Expected:** Raises `LexFormatError`.  
**Input:** `get("f_str_bad", "abc")`  
**Source:** `f_str_bad::%f`  
**Expected:** Raises `LexFormatError`.

#### T-284 — Large float with an explicit precision
 
**Input:** `get("f_big_prec", 9e18)`  
**Source:** `f_big_prec::%.2f`  
**Expected:** `9000000000000000000.00`
> **Notes:** `9e18` is below `2^63` and exactly representable.
 
#### T-285 — `%f` with a boolean is an error
 
**Input:** `get("f_bool", true)`  
**Source:** `f_bool::%f`  
**Expected:** Raises `LexFormatError`.

#### T-286 — `%%s` is literal text and consumes no argument
 
**Input:** `get("pct_pct_s")`  
**Source:** `pct_pct_s::%%s`  
**Expected:** `%s`


### Edge Cases

#### T-301 — *retired* (duplicate of T-006)

#### T-302 — *retired* (duplicate of T-007)

#### T-303 — Triple `::` in value

**Input:** `get("triple_colon")`  
**Source:** `triple_colon::key:::value with triple colon`  
**Expected:** `key:::value with triple colon`


## Conformance Tests

These tests verify runtime behavior beyond key lookup.

#### T-401 — Missing key raises error

**Input:** `get("nonexistent_key")`  
**Expected:** raises `LexKeyNotFoundError`

#### T-402 — Missing key with default

**Input:** `get_or_default("nonexistent_key", "fallback")`  
**Expected:** `fallback`

#### T-403 — Missing key with default and args

**Input:** `get_or_default("nonexistent_key", "Hello %s", "Alice")`  
**Expected:** `Hello Alice`

#### T-404 — Locale fallback (default)

**Setup:** Request a locale with no `.lex` file (e.g. `fr`); the default fallback is `"en"`.
**Expected:** Runtime loads `en.lex` without error.

#### T-405 — Load with custom fallback

**Setup:** Call `load(lang_dir, "fr", fallback_locale="pt")` where only `pt.lex` exists.
**Expected:** `fallback_locale` is set to `"pt"` and `pt.lex` is loaded.

#### T-406 — Reload switches locale

**Setup:**
1. Load locale `es`
2. Call `get("welcome", "Alice")` → verify Spanish output
3. Call `reload("en")`
4. Call `get("welcome", "Alice")` → verify English output

**Expected:** Output changes after reload.

#### T-407 — Reload changes fallback locale

**Setup:**
1. Load locale `en` with fallback `en`
2. Call `reload(fallback_locale="es")`
3. Verify `fallback_locale` is now `"es"`

**Expected:** Fallback locale changes after reload.

#### T-408 — Reload rollback on failure

**Setup:**
1. Load a valid locale
2. Call `reload("nonexistent_locale_xyz")`

**Expected:** Previous translations remain available after the failed reload.

#### T-409 — *retired* (duplicate of T-405)

#### T-410 — Duplicate key raises error

**Setup:** Load a `.lex` file containing:

```text
hello::First
hello::Second
```

**Expected:** `LexParseError` is raised.

#### T-411 — Malformed line raises error

**Setup:** Load a `.lex` file containing:

```text
this line has no separator
```

**Expected:** `LexParseError` is raised.

#### T-412 — Empty key raises error

**Setup:** Load a `.lex` file containing:

```text
::value with no key
```

**Expected:** `LexParseError` is raised.

#### T-413 — File not found raises error

**Setup:** Call `load("nonexistent/path", "en")`  
**Expected:** `LexFileNotFoundError` is raised.

#### T-414 — Lazy caching: escape processed only once *(optional, white-box)*

**Setup:**
1. Call `get("escape_newline")` — first access
2. Call `get("escape_newline")` — second access

**Expected:** Both calls return identical output. `_unescape` is called exactly once.
> **Notes:** The runtime must not re-process escapes on subsequent calls. This is a white-box test — it requires instrumenting or inspecting the runtime's internals, so it's optional for runtimes that can't expose that.

#### T-415 — Cache eviction on reload 

**Setup:** Load locale A with key `k1`. Reload to locale B where `k1` is omitted.  
**Input:** `get("k1")`  
**Expected:** Raises `LexKeyNotFoundError` (no stale entries from locale A).

#### T-416 — Memory state isolation on failed reload 

**Setup:** Load valid locale. Attempt loading a corrupt `.lex` file.   
**Expected:** Original memory cache remains fully operational and unchanged.

#### T-417 — Key case sensitivity 

**Setup:** Load a `.lex` file containing both `KEY::value1` and `key::value2`.  
**Input:** `get("KEY")` vs `get("key")`  
**Expected:** Evaluated as two independent, distinct keys.

#### T-418 — Locale code normalization 

**Setup:** `lang_dir` contains only `es.lex` for Spanish (no `es_ES` file). Request `es-ES`, `es_ES` and `ES`.  
**Expected:** The codes are normalized to `es_ES`, `es_ES` and `es`. Each request resolves to `es.lex`, and `info().locale` is `"es"`.  
> **Notes:** See T-426 to T-428 for regional files and the resolution chain.

#### T-419 — Invalid UTF-8 byte sequence 

**Setup:** Load file containing invalid UTF-8 byte stream.   
**Expected:** Raises `LexParseError`.

#### T-420 — Reserved object property key collision *(optional, prototype-based languages only)* 

**Setup:** Load a `.lex` file with keys `toString`, `valueOf`, `__proto__`, and `constructor`.  
**Input:** `get("toString")`  
**Expected:** Returns the mapped string value without prototype pollution.  
> **Notes:** Only meaningful for runtimes whose key storage is a prototype-based object (JS/TS). Not applicable to a plain hash map / dict.

#### T-421 — Multi-instance isolation 

**Setup:** Instantiate `client1` (`en`) and `client2` (`es`) in the same process.  
**Expected:** State and caches of `client1` and `client2` are fully isolated.

#### T-422 — Empty or comment-only file 

**Setup:** Load a `.lex` file that is completely empty or contains only comments and blank lines.  
**Expected:** Loads successfully without errors, resulting in an empty translation table (`size = 0`).

#### T-423 — Path traversal via locale code 

**Input:** `load(lang_dir, "../secret")`  
**Expected:**  Raises `LexFileNotFoundError`. The locale code fails validation before it ever reaches the filesystem — the runtime must not reveal whether `../secret.lex` exists.
 
#### T-424 — Invalid locale codes are rejected
 
**Input:** `load(lang_dir, locale)` with `locale` set to each of: `"../secret"`, `"es/.."`, `"es\x"` (a backslash), `"es.x"`, `""`, `"es_VE_X"`, `"es VE"`.  
**Expected:** Each call raises `LexFileNotFoundError`.  
> **Notes:** Validation happens before any path is built. Extends T-423. That the filesystem is never touched is a white-box property and cannot be checked from the outside.
 
#### T-425 — Invalid fallback locale and entry-file name are rejected
 
**Setup:** `lang_dir` is `tests/fixtures/locales/` (it contains `es.lex`).  
**Input:**
- `load(lang_dir, "es", fallback_locale="../x")`
- `load(lang_dir, "es", name="../main")`
- `load(lang_dir, "es", name="")`
- `load(lang_dir, "es", name="a/b")`

**Expected:** Each call raises `LexFileNotFoundError`, even though `es.lex` exists.  
> **Notes:** All inputs are validated before the first file is looked up.

#### T-426 — Regional locale code normalization

**Setup:** `lang_dir` is `tests/fixtures/locales/`.  
**Input:** load with `locale` set to each of `"es-VE"`, `"es_ve"` and `"ES_VE"`, then call `get("welcome")` and `info()`.  
**Expected:** `get("welcome")` returns `es_VE` and `info().locale` is `"es_VE"` in all three cases.

#### T-427 — Regional file layout
 
**Setup:** `lang_dir` is `tests/fixtures/locales/`. Call `load(lang_dir, "es_VE")`.  
**Expected:** `get("welcome")` returns `es_VE`. `info().locale` is `"es_VE"`.

#### T-428 — A regional locale falls back to its language
 
**Setup:** `lang_dir` is `tests/fixtures/locales/` (there is no `es_AR` file). Call `load(lang_dir, "es_AR")`.  
**Expected:** `get("welcome")` returns `es`. `info().locale` is `"es"`.  
> **Notes:** The `locale` state follows the file that was actually resolved.

#### T-429 — Directory layout with the default entry-file name
 
**Setup:** `lang_dir` is `tests/fixtures/locales/`. Call `load(lang_dir, "pt")`.  
**Expected:** `get("welcome")` returns `pt (main)`.

#### T-430 — Custom entry-file name
 
**Setup:** `lang_dir` is `tests/fixtures/locales/`. Call `load(lang_dir, "pt", name="custom")`.  
**Expected:** `get("welcome")` returns `pt (custom)`. `info().name` is `"custom"`.

#### T-431 — The file layout wins over the directory layout
 
**Setup:** `lang_dir` is `tests/fixtures/locales/`, which contains both `de.lex` and `de/main.lex`. Call `load(lang_dir, "de")`.  
**Expected:** `get("welcome")` returns `de (file)`.

#### T-432 — Regional directory layout
 
**Setup:** `lang_dir` is `tests/fixtures/locales/`. Call `load(lang_dir, "fr_CA")`.
**Expected:** `get("welcome")` returns `fr_CA (dir)`.

#### T-433 — The fallback locale follows its own shape
 
**Setup:** `lang_dir` is `tests/fixtures/locales/` (there is no `ja` file). Call `load(lang_dir, "ja", fallback_locale="es_VE")`.  
**Expected:** `get("welcome")` returns `es_VE`. `info().locale` is `"es_VE"`.

#### T-434 — `locale` state follows the resolved fallback
 
**Setup:** `lang_dir` is `tests/fixtures/locales/` (there is no `ja` file). Call `load(lang_dir, "ja")` with the default fallback.  
**Expected:** `get("welcome")` returns `en`. `info().locale` is `"en"`.
 
#### T-435 — `reload()` keeps the entry-file name when it is omitted
 
**Setup:** `lang_dir` is `tests/fixtures/locales/`.
1. `load(lang_dir, "pt", name="custom")`
2. `reload("pt")`
3. `get("welcome")`
4. `reload("../x")` (invalid, fails)
5. `get("welcome")` and `info().name`
**Expected:** Step 3 returns `pt (custom)`. After the failed reload in step 4, step 5 still returns `pt (custom)` and `info().name` is `"custom"`.
 
#### T-436 — `reload()` keeps the locale when it is omitted
 
**Setup:** `lang_dir` is `tests/fixtures/locales/`.
1. `load(lang_dir, "es_VE")`
2. `reload(fallback_locale="en")`
3. `get("welcome")` and `info().locale`
**Expected:** `get("welcome")` returns `es_VE` and `info().locale` is `"es_VE"`.  
> **Notes:** An omitted (or `null`) `locale` keeps the current one. It does not trigger auto-detection.
 
#### T-437 — Locale auto-detection from `LANG` *(optional, requires setting the environment)*
 
**Setup:** `lang_dir` is `tests/fixtures/locales/`. For each `LANG` value, call `load(lang_dir)` without a locale and read `info().locale`.
 
| `LANG`               | `info().locale` | `get("welcome")` |
| -------------------- | --------------- | ---------------- |
| `es_VE.UTF-8`        | `es_VE`         | `es_VE`          |
| `es_VE@euro`         | `es_VE`         | `es_VE`          |
| `C.UTF-8`            | `en`            | `en`             |
| `POSIX`              | `en`            | `en`             |
| *(empty)*            | `en`            | `en`             |
| `zh_Hans_CN.UTF-8`   | `en`            | `en`             |
 
**Expected:** As shown in the table.  
> **Notes:** `zh_Hans_CN` is reduced to `zh_CN`. No `zh_CN` or `zh` file exists, so the fallback `en` is used and no error is raised.


## Compliance Checklist

| Category         | Range             | Tests | Optional | Retired |
| ---------------- | ----------------- | ----- | -------- | ------- |
| Parsing          | `T-001` – `T-026` | 26    | 0        | 0       |
| Escape sequences | `T-101` – `T-114` | 14    | 0        | 0       |
| Placeholders     | `T-201` – `T-286` | 83    | 3        | 0       |
| Edge cases       | `T-301` – `T-303` | 1     | 0        | 2       |
| Conformance      | `T-401` – `T-437` | 33    | 3        | 1       |

A runtime is **fully compliant** when it passes every **Active** case, plus every **Optional** case its language/environment is actually capable of expressing.
**Retired** IDs are kept as placeholders — they're intentionally not reassigned.

> *Lexis — Una ley, muchos lenguajes.*