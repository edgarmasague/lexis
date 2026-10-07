# Lexis Format Specifiers

This document is normative. It defines the exact runtime behavior of every placeholder listed in section 7 of `LEX_FORMAT_SPEC.md`, with enough precision for two independent runtimes, written in different languages, to produce identical output for every case in `TESTS.md`.

Where this document and section 7 of `LEX_FORMAT_SPEC.md` overlap, the two specifications MUST remain consistent.
The grammar and the limits (`MAX_WIDTH`, `MAX_PREC`) are defined in section 7 of `LEX_FORMAT_SPEC.md` and only referenced here.

A runtime MUST NOT delegate formatting to the host language's native `printf`/`sprintf` and assume the result matches. Hosts implementations differ, particularly in rounding, negative hexadecimal formatting, and float-to-string conversion. See Differences From Host Printf at the end of each section.

## 1. Specifiers

| Specifier    | Accepts                                                     | Produces                      |
| ------------ | ----------------------------------------------------------- | ----------------------------- |
| `%s`         | string, integer, float                                      | string                        |
| `%d` / `%i`  | integer, integral float, integer string                     | base-10 integer               |
| `%f`         | integer, float, decimal string                              | decimal, fixed-point          |
| `%x`         | integer, integral float, integer string                     | lowercase hex, sign-magnitude |
| `%o`         | integer, integral float, integer string                     | octal, sign-magnitude         |
| `%c`         | integer, integral float, integer string (a code point)      | one character                 |
| `%%`         | *(consumes no argument)*                                    | literal `%`                   |

Any other argument type (boolean, null, list, map, object) MUST raise `LexFormatError` for every specifier.  
If the host language represents booleans as integers (for example, Python), the runtime MUST still reject booleans explicitly.

## 2. Grammar and Argument Matching

The grammar is closed (section 7.1 of `LEX_FORMAT_SPEC.md`):

```text
%[-][0][width][.precision]specifier
```

- A `%` sequence that does not match the grammar exactly MUST be treated as literal text. The `%` is emitted as-is, and scanning continues with the next character.
- Precision is valid only with `f`. `%.3s` and `%.2d` MUST be treated as literal text.
- A `width` greater than `MAX_WIDTH` or a `precision` greater than `MAX_PREC` MUST be treated as literal text. The limit MUST be checked while reading the digits, never after converting them to an integer.
- A lone `%`, or a `%` followed by an incomplete placeholder at the end of the value (`%`, `%5`, `%-0`), MUST be treated as literal text, not an error.
- Placeholders MUST consume arguments strictly from left to right.
- `%%` MUST produce a literal `%` and MUST NOT consume an argument.
- Fewer arguments than placeholders MUST raise `LexFormatError`.
- Extra arguments MUST be ignored.
- A substituted argument MUST be inserted as-is. Its content MUST NOT be scanned again for escape sequences or placeholders.
- Positional forms such as `%1$s` do not exist and MUST be treated as literal text.

## 3. Padding (all specifiers)

- `width` is a minimum measured in Unicode code points, not bytes or UTF-16 code units.
- A value longer than `width` MUST NOT be truncated.
- `-` MUST left-align the value and pad it with spaces on the right. If both `-` and `0` are present, `-` takes precedence and `0` MUST be ignored.
- `0` MUST use zero padding only for `%d`, `%i`, `%f`, `%x`, and `%o`. For `%s` and `%c`, `0` MUST be ignored and padding MUST use spaces.
- With zero padding, the sign MUST appear before the zeros. For example, `%05d` with `-42` produces `-0042`, and `%08.2f` with `-3.14159` produces `-0003.14`.
- For floating-point values, precision MUST be applied before width padding. The resulting value, including its sign, MUST then be padded to the requested width.

## 4. `%s`, String

- A string is written as-is.
- An integer is written in decimal.
- A float is written exactly as `%f` without a precision would write it (section 6).
- A string argument that is not valid UTF-8 is a `LexFormatError`.
- Booleans and null MUST raise `LexFormatError`.

### Differences From Host Printf

C's `%s` only takes a `char *`. Lexis `%s` also accepts integers and floats, because most host languages do not provide a single portable way to convert a float to text.

## 5. `%d` / `%i`, Integer

The resulting value MUST be a signed 64-bit integer. The accepted input are:

1. **Integer**: used as-is.
2. **Float** MUST be finite, has an integral value, and be within the signed 64-bit range. It is used as its integer value.
3. **String** MUST match `^-?[0-9]+$` and represent a value within the signed 64-bit range. It is parsed as an integer.

All other inputs MUST raise `LexFormatError`, including:

- A float with a fractional part (`3.7`), `NaN` or infinity.
- A string that does not match the pattern (`"abc"`, `"4.0"`, `"+5"`, `" 5"`, `""`).
- A value outside the signed 64-bit range, including `1e19` and `"9223372036854775808"`.
- A boolean.

The range MUST be checked before converting. Casting an out-of-range float to an integer is undefined or saturating in several hosts languages, so a runtime that converts first cannot reliably detect the original range.

A runtime MUST represent the full signed 64-bit range without precision loss. A host whose native number type cannot represent this range exactly, such as a float-backed number type, MUST use a wider integer representation for this path.

### Differences From Host Printf

C's `%d` does not accept a float or a string. Lexis supports both. Host languages also differ in how they handle strings such as `"abc"`; some may silently convert them to `0`. Lexis MUST NOT perform such conversions.

## 6. `%f`, Float

Accepted inputs are integers, floats, and strings matching `^-?[0-9]+(\.[0-9]+)?$`.

- An integer MUST be converted to the nearest double, with ties to even.
- A string MUST be converted to the nearest double using a correctly rounded decimal parser.
- `NaN`, positive infinity, negative infinity, and any value whose absolute value is `2^63` or greater MUST raise `LexFormatError`.

### Precision

- `%.Nf` MUST write exactly `N` digits after the decimal point, where `N` is from `0` to `MAX_PREC`.
- `%.0f` MUST write no decimal point.
- `%f` without a precision MUST round to 6 decimal places, remove trailing zeros, and then remove a trailing decimal point.

Examples:

| Value        |       `%f` |
| :----------- | ---------: |
| `3.14`       |     `3.14` |
| `3.0`        |        `3` |
| `100.0`      |      `100` |
| `0.1 + 0.2`  |      `0.3` |
| `1/3`        | `0.333333` |
| `1.23456789` | `1.234568` |
| `0.0000004`  |        `0` |

Values with an absolute value smaller than `0.0000005` are written as `0` with the default precision. An explicit precision such as `%.7f` MUST be used to preserve additional decimal places.

### Rounding

Rounding MUST use the actual binary value of the double, not its decimal representation.

When the discarded portion is exactly halfway between two values, the result MUST be rounded away from zero:

- `%.0f` of `2.5` MUST produce `3`.
- `%.0f` of `-2.5` MUST produce `-3`.
- `%.0f` of `0.5` MUST produce `1`.
- `%.0f` of `1.5` MUST produce `2`.

For example, `1.005` is not exactly representable as a double. Its actual value is slightly below `1.005`, so `%.2f` of `1.005` MUST produce `1.00`.

A runtime MUST NOT round through an intermediate decimal-string representation. Doing so can produce incorrect results for values such as `1.005`.

### Sign of Zero

A zero result MUST never be written with a minus sign.

- `%.2f` of `-0.001` MUST produce `0.00`.
- `%f` of `-0.0` MUST produce `0`.

### Notation

`%f` MUST never use scientific notation.

Because the absolute value MUST be less than `2^63`, the integer part fits in at most 19 digits. Output MUST always use plain fixed-point notation.

### Differences From Host Printf

- C's `%f` writes 6 decimal places by default. Lexis removes trailing zeros.
- C rounds exact ties to even (`%.0f` of `2.5` produces `2`). Lexis rounds ties away from zero. Several other hosts, including Python, Go, and Rust, also round ties to even, while Java and JavaScript use different rules. No host provides exactly the behavior defined by Lexis.
- C writes `-0.00` for `-0.001`. Lexis writes `0.00`.
- C writes `nan` and `inf`. Lexis raises `LexFormatError`.
- Hosts that use shortest-representation conversion may print `0.1 + 0.2` as `0.30000000000000004`. Lexis does not use shortest-representation conversion.

## 7. `%x` / `%o`, Hexadecimal and Octal

`%x` and `%o` use the same input conversion and error rules as `%d` and `%i`.

- `%x` MUST use lowercase hexadecimal digits (`ff`, not `FF`).
- Negative values MUST use sign-and-magnitude representation, never two's complement.
- `%x` of `-42` MUST produce `-2a`.
- `%o` of `-8` MUST produce `-10`.
- With zero padding, the sign MUST appear before the zeros. `%05x` of `-42` MUST produce `-002a`.

### Differences From Host Printf

C's `%x` formats negative integers using the two's-complement bit pattern of the integer type. The result therefore depends on the integer width.

Lexis always writes a leading `-` followed by the magnitude. The result is independent of the host integer width.


## 8. `%c`, Character

The argument MUST be converted using the same input conversion rules as `%d` and `%i`, then interpreted as a Unicode code point.

- A single-character string MUST NOT be accepted as a code point and MUST raise `LexFormatError`.
- The valid range is `1` to `0x10FFFF`, excluding the surrogate range `0xD800` to `0xDFFF`.
- `0`, negative values, values above `0x10FFFF` (`1114112`), and surrogate code points MUST raise `LexFormatError`.
- Code points above `U+00FF` MUST be written as their actual characters. For example, `8364` MUST produce `€`, and `128075` MUST produce `👋`.
- The result MUST contain exactly one Unicode code point before padding.

## 9. `%%`, Literal Percent

- Each `%%` MUST produce exactly one literal `%`.
- `%%` MUST NOT consume an argument or count as a placeholder.
- Each `%%` pair MUST resolve independently from left to right. `%%%%` MUST produce `%%`.
- `%%s` MUST produce `%s` as literal text and MUST NOT consume an argument.

## 10. Unsupported Forms

Any `%` sequence that does not match the grammar MUST remain in the output exactly as written, including the `%`.

Examples include:

- Unknown specifier letters: `%q`, `%u`, `%X`, `%e`, `%g`, `%b`, `%n`, `%p`.
- Unsupported flags: `%+d`, `% d`, `%#x`.
- Length modifiers: `%ld`, `%lld`, `%hd`, `%zu`.
- `*` widths and precisions: `%*d`, `%.*f`.
- Positional forms: `%1$s`.
- Precision with a specifier other than `f`: `%.3s`, `%.2d`.
- Precision with no digits: `%.f`.
- Flags in an invalid order: `%0-5d`.
- A width or precision above its limit.

Unsupported forms MUST NOT consume an argument and MUST NOT raise an error.

Only a recognized placeholder with an invalid argument MUST raise `LexFormatError`.

## 11. Error Summary

| Condition                                                           | Error                  |
| ------------------------------------------------------------------- | ---------------------- |
| Fewer arguments than placeholders                                   | `LexFormatError`       |
| Argument of a type the specifier does not accept (boolean, null...) | `LexFormatError`       |
| `%s` given a string that is not valid UTF-8                         | `LexFormatError`       |
| `%d` `%i` `%x` `%o` `%c` given a non-integer string                | `LexFormatError`       |
| `%d` `%i` `%x` `%o` `%c` given a float with a fractional part       | `LexFormatError`       |
| `%d` `%i` `%x` `%o` `%c` given a value outside the 64-bit range     | `LexFormatError`       |
| `%c` given `0`, a negative, a surrogate, or a value above `0x10FFFF`| `LexFormatError`       |
| `%f` given `NaN`, infinity, or an absolute value of 2^63 or more    | `LexFormatError`       |
| `%f` given a string that is not a decimal number                    | `LexFormatError`       |
| Key not found                                                       | `LexKeyNotFoundError`  |

Everything else defined by this document MUST NOT raise an error. This includes every unsupported form in section 10, which MUST remain literal text.

## 12. Reference Algorithm (informative)

The rules above are normative. The following pseudocode is one possible implementation. It is intentionally written so that it can be translated almost line by line into any language.

`at(s, j)` returns the character at index `j`, or an empty string when `j` is past the end of the string.

```text
format(fmt, args):
    out = ""; i = 0; argi = 0
    while i < len(fmt):
        if fmt[i] != '%':
            out += fmt[i]; i += 1; continue

        ph = parse_placeholder(fmt, i)
        if ph == null:                        # does not match the grammar: literal
            out += '%'; i += 1; continue
        if ph.spec == '%':                    # %% never consumes an argument
            out += '%'; i = ph.end; continue

        if argi >= len(args): raise LexFormatError
        out += render(ph, args[argi])         # the result is never scanned again
        argi += 1; i = ph.end
    return out


parse_placeholder(fmt, i):
    j = i + 1
    if at(fmt, j) == '%': return {spec:'%', end: j + 1}

    left = false; zero = false; width = 0; prec = null
    if at(fmt, j) == '-': left = true; j += 1
    if at(fmt, j) == '0': zero = true; j += 1
    while isdigit(at(fmt, j)):
        width = width * 10 + digit(at(fmt, j))
        if width > MAX_WIDTH: return null     # checked while reading the digits
        j += 1

    if at(fmt, j) == '.':
        j += 1
        if not isdigit(at(fmt, j)): return null
        prec = 0
        while isdigit(at(fmt, j)):
            prec = prec * 10 + digit(at(fmt, j))
            if prec > MAX_PREC: return null
            j += 1

    spec = at(fmt, j)
    if spec not in "sdifxoc": return null
    if prec != null and spec != 'f': return null

    if left: zero = false
    return {spec, left, zero, width, prec, end: j + 1}


pad(text, ph, numeric):
    n = ph.width - codepoint_count(text)
    if n <= 0: return text
    if ph.left: return text + spaces(n)
    if ph.zero and numeric:
        if text[0] == '-': return '-' + zeros(n) + text[1:]
        return zeros(n) + text
    return spaces(n) + text


render(ph, arg):
    switch ph.spec:
        's':      return pad(to_str(arg), ph, false)
        'd','i':  return pad(fmt_int(to_int(arg), 10), ph, true)
        'x':      return pad(fmt_int(to_int(arg), 16), ph, true)
        'o':      return pad(fmt_int(to_int(arg), 8),  ph, true)
        'c':      return pad(fmt_char(to_int(arg)), ph, false)
        'f':      return pad(fmt_float_default(to_float(arg), ph.prec), ph, true)


to_str(arg):
    if arg is a string:
        if not valid_utf8(arg): raise LexFormatError
        return arg
    if arg is an integer: return decimal(arg)
    if arg is a float:     return fmt_float_default(to_float(arg), null)
    raise LexFormatError                      # boolean, null, anything else


to_int(arg):
    if arg is a boolean: raise LexFormatError
    if arg is an integer: n = arg
    elif arg is a float:
        if not finite(arg) or arg != floor(arg): raise LexFormatError
        if arg < -2^63 or arg >= 2^63: raise LexFormatError   # before converting
        n = int(arg)
    elif arg is a string:
        if arg does not match ^-?[0-9]+$: raise LexFormatError
        n = parse_int64(arg)                  # raises LexFormatError on overflow
    else: raise LexFormatError
    return n


fmt_int(n, base):                             # sign and magnitude, lowercase
    sign = (n < 0) ? "-" : ""
    m = magnitude of n as an unsigned 64-bit value   # careful with -2^63
    digits = ""
    if m == 0: digits = "0"
    while m > 0:
        digits = "0123456789abcdef"[m % base] + digits
        m = m / base
    return sign + digits


fmt_char(cp):
    if cp < 1 or cp > 0x10FFFF or (0xD800 <= cp <= 0xDFFF): raise LexFormatError
    return utf8_encode(cp)


to_float(arg):
    if arg is a boolean: raise LexFormatError
    if arg is an integer or a float: x = double(arg)
    elif arg is a string matching ^-?[0-9]+(\.[0-9]+)?$: x = parse_double(arg)
    else: raise LexFormatError
    if x is NaN or infinite or abs(x) >= 2^63: raise LexFormatError
    return x


fmt_float_default(x, prec):
    if prec != null: return fmt_float(x, prec)
    s = fmt_float(x, 6)
    if '.' in s:
        strip trailing '0' characters from s
        strip a trailing '.' from s
    return s                                  # "0" when it rounded to zero


fmt_float(x, p):                              # exactly p decimals, p <= MAX_PREC
    bits = bits_of_double(x)
    neg  = bits >> 63
    ex   = (bits >> 52) & 0x7FF
    fr   = bits & (2^52 - 1)
    if ex == 0: m = fr;        e = -1074      # subnormal
    else:       m = fr | 2^52; e = ex - 1075  # abs(x) = m * 2^e, exact

    if e >= 0:
        q = (m << e) * 10^p                   # already an integer
    else:
        k = -e
        if k > 110:
            q = 0                             # too small to reach the rounding threshold
        else:
            scaled = m * 10^p                 # fits in 128 bits
            q = scaled >> k
            r = scaled & (2^k - 1)
            if r >= 2^(k - 1): q += 1         # a tie rounds up in magnitude

    digits = decimal(q)
    if len(digits) < p + 1: digits = zeros(p + 1 - len(digits)) + digits
    if p == 0: body = digits
    else:      body = digits[: -p] + "." + digits[-p :]

    if neg and q != 0: return "-" + body     # never "-0" or "-0.00"
    return body
```

The limits (`MAX_PREC` = 15, and an absolute value below `2^63`) allow `fmt_float` to use 128-bit unsigned integers: the largest intermediate value is below `2^113`. A runtime without 128-bit integers MAY use a big-integer type or a small fixed-size array of 32-bit limbs with multiply-by-10, shift, and compare operations.