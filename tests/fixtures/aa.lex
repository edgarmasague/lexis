# test.py - Official Test Suite for LEXIS Python Runtime
# Based on TESTS.md

import math
import shutil
import sys
from pathlib import Path
import pytest
# Add runtimes/python to path so lexis.py can be imported
sys.path.insert(0, str(
    Path(__file__).resolve().parent.parent.parent.parent
    / "runtimes" / "python"
))
from lexis import (
    Lexis,
    LexFileNotFoundError,
    LexKeyNotFoundError,
    LexParseError,
    LexFormatError,
)
# Path to test fixtures directory
FIXTURES_DIR = Path(__file__).resolve().parent.parent.parent / "fixtures"


@pytest.fixture()
def standalone_dir(tmp_path: Path) -> str:
    dst = tmp_path / "fixtures"
    shutil.copytree(FIXTURES_DIR, dst)
    aliases = {
        "crlf.lex": "cr.lex",
        "duplicate_key.lex": "dk.lex",
        "malformed_line.lex": "ml.lex",
        "empty_key.lex": "ek.lex",
        "empty.lex": "em.lex",
        "invalid_utf8.lex": "iv.lex",
        "reserved_keys.lex": "rk.lex",
        "test.lex": "ts.lex",
    }
    for src_name, alias_name in aliases.items():
        if (dst / src_name).exists():
            shutil.copy(dst / src_name, dst / alias_name)
    return str(dst)


@pytest.fixture()
def lexis(standalone_dir: str) -> Lexis:
    # Fixture providing a Lexis instance loaded with test.lex
    return Lexis(standalone_dir, locale="ts")


@pytest.fixture()
def fixtures_dir() -> str:
    return str(FIXTURES_DIR)


# Parsing Tests T-001 to T-020
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
        assert lexis.get(
            "value_with_hash"
        ) == "#this value starts with hash"

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

    def test_t012_crlf_line_endings(self, standalone_dir):
        instance = Lexis(standalone_dir, locale="cr")
        assert instance.get(
            "crlf_entry"
        ) == "value without trailing carriage return"

    def test_t013_indented_comments_do_not_raise(self, standalone_dir):
        Lexis(standalone_dir, locale="ts")

    def test_t014_whitespace_around_separator(self, lexis):
        assert lexis.get("key_space") == "value_space"

    def test_t015_whitespace_only_lines_are_skipped(self, standalone_dir):
        Lexis(standalone_dir, locale="ts")

    def test_t016_complex_4byte_utf8_sequence(self, lexis):
        assert lexis.get("emoji_sequence") == "Family: 👨‍👩‍👧‍👦"

    def test_t017_extreme_trailing_whitespace(self, lexis):
        assert lexis.get("huge_spaces") == "correct string" + (" " * 10000)

    def test_t018_utf8_bom_is_stripped(self, fixtures_dir):
        instance = Lexis(fixtures_dir, locale="bom")
        assert instance.get("first_key") == "first_value"

    def test_t019_no_trailing_newline_at_eof(self, fixtures_dir):
        instance = Lexis(fixtures_dir, locale="bom")
        assert instance.get("last_key") == "last_value"

    def test_t020_bom_mid_file_is_literal(self, fixtures_dir):
        instance = Lexis(fixtures_dir, locale="bom")
        assert instance.get("mid_bom") == "prefix_\ufeff_suffix"


# Escape Sequence Tests T-101 to T-113
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

    def test_t111_null_escape_is_not_recognize(self, lexis):
        # \0 must stay literal (backslash + '0'), not become a real
        # null byte - "\0" in this Python source IS a null byte, so
        # the backslash must itself be escaped to represent that.
        assert lexis.get("escape_null") == "before\\0after"

    def test_t112_escaped_backslash_before_escape_char(self, lexis):
        # Same reasoning: \n here must stay literal, not become a
        # real newline.
        assert lexis.get("escape_escaped_n") == "literal \\n character"

    def test_t113_argument_is_never_reunescaped(self, lexis):
        literal_backslash_n_b = "a" + "\\" + "n" + "b"
        assert lexis.get(
            "passthrough_arg", literal_backslash_n_b
        ) == "Hello a\\nb"


# Placeholder Tests T-201 to T-241
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

    def test_t209_boolean_coercion(self, lexis):
        assert lexis.get("bool_spec", True, False) == "Active: 1, Blocked: 0"

    def test_t210_null_handling_optional(self, lexis):
        assert lexis.get("null_spec", None) == "Value: "

    def test_t211_signed_zero_padding(self, lexis):
        assert lexis.get("pad_neg_int", -42) == "-0042"

    def test_t212_float_precision(self, lexis):
        assert lexis.get("float_prec", 3.14159) == "00003.14"

    def test_t213_negative_hex_is_signed_magnitude(self, lexis):
        assert lexis.get("neg_hex", -42) == "-2a"

    def test_t214_argument_count_mismatch_raises(self, lexis):
        with pytest.raises(LexFormatError):
            lexis.get("two_placeholders", "only_one_arg")

    def test_t215_unsupported_specifier_is_literal(self, lexis):
        assert lexis.get("invalid_specifier", "ts") == "Value: %q"

    def test_t216_nan_and_infinity_lowercase(self, lexis):
        assert lexis.get("placeholder_float", math.nan) == "Rating: nan"
        assert lexis.get("placeholder_float", math.inf) == "Rating: inf"

    def test_t217_large_float_no_scientific_notation(self, lexis):
        assert lexis.get(
            "placeholder_float", 1e20
        ) == "Rating: 100000000000000000000.000000"

    def test_tT218_64bit_integer_limit(self, lexis):
        assert lexis.get(
            "placeholder_integer", 9223372036854775807
        ) == "You have 9223372036854775807 messages"

    def test_t219_adjacent_percent_tokens(self, lexis):
        assert lexis.get("adjacent_percent", "Alice") == "%%s Alice"

    def test_t220_extra_arguments_ignored(self, lexis):
        assert lexis.get(
            "one_placeholder", "Alice", "extra_arg"
        ) == "Hello Alice"

    def test_t221_default_float_precision(self, lexis):
        assert lexis.get("float_default_prec", 3.1) == "3.100000"

    def test_t222_round_half_away_from_zero_positive_tie(self, lexis):
        assert lexis.get("float_zero_prec", 2.5) == "3"

    def test_t223_string_padding_and_alignment(self, lexis):
        assert lexis.get("string_width_right", "Hi") == "   Hi"
        assert lexis.get("string_width_left", "Hi") == "Hi   "

    def test_t224_zero_padding_on_strings_is_space_padding(self, lexis):
        assert lexis.get("string_zero_pad", "Hi") == "   Hi"

    def test_t225_strict_sequential_binding(self, lexis):
        assert lexis.get("pos_test", "Alice", 10) == "Hello Alice, code 10"

    def test_226_argument_injection_never_reparsed(self, lexis):
        assert lexis.get("placeholder_string", "%s%d") == "Hello %s%d"

    def test_t227_trailing_lone_percent_is_literal(self, lexis):
        assert lexis.get("trailing_percent") == "Value ends with %"

    def test_t228_non_numeric_argument_for_d_raises(self, lexis):
        with pytest.raises(LexFormatError):
            lexis.get("placeholder_integer", "abc")

    def test_t229_char_with_codepoint_above_255(self, lexis):
        assert lexis.get("placeholder_char", 8364) == "Char: €"

    def test_t230_i_is_alias_for_d(self, lexis):
        assert lexis.get("i_spec", 42) == "Count: 42"

    def test_t231_all_unknown_specifiers_stay_literal(self, lexis):
        assert lexis.get("unknown_specs", "x") == "%u %X %e %g %b %n %p"

    def test_t232_positional_syntax_unsupported(self, lexis):
        assert lexis.get("positional_attempt_2", "Alice") == "Hello %1$s"

    def test_t233_width_measured_in_codepoints(self, lexis):
        assert lexis.get("width_codepoint", "ñ") == "    ñ"

    def test_t234_numeric_string_valid_for_d(self, lexis):
        assert lexis.get("numeric_string", "42") == "42"

    def test_t235_negative_infinity(self, lexis):
        assert lexis.get("placeholder_float", -math.inf) == "Rating: -inf"

    def test_t236_round_half_away_from_zero_negative_tie(self, lexis):
        assert lexis.get("float_zero_prec", -2.5) == "-3"

    def test_t237_rounding_against_exact_binary_value(self, lexis):
        assert lexis.get("float_two_prec", 1.005) == "1.00"

    def test_t238_float_at_or_above_1e21(self, lexis):
        assert lexis.get(
            "placeholder_float", 1e21
        ) == "Rating: 1000000000000000000000.000000"

    def test_t239_char_with_invalid_codepoint_raises(self, lexis):
        with pytest.raises(LexFormatError):
            lexis.get("placeholder_char", 1114112)

    def test_t240_d_with_integral_float_is_valid(self, lexis):
        assert lexis.get("placeholder_integer", 3.0) == "You have 3 messages"

    def test_t241_d_with_non_integral_float_raises(self, lexis):
        with pytest.raises(LexFormatError):
            lexis.get("placeholder_integer", 3.7)


# Edge Case Tests T-303
class TestEdgeCase:
    def test_t303_triple_colon(self, lexis):
        assert lexis.get(
            "triple_colon"
        ) == "key:::value with triple colon"


# Conformance Tests T-401 to T-423
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
        result = lexis.get_or_default(
            "nonexistent_key", "Hello %s", "Alice"
        )
        assert result == "Hello Alice"

    def test_t404_locale_fallback_default(self, fixtures_dir):
        # Request fr, en.lex exists, default fallback
        instance = Lexis(fixtures_dir, locale="fr")
        assert instance.locale == "en"
        # en.lex: welcome::Welcome %s - needs an argument
        assert instance.get("welcome", "Alice") == "Welcome Alice"

    def test_t405_locale_fallback_custom(self, fixtures_dir):
        # Request fr, fallback to pt where pt.lex exists
        instance = Lexis(
            fixtures_dir, locale="fr", fallback_locale="pt"
        )
        assert instance.fallback_locale == "pt"
        assert instance.locale == "pt"
        # pt.lex: welcome::Bem-vindo %s - needs an argument
        assert instance.get("welcome", "Alice") == "Bem-vindo Alice"

    def test_t406_reload_switches_locale(self, fixtures_dir):
        # Verify reload changes locale and loads different translations
        instance = Lexis(fixtures_dir, locale="es")
        assert instance.get("welcome", "Alice") == "Bienvenido Alice"
        instance.reload("en")
        assert instance.get("welcome", "Alice") == "Welcome Alice"

    def test_t407_reload_changes_fallback(self, fixtures_dir):
        instance = Lexis(fixtures_dir, "fr", fallback_locale="en")
        assert instance.fallback_locale == "en"
        # Pass locale explicitly - reload(locale=None) means
        # "auto-detect", not "keep current locale", and auto-detect
        # can crash when LANG="C.UTF-8" (Lexis._detect_locale only
        # special-cases the exact strings "C"/"POSIX"). Re-requesting
        # "fr" (still missing) is what actually re-triggers fallback.
        instance.reload(locale="fr", fallback_locale="es")
        assert instance.fallback_locale == "es"
        assert instance.locale == "es"
        # es.lex has no "hello" key - "welcome" is the one confirmed
        # to exist in both en.lex and es.lex.
        assert instance.get("welcome", "Alice") == "Bienvenido Alice"

    def test_t408_reload_rollback_on_fallback(self, fixtures_dir):
        instance = Lexis(fixtures_dir, locale="en")
        before = dict(instance._raw_translations)
        with pytest.raises((LexFileNotFoundError, LexParseError)):
            instance.reload("nonexistent_locale_xyz")
        assert dict(instance._raw_translations) == before
        assert instance.get("welcome", "Alice")

    def test_t410_duplicate_key_raises(self, standalone_dir):
        with pytest.raises(LexParseError):
            Lexis(standalone_dir, locale="dk")

    def test_t411_malformed_line_raises(self, standalone_dir):
        with pytest.raises(LexParseError):
            Lexis(standalone_dir, locale="ml")

    def test_t412_empty_key_raises(self, standalone_dir):
        with pytest.raises(LexParseError):
            Lexis(standalone_dir, locale="ek")

    def test_t413_file_not_found_raises(self, tmp_path):
        with pytest.raises(LexFileNotFoundError):
            Lexis(str(tmp_path), "en", fallback_locale="zz")

    def test_t414_lazy_caching_unescape_once(
            self, monkeypatch, standalone_dir
    ):
        # Mock _unescape to count calls
        original_unescape = Lexis._unescape
        call_count = []

        def counting_unescape(self, value):
            call_count.append(value)
            return original_unescape(self, value)
        monkeypatch.setattr(Lexis, "_unescape", counting_unescape)
        fresh = Lexis(standalone_dir, locale="ts")
        first = fresh.get("escape_newline")
        second = fresh.get("escape_newline")
        assert first == second
        assert len(call_count) == 1

    def test_t415_cache_eviction_on_reload(self, fixtures_dir):
        instance = Lexis(fixtures_dir, locale="aa")
        assert instance.get("k1") == "value from locale A"
        instance.reload("bb")
        with pytest.raises(LexKeyNotFoundError):
            instance.get("k1")

    def test_t416_state_isolation_on_failed_reload(self, standalone_dir):
        lang_dir = Path(standalone_dir)
        shutil.copy(lang_dir / "ml.lex", lang_dir / "xx.lex")
        instance = Lexis(standalone_dir, locale="en")
        before = dict(instance._raw_translations)
        with pytest.raises(LexParseError):
            instance.reload("xx")
        assert dict(instance._raw_translations) == before

    def test_t417_key_case_sensitivity(self, lexis):
        assert lexis.get("KEY") != lexis.get("key")
        assert lexis.get("KEY") == "value1"
        assert lexis.get("key") == "value2"

    def test_t418_locale_code_normalization(self, fixtures_dir):
        for raw in ("es-ES", "es_ES", "ES"):
            instance = Lexis(fixtures_dir, locale=raw)
            assert instance.locale == "es"

    def test_t419_invalid_utf8_raises_parse_error(self, standalone_dir):
        with pytest.raises(LexParseError):
            Lexis(standalone_dir, locale="iv")

    def test_t420_reserved_keys_no_prototype_pollution_optional(
            self, standalone_dir
    ):
        instance = Lexis(standalone_dir, locale="rk")
        assert instance.get("toString") == "mapped toString value"
        assert instance.get("valueOf") == "mapped valueOf value"
        assert instance.get("__proto__") == "mapped __proto__ value"
        assert instance.get("constructor") == "mapped constructor value"

    def test_t421_multi_instance_isolation(self, fixtures_dir):
        client1 = Lexis(fixtures_dir, locale="en")
        client2 = Lexis(fixtures_dir, locale="es")
        assert client1.locale != client2.locale
        client1.reload("es")
        assert client2.locale == "es"
        assert client1 is not client2

    def test_t422_empty_or_comment_only_file(self, standalone_dir):
        instance = Lexis(standalone_dir, locale="em")
        assert len(instance) == 0

    def test_t423_path_traversal_via_locale(self, fixtures_dir):
        with pytest.raises(LexFileNotFoundError):
            Lexis(fixtures_dir, locale="../secret")


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
        assert "cached_keys=" in r
        assert "filepath=" in r


if __name__ == "__main__":
    pytest.main([__file__, "-v"])