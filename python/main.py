# lex.py - LEX Independent Translation Engine

import os


class LexFileNotFoundError(Exception):
    pass


class LexKeyNotFoundError(Exception):
    pass


class LEX:

    def __init__(self, lang_dir: str, locale: str = None):
        self.lang_dir = lang_dir
        self.locale = locale or self._detect_locale()
        self.translations = {}
        self.filepath = self._resolve_filepath()

    def _detect_locale(self) -> str:
        return os.environ.get("LANG", "en")[:2]

    def _resolve_filepath(self) -> str:
        filepath = os.path.join(self.lang_dir, f"{self.locale}.lex")
        if os.path.exists(filepath):
            return filepath
        fallback = os.path.join(self.lang_dir, "en.lex")
        if os.path.exists(fallback):
            self.locale = "en"
            return fallback
        raise LexFileNotFoundError(
            f"No .lex file found for locale "
            f"'{self.locale}' in '{self.lang_dir}'"
        )

    def _fetch_from_file(self, key: str) -> str:
        try:
            with open(self.filepath, encoding="utf-8") as file:
                for line in file:
                    if line.startswith(f"{key}::"):
                        _, _, value = line.strip().partition("::")
                        return value
        except FileNotFoundError:
            raise LexFileNotFoundError(
                f"File not found: {self.filepath}"
            )
        raise LexKeyNotFoundError(
            f"Key not found: '{key}'"
        )

    def _cache_fetch(self, key: str) -> str:
        if key not in self.translations:
            self.translations[key] = self._fetch_from_file(key)
        return self.translations[key]

    def get(self, key: str, *args) -> str:
        value = self._cache_fetch(key)
        return value % args if args else value

    def reload(self, locale: str = None) -> None:
        if locale:
            self.locale = locale
        self.translations = {}
        self.filepath = self._resolve_filepath()

    def __repr__(self) -> str:
        return (
            f"LEX(locale={self.locale!r}, "
            f"cached={len(self.translations)})"
        )


if __name__ == "__main__":
    try:
        base_dir = os.path.dirname(os.path.abspath(__file__))
        lang_dir = os.path.join(base_dir, "..", "lang")
        lex = LEX(lang_dir)
        print(lex.get("welcome", "LEX"))
        print(lex.get("modules_available"))
        print(lex.get("error_file", "foo.txt"))

        lex.reload("en")
        print(lex.get("welcome", "LEX"))

    except LexFileNotFoundError as error:
        print(f"[ERROR] {error}")
    except LexKeyNotFoundError as error:
        print(f"[ERROR] {error}")
