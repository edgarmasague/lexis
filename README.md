# Lexis · Independent Translation Engine

> *"Lex una, linguae multae."*
> *One law, many languages.*

**Lexis** (from the Greek *Léxis*: word / from the Latin *Lex*: law) is an agnostic, minimalist and lightweight translation system designed under the **Unix** philosophy.

It separates human text from source code using a lightweight `.lex` format based on `key::value` entries and printf-style placeholders.

Designed to work everywhere:

| Runtime | Status     |
| ------- | ---------- |
| Python  | ✅ stable  |
| Bash    | ✅ stable  |
| C       | 🔜 planned |
| Lua     | 🔜 planned |
| JS      | 🔜 planned |

---

## Philosophy

Lexis follows a small and strict philosophy:

| Principle           | Description                                   |
| ------------------- | --------------------------------------------- |
| **Minimalism**      | No JSON, YAML, XML or complex parsing         |
| **Portability**     | Same format across all languages              |
| **Predictability**  | Flat structure, deterministic behavior        |
| **Unix Philosophy** | Small format, simple rules                    |
| **Performance**     | Fast parsing with lightweight implementations |

Lexis intentionally avoids complexity.

No nesting.
No logic.
No imports.
No namespaces.
No magic.

---

## The `.lex` Format

Lexis uses a simple separator:

```text
key::value
```

Example:

```
# lang/es.lex
welcome::Bienvenido a %s
modules_available::Módulos Disponibles
modules_available_list::Lista de Módulos Disponibles
error_file::No se encontró el archivo: %s
```

## Features

* UTF-8 support
* printf-style placeholders
* escape sequences
* automatic locale detection
* fallback locale support
* lazy runtime caching
* runtime agnostic
* zero external dependencies

---

## Placeholders

Lexis uses printf-style placeholders.

| Placeholder | Type                 |
| ----------- | -------------------- |
| `%s`        | String               |
| `%d`        | Integer              |
| `%f`        | Float                |
| `%x`        | Hexadecimal          |
| `%o`        | Octal                |
| `%c`        | Character            |
| `%%`        | Literal percent sign |

Example:

```text
welcome::Welcome %s
progress::Progress: %d%%
```

---

## Escapes

Lexis supports lightweight escape sequences inside values.

| Sequence | Result          |
| -------- | --------------- |
| `\n`     | Newline         |
| `\t`     | Tab             |
| `\\`     | Backslash       |
| `\"`     | Double quote    |
| `\r`     | Carriage return |
| `\b`     | Backspace       |
| `\v`     | Vertical tab    |

Unknown escape sequences remain unchanged.

Example:

```text
multiline::Line 1\nLine 2

path::C:\\Program Files\\Lexis

quote::\"Lex una, linguae multae.\"
```

---

## Example Usage

### Translation File

```text
# lang/en.lex

welcome::Welcome %s
modules_available::Modules Available
error_file::File not found: %s
progress::Progress: %d%%
```
---

## Generic Runtime Usage

Load the `.lex` file using any compatible Lexis runtime.

```text
get("welcome", "Lexis")
→ Welcome Lexis
```

```text
get("modules_available")
→ Modules Available
```

```text
get("error_file", "config.txt")
→ File not found: config.txt
```

```text
get("progress", 80)
→ Progress: 80%
```

### Locale Detection

Lexis automatically detects the system locale from `$LANG`.

```text
$LANG=es_ES.UTF-8
→ loads es.lex
```

If the locale file does not exist, it falls back to en.lex by default (this behavior can be customized in the runtime configuration).

---

## Runtime Behavior

Lexis runtimes follow a strongly recommended hybrid loading strategy:

| Phase  | Strategy                           |
| ------ | ---------------------------------- |
| Load   | Eager parsing and validation       |
| Access | Lazy escape processing and caching |

This ensures:

* malformed files fail immediately
* duplicate keys are detected on load
* runtime lookups remain fast

---

## Project Structure

```text
lexis/
├── docs/
│   ├── LEX_FORMAT_SPEC.md
│   └── RUNTIME_TEMPLATE.md
│
├── lang/
│   ├── en.lex
│   └── es.lex
│
├── runtimes/
│   ├── python/
│   │   └── lexis.py
│   │
│   └── bash/
│       └── lexis.sh
│
├── tests/
│   └── test.lex
│
└── README.md
```

---

## Specification

Official documents:

| Document                  | Description                          |
| ------------------------- | ------------------------------------ |
| `LEX_FORMAT_SPEC.md`      | Official `.lex` format specification |
| `RUNTIME_TEMPLATE.md`     | Runtime implementation guidelines    |

---

## What Lexis Is Not

Lexis deliberately excludes:

* nesting
* imports
* multiline blocks
* logic
* conditionals
* pluralization systems
* namespaces
* heavy serialization formats

Use `\n` for multiline text.

---

## Versioning

| Version | Meaning                       |
| ------- | ----------------------------- |
| `0.x`   | Development                   |
| `1.0`   | Stable core specification     |
| `1.x`   | Backward-compatible additions |

---

## Goal

Lexis is designed to remain understandable without external tooling or complex parsing logic.

The format is the law.
The implementation is free.

---

## License

MIT License

---

*Lexis — Una ley, muchos lenguajes.*