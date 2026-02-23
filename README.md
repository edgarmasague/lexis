# LEX · Independent Translation Engine

**LEX** (del griego *Léxis*: palabra / del latín *Lex*: ley) es un sistema de traducción agnóstico, minimalista y ligero, diseñado bajo la filosofía **Unix**. 

Permite separar las cadenas de texto del código fuente, facilitando aplicaciones multilingües en cualquier lenguaje de programación (Bash, Python, C, Lua, etc.).

##  filosofia
* **Minimalismo:** Sin dependencias, sin formatos pesados (JSON/YAML). Solo texto plano.
* **Kaizen:** Mejora continua a través de la simplicidad.
* **Universalidad:** Un solo archivo de traducción para múltiples lenguajes de programación.

## El Formato `.lex`
El archivo utiliza un separador de doble punto (`::`) para definir las leyes del lenguaje. Es crudo, rápido y eficiente.

```
# lang/es.lex
welcome::Bienvenido a %s
modules_available::Módulos Disponibles
error_file::No se encontró el archivo: %s
```
