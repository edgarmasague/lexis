# lexis.py - LEXIS Independent Translation Engine
# Official Python Runtime

import os


class LexFileNotFoundError(Exception):
    # Raised when no .lex file is found for the requested locale.
    pass


class LexKeyNotFoundError(Exception):
    # Raised when a key is not found in the loaded .lex file.
    pass


class LexParseError(Exception):
    # Raised when .lex file contains malformed lines.
    pass


class LEX:
    """
    Lexis Engine
    Load .lex files and provides key based translation with
    printf-style placeholder support.
    Loading strategy:
        Eager - entire file is parsed and validated on load()
        Lazy  - escape sequences are processed only on first access.
    """

    # Official escape sequences
    _ESCAPE_SEQUENCES = {
        r'\\': '\\',
        r'\n': '\n',
        r'\t': '\t',
        r'\r': '\r',
        r'\b': '\b',
        r'\v': '\v',
        r'\"': '"',
    }

    def __init__(
            self, lang_dir: str,
            locale: str = None,
            fallback_locale: str = "en"
    ):
        """
        Initialize Lexis with a language directory and optional locale.
        Args:
            lang_dir: Directory containing .lex files.
            locale: Locale code. Auto-detected if None.
            fallback_locale: Fallback locale code. Default is "en".
        """
        self.lang_dir = lang_dir
        self.fallback_locale = fallback_locale
        self.locale = locale or self._detect_locale()
        self._raw_translations: dict[str, str] = {}
        self._cache_translations: dict[str, str] = {}
        self.filepath = self._resolve_filepath()
        self._load_file()

    def _detect_locale(self) -> str:
        """
        Safely detect system locale from environment.
        Returns:
            locale code (e.g. 'en', 'es').
        """
        lang = os.environ.get("LANG", "")
        # Handle C, POSIX, or missing LANG
        if not lang or lang in ("C", "POSIX"):
            return "en"
        lang = lang.split(".")[0]
        lang = lang.replace('-', "_")
        # Extract language code before underscore
        return lang.split("_")[0].lower()

    def _resolve_filepath(self) -> str:
        """
        Resolve the .lex file path with fallback to en.lex.
        If fallback is used, updates locale state to match fallback.
        Returns:
            Absolute path to the .lex file.
        Raises:
            LexFileNotFoundError:
                If no file found.
        """
        filepath = os.path.join(self.lang_dir, f"{self.locale}.lex")
        if os.path.isfile(filepath):
            return filepath
        # Fallback to English if locale file missing
        fallback = os.path.join(
            self.lang_dir,
            f"{self.fallback_locale}.lex"
        )
        if os.path.isfile(fallback):
            self.locale = self.fallback_locale
            return fallback
        raise LexFileNotFoundError(
            f"No .lex file found for locale "
            f"'{self.locale}' (fallback '{self.fallback_locale}') "
            f"in '{self.lang_dir}'"
        )

    def _unescape(self, value: str) -> str:
        """
        Process escape sequences in values.
        Args:
            value: Raw value string from .lex file.
        Returns:
            Value with escape sequences converted.
        """
        result = []
        i = 0
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
        line = raw_line.rstrip("\r\n")
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
        """
        self._raw_translations = {}
        self._cache_translations = {}
        try:
            with open(self.filepath, encoding="utf-8") as file:
                for line_num, line in enumerate(file, start=1):
                    result = self._parse_line(line, line_num)
                    if result:
                        key, value = result
                        self._raw_translations[key] = value
        except FileNotFoundError:
            # Race condition: file deleted after resolve but before open
            raise LexFileNotFoundError(
                f"File not found: {self.filepath}"
            )

    def _cache_fetch(self, key: str) -> str:
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

    def load(
            self,
            lang_dir: str,
            locale: str = None,
            fallback_locale: str = "en"
    ) -> None:
        """
        Load .lex file from given directory.
        Alias for re-initializing a new lang_dir and locale.
        Args:
            lang_dir: Directory containing .lex files.
            locale: Locale code. Auto-detected if None.
            fallback_locale: Fallback locale code. Default is "en".
        """
        self.lang_dir = lang_dir
        self.fallback_locale = fallback_locale
        self.locale = locale or self._detect_locale()
        self.filepath = self._resolve_filepath()
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
        """
        value = self._cache_fetch(key)
        # Apply printf-style formatting if arguments provided
        if not args:
            return value.replace("%%", "%")
        try:
            return value % args
        except TypeError as error:
            raise LexKeyNotFoundError(
                f"Format error for key '{key}': {error}"
            ) from error

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
        try:
            return self.get(key, *args)
        except LexKeyNotFoundError:
            # Format default with args if provided
            try:
                return default % args if args else default
            except TypeError:
                return default

    def reload(
            self,
            locale: str = None,
            fallback_locale: str = None
    ) -> None:
        """
        Reload translations with a new or auto-detected locale.
        Args:
            locale: New locale code. Auto-detected if None.
            fallback_locale: New fallback locale code,
                or None to keep previous.
        """
        new_locale = locale or self._detect_locale()
        new_fallback = (
            fallback_locale
            if fallback_locale is not None
            else self.fallback_locale
        )
        # Save current state for rollback on failure
        old_lang_dir = self.lang_dir
        old_locale = self.locale
        old_fallback = self.fallback_locale
        old_filepath = self.filepath
        old_raw_translations = self._raw_translations.copy()
        old_cache_translations = self._cache_translations.copy()
        try:
            self.locale = new_locale
            self.fallback_locale = new_fallback
            self.filepath = self._resolve_filepath()
            self._load_file()
        except (LexFileNotFoundError, LexParseError):
            # Restore previous state if anything fails
            self.lang_dir = old_lang_dir
            self.locale = old_locale
            self.fallback_locale = old_fallback
            self.filepath = old_filepath
            self._raw_translations = old_raw_translations
            self._cache_translations = old_cache_translations
            raise

    def keys(self) -> tuple:
        """
        Return all available translation keys.
        Returns:
            Tuple of keys strings.
        """
        return tuple(self._raw_translations.keys())

    def __repr__(self) -> str:
        # String representation for debugging
        return (
            f"Lexis(locale={self.locale!r}, "
            f"fallback={self.fallback_locale!r}, "
            f"keys={len(self._raw_translations)}, "
            f"cached keys={len(self._cache_translations)}, "
            f"filepath={self.filepath!r})"
        )

    def __len__(self) -> int:
        # Len(lex) to count loaded keys
        return len(self._raw_translations)

    def __contains__(self, key: str) -> bool:
        # "Key in lex" membership testing
        return key in self._raw_translations


if __name__ == "__main__":
    # Demo: Load translations and run basic operations
    try:
        base_dir = os.path.dirname(os.path.abspath(__file__))
        lang_dir = os.path.join(base_dir, "..", "lang")
        lex = LEX(lang_dir)
        print(lex.get("welcome", "LEX"))
        print(lex.get("modules_available"))
        print(lex.get("error_file", "foo.txt"))
        print(repr(lex))

        lex.reload("en")
        print(lex.get("welcome", "Lexis"))

    except LexFileNotFoundError as error:
        print(f"[ERROR] {error}")
    except LexKeyNotFoundError as error:
        print(f"[ERROR] {error}")
