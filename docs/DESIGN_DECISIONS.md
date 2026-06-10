# Lexis Design Decisions

This document explains the major design choices behind Lexis.

It is not part of the formal specification.

The specification defines behavior.

This document explains the reasoning.

---

# Core Principle

Lexis was designed around a simple idea:

> Translation files should be understandable without specialized tooling or complex parsing logic.

Every feature is evaluated against this principle.

When a feature increases complexity without significantly improving portability or predictability, it is usually rejected.

---

# Why a Flat Structure?

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

Nested structures require additional parsing rules and create implementation differences between runtimes.

Flat keys:

* are easier to parse
* are easier to validate
* are portable across languages
* avoid hierarchy-specific behavior

Hierarchy can still be represented through naming conventions:

```text
auth.login.title
auth.login.button
auth.logout.button
```

without introducing special syntax.

---

# Why Use `::` as a Separator?

Lexis requires a separator that is:

* visually distinct
* easy to detect
* simple to parse

Several alternatives were considered:

```text
=
:
->
```

The `::` separator was chosen because it is unlikely to appear accidentally in normal translation text while remaining easy for humans to recognize.

The parser only treats the first occurrence as a separator.

Everything after it belongs to the value.

---

# Why No Imports?

Lexis deliberately avoids file imports.

Example of a rejected feature:

```text
import common.lex
```

### Reasoning

Imports introduce:

* dependency chains
* load-order concerns
* circular references
* runtime-specific behavior

Lexis favors self-contained translation files.

A runtime should be able to load a file without resolving external dependencies.

---

# Why No Namespaces?

Namespaces were considered unnecessary.

The same organizational benefits can be achieved through key naming:

```text
auth.login.title
auth.login.button
settings.language.title
```

without introducing additional syntax or parser rules.

---

# Why No Pluralization System?

Pluralization rules differ dramatically across languages.

For example:

* English
* Arabic
* Russian
* Polish

all require different plural forms.

Embedding pluralization logic into the format would significantly increase complexity and reduce portability.

Lexis leaves pluralization to the application layer.

---

# Why No Conditions or Logic?

Rejected examples:

```text
@if user_is_admin
```

```text
count > 1 ? ...
```

### Reasoning

Translation files should contain text, not behavior.

Introducing logic transforms a translation format into a template language.

Lexis intentionally avoids this transition.

---

# Why Use Printf-Style Placeholders?

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

Printf-style formatting already exists in many programming languages:

* C
* Python
* Bash
* Go
* Java
* Rust
* PHP

This minimizes implementation effort and improves runtime portability.

---

# Why Are Keys Case-Sensitive?

Lexis treats keys exactly as written.

For example:

```text
welcome::
Welcome::
```

### Reasoning

Case-sensitive keys preserve exactness and avoid runtime-specific normalization rules.

Different languages and runtimes handle case conversion differently. Treating keys exactly as written keeps behavior predictable and portable.

---

# Why No Multiline Blocks?

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

which preserve a single-line parsing model.

---

# Why One Translation Per Line?

Lexis stores exactly one translation entry per line.

Example:

welcome::Welcome
error_file::File not found

### Reasoning

A one-line model keeps parsing simple and deterministic.

It allows runtimes to process files line-by-line without requiring stateful parsers or multiline grammars.

This improves portability and reduces implementation complexity.

---

# Why UTF-8?

UTF-8 has become the de facto standard for text interchange.

Translation files frequently contain multilingual content.

Supporting a single required encoding simplifies runtime implementations and avoids platform-specific behavior.

---

# Why Runtime-Agnostic?

Lexis does not define a reference platform.

The same `.lex` file should behave identically in:

* Python
* Bash
* C
* Lua
* JavaScript

The format defines behavior.

The runtime defines implementation.

---

# Why Is The Specification Separate From The Runtime?

Lexis defines a format, not an implementation.

Different runtimes may use different:

* parsers
* caches
* data structures
* optimization strategies

As long as observable behavior remains compliant with the specification, implementation details are left to runtime authors.

This separation allows Lexis to remain portable across languages without enforcing a specific architecture.

---

# Why No Tooling Requirements?

Lexis does not require generators, compilers, extractors, or build steps.

### Reasoning

Translation files should remain ordinary text files.

A valid `.lex` file can be created, edited, reviewed, and versioned using any text editor.

Tooling may exist around Lexis, but it is never required to use the format.

---

# Why "The Format Is The Law"?

The Lexis specification defines observable behavior.

Runtime implementations may differ internally:

* data structures
* caching strategies
* optimization techniques

but compliant runtimes must produce the same results.

This principle allows innovation without fragmenting the ecosystem.

---

# What Lexis Optimizes For

Lexis prioritizes:

1. Simplicity
2. Portability
3. Predictability
4. Readability
5. Performance

in that order.

When trade-offs are required, simplicity is generally preferred.

---

# Future Features

New features are evaluated using a simple question:

> Does this improve portability and predictability without significantly increasing complexity?

If the answer is no, the feature is usually rejected.

Lexis is intended to remain small by design.

---

# Why Prioritize Backward Compatibility?

Translation files tend to live for many years.

A format that frequently changes creates unnecessary migration work for users and runtime authors.

Lexis therefore prefers stability over feature growth.

The goal is that a valid Lexis 1.0 file remains valid throughout the entire 1.x series.

---

# Closing Principle

Lexis is not designed to be the most powerful translation system.

It is designed to be the simplest translation system that remains portable across languages.

When simplicity and feature growth conflict, simplicity usually wins.

---

*The format is the law. The implementation is free.*