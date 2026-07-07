# Lexis · Bash Runtime

Full API documentation for the Bash runtime.

---

## Installation

Copy `runtimes/bash/lexis.sh` into your project and source it:

```bash
source "path/to/lexis.sh"
```

No external dependencies. Requires Bash 4+ (for associative arrays).

---

## Loading Strategy

The Bash runtime uses an **eager + lazy** model:

| Phase     | When                                  | What                                                                                     |
|-----------|---------------------------------------|------------------------------------------------------------------------------------------|
| **Eager** | On `lexis_load()` or `lexis_reload()` | Reads and validates the entire file — detects duplicates and malformed lines immediately |
| **Lazy**  | On first `lexis_get()` for a key      | Processes escape sequences and stores the result in cache                                |

---

## API

### `lexis_load(lang_dir, [locale], [fallback_locale])`

Loads a `.lex` file from the given directory. Auto-detects locale from `$LANG`. Falls back to the default locale file if the requested one does not exist.

```bash
lexis_load "lang"                           # detects $LANG automatically
lexis_load "lang" "fr"                      # forces locale (falls back if not found)
lexis_load "lang" "fr" "pt"                 # custom fallback
```

Returns `0` on success, `1` on failure. Errors are printed to stderr.

---

### `lexis_get(key, [args...])`

Returns the translation with `printf`-style substitution. Processes escape sequences on first access and caches the result.

```bash
lexis_get "welcome" "Alice" 3         # → "Welcome Alice to Lexis!"
lexis_get "error_file" "data.csv"     # → "File not found: data.csv"
lexis_get "progress" 42               # → "Progress: 42% completed"
lexis_get "app_name"                  # → "Lexis"
```

Returns `1` if the key doesn't exist or if placeholder formatting fails. Errors are printed to stderr.

---

### `lexis_get_or_default(key, default, [args...])`

Returns the translation or a default value if the key is not found. Applies `args` to the default if the translation is missing.

```bash
lexis_get_or_default "missing" "N/A"              # → "N/A"
lexis_get_or_default "missing" "Hello %s" "Bob"   # → "Hello Bob"
```

Always returns `0` (never fails — falls back to default).

---

### `lexis_reload([locale], [fallback_locale])`

Reloads translations from the same directory, optionally switching locale. **Restores previous state if the reload fails.**

```bash
lexis_reload                          # reloads current locale
lexis_reload "en"                     # switches to en.lex and reloads
lexis_reload "en" "pt"                # switches locale and fallback
lexis_reload "" "pt"                   # keeps locale, changes fallback
```

Returns `0` on success, `1` on failure. On failure, previous translations remain available.

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

Shows the current runtime state including total keys and cached keys.

```bash
lexis_info
# → Lexis(locale='en', fallback='en', keys=42, cached_keys=3, filepath='lang/en.lex')
```

---

### `lexis_clear()`

Resets all state — clears translations, locale, and filepath.

```bash
lexis_clear
```

---

## Error Handling

The Bash runtime does not use exceptions. Instead:

- **Errors print to stderr** with a descriptive message
- **Functions return `1`** on failure, `0` on success
- **Callers should check `$?`** after public API calls

| Error Pattern          | When                                               | Exit Code |
|------------------------|----------------------------------------------------|-----------|
| `LexFileNotFoundError` | File does not exist or cannot be read              | `1`       |
| `LexKeyNotFoundError`  | Key does not exist or placeholder formatting fails | `1`       |
| `LexParseError`        | File contains malformed lines or duplicate keys    | `1`       |

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

- Bash 4+ (associative arrays required)
- No external dependencies — POSIX utilities only

---

*Lexis — Lex una, linguae multae.*
