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

        // Global state
        private string $langDir;
        private string $fallbackLocale;
        private string $locale;
        private string $filepath;
        private array  $rawTranslations   =[];
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
            string  $fallbackLocale = "en"
        ) {
            $this->langDir        = $langDir;
            $this->fallbackLocale = $fallbackLocale;
            $this->locale         = $locale ?? $this->detectLocale();
            $this->filepath       = $this->resolveFilepath();
            $this->loadFile();
        }

        private function detectLocale(): string {
            /** 
             * Safely detect system locale from environment.
             * Returns:
             *      locale code (e.g. 'en', 'es').
             */
            $lang =getenv("LANG");
                if ($lang === false || $lang === "" || $lang === "C" || $lang === "POSIX") {
                    return "en";
                }
            $lang = explode('.', $lang)[0];
            $lang = str_replace('-', '_', $lang);
            return strtolower(explode("_", $lang)[0]);
        }

        private function resolveFilepath(): string {
            /**
             * Resolve the .lex file path with fallback to en.lex.
             * If fallback is used, updates locale state to match fallback.
             * Returns:
             *      Absolute path to the .lex file.
             * Raises:
             *      LexFileNotFoundError:
             *          If no file found.
             */
            $filepath = $this->langDir . DIRECTORY_SEPARATOR . "{$this->locale}.lex";
            if(is_file($filepath)) {
                return $filepath;
            }
            // Fallback to English if locale file missing
            $fallback = $this->langDir . DIRECTORY_SEPARATOR . "{$this->fallbackLocale}.lex";
            if(is_file($fallback)) {
                $this->locale = $this->fallbackLocale;
                return $fallback;
            }
            throw new LexFileNotFoundError(
                "No .lex file found for locale '{$this->locale}'" .
                "(fallback '{$this->fallbackLocale}') in '{$this->langDir}'"
            );
        }

        protected function unescape(string $value): string {
            /**
             * Process escape sequences in values.
             * Args:
             *      value: Raw value string from .lex file.
             * Returns:
             *      Value with escape sequences converted.
             */
            $result = "";
            $len    = strlen($value);
            $i      = 0;
            while($i < $len) {
                if($value[$i] === "\\" && $i + 1 < $len) {
                    $seq = substr($value, $i, 2);
                    if(isset(self::ESCAPE_SEQUENCES[$seq])) {
                        $result .= self::ESCAPE_SEQUENCES[$seq];
                        $i      += 2;
                        continue;
                    }
                }
                $result .= $value[$i];
                $i++;
            }
            return $result;
        }

        private function parseLine(string $rawLine, int $lineNum): ?array {
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
            $line = rtrim($rawLine, "\r\n");
            // Skip empty lines or comments
            if(trim($line) === "" || str_starts_with(ltrim($line), "#")) {
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
            $key = trim($key);
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
            return [$key, ltrim($value)];
        }

        private function loadFile(): void {
            /**
             * Load and parse the entire .lex file into memory.
             * Raises:
             *      LexFileNotFoundError:
             *          If file disappears during load.
             */
            $this->rawTranslations   = [];
            $this->cacheTranslations = [];
            $handle = @fopen($this->filepath, "r");
            if($handle === false) {
                // Race condition: file deleted after resolve but before open
                throw new LexFileNotFoundError(
                    "File not found: {$this->filepath}"
                );
            }
            $lineNum = 0;
            while(($rawLine = fgets($handle)) !== false) {
                $lineNum++;
                if(!mb_check_encoding($rawLine, "utf-8")) {
                    fclose($handle);
                    throw new LexParseError(
                        "Invalid UTF-8 sequence at line {$lineNum} in {$this->filepath}"
                    );
                }
                $result = $this->parseLine($rawLine, $lineNum);
                if($result !== null) {
                    [$key, $value] = $result;
                    $this->rawTranslations[$key] = $value;
                }
            }
            fclose($handle);
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
                throw new LexKeyNotFoundError(
                    "Key not found: '{$key}'"
                );
            }
            if(!array_key_exists($key, $this->cacheTranslations)) {
                $this->cacheTranslations[$key] = $this->unescape($this->rawTranslations[$key]);
            }
            return $this->cacheTranslations[$key];
        }

        public function load(
            string  $langDir,
            ?string $locale         = null,
            string  $fallbackLocale = "en"
        ): void {
            /**
             * Load .lex file from given directory.
             * Alias for re-initializing a new lang_dir and locale.
             * Args:
             *      lang_dir: Directory containing .lex files.
             *      locale: Locale code. Auto-detected if None.
             *      fallback_locale: Fallback locale code. Default is "en".
             */
            $this->langDir        = $langDir;
            $this->fallbackLocale = $fallbackLocale;
            $this->locale         = $locale ?? $this->detectLocale();
            $this->filepath       = $this->resolveFilepath();
            $this->loadFile();
        }

        public function get(string $key, ...$args): string {
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
            $value = $this->cacheFetch($key);
            // Apply printf-style formatting if arguments provided
            if(empty($args)) {
                return str_replace("%%", "%", $value);
            }
            // PHP 8+ throws ValueError on format failure instead of returning false
            try {
                $formatted = @vsprintf($value, $args);
            } catch(\ValueError $error) {
                throw new LexKeyNotFoundError("Format error for key '{$key}'", 0, $error);
            }
            if($formatted === false) {
                throw new LexKeyNotFoundError(
                    "Format error for key '{$key}'"
                );
            }
            return $formatted;
        }

        public function getOrDefault(string $key, string $default, ...$args): string {
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
                return $this->get($key, ...$args);
            } catch (LexKeyNotFoundError) {
                // Format default with args if provided
                if(empty($args)) {
                    return $default;
                }
                // PHP 8+ throws ValueError on format failure instead of returning default
                try {
                    $formatted = @vsprintf($default, $args);
                } catch(\ValueError)  {
                    return $default;
                }
                return $formatted === false ? $default : $formatted;
            }
        }

        public function reload(
            ?string $locale = null,
            ?string $fallbackLocale = null
        ): void {
            /**
             * Reload translations with a new or auto-detected locale.
             * Args:
             *      locale: New locale code. Auto-detected if None.
             *      fallback_locale: New fallback locale code,
             *          or None to keep previous.
             */
            $newLocale   = $locale ?? $this->detectLocale();
            $newFallback = $fallbackLocale ?? $this->fallbackLocale;
            // Save current state for rollback on failure
            $oldLangDir  = $this->langDir;
            $oldLocale   = $this->locale;
            $oldFallback = $this->fallbackLocale;
            $oldFilepath = $this->filepath;
            $oldRaw      = $this->rawTranslations;
            $oldCache    = $this->cacheTranslations;
            try {
                $this->locale         = $newLocale;
                $this->fallbackLocale = $newFallback;
                $this->filepath       = $this->resolveFilepath();
                $this->loadFile();
            } catch (LexFileNotFoundError | LexParseError $error) {
                // Restore previous state if anything fails
                $this->langDir           = $oldLangDir;
                $this->locale            = $oldLocale;
                $this->fallbackLocale    = $oldFallback;
                $this->filepath          = $oldFilepath;
                $this->rawTranslations   = $oldRaw;
                $this->cacheTranslations = $oldCache;
                throw $error;
            }
        }

        public function keys(): array {
            /**
             * Return all available translation keys.
             * Returns:
             *      Tuple of keys strings.
             */
            return array_keys($this->rawTranslations);
        }

        public function getLocale(): string {
            // Returns the currently active locale code
            return $this->locale;
        }

        public function getFilepath(): string {
            // Returns the path to the currently loaded .lex file
            return $this->filepath;
        }

        public function count(): int {
            // count($lex) - total number of loaded keys
            return count($this->rawTranslations);
        }

        public function __toString(): string {
            // String representation for debugging
            return sprintf(
                "Lexis(locale=%s, fallback=%s, keys=%d, cached_keys=%d, filepath=%s)",
                $this->locale,
                $this->fallbackLocale,
                count($this->rawTranslations),
                count($this->cacheTranslations),
                $this->filepath
            );
        }

        public function offsetExists(mixed $offset): bool {
            /**
             * Check whether a key exists, without loading or formatting its value.
             * Triggered automatically by isset($lexis['key']) or empty($lexis['key']).
             */
            return array_key_exists($offset, $this->rawTranslations);
        }

        public function offsetGet(mixed $offset): string {
            /**
             * Read shorthand: $lexis['welcome'] is equivalent to $lexis->get('welcome').
             * Delegates to get() to reuse the same caching and placeholder logic,
             *      including the LexKeyNotFoundError if the key doesn't exist.
             */
            return $this->get($offset);
        }

        public function offsetSet(mixed $offset, mixed $value): void {
            /**
             * Blocks array-style writes: $lexis['key'] = 'value'.
             * Translations are only ever loaded from the .lex file — never mutated
             *      at runtime — so any assignment attempt is a programming error.
             */
            throw new \LogicException(
                "Lexis translations are read-only."
            );
        }

        public function offsetUnset(mixed $offset): void {
            /**
             * Blocks array-style deletion: unset($lexis['key']).
             * Same reasoning as offsetSet() — state is read-only once loaded.
             */
            throw new \LogicException(
                "Lexis translations are read-only."
            );
        }
    }
    if(PHP_SAPI === 'cli' && isset($argv[0]) && realpath($argv[0]) === realpath(__FILE__)) {
        /**
         * Demo: Load translations and run basic operations
         */
        try {
            $langDir = __DIR__ . '/../lang';
            $lex     = new Lexis($langDir);
            echo $lex->get("welcome", "LEX") . "\n";
            echo $lex->get("modules_available") . "\n";
            echo $lex->get("error_file", "foo.txt") . "\n";
            echo (string) $lex . "\n";
            $lex->reload("en");
            echo $lex->get("welcome", "Lexis") . "\n";
        } catch(LexFileNotFoundError $error) {
            echo "[ERROR] {$error->getMessage()}\n";
        } catch(LexKeyNotFoundError $error) {
            echo "[ERROR] {$error->getMessage()}\n";
        }
    }
