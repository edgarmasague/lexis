# Contributing to Lexis

Thank you for your interest in contributing.  
Lexis follows the Unix philosophy: simple, explicit, no magic.

## Before Contributing

- **Minimalism first.** If the solution requires an external dependency, it probably does not belong here.
- **The `.lex` format is stable from 1.0.** A valid 1.0 file stays valid throughout the 1.x series. A change that would break existing files requires a new major version.
- **One runtime = one file.** Each runtime must be self-contained and copyable into any project.
- **The contract is `printf`-style.** Every runtime must respect the same placeholders and escapes.

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

## Versioning Policy

| Version | What can change                                 |
|---------|-------------------------------------------------|
| `0.x`   | Everything                                      |
| `0.5`   | Beta — format stabilizing                       |
| `1.0`   | Runtimes, cache, and docs only                  |
| `1.x`   | Runtimes, cache, and docs — no breaking changes |

The `.lex` format is stable from 1.0: breaking changes require a new major version.

## Implementing a New Runtime

A Lexis runtime must:

1. Read the `.lex` file as UTF-8, reject invalid UTF-8 (`LexParseError`) and strip a leading BOM
2. Split lines on LF, removing the CR of a CRLF pair
3. Classify each line as empty, comment (`#`) or entry, in that order
4. Split `key` and `value` on the first `::`; trim the key, left-trim the value only
5. Reject empty and duplicate keys (`LexParseError`)
6. Store raw values without processing escapes (eager phase)
7. Process escapes in a single pass, lazily on first access, and cache the result
8. Validate `locale`, `fallback_locale` and `name` before building any path, and resolve files through the regional chain with fallback
9. Format placeholders with its own formatter, following `docs/FORMAT_SPECIFIERS.md` (never the host's `printf`)

Minimum required interface:

```
load(lang_dir, locale?, fallback_locale?, name?)
get(key, *args)
get_or_default(key, default, *args)
reload(locale?, fallback_locale?, name?)
has(key) · keys() · len() · info() · clear()
```

Required error types:

```
LexFileNotFoundError
LexKeyNotFoundError
LexParseError
LexFormatError
```

Refer to the "Required Primitives" section of `docs/RUNTIME_TEMPLATE.md` for low-level language prerequisites.
 
Once implemented:
 
- Place the file at `runtimes/<lang>/lexis.<ext>`
- Add documentation at `runtimes/<lang>/README.md`
- Add an entry to the runtimes table in `README.md`
- Add test implementation at `tests/runtimes/<lang>/test.<ext>`
 
## Conformance
 
All runtimes must pass the official test suite located in `tests/fixtures/`.  
See `tests/TESTS.md` for the full list of cases and expected outputs.
 
## Code Style
 
Follow the conventions of the language you are implementing.  
Keep the runtime minimal, readable, and dependency-free.
 
For reference implementations see:
 
- `runtimes/bash/lexis.sh`
- `runtimes/python/lexis.py`

*Lexis — Lex una, linguae multae.*