# lexis.py - LEXIS Independent Translation Engine
# Official Python Runtime

import os
import re
from decimal import Context, Decimal, ROUND_HALF_UP
from typing import Any


class LexFileNotFoundError(Exception):
    # Raised when no .lex file is found for the requested locale.
    pass


class LexKeyNotFoundError(Exception):
    # Raised when a key is not found in the loaded .lex file.
    pass


class LexParseError(Exception):
    # Raised when .lex file contains malformed lines.
    pass


class LexFormatError(Exception):
    # Raised for placeholder errors: a missing argument, or an argument
    # that is invalid for its specifier (type, range, %c code point...).
    pass


# {language} or {language}_{REGION}. fullmatch() is always used, so a
# trailing newline can never slip through.
_LOCALE_PATTERN: re.Pattern[str] = re.compile(
    r"[A-Za-z0-9]+(?:[_-][A-Za-z0-9]+)?"
)
_NAME_PATTERN: re.Pattern[str] = re.compile(r"[A-Za-z0-9_-]+")

# One line with its LF, or a last line without one. A lone CR is content.
_LINES:        re.Pattern[str] = re.compile(r"[^\n]*\n|[^\n]+")
# %[-][0][width][.precision]specifier, or %%
_PLACEHOLDER:  re.Pattern[str] = re.compile(
    r"%(?:(?P<pct>%)|(?P<left>-)?(?P<zero>0)?(?P<width>[0-9]+)?"
    r"(?:\.(?P<prec>[0-9]+))?(?P<spec>[sdifxoc]))"
)
# Strict argument formats for strings used with %d / %f
_PLAIN_INT:     re.Pattern[str] = re.compile(r"-?[0-9]+")
_PLAIN_DECIMAL: re.Pattern[str] = re.compile(r"-?[0-9]+(?:\.[0-9]+)?")

_DEFAULT_LOCALE: str = "en"

# Placeholder limits
_MAX_WIDTH:         int = 1024
_MAX_PRECISION:     int = 15
_WIDTH_DIGITS:      int = len(str(_MAX_WIDTH))
_PRECISION_DIGITS:  int = len(str(_MAX_PRECISION))
_DEFAULT_PRECISION: int = 6  # %f without a precision

# Argument ranges
_INT64_MIN:      int = -2 ** 63
_INT64_MAX:      int = 2 ** 63 - 1
_FLOAT_LIMIT:    int = 2 ** 63  # %f accepts |value| below this
_MAX_CODE_POINT: int = 0x10FFFF
_SURROGATES:   range = range(0xD800, 0xE000)

# Wide enough for the largest intermediate value of %f (below 2^113).
_FLOAT_CONTEXT: Context = Context(prec=80, rounding=ROUND_HALF_UP)


class Lexis:
    """
    Lexis Engine
    Load .lex files and provides key based translation with
    printf-style placeholder support.
    Loading strategy:
        Eager - entire file is parsed and validated on load()
        Lazy  - escape sequences are processed only on first access.
    """

    # Official escape sequences
    _ESCAPE_SEQUENCES: dict[str, str] = {
        r'\\': '\\',
        r'\n': '\n',
        r'\t': '\t',
        r'\r': '\r',
        r'\b': '\b',
        r'\v': '\v',
        r'\"': '"',
    }

    def __init__(
            self,
            lang_dir: str,
            locale:   str | None = None,
            fallback_locale: str = "en",
            name:            str = "main"
    ) -> None:
        """
        Initialize Lexis with a language directory and optional locale.
        Args:
            lang_dir: Directory containing .lex files.
            locale: Locale code. Auto-detected if None.
            fallback_locale: Fallback locale code. Default is "en".
            name: Entry-file name for the directory layout.
                Default is "main".

        """
        self.lang_dir:                       str = ""
        self.locale:                         str = ""
        self.fallback_locale:                str = "en"
        self.name:                           str = "main"
        self.filepath:                       str = ""
        self._raw_translations:   dict[str, str] = {}
        self._cache_translations: dict[str, str] = {}
        self.load(lang_dir, locale, fallback_locale, name)

    def _detect_locale(self) -> str:
        """
        Safely detect system locale from environment.
        Returns:
            locale code: "language" or "language_REGION" (e.g. 'en', 'es_VE').
        """
        lang: str = os.environ.get("LANG", "")
        lang = re.split(r"[.@]", lang, maxsplit=1)[0].strip()
        # Handle C, POSIX, or missing LANG
        if not lang or lang in ("C", "POSIX"):
            return _DEFAULT_LOCALE
        parts: list = lang.replace("-", "_").split("_")
        if len(parts) > 2:
            # zh_Hans_CN -> zh_CN: keep only language and region
            parts = [parts[0], parts[-1]]
        if not _LOCALE_PATTERN.fullmatch("_".join(parts)):
            return _DEFAULT_LOCALE  # a garbage LANG must not break loading
        if len(parts) == 1:
            return parts[0].lower()
        return f"{parts[0].lower()}_{parts[1].upper()}"

    def _resolve_filepath(
            self,
            lang_dir: str,
            locale: str,
            fallback_locale: str,
            name: str
    ) -> str:
        """
        Resolve the .lex file path after validating and normalizing
        the inputs.
        Regional locale (es_VE):
            es_VE.lex, es_VE/{name}.lex, es.lex, es/{name}.lex
        Language-only locale (es):
            es.lex, es/{name}.lex
        The same steps are then applied to fallback_locale. Updates
        self.locale to the code of the file actually found.
        Returns:
            Absolute path to the .lex file.
        Raises:
            LexFileNotFoundError:
                If an input is invalid (before touching the filesystem)
                or no file is found.
        """
        # Validate and normalize every input before touching the filesystem
        codes: list[str] = []
        for code in (locale, fallback_locale):
            if (not isinstance(code, str)
                    or not _LOCALE_PATTERN.fullmatch(code)):
                raise LexFileNotFoundError(f"Invalid locale code: {code!r}")
            parts: list[str] = code.replace("-", "_").split("_")
            codes.append(
                parts[0].lower() if len(parts) == 1
                else f"{parts[0].lower()}_{parts[1].upper()}"
            )
        if not isinstance(name, str) or not _NAME_PATTERN.fullmatch(name):
            raise LexFileNotFoundError(f"Invalid entry-file name: {name!r}")
        try:
            lang_dir = os.fspath(lang_dir)
        except TypeError as error:
            raise LexFileNotFoundError(
                f"Invalid language directory: {lang_dir!r}"
            ) from error

        # Every place to look, in order: es_VE, then es, then the fallback
        candidates: list[tuple[str, str]] = []
        for requested in codes:
            for code in dict.fromkeys((requested, requested.split("_")[0])):
                candidates.append(
                    (code, os.path.join(lang_dir, f"{code}.lex"))
                )
                candidates.append(
                    (code, os.path.join(lang_dir, code, f"{name}.lex"))
                )
        for code, path in candidates:
            if os.path.isfile(path):
                self.locale = code
                return os.path.abspath(path)
        raise LexFileNotFoundError(
            f"No .lex file found for locale '{codes[0]}' "
            f"(fallback '{codes[1]}') in '{lang_dir}'"
        )

    def _unescape(self, value: str) -> str:
        """
        Process escape sequences in values.
        Args:
            value: Raw value string from .lex file.
        Returns:
            Value with escape sequences converted.
        """
        result: list[str] = []
        i: int = 0
        while i < len(value):
            # Check for backslash followed by another character
            if value[i] == "\\" and i + 1 < len(value):
                seq = value[i:i + 2]
                if seq in self._ESCAPE_SEQUENCES:
                    result.append(self._ESCAPE_SEQUENCES[seq])
                    i += 2
                    continue
            result.append(value[i])
            i += 1
        return "".join(result)

    def _parse_line(
            self,
            raw_line: str,
            line_num: int
    ) -> tuple[str, str] | None:
        """
        Parse a single line from .lex file.
        Args:
            raw_line: Raw line string.
            line_num: Line number for error reporting.
        Returns:
            Tuple of (key, value) or None if line skipped.
        Raises:
            LexParseError:
                On malformed lines or duplicates.
        """
        line: str = raw_line
        if line.endswith("\n"):
            line = line[:-1]
            if line.endswith("\r"):
                line = line[:-1]
        # Skip empty lines or comments
        if not line.strip() or line.lstrip().startswith("#"):
            return None
        # Every valid entry must contain the separator
        if "::" not in line:
            raise LexParseError(
                f"Malformed line {line_num} in {self.filepath}: "
                f"missing '::' separator"
            )
        # Split on first occurrence of separator
        key: str
        value: str
        key, _, value = line.partition("::")
        key = key.strip()
        # Key cannot be empty after trimming
        if not key:
            raise LexParseError(
                f"Malformed line {line_num} in {self.filepath}: "
                f"empty key"
            )
        # Duplicate keys are not allowed
        if key in self._raw_translations:
            raise LexParseError(
                f"Duplicate key '{key}' at "
                f"line {line_num} in {self.filepath}"
            )
        return key, value.lstrip()

    def _load_file(self) -> None:
        """
        Load and parse the entire .lex file into memory.
        Raises:
            LexFileNotFoundError:
                If file disappears during load.
            LexParseError:
                If the file is not valid UTF-8.
        """
        self._raw_translations = {}
        self._cache_translations = {}
        try:
            with open(self.filepath, "rb") as file:
                data: bytes = file.read()
        except OSError as error:
            # Race condition: file deleted after resolve but before open
            raise LexFileNotFoundError(
                f"File not found: {self.filepath}"
            ) from error
        try:
            # utf-8-sig removes a leading BOM (and only a leading one)
            text: str = data.decode("utf-8-sig")
        except UnicodeDecodeError as error:
            raise LexParseError(
                f"Invalid UTF-8 in {self.filepath}: {error}"
            ) from error
        for line_num, line in enumerate(_LINES.findall(text), start=1):
            result: tuple[str, str] | None = self._parse_line(line, line_num)
            if result is not None:
                self._raw_translations[result[0]] = result[1]

    def _get_value(self, key: str) -> str:
        """
        Fetch value from cache.
        Args:
            key: Translation key.
        Returns:
            Unescaped (processed) value string
        Raises:
            LexKeyNotFoundError:
                If key not found.
        """
        if key not in self._raw_translations:
            raise LexKeyNotFoundError(
                f"Key not found: '{key}'"
            )
        if key not in self._cache_translations:
            self._cache_translations[key] = self._unescape(
                self._raw_translations[key]
            )
        return self._cache_translations[key]

    def _format(self, template: str, args: tuple) -> str:
        """
        Lexis' own printf: apply placeholders to an unescaped template.
        Anything that is not a valid placeholder stays literal and uses
        no argument. Arguments are never scanned again.
        Raises:
            LexFormatError:
                If an argument is missing or invalid for its specifier.
        """

        def format_float(arg: Any, decimals: int, strip_zeros: bool) -> str:
            # Text for %f, and %s with a float
            if isinstance(arg, str) and not _PLAIN_DECIMAL.fullmatch(arg):
                raise ValueError("not a decimal number")
            number: Decimal = Decimal(
                float(arg) if isinstance(arg, str) else arg
            )
            if not -_FLOAT_LIMIT < number < _FLOAT_LIMIT:
                raise ValueError("out of range")
            text: str = format(number.quantize(
                Decimal(1).scaleb(-decimals), ROUND_HALF_UP,
                _FLOAT_CONTEXT), "f")
            if strip_zeros and "." in text:
                text = text.rstrip("0").rstrip(".")
            if text.startswith("-") and not text.strip("-0."):
                text = text[1:]
            return text

        def format_integer(arg: Any, spec: str) -> str:
            # Text for %d %i %x %o %c, and %s with an integer
            if isinstance(arg, str) and not _PLAIN_INT.fullmatch(arg):
                raise ValueError("not an integer")
            number: Decimal = Decimal(arg)
            if (not _INT64_MIN <= number <= _INT64_MAX
                    or number != number.to_integral_value()):
                raise ValueError("not a 64-bit integer")
            integer: int = int(number)
            if spec == "c":
                if (not 1 <= integer <= _MAX_CODE_POINT
                        or integer in _SURROGATES):
                    raise ValueError("invalid code point")
                return chr(integer)
            if spec in "xo":
                return "-" * (integer < 0) + format(abs(integer), spec)
            return str(integer)

        def pad_text(
                text: str,
                spec: str,
                left: bool,
                zero: bool,
                width: int
        ) -> str:
            # Pad the text to its width
            if left:
                return text.ljust(width)
            if zero and spec in "dixof":
                return text.zfill(width)
            return text.rjust(width)

        out: list[str] = []
        cursor:    int = 0
        used:      int = 0
        while True:
            # Copy everything up to the next "%"
            start: int = template.find("%", cursor)
            if start == -1:
                out.append(template[cursor:])
                return "".join(out)
            out.append(template[cursor:start])
            # "%%", or a "%" that starts nothing valid, is a literal "%"
            placeholder: re.Match[str] | None = _PLACEHOLDER.match(
                template, start
            )
            cursor = placeholder.end() if placeholder else start + 1
            if placeholder is None or placeholder["pct"]:
                out.append("%")  # "%%", or a "%" that starts nothing valid
                continue
            # Out of limits: stays literal and uses no argument
            spec: str = placeholder["spec"]
            has_precision: bool = placeholder["prec"] is not None
            width_digits: str = (placeholder["width"] or "").lstrip("0")
            precision_digits: str = (placeholder["prec"] or "").lstrip("0")
            too_wide: bool = (len(width_digits) > _WIDTH_DIGITS
                              or int(width_digits or 0) > _MAX_WIDTH)
            bad_precision: bool = has_precision and (
                spec != "f"
                or len(precision_digits) > _PRECISION_DIGITS
                or int(precision_digits or 0) > _MAX_PRECISION
            )
            if too_wide or bad_precision:
                out.append(placeholder.group())  # literal, uses no argument
                continue
            width: int = int(width_digits or 0)
            decimals: int = (
                int(precision_digits or 0) if has_precision
                else _DEFAULT_PRECISION
            )
            # The argument
            if used >= len(args):
                raise LexFormatError(f"Missing argument for '%{spec}'")
            arg: Any = args[used]
            used += 1
            # Convert it to text. Any ValueError / TypeError /
            # ArithmeticError below means "invalid argument for this
            # specifier"
            text: str
            try:
                if isinstance(arg, bool) or arg is None:
                    raise ValueError("bool and None are never valid")
                if spec == "s" and isinstance(arg, str):
                    arg.encode("utf-8")  # raises if it is not valid UTF-8
                    text = arg
                elif spec == "f" or (spec == "s" and isinstance(arg, float)):
                    text = format_float(arg, decimals, not has_precision)
                else:  # %d %i %x %o %c, and %s with an integer
                    text = format_integer(arg, spec)
            except (TypeError, ValueError, ArithmeticError) as error:
                raise LexFormatError(
                    f"Invalid argument {arg!r} for '%{spec}'"
                ) from error

            # Width. len() counts code points. "-" wins over "0", and "0" only
            # applies to numbers
            out.append(pad_text(
                text, spec, bool(placeholder["left"]),
                bool(placeholder["zero"]), width
            ))

    def load(
            self,
            lang_dir: str,
            locale:   str | None = None,
            fallback_locale: str = "en",
            name:            str = "main"
    ) -> None:
        """
        Load a .lex file from the given directory.
        - If `locale` is not provided, it is detected from the environment.
        - If the requested locale is not found, falls back to
          `fallback_locale` (default "en").
        Args:
            lang_dir: Directory containing .lex files.
            locale: Locale code. Auto-detected if None.
            fallback_locale: Fallback locale code. Default is "en".
            name: Entry-file name for the directory layout.
                Default is "main".
        Raises:
            LexFileNotFoundError:
                If no suitable file is found or an input is invalid.
            LexParseError:
                If the file is malformed.
        """
        fallback_locale = (
            _DEFAULT_LOCALE if fallback_locale is None else fallback_locale
        )
        name = "main" if name is None else name
        if locale is None:  # only None auto-detects; "" is invalid
            locale = self._detect_locale()
        filepath: str = self._resolve_filepath(
            lang_dir, locale, fallback_locale, name
        )
        self.lang_dir = os.fspath(lang_dir)
        self.fallback_locale = fallback_locale
        self.name = name
        self.filepath = filepath
        self._load_file()

    def get(self, key: str, *args) -> str:
        """
        Get a translation by key with optional printf style format.
        Args:
            key: Translation key
            *args: Values for placeholders (%s, %d, etc.)
        Returns:
            Formatted translation string
        Raises:
            LexKeyNotFoundError:
                If key doesn't exist.
            LexFormatError:
                If an argument is missing or can't be coerced to
                the type its placeholder needs.
        """
        return self._format(self._get_value(key), args)

    def get_or_default(self, key: str, default: str, *args) -> str:
        """
        Get a translation or return a default value if key not found.
        Args:
            key: Translation key
            default: Default value if key not found
            *args: Values for placeholders
        Returns:
            Formatted translation string or default
        """
        if key in self._raw_translations:
            return self.get(key, *args)
        return self._format(default, args) if args else default

    def reload(
            self,
            locale:          str | None = None,
            fallback_locale: str | None = None,
            name:            str | None = None
    ) -> None:
        """
        Reload translations, optionally switching locale.
        Preserves the previous state on failure.
        Args:
            locale: New locale code. None keeps the current one
                (it does NOT trigger auto-detection).
            fallback_locale: New fallback locale code,
                or None to keep previous.
            name: New entry-file name, or None to keep the current one.
        """
        # Save current state
        previous: tuple[
            str, str, str, str, str, dict[str, str], dict[str, str]
        ] = (
            self.lang_dir,
            self.locale,
            self.fallback_locale,
            self.name,
            self.filepath,
            self._raw_translations,
            self._cache_translations
        )
        try:
            # Try to load new locale
            self.load(
                self.lang_dir,
                self.locale if locale is None else locale,
                self.fallback_locale if fallback_locale is None
                else fallback_locale,
                self.name if name is None else name
            )
        except (LexFileNotFoundError, LexParseError):
            # On failure: restore previous state and raise the error
            (
                self.lang_dir,
                self.locale,
                self.fallback_locale,
                self.name,
                self.filepath,
                self._raw_translations,
                self._cache_translations
            ) = previous
            raise

    def has(self, key: str) -> bool:
        """
        Return whether `key` exists in _raw_translations.
        Never raises and never touches the cache.
        """
        return self.__contains__(key)

    def keys(self) -> tuple:
        """
        Return all available translation keys.
        Returns:
            Snapshot (tuple) of the keys at the time of the call.
        """
        return tuple(self._raw_translations.keys())

    def len(self) -> int:
        """
        Return the number of keys in _raw_translations.
        An empty or comment-only file gives 0.
        """
        return self.__len__()

    def info(self) -> dict:
        """
        Return a snapshot of the runtime state.
        Returns:
            Dict with locale, fallback_locale, lang_dir, name, filepath,
            keys and cached_keys.
        """
        return {
            "locale": self.locale,
            "fallback_locale": self.fallback_locale,
            "lang_dir": self.lang_dir,
            "name": self.name,
            "filepath": self.filepath,
            "keys": len(self._raw_translations),
            "cached_keys": len(self._cache_translations),
        }

    def clear(self) -> None:
        """
        Clear _cache_translations.
        Raw translations and all other state are preserved;
        use reload() to reread the file.
        """
        self._cache_translations = {}

    def __repr__(self) -> str:
        # String representation for debugging
        return f"Lexis({self.info()!r})"

    def __len__(self) -> int:
        # Len(lex) to count loaded keys
        return len(self._raw_translations)

    def __contains__(self, key: str) -> bool:
        # "Key in lex" membership testing
        return isinstance(key, str) and key in self._raw_translations


if __name__ == "__main__":
    # Demo: Load translations and run basic operations
    try:
        base_dir: str = os.path.dirname(os.path.abspath(__file__))
        lang_dir: str = os.path.join(base_dir, "..", "..", "lang")
        lexis = Lexis(lang_dir)
        print(lexis.get("welcome", "LEX"))
        print(lexis.get("modules_available"))
        print(lexis.get("error_file", "foo.txt"))
        print(repr(lexis))

        lexis.reload("en")
        print(lexis.get("welcome", "Lexis"))

    except LexFileNotFoundError as error:
        print(f"[ERROR] {error}")
    except LexKeyNotFoundError as error:
        print(f"[ERROR] {error}")
    except LexFormatError as error:
        print(f"[ERROR] {error}")
    except LexParseError as error:
        print(f"[ERROR] {error}")
