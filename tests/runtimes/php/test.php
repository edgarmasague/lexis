<?php
    /**
     * test.php - Official Test Suite for LEXIS PHP Runtime
     * Based on TESTS.md (T-001 to T-437). Retired IDs are not tested.
     */
    const LEXIS_ENGINE_PATH = __DIR__ . '/../../../runtimes/php/lexis.php';
    const FIXTURES_DIR      = __DIR__ . '/../../fixtures';
    const LOCALES_DIR       = FIXTURES_DIR . '/locales';
    if(!is_file(LEXIS_ENGINE_PATH)) {
        fwrite(STDERR, "[test.php] Cannot find Lexis engine at: " . LEXIS_ENGINE_PATH . "\n");
        fwrite(STDERR, "[test.php] Update LEXIS_ENGINE_PATH at the top of this file.\n");
        exit(1);
    }
    require_once LEXIS_ENGINE_PATH;

    $GLOBALS['__passed']   = 0;
    $GLOBALS['__failed']   = 0;
    $GLOBALS['__failures'] = [];
    $GLOBALS['__tmpDirs']  = [];
    $GLOBALS['lex']        = null;

    function report_pass(string $id): void {
        $GLOBALS['__passed']++;
    }

    function report_fail(string $id, string $reason): void {
        $GLOBALS['__failed']++;
        $GLOBALS['__failures'][] = "{$id}: {$reason}";
        echo "   \033[31mFAIL\033[0m {$id} - {$reason}\n";
    }

    function assert_equal(string $id, mixed $actual, mixed $expected): void {
        if($actual === $expected) {
            report_pass($id);
            return;
        }
        report_fail($id, sprintf(
            "expected %s, got %s",
            var_export($expected, true),
            var_export($actual, true)
        ));
    }

    function assert_throws(string $id, callable $fn, string $expectedExceptionClass): void {
        try {
            $fn();
            report_fail($id, "expected {$expectedExceptionClass} to be thrown, none was");
        } catch(\Throwable $error) {
            if($error instanceof $expectedExceptionClass) {
                report_pass($id);
            } else {
                report_fail($id, "expected {$expectedExceptionClass}, got " . get_class($error) . ": " . $error->getMessage());
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

    function copy_dir(string $source, string $target): void {
        mkdir($target, 0777, true);
        foreach(scandir($source) as $entry) {
            if($entry === '.' || $entry === '..') {
                continue;
            }
            is_dir("{$source}/{$entry}")
                ? copy_dir("{$source}/{$entry}", "{$target}/{$entry}")
                : copy("{$source}/{$entry}", "{$target}/{$entry}");
        }
    }

    function remove_dir(string $dir): void {
        foreach(glob($dir . '/*') ?: [] as $entry) {
            is_dir($entry) ? remove_dir($entry) : @unlink($entry);
        }
        @rmdir($dir);
    }

    function clean_tmp_dirs(): void {
        foreach($GLOBALS['__tmpDirs'] as $dir) {
            remove_dir($dir);
        }
    }

    // Fixture names with "_" are not plain locale codes (cr_inside would be
    // normalized to cr_INSIDE), so a copy of the fixtures gets short aliases.
    function standalone_dir(): string {
        static $dir = null;
        if($dir === null) {
            $dir = make_tmp_dir() . '/fixtures';
            copy_dir(FIXTURES_DIR, $dir);
            $aliases = [
                'crlf' => 'cr', 'crlf_trailing' => 'ct', 'cr_inside' => 'ci',
                'duplicate_key' => 'dk', 'malformed_line' => 'ml', 'empty_key' => 'ek',
                'empty' => 'em', 'invalid_utf8' => 'iv', 'reserved_keys' => 'rk', 'test' => 'ts',
            ];
            foreach($aliases as $source => $alias) {
                if(is_file("{$dir}/{$source}.lex")) {
                    copy("{$dir}/{$source}.lex", "{$dir}/{$alias}.lex");
                }
            }
        }
        return $dir;
    }

    function use_lex(string $dir, string $locale): Lexis {
        return $GLOBALS['lex'] = new Lexis($dir, $locale);
    }

    class CountingLexis extends Lexis {
        public int $unescapeCalls = 0;
        protected function unescape(string $value): string {
            $this->unescapeCalls++;
            return parent::unescape($value);
        }
    }

    foreach(['test.lex', 'en.lex', 'es.lex', 'pt.lex'] as $fixture) {
        if(!is_file(FIXTURES_DIR . '/' . $fixture)) {
            fwrite(STDERR, "[test.php] Missing required fixture: fixtures/{$fixture}\n");
            exit(1);
        }
    }

    // --- Parsing: T-001 to T-026 ---------------------------------------------------
    section("Parsing (T-001 to T-026)");
    use_lex(standalone_dir(), "ts");
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

    // T-012: CRLF line endings (the fixture must really use CRLF; git can normalize it)
    assert_equal("T-012 (fixture has CRLF)", str_contains(file_get_contents(FIXTURES_DIR . '/crlf.lex'), "\r\n"), true);
    use_lex(standalone_dir(), "cr");
    assert_equal("T-012", $lex->get("crlf_entry"), "value without trailing carriage return");

    // T-013 and T-015: indented comments and whitespace-only lines are skipped
    $dir = make_tmp_dir();
    write_lex($dir, "en.lex", "  # indented comment\n   \n\t\nk::v\n");
    assert_equal("T-013/T-015", (new Lexis($dir, "en"))->keys(), ["k"]);

    use_lex(standalone_dir(), "ts");
    assert_equal("T-014", $lex->get("key_space"), "value_space");
    assert_equal("T-016", $lex->get("emoji_sequence"), "Family: 👨‍👩‍👧‍👦");
    assert_equal("T-017", $lex->get("huge_spaces"), "correct string" . str_repeat(" ", 10000));

    use_lex(FIXTURES_DIR, "bom");
    assert_equal("T-018", $lex->get("first_key"), "first_value");
    assert_equal("T-019", $lex->get("last_key"), "last_value");
    assert_equal("T-020", $lex->get("mid_bom"), "prefix_\xEF\xBB\xBF_suffix");

    use_lex(standalone_dir(), "ts");
    assert_equal("T-021", $lex->has("comment"), false);
    assert_equal("T-022", $lex->has("hidden") || $lex->has("#hidden"), false);
    assert_equal("T-023", $lex->get("colon_run"), ":tail");
    assert_equal("T-024", $lex->get("url:home"), "Home page");

    assert_equal("T-025 (fixture has CRLF)", str_contains(file_get_contents(FIXTURES_DIR . '/crlf_trailing.lex'), "\r\n"), true);
    use_lex(standalone_dir(), "ct");
    assert_equal("T-025", $lex->get("crlf_trailing"), "value  ");
    use_lex(standalone_dir(), "ci");
    assert_equal("T-026", $lex->get("cr_inside"), "a\rb");
    use_lex(standalone_dir(), "ts");

    // --- Escape sequences: T-101 to T-114 -------------------------------------------
    section("Escape sequences (T-101 to T-114)");
    assert_equal("T-101", $lex->get("escape_newline"), "Line 1\nLine 2");
    assert_equal("T-102", $lex->get("escape_tab"), "Col1\tCol2");
    assert_equal("T-103", $lex->get("escape_backslash"), 'C:\Program Files\Lexis');
    assert_equal("T-104", $lex->get("escape_quote"), 'She said "hello"');
    assert_equal("T-105", $lex->get("escape_carriage_return"), "before\rafter");
    assert_equal("T-106", $lex->get("escape_backspace"), "before\x08after");
    assert_equal("T-107", $lex->get("escape_vertical_tab"), "before\x0Bafter");
    assert_equal("T-108", $lex->get("escape_unknown"), 'unknown \q escape passes through');
    assert_equal("T-109", $lex->get("escape_trailing_backslash"), 'trailing backslash is literal\\');
    assert_equal("T-110", $lex->get("escape_combined", "Alice", 99), "Name:\tAlice\nScore:\t99");
    assert_equal("T-111", $lex->get("escape_null"), 'before\0after');
    assert_equal("T-112", $lex->get("escape_escaped_n"), 'literal \n character');
    assert_equal("T-113", $lex->get("passthrough_arg", 'a\nb'), 'Hello a\nb');
    assert_equal("T-114", $lex->get("escape_then_percent", "x"), '\x');

    // --- Placeholders: T-201 to T-286 -----------------------------------------------
    section("Placeholders (T-201 to T-286)");
    assert_equal("T-201", $lex->get("placeholder_string", 'Alice'), 'Hello Alice');
    assert_equal("T-202", $lex->get("placeholder_integer", 3), 'You have 3 messages');
    assert_equal("T-203", $lex->get("placeholder_float", 3.75), 'Rating: 3.75');
    assert_equal("T-204", $lex->get("placeholder_hex", 255), 'Hex value: ff');
    assert_equal("T-205", $lex->get("placeholder_octal", 8), 'Octal value: 10');
    assert_equal("T-206", $lex->get("placeholder_char", 65), 'Char: A');
    assert_equal("T-207", $lex->get("placeholder_percent"), '100% completed');
    assert_equal("T-208", $lex->get("placeholder_multiple", 'Alice', 10, 4.5), 'User Alice has 10 points and rating 4.50');
    assert_equal("T-211", $lex->get("pad_neg_int", -42), '-0042');
    assert_equal("T-212", $lex->get("float_prec", 3.14159), '00003.14');
    assert_equal("T-213", $lex->get("neg_hex", -42), '-2a');
    assert_equal("T-215", $lex->get("invalid_specifier", 'test'), 'Value: %q');
    assert_equal("T-217", $lex->get("placeholder_float", 1e+18), 'Rating: 1000000000000000000');
    assert_equal("T-218", $lex->get("placeholder_integer", 9223372036854775807), 'You have 9223372036854775807 messages');
    assert_equal("T-219", $lex->get("adjacent_percent", 'Alice'), '%%s Alice');
    assert_equal("T-220", $lex->get("one_placeholder", 'Alice', 'extra_arg'), 'Hello Alice');
    assert_equal("T-221", $lex->get("float_default_prec", 3.1), '3.1');
    assert_equal("T-222", $lex->get("float_zero_prec", 2.5), '3');
    assert_equal("T-223a", $lex->get("string_width_right", 'Hi'), '   Hi');
    assert_equal("T-223b", $lex->get("string_width_left", 'Hi'), 'Hi   ');
    assert_equal("T-224", $lex->get("string_zero_pad", 'Hi'), '   Hi');
    assert_equal("T-225", $lex->get("pos_test", 'Alice', 10), 'Hello Alice, code 10');
    assert_equal("T-226", $lex->get("placeholder_string", '%s%d'), 'Hello %s%d');
    assert_equal("T-227", $lex->get("trailing_percent"), 'Value ends with %');
    assert_equal("T-229", $lex->get("placeholder_char", 8364), 'Char: €');
    assert_equal("T-230", $lex->get("i_spec", 42), 'Count: 42');
    assert_equal("T-231", $lex->get("unknown_specs", 'x'), '%u %X %e %g %b %n %p');
    assert_equal("T-232", $lex->get("positional_attempt_2", 'Alice'), 'Hello %1$s');
    assert_equal("T-233", $lex->get("width_codepoint", 'ñ'), '    ñ');
    assert_equal("T-234", $lex->get("numeric_string", '42'), '42');
    assert_equal("T-236", $lex->get("float_zero_prec", -2.5), '-3');
    assert_equal("T-237", $lex->get("float_two_prec", 1.005), '1.00');
    assert_equal("T-240", $lex->get("placeholder_integer", 3.0), 'You have 3 messages');
    assert_equal("T-242", $lex->get("lit_flags", 5, 5, 255), '%+d|% d|%#x');
    assert_equal("T-243", $lex->get("lit_length", 5), '%ld|%lld|%hd|%zu');
    assert_equal("T-244", $lex->get("lit_star", 5, 2, 3.14), '%*d|%.*f');
    assert_equal("T-245", $lex->get("lit_prec_s", 'abcdef', 5), '%.3s|%.2d');
    assert_equal("T-246", $lex->get("lit_prec_empty", 3.5), '%.f');
    assert_equal("T-247", $lex->get("lit_flag_order", 5), '%0-5d');
    assert_equal("T-248", $lex->get("lit_percent_space"), '50% discount');
    assert_equal("T-249a", $lex->get("lit_cut_off_width"), 'Width cut off %5');
    assert_equal("T-249b", $lex->get("lit_cut_off_flags"), 'Flags cut off %-0');
    assert_equal("T-250", $lex->get("lit_then_real", 'x'), '%qx');
    assert_equal("T-251", $lex->get("width_max", 1), str_repeat(' ', 1023) . '1');
    assert_equal("T-252", $lex->get("width_over", 1), '%1025d');
    assert_equal("T-253", $lex->get("width_overflow", 1), '%99999999999999999999d');
    assert_equal("T-254", $lex->get("prec_max", 0.1), '0.100000000000000');
    assert_equal("T-255a", $lex->get("prec_over", 0.1), '%.16f');
    assert_equal("T-255b", $lex->get("prec_overflow", 1), '%.99999999999999999999f');
    assert_equal("T-256", $lex->get("pad_left_zero", 42), '42   |');
    assert_equal("T-257", $lex->get("pad_char_zero", 65), '  A|');
    assert_equal("T-258", $lex->get("pad_neg_float", -3.14159), '-0003.14');
    assert_equal("T-259", $lex->get("pad_neg_hex", -42), '-002a');
    assert_equal("T-260", $lex->get("pad_left_float", 3.14159), '3.14    |');
    assert_equal("T-261", $lex->get("pad_no_truncate", 12345), '12345');
    assert_equal("T-262", $lex->get("width_emoji", '👋'), '    👋|');
    assert_equal("T-263", $lex->get("width_combining", 'é'), '   é|');
    assert_equal("T-264a", $lex->get("s_int", -42), '-42');
    assert_equal("T-264b", $lex->get("s_int_min", PHP_INT_MIN), '-9223372036854775808');
    assert_equal("T-265a", $lex->get("s_float", 3.14), '3.14');
    assert_equal("T-265b", $lex->get("s_float_int", 3.0), '3');
    assert_equal("T-265c", $lex->get("s_float_tiny", 4e-07), '0');
    assert_equal("T-270", $lex->get("d_int_min", PHP_INT_MIN), '-9223372036854775808');
    assert_equal("T-273a", $lex->get("hex_zero", 0), '0');
    assert_equal("T-273b", $lex->get("hex_int_min", PHP_INT_MIN), '-8000000000000000');
    assert_equal("T-273c", $lex->get("oct_neg", -8), '-10');
    assert_equal("T-276a", $lex->get("char_astral", 128075), '👋');
    assert_equal("T-276b", $lex->get("char_max", 1114111), '􏿿');
    assert_equal("T-276c", $lex->get("char_numstr", '65'), 'A');
    assert_equal("T-278a", $lex->get("f_def_int_valued", 3.0), '3');
    assert_equal("T-278b", $lex->get("f_def_hundred", 100.0), '100');
    assert_equal("T-278c", $lex->get("f_def_sum", 0.30000000000000004), '0.3');
    assert_equal("T-278d", $lex->get("f_def_third", 0.3333333333333333), '0.333333');
    assert_equal("T-278e", $lex->get("f_def_round", 1.23456789), '1.234568');
    assert_equal("T-278f", $lex->get("f_def_big", 1234567.891), '1234567.891');
    assert_equal("T-278g", $lex->get("f_def_intarg", 3), '3');
    assert_equal("T-279a", $lex->get("f_def_tiny", 4e-07), '0');
    assert_equal("T-279b", $lex->get("f_def_tiny_neg", -4e-07), '0');
    assert_equal("T-279c", $lex->get("f_def_negzero", -0.0), '0');
    assert_equal("T-279d", $lex->get("f_def_edge", 1e-06), '0.000001');
    assert_equal("T-280a", $lex->get("f_prec_small", 4e-07), '0.0000004');
    assert_equal("T-280b", $lex->get("f_prec_pad", 3.0), '3.00');
    assert_equal("T-280c", $lex->get("f_prec_intarg", 1), '1.00');
    assert_equal("T-280d", $lex->get("f_prec_one", 3.1), '3.10');
    assert_equal("T-281a", $lex->get("f_tie_half", 0.5), '1');
    assert_equal("T-281b", $lex->get("f_tie_onehalf", 1.5), '2');
    assert_equal("T-282", $lex->get("f_neg_tiny", -0.001), '0.00');
    assert_equal("T-283", $lex->get("f_str", '3.14'), '3.14');
    assert_equal("T-284", $lex->get("f_big_prec", 9e+18), '9000000000000000000.00');
    assert_equal("T-286", $lex->get("pct_pct_s"), '%s');

    // --- Placeholders that must raise LexFormatError --------------------------------
    section("Placeholders that raise LexFormatError");
    assert_throws("T-209", fn() => $lex->get("bool_spec", true, false), LexFormatError::class);
    assert_throws("T-210", fn() => $lex->get("null_spec", null), LexFormatError::class);
    assert_throws("T-214", fn() => $lex->get("two_placeholders", 'only_one_arg'), LexFormatError::class);
    assert_throws("T-216a", fn() => $lex->get("placeholder_float", NAN), LexFormatError::class);
    assert_throws("T-216b", fn() => $lex->get("placeholder_float", INF), LexFormatError::class);
    assert_throws("T-228", fn() => $lex->get("placeholder_integer", 'abc'), LexFormatError::class);
    assert_throws("T-235", fn() => $lex->get("placeholder_float", -INF), LexFormatError::class);
    assert_throws("T-238a", fn() => $lex->get("placeholder_float", 9.223372036854776e+18), LexFormatError::class);
    assert_throws("T-238b", fn() => $lex->get("placeholder_float", 1e+19), LexFormatError::class);
    assert_throws("T-238c", fn() => $lex->get("placeholder_float", 1e+21), LexFormatError::class);
    assert_throws("T-239", fn() => $lex->get("placeholder_char", 1114112), LexFormatError::class);
    assert_throws("T-241", fn() => $lex->get("placeholder_integer", 3.7), LexFormatError::class);
    assert_throws("T-266", fn() => $lex->get("s_bool", true), LexFormatError::class);
    assert_throws("T-267", fn() => $lex->get("s_null", null), LexFormatError::class);
    assert_throws("T-268", fn() => $lex->get("s_bad_utf8", "\xC3("), LexFormatError::class);
    assert_throws("T-269a", fn() => $lex->get("d_str_float", '4.0'), LexFormatError::class);
    assert_throws("T-269b", fn() => $lex->get("d_str_plus", '+5'), LexFormatError::class);
    assert_throws("T-269c", fn() => $lex->get("d_str_space", ' 5'), LexFormatError::class);
    assert_throws("T-269d", fn() => $lex->get("d_str_empty", ''), LexFormatError::class);
    assert_throws("T-271a", fn() => $lex->get("d_float_big", 1e+19), LexFormatError::class);
    assert_throws("T-271b", fn() => $lex->get("d_str_big", '9223372036854775808'), LexFormatError::class);
    assert_throws("T-272a", fn() => $lex->get("d_nan", NAN), LexFormatError::class);
    assert_throws("T-272b", fn() => $lex->get("d_inf", INF), LexFormatError::class);
    assert_throws("T-274a", fn() => $lex->get("hex_frac", 3.5), LexFormatError::class);
    assert_throws("T-274b", fn() => $lex->get("hex_bad_str", 'zz'), LexFormatError::class);
    assert_throws("T-275a", fn() => $lex->get("char_zero", 0), LexFormatError::class);
    assert_throws("T-275b", fn() => $lex->get("char_neg", -1), LexFormatError::class);
    assert_throws("T-275c", fn() => $lex->get("char_surr_lo", 55296), LexFormatError::class);
    assert_throws("T-275d", fn() => $lex->get("char_surr_hi", 57343), LexFormatError::class);
    assert_throws("T-277", fn() => $lex->get("char_str", 'A'), LexFormatError::class);
    assert_throws("T-283a", fn() => $lex->get("f_str_exp", '1e5'), LexFormatError::class);
    assert_throws("T-283b", fn() => $lex->get("f_str_bad", 'abc'), LexFormatError::class);
    assert_throws("T-285", fn() => $lex->get("f_bool", true), LexFormatError::class);

    // --- Edge cases: T-303 (T-301 and T-302 are retired) ------------------------------
    section("Edge cases (T-303)");
    assert_equal("T-303", $lex->get("triple_colon"), "key:::value with triple colon");

    // --- Conformance: T-401 to T-437 ------------------------------------------------
    section("Conformance (T-401 to T-437)");
    assert_throws("T-401", fn() => $lex->get("nonexistent_key"), LexKeyNotFoundError::class);
    assert_equal("T-402", $lex->getOrDefault("nonexistent_key", "fallback"), "fallback");
    assert_equal("T-403", $lex->getOrDefault("nonexistent_key", "Hello %s", "Alice"), "Hello Alice");

    // T-404: request fr, only en.lex exists
    $dir = make_tmp_dir();
    write_lex($dir, "en.lex", "welcome::Welcome");
    $fallback = new Lexis($dir, "fr");
    assert_equal("T-404", [$fallback->getLocale(), $fallback->get("welcome")], ["en", "Welcome"]);

    // T-405: custom fallback, only pt.lex exists
    $dir = make_tmp_dir();
    write_lex($dir, "pt.lex", "welcome::Bem-vindo\n");
    $fallback = new Lexis($dir, "fr", "pt");
    assert_equal("T-405", [$fallback->info()["fallback_locale"], $fallback->getLocale(), $fallback->get("welcome")], ["pt", "pt", "Bem-vindo"]);

    // T-406: reload switches locale
    $es = new Lexis(FIXTURES_DIR, "es");
    assert_equal("T-406 (es)", $es->get("welcome", "Alice"), "Bienvenido Alice");
    $es->reload("en");
    assert_equal("T-406 (en)", $es->get("welcome", "Alice"), "Welcome Alice");

    // T-407: reload changes the fallback (and only that when the locale loads)
    $dir = make_tmp_dir();
    write_lex($dir, "en.lex", "hello::Hello");
    $changing = new Lexis($dir, "en", "en");
    $changing->reload(fallbackLocale: "es");
    assert_equal("T-407", $changing->info()["fallback_locale"], "es");

    // T-408: reload that fails keeps the whole previous state
    $dir = make_tmp_dir();
    write_lex($dir, "es.lex", "welcome::Hola");
    $kept   = new Lexis($dir, "es");
    $before = $kept->info();
    assert_throws("T-408", fn() => $kept->reload("xyz"), LexFileNotFoundError::class);
    assert_equal("T-408 (state unchanged)", $kept->info(), $before);
    assert_equal("T-408 (still works)", $kept->get("welcome"), "Hola");

    // T-410 to T-413
    assert_throws("T-410", fn() => new Lexis(standalone_dir(), "dk"), LexParseError::class);
    assert_throws("T-411", fn() => new Lexis(standalone_dir(), "ml"), LexParseError::class);
    assert_throws("T-412", fn() => new Lexis(standalone_dir(), "ek"), LexParseError::class);
    assert_throws("T-413", fn() => new Lexis(make_tmp_dir() . "/nonexistent/path", "en"), LexFileNotFoundError::class);

    // T-414 (white-box, optional): unescape runs once per key
    $counting = new CountingLexis(FIXTURES_DIR, "test");
    $first    = $counting->get("escape_newline");
    $second   = $counting->get("escape_newline");
    assert_equal("T-414 (same output)", $second, $first);
    assert_equal("T-414 (unescaped once)", $counting->unescapeCalls, 1);

    // T-415: cache eviction on reload
    $dir = make_tmp_dir();
    write_lex($dir, "aa.lex", "k1::value from locale A\n");
    write_lex($dir, "bb.lex", "k2::value from locale B\n");
    $evicting = new Lexis($dir, "aa");
    assert_equal("T-415", $evicting->get("k1"), "value from locale A");
    $evicting->reload("bb");
    assert_throws("T-415 (k1 is gone)", fn() => $evicting->get("k1"), LexKeyNotFoundError::class);
    assert_equal("T-415 (k2)", $evicting->get("k2"), "value from locale B");

    // T-416: a failed reload leaves the loaded state untouched
    write_lex($dir, "bad.lex", "x::1\nx::2\n");
    $isolated = new Lexis($dir, "aa");
    assert_throws("T-416", fn() => $isolated->reload("bad"), LexParseError::class);
    assert_equal("T-416 (keys)", $isolated->keys(), ["k1"]);
    assert_equal("T-416 (value)", $isolated->get("k1"), "value from locale A");

    // T-417: keys are case sensitive
    $dir = make_tmp_dir();
    write_lex($dir, "en.lex", "KEY::value1\nkey::value2\n");
    $cased = new Lexis($dir, "en");
    assert_equal("T-417", [$cased->get("KEY"), $cased->get("key")], ["value1", "value2"]);

    foreach(["es-ES", "es_ES", "ES"] as $code) {
        assert_equal("T-418 ({$code})", (new Lexis(FIXTURES_DIR, $code))->info()["locale"], "es");
    }

    assert_throws("T-419", fn() => new Lexis(standalone_dir(), "iv"), LexParseError::class);

    $reserved = new Lexis(standalone_dir(), "rk");
    foreach(["toString", "valueOf", "__proto__", "constructor"] as $key) {
        assert_equal("T-420 ({$key})", $reserved->get($key), "mapped {$key} value");
    }

    // T-421: two instances do not share state
    $client1 = new Lexis(FIXTURES_DIR, "en");
    $client2 = new Lexis(FIXTURES_DIR, "es");
    assert_equal("T-421 (en)", $client1->get("welcome", "A"), "Welcome A");
    assert_equal("T-421 (es)", $client2->get("welcome", "A"), "Bienvenido A");
    $client2->reload("en");
    $client1->reload("es");
    assert_equal("T-421 (isolated)", [$client1->getLocale(), $client2->getLocale()], ["es", "en"]);

    // T-422: empty and comment-only files
    assert_equal("T-422 (empty file)", count(new Lexis(standalone_dir(), "em")), 0);
    $dir = make_tmp_dir();
    write_lex($dir, "en.lex", "# only\n\n  # comments\n");
    assert_equal("T-422 (comment-only file)", count(new Lexis($dir, "en")), 0);

    // T-423 and T-424: invalid locale codes are rejected before the filesystem is touched
    foreach(["../secret", "es/..", "es\\x", "es.x", "", "es_VE_X", "es VE"] as $bad) {
        assert_throws("T-423/T-424 [" . $bad . "]", fn() => new Lexis(LOCALES_DIR, $bad), LexFileNotFoundError::class);
    }
    // T-425: invalid fallback and entry-file name
    assert_throws("T-425 (fallback)", fn() => new Lexis(LOCALES_DIR, "es", fallbackLocale: "../x"), LexFileNotFoundError::class);
    foreach(["../main", "", "a/b"] as $bad) {
        assert_throws("T-425 (name '{$bad}')", fn() => new Lexis(LOCALES_DIR, "es", name: $bad), LexFileNotFoundError::class);
    }

    foreach(["es-VE", "es_ve", "ES_VE"] as $code) {
        $regional = new Lexis(LOCALES_DIR, $code);
        assert_equal("T-426 ({$code})", [$regional->get("welcome"), $regional->info()["locale"]], ["es_VE", "es_VE"]);
    }
    $chain = new Lexis(LOCALES_DIR, "es_VE");
    assert_equal("T-427", [$chain->get("welcome"), $chain->getLocale()], ["es_VE", "es_VE"]);
    $chain = new Lexis(LOCALES_DIR, "es_AR");
    assert_equal("T-428", [$chain->get("welcome"), $chain->getLocale()], ["es", "es"]);
    assert_equal("T-429", (new Lexis(LOCALES_DIR, "pt"))->get("welcome"), "pt (main)");
    $named = new Lexis(LOCALES_DIR, "pt", name: "custom");
    assert_equal("T-430", [$named->get("welcome"), $named->info()["name"]], ["pt (custom)", "custom"]);
    assert_equal("T-431", (new Lexis(LOCALES_DIR, "de"))->get("welcome"), "de (file)");
    assert_equal("T-432", (new Lexis(LOCALES_DIR, "fr_CA"))->get("welcome"), "fr_CA (dir)");
    $shaped = new Lexis(LOCALES_DIR, "ja", "es_VE");
    assert_equal("T-433", [$shaped->get("welcome"), $shaped->getLocale()], ["es_VE", "es_VE"]);
    $resolved = new Lexis(LOCALES_DIR, "ja");
    assert_equal("T-434", [$resolved->get("welcome"), $resolved->getLocale()], ["en", "en"]);

    $custom = new Lexis(LOCALES_DIR, "pt", name: "custom");
    $custom->reload("pt");
    assert_equal("T-435 (reload)", $custom->get("welcome"), "pt (custom)");
    assert_throws("T-435 (invalid)", fn() => $custom->reload("../x"), LexFileNotFoundError::class);
    assert_equal("T-435 (after failure)", [$custom->get("welcome"), $custom->info()["name"]], ["pt (custom)", "custom"]);

    $keeping = new Lexis(LOCALES_DIR, "es_VE");
    $keeping->reload(fallbackLocale: "en");
    assert_equal("T-436", [$keeping->get("welcome"), $keeping->getLocale()], ["es_VE", "es_VE"]);

    // T-437 (optional): locale auto-detection from LANG
    $originalLang = getenv("LANG");
    foreach([
        "es_VE.UTF-8" => "es_VE", "es_VE@euro" => "es_VE", "C.UTF-8" => "en",
        "POSIX" => "en", "" => "en", "zh_Hans_CN.UTF-8" => "en",
    ] as $lang => $locale) {
        putenv("LANG={$lang}");
        $detected = new Lexis(LOCALES_DIR);
        assert_equal("T-437 [{$lang}]", [$detected->info()["locale"], $detected->get("welcome")], [$locale, $locale]);
    }
    $originalLang === false ? putenv("LANG") : putenv("LANG={$originalLang}");

    // --- Additional tests: public API that TESTS.md does not number ------------------
    section("Additional tests");
    $lex = use_lex(standalone_dir(), "ts");
    assert_equal("has", [$lex->has("simple"), $lex->has("nonexistent")], [true, false]);
    assert_equal("keys are strings", array_filter($lex->keys(), 'is_string') === $lex->keys(), true);
    assert_equal("len / count", [$lex->len() > 0, count($lex) === $lex->len()], [true, true]);
    assert_equal("ArrayAccess isset", [isset($lex["simple"]), isset($lex["nonexistent"])], [true, false]);
    assert_equal("ArrayAccess read", $lex["simple"], "Hello World");
    assert_throws("ArrayAccess write", function() use ($lex) { $lex["simple"] = "x"; }, \LogicException::class);
    assert_throws("ArrayAccess unset", function() use ($lex) { unset($lex["simple"]); }, \LogicException::class);
    $info = $lex->info();
    assert_equal("info fields", array_keys($info), ["locale", "fallback_locale", "lang_dir", "name", "filepath", "keys", "cached_keys"]);
    assert_equal("info keys", $info["keys"], $lex->len());
    $text = (string) $lex;
    assert_equal("__toString", str_starts_with($text, "Lexis(") && str_contains($text, "locale='ts'") && str_contains($text, "cached_keys="), true);
    $lex->get("simple");
    assert_equal("cache is filled", $lex->info()["cached_keys"] >= 1, true);
    $lex->clear();
    assert_equal("clear empties the cache", $lex->info()["cached_keys"], 0);
    assert_equal("clear keeps the translations", $lex->get("simple"), "Hello World");
    assert_throws("getOrDefault fails on a bad argument", fn() => $lex->getOrDefault("zz", "%d", "abc"), LexFormatError::class);
    assert_equal("getOrDefault (existing key)", $lex->getOrDefault("simple", "unused"), "Hello World");

    // --- Summary ---------------------------------------------------------------------
    clean_tmp_dirs();
    $total = $GLOBALS['__passed'] + $GLOBALS['__failed'];
    echo "\n" . str_repeat("-", 40) . "\n";
    echo "{$GLOBALS['__passed']}/{$total} passed\n";
    if($GLOBALS['__failed'] > 0) {
        echo "\n\033[31mFailures:\033[0m\n";
        foreach($GLOBALS['__failures'] as $failure) {
            echo " - {$failure}\n";
        }
        exit(1);
    }
    echo "\033[32mAll Lexis conformance tests passed.\033[0m\n";
    exit(0);