# Lexis Format Specification v1.0

A flat translation format based on printf-style placeholders.
Portable across languages. Designed to stay simple.

> "Lex una, linguae multae."
> *(One law, many languages.)*


## 1. File

### Extension

```text
.lex
```

### Encoding

- UTF-8 required
- A file containing invalid UTF-8 byte sequences MUST raise a parsing error
- No BOM required or emitted by writers
- If a runtime encounters a leading BOM anyway, it MUST strip it silently before parsing
- LF line endings preferred
- CRLF tolerated (see Line endings below)
- The first line is RECOMMENDED to be a comment

> **Note:** Starting a file with a comment line is RECOMMENDED. If a tool that does not handle a BOM reads the file, the BOM ends up inside a comment instead of corrupting the first key.

### Line endings

- Lines are separated by LF (U+000A)
- A CR (U+000D) immediately before an LF belongs to the line ending and MUST be removed before the line is classified or parsed
- The last line of a file MAY end without a line ending
- Any other CR is ordinary content of its line, not a line ending

### Naming

Lexis files are loaded from a language directory, using one of four layouts:

```text
en.lex          # file layout
es/main.lex     # directory layout
es_VE.lex       # regional file layout
en_US/main.lex  # regional directory layout
```

- A Lexis runtime reads exactly one file per locale:
    - `{locale}`.lex
    - `{locale}/{name}`.lex
- `{locale}` is either a bare language code (e.g. `es`) or a regional code (e.g. `es_VE`)
- `{locale}/{name}.lex`: the `{name}` is custom but the default is `main`
- The `.lex` file format is identical in every layout above

### Locale codes

- Canonical form is `{language}_{REGION}`:
    - Lowercase language (e.g. `en`)
    - Uppercase region (e.g. `PT`)
    - Underscore separator (e.g. `es_VE`)
- Input in any other case or separator (e.g. `pt-BR`, `en_us`, `ES_VE`) MUST be normalized to canonical form before any file path is built
- A locale code has exactly one of two shapes: `{language}` or `{language}_{REGION}`. Input that normalizes to any other shape is invalid

### Input validation

`locale`, `fallback_locale` and `name` MUST be validated before any file path is built:

- They MUST contain only letters, digits, `_` or `-`
- They MUST NOT be empty
- A `locale` or `fallback_locale` MUST have one of the two shapes above after normalization

Any invalid value MUST raise `LexFileNotFoundError` without accessing the filesystem. In particular, path separators (`/`, `\`), dots and whitespace are never accepted, so a locale or name can never point outside the language directory.

### Resolution

Resolution is a chain, tried in order, and MUST stop at the first match:

1. `{language}_{REGION}.lex`
2. `{language}_{REGION}/{name}.lex`
3. `{language}.lex`
4. `{language}/{name}.lex`
5. The same steps for `fallback_locale`

- Because the chain is ordered, if both `{locale}.lex` and `{locale}/{name}.lex` exist for the same locale, `{locale}.lex` is the one used
- If a step further down the chain is used, the runtime's `locale` state MUST be updated to the code that was actually resolved
- A project that never uses a regional code is unaffected: `{language}.lex` or `{language}/{name}.lex` resolve exactly as if steps 1 and 2 didn't exist

> **Note:** Locale resolution and fallback behavior are further defined at the runtime level (see `RUNTIME_TEMPLATE.md`).


## 2. Line Types

Every line in a `.lex` file MUST be exactly one of the following.  
A line is classified in this order, and the first rule that matches wins:

1. Empty Line
2. Comment Line
3. Entry Line
4. Invalid Line

So a line such as `# a::b` is a comment, never an entry.

### Empty Line

A line containing only whitespace characters.  
Ignored by the parser.


### Comment Line

A line whose first non-whitespace character is:

```text
#
```

Ignored by the parser.  
Examples:

```text
# Comment
    # Indented comment
```


### Entry Line

A line containing the separator sequence:

```text
::
```

Parsed as a key-value pair.


### Invalid Line

Any line that is not one of the above MUST be treated as malformed and MUST raise a parsing error.


## 3. Entry Format

Format:

```text
key::value
```

The first `::` sequence encountered from the left is the separator.

- Everything before it is the key
- Everything after it is the value

Example:

```text
message::Error: value is :: %s
```

Results in:

- key → `message`
- value → `Error: value is :: %s`

Because the first `::` is the separator, a run of three colons is read as `::` followed by a colon that belongs to the value:

```text
a:::b
```

Results in key `a` and value `:b`.


## 4. Keys

Keys follow these rules:

- MUST be trimmed of leading and trailing whitespace
- MUST NOT be empty after trimming
- MUST be unique within the file
- Duplicate keys MUST raise a parsing error
- Keys are case-sensitive

Examples:

```text
hello
Hello
```

These are considered different keys.  
As a consequence of sections 2 and 3, a key cannot begin with `#` (the line would be a comment) and cannot end with `:` (the colon would be read as part of the separator or the value).

Recommended style:

```text
snake_case
```


## 5. Values

Values follow these rules:

- Left-trimmed only
- Trailing whitespace MUST be preserved
- MAY be empty
- MAY contain additional `::` sequences
- MAY start with `#`
- UTF-8 text allowed without restriction

Examples:

```text
warning::#Careful
path::C:\\Program Files\\Lexis
message::Value :: %s
empty::
```


## 6. Escapes

Escape sequences are processed sequentially from left to right inside values, in a single pass. Replacement output is not recursively rescanned for further escapes.  
The following escape sequences are officially supported:

| Sequence | Result            |
| -------- | ----------------- |
| `\n`     | Newline (LF)      |
| `\t`     | Horizontal tab    |
| `\\`     | Literal backslash |
| `\"`     | Double quote      |
| `\r`     | Carriage return   |
| `\b`     | Backspace         |
| `\v`     | Vertical tab      |

Example:

```text
text::a\\nb
```

Results in `a\nb` (a backslash followed by `n`), not in a line break, because `\\` is consumed first and its output is not scanned again.


### Escape Rules

#### Unknown Escapes

Any unsupported escape sequence:

```text
\x
```

MUST remain unchanged as literal text.

Example:

```text
path::\q
```

Results in:

```text
\q
```


#### Trailing Backslash

A single trailing backslash at the end of a value:

```text
path::C:\
```

MUST be treated as a literal backslash.


## 7. Placeholders

Lexis uses printf-style placeholders for runtime interpolation.  
Lexis is **not** POSIX printf. It defines its own closed grammar, and a runtime
MUST NOT delegate formatting to the host's printf or format facilities.

### 7.1 Grammar

```text
%[-][0][width][.precision]specifier
```

| Part         | Rule                                                              |
| ------------ | ----------------------------------------------------------------- |
| `-`          | Optional. Left-align within the field width                       |
| `0`          | Optional. Zero-pad. MUST come after `-` if both are present       |
| `width`      | Optional. Decimal integer, 0 to `MAX_WIDTH`                       |
| `.precision` | Optional. `.` followed by one or more digits, up to `MAX_PREC`    |
| `specifier`  | One of the table below                                            |

| Specifier    | Type                 |
| ------------ | -------------------- |
| `%s`         | String               |
| `%d` or `%i` | Integer              |
| `%f`         | Float                |
| `%x`         | Hexadecimal          |
| `%o`         | Octal                |
| `%c`         | Character            |
| `%%`         | Literal percent sign |

**Closed grammar rule:** a `%` that does not match this grammar exactly is
literal text, and scanning continues with the next character. Nothing outside
the grammar has any meaning (`%q`, `%X`, `%+d`, `% d`, `%#x`, `%ld`, `%*d`,
`%1$s`, `%.f`, `%0-5d`).  
A precision is valid only with `f`. A precision combined with any other
specifier makes the whole placeholder literal text (`%.3s`, `%.2d`).

### 7.2 Processing Rules

- Escape sequences MUST be processed before placeholder substitution
- `%%` MUST become a literal `%`
- `%%` does NOT count as a placeholder for argument matching
- Placeholder order is positional
- A placeholder is parsed completely before its argument is consumed
- Fewer arguments than placeholders MUST raise a format error
- Extra arguments MUST be ignored
- A substituted argument is inserted as-is and is never processed again for
  escape sequences or placeholders

### 7.3 Padding

- Width is a minimum, measured in Unicode code points
- If the content is longer than the width it is NOT truncated
- `-` takes precedence over `0`
- `0` pads with zeros only for `%d`, `%i`, `%f`, `%x` and `%o`; for `%s` and
  `%c` it is ignored and the padding uses spaces
- With zero padding, the sign comes first: `%05d` of `-42` is `-0042`

### 7.4 Conversions

Any value that cannot be converted as described below MUST raise a format error.  
**`%s`** accepts a string, an integer (written in decimal), or a float (written
as `%f` without a precision). Any other type is a format error. A string
argument that is not valid UTF-8 is a format error.  
**`%d` / `%i`** require an integer in the signed 64-bit range:
- an integer, or
- a float that is finite, has an integral value and is inside the range, or
- a string matching `^-?[0-9]+$` that is inside the range

Range MUST be checked before converting, never after. A float string such as
`"4.0"` is a format error.  
**`%x` / `%o`** use the same conversion as `%d`. Output is lowercase and uses
sign and magnitude, not two's complement (`-42` in `%x` is `-2a`).  
**`%c`** uses the same conversion as `%d`. The value is a Unicode code point
from 1 to 0x10FFFF, excluding the surrogates 0xD800 to 0xDFFF, and the output
is that character. Anything else is a format error.  
**`%f`** accepts an integer, a float, or a string matching
`^-?[0-9]+(\.[0-9]+)?$`. NaN, infinity, and any value with an absolute value of
2^63 or more are format errors.

- Rounding works on the exact binary value of the double. Exact ties round away
  from zero
- With a precision (`%.N`), the output has exactly `N` decimals
- Without a precision, the value is first rounded to 6 decimals, then trailing
  zeros are removed, then a trailing `.` is removed. A value that rounds to
  `0.000000` is written as `0`
- A result that is zero is never written with a minus sign (there is no `-0`
  and no `-0.00`)

### 7.5 Examples

| Format   | Argument       | Result       |
| -------- | -------------- | ------------ |
| `%d%%`   | `50`           | `50%`        |
| `%05d`   | `-42`          | `-0042`      |
| `%-5d\|` | `42`           | `42   \|`    |
| `%5s\|`  | `é`            | `    é\|`    |
| `%s`     | `3.14`         | `3.14`       |
| `%s`     | `3.0`          | `3`          |
| `%x`     | `-42`          | `-2a`        |
| `%c`     | `128075`       | `👋`         |
| `%f`     | `3.14`         | `3.14`       |
| `%f`     | `3.0`          | `3`          |
| `%f`     | `1/3`          | `0.333333`   |
| `%f`     | `0.0000004`    | `0`          |
| `%.7f`   | `0.0000004`    | `0.0000004`  |
| `%.2f`   | `3.1`          | `3.10`       |
| `%.2f`   | `1.005`        | `1.00`       |
| `%.0f`   | `2.5` / `-2.5` | `3` / `-3`   |
| `%.2f`   | `-0.001`       | `0.00`       |

`%.2f` of `1.005` is `1.00` because the nearest double to `1.005` is slightly
below it. The value is not decimal-corrected.

### 7.6 Differences from C printf

A runtime MUST NOT delegate blindly to the host printf. Lexis defines these
behaviors itself:

- Only the grammar in 7.1 exists. Every other C specifier, flag and length
  modifier is literal text
- A precision is accepted only with `f`; with any other specifier the
  placeholder is literal
- Exact ties in `%f` round away from zero (`%.0f` of `2.5` is `3`)
- `%f` without a precision rounds to 6 decimals and removes trailing zeros
  instead of printing 6 decimals
- `%x` and `%o` of negative numbers use sign and magnitude
- `%c` receives a Unicode code point, and width is measured in code points
- `%s` accepts integers and floats as well as strings
- `%d` accepts integers, integral floats and integer strings, and reports a
  format error otherwise
- Fewer arguments than placeholders is a format error, not undefined behavior

### 7.7 Limits

| Constant    | Value |
| ----------- | ----- |
| `MAX_WIDTH` | 1024  |
| `MAX_PREC`  | 15    |

A placeholder whose width or precision is larger than its limit is not valid
and is treated as literal text. Runtimes MUST compare against the limit while
reading the digits, so that a long digit sequence can never overflow an integer.  
These limits are defined here and nowhere else. `FORMAT_SPECIFIERS.md`
references them.

> **Note:** `FORMAT_SPECIFIERS.md` and `TESTS.md` are normative for the remaining edge cases.


## 8. What Lexis Is Not

To preserve simplicity and portability, Lexis deliberately excludes:

- No nesting
- No hierarchies
- No file includes
- No imports
- No true multiline values
- No logic or evaluation
- No conditionals
- No loops
- No namespaces
- No JSON compatibility
- No YAML compatibility
- No XML compatibility
- No INI compatibility
- No pluralization systems
- No positional or named placeholders

> **Note:** Use `\n` for multiline text.


## 9. Versioning

| Version | Meaning                       |
| ------- | ----------------------------- |
| `0.x`   | Development                   |
| `1.0`   | Stable specification          |
| `1.x`   | Revisions made directly to this specification that keep every valid 1.0 file valid |


## 10. Compatibility Test Suite

- The conformance suite is defined by `TESTS.md`, with fixtures in `tests/fixtures/`.
- All compliant runtimes MUST pass every non-optional test of the suite version they claim. A runtime states the suite version it was validated against.


## 11. Philosophy

Lexis prioritizes:

- simplicity
- portability
- predictability
- minimalism

Lexis is intentionally small by design.

The format should remain understandable without external tooling or complex parsing logic.


## 12. Example

```text
# Welcome message
welcome::Welcome %s to Lexis!\nYou have %d new messages.

error_file::Error: file %s not found!

progress::Progress: %d%% completed

total::Total: %.2f

path_example::C:\\Program Files\\Lexis

warning::#Careful
```


## 13. Full Example File

```text
# en.lex - English translations for Lexis v1.0

welcome::Welcome to %s
modules_available::Modules Available
modules_available_list::List of Available Modules
error_file::File not found: %s
with_newline::Line 1\nLine 2
with_tab::Col1\tCol2
with_percent::100%% completed
price::Price: %.2f
unicode_test::Hello 👋 World
```