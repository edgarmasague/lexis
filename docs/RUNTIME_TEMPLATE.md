# Lexis Runtime Template v 1.0

> Implement this API in any lang.
> The format is the law. The implementation is free.
> *"Lex una, linguae multae."*

---

## State

The runtime **MUST** maintain these variables:

| Variable              | Type   | Description                                        |
| --------------------- | ------ | -------------------------------------------------- |
| `lang_dir`            | string | Directory containing `.lex` files                  |
| `locale`              | string | Current locale code (e.g., `"en"`)                 |
| `fallback_locale`     | string | Fallback locale code (default: `"en"`)             |
| `_raw_translations`   | map    | Key → raw value, loaded eagerly on `load()`        |
| `_cache_translations` | map    | Key → processed value, populated lazily on `get()` |

### Loading strategy

| Phase    | When                        | What                                                         |
|----------|-----------------------------|--------------------------------------------------------------|
| **Eager**| On `load()` or `reload()`   | Read and validate entire file → populate `_raw_translations` |
| **Lazy** | On first `get()` for a key  | Process escape sequences → store in `_cache_translations`    |


**Lazy escape processing is STRONGLY RECOMMENDED** for performance.
Implementations that process escapes eagerly during load are valid but may experience slower startup on large files.
This guarantees that parse errors and duplicate keys are caught immediately on load,
while escape processing only happens on demand.

---

## Internal Functions

### `_detect_locale() → string`

Detects system locale from environment variable `LANG`.
Handles both `lang_CODE` (underscore) and `lang-CODE` (hyphen) formats.
Returns `"en"` if `LANG` is `C`, `POSIX`, empty, or missing.
Otherwise extracts language code before underscore or hyphen, lowercased.
Returns the system locale only. Fallback resolution is handled by _resolve_filepath.

Examples:

| `$LANG`          | Returns |
|------------------|---------|
| `en_US.UTF-8`    | `"en"`  |
| `pt_BR.UTF-8`    | `"pt"`  |
| `es_ES.UTF-8`    | `"es"`  |
| `pt-BR.UTF-8`    | `"pt"`  |
| `C`              | `"en"`  |
| *(empty)*        | `"en"`  |

---

### `_resolve_filepath(lang_dir, locale, fallback_locale) → string`

Resolves the `.lex` file path.
First attempts `{lang_dir}/{locale}.lex`. If not found, falls back to `{lang_dir}/{fallback_locale}.lex`.
If fallback is used, updates the `locale` state variable to match the fallback.

**Args:**
- `lang_dir` — Directory containing `.lex` files
- `locale` — Requested locale code
- `fallback_locale` — Fallback locale code to try
**Returns:** Absolute path to `.lex` file  
**Raises:** `LexFileNotFoundError` if neither file exists

---

### `_unescape(value) → string`

Processes escape sequences in values.
Called lazily by `_cache_fetch` on first access — never during parsing.

**Args:**
- `value` — Raw value string from `.lex` file (with escapes unprocessed)
**Returns:** Value with escape sequences converted to their actual characters

Supported sequences:

| Sequence | Result          |
| -------- | --------------- |
| `\n`     | newline (LF)    |
| `\t`     | tab             |
| `\\`     | backslash       |
| `\"`     | double quote    |
| `\r`     | carriage return |
| `\b`     | backspace       |
| `\v`     | vertical tab    |

Unknown `\x` sequences pass through literally.
Trailing backslash at end of value is literal.

---

### `_parse_line(raw_line, line_num) → (string, string) | null`

Parses a single line from `.lex` file.
Validates structure and checks for duplicates.
Does **not** process escape sequences — values are stored raw.

**Args:**
- `raw_line` — The raw line string from the file (including line ending characters)
- `line_num` — 1-based line number for error reporting
**Returns:**
- `tuple(key, value)` — For valid entries
- `null` — For empty lines or comments
**Raises:** `LexParseError` — On malformed lines or duplicate keys

Rules:

- Skip empty lines or comments (first non-whitespace is `#`)
- Every valid entry must contain `::` separator
- Split on first occurrence of separator
- Key cannot be empty after trimming
- Duplicate keys are not allowed
- Left-trim the value — store as-is without processing escapes
- Strip line ending characters (`\n`, `\r\n`) before parsing

---

### `_load_file()`

Loads and parses entire `.lex` file into `_raw_translations`.
Clears both `_raw_translations` and `_cache_translations` before loading.
File MUST be read as UTF-8. Invalid UTF-8 sequences raise `LexParseError`.

**Raises:**
- `LexFileNotFoundError` — If file disappears during load
- `LexParseError` — On malformed file content

---

### `_cache_fetch(key) → string`

Fetches value from cache.
On first access, calls `_unescape()` and stores the result in `_cache_translations`.
Subsequent calls return the cached value directly.

**Note:** Lazy escape processing is STRONGLY RECOMMENDED. Implementations may process escapes eagerly during load,
but this may impact startup performance on large `.lex` files.

**Args:**
- `key` — Translation key to look up
**Returns:** Unescaped (processed) value string
**Raises:** `LexKeyNotFoundError` — If key not found in `_raw_translations`

---

## Public API

### `load(lang_dir, locale?, fallback_locale?) → void`

Loads a `.lex` file from the given directory.
Auto-detects locale from environment if not provided.
Falls back to `fallback_locale` (default `"en"`) if the requested locale file does not exist.

**Args:**
- `lang_dir` — Directory containing `.lex` files
- `locale` — Locale code (optional, auto-detected if omitted)
- `fallback_locale` — Fallback locale code (optional, default `"en"`)
**Raises:**
- `LexFileNotFoundError` — if no suitable file is found
- `LexParseError` — if the file is malformed

---

### `get(key, ...args) → string`

Gets translation by key with optional printf-style formatting.
Escape sequences are processed on first access (lazy).

**Args:**
- `key` — Translation key
- `args` — Values for placeholders (`%s`, `%d`, etc.)
**Returns:** Formatted translation string  
**Raises:** `LexKeyNotFoundError` — If key doesn't exist or format fails

Placeholder formatting rules:
- More placeholders than args → raise format error
- More args than placeholders → ignore extra args
- `%%` is processed before counting placeholders (becomes literal `%`)

---

### `get_or_default(key, default, ...args) → string`

Gets translation or returns default if key not found.
If `default` contains placeholders and `args` are provided, applies printf-style formatting to the default as well.

**Args:**
- `key` — Translation key
- `default` — Fallback value
- `args` — Values for placeholders
**Returns:** Formatted translation string or default

---

### `reload(locale?, fallback_locale?) → void`

Reloads translations, optionally switching locale.
Preserves previous state on failure.

**Args:**
- `locale` — New locale code, or `null` to auto-detect
- `fallback_locale` — New fallback locale code, or `null` to keep previous

Behavior:
- Save current state (`lang_dir`, `locale`, `fallback_locale`, `filepath`, `_raw_translations`, `_cache_translations`)
- Try to load new locale
- On failure: restore previous state and raise error

---

### `keys() → iterable<string>`

Returns all available translation keys from `_raw_translations`.
Returns a snapshot (copy) of keys at the time of call, not a live view.

**Returns:** Iterable of key strings

---

## Error Types

The runtime **MUST** provide these error types:

| Error                  | Description                           |
| ---------------------- | ------------------------------------- |
| `LexFileNotFoundError` | No `.lex` file for locale or fallback |
| `LexKeyNotFoundError`  | Key not in loaded translations        |
| `LexParseError`        | Malformed line in `.lex` file         |

## Concurrency Note

Implementations targeting concurrent environments SHOULD ensure thread-safe access to `_cache_translations` during lazy writes.