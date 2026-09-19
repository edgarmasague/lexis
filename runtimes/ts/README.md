# Lexis · TypeScript Runtime

Full API documentation for the TypeScript runtime.

---

## Installation

Copy `runtimes/ts/lexis.ts` into your project and there are two ways to run it:

**Option A - Compile with `tsc` (recommended for consuming this as a lib):**

```bash
npx tsc
```

Then import the compiled output:

```typescript
import { Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError } from "./lexis.js";
```

**Option B - Run the `.ts` source directly with `tsx` (no compile step, good for scripts/dev):**

```typescript
import { Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError } from "./lexis.ts";
```

```bash
npx tsx your-script.ts
```


No external dependencies. Requires Node.js 18+ and a project configured as an ES module (`"type": "module"` in `package.json`).

---

## Loading Strategy

The TypeScript runtime uses an **eager + lazy** model:

| Phase     | When                                      | What                                                                                     |
|-----------|-------------------------------------------|------------------------------------------------------------------------------------------|
| **Eager** | On `new Lexis()`, `load()`, or `reload()` | Reads and validates the entire file — detects duplicates and malformed lines immediately |
| **Lazy**  | On first `get()` for a key                | Processes escape sequences and stores the result in cache                                |

---

## API

### `new Lexis(langDir, locale = null, fallbackLocale = "en")`

Initializes the runtime. Auto-detects locale from `$LANG`. Falls back to the default locale file if the requested one does not exist.

```typescript
const lex = new Lexis("lang");                               // detects $LANG automatically
const lex = new Lexis("lang", "fr");                         // forces locale (falls back if not found)
const lex = new Lexis("lang", "fr", "pt");                   // custom fallback
```

---

### `lex.load(langDir, locale = null, fallbackLocale = "en")`

Loads a `.lex` file from a new directory, optionally with a new locale.  
Useful when embedding Lexis in projects with multiple translation directories.

```typescript
lex.load("other/lang", "fr");
lex.load("other/lang", "fr", "pt");
```

---

### `lex.get(key, ...args)`

Returns the translation with `printf`-style substitution.  
Processes escape sequences on first access and caches the result.
Raises `LexKeyNotFoundError` if the key doesn't exist or if placeholder formatting fails (e.g., wrong number or type of arguments)

```typescript
lex.get("welcome", "Alice", 3);      // → "Welcome Alice to Lexis!"
lex.get("error_file", "data.csv");   // → "File not found: data.csv"
lex.get("progress", 42);             // → "Progress: 42% completed"
lex.get("app_name");                 // → "Lexis"
```

---

### `lex.getOrDefault(key, defaultValue, ...args)`

Returns the translation or a default value if the key is not found.  
Applies `args` to the default if the translation is missing.

```typescript
lex.getOrDefault("missing", "N/A");              // → "N/A"
lex.getOrDefault("missing", "Hello %s", "Bob");  // → "Hello Bob"
```

---

### `lex.reload(locale = null, fallbackLocale = null)`

Reloads translations from the same directory, optionally switching locale.  
**Restores previous state if the reload fails.**

```typescript
lex.reload();                     // reloads current locale
lex.reload("en");                 // switches to en.lex and reloads
lex.reload("en", "pt");           // switches locale and fallback
lex.reload(null, "pt");           // keeps locale, changes fallback
```

---

### `lex.keys()`

Returns all loaded translation keys as an array.

```typescript
lex.keys();   // → ('welcome', 'error_file', 'progress', ...)
```

---

### `lex.has(key)`

Checks if a key exists.

```typescript
lex.has("welcome");    // → true
lex.has("missing");    // → false
```

---

### `lex.size()`

Returns the total number of loaded keys.

```typescript
lex.size();   // → 42
```

---

### `lex.getLocale()`

Returns the currently active locale code.

```typescript
lex.getLocale();   // → "en"
```

---

### `lex.getFilepath()`

Returns the path to the currently loaded `.lex` file.

```typescript
lex.getFilepath();   // → "lang/en.lex"
```

---

### `lex.toString()`

Shows the current runtime state including total keys and cached_keys.

```typescript
lex.toString();
// Lexis(locale=en, fallback=en, keys=42, cached_keys=3, filepath=lang/en.lex)
```

---

## Exceptions

| Exception              | When raised                                            |
|------------------------|--------------------------------------------------------|
| `LexFileNotFoundError` | The `.lex` file does not exist or cannot be read       |
| `LexKeyNotFoundError`  | The key does not exist or placeholder formatting fails |
| `LexParseError`        | The file contains malformed lines or duplicate keys    |

```typescript
try {
    const lex = new Lexis("lang");
    console.log(lex.get("welcome", "Alice"));
} catch(error) {
    if(error instanceof LexFileNotFoundError) {
        console.error(`[ERROR] ${error.message}`)
    } else if(error instanceof LexKeyNotFoundError) {
        console.error(`[ERROR] ${error.message}`)
    } else if(error instanceof LexParseError) {
        console.error(`[ERROR] ${error.message}`)
    }
}
```

---

## Locale Detection and Fallback

```typescript
// $LANG=es_ES.UTF-8 → loads lang/es.lex
const lex = new Lexis("lang");

// $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "en" (default)
const lex = new Lexis("lang");

// $LANG=C or empty → falls back to "en" (default)
const lex = new Lexis("lang");

// $LANG=fr_FR.UTF-8, lang/fr.lex not found → falls back to "pt" (custom)
const lex = new Lexis("lang", null, "pt");

// Force explicit locale
const lex = new Lexis("lang", "en");
```

---

## Full Example

```typescript
import { Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError } from "./lexis.js";

try {
    const lex = new Lexis("lang");
    console.log(lex.toString());                       // keys=42, cached_keys=0

    console.log(lex.get("welcome", "Alice", 3));       // → Welcome Alice to Lexis!
    console.log(lex.get("error_file", "data.csv"));    // → File not found: data.csv
    console.log(lex.get("progress", 42));              // → Progress: 42% completed
    console.log(lex.toString());                       // keys=42, cached_keys=3

    console.log(lex.getOrDefault("missing", "N/A"));   // → N/A
    console.log(lex.has("welcome"));                   // → true
    console.log(lex.size());                           // → 42

    lex.reload("es");
    console.log(lex.get("welcome", "Alice", 3));      // → Bienvenida Alice a Lexis!
} catch(error) {
    if(error instanceof LexFileNotFoundError) {
        console.error(`[ERROR] ${error.message}`)
    } else if(error instanceof LexKeyNotFoundError) {
        console.error(`[ERROR] ${error.message}`)
    } else if(error instanceof LexParseError) {
        console.error(`[ERROR] ${error.message}`)
    }
}
```

---

## Requirements

- Node.js 18+
- No external dependencies — Node.js built-ins only
- tsc (TypeScript Compiler) or tsx, depending on which installation option you use

---

*Lexis — Lex una, linguae multae.*