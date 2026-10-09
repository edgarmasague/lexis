# Lexis · Tests

Official test suite for Lexis runtime compliance.

## Structure

```text
tests/
├── README.md
├── TESTS.md
├── fixtures/
│   ├── aa.lex
│   ├── bb.lex
│   ├── bom.lex
│   ├── cr_inside.lex
│   ├── crlf_trailing.lex
│   ├── crlf.lex
│   ├── duplicate_key.lex
│   ├── empty_key.lex
│   ├── empty.lex
│   ├── en.lex
│   ├── es.lex
│   ├── invalid_utf8.lex
│   ├── malformed_line.lex
│   ├── pt.lex
│   ├── reserved_keys.lex
│   ├── test.lex
│   └── locales/
│       ├── de.lex
│       ├── de/main.lex
│       ├── en.lex
│       ├── es.lex
│       ├── es_VE.lex
│       ├── fr_CA/main.lex
│       └── pt/
│           ├── custom.lex
│           └── main.lex
└── runtimes/
    ├── bash/
    │   └── test.sh
    ├── php/
    │   └── test.php
    ├── python/
    │   └── test.py
    └── ts/
        └── test.ts
```

## Fixtures

Fixtures are plain `.lex` files shared across all runtime implementations.
Each file is self-documented with a header comment indicating which test cases use it.

| File                 | Purpose                                         | Expected behavior on load         |
|----------------------|-------------------------------------------------|-----------------------------------|
| `test.lex`           | Main conformance file                           | ✅ loads successfully             |
| `en.lex`             | Base locale                                     | ✅ loads successfully             |
| `es.lex`             | Secondary locale                                | ✅ loads successfully             |
| `pt.lex`             | Custom fallback locale                          | ✅ loads successfully             |
| `empty.lex`          | Empty valid file                                | ✅ loads with 0 keys              |
| `bom.lex`            | Leading UTF-8 BOM                               | ✅ loads, BOM stripped            |
| `crlf.lex`           | CRLF line endings                               | ✅ loads, no CR in values         |
| `crlf_trailing.lex`  | CRLF, trailing spaces before the CR LF          | ✅ loads, spaces kept, no CR      |
| `cr_inside.lex`      | A lone CR inside a line                         | ✅ loads, the CR is part of the value |
| `reserved_keys.lex`  | Keys such as `toString` and `__proto__`         | ✅ loads successfully             |
| `aa.lex`, `bb.lex`   | Locale A (`k1`) and locale B (`k2`) for T-415   | ✅ load successfully              |
| `duplicate_key.lex`  | Duplicate key                                   | ❌ raises `LexParseError`         |
| `malformed_line.lex` | Missing `::` separator                          | ❌ raises `LexParseError`         |
| `empty_key.lex`      | Empty key after trim                            | ❌ raises `LexParseError`         |
| `invalid_utf8.lex`   | Invalid UTF-8 byte sequence                     | ❌ raises `LexParseError`         |

### Locale fixtures
 
The cases for locale resolution (`T-418`, `T-424` to `T-437`) use a separate directory, `tests/fixtures/locales/`, passed as `lang_dir`. Every file defines one key, `welcome`, whose value identifies the file that was loaded.
 
| File                 | `welcome` value  | Used to check                                  |
|----------------------|------------------|------------------------------------------------|
| `en.lex`             | `en`             | Default fallback                               |
| `es.lex`             | `es`             | Language-only file                             |
| `es_VE.lex`          | `es_VE`          | Regional file layout                           |
| `pt/main.lex`        | `pt (main)`      | Directory layout, default entry-file name      |
| `pt/custom.lex`      | `pt (custom)`    | Custom entry-file name                         |
| `de.lex`             | `de (file)`      | File layout wins over directory layout         |
| `de/main.lex`        | `de (dir)`       | (loses to `de.lex`)                            |
| `fr_CA/main.lex`     | `fr_CA (dir)`    | Regional directory layout                      |

### Fixtures with raw bytes
 
`bom.lex`, `crlf.lex`, `crlf_trailing.lex`, `cr_inside.lex` and `invalid_utf8.lex` only work as tests if their bytes reach the runtime exactly as committed. Because `.gitattributes` normalizes `.lex` files to LF, mark them so Git never converts them:
 
```gitattributes
tests/fixtures/bom.lex            -text
tests/fixtures/crlf.lex           -text
tests/fixtures/crlf_trailing.lex  -text
tests/fixtures/cr_inside.lex      -text
tests/fixtures/invalid_utf8.lex   -text
```
 
Without this, a Windows checkout or an editor can silently turn the CRLF files into LF and the tests would pass without testing anything.
 
## Test IDs
 
Test IDs in `TESTS.md` are grouped by category and are never reassigned:
 
| Range    | Category          |
|----------|-------------------|
| `T-0xx`  | Parsing           |
| `T-1xx`  | Escape sequences  |
| `T-2xx`  | Placeholders      |
| `T-3xx`  | Edge cases        |
| `T-4xx`  | Conformance       |
 
A case that stops being valid is marked *retired* and keeps its ID. A case that changes meaning keeps its ID and its new expected result is documented in `CHANGELOG.md`.

## Running Tests

### Python

```bash
pytest tests/runtimes/python/test.py -v
```

### Bash

```bash
bash tests/runtimes/bash/test.sh
```

### PHP

```bash
php tests/runtimes/php/test.php
```

### TypeScript

```bash
tsx tests/runtimes/ts/test.ts
```

## Adding a New Runtime

1. Create `tests/runtimes/<lang>/test.<ext>`
2. Implement all cases from `TESTS.md` using the fixtures in `fixtures/`
3. Use `fixtures/locales/` as `lang_dir` for the locale cases
4. All active cases must pass, plus every optional case your language can express

## Compliance

See [TESTS.md](TESTS.md) for the full list of test cases and expected outputs, and the compliance checklist at its end.

A runtime is **fully compliant** when it passes every active case, plus every optional case its language and environment can express. Retired cases are not run.

> *Lex una, linguae multae.*