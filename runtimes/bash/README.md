# Lexis · Bash Runtime

Official Bash runtime for Lexis. Behaves like `lexis.py` (verified against it with randomized differential tests).

## Installation

Copy `runtimes/bash/lexis.sh` into your project and source it:

```bash
source "path/to/lexis.sh"
```

Requires **Bash 4.2+** and POSIX utilities. `bc` is used by `%f` only. `iconv` validates UTF-8 when it is available; without it, a pure-Bash check does the same, line by line.

## Loading Strategy

The Bash runtime uses an **eager + lazy** model:

| Phase     | When                                  | What                                                                                     |
|-----------|---------------------------------------|------------------------------------------------------------------------------------------|
| **Eager** | On `lexis_load()` or `lexis_reload()` | Reads and validates the entire file (UTF-8, malformed lines, duplicate keys)             |
| **Lazy**  | On first `lexis_get()` for a key      | Processes escape sequences and stores the result in cache                                |

## Calling conventions
 
Bash has no return values, so results are printed to **stdout without a trailing newline** and errors go to **stderr** with a distinct return code.
 
An **empty or omitted** optional argument means "not given" (Python's `None`).
 
> **Tip:** `$(lexis_get ...)` runs in a subshell, so the lazy cache write is lost and trailing newlines are stripped. It works, but it is slower. Calling the function directly (e.g. `lexis_get "k"; echo`) keeps the cache.
 
| Error                  | Code | When                                                                 |
|------------------------|------|----------------------------------------------------------------------|
| `LexFileNotFoundError` | `2`  | No file for locale/fallback, or an invalid input                     |
| `LexKeyNotFoundError`  | `3`  | Key does not exist                                                   |
| `LexParseError`        | `4`  | Malformed line, duplicate key, invalid UTF-8                         |
| `LexFormatError`       | `5`  | Missing argument, or an argument that is invalid for its specifier   |
 

## API

### `lexis_load(lang_dir, [locale], [fallback_locale], [name])`

Locale is detected from `$LANG` when omitted. `fallback_locale` defaults to `en`, `name` to `main`.

```bash
lexis_load "lang"                           # detects $LANG automatically
lexis_load "lang" "fr"                      # forces locale (falls back if not found)
lexis_load "lang" "fr" "pt"                 # custom fallback
lexis_load "lang" "" "" "app"               # custom entry-file name
```

Resolution order for `es_VE`, then the same steps for the fallback:
 
1. `lang/es_VE.lex`
2. `lang/es_VE/{name}.lex`
3. `lang/es.lex`
4. `lang/es/{name}.lex`
Locales must be `language` or `language_REGION` (`es-ve` is normalized to `es_VE`) and `name` only letters, digits, `_` and `-`; anything else is a `LexFileNotFoundError` before touching the filesystem. The current locale becomes the code of the file actually found. A garbage `$LANG` falls back to `en`.

### `lexis_get(key, [args...])`

Returns the translation with `printf`-style substitution. The substitution is Lexis' own implementation (never the host's `printf`), so the output is identical to the other runtimes. Escape sequences are processed on first access and the result is cached.

```bash
lexis_get "welcome" "Alice" 3         # → "Welcome Alice to Lexis!"
lexis_get "error_file" "data.csv"     # → "File not found: data.csv"
lexis_get "progress" 42               # → "Progress: 42% completed"
lexis_get "app_name"                  # → "Lexis"
```

Returns `3` if the key doesn't exist and `5` if a placeholder can't be formatted. Errors are printed to stderr.

---

### `lexis_get_or_default(key, default, [args...])`

Returns the translation or a default value if the key is not found. Applies `args` to the default if the translation is missing.

```bash
lexis_get_or_default "missing" "N/A"              # → "N/A"
lexis_get_or_default "missing" "Hello %s" "Bob"   # → "Hello Bob"
```

Returns `0`, or `5` if `args` can't be applied to the text. A missing key never fails.

---

### `lexis_reload([locale], [fallback_locale], [name])`

Reloads translations from the same directory, optionally switching locale. **Restores previous state if the reload fails.**

```bash
lexis_reload                          # reloads current locale
lexis_reload "en"                     # switches to en.lex and reloads
lexis_reload "en" "pt"                # switches locale and fallback
lexis_reload "" "pt"                  # keeps locale, changes fallback (an omitted locale keeps the current one)
```

Returns `0` on success, or the error code (`2` or `4`) on failure. On failure, previous translations remain available.

---

### `lexis_keys()`

Returns all loaded translation keys, one per line.

```bash
lexis_keys
# → welcome
# → error_file  
# → progress
# → ...
```

Use with `while read` or command substitution:

```bash
while read -r key; do
    echo "$key"
done < <(lexis_keys)
```

---

### `lexis_len()`

Returns the total number of loaded keys.

```bash
lexis_len   # → 42
```

---

### `lexis_has(key)`

Checks if a key exists. Returns exit code `0` (true) or `1` (false).

```bash
if lexis_has "welcome"; then
    echo "Key exists"
fi
```

---

### `lexis_info()`

Shows the current runtime state: locale, fallback, directory, entry-file name, file path, total keys and cached keys.

```bash
lexis_info
# → Lexis(locale='en', fallback_locale='en', lang_dir='lang', name='main', filepath='/abs/lang/en.lex', keys=42, cached_keys=3)
```

---

### `lexis_clear()`

Clears the cache of processed values. The loaded translations and every other piece of state are kept, so the runtime stays usable and the next `lexis_get` processes the escapes again. Use `lexis_reload` to reread the file.

```bash
lexis_clear
```

---

## Error Handling

The Bash runtime does not use exceptions. Instead:

- **Errors print to stderr** with a descriptive message
- **Functions return a distinct code** on failure and `0` on success (see the table in *Calling conventions*: `2` file not found or invalid input, `3` key not found, `4` parse error, `5` format error)
- **Callers should check `$?`** after public API calls

Example:

```bash
if ! lexis_get "welcome" "Alice"; then
    echo "Failed to get translation"
fi
```

---

## Locale Detection and Fallback

```bash
# $LANG=es_ES.UTF-8 → loads lang/es.lex
lexis_load "lang"

# $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "en" (default)
lexis_load "lang"

# $LANG=C or empty → falls back to "en" (default)
lexis_load "lang"

# $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "pt" (custom)
lexis_load "lang" "" "pt"

# Force explicit locale
lexis_load "lang" "en"
```

---

## Full Example

```bash
#!/usr/bin/env bash

source "runtimes/bash/lexis.sh"

# Load translations
if ! lexis_load "lang"; then
    echo "Failed to load translations" >&2
    exit 1
fi

# Show info
lexis_info

# Get translations
lexis_get "welcome" "Alice" 3
lexis_get "error_file" "data.csv"
lexis_get "progress" 42

# Safe access with default
lexis_get_or_default "missing" "N/A"
lexis_get_or_default "missing" "Hello %s" "Bob"

# Check existence
if lexis_has "welcome"; then
    echo "welcome key exists"
fi

# List all keys
echo "Keys: $(lexis_len)"
lexis_keys

# Reload with different locale
lexis_reload "es"
lexis_get "welcome" "Alice" 3

# Clear when done
lexis_clear
```

---

## Debug Mode

Set `LEXIS_DEBUG=1` to enable debug output:

```bash
export LEXIS_DEBUG=1
lexis_load "lang"
# → [lexis:debug] Loaded 'lang/en.lex' - 42 keys
```

---

## Requirements

- Bash 4.2+ (associative arrays and `declare -g` are required)
- `bc` for `%f` (integers, strings and every other specifier work without it)
- `iconv` is optional: without it, UTF-8 is checked in pure Bash

---

*Lexis — Lex una, linguae multae.*