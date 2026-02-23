# LEX · Independent Translation Engine

**LEX** (del griego *Léxis*: palabra / del latín *Lex*: ley) es un sistema
de traducción agnóstico, minimalista y ligero, diseñado bajo la filosofía
**Unix**.

Permite separar las cadenas de texto del código fuente, facilitando
aplicaciones multilingües en cualquier lenguaje de programación
(Bash, Python, C, Lua, etc.).

---

## Filosofía

| Principio       | Descripción                                               |
|-----------------|-----------------------------------------------------------|
| **Minimalismo** | Sin dependencias, sin formatos pesados (JSON/YAML).       |
| **Kaizen**      | Mejora continua a través de la simplicidad.               |
| **Universalidad**| Un solo formato para múltiples lenguajes de programación.|

---

## El Formato `.lex`

El archivo utiliza un separador de doble punto (`::`) para definir las
traducciones. Es crudo, rápido y eficiente.

```
# lang/es.lex
welcome::Bienvenido a %s
modules_available::Módulos Disponibles
modules_available_list::Lista de Módulos Disponibles
error_file::No se encontró el archivo: %s
```

### Reglas

- La **clave** termina en el primer `::` encontrado.
- El **valor** es todo lo que viene después, incluyendo `::` adicionales.
- Las líneas que comienzan con `#` son comentarios.
- Las líneas vacías son ignoradas.
- Los placeholders `%s` permiten valores dinámicos.

### Convenciones de claves (recomendadas)

- `snake_case` para todas las claves independiente del lenguaje.
- Ejemplo: `error_file`, `modules_available`, `welcome`

---

## Estructura del Proyecto

```
lexis/
├── lang/
│   ├── en.lex
│   └── es.lex
├── python/
│   └── main.py
└── bash/
    └── main.sh
```

---

## Uso en Python

```python
from main import LEX, LexFileNotFoundError, LexKeyNotFoundError

try:
    lex = LEX("lang")
    print(lex.get("welcome", "LEX"))         # Bienvenido a LEX
    print(lex.get("modules_available"))      # Módulos Disponibles
    print(lex.get("error_file", "foo.txt"))  # No se encontró el archivo: foo.txt

    lex.reload("en")
    print(lex.get("welcome", "LEX"))         # Welcome to LEX

except LexFileNotFoundError as error:
    print(f"[ERROR] {error}")
except LexKeyNotFoundError as error:
    print(f"[ERROR] {error}")
```

## Uso en Bash

```bash
source main.sh

lex_load "lang"
lex_get "welcome" "LEX"         # Bienvenido a LEX
lex_get "modules_available"     # Módulos Disponibles
lex_get "error_file" "foo.txt"  # No se encontró el archivo: foo.txt

lex_reload "lang" "en"
lex_get "welcome" "LEX"         # Welcome to LEX
```

---

## Detección Automática de Locale

LEX detecta automáticamente el idioma del sistema via la variable
de entorno `$LANG`. Si no existe un archivo `.lex` para el locale
detectado, hace fallback a `en.lex`.

```
$LANG=es_ES.UTF-8  →  carga lang/es.lex
$LANG=fr_FR.UTF-8  →  carga lang/fr.lex  (si no existe → fallback a en.lex)
```

---

## Cache

LEX utiliza un sistema de cache lazy: solo carga en memoria las claves
que se solicitan. Esto lo hace eficiente incluso con archivos `.lex` de
miles de líneas.

---

*LEX — Una ley, muchos lenguajes.*