<?php
    /**
     * test.php - Official Test Suite for LEXIS PHP Runtime
     * Based on TESTS.md
     */
    const LEXIS_ENGINE_PATH = __DIR__ . '/../../../runtimes/php/lexis.php';
    const FIXTURES_DIR      = __DIR__ . '/../../fixtures';
    if(!is_file(LEXIS_ENGINE_PATH)) {
        fwrite(STDERR, "[test.php] Cannot find Lexis engine at: ". LEXIS_ENGINE_PATH . "\n");
        fwrite(STDERR, "[test.php] Update LEXIS_ENGINE_PATH at the top of this file.\n");
    }
    require_once LEXIS_ENGINE_PATH;

    $GLOBALS['__passed']   = 0;
    $GLOBALS['__failed']   = 0;
    $GLOBALS['__failures'] = [];
    $GLOBALS['__tmpDirs']  = [];

    function report_pass(string $id): void {
        $GLOBALS['__passed']++;
        echo "   \033[32mPASS\033[0m {$id}\n";
    }

    function report_fail(string $id, string $reason): void {
        $GLOBALS['__failed']++;
        $GLOBALS['__failures'][] = "{$id}: {$reason}";
        echo "   \033[32mFAIL\033[0m {$id} - {$reason}\n";
    }

    function assert_equal(string $id, mixed $actual, mixed $expected): void {
        if($actual === $expected) {
            report_pass($id);
            return;
        }
        report_fail(
            $id,
            sprintf("expected %s, got %s",
            var_export($expected, true),
            var_export($actual, true)
            )
        );
    }

    function assert_throws(string $id, callable $fn, string $expectedExceptionClass): void {
        try {
            $fn();
            report_fail($id, "expected {$expectedExceptionClass} to be thrown, none was");
        } catch(\Throwable $error) {
            if($error instanceof $expectedExceptionClass) {
                report_pass($id);
            } else {
                report_fail($id, "expected {$expectedExceptionClass}, got " . get_class($error));
            }
        }
    }

    function section(string $title): void {
        echo "\n\033[1m{$title}\033[0m\n";
    }

    function make_tmp_dir(): string {
        $dir = sys_get_temp_dir() . '/lexis_test_' . bin2hex(random_bytes(8));
        mkdir($dir, 0777, true);
        $GLOBALS['__tmpDirs'][] = $dir;
        return $dir;
    }

    function write_lex(string $dir, string $filename, string $content): void {
        file_put_contents($dir . '/' . $filename, $content);
    }

    function clean_tmp_dirs(): void {
        foreach($GLOBALS['__tmpDirs'] as $dir) {
            $files = glob($dir . '/*');
            foreach($files as $file) {
                @unlink($file);
            }
            @rmdir($dir);
        }
    }

    class CountingLexis extends Lexis {
        public int $unescapeCalls = 0;
        protected function unescape(string $value): string {
            $this->unescapeCalls++;
            return parent::unescape($value);
        }
    }

    $requiredFixtures = ['test.lex', 'en.lex', 'es.lex'];
    foreach($requiredFixtures as $fixture) {
        if(!is_file(FIXTURES_DIR . '/' . $fixture)) {
            fwrite(STDERR, "[test.php] Missing required fixture: fixtures/{$fixture}\n");
            exit(1);
        }
    }
    //Parsing
    section("Parsing");
    $lex = new Lexis(FIXTURES_DIR, "test");
    assert_equal("T-001", $lex->get("simple"), "Hello World");
    assert_equal("T-002", $lex->get("empty_value"), "");
    assert_equal("T-003", $lex->get("key_trimmed"), "Value with spaces around key");
    assert_equal("T-004", $lex->get("UPPERCASE_KEY"), "uppercase key test");
    assert_equal("T-005", $lex->get("mixed_Case_Key"), "mixed case key test");
    assert_equal("T-006", $lex->get("value_with_hash"), "#this value starts with hash");
    assert_equal("T-007", $lex->get("value_with_separator"), "value :: contains :: separators");
    assert_equal("T-008", $lex->get("value_leading_spaces"), "leading spaces are trimmed");
    assert_equal("T-009", $lex->get("value_trailing_spaces"), "trailing spaces are preserved   ");
    assert_equal("T-010", $lex->get("value_unicode"), "Hello 👋 World");
    assert_equal("T-011", $lex->get("value_utf8"), "Héllo Wörld — ñoño");
    //Escape Sequences
    section("Escape Sequences");
    assert_equal("T-101", $lex->get("escape_newline"), "Line 1\nLine 2");
    assert_equal("T-102", $lex->get("escape_tab"), "Col1\tCol2");
    assert_equal("T-103", $lex->get("escape_backslash"), "C:\\Program Files\\Lexis");
    assert_equal("T-104", $lex->get("escape_quote"), 'She said "hello"');
    assert_equal("T-105", $lex->get("escape_carriage_return"), "before\rafter");
    assert_equal("T-106", $lex->get("escape_backspace"), "before\x08after");
    assert_equal("T-107", $lex->get("escape_vertical_tab"), "before\x0Bafter");
    assert_equal("T-108", $lex->get("escape_unknown"), "unknown \\q escape passes through");
    assert_equal("T-109", $lex->get("escape_trailing_backslash"), "trailing backslash is literal\\");
    assert_equal("T-110", $lex->get("escape_combined", "Alice", 99), "Name:\tAlice\nScore:\t99");
    //Placeholders
    section("Placeholders");
    assert_equal("T-201", $lex->get("placeholder_string", "Alice"), "Hello Alice");
    assert_equal("T-202", $lex->get("placeholder_integer", 3), "You have 3 messages");
    assert_equal("T-203", $lex->get("placeholder_float", 3.75), "Rating: 3.750000");
    assert_equal("T-204", $lex->get("placeholder_hex", 255), "Hex value: ff");
    assert_equal("T-205", $lex->get("placeholder_octal", 8), "Octal value: 10");
    assert_equal("T-206", $lex->get("placeholder_char", 65), "Char: A");
    assert_equal("T-207", $lex->get("placeholder_percent"), "100% completed");
    assert_equal("T-208", $lex->get("placeholder_multiple", "Alice", 10, 4.5), "User Alice has 10 points and rating 4.50");
    //Edge Cases
    section("Edge Cases");
    assert_equal("T-301", $lex->get("not_a_comment"), "#not a comment");
    assert_equal("T-302", $lex->get("double_colon"), "key::value with double colon in value");
    assert_equal("T-303", $lex->get("triple_colon"), "key:::value with triple colon");
    //Conformance Tests
    section("Conformance Tests");
    assert_throws("T-401", fn() => $lex->get("nonexistent_key"), LexKeyNotFoundError::class);
    assert_equal("T-402", $lex->getOrDefault("nonexistent_key", "fallback"), "fallback");
    assert_equal("T-403", $lex->getOrDefault("nonexistent_key", "Hello %s", "Alice"), "Hello Alice");
    //T-404
    try {
        $dir = make_tmp_dir();
        write_lex($dir, "en.lex", "welcome::Welcome");
        $lexFallback = new Lexis($dir, "fr");
        if($lexFallback->getLocale() === "en" && $lexFallback->get("welcome") === "Welcome") {
            report_pass("T-404");
        } else {
            report_fail("T-404");
        }
    } catch(\Throwable $error) {
        report_fail("T-404", "unexpected exception: " . $error->getMessage());
    }
    //T-405
    try {
        $dir = make_tmp_dir();
        write_lex($dir, "pt.lex", "welcome::Bem-vindo\n");
        $lexFallback = new Lexis($dir, "pt");
        if($lexFallback->getLocale() === "pt" && $lexFallback->get("welcome") === "Bem-vindo") {
            report_pass("T-405");
        } else {
            report_fail("T-405");
        }
    } catch(\Throwable $error) {
        report_fail("T-405", "unexpected exception: " . $error->getMessage());
    }
    //T-406
    try {
        $lexEs = new Lexis(FIXTURES_DIR, "es");
        $esOutput = $lexEs->get("welcome", "Alice");
        $lexEs->reload("en");
        $enOutput = $lexEs->get("welcome", "Alice");
        if($esOutput === "Bienvenido Alice" && $enOutput === "Welcome Alice") {
            report_pass("T-406");
        } else {
            report_fail("T-406", "got es='{$esOutput}', en='{$enOutput}' - check fixtures/es.lex and en.lex content");
        }
    } catch(\Throwable $error) {
        report_fail("T-406", "unexpected exception: " . $error->getMessage());
    }
    //T-407
    try {
        $originalLang = getenv("LANG");
        putenv("LANG=C.UTF-8");
        $dir = make_tmp_dir();
        write_lex($dir, "es.lex", "hello::Hola");
        write_lex($dir, "en.lex", "hello::Hello");
        $lexFallbackChange = new Lexis($dir, "fr", "en");
        $fallbackRef = new \ReflectionProperty($lexFallbackChange, 'fallbackLocale');
        $fallbackRef->setAccessible(true);
        $before = $fallbackRef->getValue($lexFallbackChange);
        $lexFallbackChange->reload(fallbackLocale: "es");
        $after = $fallbackRef->getValue($lexFallbackChange);
        if(
            $before === "en"
            && $after === "es"
            && $lexFallbackChange->getLocale() === "es"
            && $lexFallbackChange->get("hello") === "Hola"
        ) {
            report_pass("T-407");
        } else {
            report_fail("T-407", "fallback/locale/value mismatch after reload");
        }
    } catch(\Throwable $error) {
        report_fail("T-407", "unexpected exception: " . $error->getMessage());
    } finally {
        if($originalLang === false) {
            putenv("LANG");
        } else {
            putenv("LANG={$originalLang}");
        }
    }
    //T-408
    try {
        $lexEn       = new Lexis(FIXTURES_DIR, "en");
        $langDirRef  = new \ReflectionProperty($lexEn, 'langDir');
        $langDirRef->setAccessible(true);
        $localeRef   = new \ReflectionProperty($lexEn, 'locale');
        $localeRef->setAccessible(true);
        $fallbackRef = new \ReflectionProperty($lexEn, 'fallbackLocale');
        $fallbackRef->setAccessible(true);
        $oldLangDir  = $langDirRef->getValue($lexEn);
        $oldLocale   = $localeRef->getValue($lexEn);
        $oldFallback = $fallbackRef->getValue($lexEn);
        $oldFilepath = $lexEn->getFilepath();
        $oldKeys     = $lexEn->keys();
        try {
            $lexEn->reload("nonexistent_xyz", "also_nonexistent");
            report_fail("T-408", "expected LexFileNotFoundError, none was thrown");
        } catch(LexFileNotFoundError) {
            $unchanged = $langDirRef->getValue($lexEn) === $oldLangDir
                && $localeRef->getValue($lexEn)        === $oldLocale
                && $fallbackRef->getValue($lexEn)      === $oldFallback
                && $lexEn->getFilepath()               === $oldFilepath
                && $lexEn->keys()                      === $oldKeys
                && $lexEn->get("welcome", "Alice")     === "Welcome Alice";
            if($unchanged) {
                report_pass("T-408");
            } else {
                report_fail("T-408", "state was not fully preserved after failed reload");
            }
        }
    } catch(\Throwable $error) {
        report_fail("T-408", "unexpected exception: " . $error->getMessage());
    }
    //T-409
    try {
        $dir = make_tmp_dir();
        write_lex($dir, "pt.lex", "hello::oi\n");
        write_lex($dir, "en.lex", "hello::Hello");
        $lexLoadFallback = new Lexis($dir, "fr");
        $lexLoadFallback->load($dir, "fr", "pt");
        $fallbackRef = new \ReflectionProperty($lexLoadFallback, "fallbackLocale");
        $fallbackRef->setAccessible(true);
        if($fallbackRef->getValue($lexLoadFallback) === "pt" && $lexLoadFallback->get("hello") === "oi") {
            report_pass("T-409");
        } else {
            report_fail("T-409", "fallback_locale or value mismatch");
        }
    } catch(\Throwable $error) {
        report_fail("T-409", "unexpected exception: " . $error->getMessage());
    }
    //T-410
    assert_throws("T-410", function() {
        $dir = make_tmp_dir();
        write_lex($dir, "test.lex", "hello::First\nhello::Second\n");
        new Lexis($dir, "test");
    }, LexParseError::class);
    //T-411
    assert_throws("T-411", function() {
        $dir = make_tmp_dir();
        write_lex($dir, "test.lex", "valid::ok\nthis line has no separator\n");
        new Lexis($dir, "test");
    }, LexParseError::class);
    //T-412
    assert_throws("T-412", function() {
        $dir = make_tmp_dir();
        write_lex($dir, "test.lex", "valid::ok\n::value with no key\n");
        new Lexis($dir, "test");
    }, LexParseError::class);
    //T-413
    assert_throws("T-413", function() {
        $dir = make_tmp_dir();
        new Lexis($dir, "en");
    }, LexFileNotFoundError::class);
    //T-414
        try {
            $lexCounting = new CountingLexis(FIXTURES_DIR, "test");
            $lexCounting->get("escape_newline");
            $lexCounting->get("escape_newline");
            assert_equal("T-414", $lexCounting->unescapeCalls, 1);
        } catch(\Throwable $error) {
            report_fail("T-414", "unexpected exception: " . $error->getMessage());
        }
    section("Additional");
    try {
        $keys = $lex->keys();
        if(
            in_array("simple", $keys, true)
            && in_array("welcome", $keys, true)
            && in_array("empty_value", $keys, true)
        ) {
            report_pass("keys_method");
        } else {
            report_fail("keys_method", "expected keys missing - does fixtures/test.lex have a 'welcome' entry?");
        }
    } catch(\Throwable $error) {
        report_fail("keys_method", "unexpected exception: " . $error->getMessage());
    }
    assert_equal("count_method", count($lex) > 0, true);
    assert_equal("contains_method", isset($lex["simple"]), true);
    assert_equal("contains_method_negative", isset($lex["nonexistent"]), false);
    try {
        $repr = (string) $lex;
        $ok   = str_starts_with($repr, "Lexis(")
                && str_contains($repr, "locale=")
                && str_contains($repr, "keys=")
                && str_contains($repr, "cached_keys=")
                && str_contains($repr, "filepath=");
        if($ok) {
            report_pass("toString_method");
        } else {
            report_fail("toString_method", "missing expected fields in: {$repr}");
        }
    } catch(\Throwable $error) {
        report_fail("toString_method", "unexpected exception: " . $error->getMessage());
    }
    //Summary
    clean_tmp_dirs();
    $total = $GLOBALS['__passed'] + $GLOBALS['__failed'];
    echo "\n" . str_repeat("-", 40) . "\n";
    echo "{$GLOBALS['__passed']}/{$total} passed\n";
    if($GLOBALS['__failed'] > 0) {
        echo "\n\033[31mFailures:\033[0m\n";
        foreach ($GLOBALS['__failures'] as $failure) {
            echo " - {$failure}\n";
        }
        exit(1);
    }
    echo "\033[32mAll Lexis conformance tests passed.\033[0m\n";
    exit(0);
