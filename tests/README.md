# Lexis · Tests

Official test suite for Lexis runtime compliance.

---

## Structure

```text
tests/
├── README.md
├── TESTS.md
├── fixtures/
│   ├── test.lex
│   ├── en.lex
│   ├── es.lex
│   ├── empty.lex
│   ├── duplicate_key.lex
│   ├── malformed_line.lex
│   └── empty_key.lex
└── runtimes/
    └── python/
        └── test.py
```

---

## Fixtures

Fixtures are plain `.lex` files shared across all runtime implementations.
Each file is self-documented with a header comment indicating which test cases use it.

| File | Purpose | Expected behavior on load |
|---|---|---|
| `test.lex` | Main conformance file | ✅ loads successfully |
| `en.lex` | Base locale | ✅ loads successfully |
| `es.lex` | Secondary locale | ✅ loads successfully |
| `empty.lex` | Empty valid file | ✅ loads with 0 keys |
| `duplicate_key.lex` | Duplicate key | ❌ raises `LexParseError` |
| `malformed_line.lex` | Missing `::` separator | ❌ raises `LexParseError` |
| `empty_key.lex` | Empty key after trim | ❌ raises `LexParseError` |

---

## Running Tests

### Python

```bash
cd tests/runtimes/python
python test.py
```

### Bash

```bash
# Coming soon
bash tests/runtimes/bash/test.sh
```

---

## Adding a New Runtime

1. Create `tests/runtimes/<lang>/test.<ext>`
2. Implement all cases from `TESTS.md` using the fixtures in `fixtures/`
3. All 51 cases must pass for full compliance

---

## Compliance

See [TESTS.md](TESTS.md) for the full list of test cases and expected outputs.

A runtime is **fully compliant** when all cases from T-001 to T-051 pass.

---

*Lex una, linguae multae.*