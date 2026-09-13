# Lexis · PHP Runtime

Full API documentation for the PHP runtime.

---

## Installation

Copy `runtimes/php/lexis.php` into your project and import it:
 
```php
require_once 'lexis.php';
```

No external dependencies. Requires PHP 8.0+.

---

## Loading Strategy

The PHP runtime uses an **eager + lazy** model:

| Phase     | When                                      | What                                                                                     |
|-----------|-------------------------------------------|------------------------------------------------------------------------------------------|
| **Eager** | On `new Lexis()`, `load()`, or `reload()` | Reads and validates the entire file — detects duplicates and malformed lines immediately |
| **Lazy**  | On first `get()` for a key                | Processes escape sequences and stores the result in cache                                |

---

## API

### `new Lexis(langDir, locale:null, fallbackLocale:"en")`

Initializes the runtime. Auto-detects locale from `$LANG`. Falls back to the default locale file if the requested one does not exist.

```php
$lex = new Lexis("lang");                               // detects $LANG automatically
$lex = new Lexis("lang", "fr");                         // forces locale (falls back if not found)
$lex = new Lexis("lang", "fr", fallbackLocale:"pt");    // custom fallback
```

---

### `$lex->load(langDir, locale:null, fallbackLocale:"en")`

Loads a `.lex` file from a new directory, optionally with a new locale.  
Useful when embedding Lexis in projects with multiple translation directories.

```php
$lex->load("other/lang", "fr");
$lex->load("other/lang", "fr", fallbackLocale:"pt");
```

---

### `$lex->get(key, ...args)`

Returns the translation with `printf`-style substitution.  
Processes escape sequences on first access and caches the result.
Raises `LexKeyNotFoundError` if the key doesn't exist or if placeholder formatting fails (e.g., wrong number or type of arguments)

```php
$lex->get("welcome", "Alice", 3);      // → "Welcome Alice to Lexis!"
$lex->get("error_file", "data.csv");   // → "File not found: data.csv"
$lex->get("progress", 42);             // → "Progress: 42% completed"
$lex->get("app_name");                 // → "Lexis"
```

---

### `$lex->getOrDefault(key, default, ...args)`

Returns the translation or a default value if the key is not found.  
Applies `args` to the default if the translation is missing.

```php
$lex->getOrDefault("missing", "N/A");              // → "N/A"
$lex->getOrDefault("missing", "Hello %s", "Bob");  // → "Hello Bob"
```

---

### `$lex->reload(locale:null, fallbackLocale:null)`

Reloads translations from the same directory, optionally switching locale.  
**Restores previous state if the reload fails.**

```php
$lex->reload();                     // reloads current locale
$lex->reload("en");                 // switches to en.lex and reloads
$lex->reload("en", "pt");           // switches locale and fallback
$lex->reload(fallbackLocale:"pt");  // keeps locale, changes fallback
```

---

### `$lex->keys()`

Returns all loaded translation keys as an array.

```php
$lex->keys();   // → ('welcome', 'error_file', 'progress', ...)
```

---

### `isset($lex["key"])`

Checks if a key exists, via the `ArrayAccess` interface - winthout loading or formatting its value.

```php
isset($lex["welcome"]);    // → true
isset($lex["missing"]);    // → false
```

`$lex["key"]` is also a read shorthand for `$lex->get("key");`

```php
$lex->get("welcome");    // → same as $lex->get("welcome")
```

Lexis translations are read-only: `$lex["key"] = "value"` and `unset($lex["key"])` both throw a `LogicException`.

---

### `count($lex)`

Returns the total number of loaded keys, via the `Countable` interface.

```php
count($lex);   // → 42
```

---

### `$lex->getLocale()`

Returns the currently active locale code.

```php
$lex->getLocale();   // → "en"
```

---

### `$lex->getfilepath()`

Returns the path to the currently loaded `.lex` file.

```php
$lex->getfilepath();   // → "lang/en.lex"
```

---

### `(string) $lex`

Shows the current runtime state including total keys and cached keys.

```php
(string) $lex;
// Lexis(locale='en', fallback='en', keys=42, cached_keys=3, filepath='lang/en.lex')
```

---

## Exceptions

| Exception              | When raised                                            |
|------------------------|--------------------------------------------------------|
| `LexFileNotFoundError` | The `.lex` file does not exist or cannot be read       |
| `LexKeyNotFoundError`  | The key does not exist or placeholder formatting fails |
| `LexParseError`        | The file contains malformed lines or duplicate keys    |

```php
try {
    $lex = new Lexis("lang");
    echo $lex->get("welcome", "Alice");
} catch(LexFileNotFoundError $error) {
    echo "[ERROR] {$error->getMessage()}\n";
} catch(LexKeyNotFoundError $error) {
    echo "[ERROR] {$error->getMessage()}\n";
} catch(LexParseError $error) {
    echo "[ERROR] {$error->getMessage()}\n";
}
```

---

## Locale Detection and Fallback

```php
// $LANG=es_ES.UTF-8 → loads lang/es.lex
$lex = new Lexis("lang");

// $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "en" (default)
$lex = new Lexis("lang");

// $LANG=C or empty → falls back to "en" (default)
$lex = new Lexis("lang");

// $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "pt" (custom)
$lex = new Lexis("lang", fallbackLocale:"pt");

// Force explicit locale
$lex = new Lexis("lang", "en");
```

---

## Full Example

```php
require_once 'lexis.php';

try {
    $lex = new Lexis("lang");
    echo (string) $lex . "\n";                       // keys=42, cached keys=0

    echo $lex->get("welcome", "Alice", 3) . "\n";    // → Welcome Alice to Lexis!
    echo $lex->get("error_file", "data.csv") . "\n"; // → File not found: data.csv
    echo $lex->get("progress", 42) . "\n";           // → Progress: 42% completed
    echo (string) $lex . "\n";                       // keys=42, cached_keys=3

    echo $lex->getOrDefault("missing", "N/A");       // → N/A
    var_dump(isset($lex["welcome"]));                // → true
    echo count($lex) . "\n";                         // → 42

    $lex->reload("es");
    echo $lex->get("welcome", "Alice", 3) . "\n";    // → Bienvenida Alice a Lexis!
} catch(LexFileNotFoundError $error) {
    echo "[ERROR] {$error->getMessage()}\n";
} catch(LexKeyNotFoundError $error) {
    echo "[ERROR] {$error->getMessage()}\n";
} catch(LexParseError $error) {
    echo "[ERROR] {$error->getMessage()}\n";
}
```

---

## Requirements

- PHP 8.0+
- No external dependencies — stdlib only

---

*Lexis — Lex una, linguae multae.*