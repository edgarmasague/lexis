/**
 * test.ts - Official Test Suite for LEXIS TypeScript Runtime
 * Based on TESTS.md (T-001 to T-437). Retired IDs are not tested.
 */
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import * as crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import {
    Lexis,
    LexFileNotFoundError,
    LexKeyNotFoundError,
    LexParseError,
    LexFormatError,
} from "../../../runtimes/ts/lexis";
//
const __filename         = fileURLToPath(import.meta.url);
const __dirname          = path.dirname(__filename);
const FIXTURES_DIR       = path.join(__dirname, "..", "..", "fixtures");
const LOCALES_DIR        = path.join(FIXTURES_DIR, "locales");
let passed               = 0;
let failed               = 0;
const failures: string[] = [];
const tmpDirs:  string[] = [];

function reportPass(_id: string): void {
    passed++;
}

function reportFail(id: string, reason = ""): void {
    failed++;
    failures.push(`${id}: ${reason}`);
    console.log(  `\x1b[31mFAIL\x1b[0m ${id} - ${reason}`);
}

function show(value: unknown): string {
    // Readable text for any value, including bigint
    return typeof value === "bigint"
        ? `${value}n`
        : JSON.stringify(value, (_key, item) => typeof item === "bigint" ? `${item}n` : item);
}

// actual may be a value or a function that produces it: a function that throws
// fails this test instead of stopping the whole run.
function assertEqual(id: string, actual: unknown, expected: unknown): void {
    let value = actual;
    if(typeof actual === "function") {
        try {
            value = (actual as () => unknown)();
        } catch(error) {
            reportFail(id, `unexpected ${(error as Error).name}: ${(error as Error).message}`);
            return;
        }
    }
    const isEqual = Array.isArray(value) && Array.isArray(expected)
        ? value.length === expected.length && value.every((v, i) => v === expected[i])
        : value === expected;
    if(isEqual) {
        reportPass(id);
        return;
    }
    reportFail(id, `expected ${show(expected)}, got ${show(value)}`);
}

function assertThrows(id: string, fn: () => void, expectedErrorClass: new (...args: any[]) => Error): void {
    try {
        fn();
        reportFail(id, `expected ${expectedErrorClass.name} to be thrown, none was`);
    } catch(error) {
        if(error instanceof expectedErrorClass) {
            reportPass(id);
        } else {
            const className = error instanceof Error ? error.constructor.name : typeof error;
            reportFail(id, `expected ${expectedErrorClass.name}, got ${className}: ${(error as Error).message}`);
        }
    }
}

function section(title: string): void {
    console.log(`\n\x1b[1m${title}\x1b[0m`);
}

function makeTmpDir(): string {
    const dir = path.join(
        os.tmpdir(),
        `lexis_test_${crypto.randomBytes(8).toString("hex")}`
    );
    fs.mkdirSync(dir, {recursive: true});
    tmpDirs.push(dir);
    return dir;
}

function writeLex(dir: string, filename: string, content: string): void {
    fs.writeFileSync(path.join(dir, filename), content);
}

function cleanTmpDirs(): void {
    for(const dir of tmpDirs) {
        fs.rmSync(dir, {recursive: true, force: true});
    }
}

// Fixture names with "_" are not plain locale codes (cr_inside would be
// normalized to cr_INSIDE), so a copy of the fixtures gets short aliases.
let standalone: string | null = null;
function standaloneDir(): string {
    if(standalone === null) {
        standalone = path.join(makeTmpDir(), "fixtures");
        fs.cpSync(FIXTURES_DIR, standalone, {recursive: true});
        const aliases: Record<string, string> = {
            crlf: "cr", crlf_trailing: "ct", cr_inside: "ci", duplicate_key: "dk",
            malformed_line: "ml", empty_key: "ek", empty: "em", invalid_utf8: "iv",
            reserved_keys: "rk", test: "ts",
        };
        for(const [source, alias] of Object.entries(aliases)) {
            const file = path.join(standalone, `${source}.lex`);
            if(fs.existsSync(file)) {
                fs.copyFileSync(file, path.join(standalone, `${alias}.lex`));
            }
        }
    }
    return standalone;
}

class CountingLexis extends Lexis {
    public unescapeCalls = 0;
    protected unescape(value: string): string {
        this.unescapeCalls++;
        return super.unescape(value);
    }
}

for(const fixture of ['test.lex', 'en.lex', 'es.lex', 'pt.lex']) {
    if(!fs.existsSync(path.join(FIXTURES_DIR, fixture))) {
        console.error(`[test.ts] Missing required fixture: fixtures/${fixture}`);
        process.exit(1);
    }
}

// Parsing: T-001 to T-026
section("Parsing (T-001 to T-026)");
let lex = new Lexis(standaloneDir(), "ts");
assertEqual("T-001", () => lex.get("simple"), "Hello World");
assertEqual("T-002", () => lex.get("empty_value"), "");
assertEqual("T-003", () => lex.get("key_trimmed"), "Value with spaces around key");
assertEqual("T-004", () => lex.get("UPPERCASE_KEY"), "uppercase key test");
assertEqual("T-005", () => lex.get("mixed_Case_Key"), "mixed case key test");
assertEqual("T-006", () => lex.get("value_with_hash"), "#this value starts with hash");
assertEqual("T-007", () => lex.get("value_with_separator"), "value :: contains :: separators");
assertEqual("T-008", () => lex.get("value_leading_spaces"), "leading spaces are trimmed");
assertEqual("T-009", () => lex.get("value_trailing_spaces"), "trailing spaces are preserved   ");
assertEqual("T-010", () => lex.get("value_unicode"), "Hello 👋 World");
assertEqual("T-011", () => lex.get("value_utf8"), "Héllo Wörld — ñoño");

// T-012: CRLF line endings (the fixture must really use CRLF; git can normalize it)
assertEqual("T-012 (fixture has CRLF)", fs.readFileSync(path.join(FIXTURES_DIR, "crlf.lex")).includes("\r\n"), true);
lex = new Lexis(standaloneDir(), "cr");
assertEqual("T-012", () => lex.get("crlf_entry"), "value without trailing carriage return");

// T-013 and T-015: indented comments and whitespace-only lines are skipped
{
    const dir = makeTmpDir();
    writeLex(dir, "en.lex", "  # indented comment\n   \n\t\nk::v\n");
    assertEqual("T-013/T-015", () => new Lexis(dir, "en").keys(), ["k"]);
}

lex = new Lexis(standaloneDir(), "ts");
assertEqual("T-014", () => lex.get("key_space"), "value_space");
assertEqual("T-016", () => lex.get("emoji_sequence"), "Family: 👨‍👩‍👧‍👦");
assertEqual("T-017", () => lex.get("huge_spaces"), "correct string" + " ".repeat(10000));

{
    const bom = new Lexis(FIXTURES_DIR, "bom");
    assertEqual("T-018", () => bom.get("first_key"), "first_value");
    assertEqual("T-019", () => bom.get("last_key"), "last_value");
    assertEqual("T-020", () => bom.get("mid_bom"), "prefix_\uFEFF_suffix");
}

assertEqual("T-021", lex.has("comment"), false);
assertEqual("T-022", lex.has("hidden") || lex.has("#hidden"), false);
assertEqual("T-023", () => lex.get("colon_run"), ":tail");
assertEqual("T-024", () => lex.get("url:home"), "Home page");

assertEqual("T-025 (fixture has CRLF)", fs.readFileSync(path.join(FIXTURES_DIR, "crlf_trailing.lex")).includes("\r\n"), true);
assertEqual("T-025", () => new Lexis(standaloneDir(), "ct").get("crlf_trailing"), "value  ");
assertEqual("T-026", () => new Lexis(standaloneDir(), "ci").get("cr_inside"), "a\rb");

// Escape Sequences: T-101 to T-114
section("Escape Sequences (T-101 to T-114)");
assertEqual("T-101", () => lex.get("escape_newline"), "Line 1\nLine 2");
assertEqual("T-102", () => lex.get("escape_tab"), "Col1\tCol2");
assertEqual("T-103", () => lex.get("escape_backslash"), "C:\\Program Files\\Lexis");
assertEqual("T-104", () => lex.get("escape_quote"), 'She said "hello"');
assertEqual("T-105", () => lex.get("escape_carriage_return"), "before\rafter");
assertEqual("T-106", () => lex.get("escape_backspace"), "before\x08after");
assertEqual("T-107", () => lex.get("escape_vertical_tab"), "before\x0Bafter");
assertEqual("T-108", () => lex.get("escape_unknown"), "unknown \\q escape passes through");
assertEqual("T-109", () => lex.get("escape_trailing_backslash"), "trailing backslash is literal\\");
assertEqual("T-110", () => lex.get("escape_combined", "Alice", 99), "Name:\tAlice\nScore:\t99");
assertEqual("T-111", () => lex.get("escape_null"), "before\\0after");
assertEqual("T-112", () => lex.get("escape_escaped_n"), "literal \\n character");
assertEqual("T-113", () => lex.get("passthrough_arg", "a\\nb"), "Hello a\\nb");
assertEqual("T-114", () => lex.get("escape_then_percent", "x"), "\\x");

// Placeholders: T-201 to T-286
section("Placeholders (T-201 to T-286)");
assertEqual("T-201", () => lex.get("placeholder_string", "Alice"), "Hello Alice");
assertEqual("T-202", () => lex.get("placeholder_integer", 3), "You have 3 messages");
assertEqual("T-203", () => lex.get("placeholder_float", 3.75), "Rating: 3.75");
assertEqual("T-204", () => lex.get("placeholder_hex", 255), "Hex value: ff");
assertEqual("T-205", () => lex.get("placeholder_octal", 8), "Octal value: 10");
assertEqual("T-206", () => lex.get("placeholder_char", 65), "Char: A");
assertEqual("T-207", () => lex.get("placeholder_percent"), "100% completed");
assertEqual("T-208", () => lex.get("placeholder_multiple", "Alice", 10, 4.5), "User Alice has 10 points and rating 4.50");
assertEqual("T-211", () => lex.get("pad_neg_int", -42), "-0042");
assertEqual("T-212", () => lex.get("float_prec", 3.14159), "00003.14");
assertEqual("T-213", () => lex.get("neg_hex", -42), "-2a");
assertEqual("T-215", () => lex.get("invalid_specifier", "test"), "Value: %q");
assertEqual("T-217", () => lex.get("placeholder_float", 1e+18), "Rating: 1000000000000000000");
assertEqual("T-218", () => lex.get("placeholder_integer", 9223372036854775807n), "You have 9223372036854775807 messages");
assertEqual("T-219", () => lex.get("adjacent_percent", "Alice"), "%%s Alice");
assertEqual("T-220", () => lex.get("one_placeholder", "Alice", "extra_arg"), "Hello Alice");
assertEqual("T-221", () => lex.get("float_default_prec", 3.1), "3.1");
assertEqual("T-222", () => lex.get("float_zero_prec", 2.5), "3");
assertEqual("T-223a", () => lex.get("string_width_right", "Hi"), "   Hi");
assertEqual("T-223b", () => lex.get("string_width_left", "Hi"), "Hi   ");
assertEqual("T-224", () => lex.get("string_zero_pad", "Hi"), "   Hi");
assertEqual("T-225", () => lex.get("pos_test", "Alice", 10), "Hello Alice, code 10");
assertEqual("T-226", () => lex.get("placeholder_string", "%s%d"), "Hello %s%d");
assertEqual("T-227", () => lex.get("trailing_percent"), "Value ends with %");
assertEqual("T-229", () => lex.get("placeholder_char", 8364), "Char: €");
assertEqual("T-230", () => lex.get("i_spec", 42), "Count: 42");
assertEqual("T-231", () => lex.get("unknown_specs", "x"), "%u %X %e %g %b %n %p");
assertEqual("T-232", () => lex.get("positional_attempt_2", "Alice"), "Hello %1$s");
assertEqual("T-233", () => lex.get("width_codepoint", "ñ"), "    ñ");
assertEqual("T-234", () => lex.get("numeric_string", "42"), "42");
assertEqual("T-236", () => lex.get("float_zero_prec", -2.5), "-3");
assertEqual("T-237", () => lex.get("float_two_prec", 1.005), "1.00");
assertEqual("T-240", () => lex.get("placeholder_integer", 3.0), "You have 3 messages");
assertEqual("T-242", () => lex.get("lit_flags", 5, 5, 255), "%+d|% d|%#x");
assertEqual("T-243", () => lex.get("lit_length", 5), "%ld|%lld|%hd|%zu");
assertEqual("T-244", () => lex.get("lit_star", 5, 2, 3.14), "%*d|%.*f");
assertEqual("T-245", () => lex.get("lit_prec_s", "abcdef", 5), "%.3s|%.2d");
assertEqual("T-246", () => lex.get("lit_prec_empty", 3.5), "%.f");
assertEqual("T-247", () => lex.get("lit_flag_order", 5), "%0-5d");
assertEqual("T-248", () => lex.get("lit_percent_space"), "50% discount");
assertEqual("T-249a", () => lex.get("lit_cut_off_width"), "Width cut off %5");
assertEqual("T-249b", () => lex.get("lit_cut_off_flags"), "Flags cut off %-0");
assertEqual("T-250", () => lex.get("lit_then_real", "x"), "%qx");
assertEqual("T-251", () => lex.get("width_max", 1), " ".repeat(1023) + "1");
assertEqual("T-252", () => lex.get("width_over", 1), "%1025d");
assertEqual("T-253", () => lex.get("width_overflow", 1), "%99999999999999999999d");
assertEqual("T-254", () => lex.get("prec_max", 0.1), "0.100000000000000");
assertEqual("T-255a", () => lex.get("prec_over", 0.1), "%.16f");
assertEqual("T-255b", () => lex.get("prec_overflow", 1), "%.99999999999999999999f");
assertEqual("T-256", () => lex.get("pad_left_zero", 42), "42   |");
assertEqual("T-257", () => lex.get("pad_char_zero", 65), "  A|");
assertEqual("T-258", () => lex.get("pad_neg_float", -3.14159), "-0003.14");
assertEqual("T-259", () => lex.get("pad_neg_hex", -42), "-002a");
assertEqual("T-260", () => lex.get("pad_left_float", 3.14159), "3.14    |");
assertEqual("T-261", () => lex.get("pad_no_truncate", 12345), "12345");
assertEqual("T-262", () => lex.get("width_emoji", "👋"), "    👋|");
assertEqual("T-263", () => lex.get("width_combining", "é"), "   é|");
assertEqual("T-264a", () => lex.get("s_int", -42), "-42");
assertEqual("T-264b", () => lex.get("s_int_min", -9223372036854775808n), "-9223372036854775808");
assertEqual("T-265a", () => lex.get("s_float", 3.14), "3.14");
assertEqual("T-265b", () => lex.get("s_float_int", 3.0), "3");
assertEqual("T-265c", () => lex.get("s_float_tiny", 4e-07), "0");
assertEqual("T-270", () => lex.get("d_int_min", -9223372036854775808n), "-9223372036854775808");
assertEqual("T-273a", () => lex.get("hex_zero", 0), "0");
assertEqual("T-273b", () => lex.get("hex_int_min", -9223372036854775808n), "-8000000000000000");
assertEqual("T-273c", () => lex.get("oct_neg", -8), "-10");
assertEqual("T-276a", () => lex.get("char_astral", 128075), "👋");
assertEqual("T-276b", () => lex.get("char_max", 1114111), "􏿿");
assertEqual("T-276c", () => lex.get("char_numstr", "65"), "A");
assertEqual("T-278a", () => lex.get("f_def_int_valued", 3.0), "3");
assertEqual("T-278b", () => lex.get("f_def_hundred", 100.0), "100");
assertEqual("T-278c", () => lex.get("f_def_sum", 0.30000000000000004), "0.3");
assertEqual("T-278d", () => lex.get("f_def_third", 0.3333333333333333), "0.333333");
assertEqual("T-278e", () => lex.get("f_def_round", 1.23456789), "1.234568");
assertEqual("T-278f", () => lex.get("f_def_big", 1234567.891), "1234567.891");
assertEqual("T-278g", () => lex.get("f_def_intarg", 3), "3");
assertEqual("T-279a", () => lex.get("f_def_tiny", 4e-07), "0");
assertEqual("T-279b", () => lex.get("f_def_tiny_neg", -4e-07), "0");
assertEqual("T-279c", () => lex.get("f_def_negzero", -0), "0");
assertEqual("T-279d", () => lex.get("f_def_edge", 1e-06), "0.000001");
assertEqual("T-280a", () => lex.get("f_prec_small", 4e-07), "0.0000004");
assertEqual("T-280b", () => lex.get("f_prec_pad", 3.0), "3.00");
assertEqual("T-280c", () => lex.get("f_prec_intarg", 1), "1.00");
assertEqual("T-280d", () => lex.get("f_prec_one", 3.1), "3.10");
assertEqual("T-281a", () => lex.get("f_tie_half", 0.5), "1");
assertEqual("T-281b", () => lex.get("f_tie_onehalf", 1.5), "2");
assertEqual("T-282", () => lex.get("f_neg_tiny", -0.001), "0.00");
assertEqual("T-283", () => lex.get("f_str", "3.14"), "3.14");
assertEqual("T-284", () => lex.get("f_big_prec", 9e+18), "9000000000000000000.00");
assertEqual("T-286", () => lex.get("pct_pct_s"), "%s");

// Placeholders that must raise LexFormatError
section("Placeholders that raise LexFormatError");
assertThrows("T-209", () => lex.get("bool_spec", true, false), LexFormatError);
assertThrows("T-210", () => lex.get("null_spec", null), LexFormatError);
assertThrows("T-214", () => lex.get("two_placeholders", "only_one_arg"), LexFormatError);
assertThrows("T-216a", () => lex.get("placeholder_float", NaN), LexFormatError);
assertThrows("T-216b", () => lex.get("placeholder_float", Infinity), LexFormatError);
assertThrows("T-228", () => lex.get("placeholder_integer", "abc"), LexFormatError);
assertThrows("T-235", () => lex.get("placeholder_float", -Infinity), LexFormatError);
assertThrows("T-238a", () => lex.get("placeholder_float", 9.223372036854776e+18), LexFormatError);
assertThrows("T-238b", () => lex.get("placeholder_float", 1e+19), LexFormatError);
assertThrows("T-238c", () => lex.get("placeholder_float", 1e+21), LexFormatError);
assertThrows("T-239", () => lex.get("placeholder_char", 1114112), LexFormatError);
assertThrows("T-241", () => lex.get("placeholder_integer", 3.7), LexFormatError);
assertThrows("T-266", () => lex.get("s_bool", true), LexFormatError);
assertThrows("T-267", () => lex.get("s_null", null), LexFormatError);
assertThrows("T-268", () => lex.get("s_bad_utf8", "\udcc3("), LexFormatError);
assertThrows("T-269a", () => lex.get("d_str_float", "4.0"), LexFormatError);
assertThrows("T-269b", () => lex.get("d_str_plus", "+5"), LexFormatError);
assertThrows("T-269c", () => lex.get("d_str_space", " 5"), LexFormatError);
assertThrows("T-269d", () => lex.get("d_str_empty", ""), LexFormatError);
assertThrows("T-271a", () => lex.get("d_float_big", 1e+19), LexFormatError);
assertThrows("T-271b", () => lex.get("d_str_big", "9223372036854775808"), LexFormatError);
assertThrows("T-272a", () => lex.get("d_nan", NaN), LexFormatError);
assertThrows("T-272b", () => lex.get("d_inf", Infinity), LexFormatError);
assertThrows("T-274a", () => lex.get("hex_frac", 3.5), LexFormatError);
assertThrows("T-274b", () => lex.get("hex_bad_str", "zz"), LexFormatError);
assertThrows("T-275a", () => lex.get("char_zero", 0), LexFormatError);
assertThrows("T-275b", () => lex.get("char_neg", -1), LexFormatError);
assertThrows("T-275c", () => lex.get("char_surr_lo", 55296), LexFormatError);
assertThrows("T-275d", () => lex.get("char_surr_hi", 57343), LexFormatError);
assertThrows("T-277", () => lex.get("char_str", "A"), LexFormatError);
assertThrows("T-283a", () => lex.get("f_str_exp", "1e5"), LexFormatError);
assertThrows("T-283b", () => lex.get("f_str_bad", "abc"), LexFormatError);
assertThrows("T-285", () => lex.get("f_bool", true), LexFormatError);

// Edge Cases: T-303 (T-301 and T-302 are retired)
section("Edge Cases (T-303)");
assertEqual("T-303", () => lex.get("triple_colon"), "key:::value with triple colon");

// Conformance Tests: T-401 to T-437
section("Conformance Tests (T-401 to T-437)");
assertThrows("T-401", () => lex.get("nonexistent_key"), LexKeyNotFoundError);
assertEqual("T-402", () => lex.getOrDefault("nonexistent_key", "fallback"), "fallback");
assertEqual("T-403", () => lex.getOrDefault("nonexistent_key", "Hello %s", "Alice"), "Hello Alice");

// T-404: request fr, only en.lex exists
{
    const dir = makeTmpDir();
    writeLex(dir, "en.lex", "welcome::Welcome");
    const lexFallback = new Lexis(dir, "fr");
    assertEqual("T-404", () => [lexFallback.getLocale(), lexFallback.get("welcome")], ["en", "Welcome"]);
}
// T-405: custom fallback, only pt.lex exists
{
    const dir = makeTmpDir();
    writeLex(dir, "pt.lex", "welcome::Bem-vindo\n");
    const lexFallback = new Lexis(dir, "fr", "pt");
    assertEqual("T-405", () => [lexFallback.info().fallbackLocale, lexFallback.getLocale(), lexFallback.get("welcome")], ["pt", "pt", "Bem-vindo"]);
}
// T-406: reload switches locale
{
    const lexEs = new Lexis(FIXTURES_DIR, "es");
    assertEqual("T-406 (es)", () => lexEs.get("welcome", "Alice"), "Bienvenido Alice");
    lexEs.reload("en");
    assertEqual("T-406 (en)", () => lexEs.get("welcome", "Alice"), "Welcome Alice");
}
// T-407: reload changes the fallback
{
    const dir = makeTmpDir();
    writeLex(dir, "en.lex", "hello::Hello");
    const lexFallbackChange = new Lexis(dir, "en", "en");
    lexFallbackChange.reload(null, "es");
    assertEqual("T-407", lexFallbackChange.info().fallbackLocale, "es");
}
// T-408: a reload that fails keeps the whole previous state
{
    const dir = makeTmpDir();
    writeLex(dir, "es.lex", "welcome::Hola");
    const kept   = new Lexis(dir, "es");
    const before = kept.info();
    assertThrows("T-408", () => kept.reload("xyz"), LexFileNotFoundError);
    assertEqual("T-408 (state unchanged)", JSON.stringify(kept.info()), JSON.stringify(before));
    assertEqual("T-408 (still works)", () => kept.get("welcome"), "Hola");
}
// T-410 to T-413
assertThrows("T-410", () => new Lexis(standaloneDir(), "dk"), LexParseError);
assertThrows("T-411", () => new Lexis(standaloneDir(), "ml"), LexParseError);
assertThrows("T-412", () => new Lexis(standaloneDir(), "ek"), LexParseError);
assertThrows("T-413", () => new Lexis(path.join(makeTmpDir(), "nonexistent", "path"), "en"), LexFileNotFoundError);
// T-414 (white-box, optional): unescape runs once per key
{
    const lexCounting = new CountingLexis(FIXTURES_DIR, "test");
    const first  = lexCounting.get("escape_newline");
    const second = lexCounting.get("escape_newline");
    assertEqual("T-414 (same output)", second, first);
    assertEqual("T-414 (unescaped once)", lexCounting.unescapeCalls, 1);
}
// T-415: cache eviction on reload
{
    const dir = makeTmpDir();
    writeLex(dir, "aa.lex", "k1::value from locale A\n");
    writeLex(dir, "bb.lex", "k2::value from locale B\n");
    const evicting = new Lexis(dir, "aa");
    assertEqual("T-415", () => evicting.get("k1"), "value from locale A");
    evicting.reload("bb");
    assertThrows("T-415 (k1 is gone)", () => evicting.get("k1"), LexKeyNotFoundError);
    assertEqual("T-415 (k2)", () => evicting.get("k2"), "value from locale B");
    // T-416: a failed reload leaves the loaded state untouched
    writeLex(dir, "bad.lex", "x::1\nx::2\n");
    const isolated = new Lexis(dir, "aa");
    assertThrows("T-416", () => isolated.reload("bad"), LexParseError);
    assertEqual("T-416 (keys)", isolated.keys(), ["k1"]);
    assertEqual("T-416 (value)", () => isolated.get("k1"), "value from locale A");
}
// T-417: keys are case sensitive
{
    const dir = makeTmpDir();
    writeLex(dir, "en.lex", "KEY::value1\nkey::value2\n");
    const cased = new Lexis(dir, "en");
    assertEqual("T-417", () => [cased.get("KEY"), cased.get("key")], ["value1", "value2"]);
}
for(const code of ["es-ES", "es_ES", "ES"]) {
    assertEqual(`T-418 (${code})`, () => new Lexis(FIXTURES_DIR, code).info().locale, "es");
}
assertThrows("T-419", () => new Lexis(standaloneDir(), "iv"), LexParseError);
{
    const reserved = new Lexis(standaloneDir(), "rk");
    for(const key of ["toString", "valueOf", "__proto__", "constructor"]) {
        assertEqual(`T-420 (${key})`, () => reserved.get(key), `mapped ${key} value`);
    }
}
// T-421: two instances do not share state
{
    const client1 = new Lexis(FIXTURES_DIR, "en");
    const client2 = new Lexis(FIXTURES_DIR, "es");
    assertEqual("T-421 (en)", () => client1.get("welcome", "A"), "Welcome A");
    assertEqual("T-421 (es)", () => client2.get("welcome", "A"), "Bienvenido A");
    client2.reload("en");
    client1.reload("es");
    assertEqual("T-421 (isolated)", [client1.getLocale(), client2.getLocale()], ["es", "en"]);
}
// T-422: empty and comment-only files
assertEqual("T-422 (empty file)", () => new Lexis(standaloneDir(), "em").len(), 0);
{
    const dir = makeTmpDir();
    writeLex(dir, "en.lex", "# only\n\n  # comments\n");
    assertEqual("T-422 (comment-only file)", () => new Lexis(dir, "en").len(), 0);
}
// T-423 and T-424: invalid locale codes are rejected before the filesystem is touched
for(const bad of ["../secret", "es/..", "es\\x", "es.x", "", "es_VE_X", "es VE"]) {
    assertThrows(`T-423/T-424 [${bad}]`, () => new Lexis(LOCALES_DIR, bad), LexFileNotFoundError);
}
// T-425: invalid fallback and entry-file name
assertThrows("T-425 (fallback)", () => new Lexis(LOCALES_DIR, "es", "../x"), LexFileNotFoundError);
for(const bad of ["../main", "", "a/b"]) {
    assertThrows(`T-425 (name '${bad}')`, () => new Lexis(LOCALES_DIR, "es", "en", bad), LexFileNotFoundError);
}
for(const code of ["es-VE", "es_ve", "ES_VE"]) {
    const regional = new Lexis(LOCALES_DIR, code);
    assertEqual(`T-426 (${code})`, () => [regional.get("welcome"), regional.info().locale], ["es_VE", "es_VE"]);
}
{
    const chain = new Lexis(LOCALES_DIR, "es_VE");
    assertEqual("T-427", () => [chain.get("welcome"), chain.getLocale()], ["es_VE", "es_VE"]);
    const upward = new Lexis(LOCALES_DIR, "es_AR");
    assertEqual("T-428", () => [upward.get("welcome"), upward.getLocale()], ["es", "es"]);
}
assertEqual("T-429", () => new Lexis(LOCALES_DIR, "pt").get("welcome"), "pt (main)");
{
    const named = new Lexis(LOCALES_DIR, "pt", "en", "custom");
    assertEqual("T-430", () => [named.get("welcome"), named.info().name], ["pt (custom)", "custom"]);
}
assertEqual("T-431", () => new Lexis(LOCALES_DIR, "de").get("welcome"), "de (file)");
assertEqual("T-432", () => new Lexis(LOCALES_DIR, "fr_CA").get("welcome"), "fr_CA (dir)");
{
    const shaped = new Lexis(LOCALES_DIR, "ja", "es_VE");
    assertEqual("T-433", () => [shaped.get("welcome"), shaped.getLocale()], ["es_VE", "es_VE"]);
    const resolved = new Lexis(LOCALES_DIR, "ja");
    assertEqual("T-434", () => [resolved.get("welcome"), resolved.getLocale()], ["en", "en"]);
}
{
    const custom = new Lexis(LOCALES_DIR, "pt", "en", "custom");
    custom.reload("pt");
    assertEqual("T-435 (reload)", () => custom.get("welcome"), "pt (custom)");
    assertThrows("T-435 (invalid)", () => custom.reload("../x"), LexFileNotFoundError);
    assertEqual("T-435 (after failure)", () => [custom.get("welcome"), custom.info().name], ["pt (custom)", "custom"]);
    const keeping = new Lexis(LOCALES_DIR, "es_VE");
    keeping.reload(null, "en");
    assertEqual("T-436", () => [keeping.get("welcome"), keeping.getLocale()], ["es_VE", "es_VE"]);
}
// T-437 (optional): locale auto-detection from LANG
{
    const originalLang = process.env.LANG;
    const detections: Record<string, string> = {
        "es_VE.UTF-8": "es_VE", "es_VE@euro": "es_VE", "C.UTF-8": "en",
        "POSIX": "en", "": "en", "zh_Hans_CN.UTF-8": "en",
    };
    for(const [lang, locale] of Object.entries(detections)) {
        process.env.LANG = lang;
        assertEqual(`T-437 [${lang}]`, () => {
            const detected = new Lexis(LOCALES_DIR);
            return [detected.info().locale, detected.get("welcome")];
        }, [locale, locale]);
    }
    if(originalLang === undefined) {
        delete process.env.LANG;
    } else {
        process.env.LANG = originalLang;
    }
}

// Additional tests: public API that TESTS.md does not number
section("Additional");
lex = new Lexis(standaloneDir(), "ts");
assertEqual("has", [lex.has("simple"), lex.has("nonexistent")], [true, false]);
assertEqual("keys", () => ["simple", "welcome", "empty_value"].every((key) => lex.keys().includes(key)), true);
assertEqual("len / size", [lex.len() > 0, lex.size() === lex.len()], [true, true]);
assertEqual("info fields", Object.keys(lex.info()), ["locale", "fallbackLocale", "langDir", "name", "filepath", "keys", "cachedKeys"]);
assertEqual("info keys", lex.info().keys, lex.len());
{
    const repr = lex.toString();
    assertEqual("toString", repr.startsWith("Lexis(") && repr.includes("locale='ts'") && repr.includes("cached_keys="), true);
}
lex.get("simple");
assertEqual("cache is filled", lex.info().cachedKeys >= 1, true);
lex.clear();
assertEqual("clear empties the cache", lex.info().cachedKeys, 0);
assertEqual("clear keeps the translations", () => lex.get("simple"), "Hello World");
assertThrows("getOrDefault fails on a bad argument", () => lex.getOrDefault("zz", "%d", "abc"), LexFormatError);
assertEqual("getOrDefault (existing key)", () => lex.getOrDefault("simple", "unused"), "Hello World");

// Summary
cleanTmpDirs();
const total = passed + failed;
console.log(`\n${"-".repeat(40)}`);
console.log(`${passed}/${total} passed`);
if(failed > 0) {
    console.log("\n\x1b[31mFailures:\x1b[0m");
    for (const failure of failures) {
        console.log(` - ${failure}`);
    }
    process.exit(1);
}
console.log("\x1b[32mAll Lexis conformance tests passed.\x1b[0m");
process.exit(0);