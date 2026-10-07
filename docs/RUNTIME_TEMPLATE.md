# Lexis Runtime Template

> Implement this API in any lang.
> The format is the law. The implementation is free.
> *"Lex una, linguae multae."*

## State

The runtime **MUST** maintain these variables:

| Variable              | Type   | Description                                        |
| --------------------- | ------ | -------------------------------------------------- |
| `lang_dir`            | string | Directory containing `.lex` files                  |
| `locale`              | string | Current locale code (e.g., `"en"`)                 |
| `fallback_locale`     | string | Fallback locale code (default: `"en"`)             |
| `name`                | string | Entry-file name for the directory layout (default: `"main"`) |
| `filepath`            | string | Path of the loaded .lex file                 |
| `_raw_translations`   | map    | Key → raw value, loaded eagerly on `load()`        |
| `_cache_translations` | map    | Key → processed value, populated lazily on `get()` |

### Loading strategy

| Phase    | When                        | What                                                         |
|----------|-----------------------------|--------------------------------------------------------------|
| **Eager**| On `load()` or `reload()`   | Read and validate entire file → populate `_raw_translations` |
| **Lazy** | On first `get()` for a key  | Process escape sequences → store in `_cache_translations`    |


**Lazy escape processing is STRONGLY RECOMMENDED** for performance.  
Eager processing during load is valid but may slow down startup for large files.  
Parse errors and duplicate keys MUST be detected on load. Escapes MUST be processed on demand.  
The cache MUST store the value after escape processing and before placeholder formatting. Formatting runs on every `get()`, because it depends on the arguments.

## Required Primitives
 
Every runtime needs the following building blocks. Some languages provide them; others need a
small helper. They MUST NOT be replaced by the host's `printf` family (see `FORMAT_SPECIFIERS.md`).
 
| Primitive                | Needed for                                  | Notes                                                                   |
| ------------------------ | ------------------------------------------- | ----------------------------------------------------------------------- |
| Code point count         | Width of `%s`, `%c`, and all padding        | Count Unicode code points, not bytes, UTF-16 units or grapheme clusters |
| UTF-8 validation         | File loading, `%s` arguments                | Reject overlong forms, surrogates and values above U+10FFFF             |
| UTF-8 encoding           | `%c`                                        | Encode one code point                                                   |
| Signed 64-bit integers   | `%d` `%i` `%x` `%o` `%c`                    | A float-backed number type is not enough                                |
| Bits of a double         | `%f`                                        | Sign, exponent and mantissa of an IEEE 754 double                       |
| 128-bit unsigned integer | `%f`                                        | Or a big-integer type. The largest intermediate value is below 2^113    |
| Correctly rounded parse  | `%f` with a decimal string argument         | Decimal string to nearest double                                        |

## Internal Functions

### `_detect_locale() → string`

Detects the system locale from the `LANG` environment variable.

- Supports `lang_CODE` and `lang-CODE` formats.
- Ignores everything after the first `.` or `@` (encoding or modifier).
- Returns `"en"` when `LANG` is `C`, `POSIX`, empty, or missing.
- Otherwise, extracts the language and optional region, normalized as `language_REGION` (lowercase language, uppercase region).
- If the extracted code contains more than two parts (e.g., `zh_Hans_CN`), only the language and region are retained as `language_REGION`.
- Fallback resolution, including the language-only step of the regional chain, is handled by `_resolve_filepath`.



Examples:

| `$LANG`          | Returns    |
|------------------|------------|
| `en_US.UTF-8`    | `"en_US"`  |
| `pt_BR.UTF-8`    | `"pt_BR"`  |
| `es_ES.UTF-8`    | `"es_ES"`  |
| `pt-BR.UTF-8`    | `"pt_BR"`  |
| `es.UTF-8`       | `"es"`     |
| `C.UTF-8`        | `"en"`     |
| *(empty)*        | `"en"`     |

### `_resolve_filepath(lang_dir, locale, fallback_locale, name) → string`

Resolves the `.lex` file path after validating and normalizing the inputs.
- `locale`, `fallback_locale`, and `name` MUST contain only letters, digits, `_`, or `-`, and MUST NOT be empty.
- After normalization, `locale` and `fallback_locale` MUST have the shape `{language}` or `{language}_{REGION}`; any other shape is invalid.
- Invalid values MUST raise `LexFileNotFoundError` without accessing the filesystem.

**Regional locale** (`es_VE`):
1. `{lang_dir}/es_VE.lex`
2. `{lang_dir}/es_VE/{name}.lex`
3. `{lang_dir}/es.lex`
4. `{lang_dir}/es/{name}.lex`

**Language-only locale** (`es`):
1. `{lang_dir}/es.lex`
2. `{lang_dir}/es/{name}.lex`

> **Note:** After the requested locale's steps, apply the same steps to `fallback_locale`, following its own shape (regional or language-only).

If the file found belongs to a different code than the requested `locale` (the language-only step of a regional locale, or any step of `fallback_locale`), `locale` MUST be updated to that code.

**Args:**
- `lang_dir` — Directory containing `.lex` files.
- `locale` — Requested locale code.
- `fallback_locale` — Fallback locale code.
- `name` — Entry-file name for the directory layout (optional, default "main") 

**Returns:** Absolute path to `.lex` file   
**Raises:** `LexFileNotFoundError` if neither file exists or an input is invalid

### `_unescape(value) → string`

Processes escape sequences in values.
- Called lazily by `_cache_fetch` on first access — never during parsing.
- Processing is a single left-to-right pass. Replacement output MUST NOT be processed again.
- Therefore, `\\n` produces a backslash followed by `n`, not a line break.

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

> **Note:** Unknown `\x` sequences pass through literally.
> Trailing backslash at end of value is literal.

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

**Rules:**

- Remove the line ending first: an LF, and a CR directly before it. Any other CR stays in the line
- Classify the line in this order: empty (only whitespace), comment (first non-whitespace is `#`), entry (contains `::`), otherwise malformed
- Skip empty lines and comments
- Split on the first occurrence of `::`
- Trim the key; it cannot be empty
- Duplicate keys are not allowed
- Left-trim the value only (trailing whitespace is kept) and store it raw

### `_load_file()`

Loads and parses the entire `.lex` file into `_raw_translations`.

- MUST clear `_raw_translations` and `_cache_translations` before loading.
- MUST read the file as UTF-8.
- Invalid UTF-8 sequences MUST raise `LexParseError`.
- A leading BOM MUST be removed before parsing the first line.
- The last line MAY end without a line ending.

**Raises:**
- `LexFileNotFoundError` — If file disappears during load
- `LexParseError` — On malformed file content

### `_cache_fetch(key) → string`

Fetches a value from the cache.

- On first access, calls `_unescape()` and stores the result in `_cache_translations`.
- Subsequent calls return the cached value directly.

> **Note:** Lazy escape processing is STRONGLY RECOMMENDED for performance. Eager processing during load is valid but may slow down startup for large .lex files.

**Args:**
- `key` — Translation key to look up

**Returns:** Unescaped (processed) value string

**Raises:** `LexKeyNotFoundError` — If key not found in `_raw_translations`

## Public API
**A conformant runtime exposes these nine operations.**

### `load(lang_dir, locale?, fallback_locale?, name?) → void`

Loads a `.lex` file from the given directory.

- If `locale` is not provided, detects it from the environment.
- If the requested locale is not found, falls back to `fallback_locale` (default: `"en"`).

**Args:**
- `lang_dir` — Directory containing `.lex` files
- `locale` — Locale code (optional, auto-detected if omitted)
- `fallback_locale` — Fallback locale code (optional, default `"en"`)
- `name` — Entry-file name for the directory layout (optional, default "main")

**Raises:**
- `LexFileNotFoundError` — if no suitable file is found or an input is invalid
- `LexParseError` — if the file is malformed

### `get(key, ...args) → string`

Gets a translation by key with optional `printf`-style formatting.

- Escape sequences are processed lazily on first access.
- Placeholders are formatted with the provided arguments.

**Args:**
- `key` — Translation key
- `args` — Values for placeholders (`%s`, `%d`, etc.)

**Returns:** Formatted translation string  

**Raises:**
- `LexKeyNotFoundError` — If key doesn't exist
- `LexFormatError` — If formatting fails (see below)

**Placeholder formatting rules:**
- More placeholders than args → raise `LexFormatError`
- More args than placeholders → ignore extra args
- An argument that is invalid for its specifier (for example a non-integer string for %d, or an invalid code point for %c) → raise LexFormatError
- A `%` sequence that does not match the placeholder grammar stays as literal text and consumes no argument
- A substituted argument is never scanned again for escapes or placeholders
- `%%` is processed before counting placeholders (becomes literal `%`)

> **Notes:** Format semantics are defined in `LEX_FORMAT_SPEC.md` (section 7) and `FORMAT_SPECIFIERS.md`.

### `get_or_default(key, default, ...args) → string`

Gets a translation by key, or returns `default` if the key is not found.

- If the key exists, behaves exactly like `get(key, ...args)`, including formatting rules and `LexFormatError` conditions.
- If the key exists, `default` is ignored.
- If the key does not exist, returns `default`.
- If `default` contains placeholders and `args` are provided, the same `printf`-style formatting is applied to `default`.


**Args:**
- `key` — Translation key
- `default` — Fallback value
- `args` — Values for placeholders

**Returns:** Formatted translation string or default

### `reload(locale?, fallback_locale?, name?) → void`

Reloads translations, optionally switching locale.
Preserves previous state on failure.

**Args:**
- `locale` — New locale code; omit or pass `null` to keep the current locale
- `fallback_locale` — New fallback locale code, or `null` to keep previous
- `name` — New entry-file name; omit to keep the current name

Behavior:
- Save current state (`lang_dir`, `locale`, `fallback_locale`, `filepath`, `_raw_translations`, `_cache_translations`, `name`)
- Try to load new locale
- On failure: restore previous state and raise error

### `has(key) → bool`

Returns whether `key` exists in `_raw_translations`.
Never raises for a missing key and never touches `_cache_translations`.

### `keys() → iterable<string>`

Returns all available translation keys from `_raw_translations`.  
Returns a snapshot (copy) of keys at the time of call, not a live view.

**Returns:** Iterable of key strings
 
### `len() → integer`
 
Returns the number of keys in `_raw_translations`.
An empty or comment-only file yields `0`.
 
### `info() → record`
 
Returns a snapshot of the runtime state as a map, struct or object, with these fields:
 
| Field             | Type    | Description                                     |
| ----------------- | ------- | ----------------------------------------------- |
| `locale`          | string  | Locale currently loaded                         |
| `fallback_locale` | string  | Fallback locale                                 |
| `lang_dir`        | string  | Language directory                              |
| `name`            | string  | Entry-file name in use for the directory layout |
| `filepath`        | string  | Path of the loaded `.lex` file                  |
| `keys`            | integer | Number of keys in `_raw_translations`           |
| `cached_keys`     | integer | Number of keys in `_cache_translations`         |
 
### `clear() → void`
 
Clears `_cache_translations`.

- `_raw_translations` and all other state MUST be preserved, so the runtime remains usable.
- The next `get()` for a key processes its escape sequences again.

To discard everything and reread the file, use `reload()`.

## Error Types

The runtime **MUST** provide these error types:

| Error                  | Description                           |
| ---------------------- | ------------------------------------- |
| `LexFileNotFoundError` | No `.lex` file for locale or fallback |
| `LexKeyNotFoundError`  | Key not in loaded translations        |
| `LexParseError`        | Malformed line in `.lex` file         |
| `LexFormatError`       | Placeholder and argument mismatch, or an invalid argument for a specifier |

**Languages without exceptions.** If the host language does not support exceptions (for example, GDScript), the runtime MAY use the language's native error mechanism, such as a result object or error code. The four error kinds MUST remain distinguishable. An error MUST never be silently converted into an empty string.

## Concurrency

Implementations targeting concurrent environments SHOULD ensure thread-safe access to `_cache_translations` during lazy writes.
