# Lexis FAQ

# Documentation Index

| Document            | Description                                |
|---------------------|--------------------------------------------|
| README.md           | Introduction to Lexis                      |
| WORKFLOW.md         | Creating and maintaining translation files |
| LEX_FORMAT_SPEC.md  | Official `.lex` specification              |
| RUNTIME_TEMPLATE.md | Runtime implementation requirements        |
| DESIGN_DECISIONS.md | Why Lexis was designed this way            |
| FAQ.md              | Frequently asked questions                 |
| CONTRIBUTING.md     | Contributing guidelines                    |
| CHANGELOG.md        | Release history                            |

---

## What is Lexis?

Lexis is a lightweight, runtime-agnostic translation format and specification.

It separates human-readable text from source code using a simple `key::value` format that can be implemented in any programming language.

---

## Why does Lexis exist?

Most translation systems are tied to a framework, a programming language, or a complex file format.

Lexis focuses on a smaller goal:

Provide a portable, predictable and human-readable translation format that behaves consistently across runtimes.

---

## Is Lexis a replacement for JSON?

No.

JSON is a general-purpose data format.

Lexis is specifically designed for translation files.

If you need structured data, nested objects, arrays, or configuration files, JSON is usually the better choice.

---

## Is Lexis a replacement for YAML?

No.

YAML is a general-purpose serialization format.

Lexis focuses exclusively on translations and intentionally avoids YAML's complexity and parsing rules.

---

## Is Lexis a replacement for gettext?

No.

Gettext provides a much larger localization ecosystem, including extraction tools, catalogs, pluralization systems, and translator workflows.

Lexis intentionally solves a smaller problem with a much smaller specification.

---

## Why does Lexis use flat keys?

Flat keys are simple, predictable and portable.

They avoid implementation-specific behavior and make runtimes easier to implement across different languages.

Example:

```text
auth.login.title
auth.login.button
auth.logout.button
```

---

## Why does Lexis not support nesting?

Nested structures increase parser complexity and often introduce language-specific behavior.

Lexis prioritizes portability and simplicity over hierarchy.

---

## Why does Lexis not support namespaces?

Namespaces can already be represented through naming conventions.

Example:

```text
auth.login.title
auth.login.button
settings.language.title
```

No special namespace syntax is required.

---

## Why does Lexis not support imports?

Lexis files are intentionally self-contained.

This avoids dependency chains between translation files and keeps runtime implementations simple.

---

## Why does Lexis not support pluralization?

Pluralization rules vary significantly across languages.

Instead of embedding language-specific rules into the format, Lexis leaves pluralization to the application layer.

---

## Why does Lexis use printf-style placeholders?

Printf-style placeholders are available in many programming languages including:

* C
* Python
* Bash
* Go
* Rust
* Java
* PHP

Using an existing convention reduces runtime complexity and improves portability.

---

## Why are keys case-sensitive?

Lexis treats keys exactly as written.

For example:

```text
welcome::
Welcome::
```

---

## Why is the separator `::`?

The separator must be:

* easy to read
* easy to parse
* visually distinct

`::` satisfies these requirements while remaining uncommon in ordinary translation text.

---

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

---

## What happens when a key is missing?

The runtime must either:
- raise a `LexKeyNotFoundError`, or
- return the key itself as a fallback string

Returning an empty string is not acceptable.
Most runtimes also provide a helper such as:

```text
get_or_default(key, default)
```

---

## Can values span multiple lines?

No.

Lexis does not support multiline blocks.

Use escape sequences instead:

```text
message::Line 1\nLine 2
```

---

## Does Lexis support Unicode?

Yes.

Lexis files use UTF-8 encoding.

Example:

```text
welcome::Hola 👋 Mundo
```

---

## Can Lexis be used for configuration files?

It can, but that is not its intended purpose.

Lexis is designed for translations.

General configuration formats such as JSON, YAML, or TOML are usually more appropriate for configuration data.

---

## Does Lexis require external dependencies?

No.

The format is intentionally simple and can be implemented using standard language features.

---

## What does "The format is the law. The implementation is free." mean?

The Lexis specification defines how `.lex` files behave.

Runtime authors are free to choose their own implementation details as long as the observable behavior remains compliant with the specification.

---

## How do I know if a runtime is compliant?

A runtime is considered compliant when it passes the official Lexis conformance tests.

See:

* `tests/TESTS.md`
* `LEX_FORMAT_SPEC.md`
* `RUNTIME_TEMPLATE.md`

---

## What is the long-term goal of Lexis?

To remain small.

Lexis prioritizes:

* simplicity
* portability
* predictability
* readability

New features are evaluated against these principles before being added to the specification.

---

## Will the `.lex` format change in the future?

Lexis 1.0 defines the stable core format.

Future releases may add:

* new runtime implementations
* documentation improvements
* tooling
* conformance tests

However, the `.lex` format itself is intended to remain stable.

Valid Lexis 1.0 files should continue to work throughout the entire 1.x series without modification.

Any change that would break existing `.lex` files would require a new major specification version.

---

## Still Have Questions?

See:

- README.md — Project overview
- WORKFLOW.md — Usage and maintenance
- LEX_FORMAT_SPEC.md — Formal specification
- RUNTIME_TEMPLATE.md — Runtime requirements
- DESIGN_DECISIONS.md — Design rationale
- CONTRIBUTING.md — Contribution guidelines