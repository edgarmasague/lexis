# Lexis Design Decisions

This document explains the major design choices behind Lexis.  
It is not part of the formal specification.  
The specification defines behavior.  
This document explains the reasoning behind that behavior.

## Core Principle

Lexis was designed around a simple idea:

> Translation files should be understandable without specialized tooling or complex parsing logic.

Every feature is evaluated against this principle.  
When a feature increases complexity without significantly improving portability or predictability, it is usually rejected.

## Why a Flat Structure?

Lexis uses a flat key-value model:

```text
welcome::Welcome
error_file::File not found
```

instead of nested structures:

```json
{
  "messages": {
    "welcome": "Welcome"
  }
}
```

### Reasoning

Nested structures require additional parsing rules and can create implementation differences between runtimes.  
Flat keys:

- are easier to parse
- are easier to validate
- are portable across languages
- avoid hierarchy-specific behavior

Hierarchy can still be represented through naming conventions:

```text
auth.login.title
auth.login.button
auth.logout.button
```

without introducing special syntax.

## Why Use `::` as a Separator?

Lexis requires a separator that is:

- visually distinct
- easy to detect
- simple to parse

Several alternatives were considered:

```text
=
:
->
```

The `::` separator was chosen because it is unlikely to appear accidentally in normal translation text while remaining easy for humans to recognize.  
Only the first occurrence of `::` is treated as the separator.  
Everything after it belongs to the value.  
For example, `a:::b` is parsed as key `a` and value `:b`.  
Therefore, a key cannot end with `:`.

## Why No Imports?

The Lexis file format itself deliberately avoids file imports.  
No `.lex` file can reference or include another.  
Example of a rejected feature:

```text
import common.lex
```

### Reasoning

Imports introduce:

- dependency chains
- load-order concerns
- circular references
- runtime-specific behavior

Lexis favors self-contained translation files.  
A runtime should be able to load a file without resolving external dependencies.

## Why No Namespaces?

Namespaces were considered unnecessary.  
The same organizational benefits can be achieved through key naming:

```text
auth.login.title
auth.login.button
settings.language.title
```

without introducing additional syntax or parser rules.

## Why No Pluralization System?

Pluralization rules differ significantly across languages.

For example:

- English
- Arabic
- Russian
- Polish

use different grammatical rules and different numbers of plural forms.  
Embedding pluralization logic into the format would significantly increase complexity and reduce portability.  
Pluralization is therefore left to the application or runtime rather than being part of the `.lex` format.

## Why No Conditions or Logic?

Rejected examples:

```text
@if user_is_admin
```

```text
count > 1 ? ...
```

### Reasoning

Translation files should contain text, not behavior.  
Introducing conditions or expressions would turn the translation format into a template language.  
Lexis intentionally avoids that boundary.

## Why Use Printf-Style Placeholders?

Lexis uses:

```text
%s
%d
%f
```

instead of named placeholders:

```text
{name}
{count}
```

### Reasoning

Printf-style formatting is a familiar convention across many programming ecosystems. Developers already recognize common placeholders such as `%s` and `%d`, which reduces the learning curve.  
Even where a language does not provide a compatible formatter, the syntax is simple enough to implement with a small dedicated formatter.  
Lexis defines its own exact semantics for these placeholders (see section 7 of `LEX_FORMAT_SPEC.md` and `FORMAT_SPECIFIERS.md`) rather than relying on host-language formatting behavior. Host implementations differ, particularly in rounding and negative hexadecimal formatting.

## Why a Closed Placeholder Grammar?

Lexis does not accept whatever the host's `printf` accepts. Placeholders follow one small grammar:

```text
%[-][0][width][.precision]specifier
```

Any `%` sequence that does not match the grammar exactly is treated as literal text.

### Reasoning

If a runtime hands the format string to the host's `printf`, the result depends on which flags, length modifiers, and edge cases that host supports. Two runtimes could then produce different results from the same `.lex` file.  
A closed grammar removes that ambiguity. There is nothing to look up and nothing to guess: either the text matches the grammar, or it is text.  
Treating everything else as literal text also avoids a classic `printf` trap. A sentence such as `50% discount` contains `% d`, which C interprets as a placeholder with a space flag and then consumes an argument. In Lexis, it remains `50% discount`.  
The trade-off is that some C formats (`%+d`, `%#x`, `%ld`, `%X`, `%e`) do not exist. Translation text rarely needs them.

## Why No Positional Placeholders?

Lexis has no `%1$s` and no `{name}`. Arguments are matched in the order the placeholders appear.

### Reasoning

Positional-argument syntax adds a second way to write every placeholder and a second set of rules to define and test in every runtime.  
The consequence is that argument order is the same in every language. When a translation needs a different word order, the sentence is rephrased or split into two keys.  
This is a deliberate trade-off: a little more care from the translator in exchange for a much smaller format.

## Why Does `%f` Remove Trailing Zeros?

Without a precision, `%f` rounds to 6 decimal places and removes trailing zeros. Thus, `3.14` is written as `3.14`, while `3.0` is written as `3`.

### Reasoning

C writes `3.140000`, which is often undesirable in running text. Translated messages usually contain numbers meant to be read by people, and the natural form is one without unnecessary trailing zeros.  
A fixed rule—round to 6 decimals, then strip trailing zeros—is also deterministic across languages. The alternative, "the shortest text that reads back as the same number", depends on an algorithm that every runtime would have to implement consistently.  
The trade-off is that values below `0.0000005` are written as `0`. Code that needs more decimal places, or a fixed number of decimal places such as prices, can use an explicit precision such as `%.7f` or `%.2f`.
 
## Why Do Hexadecimal and Octal Use Sign and Magnitude?

`%x` of `-42` produces `-2a`, not a bit pattern such as `ffffffd6`.

### Reasoning

A two's-complement result depends on the width of the integer (32 or 64 bits), which differs between languages and can even differ between platforms.  
Sign-and-magnitude representation does not depend on integer width, so the result is the same everywhere.

## Why Are Some Values Errors Instead of Output?

`NaN`, infinity, and very large values in `%f`, `0` and surrogate code points in `%c`, booleans and null as arguments, and invalid UTF-8 input are all `LexFormatError`.

### Reasoning

For these cases, host languages disagree on what to print or cannot represent the value in the required form.  
Inventing an output for them would add another rule that every runtime would have to implement and test.  
An error is consistent across languages and tells the developer that the call is invalid.

## Why Are Width and Precision Limited?

`MAX_WIDTH` and `MAX_PREC` are part of the specification rather than being left to each runtime.

### Reasoning

A format string is data. An arbitrarily large width could require a runtime to allocate a huge output buffer or could overflow an integer while the width is being parsed.  
A fixed limit checked while reading the digits prevents the format from requesting arbitrarily large widths or precisions and ensures that every runtime applies the same limits.  
The `MAX_PREC` of 15 and the `2^63` limit on `%f` also allow a runtime to perform the required exact rounding with 128-bit integers instead of requiring a general-purpose big-number library.
 
## Why Are Arguments Never Processed Again?

A substituted argument is inserted as-is. Its `%` and `\` characters are never interpreted.

### Reasoning

Arguments often come from users or files. If a `%s` inside an argument were treated as a placeholder, the data itself could change the formatting of the message.  
Escapes are processed before placeholders, and replacement output is never rescanned. This keeps translation text and inserted data separate.

## Why Are Locale and Name Validated Before Building a Path?

A runtime builds a file path from the locale and the entry-file name. These values may come from an environment variable, a configuration file, or a user.

### Reasoning

Without validation, a value such as `../secret` could point outside the language directory.  
The specification therefore allows only letters, digits, `_`, and `-`, and requires validation before the filesystem is accessed.
 
## Why Are Trailing Spaces in Values Kept?

Values are trimmed on the left only. Whitespace at the end is part of the value.

### Reasoning

Some translations intentionally end with a space, for example when a label is followed by inserted text. Removing that space would silently change the text.  
Keeping the rule simple—the value is everything after the separator, with leading whitespace removed—means that a runtime never has to decide which trailing whitespace matters.  
The trade-off is that trailing spaces are invisible in many editors. This is why a line ending, including the CR in CRLF, is never part of the value.

## Why Are Keys Case-Sensitive?

Lexis treats keys exactly as written.  
For example:

```text
welcome::
Welcome::
```

### Reasoning

Case-sensitive keys preserve exactness and avoid runtime-specific normalization rules.  
Different languages and runtimes handle case conversion differently. Treating keys exactly as written keeps behavior predictable and portable.

## Why No Multiline Blocks?

Rejected example:

```text
message::
    Line 1
    Line 2
```

### Reasoning

Multiline syntax introduces additional grammar rules.  
Lexis instead uses escape sequences:

```text
message::Line 1\nLine 2
```

This preserves a single-line parsing model while still allowing multiline output.

## Why One Translation Per Line?

Lexis stores exactly one translation entry per line.  
For example:

```text id="w2z8qk"
welcome::Welcome
error_file::File not found
```

### Reasoning

A one-line model keeps parsing simple and deterministic.  
It allows runtimes to process files line by line without requiring stateful parsers or multiline grammar rules.  
This improves portability and reduces implementation complexity.

## Why UTF-8?

UTF-8 is the standard encoding for text interchange and supports multilingual content without requiring separate encodings for different languages.  
Lexis therefore requires UTF-8 for `.lex` files.  
A leading UTF-8 BOM is handled explicitly by the specification rather than being left to the host language's file-reading behavior. This avoids differences between runtimes, since some libraries remove the BOM automatically while others preserve it.

## Why Is Lexis Runtime-Agnostic?

Lexis does not define a reference platform or implementation.  
The same `.lex` file should behave identically regardless of which runtime reads it—a Bash script, a PHP backend, a Lua game, or a Swift mobile app.  
The format defines behavior.  
The runtime defines the implementation.

## Why Is the Specification Separate From the Runtime?

Lexis defines a format, not an implementation.  
Different runtimes may use different:

- parsers
- caches
- data structures
- optimization strategies

As long as observable behavior remains compliant with the specification, implementation details are left to runtime authors.  
This separation keeps Lexis portable across languages without requiring a specific architecture.

## Why No Tooling Requirements?

Lexis does not require generators, compilers, extractors, or build steps.

### Reasoning

Translation files should remain ordinary text files.  
A valid `.lex` file can be created, edited, reviewed, and versioned using any text editor.  
Tooling may exist around Lexis, but it is never required to use the format.

## Why "The Format Is the Law"?

The Lexis specification defines observable behavior.  
Runtime implementations may differ internally:

- data structures
- caching strategies
- optimization techniques

As long as they comply with the specification, runtimes must produce the same results.  
This principle allows implementations to evolve without fragmenting the ecosystem.

## Why a Directory Layout With a Named Entry File?

The directory layout (`{locale}/{name}.lex`, with `name = "main"` by default) allows `load()` to select a named entry file within a locale directory.  
`main` is the default value for `name`; it is not a hardcoded filename.

## A Note on Extensions

Lexis is intentionally kept small and stable.  
Future versions or implementations may define extensions, but extensions are outside the scope of the core Lexis specification.  
Extensions must not change the meaning of valid core Lexis files.
 
## What Does Lexis Optimize For?

Lexis prioritizes:

1. Simplicity
2. Portability
3. Predictability
4. Readability
5. Performance

in that order.  
When trade-offs are required, simplicity is generally preferred.

## Future Features

New features are evaluated using a simple question:

> Does this improve portability and predictability without significantly increasing complexity?

If the answer is no, the feature is usually rejected.  
Lexis is intended to remain small by design.

## Why Prioritize Backward Compatibility?

Translation files tend to live for many years.  
A format that changes frequently creates unnecessary migration work for users and runtime authors.  
Lexis therefore prefers stability over feature growth.  
The goal is to keep existing valid files usable across future compatible releases.

## Closing Principle

Lexis is not designed to be the most powerful translation system.  
It is designed to be a simple translation system that remains portable across languages.  
When simplicity and feature growth conflict, simplicity usually wins.

> *The format is the law. The implementation is free.*
