# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.6.0] - 2026-06-10

### Added
- `docs/DESIGN_DECISIONS.md` — explains major design choices behind Lexis
- `docs/FAQ.md` — frequently asked questions and documentation index
- `CHANGELOG.md` — this file
- Bash runtime: `has()`, `count()`, `clear()`, `info()` helper functions
- Bash runtime: debug helper for development
- Bash runtime: explicit `fallback_locale` support
- Bash runtime: proper eager parsing into associative array
- Bash runtime: `printf`-style formatting in `get()`

### Changed
- **Major Bash runtime overhaul** (`runtimes/bash/lexis.sh`):
  - Renamed/clarified script header
  - Introduced global `LEXIS_*` state variables
  - Added trimming and locale detection functions
  - Improved filepath resolution and error messages
  - Removed old file-cache implementation
  - Cleaned demo entrypoint
- `CONTRIBUTING.md` updated with doc path/name clarifications
- `README.md` updated with API parameter clarifications
- `WORKFLOW.md` updated with API parameter clarifications
- `tests/runtimes/python/test.py` — formatting change to `sys.path.insert`

---

## [0.5.0] - 2026-06-04

### Added
- Configurable `fallback_locale` parameter in `LEX` constructor, `load()`, and `reload()`
- `DESIGN_DECISIONS.md` — explains major design choices behind Lexis
- `FAQ.md` — frequently asked questions and documentation index
- `tests/fixtures/` — shared test fixtures for all runtime implementations
- `tests/TESTS.md` — 52 conformance test cases (T-001 to T-052)
- `tests/runtimes/python/test.py` — official Python test suite
- `get_or_default()` method for safe key access with fallback values
- `__repr__`, `__len__`, `__contains__` convenience methods
- Lazy escape processing with eager validation on load
- Rollback mechanism in `reload()` preserving full state on failure

### Changed
- `fallback_locale` is now explicit parameter (default `"en"`) instead of hardcoded
- `reload()` now accepts optional `fallback_locale` parameter
- `load()` now accepts optional `fallback_locale` parameter
- `_resolve_filepath()` uses configurable `fallback_locale` instead of fixed `"en"`
- `RUNTIME_TEMPLATE.md` expanded with full argument documentation and concurrency note
- `LEX_FORMAT_SPEC.md` updated with escape sequence corrections and naming conventions
- `README.md` expanded with "Why Lexis?" comparison section and project structure
- `WORKFLOW.md` added pre-release checklist and key naming conventions
- `CONTRIBUTING.md` added commit conventions and versioning policy
- `python.md` renamed to `runtime-python.md` for consistency

### Fixed
- `_cache_fetch` docstring: "Raw value" → "Unescaped (processed) value"
- `_parse_line()` now strips `\r\n` for proper CRLF handling
- `reload()` rollback now preserves `lang_dir` and `fallback_locale`
- `_ESCAPE_SEQUENCES` in Python runtime now uses raw strings for clarity
- `repr(lex)` now includes `fallback` state for debugging

---

## [0.4.0] - 2026-05-31

### Added
- `RUNTIME_TEMPLATE.md` — official runtime implementation guidelines
- `LEX_FORMAT_SPEC.md` — formal `.lex` format specification
- `CONTRIBUTING.md` — contribution guidelines and commit conventions
- `WORKFLOW.md` — guide for creating and maintaining `.lex` files
- `python.md` — Python runtime API documentation
- `tests/` directory structure with fixture files
- `empty.lex`, `duplicate_key.lex`, `malformed_line.lex`, `empty_key.lex` test fixtures
- `CHANGELOG.md` (this file)

### Changed
- `README.md` completely revamped with philosophy, features, and project structure
- `lexis.py` refactored with eager parsing and lazy escape processing
- `lexis.sh` rewritten with proper error handling and caching
- `lexis.py` now uses `dict` instead of `SimpleNamespace` for translations
- `lexis.py` `get()` now supports `printf`-style formatting with `*args`

### Fixed
- `lexis.py` `_detect_locale()` now handles `C`, `POSIX`, and empty `LANG`
- `lexis.py` `_parse_line()` now properly splits on first `::` only
- `lexis.sh` `lex_get()` now handles missing keys correctly
- `lexis.sh` `lex_load()` now clears cache on reload

---

## [0.3.0] - 2026-05-29

### Added
- `lexis.py` — Python runtime with `LEX` class
- `lexis.sh` — Bash runtime with associative array caching
- `lang/en.lex` and `lang/es.lex` — example translation files
- `__main__` demo block in `lexis.py`
- `main()` demo function in `lexis.sh`

### Changed
- `README.md` updated with runtime status table and usage examples

---

## [0.2.0] - 2026-05-24

### Added
- `.lex` file format definition with `key::value` separator
- `printf`-style placeholders (`%s`, `%d`, `%f`, `%%`)
- Escape sequences (`\n`, `\t`, `\\`, `\"`)
- UTF-8 support specification
- Automatic locale detection from `$LANG`
- Fallback to `en.lex` when locale file missing

### Changed
- Project renamed from "LEX" to "Lexis"
- `README.md` rewritten with full format specification and philosophy

---

## [0.1.0] - 2026-02-23

### Added
- Initial project structure
- Basic `README.md` with project concept
- MIT License

---

*Lexis — Lex una, linguae multae.*