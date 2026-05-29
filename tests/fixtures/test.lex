# Lexis Official Test File
# All compliant runtimes must produce identical outputs for all entries.
# See tests/tests.md for full list of expected values.

# Parsing T-001 to T-011
simple::Hello World
simple_with_arg::Hello %s
two_args::Hello %s you have %d messages
empty_value::
key_trimmed ::Value with spaces around key
UPPERCASE_KEY::uppercase key test
mixed_Case_Key::mixed case key test
value_with_hash::#this value starts with hash
value_with_separator::value :: contains :: separators
value_leading_spaces::   leading spaces are trimmed
value_trailing_spaces::trailing spaces are preserved   
value_unicode::Hello 👋 World
value_utf8::Héllo Wörld — ñoño

# Escape Sequences T-020 to T-029

escape_newline::Line 1\nLine 2
escape_tab::Col1\tCol2
escape_backslash::C:\\Program Files\\Lexis
escape_quote::She said \"hello\"
escape_carriage_return::before\rafter
escape_backspace::before\bafter
escape_vertical_tab::before\vafter
escape_combined::Name:\t%s\nScore:\t%d
escape_unknown::unknown \q escape passes through
escape_trailing_backslash::trailing backslash is literal\

# Placeholders T-030 to T-037

placeholder_string::Hello %s
placeholder_integer::You have %d messages
placeholder_float::Rating: %f
placeholder_hex::Hex value: %x
placeholder_octal::Octal value: %o
placeholder_char::Char: %c
placeholder_percent::100%% completed
placeholder_multiple::User %s has %d points and rating %.2f

# Edge Cases T-038 to T-040

not_a_comment::#not a comment
double_colon::key::value with double colon in value
triple_colon::key:::value with triple colon

# Real-World examples

welcome::Welcome %s to Lexis!
error_file::File not found: %s
error_permission::Permission denied: %s
info_loaded::Loaded %d translations from %s
progress::Progress: %d%% completed
app_name::Lexis
app_version::v%s