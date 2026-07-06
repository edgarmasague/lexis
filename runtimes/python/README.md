# Lexis · Python Runtime

Full API documentation for the Python runtime.

---

## Installation

Copy `runtimes/python/lexis.py` into your project and import it:

```python
from lexis import Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError
```

No external dependencies. Requires Python 3.10+.

---

## Loading Strategy

The Python runtime uses an **eager + lazy** model:

| Phase     | When                                  | What                                                                                     |
|-----------|---------------------------------------|------------------------------------------------------------------------------------------|
| **Eager** | On `Lexis()`, `load()`, or `reload()` | Reads and validates the entire file — detects duplicates and malformed lines immediately |
| **Lazy**  | On first `get()` for a key            | Processes escape sequences and stores the result in cache                                |

---

## API

### `Lexis(lang_dir, locale=None, fallback_locale="en")`

Initializes the runtime. Auto-detects locale from `$LANG`. Falls back to the default locale file if the requested one does not exist.

```python
lex = Lexis("lang")                               # detects $LANG automatically
lex = Lexis("lang", "fr")                         # forces locale (falls back if not found)
lex = Lexis("lang", "fr", fallback_locale="pt")  # custom fallback
```

---

### `lexis.load(lang_dir, locale=None, fallback_locale="en")`

Loads a `.lex` file from a new directory, optionally with a new locale.  
Useful when embedding Lexis in projects with multiple translation directories.

```python
lexis.load("other/lang", "fr")
lexis.load("other/lang", "fr", fallback_locale="pt")
```

---

### `lexis.get(key, *args)`

Returns the translation with `printf`-style substitution.  
Processes escape sequences on first access and caches the result.
Raises `LexKeyNotFoundError` if the key doesn't exist or if placeholder formatting fails (e.g., wrong number or type of arguments)

```python
lexis.get("welcome", "Alice", 3)      # → "Welcome Alice to Lexis!"
lexis.get("error_file", "data.csv")   # → "File not found: data.csv"
lexis.get("progress", 42)             # → "Progress: 42% completed"
lexis.get("app_name")                 # → "Lexis"
```

---

### `lexis.get_or_default(key, default, *args)`

Returns the translation or a default value if the key is not found.  
Applies `args` to the default if the translation is missing.

```python
lexis.get_or_default("missing", "N/A")              # → "N/A"
lexis.get_or_default("missing", "Hello %s", "Bob")  # → "Hello Bob"
```

---

### `lexis.reload(locale=None, fallback_locale=None)`

Reloads translations from the same directory, optionally switching locale.  
**Restores previous state if the reload fails.**

```python
lexis.reload()                     # reloads current locale
lexis.reload("en")                 # switches to en.lex and reloads
lexis.reload("en", "pt")           # switches locale and fallback
lexis.reload(fallback_locale="pt") # keeps locale, changes fallback
```

---

### `lexis.keys()`

Returns all loaded translation keys as a tuple.

```python
lexis.keys()   # → ('welcome', 'error_file', 'progress', ...)
```

---

### `"key" in lexis`

Checks if a key exists.

```python
"welcome" in lexis    # → True
"missing" in lexis    # → False
```

---

### `len(lexis)`

Returns the total number of loaded keys.

```python
len(lexis)   # → 42
```

---

### `repr(lexis)`

Shows the current runtime state including total keys and cached keys.

```python
repr(lexis)
# Lexis(locale='en', fallback='en', keys=42, cached keys=3, filepath='lang/en.lex')
```

---

## Exceptions

| Exception              | When raised                                            |
|------------------------|--------------------------------------------------------|
| `LexFileNotFoundError` | The `.lex` file does not exist or cannot be read       |
| `LexKeyNotFoundError`  | The key does not exist or placeholder formatting fails |
| `LexParseError`        | The file contains malformed lines or duplicate keys    |

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
```

---

## Locale Detection and Fallback

```python
# $LANG=es_ES.UTF-8 → loads lang/es.lex
lexis = Lexis("lang")

# $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "en" (default)
lexis = Lexis("lang")

# $LANG=C or empty → falls back to "en" (default)
lexis = Lexis("lang")

# $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "pt" (custom)
lexis = Lexis("lang", fallback_locale="pt")

# Force explicit locale
lexis = Lexis("lang", "en")
```

---

## Full Example

```python
from lexis import Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError

try:
    lexis = Lexis("lang")
    print(repr(lexis))                                # keys=42, cached keys=0

    print(lexis.get("welcome", "Alice", 3))           # → Welcome Alice to Lexis!
    print(lexis.get("error_file", "data.csv"))        # → File not found: data.csv
    print(lexis.get("progress", 42))                  # → Progress: 42% completed
    print(repr(lexis))                                # keys=42, cached keys=3

    print(lexis.get_or_default("missing", "N/A"))     # → N/A
    print("welcome" in lexis)                         # → True
    print(len(lexis))                                 # → 42

    lexis.reload("es")
    print(lexis.get("welcome", "Alice", 3))           # → Bienvenida Alice a Lexis!

except LexFileNotFoundError as error:
    print(f"[ERROR] {error}")
except LexKeyNotFoundError as error:
    print(f"[ERROR] {error}")
except LexParseError as error:
    print(f"[ERROR] {error}")
```

---

## Requirements

- Python 3.10+
- No external dependencies — stdlib only

---

*Lexis — Lex una, linguae multae.*