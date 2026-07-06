# test.py - Official Test Suite for LEXIS Python Runtime
# Based on TESTS.md

import os
import sys
import pytest
# Add runtimes/python to path so lexis.py can be imported
sys.path.insert(0, os.path.join(
    os.path.dirname(__file__), "..", "..", "..", "runtimes", "python"
))
from lexis import Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError

# Path to test fixtures directory
FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "fixtures")


@pytest.fixture
def lexis():
    # Fixture providing a Lexis instance loaded with test.lex
    return Lexis(FIXTURES_DIR, "test")


@pytest.fixture
def lexis_en():
    # Fixture providing a Lexis instance loaded with en.lex
    return Lexis(FIXTURES_DIR, "en")


@pytest.fixture
def lexis_es():
    # Fixture providing a Lexis instance loaded with es.lex
    return Lexis(FIXTURES_DIR, "es")


# Parsing Tests T-001 to T-011
class TestParsing:
    def test_t001_simple_entry(self, lexis):
        assert lexis.get("simple") == "Hello World"

    def test_t002_empty_value(self, lexis):
        assert lexis.get("empty_value") == ""

    def test_t003_key_trimmed(self, lexis):
        assert lexis.get("key_trimmed") == "Value with spaces around key"

    def test_t004_uppercase_key(self, lexis):
        assert lexis.get("UPPERCASE_KEY") == "uppercase key test"

    def test_t005_mixed_case_key(self, lexis):
        assert lexis.get("mixed_Case_Key") == "mixed case key test"

    def test_t006_value_with_hash(self, lexis):
        assert lexis.get("value_with_hash") == "#this value starts with hash"

    def test_t007_value_with_separator(self, lexis):
        assert lexis.get(
            "value_with_separator"
        ) == "value :: contains :: separators"

    def test_t008_leading_spaces_trimmed(self, lexis):
        assert lexis.get(
            "value_leading_spaces"
        ) == "leading spaces are trimmed"

    def test_t009_trailing_spaces_preserved(self, lexis):
        assert lexis.get(
            "value_trailing_spaces"
        ) == "trailing spaces are preserved   "

    def test_t010_unicode(self, lexis):
        assert lexis.get("value_unicode") == "Hello 👋 World"

    def test_t011_utf8_extended(self, lexis):
        assert lexis.get("value_utf8") == "Héllo Wörld — ñoño"


# Escape Sequence Tests T-101 to T-110
class TestEscapes:
    def test_t101_newline(self, lexis):
        assert lexis.get("escape_newline") == "Line 1\nLine 2"

    def test_t102_tab(self, lexis):
        assert lexis.get("escape_tab") == "Col1\tCol2"

    def test_t103_backslash(self, lexis):
        assert lexis.get("escape_backslash") == "C:\\Program Files\\Lexis"

    def test_t104_quote(self, lexis):
        assert lexis.get("escape_quote") == 'She said "hello"'

    def test_t105_carriage_return(self, lexis):
        assert lexis.get("escape_carriage_return") == "before\rafter"

    def test_t106_backspace(self, lexis):
        assert lexis.get("escape_backspace") == "before\bafter"

    def test_t107_vertical_tab(self, lexis):
        assert lexis.get("escape_vertical_tab") == "before\vafter"

    def test_t108_unknown_escape(self, lexis):
        assert lexis.get(
            "escape_unknown"
        ) == "unknown \\q escape passes through"

    def test_t109_trailing_backslash(self, lexis):
        assert lexis.get(
            "escape_trailing_backslash"
        ) == "trailing backslash is literal\\"

    def test_t110_combined_escapes_with_placeholders(self, lexis):
        result = lexis.get("escape_combined", "Alice", 99)
        assert result == "Name:\tAlice\nScore:\t99"


# Placeholder Tests T-201 to T-208
class TestPlaceholders:
    def test_t201_string(self, lexis):
        assert lexis.get("placeholder_string", "Alice") == "Hello Alice"

    def test_t202_integer(self, lexis):
        assert lexis.get("placeholder_integer", 3) == "You have 3 messages"

    def test_t203_float(self, lexis):
        result = lexis.get("placeholder_float", 3.75)
        assert result == "Rating: 3.750000"

    def test_t204_hex(self, lexis):
        assert lexis.get("placeholder_hex", 255) == "Hex value: ff"

    def test_t205_octal(self, lexis):
        assert lexis.get("placeholder_octal", 8) == "Octal value: 10"

    def test_t206_char(self, lexis):
        assert lexis.get("placeholder_char", 65) == "Char: A"

    def test_t207_literal_percent(self, lexis):
        assert lexis.get("placeholder_percent") == "100% completed"

    def test_t208_multiple_placeholders(self, lexis):
        result = lexis.get("placeholder_multiple", "Alice", 10, 4.5)
        assert result == "User Alice has 10 points and rating 4.50"


# Edge Case Tests T-301 to T-303
class TestEdgeCase:
    def test_t301_not_a_comment(self, lexis):
        assert lexis.get("not_a_comment") == "#not a comment"

    def test_t302_double_colon(self, lexis):
        assert lexis.get(
            "double_colon"
        ) == "key::value with double colon in value"

    def test_t303_triple_colon(self, lexis):
        assert lexis.get(
            "triple_colon"
        ) == "key:::value with triple colon"


# Conformance Tests T-401 to T-414
class TestConformance:
    def test_t401_missing_key_raises(self, lexis):
        with pytest.raises(LexKeyNotFoundError):
            lexis.get("nonexistent_key")

    def test_t402_missing_key_with_default(self, lexis):
        assert lexis.get_or_default(
            "nonexistent_key",
            "fallback"
        ) == "fallback"

    def test_t403_missing_key_with_default_and_args(self, lexis):
        result = lexis.get_or_default("nonexistent_key", "Hello %s", "Alice")
        assert result == "Hello Alice"

    def test_t404_locale_fallback_default(self, tmp_path):
        # Request fr, only en.lex exists, default fallback
        en_lexis = tmp_path / "en.lex"
        en_lexis.write_text("welcome::Welcome", encoding="utf-8")
        lexis = Lexis(str(tmp_path), "fr")
        assert lexis.locale == "en"
        assert lexis.get("welcome") == "Welcome"

    def test_t405_locale_fallback_custom(self, tmp_path):
        # Request fr, fallback to pt where only pt.lex exists
        pt_lexis = tmp_path / "pt.lex"
        pt_lexis.write_text("welcome::Bem-vindo\n", encoding="utf-8")
        lexis = Lexis(str(tmp_path), "fr", fallback_locale="pt")
        assert lexis.locale == "pt"
        assert lexis.get("welcome") == "Bem-vindo"

    def test_t406_reload_switches_locale(self, lexis_es):
        # Verify reload changes locale and loads different translations
        assert lexis_es.get("welcome", "Alice") == "Bienvenido Alice"
        lexis_es.reload("en")
        assert lexis_es.get("welcome", "Alice") == "Welcome Alice"

    def test_t407_reload_changes_fallback(self, tmp_path):
        es_lexis = tmp_path / "es.lex"
        es_lexis.write_text("hello::Hola", encoding="utf-8")
        en_lexis = tmp_path / "en.lex"          # ← añadir
        en_lexis.write_text("hello::Hello", encoding="utf-8")  # ← añadir
        lexis = Lexis(str(tmp_path), "fr", fallback_locale="en")
        assert lexis.fallback_locale == "en"
        lexis.reload(fallback_locale="es")
        assert lexis.fallback_locale == "es"
        assert lexis.locale == "es"
        assert lexis.get("hello") == "Hola"

    def test_t408_reload_rollback_preserves_fallback(self, lexis_en):
        old_lang_dir = lexis_en.lang_dir
        old_locale = lexis_en.locale
        old_fallback = lexis_en.fallback_locale
        old_filepath = lexis_en.filepath
        old_keys = lexis_en.keys()
        with pytest.raises(LexFileNotFoundError):
            lexis_en.reload(
                "nonexistent_xyz",
                fallback_locale="also_nonexistent"
            )
        assert lexis_en.lang_dir == old_lang_dir
        assert lexis_en.locale == old_locale
        assert lexis_en.fallback_locale == old_fallback
        assert lexis_en.filepath == old_filepath
        assert lexis_en.keys() == old_keys
        assert lexis_en.get("welcome", "Alice") == "Welcome Alice"

    def test_t409_load_with_custom_fallback(self, tmp_path):
        pt_lexis = tmp_path / "pt.lex"
        pt_lexis.write_text("hello::Oi\n", encoding="utf-8")
        en_lexis = tmp_path / "en.lex"
        en_lexis.write_text("hello::Hello", encoding="utf-8")
        lexis = Lexis(str(tmp_path), "fr")
        lexis.load(str(tmp_path), "fr", fallback_locale="pt")
        assert lexis.fallback_locale == "pt"
        assert lexis.get("hello") == "Oi"

    def test_t410_duplicate_key_raises(self, tmp_path):
        dup_lexis = tmp_path / "test.lex"
        dup_lexis.write_text("hello::First\nhello::Second\n", encoding="utf-8")
        with pytest.raises(LexParseError):
            Lexis(str(tmp_path), "test")

    def test_t411_malformed_line_raises(self, tmp_path):
        bad_lexis = tmp_path / "test.lex"
        bad_lexis.write_text(
            "valid::ok\nthis line has no separator\n", encoding="utf-8"
        )
        with pytest.raises(LexParseError):
            Lexis(str(tmp_path), "test")

    def test_t412_empty_key_raises(self, tmp_path):
        bad_lexis = tmp_path / "test.lex"
        bad_lexis.write_text(
            "valid::ok\n::value with no key\n", encoding="utf-8"
        )
        with pytest.raises(LexParseError):
            Lexis(str(tmp_path), "test")

    def test_t413_file_not_found_raises(self, tmp_path):
        with pytest.raises(LexFileNotFoundError):
            Lexis(str(tmp_path), "en")  # No files in directory

    def test_t414_lazy_caching_no_reprocess(self, lexis):
        # Mock _unescape to count calls
        original_unescape = lexis._unescape
        call_count = [0]

        def counting_unescape(value):
            call_count[0] += 1
            return original_unescape(value)
        lexis._unescape = counting_unescape
        lexis.get("escape_newline")
        lexis.get("escape_newline")
        assert call_count[0] == 1  # Only called once


# Additional Tests
class TestAdditional:
    # Extra tests not in tests.md but useful for completeness.
    def test_keys_method(self, lexis):
        # Verify keys() returns all keys.
        keys = lexis.keys()
        assert "simple" in keys
        assert "welcome" in keys
        assert "empty_value" in keys

    def test_len_method(self, lexis):
        # Verify __len__ returns correct count.
        assert len(lexis) > 0

    def test_contains_method(self, lexis):
        # Verify __contains__ works.
        assert "simple" in lexis
        assert "nonexistent" not in lexis

    def test_repr(self, lexis):
        # Verify __repr__ is informative.
        r = repr(lexis)
        assert r.startswith("Lexis(")
        assert "locale=" in r
        assert "keys=" in r
        assert "cached keys=" in r
        assert "filepath=" in r


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
