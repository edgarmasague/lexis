# Lexis · Python Runtime

Full API documentation for the Python runtime.

---

## Installation

Copy `runtimes/python/lexis.py` into your project and import it:

```python
from lexis import LEX, LexFileNotFoundError, LexKeyNotFoundError, LexParseError
```

No external dependencies. Requires Python 3.10+.

---

## Loading Strategy

The Python runtime uses an **eager + lazy** model:

| Phase | When | What |
|---|---|---|
| **Eager** | On `LEX()`, `load()`, or `reload()` | Reads and validates the entire file — detects duplicates and malformed lines immediately |
| **Lazy** | On first `get()` for a key | Processes escape sequences and stores the result in cache |

---

## API

### `LEX(lang_dir, locale=None, fallback_locale="en")`

Initializes the runtime. Auto-detects locale from `$LANG`. Falls back to the default locale file if the requested one does not exist.

```python
lex = LEX("lang")                               # detects $LANG automatically
lex = LEX("lang", "fr")                         # forces locale (falls back if not found)
lex = LEX("lang", "fr", fallback_locale="pt")  # custom fallback
```

---

### `lex.load(lang_dir, locale=None, fallback_locale="en")`

Loads a `.lex` file from a new directory, optionally with a new locale.  
Useful when embedding Lexis in projects with multiple translation directories.

```python
lex.load("other/lang", "fr")
lex.load("other/lang", "fr", fallback_locale="pt")
```

---

### `lex.get(key, *args)`

Returns the translation with `printf`-style substitution.  
Processes escape sequences on first access and caches the result.
Raises `LexKeyNotFoundError` if the key doesn't exist or if placeholder formatting fails (e.g., wrong number or type of arguments)

```python
lex.get("welcome", "Alice", 3)      # → "Welcome Alice to Lexis!"
lex.get("error_file", "data.csv")   # → "File not found: data.csv"
lex.get("progress", 42)             # → "Progress: 42% completed"
lex.get("app_name")                 # → "Lexis"
```

---

### `lex.get_or_default(key, default, *args)`

Returns the translation or a default value if the key is not found.  
Applies `args` to the default if the translation is missing.

```python
lex.get_or_default("missing", "N/A")              # → "N/A"
lex.get_or_default("missing", "Hello %s", "Bob")  # → "Hello Bob"
```

---

### `lex.reload(locale=None, fallback_locale=None)`

Reloads translations from the same directory, optionally switching locale.  
**Restores previous state if the reload fails.**

```python
lex.reload()                     # reloads current locale
lex.reload("en")                 # switches to en.lex and reloads
lex.reload("en", "pt")           # switches locale and fallback
lex.reload(fallback_locale="pt") # keeps locale, changes fallback
```

---

### `lex.keys()`

Returns all loaded translation keys as a tuple.

```python
lex.keys()   # → ('welcome', 'error_file', 'progress', ...)
```

---

### `"key" in lex`

Checks if a key exists.

```python
"welcome" in lex    # → True
"missing" in lex    # → False
```

---

### `len(lex)`

Returns the total number of loaded keys.

```python
len(lex)   # → 42
```

---

### `repr(lex)`

Shows the current runtime state including total keys and cached keys.

```python
repr(lex)
# Lexis(locale='en', keys=42, cached keys=3, filepath='lang/en.lex')
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
    lex = LEX("lang")
    print(lex.get("welcome", "Alice"))

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
lex = LEX("lang")

# $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "en" (default)
lex = LEX("lang")

# $LANG=C or empty → falls back to "en" (default)
lex = LEX("lang")

# $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "pt" (custom)
lex = LEX("lang", fallback_locale="pt")

# Force explicit locale
lex = LEX("lang", "en")
```

---

## Full Example

```python
from lexis import LEX, LexFileNotFoundError, LexKeyNotFoundError, LexParseError

try:
    lex = LEX("lang")
    print(repr(lex))                                # keys=42, cached keys=0

    print(lex.get("welcome", "Alice", 3))           # → Welcome Alice to Lexis!
    print(lex.get("error_file", "data.csv"))        # → File not found: data.csv
    print(lex.get("progress", 42))                  # → Progress: 42% completed
    print(repr(lex))                                # keys=42, cached keys=3

    print(lex.get_or_default("missing", "N/A"))     # → N/A
    print("welcome" in lex)                         # → True
    print(len(lex))                                 # → 42

    lex.reload("es")
    print(lex.get("welcome", "Alice", 3))           # → Bienvenida Alice a Lexis!

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