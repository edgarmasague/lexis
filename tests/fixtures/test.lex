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

# --- Added for the new cases: T-021 to T-024, T-114, T-242 to T-286 -------
# Parsing

# T-021 — Comment containing :: is a comment
# comment::with separator inside a comment

# T-022 — A line starting with # is never an entry
#hidden::comment that looks like an entry

# T-023 — Three colons after the key
colon_run:::tail

# T-024 — A single colon inside a key
url:home::Home page

# Escape sequences

# T-114 — Escapes are processed before placeholders
escape_then_percent::\\%s

# Placeholders

# T-242 — Unsupported flags are literal
lit_flags::%+d|% d|%#x

# T-243 — Length modifiers are literal
lit_length::%ld|%lld|%hd|%zu

# T-244 —  width and precision are literal
lit_star::%*d|%.*f

# T-245 — Precision with a specifier other than f is literal
lit_prec_s::%.3s|%.2d

# T-246 — Precision without digits is literal
lit_prec_empty::%.f

# T-247 — Flags in the wrong order are literal
lit_flag_order::%0-5d

# T-248 — % d inside ordinary text is not a placeholder
lit_percent_space::50% discount

# T-249 — Placeholder cut off by the end of the value is literal
lit_cut_off_width::Width cut off %5
lit_cut_off_flags::Flags cut off %-0

# T-250 — A literal sequence does not consume an argument
lit_then_real::%q%s

# T-251 — Width at MAX_WIDTH
width_max::%1024d

# T-252 — Width above MAX_WIDTH is literal
width_over::%1025d

# T-253 — A very long width does not overflow
width_overflow::%99999999999999999999d

# T-254 — Precision at MAX_PREC
prec_max::%.15f

# T-255 — Precision above MAX_PREC is literal
prec_over::%.16f
prec_overflow::%.99999999999999999999f

# T-256 — - takes precedence over 0
pad_left_zero::%-05d|

# T-257 — 0 is ignored for %c
pad_char_zero::%03c|

# T-258 — Zero padding with a negative float
pad_neg_float::%08.2f

# T-259 — Zero padding with a negative hexadecimal
pad_neg_hex::%05x

# T-260 — Left-aligned float
pad_left_float::%-8.2f|

# T-261 — A value longer than the width is not truncated
pad_no_truncate::%2d

# T-262 — Width counts a character outside the BMP as one
width_emoji::%5s|

# T-263 — Width counts code points, not grapheme clusters
width_combining::%5s|

# T-264 — %s with an integer
s_int::%s
s_int_min::%s

# T-265 — %s with a float
s_float::%s
s_float_int::%s
s_float_tiny::%s

# T-266 — %s with a boolean is an error
s_bool::%s

# T-267 — %s with null is an error (optional, requires a null type)
s_null::%s

# T-268 — %s with a string that is not valid UTF-8 (optional, only where such a value can be built)
s_bad_utf8::%s

# T-269 — %d rejects strings that are not plain integers
d_str_float::%d
d_str_plus::%d
d_str_space::%d
d_str_empty::%d

# T-270 — %d at the lower 64-bit limit
d_int_min::%d

# T-271 — %d outside the 64-bit range is an error
d_float_big::%d
d_str_big::%d

# T-272 — %d with NaN or Infinity is an error
d_nan::%d
d_inf::%d

# T-273 — %x and %o edge values
hex_zero::%x
hex_int_min::%x
oct_neg::%o

# T-274 — %x uses the same conversion errors as %d
hex_frac::%x
hex_bad_str::%x

# T-275 — %c with an invalid code point is an error
char_zero::%c
char_neg::%c
char_surr_lo::%c
char_surr_hi::%c

# T-276 — %c valid code points
char_astral::%c
char_max::%c
char_numstr::%c

# T-277 — %c with a one-character string is an error
char_str::%c

# T-278 — %f without a precision removes trailing zeros
f_def_int_valued::%f
f_def_hundred::%f
f_def_sum::%f
f_def_third::%f
f_def_round::%f
f_def_big::%f
f_def_intarg::%f

# T-279 — %f without a precision: tiny values become 0
f_def_tiny::%f
f_def_tiny_neg::%f
f_def_negzero::%f
f_def_edge::%f

# T-280 — %.Nf keeps the requested decimals
f_prec_small::%.7f
f_prec_pad::%.2f
f_prec_intarg::%.2f
f_prec_one::%.2f

# T-281 — Rounding: more ties away from zero
f_tie_half::%.0f
f_tie_onehalf::%.0f

# T-282 — A negative value that rounds to zero has no minus sign
f_neg_tiny::%.2f

# T-283 — %f with a decimal string
f_str::%f
f_str_exp::%f
f_str_bad::%f

# T-284 — Large float with an explicit precision
f_big_prec::%.2f

# T-285 — %f with a boolean is an error
f_bool::%f

# T-286 — %%s is literal text and consumes no argument
pct_pct_s::%%s

# --- Demo-only content, not tied to any test ID ------------------------
welcome::Welcome %s to Lexis!
app_name::Lexis
