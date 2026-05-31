# Lexis Format Specification v1.0

A flat translation format based on printf-style placeholders.
Portable across languages. Designed to stay simple.

> "Lex una, linguae multae."
> *(One law, many languages.)*

---

# 1. File

## Extension

```text
.lex
```

## Encoding

* UTF-8 required
* No BOM
* LF line endings preferred
* CRLF tolerated

## Naming

Lexis files are named `{locale}.lex` (e.g., `en.lex`, `es.lex`) and loaded from a language directory.
Fallback behavior is runtime-defined.

---

# 2. Line Types

Every line in a `.lex` file MUST be exactly one of the following:

## Empty Line

A line containing only whitespace characters.

Ignored by the parser.

---

## Comment Line

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

---

## Entry Line

A line containing the separator sequence:

```text
::
```

Parsed as a key-value pair.

---

## Invalid Line

Any line that is not one of the above MUST be treated as malformed and MUST raise a parsing error.

---

# 3. Entry Format

Format:

```text
key::value
```

The first `::` sequence encountered from the left is the separator.

* Everything before it is the key
* Everything after it is the value

Example:

```text
message::Error: value is :: %s
```

Results in:

* key → `message`
* value → `Error: value is :: %s`

---

# 4. Keys

Keys follow these rules:

* MUST be trimmed of leading and trailing whitespace
* MUST NOT be empty after trimming
* MUST be unique within the file
* Duplicate keys MUST raise a parsing error
* Keys are case-sensitive

Examples:

```text
hello
Hello
```

These are considered different keys.

Recommended style:

```text
snake_case
```

---

# 5. Values

Values follow these rules:

* Left-trimmed only
* Trailing whitespace MUST be preserved
* MAY be empty
* MAY contain additional `::` sequences
* MAY start with `#`
* UTF-8 text allowed without restriction

Examples:

```text
warning::#Careful
path::C:\\Program Files\\Lexis
message::Value :: %s
empty::
```

---

# 6. Escapes

Escape sequences are processed sequentially from left to right inside values.

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

---

## Escape Rules

### Unknown Escapes

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

---

### Trailing Backslash

A single trailing backslash at the end of a value:

```text
path::C:\
```

MUST be treated as a literal backslash.

---

# 7. Placeholders

Lexis uses printf-style placeholders for runtime interpolation.

All runtimes MUST support the following placeholders:

| Placeholder | Type                 |
| ----------- | -------------------- |
| `%s`        | String               |
| `%d`        | Integer              |
| `%f`        | Float                |
| `%x`        | Hexadecimal          |
| `%o`        | Octal                |
| `%c`        | Character            |
| `%%`        | Literal percent sign |

---

## Placeholder Processing Rules

* Escape sequences MUST be processed before placeholder substitution
* `%%` MUST become a literal `%`
* `%%` does NOT count as a placeholder for argument matching
* Placeholder substitution occurs at runtime
* Placeholder order is positional

Example:

```text
welcome::Welcome %s
progress::Progress: %d%%
```

---

## Optional Format Modifiers

Runtimes MAY support additional printf modifiers such as:

```text
%.2f
%10s
%04d
```

Support for these modifiers is OPTIONAL and runtime-dependent.

---

## Invalid Placeholders

Any unsupported or invalid placeholder sequence MUST be treated as literal text.

Example:

```text
value::%q
```

Results in:

```text
%q
```

---

# 8. What Lexis Is Not

To preserve simplicity and portability, Lexis deliberately excludes:

* No nesting
* No hierarchies
* No file includes
* No imports
* No true multiline values
* No logic or evaluation
* No conditionals
* No loops
* No namespaces
* No JSON compatibility
* No YAML compatibility
* No XML compatibility
* No INI compatibility
* No pluralization systems

Use `\n` for multiline text.

---

# 9. Versioning

| Version | Meaning                       |
| ------- | ----------------------------- |
| `0.x`   | Development                   |
| `1.0`   | Stable core specification     |
| `1.x`   | Backward-compatible additions |

---

# 10. Compatibility Test Suite

The official test file is:

```text
tests/fixtures/test.lex
```

All compliant parsers MUST produce identical key-value outputs for all entries in that file.

---

# 11. Philosophy

Lexis prioritizes:

* simplicity
* portability
* predictability
* minimalism

Lexis is intentionally small by design.

The format should remain understandable without external tooling or complex parsing logic.

---

# 12. Example

```text
# Welcome message
welcome::Welcome %s to Lexis!\nYou have %d new messages.

error_file::Error: file %s not found!

progress::Progress: %d%% completed

path_example::C:\\Program Files\\Lexis

warning::#Careful
```

---

# 13. Full Example File

```text
# en.lex - English translations for Lexis v1.0

welcome::Welcome to %s
modules_available::Modules Available
modules_available_list::List of Available Modules
error_file::File not found: %s
with_newline::Line 1\nLine 2
with_tab::Col1\tCol2
with_percent::100%% completed
unicode_test::Hello 👋 World
```