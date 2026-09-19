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

// Official escape sequences
const ESCAPE_SEQUENCES: Record<string, string> = {
    '\\': '\\',
    'n':  "\n",
    't':  "\t",
    'r':  "\r",
    'b':  "\b",
    'v':  "\v",
    '"':  '"',
}

const SPECIFIER_RE = /%([-0]*)(\d+)?(?:\.(\d+))?([sdfxoc%])/g;

export class Lexis {
    /**
     * Lexis Engine
     * Load .lex files and provides key based translation with
     * printf-style placeholder support.
     * Loading strategy:
     *      Eager - entire file is parsed and validated on load()
     *      Lazy  - escape sequences are processed only on first access.
     */
    // Global state
    private langDir                                = "";
    private locale                                 = "";
    private fallbackLocale                         = "en";
    private filepath                               = "";
    private rawTranslations: Map<string, string>   = new Map();
    private cacheTranslations: Map<string, string> = new Map();
    constructor(
        /**
         * Initializes the engine: resolves the .lex file path for
         * the given locale (falling back if needed) and loads it immediately.
         * Args:
         *      lang_dir: Directory containing .lex files.
         *      locale: Locale code. Auto-detected if None.
         *      fallback_locale: Fallback locale code. Default is "en".
         */
        langDir: string,
        locale: string | null = null,
        fallbackLocale = "en"
    ) {
        this.load(langDir, locale, fallbackLocale);
    }

    private detectLocale(): string {
        /** 
         * Safely detect system locale from environment.
         * Returns:
         *      locale code (e.g. 'en', 'es').
         */
        const lang = process.env.LANG;
        if(!lang || lang === "C" || lang === "POSIX") {
            return "en";
        }
        const withoutEncoding = lang.split(".")[0];
        const normalized = withoutEncoding.replace(/-/g, "_");
        return normalized.split("_")[0].toLowerCase();
    }

    private resolveFilepath(): string {
        /**
         * Resolve the .lex file path with fallback to en.lex.
         * If fallback is used, updates locale state to match fallback.
         * Returns:
         *      Absolute path to the .lex file.
         * Raises:
         *      LexFileNotFoundError:
         *          If no file found.
         */
        const filepath = path.join(this.langDir, `${this.locale}.lex`);
        if(fs.existsSync(filepath) && fs.statSync(filepath).isFile()) {
            return filepath;
        }
        // Fallback to English if locale file missing
        const fallbackfilepath = path.join(this.langDir, `${this.fallbackLocale}.lex`);
        if(fs.existsSync(fallbackfilepath) && fs.statSync(fallbackfilepath).isFile()) {
            this.locale = this.fallbackLocale;
            return fallbackfilepath;
        }
        throw new LexFileNotFoundError(
            `No .lex file found for locale '${this.locale}' ` +
                `(fallback '${this.fallbackLocale}') in '${this.langDir}'`
        );
    }

    protected unescape(value: string): string {
        /**
         * Process escape sequences in values.
         * Args:
         *      value: Raw value string from .lex file.
         * Returns:
         *      Value with escape sequences converted.
         */
        let result = "";
        const len = value.length;
        let i = 0;
        while(i<len) {
            const char = value[i];
            if(char === "\\" && i + 1 < len) {
                const next = value[i + 1];
                if(Object.prototype.hasOwnProperty.call(ESCAPE_SEQUENCES, next)) {
                    result += ESCAPE_SEQUENCES[next];
                    i += 2;
                    continue;
                }
                //
                result += char;
                i += 1;
                continue;
            }
            result += char;
            i += 1;
        }
        return result;
    }

    private parseLine(
        rawLine: string,
        lineNum: number
    ): [string, string] | null {
        /**
         * Parse a single line from .lex file.
         * Args:
         *      raw_line: Raw line string.
         *      line_num: Line number for error reporting.
         * Returns:
         *      Tuple of (key, value) or None if line skipped.
         * Raises:
         *      LexParseError:
         *          On malformed lines or duplicates.
         */
        const line = rawLine.replace(/\r$/, "");
        const trimmedStart = line.replace(/^\s+/, "");
        // Skip empty lines or comments
        if(trimmedStart === "" || trimmedStart.startsWith("#")) {
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
        const rawKey   = line.slice(0, separatorIndex);
        const rawValue = line.slice(separatorIndex + 2);
        const key      = rawKey.trim();
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
        const value = rawValue.replace(/^\s+/, "");
        return [key, value];
    }

    private loadFile(): void {
        /**
         * Load and parse the entire .lex file into memory.
         * Raises:
         *      LexFileNotFoundError:
         *          If file disappears during load.
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
            content = new TextDecoder("utf-8", { fatal: true}).decode(buffer);
        } catch {
            throw new LexParseError(
                `Invalid UTF-8 sequence in ${this.filepath}`
            );
        }
        //
        const lines = content.length === 0 ? [] : content.split("\n");
        if(lines.length > 0 && lines[lines.length -1] === "" && content.endsWith("\n")) {
            lines.pop();
        }
        lines.forEach((rawLine, index) => {
            const result = this.parseLine(rawLine, index + 1);
            if(result !== null) {
                const [key, value] = result;
                this.rawTranslations.set(key, value);
            }
        });
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

    private parseInteger(arg: unknown, typeName: string): number {
        /**
         * Coerces a placeholder argument into an integer for %d, %x, %o and % c.
         * Args:
         *      arg: The raw argument passed to get()/getOrDefault().
         *      typeName: Human-readable type name used only in the error message(e.g. "hex", "octal", "char").
         * Returns:
         *      The argument truncated to an integer.
         * Raises:
         *      LexKeyNotFoundError:
         *          If the argument can't be coerced to a number.
         */
        const num = Math.trunc(Number(arg));
        if(Number.isNaN(num)) {
            throw new LexKeyNotFoundError(
                `Format error: invalid ${typeName} argument '${arg}'`
            );
        }
        return num;
    }

    private vsprintf(value: string, args: unknown[]): string {
        /**
         * Applies printf-style formatting to a processed unescaped value.
         * Supports %s, %d, %f, %x, %o, %c and %%, with optional width, zero-pad ("0"),
         *  left-align ("-") and precision (e.g. %10s, %04d, %.2f).
         * Args:
         *      value: The unescaped translation value containing specifiers.
         *      args: Positional value to substitute into the specifiers, consumed in orfer as each specifier is encountered.
         * Returns:
         *      The formatted string.
         * Raises:
         *      LexKeyNotFoundError:
         *          If there are more placeholders than args or if an argument can't be coerced to the tpe its specifier expects.
         */
        let argIndex = 0;
        const pad = (str: string, flags: string, width?: string): string => {
            const w = width ? parseInt(width, 10) : 0;
            if(str.length >= w) return str;
            const padChar = flags.includes("0") && !flags.includes("-") ? "0" : " ";
            return flags.includes("-") ? str.padEnd(w, " ") : str.padStart(w, padChar);
        };
        return value.replace(
            SPECIFIER_RE,
            (_match, flags: string, width: string | undefined, precision: string | undefined, conv: string) => {
                if(conv === "%") {
                    return "%";
                }
                if(argIndex >= args.length) {
                    throw new LexKeyNotFoundError(
                        "Format error: not enough arguments for placeholders"
                    );
                }
                const arg = args[argIndex++];
                switch(conv) {
                    case "s":
                        return pad(String(arg), flags, width);
                    case "d": {
                        return pad(String(this.parseInteger(arg, "integer")), flags, width);
                    }
                    case "f": {
                        const num = Number(arg);
                        if(Number.isNaN(num)) {
                            throw new LexKeyNotFoundError(
                                `Format error: invalid float argument '${arg}'`
                            );
                        }
                        const decimals = precision !== undefined ? parseInt(precision, 10) : 6;
                        return pad(num.toFixed(decimals), flags, width);
                    }
                    case "x": {
                        return pad(this.parseInteger(arg, "hex").toString(16), flags, width);
                    }
                    case "o": {
                        return pad(this.parseInteger(arg, "octal").toString(8), flags, width);
                    }
                    case "c": {
                        return pad(String.fromCodePoint(this.parseInteger(arg, "char")), flags, width);
                    }
                    default:
                        return _match;
                }
            }
        );
    }

    public load(langDir: string, locale: string | null = null, fallbackLocale = "en"): void {
        /**
         * Load .lex file from given directory.
         * Alias for re-initializing a new lang_dir and locale.
         * Args:
         *      lang_dir: Directory containing .lex files.
         *      locale: Locale code. Auto-detected if None.
         *      fallback_locale: Fallback locale code. Default is "en".
         */
        this.langDir = langDir;
        this.fallbackLocale = fallbackLocale;
        this.locale = locale ?? this.detectLocale();
        this.filepath = this.resolveFilepath();
        this.loadFile();
    }

    public get(key: string, ...args: unknown[]): string {
        /**
         * Get a translation by key with optional printf style format.
         * Args:
         *      key: Translation key
         *      *args: Values for placeholders (%s, %d, etc.)
         * Returns:
         *      Formatted translation string
         * Raises:
         *      LexKeyNotFoundError:
         *          If key doesn't exist.
         */
        const value = this.cacheFetch(key);
        // Apply printf-style formatting if arguments provided
        if(args.length === 0) {
            return value.replace(/%%/g, "%");
        }
        return this.vsprintf(value, args);
    }

    public getOrDefault(key: string, defaultValue: string, ...args: unknown[]): string {
        /**
         * Get a translation or return a default value if key not found.
         * Args:
         *      key: Translation key
         *      default: Default value if key not found
         *      *args: Values for placeholders
         * Returns:
         *      Formatted translation string or default
         */
        try {
            return this.get(key, ...args);
        } catch(error) {
            // Format default with args if provided
            if(!(error instanceof LexKeyNotFoundError)) {
                throw error;
            }
            if(args.length === 0) {
                return defaultValue.replace(/%%/g, "%");
            }
            try {
                return this.vsprintf(defaultValue, args);
            } catch {
                return defaultValue;
            }
        }
    }

    public reload(locale: string | null = null, fallbackLocale: string | null = null): void {
        /**
         * Reload translations with a new or auto-detected locale.
         * Args:
         *      locale: New locale code. Auto-detected if None.
         *      fallback_locale: New fallback locale code,
         *          or None to keep previous.
         */
        const newLocale   = locale ?? this.detectLocale();
        const newFallback = fallbackLocale ?? this.fallbackLocale;
        // Save current state for rollback on failure
        const oldLangDir  = this.langDir;
        const oldLocale   = this.locale;
        const oldFallback = this.fallbackLocale;
        const oldFilepath = this.filepath;
        const oldRaw      = new Map(this.rawTranslations);
        const oldCache    = new Map(this.cacheTranslations);
        try {
            this.locale         = newLocale;
            this.fallbackLocale = newFallback;
            this.filepath       = this.resolveFilepath();
            this.loadFile();
        } catch (error) {
            // Restore previous state if anything fails
            this.langDir           = oldLangDir;
            this.locale            = oldLocale;
            this.fallbackLocale    = oldFallback;
            this.filepath          = oldFilepath;
            this.rawTranslations   = oldRaw;
            this.cacheTranslations = oldCache;
            throw error;
        }
    }

    public keys(): string[] {
        /**
         * Return all available translation keys.
         * Returns:
         *      Tuple of keys strings.
         */
        return Array.from(this.rawTranslations.keys());
    }

    public has(key: string): boolean {
        // Check whether a key exists, without loading or formatting its value.
        return this.rawTranslations.has(key);
    }

    public getLocale(): string {
        // Returns the currently active locale code
        return this.locale;
    }

    public getFilepath(): string {
        // Returns the path to the currently loaded .lex file
        return this.filepath;
    }

    public size(): number {
        // Total number of loaded keys
        return this.rawTranslations.size;
    }

    public toString(): string {
        // String representation for debugging
        return (
            `Lexis(locale=${this.locale}, ` +
            `fallback=${this.fallbackLocale}, ` +
            `keys=${this.rawTranslations.size}, ` +
            `cached_keys=${this.cacheTranslations.size}, ` +
            `filepath=${this.filepath})`
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
        if(error instanceof LexFileNotFoundError || error instanceof LexKeyNotFoundError) {
            console.error(`[ERROR] ${(error as Error).message}`);
        } else {
            throw error;
        }
    }
}