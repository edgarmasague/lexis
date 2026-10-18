# Lexis · Python Runtime

Full API documentation for the Python runtime.

## Installation

Copy `runtimes/python/lexis.py` into your project and import it:

```python
from lexis import (
    Lexis,
    LexFileNotFoundError,
    LexKeyNotFoundError,
    LexParseError,
    LexFormatError
)
```

No external dependencies. Requires Python 3.10+.

## Loading Strategy

The Python runtime uses an **eager + lazy** model:

| Phase     | When                                  | What                                                                                     |
|-----------|---------------------------------------|------------------------------------------------------------------------------------------|
| **Eager** | On `Lexis()`, `load()`, or `reload()` | Reads and validates the entire file — detects duplicates and malformed lines immediately |
| **Lazy**  | On first `get()` for a key            | Processes escape sequences and stores the result in cache                                |

> **Note:** The cache holds the value after escape processing and before placeholder formatting.  
> Formatting runs on every `get()`, because it depends on the arguments.

## API

### `Lexis(lang_dir, locale=None, fallback_locale="en", name="main")`

Initializes the runtime. Auto-detects locale from `$LANG` when locale is `None`.  
Falls back to `fallback_locale` if the requested one does not exist.

```python
lex = Lexis("lang")                               # detects $LANG automatically
lex = Lexis("lang", "fr")                         # forces locale (falls back if not found)
lex = Lexis("lang", "fr", fallback_locale="pt")   # custom fallback
lex = Lexis("lang", "es_VE")                      # regional locale
lex = Lexis("lang", "pt", name="custom")          # custom entry-file name
```

> **Note:** `name` is the entry-file name used by the directory layout (`{locale}/{name}.lex`).  
> When it is not given, `"main"` is used.

### `lexis.load(lang_dir, locale=None, fallback_locale="en", name="main")`

Loads a `.lex` file from a new directory, optionally with a new locale.  
Useful when embedding Lexis in projects with multiple translation directories.  
Only `reload()` restores the previous state if it fails.

```python
lexis.load("other/lang", "fr")
lexis.load("other/lang", "fr", fallback_locale="pt")
lexis.load("other/lang", "fr", name="custom")
```

### `lexis.get(key, *args)`

Returns the translation with `printf`-style substitution.   
Processes escape sequences on first access and caches the result.  
Raises `LexKeyNotFoundError` if the key doesn't exist, and `LexFormatError` if placeholder formatting fails (e.g., missing argument, or an argument that is invalid for its specifier).

```python
lexis.get("welcome", "Alice", 3)      # → "Welcome Alice to Lexis!"
lexis.get("error_file", "data.csv")   # → "File not found: data.csv"
lexis.get("progress", 42)             # → "Progress: 42% completed"
lexis.get("app_name")                 # → "Lexis"
```
> **Note:** See Placeholders for the formatting rules.

### `lexis.get_or_default(key, default, *args)`

Returns the translation or a `default` if the key is not found.  
If the key exists it behaves exactly like `get()`, including `LexFormatError`.  
`args` are applied to `default` only when the key is missing and `args` are given.

```python
lexis.get_or_default("missing", "N/A")              # → "N/A"
lexis.get_or_default("missing", "Hello %s", "Bob")  # → "Hello Bob"
```

### `lexis.reload(locale=None, fallback_locale=None, name=None)`

Reloads translations from the same directory, optionally switching locale.  
Every argument left as `None` keeps its current value; `reload()` never triggers auto-detection.
> **Note:** Restores previous state if the reload fails.

```python
lexis.reload()                     # reloads current locale
lexis.reload("en")                 # switches to en.lex and reloads
lexis.reload("en", "pt")           # switches locale and fallback
lexis.reload(fallback_locale="pt") # keeps locale, changes fallback
lexis.reload(name="custom")        # Keeps locale, changes entry-file name
```

### `lexis.keys()`

Returns all loaded translation keys as a tuple.

```python
lexis.keys()   # → ('welcome', 'error_file', 'progress', ...)
```

### `"key" in lexis` / `lexis.has(key)`

Returns whether a key exists.  
Never raises and never touches the cache.

```python
"welcome" in lexis    # → True
"missing" in lexis    # → False
lexis.has("welcome")  # → True
```

### `lexis.len()`/`len(lexis)`

Returns the total number of loaded keys.  
An empty or comment-only file gives `0`.

```python
lexis.len()  # → 42
len(lexis)   # → 42
```

### `lexis.info()`/ `repr(lexis)`
 
Returns a snapshot of the runtime state as a `dict`.  
`repr(lexis)` shows the same data: `Lexis({'locale': 'en', 'fallback_locale': 'en', ...})`.
 
```python
lexis.info()
# {
#   'locale': 'es_VE', 'fallback_locale': 'en', 'lang_dir': 'lang',
#   'name': 'main', 'filepath': '/abs/path/lang/es_VE.lex',
#   'keys': 42, 'cached_keys': 3
# }
```
 
`locale` is the locale of the file that was actually loaded, which may differ from the one requested (see [Locale Resolution](#locale-resolution)).
 
### `lexis.clear()`
 
Clears the escape cache. The loaded translations and all other state are kept, so the instance stays usable; the next `get()` for a key processes its escapes again.  
To discard everything and reread the file, use `reload()`.
 
```python
lexis.clear()
lexis.info()["cached_keys"]   # → 0
```

## Locale Resolution
 
Locale codes are validated and normalized before any file is looked up. `locale`, `fallback_locale` and `name` may only contain letters, digits, `_` or `-`, and cannot be empty.  
Any other value raises `LexFileNotFoundError` without touching the filesystem (this blocks path traversal such as `"../secret"`).
 
A locale is normalized to `language` or `language_REGION` (lowercase language,
uppercase region); `-` and `_` are both accepted:
 
| Input                      | Normalized |
|----------------------------|------------|
| `ES`                       | `es`       |
| `es-ve`, `es_ve`, `ES_VE`  | `es_VE`    |
| `es_VE_X`, `es VE`, `""`   | invalid    |
 
Files are searched in this order, and `info()["locale"]` follows the file found:
 
| Requested          | Lookup order                                                   |
|--------------------|----------------------------------------------------------------|
| `es_VE` (regional) | `es_VE.lex` → `es_VE/{name}.lex` → `es.lex` → `es/{name}.lex`  |
| `es` (language)    | `es.lex` → `es/{name}.lex`                                     |
 
If nothing matches, the same steps are applied to `fallback_locale`, following its own shape.  
The file layout (`es.lex`) always wins over the directory layout (`es/main.lex`).
 
### Auto-detection
 
When no locale is given, it is read from `$LANG`: the encoding (`.UTF-8`) and modifier (`@euro`) are ignored; `C`, `POSIX`, empty or missing give `en`; and `zh_Hans_CN` is reduced to `zh_CN`.
 
```python
# $LANG=es_VE.UTF-8 → es_VE.lex, else es.lex
lexis = Lexis("lang")
 
# $LANG=fr_FR.UTF-8, no fr_FR / fr file → falls back to "en" (default)
lexis = Lexis("lang")
 
# $LANG=C or empty → "en"
lexis = Lexis("lang")
 
# $LANG=fr_FR.UTF-8, no fr file → falls back to "pt" (custom)
lexis = Lexis("lang", fallback_locale="pt")
 
# Force an explicit locale
lexis = Lexis("lang", "en")
```
 
## Placeholders
 
Supported specifiers: `%s %d %i %f %x %o %c %%`. The grammar is `%[-][0][width][.precision]specifier`.
 
| Rule      | Behavior                                                                                                                                                                                    |
|-----------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `%s`      | string, integer or float. Booleans and `None` raise `LexFormatError`                                                                                                                        |
| `%d` `%i` | integer, integral float (`3.0`) or a plain integer string (`"42"`). Booleans, `"4.0"`, `"+5"`, `" 5"`, `""`, NaN/Infinity and values outside the signed 64-bit range raise `LexFormatError` |
| `%x` `%o` | same coercion as `%d`; negatives are signed magnitude (`-2a`), never two's complement                                                                                                       |
| `%c`      | code point `1`–`0x10FFFF`, excluding surrogates; anything else raises `LexFormatError`                                                                                                      |
| `%f`      | int, float or decimal string. Without a precision: 6 decimals, then trailing zeros are removed (`3.0` → `3`). `%.2f` keeps the decimals. Rounds half away from zero against the exact binary value. NaN, Infinity, booleans and `abs(value) >= 2**63` raise `LexFormatError`                                                                                                                           |
| width     | counted in code points; a longer value is never truncated. Maximum `1024`                                                                                                                   |
| precision | only for `%f`. Maximum `15`                                                                                                                                                                 |
| flags     | `-` (left-align) and `0` (zero-pad, numeric only), in that order. `-` wins over `0`                                                                                                         |
| `%%`      | a literal `%`                                                                                                                                                                               |
 
Anything that does not match the grammar (`%q`, `%+d`, `%ld`, `%1$s`, `%.3s`, `%.f`, `%1025d`, a `%` at the end of the value...) stays as literal text and consumes **no** argument.  
More placeholders than arguments raises `LexFormatError`; extra arguments are ignored.  
Substituted arguments are never scanned again for escapes or placeholders.


## Exceptions

| Exception              | When raised                                                                                                             |
|------------------------|-------------------------------------------------------------------------------------------------------------------------|
| `LexFileNotFoundError` | No `.lex` file for the locale or fallback, the file cannot be read, or `locale`, `fallback_locale` or `name` is invalid |
| `LexKeyNotFoundError`  | The key does not exist                                                                                                  |
| `LexParseError`        | The file has a malformed line, an empty key, a duplicate key, or invalid UTF-8                                          |
| `LexFormatError`       | Missing placeholder argument, or an argument that is invalid for its specifier                                          |

```python
try:
    lexis = Lexis("lang")
    print(lexis.get("welcome", "Alice"))

except LexFileNotFoundError as error:
    print(f"[ERROR] {error}")
except LexKeyNotFoundError as error:
    print(f"[ERROR] {error}")
except LexParseError as error:
    print(f"[ERROR] {error}")
except LexFormatError as error:
    print(f"[ERROR] {error}")
```

## Full Example

```python
from lexis import (
    Lexis,
    LexFileNotFoundError,
    LexKeyNotFoundError,
    LexParseError,
    LexFormatError,
)

try:
    lexis = Lexis("lang")
    print(lexis.info()["cached_keys"])                # → 0

    print(lexis.get("welcome", "Alice", 3))           # → Welcome Alice to Lexis!
    print(lexis.get("error_file", "data.csv"))        # → File not found: data.csv
    print(lexis.get("progress", 42))                  # → Progress: 42% completed
    print(lexis.info()["cached_keys"])                # → 3

    print(lexis.get_or_default("missing", "N/A"))     # → N/A
    print("welcome" in lexis)                         # → True
    print(len(lexis))                                 # → 42
    print(lexis.info()["locale"])                     # → en

    lexis.reload("es")
    print(lexis.get("welcome", "Alice", 3))           # → Bienvenida Alice a Lexis!

except LexFileNotFoundError as error:
    print(f"[ERROR] {error}")
except LexKeyNotFoundError as error:
    print(f"[ERROR] {error}")
except LexParseError as error:
    print(f"[ERROR] {error}")
except LexFormatError as error:
    print(f"[ERROR] {error}")
```

## Requirements

- Python 3.10+
- No external dependencies — stdlib only

> *Lexis — Lex una, linguae multae.*