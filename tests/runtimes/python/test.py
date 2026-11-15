# test.py - Official Test Suite for LEXIS Python Runtime
# Based on TESTS.md (T-001 to T-437). Retired IDs are not tested.

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
LOCALES_DIR = FIXTURES_DIR / "locales"
# Fixture names with "_" are not plain locale codes (cr_inside would be
# normalized to cr_INSIDE), so they are copied under a short alias.
FILE_ALIASES = [
    ("crlf", "cr"),
    ("crlf_trailing", "ct"),
    ("cr_inside", "ci"),
    ("duplicate_key", "dk"),
    ("malformed_line", "ml"),
    ("empty_key", "ek"),
    ("empty", "em"),
    ("invalid_utf8", "iv"),
    ("reserved_keys", "rk"),
    ("test", "ts"),
]
NAN = math.nan
INF = math.inf


def write_lex(directory: Path, name: str, content: str) -> None:
    # newline="" keeps CR / CRLF exactly as written
    (directory / f"{name}.lex").write_text(
        content, encoding="utf-8", newline=""
    )


def cases(rows: list[tuple]) -> list:
    # rows: (test id, key, args, expected) -> pytest params named by id
    return [pytest.param(*row[1:], id=row[0]) for row in rows]


@pytest.fixture()
def standalone_dir(tmp_path: Path) -> str:
    dst = tmp_path / "fixtures"
    shutil.copytree(FIXTURES_DIR, dst)
    for src, alias in FILE_ALIASES:
        src_file = dst / f"{src}.lex"
        if src_file.exists():
            shutil.copy(src_file, dst / f"{alias}.lex")
    return str(dst)


@pytest.fixture()
def lexis(standalone_dir: str) -> Lexis:
    # Fixture providing a Lexis instance loaded with test.lex
    return Lexis(standalone_dir, locale="ts")


@pytest.fixture()
def fixtures_dir() -> str:
    return str(FIXTURES_DIR)


@pytest.fixture()
def locales_dir() -> str:
    return str(LOCALES_DIR)


PLACEHOLDERS = [
    ("T-201", "placeholder_string", ("Alice",), "Hello Alice"),
    ("T-202", "placeholder_integer", (3,), "You have 3 messages"),
    ("T-203", "placeholder_float", (3.75,), "Rating: 3.75"),
    ("T-204", "placeholder_hex", (255,), "Hex value: ff"),
    ("T-205", "placeholder_octal", (8,), "Octal value: 10"),
    ("T-206", "placeholder_char", (65,), "Char: A"),
    ("T-207", "placeholder_percent", (), "100% completed"),
    ("T-208", "placeholder_multiple", ("Alice", 10, 4.5),
     "User Alice has 10 points and rating 4.50"),
    ("T-211", "pad_neg_int", (-42,), "-0042"),
    ("T-212", "float_prec", (3.14159,), "00003.14"),
    ("T-213", "neg_hex", (-42,), "-2a"),
    ("T-215", "invalid_specifier", ("test",), "Value: %q"),
    ("T-217", "placeholder_float", (1e18,), "Rating: 1000000000000000000"),
    ("T-218", "placeholder_integer", (9223372036854775807,),
     "You have 9223372036854775807 messages"),
    ("T-219", "adjacent_percent", ("Alice",), "%%s Alice"),
    ("T-220", "one_placeholder", ("Alice", "extra_arg"), "Hello Alice"),
    ("T-221", "float_default_prec", (3.1,), "3.1"),
    ("T-222", "float_zero_prec", (2.5,), "3"),
    ("T-223a", "string_width_right", ("Hi",), "   Hi"),
    ("T-223b", "string_width_left", ("Hi",), "Hi   "),
    ("T-224", "string_zero_pad", ("Hi",), "   Hi"),
    ("T-225", "pos_test", ("Alice", 10), "Hello Alice, code 10"),
    ("T-226", "placeholder_string", ("%s%d",), "Hello %s%d"),
    ("T-227", "trailing_percent", (), "Value ends with %"),
    ("T-229", "placeholder_char", (8364,), "Char: \u20ac"),
    ("T-230", "i_spec", (42,), "Count: 42"),
    ("T-231", "unknown_specs", ("x",), "%u %X %e %g %b %n %p"),
    ("T-232", "positional_attempt_2", ("Alice",), "Hello %1$s"),
    ("T-233", "width_codepoint", ("ñ",), "    ñ"),
    ("T-234", "numeric_string", ("42",), "42"),
    ("T-236", "float_zero_prec", (-2.5,), "-3"),
    ("T-237", "float_two_prec", (1.005,), "1.00"),
    ("T-240", "placeholder_integer", (3.0,), "You have 3 messages"),
    ("T-242", "lit_flags", (5, 5, 255), "%+d|% d|%#x"),
    ("T-243", "lit_length", (5,), "%ld|%lld|%hd|%zu"),
    ("T-244", "lit_star", (5, 2, 3.14), "%*d|%.*f"),
    ("T-245", "lit_prec_s", ("abcdef", 5), "%.3s|%.2d"),
    ("T-246", "lit_prec_empty", (3.5,), "%.f"),
    ("T-247", "lit_flag_order", (5,), "%0-5d"),
    ("T-248", "lit_percent_space", (), "50% discount"),
    ("T-249a", "lit_cut_off_width", (), "Width cut off %5"),
    ("T-249b", "lit_cut_off_flags", (), "Flags cut off %-0"),
    ("T-250", "lit_then_real", ("x",), "%qx"),
    ("T-251", "width_max", (1,), " " * 1023 + "1"),
    ("T-252", "width_over", (1,), "%1025d"),
    ("T-253", "width_overflow", (1,), "%99999999999999999999d"),
    ("T-254", "prec_max", (0.1,), "0.100000000000000"),
    ("T-255a", "prec_over", (0.1,), "%.16f"),
    ("T-255b", "prec_overflow", (1,), "%.99999999999999999999f"),
    ("T-256", "pad_left_zero", (42,), "42   |"),
    ("T-257", "pad_char_zero", (65,), "  A|"),
    ("T-258", "pad_neg_float", (-3.14159,), "-0003.14"),
    ("T-259", "pad_neg_hex", (-42,), "-002a"),
    ("T-260", "pad_left_float", (3.14159,), "3.14    |"),
    ("T-261", "pad_no_truncate", (12345,), "12345"),
    ("T-262", "width_emoji", ("\U0001F44B",), "    \U0001F44B|"),
    ("T-263", "width_combining", ("e\u0301",), "   e\u0301|"),
    ("T-264a", "s_int", (-42,), "-42"),
    ("T-264b", "s_int_min", (-9223372036854775808,),
     "-9223372036854775808"),
    ("T-265a", "s_float", (3.14,), "3.14"),
    ("T-265b", "s_float_int", (3.0,), "3"),
    ("T-265c", "s_float_tiny", (0.0000004,), "0"),
    ("T-270", "d_int_min", (-9223372036854775808,),
     "-9223372036854775808"),
    ("T-273a", "hex_zero", (0,), "0"),
    ("T-273b", "hex_int_min", (-9223372036854775808,),
     "-8000000000000000"),
    ("T-273c", "oct_neg", (-8,), "-10"),
    ("T-276a", "char_astral", (128075,), "\U0001F44B"),
    ("T-276b", "char_max", (1114111,), "\U0010FFFF"),
    ("T-276c", "char_numstr", ("65",), "A"),
    ("T-278a", "f_def_int_valued", (3.0,), "3"),
    ("T-278b", "f_def_hundred", (100.0,), "100"),
    ("T-278c", "f_def_sum", (0.30000000000000004,), "0.3"),
    ("T-278d", "f_def_third", (0.3333333333333333,), "0.333333"),
    ("T-278e", "f_def_round", (1.23456789,), "1.234568"),
    ("T-278f", "f_def_big", (1234567.891,), "1234567.891"),
    ("T-278g", "f_def_intarg", (3,), "3"),
    ("T-279a", "f_def_tiny", (0.0000004,), "0"),
    ("T-279b", "f_def_tiny_neg", (-0.0000004,), "0"),
    ("T-279c", "f_def_negzero", (-0.0,), "0"),
    ("T-279d", "f_def_edge", (0.000001,), "0.000001"),
    ("T-280a", "f_prec_small", (0.0000004,), "0.0000004"),
    ("T-280b", "f_prec_pad", (3.0,), "3.00"),
    ("T-280c", "f_prec_intarg", (1,), "1.00"),
    ("T-280d", "f_prec_one", (3.1,), "3.10"),
    ("T-281a", "f_tie_half", (0.5,), "1"),
    ("T-281b", "f_tie_onehalf", (1.5,), "2"),
    ("T-282", "f_neg_tiny", (-0.001,), "0.00"),
    ("T-283", "f_str", ("3.14",), "3.14"),
    ("T-284", "f_big_prec", (9e18,), "9000000000000000000.00"),
    ("T-286", "pct_pct_s", (), "%s"),
]

FORMAT_ERRORS = [
    ("T-209", "bool_spec", (True, False)),
    ("T-210", "null_spec", (None,)),
    ("T-214", "two_placeholders", ("only_one_arg",)),
    ("T-216a", "placeholder_float", (NAN,)),
    ("T-216b", "placeholder_float", (INF,)),
    ("T-228", "placeholder_integer", ("abc",)),
    ("T-235", "placeholder_float", (-INF,)),
    ("T-238a", "placeholder_float", (9223372036854775808.0,)),
    ("T-238b", "placeholder_float", (1e19,)),
    ("T-238c", "placeholder_float", (1e21,)),
    ("T-239", "placeholder_char", (1114112,)),
    ("T-241", "placeholder_integer", (3.7,)),
    ("T-266", "s_bool", (True,)),
    ("T-267", "s_null", (None,)),
    ("T-268", "s_bad_utf8", ("\udcc3(",)),
    ("T-269a", "d_str_float", ("4.0",)),
    ("T-269b", "d_str_plus", ("+5",)),
    ("T-269c", "d_str_space", (" 5",)),
    ("T-269d", "d_str_empty", ("",)),
    ("T-271a", "d_float_big", (1e19,)),
    ("T-271b", "d_str_big", ("9223372036854775808",)),
    ("T-272a", "d_nan", (NAN,)),
    ("T-272b", "d_inf", (INF,)),
    ("T-274a", "hex_frac", (3.5,)),
    ("T-274b", "hex_bad_str", ("zz",)),
    ("T-275a", "char_zero", (0,)),
    ("T-275b", "char_neg", (-1,)),
    ("T-275c", "char_surr_lo", (55296,)),
    ("T-275d", "char_surr_hi", (57343,)),
    ("T-277", "char_str", ("A",)),
    ("T-283a", "f_str_exp", ("1e5",)),
    ("T-283b", "f_str_bad", ("abc",)),
    ("T-285", "f_bool", (True,)),
]

BAD_LOCALES = [
    "../secret", "es/..", "es\\x", "es.x", "", "es_VE_X", "es VE",
]


# Parsing Tests T-001 to T-026
class TestParsing:
    def test_t001_simple_entry(self, lexis: Lexis) -> None:
        assert lexis.get("simple") == "Hello World"

    def test_t002_empty_value(self, lexis: Lexis) -> None:
        assert lexis.get("empty_value") == ""

    def test_t003_key_trimmed(self, lexis: Lexis) -> None:
        assert lexis.get("key_trimmed") == "Value with spaces around key"

    def test_t004_uppercase_key(self, lexis: Lexis) -> None:
        assert lexis.get("UPPERCASE_KEY") == "uppercase key test"

    def test_t005_mixed_case_key(self, lexis: Lexis) -> None:
        assert lexis.get("mixed_Case_Key") == "mixed case key test"

    def test_t006_value_with_hash(self, lexis: Lexis) -> None:
        assert lexis.get(
            "value_with_hash"
        ) == "#this value starts with hash"

    def test_t007_value_with_separator(self, lexis: Lexis) -> None:
        assert lexis.get(
            "value_with_separator"
        ) == "value :: contains :: separators"

    def test_t008_leading_spaces_trimmed(self, lexis: Lexis) -> None:
        assert lexis.get(
            "value_leading_spaces"
        ) == "leading spaces are trimmed"

    def test_t009_trailing_spaces_preserved(self, lexis: Lexis) -> None:
        assert lexis.get(
            "value_trailing_spaces"
        ) == "trailing spaces are preserved   "

    def test_t010_unicode(self, lexis: Lexis) -> None:
        assert lexis.get("value_unicode") == "Hello \U0001F44B World"

    def test_t011_utf8_extended(self, lexis: Lexis) -> None:
        assert lexis.get("value_utf8") == "Héllo Wörld — ñoño"

    def test_t012_crlf_line_endings(self, standalone_dir: str) -> None:
        # Guard: the fixture must really use CRLF (git can normalize it)
        assert b"\r\n" in (FIXTURES_DIR / "crlf.lex").read_bytes()
        instance = Lexis(standalone_dir, locale="cr")
        assert instance.get(
            "crlf_entry"
        ) == "value without trailing carriage return"

    def test_t013_indented_comments_do_not_raise(
            self, tmp_path: Path
    ) -> None:
        write_lex(tmp_path, "en", "  # indented comment\nk::v\n")
        assert Lexis(str(tmp_path), "en").keys() == ("k",)

    def test_t014_whitespace_around_separator(self, lexis: Lexis) -> None:
        assert lexis.get("key_space") == "value_space"

    def test_t015_whitespace_only_lines_are_skipped(
            self, tmp_path: Path
    ) -> None:
        write_lex(tmp_path, "en", "   \n\t\nk::v\n")
        assert Lexis(str(tmp_path), "en").keys() == ("k",)

    def test_t016_complex_4byte_utf8_sequence(self, lexis: Lexis) -> None:
        family = "\U0001F468\u200D\U0001F469\u200D\U0001F467\u200D\U0001F466"
        assert lexis.get("emoji_sequence") == "Family: " + family

    def test_t017_extreme_trailing_whitespace(self, lexis: Lexis) -> None:
        assert lexis.get("huge_spaces") == "correct string" + (" " * 10000)

    def test_t018_utf8_bom_is_stripped(self, fixtures_dir: str) -> None:
        instance = Lexis(fixtures_dir, locale="bom")
        assert instance.get("first_key") == "first_value"

    def test_t019_no_trailing_newline_at_eof(self, fixtures_dir: str) -> None:
        instance = Lexis(fixtures_dir, locale="bom")
        assert instance.get("last_key") == "last_value"

    def test_t020_bom_mid_file_is_literal(self, fixtures_dir: str) -> None:
        instance = Lexis(fixtures_dir, locale="bom")
        assert instance.get("mid_bom") == "prefix_\ufeff_suffix"

    def test_t021_comment_with_separator_is_a_comment(
            self, lexis: Lexis
    ) -> None:
        assert lexis.has("comment") is False

    def test_t022_hash_line_is_never_an_entry(self, lexis: Lexis) -> None:
        assert lexis.has("hidden") is False
        assert lexis.has("#hidden") is False

    def test_t023_three_colons_after_the_key(self, lexis: Lexis) -> None:
        assert lexis.get("colon_run") == ":tail"

    def test_t024_single_colon_inside_a_key(self, lexis: Lexis) -> None:
        assert lexis.get("url:home") == "Home page"

    def test_t025_trailing_whitespace_before_crlf(
            self, standalone_dir: str
    ) -> None:
        # Guard: the fixture must really use CRLF (git can normalize it)
        assert b"\r\n" in (FIXTURES_DIR / "crlf_trailing.lex").read_bytes()
        instance = Lexis(standalone_dir, locale="ct")
        assert instance.get("crlf_trailing") == "value  "

    def test_t026_lone_cr_is_content(self, standalone_dir: str) -> None:
        instance = Lexis(standalone_dir, locale="ci")
        assert instance.get("cr_inside") == "a\rb"


# Escape Sequence Tests T-101 to T-114
class TestEscapes:
    def test_t101_newline(self, lexis: Lexis) -> None:
        assert lexis.get("escape_newline") == "Line 1\nLine 2"

    def test_t102_tab(self, lexis: Lexis) -> None:
        assert lexis.get("escape_tab") == "Col1\tCol2"

    def test_t103_backslash(self, lexis: Lexis) -> None:
        assert lexis.get("escape_backslash") == "C:\\Program Files\\Lexis"

    def test_t104_quote(self, lexis: Lexis) -> None:
        assert lexis.get("escape_quote") == 'She said "hello"'

    def test_t105_carriage_return(self, lexis: Lexis) -> None:
        assert lexis.get("escape_carriage_return") == "before\rafter"

    def test_t106_backspace(self, lexis: Lexis) -> None:
        assert lexis.get("escape_backspace") == "before\bafter"

    def test_t107_vertical_tab(self, lexis: Lexis) -> None:
        assert lexis.get("escape_vertical_tab") == "before\vafter"

    def test_t108_unknown_escape(self, lexis: Lexis) -> None:
        assert lexis.get(
            "escape_unknown"
        ) == "unknown \\q escape passes through"

    def test_t109_trailing_backslash(self, lexis: Lexis) -> None:
        assert lexis.get(
            "escape_trailing_backslash"
        ) == "trailing backslash is literal\\"

    def test_t110_combined_escapes_with_placeholders(
            self, lexis: Lexis
    ) -> None:
        result = lexis.get("escape_combined", "Alice", 99)
        assert result == "Name:\tAlice\nScore:\t99"

    def test_t111_null_escape_is_not_recognized(self, lexis: Lexis) -> None:
        assert lexis.get("escape_null") == "before\\0after"

    def test_t112_escaped_backslash_before_escape_char(
            self, lexis: Lexis
    ) -> None:
        assert lexis.get("escape_escaped_n") == "literal \\n character"

    def test_t113_argument_is_never_reunescaped(self, lexis: Lexis) -> None:
        literal_backslash_n_b = "a" + "\\" + "n" + "b"
        assert lexis.get(
            "passthrough_arg", literal_backslash_n_b
        ) == "Hello a\\nb"

    def test_t114_escapes_are_processed_before_placeholders(
            self, lexis: Lexis
    ) -> None:
        assert lexis.get("escape_then_percent", "x") == "\\x"


# Placeholder Tests T-201 to T-286
class TestPlaceholders:
    @pytest.mark.parametrize("key,args,expected", cases(PLACEHOLDERS))
    def test_formatted_output(
            self, lexis: Lexis, key: str, args: tuple, expected: str
    ) -> None:
        assert lexis.get(key, *args) == expected

    @pytest.mark.parametrize(
        "key,args",
        [pytest.param(row[1], row[2], id=row[0]) for row in FORMAT_ERRORS],
    )
    def test_raises_format_error(
            self, lexis: Lexis, key: str, args: tuple
    ) -> None:
        with pytest.raises(LexFormatError):
            lexis.get(key, *args)


# Edge Case Tests T-303 (T-301 and T-302 are retired)
class TestEdgeCase:
    def test_t303_triple_colon(self, lexis: Lexis) -> None:
        assert lexis.get(
            "triple_colon"
        ) == "key:::value with triple colon"


# Conformance Tests T-401 to T-437
class TestConformance:
    def test_t401_missing_key_raises(self, lexis: Lexis) -> None:
        with pytest.raises(LexKeyNotFoundError):
            lexis.get("nonexistent_key")

    def test_t402_missing_key_with_default(self, lexis: Lexis) -> None:
        assert lexis.get_or_default(
            "nonexistent_key",
            "fallback"
        ) == "fallback"

    def test_t403_missing_key_with_default_and_args(
            self, lexis: Lexis
    ) -> None:
        result = lexis.get_or_default(
            "nonexistent_key", "Hello %s", "Alice"
        )
        assert result == "Hello Alice"

    def test_t404_locale_fallback_default(self, fixtures_dir: str) -> None:
        # Request fr, en.lex exists, default fallback
        instance = Lexis(fixtures_dir, locale="fr")
        assert instance.locale == "en"
        assert instance.get("welcome", "Alice") == "Welcome Alice"

    def test_t405_locale_fallback_custom(self, fixtures_dir: str) -> None:
        # Request fr, fallback to pt where pt.lex exists
        instance = Lexis(
            fixtures_dir, locale="fr", fallback_locale="pt"
        )
        assert instance.fallback_locale == "pt"
        assert instance.locale == "pt"
        assert instance.get("welcome", "Alice") == "Bem-vindo Alice"

    def test_t406_reload_switches_locale(self, fixtures_dir: str) -> None:
        # Verify reload changes locale and loads different translations
        instance = Lexis(fixtures_dir, locale="es")
        assert instance.get("welcome", "Alice") == "Bienvenido Alice"
        instance.reload("en")
        assert instance.get("welcome", "Alice") == "Welcome Alice"

    def test_t407_reload_changes_fallback(self, fixtures_dir: str) -> None:
        instance = Lexis(fixtures_dir, "fr", fallback_locale="en")
        assert instance.fallback_locale == "en"
        instance.reload(locale="fr", fallback_locale="es")
        assert instance.fallback_locale == "es"
        assert instance.locale == "es"
        assert instance.get("welcome", "Alice") == "Bienvenido Alice"

    def test_t408_reload_rollback_on_failure(self, tmp_path: Path) -> None:
        # Only es.lex exists, so "xyz" and the fallback "en" both miss
        write_lex(tmp_path, "es", "welcome::Hola")
        instance = Lexis(str(tmp_path), locale="es")
        before = instance.info()
        with pytest.raises(LexFileNotFoundError):
            instance.reload("xyz")
        assert instance.info() == before
        assert instance.get("welcome") == "Hola"

    def test_t410_duplicate_key_raises(self, standalone_dir: str) -> None:
        with pytest.raises(LexParseError):
            Lexis(standalone_dir, locale="dk")

    def test_t411_malformed_line_raises(self, standalone_dir: str) -> None:
        with pytest.raises(LexParseError):
            Lexis(standalone_dir, locale="ml")

    def test_t412_empty_key_raises(self, standalone_dir: str) -> None:
        with pytest.raises(LexParseError):
            Lexis(standalone_dir, locale="ek")

    def test_t413_file_not_found_raises(self, tmp_path: Path) -> None:
        with pytest.raises(LexFileNotFoundError):
            Lexis(str(tmp_path), "en", fallback_locale="zz")

    def test_t414_lazy_caching_unescape_once(
            self, monkeypatch: pytest.MonkeyPatch, standalone_dir: str
    ) -> None:
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

    def test_t415_cache_eviction_on_reload(self, tmp_path: Path) -> None:
        write_lex(tmp_path, "aa", "k1::value from locale A\n")
        write_lex(tmp_path, "bb", "k2::value from locale B\n")
        instance = Lexis(str(tmp_path), locale="aa")
        assert instance.get("k1") == "value from locale A"
        instance.reload("bb")
        with pytest.raises(LexKeyNotFoundError):
            instance.get("k1")
        assert instance.get("k2") == "value from locale B"

    def test_t416_state_isolation_on_failed_reload(
            self, standalone_dir: str
    ) -> None:
        lang_dir = Path(standalone_dir)
        shutil.copy(lang_dir / "ml.lex", lang_dir / "xx.lex")
        instance = Lexis(standalone_dir, locale="en")
        before = dict(instance._raw_translations)
        with pytest.raises(LexParseError):
            instance.reload("xx")
        assert dict(instance._raw_translations) == before

    def test_t417_key_case_sensitivity(self, lexis: Lexis) -> None:
        assert lexis.get("KEY") != lexis.get("key")
        assert lexis.get("KEY") == "value1"
        assert lexis.get("key") == "value2"

    @pytest.mark.parametrize("raw", ["es-ES", "es_ES", "ES"])
    def test_t418_locale_code_normalization(
            self, fixtures_dir: str, raw: str
    ) -> None:
        instance = Lexis(fixtures_dir, locale=raw)
        assert instance.locale == "es"
        assert instance.info()["locale"] == "es"

    def test_t419_invalid_utf8_raises_parse_error(
            self, standalone_dir: str
    ) -> None:
        with pytest.raises(LexParseError):
            Lexis(standalone_dir, locale="iv")

    def test_t420_reserved_keys_no_prototype_pollution_optional(
            self, standalone_dir: str
    ) -> None:
        instance = Lexis(standalone_dir, locale="rk")
        assert instance.get("toString") == "mapped toString value"
        assert instance.get("valueOf") == "mapped valueOf value"
        assert instance.get("__proto__") == "mapped __proto__ value"
        assert instance.get("constructor") == "mapped constructor value"

    def test_t421_multi_instance_isolation(self, fixtures_dir: str) -> None:
        client1 = Lexis(fixtures_dir, locale="en")
        client2 = Lexis(fixtures_dir, locale="es")
        assert client1.get("welcome", "A") == "Welcome A"
        assert client2.get("welcome", "A") == "Bienvenido A"
        assert client1.info()["cached_keys"] == 1
        assert client2.info()["cached_keys"] == 1
        client2.reload("en")
        assert client1.info()["cached_keys"] == 1
        client1.reload("es")
        assert client2.locale == "en"
        assert client2.get("welcome", "A") == "Welcome A"

    def test_t422_empty_file(self, standalone_dir: str) -> None:
        instance = Lexis(standalone_dir, locale="em")
        assert len(instance) == 0

    def test_t422_comment_only_file(self, tmp_path: Path) -> None:
        write_lex(tmp_path, "en", "# only\n\n  # comments\n")
        assert len(Lexis(str(tmp_path), "en")) == 0

    @pytest.mark.parametrize("locale", BAD_LOCALES)
    def test_t423_t424_invalid_locale_rejected(
            self, fixtures_dir: str, locale: str
    ) -> None:
        with pytest.raises(LexFileNotFoundError):
            Lexis(fixtures_dir, locale=locale)

    @pytest.mark.parametrize("kwargs", [
        {"fallback_locale": "../x"},
        {"name": "../main"},
        {"name": ""},
        {"name": "a/b"},
    ], ids=["fallback", "name-traversal", "name-empty", "name-slash"])
    def test_t425_invalid_fallback_and_name_rejected(
            self, locales_dir: str, kwargs: dict
    ) -> None:
        with pytest.raises(LexFileNotFoundError):
            Lexis(locales_dir, "es", **kwargs)

    @pytest.mark.parametrize("raw", ["es-VE", "es_ve", "ES_VE"])
    def test_t426_regional_code_normalization(
            self, locales_dir: str, raw: str
    ) -> None:
        instance = Lexis(locales_dir, raw)
        assert instance.get("welcome") == "es_VE"
        assert instance.info()["locale"] == "es_VE"

    def test_t427_regional_file_layout(self, locales_dir: str) -> None:
        instance = Lexis(locales_dir, "es_VE")
        assert instance.get("welcome") == "es_VE"
        assert instance.info()["locale"] == "es_VE"

    def test_t428_regional_falls_back_to_language(
            self, locales_dir: str
    ) -> None:
        instance = Lexis(locales_dir, "es_AR")
        assert instance.get("welcome") == "es"
        assert instance.info()["locale"] == "es"

    def test_t429_directory_layout_default_name(
            self, locales_dir: str
    ) -> None:
        assert Lexis(locales_dir, "pt").get("welcome") == "pt (main)"

    def test_t430_custom_entry_file_name(self, locales_dir: str) -> None:
        instance = Lexis(locales_dir, "pt", name="custom")
        assert instance.get("welcome") == "pt (custom)"
        assert instance.info()["name"] == "custom"

    def test_t431_file_layout_wins_over_directory(
            self, locales_dir: str
    ) -> None:
        assert Lexis(locales_dir, "de").get("welcome") == "de (file)"

    def test_t432_regional_directory_layout(self, locales_dir: str) -> None:
        assert Lexis(locales_dir, "fr_CA").get("welcome") == "fr_CA (dir)"

    def test_t433_fallback_follows_its_own_shape(
            self, locales_dir: str
    ) -> None:
        instance = Lexis(locales_dir, "ja", fallback_locale="es_VE")
        assert instance.get("welcome") == "es_VE"
        assert instance.info()["locale"] == "es_VE"

    def test_t434_locale_state_follows_resolved_fallback(
            self, locales_dir: str
    ) -> None:
        instance = Lexis(locales_dir, "ja")
        assert instance.get("welcome") == "en"
        assert instance.info()["locale"] == "en"

    def test_t435_reload_keeps_entry_file_name(
            self, locales_dir: str
    ) -> None:
        instance = Lexis(locales_dir, "pt", name="custom")
        instance.reload("pt")
        assert instance.get("welcome") == "pt (custom)"
        with pytest.raises(LexFileNotFoundError):
            instance.reload("../x")
        assert instance.get("welcome") == "pt (custom)"
        assert instance.info()["name"] == "custom"

    def test_t436_reload_keeps_locale_when_omitted(
            self, locales_dir: str
    ) -> None:
        instance = Lexis(locales_dir, "es_VE")
        instance.reload(fallback_locale="en")
        assert instance.get("welcome") == "es_VE"
        assert instance.info()["locale"] == "es_VE"

    @pytest.mark.parametrize("lang,locale", [
        ("es_VE.UTF-8", "es_VE"),
        ("es_VE@euro", "es_VE"),
        ("C.UTF-8", "en"),
        ("POSIX", "en"),
        ("", "en"),
        ("zh_Hans_CN.UTF-8", "en"),
    ])
    def test_t437_locale_auto_detection_optional(
            self,
            monkeypatch: pytest.MonkeyPatch,
            locales_dir: str,
            lang: str,
            locale: str,
    ) -> None:
        monkeypatch.setenv("LANG", lang)
        instance = Lexis(locales_dir)
        assert instance.info()["locale"] == locale
        assert instance.get("welcome") == locale


# Additional Tests
class TestAdditional:
    # Extra tests not in TESTS.md but useful for completeness.
    def test_keys_method(self, lexis: Lexis) -> None:
        # Verify keys() returns all keys.
        keys = lexis.keys()
        assert "simple" in keys
        assert "empty_value" in keys

    def test_len_and_has(self, lexis: Lexis) -> None:
        assert len(lexis) > 0
        assert lexis.len() == len(lexis)
        assert lexis.has("simple") is True
        assert lexis.has("nonexistent") is False

    def test_contains_method(self, lexis: Lexis) -> None:
        # Verify __contains__ works.
        assert "simple" in lexis
        assert "nonexistent" not in lexis

    def test_info_snapshot(self, lexis: Lexis) -> None:
        info = lexis.info()
        assert set(info) == {
            "locale", "fallback_locale", "lang_dir", "name",
            "filepath", "keys", "cached_keys",
        }
        assert info["keys"] == len(lexis)

    def test_clear_empties_cache_only(self, lexis: Lexis) -> None:
        lexis.get("simple")
        assert lexis.info()["cached_keys"] == 1
        lexis.clear()
        assert lexis.info()["cached_keys"] == 0
        assert lexis.get("simple") == "Hello World"

    def test_repr(self, lexis: Lexis) -> None:
        # Verify __repr__ wraps the info() snapshot.
        assert repr(lexis) == f"Lexis({lexis.info()!r})"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
