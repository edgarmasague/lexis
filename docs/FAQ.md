# Lexis FAQ

## Documentation Index

| Document            | Description                                |
|---------------------|--------------------------------------------|
| README.md           | Introduction to Lexis                      |
| WORKFLOW.md         | Creating and maintaining translation files |
| LEX_FORMAT_SPEC.md  | Official `.lex` specification              |
| FORMAT_SPECIFIERS.md| Exact behavior of every placeholder        |
| RUNTIME_TEMPLATE.md | Runtime implementation requirements        |
| tests/TESTS.md      | Conformance test suite                     |
| DESIGN_DECISIONS.md | Why Lexis was designed this way            |
| FAQ.md              | Frequently asked questions                 |
| CONTRIBUTING.md     | Contributing guidelines                    |
| CHANGELOG.md        | Release history                            |

## What is Lexis?

Lexis is a simple, lightweight, and portable translation format designed for localization files.  
A `.lex` file contains flat translation keys and values:

```text
hello::Hello
welcome::Welcome, %s!
```

The format defines parsing, escaping, placeholder formatting, fallback behavior, and error handling so that different runtimes can provide the same observable behavior.

## Why does Lexis exist?

Lexis is designed to be:

- Simple to read and edit.
- Easy to implement in different languages.
- Predictable across runtimes.
- Free from external runtime dependencies.
- Explicit about parsing and formatting behavior.

The goal is not to replace every existing localization system, but to provide a small and well-defined format where a lightweight solution is useful.

## Is Lexis a replacement for JSON?

No.  
JSON is a general-purpose data format.  
Lexis is specifically designed for translation files.  
Lexis defines translation-specific behavior such as keys, values, escaping, placeholders, fallback resolution, and formatting.

## Is Lexis a replacement for YAML?

No.  
YAML is a general-purpose serialization format.  
Lexis intentionally provides a much smaller feature set focused on translations.

## Is Lexis a replacement for gettext?

No.  
Gettext provides a much larger localization ecosystem, including extraction tools, catalogs, pluralization systems, and translator workflows.  
Lexis intentionally targets a smaller and simpler use case.

## Why does Lexis use flat keys?

Flat keys are simple, predictable and portable.

Example:

```text
auth.login.title
auth.login.button
auth.logout.button
```
The key itself can express structure without requiring nested syntax.

## Why does Lexis not support nesting?

Nested structures add syntax and parsing rules without being necessary for Lexis's core purpose.  
Applications can represent structure directly in their keys when needed.

Example:
```text
menu.file.open::Open
menu.file.close::Close
```

## Why does Lexis not support namespaces?

Lexis keeps the file format intentionally small.  
Namespaces can already be represented through naming conventions.

Example:

```text
auth.login.title
auth.login.button
settings.language.title
```

No special namespace syntax is required.

## Why does Lexis not support imports?

Imports would introduce dependencies between files and additional resolution rules.  
Lexis keeps each `.lex` file self-contained. Applications that need multiple files can load and manage them at the runtime level.

## Why does Lexis not support pluralization?

Pluralization rules vary significantly across languages.  
Lexis does not attempt to define a universal pluralization system. Applications that need pluralization can implement it at a higher level using separate keys or another system.

## Why does Lexis use printf-style placeholders?

Printf-style placeholders such as `%s` and `%d` are familiar to most developers and are available in many languages.  
Lexis defines its own formatting rules instead of relying on the host language's `printf`, ensuring consistent behavior across runtimes.  
See `FORMAT_SPECIFIERS.md` for the complete specification.

## Which placeholders does Lexis support?
 
Lexis supports these placeholders:

| Placeholder    | Meaning                          | Example                        |
| -------------- | -------------------------------- | ------------------------------ |
| `%s`           | String (also integers and floats) | `Hello %s` → `Hello Ana`      |
| `%d` or `%i`   | Integer                          | `%d` of `42` → `42`            |
| `%f`           | Float                            | `%f` of `3.14` → `3.14`        |
| `%x`           | Hexadecimal (lowercase)          | `%x` of `255` → `ff`           |
| `%o`           | Octal                            | `%o` of `8` → `10`             |
| `%c`           | Character from a code point      | `%c` of `65` → `A`             |
| `%%`           | Literal percent sign             | `100%%` → `100%`               |

Each placeholder can have these optional parts, in this order:

```text
%[-][0][width][.precision]specifier
```

`-` left-aligns, `0` pads with zeros, `width` is a minimum width (up to 1024) measured in code points, and `.precision` applies only to `%f` (up to 15). Anything else is literal text.

See `FORMAT_SPECIFIERS.md` for the exact rules.

## Why do `%ld`, `%X`, `%+d` and similar formats stay as literal text?
 
Lexis supports only the placeholder formats explicitly defined by the specification.  
Unsupported formats are treated as literal text rather than being interpreted by the host language's formatting system.  
This keeps formatting behavior consistent across runtimes.

> **Note:** For example, `50% discount` is never read as a placeholder, because `% d` is not part of the grammar.
 
## Why does `%f` of `3.0` give `3`, and not `3.000000`?

Without a precision, `%f` rounds to 6 decimals and then removes trailing zeros, so `3.140000` becomes `3.14` and `3.0` becomes `3`.  
When you need fixed decimals, write the precision: `%.2f` of `3.0` is `3.00`.

## Why does `%f` of `0.0000004` give `0`?

Without a precision, `%f` rounds to 6 decimals first, so values smaller than `0.0000005` become `0`.  
Use an explicit precision to keep more decimals: `%.7f` of `0.0000004` is `0.0000004`. The maximum precision is 15.

 
## Why does `%x` of a negative number give `-2a` and not `ffffffd6`?
 
Lexis formats the sign separately from the hexadecimal digits.  
Therefore, a negative value such as -42 is formatted as:

```text
-2a
```

It does not use a fixed-width two's-complement representation such as:

```text
ffffffd6
```
 
## What does `%s` accept?
 
A string, an integer or a float. An integer is written in decimal, and a float is written the same way `%f` without a precision writes it (`3.14` stays `3.14`, `3.0` becomes `3`).  
Anything else raises a `LexFormatError`: booleans, null, and a string that is not valid UTF-8.
 
## Can a translation reorder its placeholders?
 
No.  
Placeholders are matched to arguments in the order they appear in the translation.  
Lexis has no `%1$s` and no named placeholders, so the argument order is the same in every language.  
If a language needs a different word order, rephrase the sentence so the order works, or split it into two keys.
 
## What happens when there are too few or too many arguments?
 
Fewer arguments than placeholders raise a `LexFormatError`.
Extra arguments are ignored. `%%` never needs an argument.
 
## Are the values I pass in processed for escapes or placeholders?
 
No.  
A value passed as an argument is inserted exactly as it is. A `%s` or a `\n` inside an argument stays as written.  
Escape processing applies only to values loaded from `.lex` files, and placeholder formatting applies when a translation is requested.
 
## Why are keys case-sensitive?

Lexis treats keys exactly as written.

Example:

```text
welcome::
Welcome::
```

> **Note:** These are two different keys.

## Why is the separator `::`?

The separator must be:

- easy to read
- easy to parse
- visually distinct

`::` satisfies these requirements while remaining uncommon in ordinary translation text.

## Can values contain `::`?

Yes.  
Only the first occurrence of `::` is treated as the separator.

Example:

```text
message::Value contains :: inside text
```

Key:

```text
message
```

Value:

```text
Value contains :: inside text
```

## Are spaces at the end of a value kept?
 
Yes.  
Trailing spaces in values are preserved.  
They are part of the value and MUST NOT be silently removed.  
The line ending itself (LF or CRLF) is never part of the value.

## What happens when a key is missing?

The runtime MUST raise a `LexKeyNotFoundError`.  
Returning an empty string is not acceptable.
Most runtimes also provide a helper such as:

```text
get_or_default(key, default)
```

## Can values span multiple lines?

No.  
Each translation entry occupies a single line.  
Use escape sequences instead:

```text
message::Line 1\nLine 2
```

## Does Lexis support Unicode?

Yes.  
Lexis files use UTF-8 encoding.  
This allows keys and values to contain Unicode characters, including accented characters, non-Latin scripts, and emoji.

Example:

```text
welcome::Hola 👋 Mundo
```

A file that contains invalid UTF-8 raises a `LexParseError`.  
When a placeholder has a width (`%5s`), the width is measured in Unicode code points, not in bytes.

## Which locale codes can I use?

A bare language code (`es`) or a language with a region (`es_VE`).  
Other spellings are normalized to that form: `pt-BR` becomes `pt_BR`, and `en_us` becomes `en_US`.  
The locale, the fallback locale and the entry-file name may only contain letters, digits, `_` and `-`, and may not be empty. Anything else, such as a path separator or a dot, raises a `LexFileNotFoundError` before any file is opened. A code with more parts than a language and a region (`es_VE_X`) is also invalid.  
For `es_VE`, the runtime looks for these files in order and stops at the first one that exists:

```text
es_VE.lex
es_VE/main.lex
es.lex
es/main.lex
```

> **Note:** If none exists, it repeats the same steps for the fallback locale (default `en`).

## Can Lexis be used for configuration files?

It can, but that is not its intended purpose.  
Lexis is designed for translations and intentionally provides a limited feature set.  
For general configuration data, a format designed for configuration is usually more appropriate.

## Does Lexis require external dependencies?

No.  
A runtime implementation can be built using the host language's standard library.  
The Lexis format does not require any external dependency.

## What does "The format is the law. The implementation is free." mean?

The Lexis specification defines how `.lex` files behave.  
Runtime authors are free to choose their own implementation details as long as the observable behavior remains compliant with the specification.  
Different runtimes may therefore use different internal designs while still behaving the same way.

## How do I know if a runtime is compliant?

A runtime is compliant when it passes every non-optional test of the conformance suite (`tests/TESTS.md`) for the suite version it claims, and its observable behavior matches the requirements defined by the Lexis specification.  
In particular, it should correctly implement:

- File parsing.
- Key and value handling.
- Escape processing.
- Placeholder formatting.
- Locale and fallback resolution.
- Required error conditions.
- Runtime API behavior defined by RUNTIME_TEMPLATE.md.

The implementation language or internal architecture does not matter as long as the required behavior is preserved.

## What is the long-term goal of Lexis?

The long-term goal is to provide a small, stable, and portable translation format that can be implemented consistently across many languages and environments.  
Lexis prioritizes:

- simplicity
- portability
- predictability
- readability

## Will the `.lex` format change in the future?

Lexis 1.0 defines the stable core format.  
A valid Lexis 1.0 file remains valid throughout the entire 1.x series, without modification. Any change that would break existing `.lex` files requires a new major specification version.  
Future releases may add:

- new runtime implementations
- documentation improvements
- tooling
- conformance tests

> **Note:** The goal is long-term stability rather than adding features for their own sake.

## Still Have Questions?

See:

- `README.md` — Project overview
- `WORKFLOW.md` — Usage and maintenance
- `LEX_FORMAT_SPEC.md` — Formal specification
- `FORMAT_SPECIFIERS.md` — Exact placeholder behavior
- `RUNTIME_TEMPLATE.md` — Runtime requirements
- `tests/TESTS.md` — Conformance test suite
- `DESIGN_DECISIONS.md` — Design rationale
- `CONTRIBUTING.md` — Contribution guidelines