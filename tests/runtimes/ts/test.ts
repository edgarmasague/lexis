/**
     * test.ts - Official Test Suite for LEXIS TypeScript Runtime
     * Based on TESTS.md
 */
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import * as crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { Lexis, LexFileNotFoundError, LexKeyNotFoundError, LexParseError } from "../../../runtimes/ts/lexis";
//
const __filename         = fileURLToPath(import.meta.url);
const __dirname          = path.dirname(__filename);
const FIXTURES_DIR       = path.join(__dirname, "..", "..", "fixtures");
let passed               = 0;
let failed               = 0;
const failures: string[] = [];
const tmpDirs:  string[] = [];

function reportPass(id: string): void {
    passed++;
    console.log(  `\x1b[32mPASS\x1b[0m ${id}`);
}

function reportFail(id: string, reason = ""): void {
    failed++;
    failures.push(`${id}: ${reason}`);
    console.log(  `\x1b[31mFAIL\x1b[0m ${id} - ${reason}`);
}

function assertEqual(id: string, actual: unknown, expected: unknown): void {
    const isEqual = Array.isArray(actual) && Array.isArray(expected)
        ? actual.length === expected.length && actual.every((v, i) => v === expected[i])
        : actual === expected;
    if(isEqual) {
        reportPass(id);
        return;
    }
    reportFail(id, `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
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
            reportFail(id, `expected ${expectedErrorClass.name}, got ${className}`);
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
        for(const file of fs.readdirSync(dir)) {
            fs.rmSync(path.join(dir, file), {force: true});
        }
        fs.rmdirSync(dir);
    }
}

function getPrivate<T = unknown>(instance: object, prop: string): T {
    return (instance as unknown as Record<string, T>)[prop];
}

class CountingLexis extends Lexis {
    public unescapeCalls = 0;
    protected unescape(value: string): string {
        this.unescapeCalls++;
        return super.unescape(value);
    }
}

const requiredFixtures = ['test.lex', 'en.lex', 'es.lex'];
for(const fixture of requiredFixtures) {
    if(!fs.existsSync(path.join(FIXTURES_DIR, fixture))) {
        console.error(`[test.ts] Missing required fixture: fixtures/${fixture}`);
        process.exit(1);
    }
}

// Parsing
section("Parsing");
const lex = new Lexis(FIXTURES_DIR, "test");
assertEqual("T-001", lex.get("simple"), "Hello World");
assertEqual("T-002", lex.get("empty_value"), "");
assertEqual("T-003", lex.get("key_trimmed"), "Value with spaces around key");
assertEqual("T-004", lex.get("UPPERCASE_KEY"), "uppercase key test");
assertEqual("T-005", lex.get("mixed_Case_Key"), "mixed case key test");
assertEqual("T-006", lex.get("value_with_hash"), "#this value starts with hash");
assertEqual("T-007", lex.get("value_with_separator"), "value :: contains :: separators");
assertEqual("T-008", lex.get("value_leading_spaces"), "leading spaces are trimmed");
assertEqual("T-009", lex.get("value_trailing_spaces"), "trailing spaces are preserved   ");
assertEqual("T-010", lex.get("value_unicode"), "Hello 👋 World");
assertEqual("T-011", lex.get("value_utf8"), "Héllo Wörld — ñoño");
//Escape Sequences
section("Escape Sequences");
assertEqual("T-101", lex.get("escape_newline"), "Line 1\nLine 2");
assertEqual("T-102", lex.get("escape_tab"), "Col1\tCol2");
assertEqual("T-103", lex.get("escape_backslash"), "C:\\Program Files\\Lexis");
assertEqual("T-104", lex.get("escape_quote"), 'She said "hello"');
assertEqual("T-105", lex.get("escape_carriage_return"), "before\rafter");
assertEqual("T-106", lex.get("escape_backspace"), "before\x08after");
assertEqual("T-107", lex.get("escape_vertical_tab"), "before\x0Bafter");
assertEqual("T-108", lex.get("escape_unknown"), "unknown \\q escape passes through");
assertEqual("T-109", lex.get("escape_trailing_backslash"), "trailing backslash is literal\\");
assertEqual("T-110", lex.get("escape_combined", "Alice", 99), "Name:\tAlice\nScore:\t99");
//Placeholders
section("Placeholders");
assertEqual("T-201", lex.get("placeholder_string", "Alice"), "Hello Alice");
assertEqual("T-202", lex.get("placeholder_integer", 3), "You have 3 messages");
assertEqual("T-203", lex.get("placeholder_float", 3.75), "Rating: 3.750000");
assertEqual("T-204", lex.get("placeholder_hex", 255), "Hex value: ff");
assertEqual("T-205", lex.get("placeholder_octal", 8), "Octal value: 10");
assertEqual("T-206", lex.get("placeholder_char", 65), "Char: A");
assertEqual("T-207", lex.get("placeholder_percent"), "100% completed");
assertEqual("T-208", lex.get("placeholder_multiple", "Alice", 10, 4.5), "User Alice has 10 points and rating 4.50");
//Edge Cases
section("Edge Cases");
assertEqual("T-301", lex.get("not_a_comment"), "#not a comment");
assertEqual("T-302", lex.get("double_colon"), "key::value with double colon in value");
assertEqual("T-303", lex.get("triple_colon"), "key:::value with triple colon");
//Conformance Tests
section("Conformance Tests");
assertThrows("T-401", () => lex.get("nonexistent_key"), LexKeyNotFoundError);
assertEqual("T-402", lex.getOrDefault("nonexistent_key", "fallback"), "fallback");
assertEqual("T-403", lex.getOrDefault("nonexistent_key", "Hello %s", "Alice"), "Hello Alice");
//T-404
try {
    const dir = makeTmpDir();
    writeLex(dir, "en.lex", "welcome::Welcome");
    const lexFallback = new Lexis(dir, "fr");
    if(lexFallback.getLocale() === "en" && lexFallback.get("welcome") === "Welcome") {
        reportPass("T-404");
    } else {
        reportFail("T-404", "");
    }
} catch(error) {
    reportFail("T-404", `unexpected exception: ${(error as Error).message}`);
}
//T-405
try {
    const dir = makeTmpDir();
    writeLex(dir, "pt.lex", "welcome::Bem-vindo\n");
    const lexFallback = new Lexis(dir, "pt");
    if(lexFallback.getLocale() === "pt" && lexFallback.get("welcome") === "Bem-vindo") {
        reportPass("T-405");
    } else {
        reportFail("T-405", "");
    }
} catch(error) {
    reportFail("T-405", `unexpected exception: ${(error as Error).message}`);
}
//T-406
try {
    const lexEs = new Lexis(FIXTURES_DIR, "es");
    const esOutput = lexEs.get("welcome", "Alice");
    lexEs.reload("en");
    const enOutput = lexEs.get("welcome", "Alice");
    if(esOutput === "Bienvenido Alice" && enOutput === "Welcome Alice") {
        reportPass("T-406");
    } else {
        reportFail("T-406", `got es='${esOutput}', en='${enOutput}' - check fixtures/es.lex and en.lex content`);
    }
} catch(error) {
    reportFail("T-406", `unexpected exception: ${(error as Error).message}`);
}
//T-407
{
    const originalLang = process.env.LANG;
    try {
        process.env.LANG="C.UTF-8";
        const dir = makeTmpDir();
        writeLex(dir, "es.lex", "hello::Hola");
        writeLex(dir, "en.lex", "hello::Hello");
        const lexFallbackChange = new Lexis(dir, "fr", "en");
        const before = getPrivate<string>(lexFallbackChange, "fallbackLocale");
        lexFallbackChange.reload(null, "es");
        const after = getPrivate<string>(lexFallbackChange, "fallbackLocale");
        if(
            before === "en" &&
            after === "es" &&
            lexFallbackChange.getLocale() === "es" &&
            lexFallbackChange.get("hello") === "Hola"
        ) {
            reportPass("T-407");
        } else {
            reportFail("T-407", "fallback/locale/value mismatch after reload");
        }
    } catch(error) {
        reportFail("T-407", `unexpected exception: ${(error as Error).message}`);
    } finally {
        if(originalLang === undefined) {
            delete process.env.LANG;
        } else {
            process.env.LANG = originalLang;
        }
    }
}
//T-408
try {
    const lexEn       = new Lexis(FIXTURES_DIR, "en");
    const oldLangDir  = getPrivate<string>(lexEn, "langDir");
    const oldLocale   = getPrivate<string>(lexEn, "locale");
    const oldFallback = getPrivate<string>(lexEn, "fallbackLocale");
    const oldFilepath = lexEn.getFilepath();
    const oldKeys     = lexEn.keys();
    try {
        lexEn.reload("nonexistent_xyz", "also_nonexistent");
        reportFail("T-408", "expected LexFileNotFoundError, none was thrown");
    } catch(error) {
        if(error instanceof LexFileNotFoundError) {
            const unchanged = 
                getPrivate<string>(lexEn, "langDir")        === oldLangDir &&
                getPrivate<string>(lexEn, "locale")         === oldLocale &&
                getPrivate<string>(lexEn, "fallbackLocale") === oldFallback &&
                lexEn.getFilepath()                         === oldFilepath &&
                JSON.stringify(lexEn.keys())                === JSON.stringify(oldKeys) &&
                lexEn.get("welcome", "Alice")               === "Welcome Alice";
            if(unchanged) {
                reportPass("T-408");
            } else {
                reportFail("T-408", "state was not fully preserved after failed reload");
            }
        } else {
            throw error;
        }
    }
} catch(error) {
    reportFail("T-408", `unexpected exception: ${(error as Error).message}`);
}
//T-409
try {
    const dir = makeTmpDir();
    writeLex(dir, "pt.lex", "hello::oi\n");
    writeLex(dir, "en.lex", "hello::Hello");
    const lexLoadFallback = new Lexis(dir, "fr");
    lexLoadFallback.load(dir, "fr", "pt");
    const fallback = getPrivate<string>(lexLoadFallback, "fallbackLocale");
    if(fallback === "pt" && lexLoadFallback.get("hello") === "oi") {
        reportPass("T-409");
    } else {
        reportFail("T-409", "fallback_locale or value mismatch");
    }
} catch(error) {
    reportFail("T-409", `unexpected exception: ${(error as Error).message}`);
}
//T-410
assertThrows("T-410", () => {
    const dir = makeTmpDir();
    writeLex(dir, "test.lex", "hello::First\nhello::Second\n");
    new Lexis(dir, "test");
}, LexParseError);
//T-411
assertThrows("T-411", () => {
    const dir = makeTmpDir();
    writeLex(dir, "test.lex", "valid::ok\nthis line has no separator\n");
    new Lexis(dir, "test");
}, LexParseError);
//T-412
assertThrows("T-412", () => {
    const dir = makeTmpDir();
    writeLex(dir, "test.lex", "valid::ok\n::value with no key\n");
    new Lexis(dir, "test");
}, LexParseError);
//T-413
assertThrows("T-413", () => {
    const dir = makeTmpDir();
    new Lexis(dir, "en");
}, LexFileNotFoundError);
//T-414
    try {
        const lexCounting = new CountingLexis(FIXTURES_DIR, "test");
        lexCounting.get("escape_newline");
        lexCounting.get("escape_newline");
        assertEqual("T-414", lexCounting.unescapeCalls, 1);
    } catch(error) {
        reportFail("T-414", `unexpected exception: ${(error as Error).message}`);
    }
section("Additional");
try {
    const keys = lex.keys();
    if(
        keys.includes("simple") &&
        keys.includes("welcome") &&
        keys.includes("empty_value")
    ) {
        reportPass("keys_method");
    } else {
        reportFail("keys_method", "expected keys missing - does fixtures/test.lex have a 'welcome' entry?");
    }
} catch(error) {
    reportFail("keys_method", `unexpected exception: ${(error as Error).message}`);
}
assertEqual("count_method", lex.size() > 0, true);
assertEqual("contains_method", lex.has("simple"), true);
assertEqual("contains_method_negative", lex.has("nonexistent"), false);
try {
    const repr = lex.toString();
    const ok   = repr.startsWith("Lexis(")
            && repr.includes("locale=")
            && repr.includes("keys=")
            && repr.includes("cached_keys=")
            && repr.includes("filepath=");
    if(ok) {
        reportPass("toString_method");
    } else {
        reportFail("toString_method", `missing expected fields in: ${repr}`);
    }
} catch(error) {
    reportFail("toString_method", `unexpected exception: ${(error as Error).message}`);
}
//Summary
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
