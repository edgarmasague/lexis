# Lexis Official Test File
# All compliant runtimes must produce identical outputs for all entries.
# See tests/TESTS.md for the full list of expected values.

# --- Parsing: T-001 to T-011, T-014, T-016, T-017 ---------------------
simple::Hello World
empty_value::
key_trimmed ::Value with spaces around key
UPPERCASE_KEY::uppercase key test
mixed_Case_Key::mixed case key test
KEY::value1
key::value2
value_with_hash::#this value starts with hash
value_with_separator::value :: contains :: separators
value_leading_spaces::   leading spaces are trimmed
value_trailing_spaces::trailing spaces are preserved   
value_unicode::Hello 👋 World
value_utf8::Héllo Wörld — ñoño
key_space :: value_space

# --- Parsing: T-013 (indented comment) --------------------------------
  # indented comment - must be ignored, not raise LexParseError

# --- Parsing: T-015 (whitespace-only lines) ---------------------------
   
	

# --- Parsing: T-016, T-017 ---------------------------------------------
emoji_sequence::Family: 👨‍👩‍👧‍👦
huge_spaces::correct string                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                

# --- Escape Sequences: T-101 to T-113 ----------------------------------
escape_newline::Line 1\nLine 2
escape_tab::Col1\tCol2
escape_backslash::C:\\Program Files\\Lexis
escape_quote::She said \"hello\"
escape_carriage_return::before\rafter
escape_backspace::before\bafter
escape_vertical_tab::before\vafter
escape_unknown::unknown \q escape passes through
escape_trailing_backslash::trailing backslash is literal\
escape_combined::Name:\t%s\nScore:\t%d
escape_null::before\0after
escape_escaped_n::literal \\n character
passthrough_arg::Hello %s

# --- Placeholders: T-201 to T-241 --------------------------------------
placeholder_string::Hello %s
placeholder_integer::You have %d messages
placeholder_float::Rating: %f
placeholder_hex::Hex value: %x
placeholder_octal::Octal value: %o
placeholder_char::Char: %c
placeholder_percent::100%% completed
placeholder_multiple::User %s has %d points and rating %.2f
bool_spec::Active: %d, Blocked: %d
null_spec::Value: %s
pad_neg_int::%05d
float_prec::%08.2f
neg_hex::%x
two_placeholders::%s %s
invalid_specifier::Value: %q
adjacent_percent::%%%%s %s
one_placeholder::Hello %s
float_default_prec::%f
float_zero_prec::%.0f
string_width_right::%5s
string_width_left::%-5s
string_zero_pad::%05s
pos_test::Hello %s, code %d
trailing_percent::Value ends with %
i_spec::Count: %i
unknown_specs::%u %X %e %g %b %n %p
positional_attempt_2::Hello %1$s
width_codepoint::%5s
numeric_string::%d
float_two_prec::%.2f

# --- Edge Cases: T-303 (T-301/T-302 retired; see value_with_hash / value_with_separator above) ---
triple_colon::key:::value with triple colon

# --- Demo-only content, not tied to any test ID ------------------------
welcome::Welcome %s to Lexis!
app_name::Lexis
