# Contributing to Lexis

Thank you for your interest in contributing.  
Lexis follows the Unix philosophy: simple, explicit, no magic.

---

## Before Contributing

- **Minimalism first.** If the solution requires an external dependency, it probably does not belong here.
- **The `.lex` format is stable from 1.0.** The format does not have breaking versions — Lexis is simple by design.
- **One runtime = one file.** Each runtime must be self-contained and copyable into any project.
- **The contract is `printf`-style.** Every runtime must respect the same placeholders and escapes.

---

## How to Contribute

### Report a Bug

Open an issue with:

- Affected runtime (Bash / Python / other)
- Lexis version
- Minimal `.lex` file that reproduces the problem
- Expected behavior vs. actual behavior

### Propose an Improvement

Open an issue before writing code. Describe:

- The problem it solves
- Why it fits Lexis philosophy
- Whether it affects the `.lex` format or only a runtime

### Submit a Pull Request

```bash
# 1. Fork + clone
git clone https://github.com/your-username/lexis
cd lexis

# 2. Descriptive branch
git checkout -b fix/bash-trim-value
git checkout -b feat/runtime-lua

# 3. Changes + commit
git add -A
git commit -m "fix(bash): replace xargs with parameter expansion in lexis_load"

# 4. Push + PR
git push origin fix/bash-trim-value
```

---

## Commit Conventions

Format: `type(scope): description in imperative`

| Type       | Usage                               |
|------------|-------------------------------------|
| `feat`     | New functionality                   |
| `fix`      | Bug fix                             |
| `docs`     | Documentation only                  |
| `refactor` | Refactoring without behavior change |
| `test`     | Tests or examples                   |
| `chore`    | Maintenance tasks                   |

Common scopes: `bash`, `python`, `format`, `docs`, `tests`

---

## Versioning Policy

| Version | What can change                                 |
|---------|-------------------------------------------------|
| `0.x`   | Everything                                      |
| `0.5`   | Beta — format stabilizing                       |
| `1.0`   | Runtimes, cache, and docs only                  |
| `1.x`   | Runtimes, cache, and docs — no breaking changes |

The `.lex` format has no breaking versions. Simple by design, forever.

---

## Implementing a New Runtime

A Lexis runtime must:

1. Read the `.lex` file line by line in UTF-8
2. Ignore empty lines and comments (`#`)
3. Split `key` and `value` on the **first** `::`
4. Trim the key
5. Store raw values without processing escapes (eager phase)
6. Process escapes (`\n`, `\t`, `\\`, `\"`…) lazily on first access
7. Implement cache for processed values
8. Fall back to a default locale file if the requested locale does not exist

Minimum required interface:

```
load(lang_dir, locale?)
get(key, *args)         →  returns string with substituted placeholders
get_or_default(key, default, *args)  →  string or default
reload(locale?)
keys()                               →  iterable of strings
```

Required error types:

```
LexFileNotFoundError
LexKeyNotFoundError
LexParseError
```

See `docs/RUNTIME_TEMPLATE.md` for the full specification.
 
Once implemented:
 
- Place the file at `runtimes/<lang>/lexis.<ext>`
- Add documentation at `docs/<lang>.md`
- Add an entry to the runtimes table in `README.md`
- Add test implementation at `tests/runtimes/<lang>/test.<ext>`
---
 
## Conformance
 
All runtimes must pass the official test suite located in `tests/fixtures/`.  
See `tests/TESTS.md` for the full list of cases and expected outputs.
 


---

## Conformance
 
All runtimes must pass the official test suite located in `tests/fixtures/`.  
See `tests/TESTS.md` for the full list of cases and expected outputs.
 
---
 
## Code Style
 
Follow the conventions of the language you are implementing.  
Keep the runtime minimal, readable, and dependency-free.
 
For reference implementations see:
 
- `runtimes/bash/lexis.sh`
- `runtimes/python/lexis.py`
---

*Lexis — Lex una, linguae multae.*