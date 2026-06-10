# Lexis · Workflow

Concise guide for creating, maintaining, and using `.lex` files in multilingual projects.

For the formal format specification, see `docs/LEX_FORMAT_SPEC.md`.

For runtime implementation details, see `docs/RUNTIME_TEMPLATE.md`.

This document focuses on recommended usage patterns and project organization.

---

## 1. Project Structure

The only required convention is a directory containing `.lex` files.
How you organize your project is up to you.

Minimal example:

```text
myproject/
├── lang/
│   ├── en.lex       # Base locale — used as fallback if others are missing
│   └── es.lex
└── runtimes/
    └── lexis.py     # or lexis.sh, lexis.lua, etc.
```

> There is no enforced structure. Lexis is embeddable anywhere.

---

## 2. Creating a `.lex` File

```text
# lang/es.lex

welcome::Bienvenido a %s
error_file::Archivo no encontrado: %s
progress::Progreso: %d%% completado
app_name::MiApp
empty_key::
```

**Essential rules:**

| Rule         | Detail                                                 |
|--------------|--------------------------------------------------------|
| Encoding     | UTF-8, no BOM                                          |
| Separator    | `::` — key ends at the first `::`                      |
| Keys         | `snake_case`, unique per file, auto-trimmed            |
| Placeholders | `%s` · `%d` · `%f` · `%%` — `printf`-style             |
| Escapes      | `\n` · `\t` · `\\` · `\"` — interpreted by the runtime |
| Empty values | Allowed (`key::`)                                      |
| Comments     | Lines starting with `#`                                |

---

## 3. Synchronizing Locales

Every locale file should have **the same keys** as your base locale.

```bash
# Detect keys missing in es.lex compared to en.lex
diff <(grep -o '^[^:]*' lang/en.lex | grep -v '^#' | sort) \
     <(grep -o '^[^:]*' lang/es.lex | grep -v '^#' | sort)
```

Recommended flow when adding a new key:

```
1. Add the key to your base locale file
2. Add the same key to every other locale file
3. Verify with the diff above
```

---
 
## 4. Generic Runtime Usage
 
Load the `.lex` file using any compatible Lexis runtime and use the standard API:
 
```text
load("lang", "es", "pt")               # locale=es, fallback=pt
 
get("welcome", "Alice")          # → Bienvenido a Alice
get("error_file", "data.csv")    # → Archivo no encontrado: data.csv
get("progress", 42)              # → Progreso: 42% completado
get_or_default("missing", "N/A") # → N/A
 
reload("en")                     # switch locale
get("welcome", "Alice")          # → Welcome Alice
```
 
**Automatic locale detection:**
 
```text
load("lang")   # detects system locale automatically, falls back if not found
```
 
For runtime-specific usage and full API documentation see `docs/`.

---

## 5. Key Naming Conventions (Recommended)

```text
# ✅ Correct
welcome::
error_file::
modules_available_list::

# ⚠️ Avoid
Welcome::        # uppercase
errorFile::      # camelCase
err-file::       # hyphens

# ❌ Wrong
error File::     # Space

```

Recommended prefixes by context:

| Prefix        | Usage                  |
|---------------|------------------------|
| `error_`      | Error messages         |
| `info_`       | Informational messages |
| `prompt_`     | User-facing questions  |
| *(no prefix)* | UI labels and names    |

---

## 6. Pre-release Checklist

- [ ] Base locale file exists and contains all keys
- [ ] All locale files have the same keys as the base locale
- [ ] No duplicate keys within a single `.lex` file
- [ ] Placeholders (`%s`, `%d`…) match in count and order across locales
- [ ] UTF-8 encoding, no BOM, in all `.lex` files
- [ ] No real newlines in values — use `\n` escape instead

---

*Lexis — Lex una, linguae multae.*