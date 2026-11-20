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
import { Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError, LexFormatError } from "./lexis.js";
```

**Option B - Run the `.ts` source directly with `tsx` (no compile step, good for scripts/dev):**

```typescript
import { Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError, LexFormatError } from "./lexis.ts";
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

### `new Lexis(langDir, locale = null, fallbackLocale = "en", name = "main")`

Initializes the runtime. Auto-detects locale from `$LANG`. Falls back to the default locale file if the requested one does not exist.

For a locale such as `es_VE`, the files are looked up in this order, and then the same steps are applied to the fallback locale:

1. `lang/es_VE.lex`
2. `lang/es_VE/{name}.lex`
3. `lang/es.lex`
4. `lang/es/{name}.lex`

Locales must be `language` or `language_REGION` (`es-ve` is normalized to `es_VE`) and `name` only letters, digits, `_` and `-`; anything else throws `LexFileNotFoundError` before the filesystem is touched. Only `null` auto-detects: an empty string is invalid. The current locale becomes the code of the file actually found (`lex.getLocale()`).

```typescript
const lex = new Lexis("lang");                               // detects $LANG automatically
const lex = new Lexis("lang", "fr");                         // forces locale (falls back if not found)
const lex = new Lexis("lang", "fr", "pt");                   // custom fallback
const lex = new Lexis("lang", null, "en", "app");            // custom entry-file name
```

---

### `lex.load(langDir, locale = null, fallbackLocale = "en", name = "main")`

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
Throws `LexKeyNotFoundError` if the key doesn't exist and `LexFormatError` if a placeholder can't be formatted (a missing argument, or an argument that is invalid for its specifier).

The formatting is Lexis' own implementation, never the host's, so the output is identical in every runtime. JavaScript types matter: `%d`, `%i`, `%x`, `%o` and `%c` take an integral `number`, a `bigint` or a plain integer string; `%f` takes a `number`, a `bigint` or a plain decimal string; `%s` takes a string, a `number` or a `bigint`. Use a `bigint` (`9223372036854775807n`) for integers above 2^53, because a `number` can't hold them exactly. `boolean`, `null` and `undefined` are never valid.

```typescript
lex.get("welcome", "Alice", 3);      // → "Welcome Alice to Lexis!"
lex.get("error_file", "data.csv");   // → "File not found: data.csv"
lex.get("progress", 42);             // → "Progress: 42% completed"
lex.get("app_name");                 // → "Lexis"
```

---

### `lex.getOrDefault(key, defaultValue, ...args)`

Returns the translation or a default value if the key is not found.  
Applies `args` to the default if the translation is missing (throwing `LexFormatError` like `get()` if they can't be applied).

```typescript
lex.getOrDefault("missing", "N/A");              // → "N/A"
lex.getOrDefault("missing", "Hello %s", "Bob");  // → "Hello Bob"
```

---

### `lex.reload(locale = null, fallbackLocale = null, name = null)`

Reloads translations from the same directory, optionally switching locale.  
**Restores previous state if the reload fails.**

```typescript
lex.reload();                     // reloads current locale (an omitted locale keeps the current one)
lex.reload("en");                 // switches to en.lex and reloads
lex.reload("en", "pt");           // switches locale and fallback
lex.reload(null, "pt");           // keeps locale, changes fallback
lex.reload(null, null, "app");     // changes the entry-file name
```

---

### `lex.keys()`

Returns all loaded translation keys as an array (a snapshot).

```typescript
lex.keys();   // → ['welcome', 'error_file', 'progress', ...]
```

---

### `lex.has(key)`

Checks if a key exists, without loading or formatting its value.

```typescript
lex.has("welcome");    // → true
lex.has("missing");    // → false
```

---

### `lex.len()`

Returns the total number of loaded keys. `lex.size()` is an alias.

```typescript
lex.len();   // → 42
```

---

### `lex.info()`

Returns a snapshot of the runtime state.

```typescript
lex.info();
// → { locale: "en", fallbackLocale: "en", langDir: "lang", name: "main",
//     filepath: "/abs/lang/en.lex", keys: 42, cachedKeys: 3 }
```

---

### `lex.clear()`

Clears the cache of processed values. The loaded translations and every other piece of state are kept, so the runtime stays usable and the next `get()` processes the escapes again. Use `reload()` to reread the file.

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
lex.getFilepath();   // → "/abs/lang/en.lex"
```

---

### `lex.toString()`

Shows the current runtime state: locale, fallback, directory, entry-file name, file path, total keys and cached keys.

```typescript
lex.toString();
// Lexis(locale='en', fallback_locale='en', lang_dir='lang', name='main', filepath='/abs/lang/en.lex', keys=42, cached_keys=3)
```

---

## Exceptions

| Exception              | When raised                                            |
|------------------------|--------------------------------------------------------|
| `LexFileNotFoundError` | No `.lex` file for the locale or fallback, or an invalid input |
| `LexKeyNotFoundError`  | The key does not exist                                 |
| `LexParseError`        | Malformed line, duplicate key or invalid UTF-8         |
| `LexFormatError`       | A missing argument, or an argument that is invalid for its specifier |

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
    } else if(error instanceof LexFormatError) {
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
import { Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError, LexFormatError } from "./lexis.js";

try {
    const lex = new Lexis("lang");
    console.log(lex.toString());                       // keys=42, cached_keys=0

    console.log(lex.get("welcome", "Alice", 3));       // → Welcome Alice to Lexis!
    console.log(lex.get("error_file", "data.csv"));    // → File not found: data.csv
    console.log(lex.get("progress", 42));              // → Progress: 42% completed
    console.log(lex.toString());                       // keys=42, cached_keys=3

    console.log(lex.getOrDefault("missing", "N/A"));   // → N/A
    console.log(lex.has("welcome"));                   // → true
    console.log(lex.len());                            // → 42

    lex.reload("es");
    console.log(lex.get("welcome", "Alice", 3));      // → Bienvenida Alice a Lexis!
} catch(error) {
    if(error instanceof LexFileNotFoundError) {
        console.error(`[ERROR] ${error.message}`)
    } else if(error instanceof LexKeyNotFoundError) {
        console.error(`[ERROR] ${error.message}`)
    } else if(error instanceof LexParseError) {
        console.error(`[ERROR] ${error.message}`)
    } else if(error instanceof LexFormatError) {
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