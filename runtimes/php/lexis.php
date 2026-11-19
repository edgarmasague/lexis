<?php
    /**
     * Lexis.php LEXIS  Independent Translation Engine
     * Official PHP Runtime
     */

    class LexFileNotFoundError extends \Exception {
        // Raised when no .lex file is found for the requested locale.
    }

    class LexKeyNotFoundError extends \Exception {
        // Raised when a key is not found in the loaded .lex file.
    }

    class LexParseError extends \Exception {
        // Raised when .lex file contains malformed lines.
    }

    class LexFormatError extends \Exception {
        // Raised for placeholder errors: a missing argument, or an argument
        // that is invalid for its specifier (type, range, %c code point...).
    }

    class Lexis implements \Countable, \ArrayAccess {
        /**
         * Lexis Engine
         * Load .lex files and provides key based translation with
         * printf-style placeholder support.
         * Loading strategy:
         *      Eager - entire file is parsed and validated on load()
         *      Lazy  - escape sequences are processed only on first access.
         */

        // Official escape sequences
        private const ESCAPE_SEQUENCES =  [
            '\\\\' => '\\',
            '\\n'  => "\n",
            '\\t'  => "\t",
            '\\r'  => "\r",
            '\\b'  => "\x08",
            '\\v'  => "\x0B",
            '\\"'  => '"',
        ];

        // {language} or {language}_{REGION}. The D modifier makes "$" match only
        // at the very end, so a trailing newline can never slip through.
        private const LOCALE_PATTERN = '/^[A-Za-z0-9]+(?:[_-][A-Za-z0-9]+)?$/D';
        private const NAME_PATTERN   = '/^[A-Za-z0-9_-]+$/D';
 
        // Whitespace, as str.strip() sees it in the reference runtime.
        private const WS = '\x09-\x0D\x1C-\x20\x{85}\x{A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}';
 
        // %[-][0][width][.precision]specifier, or %%
        private const PLACEHOLDER = '/%(?:(%)|(-)?(0)?([0-9]+)?(?:\.([0-9]+))?([sdifxoc]))/A';
 
        // Placeholder limits
        private const MAX_WIDTH         = 1024;
        private const MAX_PRECISION     = 15;
        private const WIDTH_DIGITS      = 4;   // digits of MAX_WIDTH
        private const PRECISION_DIGITS  = 2;   // digits of MAX_PRECISION
        private const DEFAULT_PRECISION = 6;   // %f without a precision
 
        // Argument ranges
        private const FLOAT_LIMIT    = 9.2233720368547758E18;   // 2^63: %f accepts |value| below this
        private const MAX_CODE_POINT = 0x10FFFF;
 
        // Global state
        private string $langDir        = "";
        private string $fallbackLocale = "en";
        private string $locale         = "";
        private string $name           = "main";
        private string $filepath       = "";
        private array  $rawTranslations   = [];
        private array  $cacheTranslations = [];

        public function __construct(
            /**
             * Initializes the engine: resolves the .lex file path for
             * the given locale (falling back if needed) and loads it immediately.
             * Args:
             *      lang_dir: Directory containing .lex files.
             *      locale: Locale code. Auto-detected if None.
             *      fallback_locale: Fallback locale code. Default is "en".
             * Raises:
             *      LexFileNotFoundError:
             *          If no file found.
             *      LexParseError:
             *          On malformed lines or duplicates.
             */
            string  $langDir,
            ?string $locale         = null,
            ?string $fallbackLocale = "en",
            ?string $name           = "main"
        ) {
            $this->load(
                $langDir,
                $locale,
                $fallbackLocale,
                $name
            );
        }

        private function detectLocale(): string {
            /**
             * Safely detect system locale from environment.
             * Returns:
             *      locale code: "language" or "language_REGION" (e.g. 'en', 'es_VE').
             */
            $lang = getenv("LANG");
            if($lang === false) {
                $lang = "";
            }
            $lang = trim(preg_split('/[.@]/', $lang, 2)[0]);
            // Handle C, POSIX, or missing LANG
            if($lang === "" || $lang === "C" || $lang === "POSIX") {
                return "en";
            }
            $parts = explode("_", str_replace("-", "_", $lang));
            if(count($parts) > 2) {
                // zh_Hans_CN -> zh_CN: keep only language and region
                $parts = [$parts[0], $parts[count($parts) - 1]];
            }
            if(preg_match(self::LOCALE_PATTERN, implode("_", $parts)) !== 1) {
                return "en";   // a garbage LANG must not break loading
            }
            return $this->normalizeCode(implode("_", $parts));
        }
 
        private function normalizeCode(string $code): string {
            // es-ve -> es_VE: lowercase language, uppercase region
            $parts = explode("_", str_replace("-", "_", $code));
            return count($parts) === 1
                ? strtolower($parts[0])
                : strtolower($parts[0]) . "_" . strtoupper($parts[1]);
        }
 
        private function absolutePath(string $path): string {
            // Absolute path without touching the filesystem (no symlink resolution).
            $isAbsolute = str_starts_with($path, "/") || str_starts_with($path, "\\")
                || preg_match('~^[A-Za-z]:[\\\\/]~', $path) === 1;
            if(!$isAbsolute) {
                $path = getcwd() . DIRECTORY_SEPARATOR . $path;
            }
            $prefix = (str_starts_with($path, "/") || str_starts_with($path, "\\")) ? DIRECTORY_SEPARATOR : "";
            $parts  = [];
            foreach(preg_split('~[\\\\/]+~', $path) as $segment) {
                if($segment === "" || $segment === ".") {
                    continue;
                }
                if($segment === "..") {
                    array_pop($parts);
                    continue;
                }
                $parts[] = $segment;
            }
            return $prefix . implode(DIRECTORY_SEPARATOR, $parts);
        }
 
        private function resolveFilepath(
            string $langDir,
            string $locale,
            string $fallbackLocale,
            string $name
        ): string {
            /**
             * Resolve the .lex file path after validating and normalizing
             * the inputs.
             * Regional locale (es_VE):
             *      es_VE.lex, es_VE/{name}.lex, es.lex, es/{name}.lex
             * Language-only locale (es):
             *      es.lex, es/{name}.lex
             * The same steps are then applied to the fallback locale. Updates
             * $this->locale to the code of the file actually found.
             * Returns:
             *      Absolute path to the .lex file.
             * Raises:
             *      LexFileNotFoundError:
             *          If an input is invalid (before touching the filesystem)
             *          or no file is found.
             */
            $codes = [];
            foreach([$locale, $fallbackLocale] as $code) {
                if(preg_match(self::LOCALE_PATTERN, $code) !== 1) {
                    throw new LexFileNotFoundError("Invalid locale code: " . var_export($code, true));
                }
                $codes[] = $this->normalizeCode($code);
            }
            if(preg_match(self::NAME_PATTERN, $name) !== 1) {
                throw new LexFileNotFoundError("Invalid entry-file name: " . var_export($name, true));
            }
            // Every place to look, in order: es_VE, then es, then the fallback
            foreach($codes as $requested) {
                foreach(array_unique([$requested, explode("_", $requested)[0]]) as $code) {
                    $candidates = [
                        $langDir . DIRECTORY_SEPARATOR . "{$code}.lex",
                        $langDir . DIRECTORY_SEPARATOR . $code . DIRECTORY_SEPARATOR . "{$name}.lex",
                    ];
                    foreach($candidates as $path) {
                        if(is_file($path)) {
                            $this->locale = $code;
                            return $this->absolutePath($path);
                        }
                    }
                }
            }
            throw new LexFileNotFoundError(
                "No .lex file found for locale '{$codes[0]}' " .
                "(fallback '{$codes[1]}') in '{$langDir}'"
            );
        }
 
        protected function unescape(string $value): string {
            /**
             * Process escape sequences in values.
             * One left-to-right pass: a replacement is never processed again.
             * Args:
             *      value: Raw value string from .lex file.
             * Returns:
             *      Value with escape sequences converted.
             */
            return strtr($value, self::ESCAPE_SEQUENCES);
        }
 
        private function parseLine(string $rawLine, int $lineNum): ?array {
            /**
             * Parse a single line from .lex file.
             * Args:
             *      rawLine: Raw line string.
             *      lineNum: Line number for error reporting.
             * Returns:
             *      Array [key, value] or null if line skipped.
             * Raises:
             *      LexParseError:
             *          On malformed lines or duplicates.
             */
            $line = $rawLine;
            // Remove the line ending: an LF, and a CR directly before it
            if(str_ends_with($line, "\n")) {
                $line = substr($line, 0, -1);
                if(str_ends_with($line, "\r")) {
                    $line = substr($line, 0, -1);
                }
            }
            // Skip empty (whitespace-only) lines or comments
            if(preg_match('/^[' . self::WS . ']*(?:$|#)/Du', $line) === 1) {
                return null;
            }
            // Every valid entry must contain the separator
            if(!str_contains($line, "::")) {
                throw new LexParseError(
                    "Malformed line {$lineNum} in {$this->filepath}: missing '::' separator"
                );
            }
            // Split on first occurrence of separator
            [$key, $value] = explode("::", $line, 2);
            preg_match('/^[' . self::WS . ']*(.*[^' . self::WS . '])?/su', $key, $matches);
            $key = $matches[1] ?? "";
            // Key cannot be empty after trimming
            if($key === "") {
                throw new LexParseError(
                    "Malformed line {$lineNum} in {$this->filepath}: empty key"
                );
            }
            // Duplicate keys are not allowed
            if(array_key_exists($key, $this->rawTranslations)) {
                throw new LexParseError(
                    "Duplicate key '{$key}' at line {$lineNum} in {$this->filepath}"
                );
            }
            // Left-trim the value only: trailing whitespace is kept
            preg_match('/^[' . self::WS . ']*/u', $value, $matches);
            return [$key, substr($value, strlen($matches[0]))];
        }
 
        private function loadFile(): void {
            /**
             * Load and parse the entire .lex file into memory.
             * Raises:
             *      LexFileNotFoundError:
             *          If file disappears during load.
             *      LexParseError:
             *          If the file is not valid UTF-8 or is malformed.
             */
            $this->rawTranslations   = [];
            $this->cacheTranslations = [];
            $data = @file_get_contents($this->filepath);
            if($data === false) {
                // Race condition: file deleted after resolve but before open
                throw new LexFileNotFoundError(
                    "File not found: {$this->filepath}"
                );
            }
            // The u modifier rejects overlong forms, surrogates and values above U+10FFFF
            if(preg_match('//u', $data) !== 1) {
                throw new LexParseError("Invalid UTF-8 in {$this->filepath}");
            }
            // A leading BOM (and only a leading one) is removed
            if(str_starts_with($data, "\xEF\xBB\xBF")) {
                $data = substr($data, 3);
            }
            // One line with its LF, or a last line without one. A lone CR is content.
            $length  = strlen($data);
            $offset  = 0;
            $lineNum = 0;
            while($offset < $length) {
                $newline = strpos($data, "\n", $offset);
                if($newline === false) {
                    $rawLine = substr($data, $offset);
                    $offset  = $length;
                } else {
                    $rawLine = substr($data, $offset, $newline - $offset + 1);
                    $offset  = $newline + 1;
                }
                $lineNum++;
                $result = $this->parseLine($rawLine, $lineNum);
                if($result !== null) {
                    $this->rawTranslations[$result[0]] = $result[1];
                }
            }
        }
 
        private function cacheFetch(string $key): string {
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
            if(!array_key_exists($key, $this->rawTranslations)) {
                throw new LexKeyNotFoundError("Key not found: '{$key}'");
            }
            if(!array_key_exists($key, $this->cacheTranslations)) {
                $this->cacheTranslations[$key] = $this->unescape($this->rawTranslations[$key]);
            }
            return $this->cacheTranslations[$key];
        }
 
        // --- Lexis' own printf ---------------------------------------------------
 
        private function badArgument(mixed $arg, string $spec): LexFormatError {
            return new LexFormatError(
                "Invalid argument " . var_export($arg, true) . " for '%{$spec}'"
            );
        }
 
        private function codePointLength(string $text): int {
            // Code points, not bytes: every byte except UTF-8 continuation bytes
            if(preg_match('/[\x80-\xFF]/', $text) !== 1) {
                return strlen($text);
            }
            return strlen($text) - preg_match_all('/[\x80-\xBF]/', $text);
        }
 
        private function encodeUtf8(int $codePoint): string {
            // Encode one code point (already validated)
            if($codePoint < 0x80) {
                return chr($codePoint);
            }
            if($codePoint < 0x800) {
                return chr(0xC0 | ($codePoint >> 6)) . chr(0x80 | ($codePoint & 63));
            }
            if($codePoint < 0x10000) {
                return chr(0xE0 | ($codePoint >> 12))
                    . chr(0x80 | (($codePoint >> 6) & 63))
                    . chr(0x80 | ($codePoint & 63));
            }
            return chr(0xF0 | ($codePoint >> 18))
                . chr(0x80 | (($codePoint >> 12) & 63))
                . chr(0x80 | (($codePoint >> 6) & 63))
                . chr(0x80 | ($codePoint & 63));
        }
 
        private function toInteger(mixed $arg, string $spec): int {
            // A signed 64-bit integer from an int, an integral float or a plain integer string
            if(is_int($arg)) {
                return $arg;
            }
            if(is_float($arg)) {
                if(is_finite($arg) && $arg == floor($arg)
                        && $arg >= -self::FLOAT_LIMIT && $arg < self::FLOAT_LIMIT) {
                    return (int) $arg;
                }
                throw $this->badArgument($arg, $spec);
            }
            if(is_string($arg) && preg_match('/^-?[0-9]+$/D', $arg) === 1) {
                $negative = $arg[0] === "-";
                $digits   = ltrim($negative ? substr($arg, 1) : $arg, "0");
                if($digits === "") {
                    return 0;
                }
                $limit = $negative ? "9223372036854775808" : "9223372036854775807";
                if(strlen($digits) < 19 || (strlen($digits) === 19 && strcmp($digits, $limit) <= 0)) {
                    return (int) (($negative ? "-" : "") . $digits);
                }
            }
            throw $this->badArgument($arg, $spec);
        }
 
        private function fixedPoint(float $magnitude, int $decimals): string {
            /**
             * Exact decimal text of a finite double (below 2^63) rounded half up
             * to the given decimals. The double is split into mantissa and exponent;
             * the value is mantissa * 5^p / 10^p, so its digits come out exactly.
             */
            $bits     = unpack('J', pack('E', $magnitude))[1];
            $exponent = ($bits >> 52) & 0x7FF;
            $mantissa = $bits & 0xFFFFFFFFFFFFF;
            if($exponent === 0) {
                $m = $mantissa;
                $e = -1074;
            } else {
                $m = $mantissa | (1 << 52);
                $e = $exponent - 1075;
            }
            if($m === 0) {
                $m = 0;
                $e = 0;
            }
            while($e < 0 && ($m & 1) === 0) {
                $m >>= 1;
                $e++;
            }
            if($e >= 0) {
                $intPart = (string) ($m << $e);
                $frac    = "";
            } else {
                $p     = -$e;
                $limbs = [$m % 1000000000, intdiv($m, 1000000000)];   // base 10^9, least significant first
                for($left = $p; $left > 0; $left -= 13) {
                    $multiplier = 5 ** min($left, 13);
                    $carry      = 0;
                    foreach($limbs as $i => $limb) {
                        $current   = $limb * $multiplier + $carry;
                        $limbs[$i] = $current % 1000000000;
                        $carry     = intdiv($current, 1000000000);
                    }
                    while($carry > 0) {
                        $limbs[] = $carry % 1000000000;
                        $carry   = intdiv($carry, 1000000000);
                    }
                }
                while(count($limbs) > 1 && $limbs[count($limbs) - 1] === 0) {
                    array_pop($limbs);   // drop leading zero limbs
                }
                $digits = (string) array_pop($limbs);
                while($limbs !== []) {
                    $digits .= str_pad((string) array_pop($limbs), 9, "0", STR_PAD_LEFT);
                }
                if(strlen($digits) <= $p) {
                    $digits = str_repeat("0", $p - strlen($digits) + 1) . $digits;
                }
                $intPart = substr($digits, 0, strlen($digits) - $p);
                $frac    = substr($digits, strlen($digits) - $p);
            }
            if(strlen($frac) > $decimals) {
                $roundUp = $frac[$decimals] >= "5";
                $frac    = substr($frac, 0, $decimals);
                if($roundUp) {
                    $joined = $intPart . $frac;
                    $i      = strlen($joined) - 1;
                    while($i >= 0 && $joined[$i] === "9") {
                        $joined[$i] = "0";
                        $i--;
                    }
                    $joined  = $i < 0 ? "1" . $joined : substr_replace($joined, (string) ((int) $joined[$i] + 1), $i, 1);
                    $intPart = substr($joined, 0, strlen($joined) - $decimals);
                    $frac    = substr($joined, strlen($joined) - $decimals);
                }
            } else {
                $frac = str_pad($frac, $decimals, "0");
            }
            return $decimals > 0 ? "{$intPart}.{$frac}" : $intPart;
        }
 
        private function formatFloat(mixed $arg, int $decimals, bool $stripZeros, string $spec): string {
            // Text for %f, and %s with a float
            if(is_int($arg)) {
                if($arg === PHP_INT_MIN) {   // %f accepts |value| strictly below 2^63
                    throw $this->badArgument($arg, $spec);
                }
                $negative = $arg < 0;
                $text = ltrim((string) $arg, "-") . ($decimals > 0 ? "." . str_repeat("0", $decimals) : "");
            } else {
                if(is_string($arg)) {
                    if(preg_match('/^-?[0-9]+(?:\.[0-9]+)?$/D', $arg) !== 1) {
                        throw $this->badArgument($arg, $spec);
                    }
                    $number = (float) $arg;       // nearest double, as the reference runtime does
                } elseif(is_float($arg)) {
                    $number = $arg;
                } else {
                    throw $this->badArgument($arg, $spec);
                }
                if(is_nan($number) || is_infinite($number) || abs($number) >= self::FLOAT_LIMIT) {
                    throw $this->badArgument($arg, $spec);
                }
                $negative = $number < 0;
                $text     = $this->fixedPoint(abs($number), $decimals);
            }
            if($stripZeros && str_contains($text, ".")) {
                $text = rtrim(rtrim($text, "0"), ".");
            }
            if($negative && trim($text, "0.") !== "") {
                $text = "-" . $text;
            }
            return $text;
        }
 
        private function format(string $template, array $args): string {
            /**
             * Lexis' own printf: apply placeholders to an unescaped template.
             * Anything that is not a valid placeholder stays literal and uses
             * no argument. Arguments are never scanned again.
             * Raises:
             *      LexFormatError:
             *          If an argument is missing or invalid for its specifier.
             */
            $args   = array_values($args);
            $count  = count($args);
            $out    = [];
            $cursor = 0;
            $used   = 0;
            while(true) {
                // Copy everything up to the next "%"
                $start = strpos($template, "%", $cursor);
                if($start === false) {
                    $out[] = substr($template, $cursor);
                    return implode("", $out);
                }
                $out[] = substr($template, $cursor, $start - $cursor);
                // "%%", or a "%" that starts nothing valid, is a literal "%"
                if(preg_match(self::PLACEHOLDER, $template, $m, PREG_UNMATCHED_AS_NULL, $start) !== 1) {
                    $out[]  = "%";
                    $cursor = $start + 1;
                    continue;
                }
                $cursor = $start + strlen($m[0]);
                if($m[1] !== null) {
                    $out[] = "%";
                    continue;
                }
                // Out of limits: stays literal and uses no argument
                $spec         = $m[6];
                $hasPrecision = $m[5] !== null;
                $widthDigits  = ltrim($m[4] ?? "", "0");
                $precDigits   = ltrim($m[5] ?? "", "0");
                $tooWide      = strlen($widthDigits) > self::WIDTH_DIGITS || (int) $widthDigits > self::MAX_WIDTH;
                $badPrecision = $hasPrecision && (
                    $spec !== "f"
                    || strlen($precDigits) > self::PRECISION_DIGITS
                    || (int) $precDigits > self::MAX_PRECISION
                );
                if($tooWide || $badPrecision) {
                    $out[] = $m[0];
                    continue;
                }
                $width    = (int) $widthDigits;
                $decimals = $hasPrecision ? (int) $precDigits : self::DEFAULT_PRECISION;
                // The argument
                if($used >= $count) {
                    throw new LexFormatError("Missing argument for '%{$spec}'");
                }
                $arg = $args[$used++];
                if(is_bool($arg) || $arg === null) {
                    throw $this->badArgument($arg, $spec);   // bool and null are never valid
                }
                switch($spec) {
                    case "s":
                        if(is_string($arg)) {
                            if(preg_match('//u', $arg) !== 1) {
                                throw $this->badArgument($arg, $spec);   // not valid UTF-8
                            }
                            $text = $arg;
                        } elseif(is_float($arg)) {
                            $text = $this->formatFloat($arg, $decimals, true, $spec);
                        } elseif(is_int($arg)) {
                            $text = (string) $arg;
                        } else {
                            throw $this->badArgument($arg, $spec);
                        }
                        break;
                    case "f":
                        $text = $this->formatFloat($arg, $decimals, !$hasPrecision, $spec);
                        break;
                    case "c":
                        $number = $this->toInteger($arg, $spec);
                        if($number < 1 || $number > self::MAX_CODE_POINT || ($number >= 0xD800 && $number <= 0xDFFF)) {
                            throw $this->badArgument($arg, $spec);
                        }
                        $text = $this->encodeUtf8($number);
                        break;
                    case "x":
                    case "o":
                        $number = $this->toInteger($arg, $spec);
                        if($number === PHP_INT_MIN) {   // its magnitude, 2^63, does not fit an int
                            $text = $spec === "x" ? "-8000000000000000" : "-1000000000000000000000";
                        } else {
                            $text = ($number < 0 ? "-" : "") . ($spec === "x" ? dechex(abs($number)) : decoct(abs($number)));
                        }
                        break;
                    default:   // d, i
                        $text = (string) $this->toInteger($arg, $spec);
                }
                // Width. Counts code points. "-" wins over "0", and "0" only applies to numbers
                $padding = $width - $this->codePointLength($text);
                if($padding > 0) {
                    if($m[2] !== null) {
                        $text .= str_repeat(" ", $padding);
                    } elseif($m[3] !== null && strpos("dixof", $spec) !== false) {
                        $text = ($text[0] === "-")
                            ? "-" . str_repeat("0", $padding) . substr($text, 1)
                            : str_repeat("0", $padding) . $text;
                    } else {
                        $text = str_repeat(" ", $padding) . $text;
                    }
                }
                $out[] = $text;
            }
        }
 
        // --- Public API ----------------------------------------------------------
 
        public function load(
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
            string  $langDir,
            ?string $locale         = null,
            ?string $fallbackLocale = "en",
            ?string $name           = "main"
        ): void {
            $fallbackLocale = $fallbackLocale ?? "en";
            $name           = $name ?? "main";
            $locale         = $locale ?? $this->detectLocale();   // only null auto-detects; "" is invalid
            $filepath       = $this->resolveFilepath($langDir, $locale, $fallbackLocale, $name);
            $this->langDir        = $langDir;
            $this->fallbackLocale = $fallbackLocale;
            $this->name           = $name;
            $this->filepath       = $filepath;
            $this->loadFile();
        }
 
        public function get(string $key, mixed ...$args): string {
            /**
             * Get a translation by key with optional printf style format.
             * Args:
             *      key: Translation key
             *      args: Values for placeholders (%s, %d, etc.)
             * Returns:
             *      Formatted translation string
             * Raises:
             *      LexKeyNotFoundError:
             *          If key doesn't exist.
             *      LexFormatError:
             *          If an argument is missing or invalid for its specifier.
             */
            return $this->format($this->cacheFetch($key), $args);
        }
 
        public function getOrDefault(string $key, string $default, mixed ...$args): string {
            /**
             * Get a translation or return a default value if key not found.
             * Args:
             *      key: Translation key
             *      default: Default value if key not found
             *      args: Values for placeholders
             * Returns:
             *      Formatted translation string or default
             */
            if(array_key_exists($key, $this->rawTranslations)) {
                return $this->get($key, ...$args);
            }
            return $args !== [] ? $this->format($default, $args) : $default;
        }
 
        public function reload(
            /**
             * Reload translations, optionally switching locale.
             * Preserves the previous state on failure.
             * Args:
             *      locale: New locale code. null keeps the current one
             *          (it does NOT trigger auto-detection).
             *      fallbackLocale: New fallback locale code, or null to keep previous.
             *      name: New entry-file name, or null to keep the current one.
             */
            ?string $locale         = null,
            ?string $fallbackLocale = null,
            ?string $name           = null
        ): void {
            $previous = [
                $this->langDir, $this->locale, $this->fallbackLocale, $this->name,
                $this->filepath, $this->rawTranslations, $this->cacheTranslations,
            ];
            try {
                $this->load(
                    $this->langDir,
                    $locale         ?? $this->locale,
                    $fallbackLocale ?? $this->fallbackLocale,
                    $name           ?? $this->name
                );
            } catch(\Throwable $error) {
                // On failure: restore previous state and raise the error
                [
                    $this->langDir, $this->locale, $this->fallbackLocale, $this->name,
                    $this->filepath, $this->rawTranslations, $this->cacheTranslations,
                ] = $previous;
                throw $error;
            }
        }
 
        public function has(string $key): bool {
            /**
             * Return whether key exists in the loaded translations.
             * Never raises and never touches the cache.
             */
            return array_key_exists($key, $this->rawTranslations);
        }
 
        public function keys(): array {
            /**
             * Return all available translation keys.
             * Returns:
             *      Snapshot (array) of the keys at the time of the call.
             */
            return array_map('strval', array_keys($this->rawTranslations));
        }
 
        public function len(): int {
            /**
             * Return the number of loaded keys.
             * An empty or comment-only file gives 0.
             */
            return count($this->rawTranslations);
        }
 
        public function info(): array {
            /**
             * Return a snapshot of the runtime state.
             * Returns:
             *      Array with locale, fallback_locale, lang_dir, name, filepath,
             *      keys and cached_keys.
             */
            return [
                "locale"          => $this->locale,
                "fallback_locale" => $this->fallbackLocale,
                "lang_dir"        => $this->langDir,
                "name"            => $this->name,
                "filepath"        => $this->filepath,
                "keys"            => count($this->rawTranslations),
                "cached_keys"     => count($this->cacheTranslations),
            ];
        }
 
        public function clear(): void {
            /**
             * Clear the cache of processed values.
             * Raw translations and all other state are preserved;
             * use reload() to reread the file.
             */
            $this->cacheTranslations = [];
        }
 
        public function getLocale(): string {
            // Returns the currently active locale code.
            return $this->locale;
        }
 
        public function getFilepath(): string {
            // Returns the path to the currently loaded .lex file.
            return $this->filepath;
        }
 
        public function count(): int {
            // count($lex) to count loaded keys
            return $this->len();
        }
 
        public function __toString(): string {
            // String representation for debugging
            $info = $this->info();
            return "Lexis(locale='{$info['locale']}', fallback_locale='{$info['fallback_locale']}', "
                . "lang_dir='{$info['lang_dir']}', name='{$info['name']}', filepath='{$info['filepath']}', "
                . "keys={$info['keys']}, cached_keys={$info['cached_keys']})";
        }
 
        public function offsetExists(mixed $offset): bool {
            // isset($lex["key"]) membership testing, without loading or formatting
            return is_string($offset) && $this->has($offset);
        }
 
        public function offsetGet(mixed $offset): string {
            // $lex["key"] is a read shorthand for $lex->get("key")
            if(!is_string($offset)) {
                throw new LexKeyNotFoundError("Key not found: " . var_export($offset, true));
            }
            return $this->get($offset);
        }
 
        public function offsetSet(mixed $offset, mixed $value): void {
            // Lexis translations are read-only.
            throw new \LogicException(
                "Lexis translations are read-only; \$lex[...] = ... is not supported."
            );
        }
 
        public function offsetUnset(mixed $offset): void {
            // Lexis translations are read-only.
            throw new \LogicException(
                "Lexis translations are read-only; unset(\$lex[...]) is not supported."
            );
        }
    }
