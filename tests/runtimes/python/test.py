# test.py - Official Test Suite for LEXIS
# Based on TESTS.md

import os
import sys
import pytest
# Add runtimes/python to path so lexis.py can be imported
sys.path.insert(0, os.path.join(
    os.path.dirname(__file__), "..", "..", "..", "runtimes", "python"
))
from lexis import LEX, LexFileNotFoundError, LexKeyNotFoundError, LexParseError

# Path to test fixtures directory
FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "fixtures")


@pytest.fixture
def lex():
    # Fixture providing a LEX instance loaded with test.lex
    return LEX(FIXTURES_DIR, "test")


@pytest.fixture
def lex_en():
    # Fixture providing a LEX instance loaded with en.lex
    return LEX(FIXTURES_DIR, "en")


@pytest.fixture
def lex_es():
    # Fixture providing a LEX instance loaded with es.lex
    return LEX(FIXTURES_DIR, "es")


# Parsing Tests T-001 to T-011
class TestParsing:
    def test_t001_simple_entry(self, lex):
        assert lex.get("simple") == "Hello World"

    def test_t002_empty_value(self, lex):
        assert lex.get("empty_value") == ""

    def test_t003_key_trimmed(self, lex):
        assert lex.get("key_trimmed") == "Value with spaces around key"

    def test_t004_uppercase_key(self, lex):
        assert lex.get("UPPERCASE_KEY") == "uppercase key test"

    def test_t005_mixed_case_key(self, lex):
        assert lex.get("mixed_Case_Key") == "mixed case key test"

    def test_t006_value_with_hash(self, lex):
        assert lex.get("value_with_hash") == "#this value starts with hash"

    def test_t007_value_with_separator(self, lex):
        assert lex.get(
            "value_with_separator"
        ) == "value :: contains :: separators"

    def test_t008_leading_spaces_trimmed(self, lex):
        assert lex.get("value_leading_spaces") == "leading spaces are trimmed"

    def test_t009_trailing_spaces_preserved(self, lex):
        assert lex.get(
            "value_trailing_spaces"
        ) == "trailing spaces are preserved   "

    def test_t010_unicode(self, lex):
        assert lex.get("value_unicode") == "Hello 👋 World"

    def test_t011_utf8_extended(self, lex):
        assert lex.get("value_utf8") == "Héllo Wörld — ñoño"


# Escape Sequence Tests T-020 to T-029
class TestEscapes:
    def test_t020_newline(self, lex):
        assert lex.get("escape_newline") == "Line 1\nLine 2"

    def test_t021_tab(self, lex):
        assert lex.get("escape_tab") == "Col1\tCol2"

    def test_t022_backslash(self, lex):
        assert lex.get("escape_backslash") == "C:\\Program Files\\Lexis"

    def test_t023_quote(self, lex):
        assert lex.get("escape_quote") == 'She said "hello"'

    def test_t024_carriage_return(self, lex):
        assert lex.get("escape_carriage_return") == "before\rafter"

    def test_t025_backspace(self, lex):
        assert lex.get("escape_backspace") == "before\bafter"

    def test_t026_vertical_tab(self, lex):
        assert lex.get("escape_vertical_tab") == "before\vafter"

    def test_t027_unknown_escape(self, lex):
        assert lex.get("escape_unknown") == "unknown \\q escape passes through"

    def test_t028_trailing_backslash(self, lex):
        assert lex.get(
            "escape_trailing_backslash"
        ) == "trailing backslash is literal\\"

    def test_t029_combined_escapes_with_placeholders(self, lex):
        result = lex.get("escape_combined", "Alice", 99)
        assert result == "Name:\tAlice\nScore:\t99"


# Placeholder Tests T-030 to T-037
class TestPlaceholders:
    def test_t030_string(self, lex):
        assert lex.get("placeholder_string", "Alice") == "Hello Alice"

    def test_t031_integer(self, lex):
        assert lex.get("placeholder_integer", 3) == "You have 3 messages"

    def test_t032_float(self, lex):
        result = lex.get("placeholder_float", 3.75)
        assert result == "Rating: 3.750000"

    def test_t033_hex(self, lex):
        assert lex.get("placeholder_hex", 255) == "Hex value: ff"

    def test_t034_octal(self, lex):
        assert lex.get("placeholder_octal", 8) == "Octal value: 10"

    def test_t035_char(self, lex):
        assert lex.get("placeholder_char", 65) == "Char: A"

    def test_t036_literal_percent(self, lex):
        assert lex.get("placeholder_percent") == "100% completed"

    def test_t037_multiple_placeholders(self, lex):
        result = lex.get("placeholder_multiple", "Alice", 10, 4.5)
        assert result == "User Alice has 10 points and rating 4.50"


# Edge Case Tests T-038 to T-040
class TestEdgeCase:
    def test_t038_not_a_comment(self, lex):
        assert lex.get("not_a_comment") == "#not a comment"

    def test_t039_double_colon(self, lex):
        assert lex.get(
            "double_colon"
        ) == "key::value with double colon in value"

    def test_t040_triple_colon(self, lex):
        assert lex.get(
            "triple_colon"
        ) == "key:::value with triple colon"


# Conformance Tests T-041 to T-052
class TestConformance:
    def test_t041_missing_key_raises(self, lex):
        with pytest.raises(LexKeyNotFoundError):
            lex.get("nonexistent_key")

    def test_t042_missing_key_with_default(self, lex):
        assert lex.get_or_default("nonexistent_key", "fallback") == "fallback"

    def test_t043_missing_key_with_default_and_args(self, lex):
        result = lex.get_or_default("nonexistent_key", "Hello %s", "Alice")
        assert result == "Hello Alice"

    def test_t044a_locale_fallback_default(self, tmp_path):
        # Request fr, only en.lex exists, default fallback
        en_lex = tmp_path / "en.lex"
        en_lex.write_text("welcome::Welcome", encoding="utf-8")
        lex = LEX(str(tmp_path), "fr")
        assert lex.locale == "en"
        assert lex.get("welcome") == "Welcome"

    def test_t044b_locale_fallback_custom(self, tmp_path):
        # Request fr, fallback to pt where only pt.lex exists
        pt_lex = tmp_path / "pt.lex"
        pt_lex.write_text("welcome::Bem-vindo\n", encoding="utf-8")
        lex = LEX(str(tmp_path), "fr", fallback_locale="pt")
        assert lex.locale == "pt"
        assert lex.get("welcome") == "Bem-vindo"

    def test_t045a_reload_switches_locale(self, lex_es):
        # Verify reload changes locale and loads different translations
        assert lex_es.get("welcome", "Alice") == "Bienvenido Alice"
        lex_es.reload("en")
        assert lex_es.get("welcome", "Alice") == "Welcome Alice"

    def test_t045b_reload_changes_fallback(self, tmp_path):
        es_lex = tmp_path / "es.lex"
        es_lex.write_text("hello::Hola", encoding="utf-8")
        en_lex = tmp_path / "en.lex"          # ← añadir
        en_lex.write_text("hello::Hello", encoding="utf-8")  # ← añadir
        lex = LEX(str(tmp_path), "fr", fallback_locale="en")
        assert lex.fallback_locale == "en"
        lex.reload(fallback_locale="es")
        assert lex.fallback_locale == "es"
        assert lex.locale == "es"
        assert lex.get("hello") == "Hola"

    def test_t046_reload_rollback_preserves_fallback(self, lex_en):
        old_lang_dir = lex_en.lang_dir
        old_locale = lex_en.locale
        old_fallback = lex_en.fallback_locale
        old_filepath = lex_en.filepath
        old_keys = lex_en.keys()
        with pytest.raises(LexFileNotFoundError):
            lex_en.reload(
                "nonexistent_xyz",
                fallback_locale="also_nonexistent"
            )
        assert lex_en.lang_dir == old_lang_dir
        assert lex_en.locale == old_locale
        assert lex_en.fallback_locale == old_fallback
        assert lex_en.filepath == old_filepath
        assert lex_en.keys() == old_keys
        assert lex_en.get("welcome", "Alice") == "Welcome Alice"

    def test_t047_load_with_custom_fallback(self, tmp_path):
        pt_lex = tmp_path / "pt.lex"
        pt_lex.write_text("hello::Oi\n", encoding="utf-8")
        en_lex = tmp_path / "en.lex"          # ← añadir para el __init__
        en_lex.write_text("hello::Hello", encoding="utf-8")
        lex = LEX(str(tmp_path), "fr")        # carga en.lex como fallback
        lex.load(str(tmp_path), "fr", fallback_locale="pt")
        assert lex.fallback_locale == "pt"
        assert lex.get("hello") == "Oi"

    def test_t048_duplicate_key_raises(self, tmp_path):
        dup_lex = tmp_path / "test.lex"
        dup_lex.write_text("hello::First\nhello::Second\n", encoding="utf-8")
        with pytest.raises(LexParseError):
            LEX(str(tmp_path), "test")

    def test_t049_malformed_line_raises(self, tmp_path):
        bad_lex = tmp_path / "test.lex"
        bad_lex.write_text(
            "valid::ok\nthis line has no separator\n", encoding="utf-8"
        )
        with pytest.raises(LexParseError):
            LEX(str(tmp_path), "test")

    def test_t050_empty_key_raises(self, tmp_path):
        bad_lex = tmp_path / "test.lex"
        bad_lex.write_text(
            "valid::ok\n::value with no key\n", encoding="utf-8"
        )
        with pytest.raises(LexParseError):
            LEX(str(tmp_path), "test")

    def test_t051_file_not_found_raises(self, tmp_path):
        with pytest.raises(LexFileNotFoundError):
            LEX(str(tmp_path), "en")  # No files in directory

    def test_t052_lazy_caching_no_reprocess(self, lex):
        # Mock _unescape to count calls
        original_unescape = lex._unescape
        call_count = [0]

        def counting_unescape(value):
            call_count[0] += 1
            return original_unescape(value)
        lex._unescape = counting_unescape
        lex.get("escape_newline")
        lex.get("escape_newline")
        assert call_count[0] == 1  # Only called once


# Additional Tests
class TestAdditional:
    # Extra tests not in tests.md but useful for completeness.
    def test_keys_method(self, lex):
        # Verify keys() returns all keys.
        keys = lex.keys()
        assert "simple" in keys
        assert "welcome" in keys
        assert "empty_value" in keys

    def test_len_method(self, lex):
        # Verify __len__ returns correct count.
        assert len(lex) > 0

    def test_contains_method(self, lex):
        # Verify __contains__ works.
        assert "simple" in lex
        assert "nonexistent" not in lex

    def test_repr(self, lex):
        # Verify __repr__ is informative.
        r = repr(lex)
        assert r.startswith("Lexis(")
        assert "locale=" in r
        assert "keys=" in r
        assert "cached keys=" in r
        assert "filepath=" in r


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
