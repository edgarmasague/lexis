/**
 *
 * Lexis.ts LEXIS Independent Translation Engine
 * Official TypeScript Runtime
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

export class LexFileNotFoundError extends Error {
    // Raised when no .lex file is found for the requested locale.
    constructor(message: string) {
        super(message);
        this.name = "LexFileNotFoundError";
    }
}

export class LexKeyNotFoundError extends Error {
    // Raised when a key is not found in the loaded .lex file.
    constructor(message: string) {
        super(message);
        this.name = "LexKeyNotFoundError";
    }
}

export class LexParseError extends Error {
    // Raised when .lex file contains malformed lines.
    constructor(message: string) {
        super(message);
        this.name = "LexParseError";
    }
}

export class LexFormatError extends Error {
    // Raised for placeholder errors: a missing argument, or an argument
    // that is invalid for its specifier (type, range, %c code point...).
    constructor(message: string) {
        super(message);
        this.name = "LexFormatError";
    }
}

export interface LexisInfo {
    locale:         string;
    fallbackLocale: string;
    langDir:        string;
    name:           string;
    filepath:       string;
    keys:           number;
    cachedKeys:     number;
}

// Official escape sequences
const ESCAPE_SEQUENCES: Record<string, string> = {
    '\\': '\\',
    'n':  "\n",
    't':  "\t",
    'r':  "\r",
    'b':  "\b",
    'v':  "\v",
    '"':  '"',
};
const ESCAPE_RE = /\\([\\ntrbv"])/g;

// {language} or {language}_{REGION}. Without the m flag "$" only matches at the
// very end, so a trailing newline can never slip through.
const LOCALE_PATTERN = /^[A-Za-z0-9]+(?:[_-][A-Za-z0-9]+)?$/;
const NAME_PATTERN   = /^[A-Za-z0-9_-]+$/;

// %[-][0][width][.precision]specifier, or %%
const PLACEHOLDER_RE = /%(?:(%)|(-)?(0)?([0-9]+)?(?:\.([0-9]+))?([sdifxoc]))/g;
const PLAIN_INT      = /^-?[0-9]+$/;
const PLAIN_DECIMAL  = /^(-?)([0-9]+)(?:\.([0-9]+))?$/;

// Placeholder limits
const MAX_WIDTH         = 1024;
const MAX_PRECISION     = 15;
const WIDTH_DIGITS      = String(MAX_WIDTH).length;
const PRECISION_DIGITS  = String(MAX_PRECISION).length;
const DEFAULT_PRECISION = 6;   // %f without a precision

// Argument ranges
const INT64_MIN      = -(2n ** 63n);
const INT64_MAX      = 2n ** 63n - 1n;
const FLOAT_LIMIT    = 2n ** 63n;   // %f accepts |value| below this
const MAX_CODE_POINT = 0x10FFFF;

const LONE_SURROGATE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;

function isWhitespace(code: number): boolean {
    // Whitespace as str.strip() sees it in the reference runtime.
    return (code >= 0x09 && code <= 0x0D) || (code >= 0x1C && code <= 0x20)
        || code === 0x85 || code === 0xA0 || code === 0x1680
        || (code >= 0x2000 && code <= 0x200A) || code === 0x2028 || code === 0x2029
        || code === 0x202F || code === 0x205F || code === 0x3000;
}

function firstNonWhitespace(text: string): number {
    // Index of the first non-whitespace character (text.length if none). Linear time.
    let i = 0;
    while(i < text.length && isWhitespace(text.charCodeAt(i))) {
        i++;
    }
    return i;
}

function strip(text: string): string {
    // Trim whitespace at both ends, in linear time.
    let end = text.length;
    while(end > 0 && isWhitespace(text.charCodeAt(end - 1))) {
        end--;
    }
    return text.slice(firstNonWhitespace(text), end);
}

function normalizeCode(code: string): string {
    // es-ve -> es_VE: lowercase language, uppercase region
    const parts = code.replace(/-/g, "_").split("_");
    return parts.length === 1
        ? parts[0].toLowerCase()
        : `${parts[0].toLowerCase()}_${parts[1].toUpperCase()}`;
}

function describe(arg: unknown): string {
    // Text of an argument for error messages (BigInt and symbols are not JSON friendly)
    if(typeof arg === "string") {
        return JSON.stringify(arg);
    }
    if(typeof arg === "bigint") {
        return `${arg}n`;
    }
    return String(arg);
}

function codePointLength(text: string): number {
    // Width counts code points: not UTF-16 units, and not grapheme clusters
    let length = 0;
    for(const _char of text) {
        length++;
    }
    return length;
}

export class Lexis {
    /**
     * Lexis Engine
     * Load .lex files and provides key based translation with
     * printf-style placeholder support (Lexis' own formatter).
     * Loading strategy:
     *      Eager - entire file is parsed and validated on load()
     *      Lazy  - escape sequences are processed only on first access.
     */
    // Global state
    private langDir                                = "";
    private locale                                 = "";
    private fallbackLocale                         = "en";
    private name                                   = "main";
    private filepath                               = "";
    private rawTranslations: Map<string, string>   = new Map();
    private cacheTranslations: Map<string, string> = new Map();
    constructor(
        /**
         * Initializes the engine: resolves the .lex file path for
         * the given locale (falling back if needed) and loads it immediately.
         * Args:
         *      langDir: Directory containing .lex files.
         *      locale: Locale code. Auto-detected if null.
         *      fallbackLocale: Fallback locale code. Default is "en".
         *      name: Entry-file name for the directory layout. Default is "main".
         */
        langDir: string,
        locale: string | null = null,
        fallbackLocale: string | null = "en",
        name: string | null = "main"
    ) {
        this.load(langDir, locale, fallbackLocale, name);
    }

    private detectLocale(): string {
        /**
         * Safely detect system locale from environment.
         * Returns:
         *      locale code: "language" or "language_REGION" (e.g. 'en', 'es_VE').
         */
        const lang = (process.env.LANG ?? "").split(/[.@]/, 1)[0].trim();
        // Handle C, POSIX, or missing LANG
        if(lang === "" || lang === "C" || lang === "POSIX") {
            return "en";
        }
        let parts = lang.replace(/-/g, "_").split("_");
        if(parts.length > 2) {
            // zh_Hans_CN -> zh_CN: keep only language and region
            parts = [parts[0], parts[parts.length - 1]];
        }
        if(!LOCALE_PATTERN.test(parts.join("_"))) {
            return "en";   // a garbage LANG must not break loading
        }
        return normalizeCode(parts.join("_"));
    }

    private resolveFilepath(
        langDir: string,
        locale: string,
        fallbackLocale: string,
        name: string
    ): string {
        /**
         * Resolve the .lex file path after validating and normalizing
         * the inputs.
         * Regional locale (es_VE):
         *      es_VE.lex, es_VE/{name}.lex, es.lex, es/{name}.lex
         * Language-only locale (es):
         *      es.lex, es/{name}.lex
         * The same steps are then applied to fallbackLocale. Updates
         * this.locale to the code of the file actually found.
         * Returns:
         *      Absolute path to the .lex file.
         * Raises:
         *      LexFileNotFoundError:
         *          If an input is invalid (before touching the filesystem)
         *          or no file is found.
         */
        const codes: string[] = [];
        for(const code of [locale, fallbackLocale]) {
            if(typeof code !== "string" || !LOCALE_PATTERN.test(code)) {
                throw new LexFileNotFoundError(`Invalid locale code: ${describe(code)}`);
            }
            codes.push(normalizeCode(code));
        }
        if(typeof name !== "string" || !NAME_PATTERN.test(name)) {
            throw new LexFileNotFoundError(`Invalid entry-file name: ${describe(name)}`);
        }
        if(typeof langDir !== "string") {
            throw new LexFileNotFoundError(`Invalid language directory: ${describe(langDir)}`);
        }
        // Every place to look, in order: es_VE, then es, then the fallback
        for(const requested of codes) {
            for(const code of new Set([requested, requested.split("_")[0]])) {
                for(const candidate of [
                    path.join(langDir, `${code}.lex`),
                    path.join(langDir, code, `${name}.lex`),
                ]) {
                    if(fs.statSync(candidate, { throwIfNoEntry: false })?.isFile()) {
                        this.locale = code;
                        return path.resolve(candidate);
                    }
                }
            }
        }
        throw new LexFileNotFoundError(
            `No .lex file found for locale '${codes[0]}' ` +
                `(fallback '${codes[1]}') in '${langDir}'`
        );
    }

    protected unescape(value: string): string {
        /**
         * Process escape sequences in values.
         * One left-to-right pass: a replacement is never processed again.
         * Args:
         *      value: Raw value string from .lex file.
         * Returns:
         *      Value with escape sequences converted.
         */
        return value.replace(ESCAPE_RE, (_match, char: string) => ESCAPE_SEQUENCES[char]);
    }

    private parseLine(
        rawLine: string,
        lineNum: number,
        hasLineFeed: boolean
    ): [string, string] | null {
        /**
         * Parse a single line from .lex file.
         * Args:
         *      rawLine: Raw line string, without its LF.
         *      lineNum: Line number for error reporting.
         *      hasLineFeed: Whether the line ended with an LF.
         * Returns:
         *      Tuple of (key, value) or null if line skipped.
         * Raises:
         *      LexParseError:
         *          On malformed lines or duplicates.
         */
        // Only a CR directly before an LF belongs to the line ending
        const line = hasLineFeed && rawLine.endsWith("\r") ? rawLine.slice(0, -1) : rawLine;
        // Skip empty (whitespace-only) lines or comments
        const first = firstNonWhitespace(line);
        if(first === line.length || line[first] === "#") {
            return null;
        }
        // Every valid entry must contain the separator
        const separatorIndex = line.indexOf("::");
        if(separatorIndex === -1) {
            throw new LexParseError(
                `Malformed line ${lineNum} in ${this.filepath}: missing '::' separator`
            );
        }
        // Split on first occurrence of separator
        const key = strip(line.slice(0, separatorIndex));
        // Key cannot be empty after trimming
        if(key === "") {
            throw new LexParseError(
                `Malformed line ${lineNum} in ${this.filepath}: empty key`
            );
        }
        // Duplicate keys are not allowed
        if(this.rawTranslations.has(key)) {
            throw new LexParseError(
                `Duplicate key '${key}' at line ${lineNum} in ${this.filepath}`
            );
        }
        // Left-trim the value only: trailing whitespace is kept
        const rawValue = line.slice(separatorIndex + 2);
        return [key, rawValue.slice(firstNonWhitespace(rawValue))];
    }

    private loadFile(): void {
        /**
         * Load and parse the entire .lex file into memory.
         * Raises:
         *      LexFileNotFoundError:
         *          If file disappears during load.
         *      LexParseError:
         *          If the file is not valid UTF-8 or is malformed.
         */
        this.rawTranslations   = new Map();
        this.cacheTranslations = new Map();
        let buffer: Buffer;
        try {
            buffer = fs.readFileSync(this.filepath);
        } catch {
            // Race condition: file deleted after resolve but before open
            throw new LexFileNotFoundError(
                `File not found: ${this.filepath}`
            );
        }
        let content: string;
        try {
            // fatal rejects overlong forms, surrogates and values above U+10FFFF;
            // a leading BOM (and only a leading one) is removed
            content = new TextDecoder("utf-8", { fatal: true }).decode(buffer);
        } catch {
            throw new LexParseError(
                `Invalid UTF-8 in ${this.filepath}`
            );
        }
        // One line with its LF, or a last line without one. A lone CR is content.
        let offset  = 0;
        let lineNum = 0;
        while(offset < content.length) {
            const newline = content.indexOf("\n", offset);
            const hasLineFeed = newline !== -1;
            const rawLine = hasLineFeed ? content.slice(offset, newline) : content.slice(offset);
            offset = hasLineFeed ? newline + 1 : content.length;
            lineNum++;
            const result = this.parseLine(rawLine, lineNum, hasLineFeed);
            if(result !== null) {
                this.rawTranslations.set(result[0], result[1]);
            }
        }
    }

    private cacheFetch(key: string): string {
        /**
         * Fetch value from cache.
         * Args:
         *      key: Translation key.
         * Returns:
         *      Unescaped (processed) value string
         * Raises:
         *      LexKeyNotFoundError:
         *          If key not found.
         */
        if(!this.rawTranslations.has(key)) {
            throw new LexKeyNotFoundError(`Key not found: '${key}'`);
        }
        if(!this.cacheTranslations.has(key)) {
            this.cacheTranslations.set(key, this.unescape(this.rawTranslations.get(key) as string));
        }
        return this.cacheTranslations.get(key) as string;
    }

    // --- Lexis' own printf ---------------------------------------------------

    private badArgument(arg: unknown, spec: string): LexFormatError {
        return new LexFormatError(`Invalid argument ${describe(arg)} for '%${spec}'`);
    }

    private toInteger(arg: unknown, spec: string): bigint {
        /**
         * A signed 64-bit integer from a bigint, an integral number or a plain
         * integer string. Booleans, null and everything else are never valid.
         */
        let value: bigint | null = null;
        if(typeof arg === "bigint") {
            value = arg;
        } else if(typeof arg === "number") {
            if(Number.isInteger(arg) && Math.abs(arg) < 2 ** 63) {
                value = BigInt(arg);
            }
        } else if(typeof arg === "string" && PLAIN_INT.test(arg)) {
            value = BigInt(arg);
        }
        if(value === null || value < INT64_MIN || value > INT64_MAX) {
            throw this.badArgument(arg, spec);
        }
        return value;
    }

    private decimalToDouble(digits: bigint, decimals: number): [bigint, number] {
        /**
         * Nearest IEEE 754 double (ties to even) of digits / 10^decimals, as
         * [q, p] with value = q / 2^p. Done in integers, so it never depends on
         * how the host parses long decimal strings.
         */
        if(digits === 0n) {
            return [0n, 0];
        }
        const denominator = 10n ** BigInt(decimals);
        const bitLength   = (n: bigint): number => n.toString(2).length;
        let p = 53 - bitLength(digits) + bitLength(denominator);
        let numerator: bigint;
        let divisor:   bigint;
        let q:         bigint;
        for(;;) {
            if(p >= 0) {
                numerator = digits << BigInt(p);
                divisor   = denominator;
            } else {
                numerator = digits;
                divisor   = denominator << BigInt(-p);
            }
            q = numerator / divisor;
            if(q >= 2n ** 53n) {
                p -= 1;
                continue;
            }
            break;
        }
        const remainder = numerator - q * divisor;
        if(2n * remainder > divisor || (2n * remainder === divisor && (q & 1n) === 1n)) {
            q += 1n;
        }
        if(q === 2n ** 53n) {
            q = 2n ** 52n;
            p -= 1;
        }
        return [q, p];
    }

    private numberToDouble(value: number): [bigint, number] {
        // Exact mantissa and exponent of a finite double: value = q / 2^p
        const view = new DataView(new ArrayBuffer(8));
        view.setFloat64(0, Math.abs(value));
        const high     = view.getUint32(0);
        const exponent = (high >>> 20) & 0x7FF;
        const mantissa = (BigInt(high & 0xFFFFF) << 32n) | BigInt(view.getUint32(4));
        return exponent === 0
            ? [mantissa, 1074]
            : [mantissa | (1n << 52n), 1075 - exponent];
    }

    private formatFloat(arg: unknown, decimals: number, stripZeros: boolean, spec: string): string {
        /**
         * Text for %f, and %s with a float: the exact value of the double,
         * rounded half away from zero to the requested decimals.
         */
        const scale = 10n ** BigInt(decimals);
        let negative = false;
        let digits: string;
        if(typeof arg === "bigint") {
            if(arg <= -FLOAT_LIMIT || arg >= FLOAT_LIMIT) {   // %f accepts |value| strictly below 2^63
                throw this.badArgument(arg, spec);
            }
            negative = arg < 0n;
            digits   = ((negative ? -arg : arg) * scale).toString();
        } else {
            let q: bigint;
            let p: number;
            if(typeof arg === "number") {
                if(!Number.isFinite(arg)) {
                    throw this.badArgument(arg, spec);
                }
                negative = arg < 0;
                [q, p]   = this.numberToDouble(arg);
            } else if(typeof arg === "string") {
                const match = PLAIN_DECIMAL.exec(arg);
                if(match === null) {
                    throw this.badArgument(arg, spec);
                }
                negative = match[1] === "-";
                [q, p]   = this.decimalToDouble(BigInt(match[2] + (match[3] ?? "")), (match[3] ?? "").length);
            } else {
                throw this.badArgument(arg, spec);
            }
            const tooBig = p >= 0 ? q >= (FLOAT_LIMIT << BigInt(p)) : (q << BigInt(-p)) >= FLOAT_LIMIT;
            if(tooBig) {
                throw this.badArgument(arg, spec);
            }
            // round half up: floor(q * 10^decimals / 2^p + 1/2)
            const rounded = p > 0
                ? (2n * q * scale + (1n << BigInt(p))) >> BigInt(p + 1)
                : (q << BigInt(-p)) * scale;
            digits = rounded.toString();
        }
        const isZero = /^0+$/.test(digits);
        if(decimals > 0) {
            digits = digits.padStart(decimals + 1, "0");
            digits = `${digits.slice(0, -decimals)}.${digits.slice(-decimals)}`;
        }
        if(stripZeros && digits.includes(".")) {
            digits = digits.replace(/0+$/, "").replace(/\.$/, "");
        }
        return negative && !isZero ? `-${digits}` : digits;
    }

    private format(template: string, args: unknown[]): string {
        /**
         * Lexis' own printf: apply placeholders to an unescaped template.
         * Anything that is not a valid placeholder stays literal and uses
         * no argument. Arguments are never scanned again.
         * Raises:
         *      LexFormatError:
         *          If an argument is missing or invalid for its specifier.
         */
        let used = 0;
        return template.replace(
            PLACEHOLDER_RE,
            (
                match: string,
                percent: string | undefined,
                left: string | undefined,
                zero: string | undefined,
                width: string | undefined,
                precision: string | undefined,
                spec: string
            ): string => {
                // "%%" is a literal "%"
                if(percent !== undefined) {
                    return "%";
                }
                // Out of limits: stays literal and uses no argument
                const widthDigits     = (width ?? "").replace(/^0+/, "");
                const precisionDigits = (precision ?? "").replace(/^0+/, "");
                const hasPrecision    = precision !== undefined;
                const tooWide         = widthDigits.length > WIDTH_DIGITS || Number(widthDigits || 0) > MAX_WIDTH;
                const badPrecision    = hasPrecision && (
                    spec !== "f"
                    || precisionDigits.length > PRECISION_DIGITS
                    || Number(precisionDigits || 0) > MAX_PRECISION
                );
                if(tooWide || badPrecision) {
                    return match;
                }
                const decimals = hasPrecision ? Number(precisionDigits || 0) : DEFAULT_PRECISION;
                // The argument
                if(used >= args.length) {
                    throw new LexFormatError(`Missing argument for '%${spec}'`);
                }
                const arg = args[used++];
                let text: string;
                switch(spec) {
                    case "s":
                        if(typeof arg === "string") {
                            if(LONE_SURROGATE.test(arg)) {
                                throw this.badArgument(arg, spec);   // not valid UTF-8
                            }
                            text = arg;
                        } else if(typeof arg === "number") {
                            text = this.formatFloat(arg, decimals, true, spec);
                        } else if(typeof arg === "bigint") {
                            text = String(this.toInteger(arg, spec));
                        } else {
                            throw this.badArgument(arg, spec);
                        }
                        break;
                    case "f":
                        text = this.formatFloat(arg, decimals, !hasPrecision, spec);
                        break;
                    case "c": {
                        const codePoint = this.toInteger(arg, spec);
                        if(codePoint < 1n || codePoint > BigInt(MAX_CODE_POINT)
                                || (codePoint >= 0xD800n && codePoint <= 0xDFFFn)) {
                            throw this.badArgument(arg, spec);
                        }
                        text = String.fromCodePoint(Number(codePoint));
                        break;
                    }
                    case "x":
                    case "o": {
                        const integer = this.toInteger(arg, spec);
                        const radix   = spec === "x" ? 16 : 8;
                        text = (integer < 0n ? "-" : "") + (integer < 0n ? -integer : integer).toString(radix);
                        break;
                    }
                    default:   // d, i
                        text = String(this.toInteger(arg, spec));
                }
                // Width. Counts code points. "-" wins over "0", and "0" only applies to numbers
                const padding = Number(widthDigits || 0) - codePointLength(text);
                if(padding > 0) {
                    if(left !== undefined) {
                        text += " ".repeat(padding);
                    } else if(zero !== undefined && "dixof".includes(spec)) {
                        text = text.startsWith("-")
                            ? `-${"0".repeat(padding)}${text.slice(1)}`
                            : "0".repeat(padding) + text;
                    } else {
                        text = " ".repeat(padding) + text;
                    }
                }
                return text;
            }
        );
    }

    // --- Public API ----------------------------------------------------------

    public load(
        langDir: string,
        locale: string | null = null,
        fallbackLocale: string | null = "en",
        name: string | null = "main"
    ): void {
        /**
         * Load a .lex file from the given directory.
         * - If locale is not provided, it is detected from the environment.
         * - If the requested locale is not found, falls back to
         *   fallbackLocale (default "en").
         * Args:
         *      langDir: Directory containing .lex files.
         *      locale: Locale code. Auto-detected if null.
         *      fallbackLocale: Fallback locale code. Default is "en".
         *      name: Entry-file name for the directory layout. Default is "main".
         * Raises:
         *      LexFileNotFoundError:
         *          If no suitable file is found or an input is invalid.
         *      LexParseError:
         *          If the file is malformed.
         */
        const fallback = fallbackLocale ?? "en";
        const entry    = name ?? "main";
        const code     = locale ?? this.detectLocale();   // only null auto-detects; "" is invalid
        const filepath = this.resolveFilepath(langDir, code, fallback, entry);
        this.langDir        = langDir;
        this.fallbackLocale = fallback;
        this.name           = entry;
        this.filepath       = filepath;
        this.loadFile();
    }

    public get(key: string, ...args: unknown[]): string {
        /**
         * Get a translation by key with optional printf style format.
         * Args:
         *      key: Translation key
         *      ...args: Values for placeholders (%s, %d, etc.)
         * Returns:
         *      Formatted translation string
         * Raises:
         *      LexKeyNotFoundError:
         *          If key doesn't exist.
         *      LexFormatError:
         *          If an argument is missing or invalid for its specifier.
         */
        return this.format(this.cacheFetch(key), args);
    }

    public getOrDefault(key: string, defaultValue: string, ...args: unknown[]): string {
        /**
         * Get a translation or return a default value if key not found.
         * Args:
         *      key: Translation key
         *      defaultValue: Default value if key not found
         *      ...args: Values for placeholders
         * Returns:
         *      Formatted translation string or default
         */
        if(this.rawTranslations.has(key)) {
            return this.get(key, ...args);
        }
        return args.length > 0 ? this.format(defaultValue, args) : defaultValue;
    }

    public reload(
        locale: string | null = null,
        fallbackLocale: string | null = null,
        name: string | null = null
    ): void {
        /**
         * Reload translations, optionally switching locale.
         * Preserves the previous state on failure.
         * Args:
         *      locale: New locale code. null keeps the current one
         *          (it does NOT trigger auto-detection).
         *      fallbackLocale: New fallback locale code,
         *          or null to keep previous.
         *      name: New entry-file name, or null to keep the current one.
         */
        const previous = {
            langDir:           this.langDir,
            locale:            this.locale,
            fallbackLocale:    this.fallbackLocale,
            name:              this.name,
            filepath:          this.filepath,
            rawTranslations:   this.rawTranslations,
            cacheTranslations: this.cacheTranslations,
        };
        try {
            this.load(
                this.langDir,
                locale         ?? this.locale,
                fallbackLocale ?? this.fallbackLocale,
                name           ?? this.name
            );
        } catch(error) {
            // On failure: restore previous state and raise the error
            Object.assign(this, previous);
            throw error;
        }
    }

    public keys(): string[] {
        /**
         * Return all available translation keys.
         * Returns:
         *      Snapshot (array) of the keys at the time of the call.
         */
        return Array.from(this.rawTranslations.keys());
    }

    public has(key: string): boolean {
        // Check whether a key exists, without loading or formatting its value.
        return this.rawTranslations.has(key);
    }

    public len(): number {
        // Total number of loaded keys. An empty or comment-only file gives 0.
        return this.rawTranslations.size;
    }

    public size(): number {
        // Alias of len()
        return this.len();
    }

    public info(): LexisInfo {
        // Snapshot of the runtime state
        return {
            locale:         this.locale,
            fallbackLocale: this.fallbackLocale,
            langDir:        this.langDir,
            name:           this.name,
            filepath:       this.filepath,
            keys:           this.rawTranslations.size,
            cachedKeys:     this.cacheTranslations.size,
        };
    }

    public clear(): void {
        /**
         * Clear the cache of processed values.
         * Raw translations and all other state are preserved;
         * use reload() to reread the file.
         */
        this.cacheTranslations = new Map();
    }

    public getLocale(): string {
        // Returns the currently active locale code
        return this.locale;
    }

    public getFilepath(): string {
        // Returns the path to the currently loaded .lex file
        return this.filepath;
    }

    public toString(): string {
        // String representation for debugging
        const info = this.info();
        return (
            `Lexis(locale='${info.locale}', fallback_locale='${info.fallbackLocale}', ` +
            `lang_dir='${info.langDir}', name='${info.name}', filepath='${info.filepath}', ` +
            `keys=${info.keys}, cached_keys=${info.cachedKeys})`
        );
    }
}

// Demo: Load translations and run basic operations
const isMainModule = (): boolean => {
    try {
        return process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1];
    } catch {
        return false;
    }
};

if(isMainModule()) {
    try {
        const langDir = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "lang");
        const lex     = new Lexis(langDir);
        console.log(lex.get("welcome", "LEX"));
        console.log(lex.get("modules_available"));
        console.log(lex.get("error_file", "foo.txt"));
        console.log(lex.toString());
        lex.reload("en");
        console.log(lex.get("welcome", "Lexis"));
    } catch (error) {
        if(error instanceof LexFileNotFoundError
                || error instanceof LexKeyNotFoundError
                || error instanceof LexFormatError) {
            console.error(`[ERROR] ${(error as Error).message}`);
        } else {
            throw error;
        }
    }
}