#!/usr/bin/env bash
# lexis.sh - LEXIS Independent Translation Engine
# Official Bash Runtime

# Global state
declare -A _LEXIS_RAW_TRANSLATIONS
declare -A _LEXIS_CACHE_TRANSLATIONS
_LEXIS_LANG_DIR=""
_LEXIS_LOCALE=""
_LEXIS_FALLBACK_LOCALE="en"
_LEXIS_FILEPATH=""
_LEXIS_NAME="main"
# Return buffers: Bash has no return values, so internal functions leave
# their result here instead of printing it (printing would need a subshell).
_LEXIS_R=""        # result of internal functions
_LEXIS_KEY=""      # result of _lexis_parse_line (empty = skipped line)
_LEXIS_VALUE=""
# Constants
_LEXIS_DEFAULT_LOCALE="en"
_LEXIS_MAX_WIDTH=1024
_LEXIS_MAX_PRECISION=15
_LEXIS_WIDTH_DIGITS=4      # digits of _LEXIS_MAX_WIDTH
_LEXIS_PRECISION_DIGITS=2  # digits of _LEXIS_MAX_PRECISION
_LEXIS_DEFAULT_PRECISION=6   # %f without a precision

# Debug mode: set LEXIS_DEBUG=1 to enable
LEXIS_DEBUG="${LEXIS_DEBUG:-0}"

_lexis_debug() {
    # Print a debug line to stderr when LEXIS_DEBUG=1.
    [[ "$LEXIS_DEBUG" == 1 ]] && printf '[lexis:debug] %s\n' "$*" >&2
    return 0
}

_lexis_err() {
    # Print an error to stderr and return its code.
    # Args:
    #   $1  — kind: LexFileNotFoundError, LexKeyNotFoundError, LexParseError or LexFormatError
    #   $@  — message
    # Returns:
    #   2, 3, 4 or 5 depending on the kind
    # $1 error kind, rest: message
    local kind="$1"; shift
    printf '[lexis] %s: %s\n' "$kind" "$*" >&2
    case "$kind" in
        LexFileNotFoundError) return 2 ;;
        LexKeyNotFoundError)  return 3 ;;
        LexParseError)        return 4 ;;
        *)                    return 5 ;;
    esac
}
 
_lexis_rep() {
    # Repeat a string n times.
    # Args:
    #   $1  — string to repeat
    #   $2  — n: number of repetitions
    # Returns:
    #   Result in _LEXIS_R
        local c="$1"
    local n="$2"
    local r=""
    while (( n > 0 )); do (( n & 1 )) && r+="$c"; c+="$c"; n=$(( n >> 1 )); done
    _LEXIS_R="$r"
}

_lexis_detect_locale() {
    # Detect system locale from $LANG.
    # Returns "en" for C, POSIX, empty, missing or unusable values.
    # Keeps only language and region (zh_Hans_CN -> zh_CN).
    # Returns:
    #   "language" or "language_REGION" in _LEXIS_R
    local LC_ALL=C
    local lang="${LANG:-}"
    local us
    lang="${lang%%[.@]*}"
    lang="${lang#"${lang%%[![:space:]]*}"}"; lang="${lang%"${lang##*[![:space:]]}"}"
    if [[ -z "$lang" || "$lang" == "C" || "$lang" == "POSIX" ]]; then
        _LEXIS_R="$_LEXIS_DEFAULT_LOCALE"; return 0
    fi
    # Strip encoding (e.g., .UTF-8)
    lang="${lang//-/_}"; us="${lang//[^_]/}"
    # zh_Hans_CN -> zh_CN: keep only language and region
    (( ${#us} > 1 )) && lang="${lang%%_*}_${lang##*_}"
    if [[ "$lang" =~ ^([A-Za-z0-9]+)(_([A-Za-z0-9]+))?$ ]]; then
        _LEXIS_R="${BASH_REMATCH[1],,}"
        [[ -n "${BASH_REMATCH[3]}" ]] && _LEXIS_R+="_${BASH_REMATCH[3]^^}"
    else
        _LEXIS_R="$_LEXIS_DEFAULT_LOCALE"   # a garbage LANG must not break loading
    fi

}

_lexis_resolve_filepath() {
    # Resolve the .lex file path with fallback support.
    # Mutates _LEXIS_FILEPATH and _LEXIS_LOCALE directly.
    # Args:
    #   $1 — lang_dir: directory containing .lex files
    #   $2 — locale: requested locale code
    #   $3 — fallback: fallback locale code
    #   $4  — name: entry-file name for the directory layout
    # Returns:
    #   0 on success, 2 if an input is invalid or no file exists
    # Raises:
    #   LexFileNotFoundError to stderr
        local LC_ALL=C
    local dir="$1"
    local name="$4"
    local code abs i
    local -a codes=()
    local -a paths=()
    local -a found=()
    for code in "$2" "$3"; do
        code="${code//-/_}"
        [[ "$code" =~ ^([A-Za-z0-9]+)(_([A-Za-z0-9]+))?$ ]] || {
            _lexis_err LexFileNotFoundError "Invalid locale code: '$code'"; return $?; }
        code="${BASH_REMATCH[1],,}"
        [[ -n "${BASH_REMATCH[3]}" ]] && code+="_${BASH_REMATCH[3]^^}"
        codes+=("$code")
    done
    [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]] || {
        _lexis_err LexFileNotFoundError "Invalid entry-file name: '$name'"; return $?; }
    [[ -d "$dir" ]] || {
        _lexis_err LexFileNotFoundError "Invalid language directory: '$dir'"; return $?; }
    abs="$(cd -- "$dir" && pwd)"
    # Every place to look, in order: es_VE, then es, then the fallback
    for code in "${codes[@]}"; do
        paths+=("$abs/$code.lex" "$abs/$code/$name.lex"); found+=("$code" "$code")
        if [[ "$code" == *_* ]]; then
            paths+=("$abs/${code%%_*}.lex" "$abs/${code%%_*}/$name.lex")
            found+=("${code%%_*}" "${code%%_*}")
        fi
    done
    for i in "${!paths[@]}"; do
        if [[ -f "${paths[i]}" ]]; then
            _LEXIS_LOCALE="${found[i]}"; _LEXIS_FILEPATH="${paths[i]}"; return 0
        fi
    done
    _lexis_err LexFileNotFoundError \
        "No .lex file found for locale '${codes[0]}' (fallback '${codes[1]}') in '$dir'"
}

_lexis_unescape() {
    # Process escape sequences in a raw value string.
    # Called lazily by _lexis_cache_fetch on first access — never during parsing.
    # Args:
    #   $1 — raw value string from .lex file
    # Returns:
    #   Value with escape sequences converted, in _LEXIS_R
    local LC_ALL=C
    local v="$1"
    local out=""
    local pre
    while [[ "$v" == *\\* ]]; do
        pre="${v%%\\*}";
        out+="$pre";
        v="${v:${#pre}}"
        if (( ${#v} == 1 )); then break; fi          # lone trailing backslash stays
        case "${v:1:1}" in
            n) out+=$'\n' ;;  t) out+=$'\t' ;;  r) out+=$'\r' ;;
            b) out+=$'\b' ;;  v) out+=$'\v' ;;
            '"') out+='"' ;;  '\') out+='\' ;;
            *) out+="\\${v:1:1}" ;;
        esac
        v="${v:2}"
    done
    _LEXIS_R="$out$v"

}

_lexis_parse_line() {
    # Parse a single line from a .lex file.
    # Skips empty lines and comments. Validates structure and checks for duplicates.
    # Does not process escape sequences — values are stored raw.
    # Args:
    #   $1 — raw_line: raw line string including line endings
    #   $2 — line_num: 1-based line number for error reporting
    #   $3 — lf: 1 if the line ended with an LF, 0 for a last line without one
    # Returns:
    #   0 on success or skipped line, 1 on parse error
    # Raises:
    #   LexParseError to stderr on malformed lines or duplicate keys
        local LC_ALL=C
        local line="$1"
        local n="$2"
        local key value stripped
    _LEXIS_KEY=""; _LEXIS_VALUE=""
    # CR is dropped only as part of a CRLF; a lone CR is content
    (( $3 )) && line="${line%$'\r'}"
    stripped="${line#"${line%%[![:space:]]*}"}"
    # Skip empty lines or comments
    [[ -z "$stripped" || "$stripped" == \#* ]] && return 0
    [[ "$line" == *::* ]] || {
        _lexis_err LexParseError "Malformed line $n in $_LEXIS_FILEPATH: missing '::' separator"; return $?; }
    key="${line%%::*}"; value="${line#*::}"
    key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
    [[ -n "$key" ]] || {
        _lexis_err LexParseError "Malformed line $n in $_LEXIS_FILEPATH: empty key"; return $?; }
    [[ -z "${_LEXIS_RAW_TRANSLATIONS["$key"]+x}" ]] || {
        _lexis_err LexParseError "Duplicate key '$key' at line $n in $_LEXIS_FILEPATH"; return $?; }
    _LEXIS_KEY="$key"; _LEXIS_VALUE="${value#"${value%%[![:space:]]*}"}"
}

_lexis_load_file() {
    # Load and parse entire .lex file at _LEXIS_FILEPATH  into _LEXIS_RAW_TRANSLATIONS.
    # Clears both raw and cache translations before loading.
    # Args:
    #   $1 — filepath: absolute path to .lex file
    # Returns:
    #   0 on success, 2 or 4 on failure
    # Raises:
    #   LexFileNotFoundError to stderr if file does not exist
    #   LexParseError to stderr on invalid UTF-8 or malformed file content
    local LC_ALL=C
    local line
    local n=0
    local lf=1
    local bom=$'\xEF\xBB\xBF'
    _LEXIS_RAW_TRANSLATIONS=(); _LEXIS_CACHE_TRANSLATIONS=()
    [[ -r "$_LEXIS_FILEPATH" ]] || {
        _lexis_err LexFileNotFoundError "File not found: $_LEXIS_FILEPATH"; return $?; }
    local have_iconv=0
    if command -v iconv >/dev/null 2>&1; then
        have_iconv=1
        iconv -f UTF-8 -t UTF-8 < "$_LEXIS_FILEPATH" >/dev/null 2>&1 || {
            _lexis_err LexParseError "Invalid UTF-8 in $_LEXIS_FILEPATH"; return $?; }
    fi
    while :; do
        # A last line without LF is still a line
        IFS= read -r line || { lf=0; [[ -n "$line" ]] || break; }
        n=$(( n + 1 ))
        # Without iconv, validate each line with the pure-Bash check
        if (( ! have_iconv )); then
            _lexis_utf8_valid "$line" || {
                _lexis_err LexParseError "Invalid UTF-8 in $_LEXIS_FILEPATH"; return $?; }
        fi
        (( n == 1 )) && line="${line#"$bom"}"
        _lexis_parse_line "$line" "$n" "$lf" || return $?
        [[ -n "$_LEXIS_KEY" ]] && _LEXIS_RAW_TRANSLATIONS["$_LEXIS_KEY"]="$_LEXIS_VALUE"
        (( lf )) || break
    done < "$_LEXIS_FILEPATH"
    [[ "$LEXIS_DEBUG" == 1 ]] && printf "[lexis:debug] Loaded '%s' - %d keys\n" \
        "$_LEXIS_FILEPATH" "${#_LEXIS_RAW_TRANSLATIONS[@]}" >&2
    return 0

}

# --- UTF-8 helpers ----------------------------------------------------------

_lexis_build_utf8_re() {
    # Build the regex that matches a whole well-formed UTF-8 string:
    # no overlong forms, no surrogates, nothing above U+10FFFF.
    local LC_ALL=C
    local c=$'[\x80-\xBF]'
    _LEXIS_UTF8_RE="^([^"$'\x80'-$'\xFF'"]|"$'[\xC2-\xDF]'"$c|"$'\xE0[\xA0-\xBF]'"$c|"$'[\xE1-\xEC\xEE\xEF]'"$c$c|"$'\xED[\x80-\x9F]'"$c|"$'\xF0[\x90-\xBF]'"$c$c|"$'[\xF1-\xF3]'"$c$c$c|"$'\xF4[\x80-\x8F]'"$c$c)*\$"
}
_lexis_build_utf8_re

_lexis_utf8_valid() {
    # Check that a string is well-formed UTF-8.
    # Args:
    #   $1 — string to check
    # Returns:
    #   0 if valid, 1 if not
    local LC_ALL=C
    [[ "$1" == *[!$'\001'-$'\177']* ]] || return 0   # pure ASCII (a Bash string has no NUL)
    [[ "$1" =~ $_LEXIS_UTF8_RE ]]
}

_lexis_cplen() {
    # Count Unicode code points: every byte except UTF-8 continuation bytes.
    # Args:
    #   $1 — string
    # Returns:
    #   Count in _LEXIS_CPN
    local LC_ALL=C
    local s="$1"
    s="${s//[$'\x80'-$'\xBF']/}"
    _LEXIS_CPN=${#s}
}

_lexis_chr() {
    # Encode one code point as UTF-8 (printf only emits the bytes).
    # Args:
    #   $1 — code point, already validated (1..0x10FFFF, no surrogates)
    # Returns:
    #   The character in _LEXIS_R
    local cp="$1" f="" h b
    local -a bytes
    if   (( cp < 0x80 ));    then bytes=("$cp")
    elif (( cp < 0x800 ));   then bytes=($(( 0xC0 | (cp >> 6) )) $(( 0x80 | (cp & 63) )))
    elif (( cp < 0x10000 )); then bytes=($(( 0xE0 | (cp >> 12) )) $(( 0x80 | ((cp >> 6) & 63) )) $(( 0x80 | (cp & 63) )))
    else bytes=($(( 0xF0 | (cp >> 18) )) $(( 0x80 | ((cp >> 12) & 63) )) $(( 0x80 | ((cp >> 6) & 63) )) $(( 0x80 | (cp & 63) )))
    fi
    for b in "${bytes[@]}"; do printf -v h '\\x%02x' "$b"; f+="$h"; done
    printf -v _LEXIS_R '%b' "$f"
}

# --- Number helpers ---------------------------------------------------------

_lexis_int() {
    # Parse a plain decimal integer that fits a signed 64-bit integer.
    # A Bash argument is always text, so "3.0" or "+5" are invalid here.
    # Args:
    #   $1 — argument
    # Returns:
    #   0 and _LEXIS_NEG (0/1) + _LEXIS_DIG (digits, no leading zeros), or 1
    local LC_ALL=C
    local d lim
    [[ "$1" =~ ^(-?)([0-9]+)$ ]] || return 1
    d="${BASH_REMATCH[2]}"
    _LEXIS_NEG=0; [[ -n "${BASH_REMATCH[1]}" ]] && _LEXIS_NEG=1
    d="${d#"${d%%[!0]*}"}"; d="${d:-0}"
    [[ "$d" == 0 ]] && _LEXIS_NEG=0
    (( ${#d} > 19 )) && return 1
    if (( ${#d} == 19 )); then
        lim=9223372036854775807; (( _LEXIS_NEG )) && lim=9223372036854775808
        [[ "$d" > "$lim" ]] && return 1
    fi
    _LEXIS_DIG="$d"
}

_lexis_tobase() {
    # Write a non-negative integer in base 16 or 8.
    # Args:
    #   $1 — magnitude as decimal digits (at most 2^63)
    #   $2 — base: 16 or 8
    # Returns:
    #   Digits in _LEXIS_R
    local m r="" bits mask digits=0123456789abcdef
    if [[ "$1" == 9223372036854775808 ]]; then   # 2^63 does not fit a signed integer
        if (( $2 == 16 )); then _LEXIS_R=8000000000000000; else _LEXIS_R=1000000000000000000000; fi
        return 0
    fi
    m=$(( 10#$1 ))
    if (( m == 0 )); then _LEXIS_R=0; return 0; fi
    if (( $2 == 16 )); then bits=4; mask=15; else bits=3; mask=7; fi
    while (( m > 0 )); do r="${digits:$(( m & mask )):1}$r"; m=$(( m >> bits )); done
    _LEXIS_R="$r"
}

_lexis_float() {
    # %f: decimal string -> nearest IEEE 754 double (ties to even) -> its exact
    # value -> rounded half away from zero to the requested decimals.
    # Uses bc for the big-integer arithmetic.
    # Args:
    #   $1 — argument (plain decimal string)
    #   $2 — decimals
    #   $3 — 1 to remove trailing zeros (no precision given), else 0
    # Returns:
    #   0 and the text in _LEXIS_R; 1 if the argument is invalid or |x| >= 2^63;
    #   2 if bc is missing
    local LC_ALL=C
    local sign int frac digits k res text="" decimals="$2"
    [[ "$1" =~ ^(-?)([0-9]+)(\.([0-9]+))?$ ]] || return 1
    sign="${BASH_REMATCH[1]}"; int="${BASH_REMATCH[2]}"; frac="${BASH_REMATCH[4]}"
    digits="${int}${frac}"; digits="${digits#"${digits%%[!0]*}"}"; digits="${digits:-0}"
    k=${#frac}
    command -v bc >/dev/null 2>&1 || return 2
    res="$(BC_LINE_LENGTH=0 bc 2>/dev/null <<EOF
scale=0
define l2(x) { auto c; c=0; while (x>0) { x/=2; c+=1; }; return (c); }
n=$digits
d=10^$k
t=10^$decimals
if (n==0) { print "0\n"; halt; }
p=53-l2(n)+l2(d)
while (1) {
  if (p>=0) { a=n*2^p; b=d; } else { a=n; b=d*2^(-p); }
  q=a/b
  if (q>=2^53) { p-=1; continue; }
  break
}
r=a-q*b
if (2*r>b || (2*r==b && q%2==1)) { q+=1; }
if (q==2^53) { q=2^52; p-=1; }
if (p>=0) { big=(q>=2^63*2^p); } else { big=(q*2^(-p)>=2^63); }
if (big) { print "E\n"; halt; }
if (p>0) { res=(2*q*t+2^p)/2^(p+1); } else { res=q*2^(-p)*t; }
print res, "\n"
EOF
)"
    [[ "$res" == E ]] && return 1
    [[ "$res" =~ ^[0-9]+$ ]] || return 2
    local is_zero=0; [[ "$res" == 0 ]] && is_zero=1   # a value that rounds to zero has no sign
    if (( decimals > 0 )); then
        if (( ${#res} <= decimals )); then
            _lexis_rep 0 $(( decimals + 1 - ${#res} )); res="$_LEXIS_R$res"
        fi
        text="${res:0:${#res}-decimals}.${res:${#res}-decimals}"
    else
        text="$res"
    fi
    if (( $3 )) && [[ "$text" == *.* ]]; then
        text="${text%"${text##*[!0]}"}"; text="${text%.}"
    fi
    [[ -n "$sign" ]] && (( ! is_zero )) && text="-$text"
    _LEXIS_R="$text"
}

_lexis_pad() {
    # Pad text to its width. Width counts code points.
    # Args:
    #   $1 — text, $2 — specifier, $3 — "-" flag, $4 — "0" flag, $5 — width
    # Returns:
    #   Padded text in _LEXIS_R
    local text="$1" n
    _lexis_cplen "$text"
    n=$(( $5 - _LEXIS_CPN ))
    if (( n <= 0 )); then _LEXIS_R="$text"; return 0; fi
    if [[ -n "$3" ]]; then                        # "-" wins over "0"
        _lexis_rep " " "$n"; _LEXIS_R="$text$_LEXIS_R"
    elif [[ -n "$4" && "$2" == [dixof] ]]; then   # "0" only applies to numbers
        _lexis_rep 0 "$n"
        if [[ "$text" == -* ]]; then _LEXIS_R="-$_LEXIS_R${text:1}"; else _LEXIS_R="$_LEXIS_R$text"; fi
    else
        _lexis_rep " " "$n"; _LEXIS_R="$_LEXIS_R$text"
    fi
}

_lexis_arg_error() {
    # LexFormatError for an argument that is invalid for its specifier.
    _lexis_err LexFormatError "Invalid argument '$1' for '%$2'"
}

_lexis_cache_fetch() {
    # Fetch a processed value from the cache.
    # On first access, calls _lexis_unescape and stores the result in the cache.
    # Args:
    #   $1 — key: translation key to look up
    # Returns:
    #   0 and the unescaped value in _LEXIS_R, or 3 if the key does not exist
    local key="$1"
    if [[ -z "${_LEXIS_RAW_TRANSLATIONS[$key]+x}" ]]; then
        _lexis_err LexKeyNotFoundError "Key not found: '$key'"; return $?
    fi
    if [[ -z "${_LEXIS_CACHE_TRANSLATIONS[$key]+x}" ]]; then
        _lexis_unescape "${_LEXIS_RAW_TRANSLATIONS[$key]}"
        _LEXIS_CACHE_TRANSLATIONS[$key]="$_LEXIS_R"
    fi
    _LEXIS_R="${_LEXIS_CACHE_TRANSLATIONS[$key]}"
}

_lexis_format() {
    # Lexis' own printf: apply placeholders to an unescaped template.
    # Anything that is not a valid placeholder stays literal and uses no
    # argument. Arguments are never scanned again.
    # Args:
    #   $1  — template: value after escape processing
    #   $@  — values for the placeholders
    # Returns:
    #   0 and the text in _LEXIS_R, or 5 (LexFormatError) if an argument is
    #   missing or invalid for its specifier
    local LC_ALL=C
    local template="$1"; shift
    local -a args=("$@")
    local nargs=$# out="" rest="$template" used=0
    local pre match left zero wd pd spec has_prec width decimals arg text cp rc
    local re='^%(%|(-)?(0)?([0-9]+)?(\.([0-9]+))?([sdifxoc]))'
    while [[ "$rest" == *%* ]]; do
        pre="${rest%%\%*}"
        out+="$pre"; rest="${rest:${#pre}}"
        # "%%" is a literal "%"; a "%" that starts nothing valid is literal too
        if [[ ! "$rest" =~ $re ]]; then out+="%"; rest="${rest:1}"; continue; fi
        match="${BASH_REMATCH[0]}"
        left="${BASH_REMATCH[2]}"; zero="${BASH_REMATCH[3]}"; wd="${BASH_REMATCH[4]}"
        has_prec=0; [[ -n "${BASH_REMATCH[5]}" ]] && has_prec=1
        pd="${BASH_REMATCH[6]}"; spec="${BASH_REMATCH[7]}"
        rest="${rest:${#match}}"
        if [[ "${BASH_REMATCH[1]}" == % ]]; then out+="%"; continue; fi
        # Out of limits: stays literal and uses no argument
        wd="${wd#"${wd%%[!0]*}"}"; pd="${pd#"${pd%%[!0]*}"}"
        if (( ${#wd} > _LEXIS_WIDTH_DIGITS )) || (( 10#${wd:-0} > _LEXIS_MAX_WIDTH )); then
            out+="$match"; continue
        fi
        if (( has_prec )) && { [[ "$spec" != f ]] || (( ${#pd} > _LEXIS_PRECISION_DIGITS )) \
                || (( 10#${pd:-0} > _LEXIS_MAX_PRECISION )); }; then
            out+="$match"; continue
        fi
        width=$(( 10#${wd:-0} ))
        if (( has_prec )); then decimals=$(( 10#${pd:-0} )); else decimals=$_LEXIS_DEFAULT_PRECISION; fi
        # The argument
        if (( used >= nargs )); then
            _lexis_err LexFormatError "Missing argument for '%$spec'"; return $?
        fi
        arg="${args[used]}"; used=$(( used + 1 ))
        case "$spec" in
            s)  _lexis_utf8_valid "$arg" || { _lexis_arg_error "$arg" "$spec"; return $?; }
                text="$arg" ;;
            d|i) _lexis_int "$arg" || { _lexis_arg_error "$arg" "$spec"; return $?; }
                text="$_LEXIS_DIG"; (( _LEXIS_NEG )) && text="-$text" ;;
            x|o) _lexis_int "$arg" || { _lexis_arg_error "$arg" "$spec"; return $?; }
                if [[ "$spec" == x ]]; then _lexis_tobase "$_LEXIS_DIG" 16; else _lexis_tobase "$_LEXIS_DIG" 8; fi
                text="$_LEXIS_R"; (( _LEXIS_NEG )) && text="-$text" ;;
            c)  _lexis_int "$arg" || { _lexis_arg_error "$arg" "$spec"; return $?; }
                if (( _LEXIS_NEG )) || [[ "$_LEXIS_DIG" == 0 ]] || (( ${#_LEXIS_DIG} > 7 )); then
                    _lexis_arg_error "$arg" "$spec"; return $?
                fi
                cp=$(( 10#$_LEXIS_DIG ))
                if (( cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) )); then
                    _lexis_arg_error "$arg" "$spec"; return $?
                fi
                _lexis_chr "$cp"; text="$_LEXIS_R" ;;
            f)  _lexis_float "$arg" "$decimals" $(( ! has_prec )); rc=$?
                if (( rc == 2 )); then _lexis_err LexFormatError "%f needs bc, which is not installed"; return $?; fi
                (( rc )) && { _lexis_arg_error "$arg" "$spec"; return $?; }
                text="$_LEXIS_R" ;;
        esac
        _lexis_pad "$text" "$spec" "$left" "$zero" "$width"
        out+="$_LEXIS_R"
    done
    _LEXIS_R="$out$rest"
}

# Public API

lexis_load() {
    # Load a .lex file from the given directory.
    # Auto-detects locale from $LANG if not provided.
    # Falls back to fallback_locale if the requested locale file does not exist.
    # Args:
    #   $1 — lang_dir: directory containing .lex files
    #   $2 — locale: locale code (optional, auto-detected if omitted)
    #   $3 — fallback_locale: fallback locale code (optional, default "en")
    #   $4 — name: entry-file name for the directory layout (optional, default "main")
    # Returns:
    #   0 on success, or the error code (2 or 4) on failure
    # Raises:
    #   LexFileNotFoundError to stderr if no suitable file is found
    #   LexParseError to stderr if the file is malformed
    local lang_dir="${1:-}"
    local locale="${2:-}"
    local fallback_locale="${3:-$_LEXIS_DEFAULT_LOCALE}"
    local name="${4:-main}"
    [[ -n "$locale" ]] || { _lexis_detect_locale; locale="$_LEXIS_R"; }
    _lexis_resolve_filepath "$lang_dir" "$locale" "$fallback_locale" "$name" || return $?
    _LEXIS_LANG_DIR="$lang_dir"; _LEXIS_FALLBACK_LOCALE="$fallback_locale"; _LEXIS_NAME="$name"
    _lexis_load_file
}

lexis_get() {
    # Get a translation by key with optional printf-style formatting.
    # Escape sequences are processed on first access (lazy).
    # Args:
    #   $1  — key: translation key
    #   $@  — values for placeholders (%s, %d, %f, %c, etc.)
    # Returns:
    #   Formatted translation string on stdout, without a trailing newline
    # Raises:
    #   LexKeyNotFoundError (3) or LexFormatError (5) to stderr
    local key="$1"
    shift
    _lexis_cache_fetch "$key" || return $?
    _lexis_format "$_LEXIS_R" "$@" || return $?
    printf '%s' "$_LEXIS_R"
}

lexis_get_or_default() {
    # Get a translation or return a default value if the key is not found.
    # Applies args to the default value if the translation is missing.
    # Always returns 0 — never fails.
    # Args:
    #   $1  — key: translation key
    #   $2  — default_value: fallback string if key not found
    #   $@  — values for placeholders
    # Returns:
    #   Formatted translation string or formatted default. Fails (5) only if
    #   formatting fails, exactly like lexis_get.
    local key="$1"
    local default_value="$2"
    shift 2
    if lexis_has "$key"; then lexis_get "$key" "$@"; return $?; fi
    if (( $# )); then _lexis_format "$default_value" "$@" || return $?; printf '%s' "$_LEXIS_R"
    else printf '%s' "$default_value"; fi
}

lexis_reload() {
    # Reload translations from the same directory, optionally switching locale.
    # Saves full state before attempting reload and restores it on failure.
    # Args:
    #   $1 — locale: new locale code (optional, keeps the current one if omitted)
    #   $2 — fallback_locale: new fallback locale code (optional, keeps previous if omitted)
    #   $3 — name: new entry-file name (optional, keeps the current one if omitted)
    # Returns:
    #   0 on success, or the error code (2 or 4) on failure
    # Raises:
    #   LexFileNotFoundError to stderr if new locale not found
    #   LexParseError to stderr if new file is malformed
    local new_locale="${1:-$_LEXIS_LOCALE}"
    local new_fallback="${2:-$_LEXIS_FALLBACK_LOCALE}"
    local new_name="${3:-$_LEXIS_NAME}"
    # Save current state in memory for rollback on failure
    local old_lang_dir="$_LEXIS_LANG_DIR"
    local old_locale="$_LEXIS_LOCALE"
    local old_fallback="$_LEXIS_FALLBACK_LOCALE"
    local old_filepath="$_LEXIS_FILEPATH"
    local old_name="$_LEXIS_NAME"
    local old_translations
    old_translations="$(declare -p _LEXIS_RAW_TRANSLATIONS _LEXIS_CACHE_TRANSLATIONS)"
    local rc=0
    lexis_load "$old_lang_dir" "$new_locale" "$new_fallback" "$new_name" || rc=$?
    if (( rc )); then
        # Restore previous state and report the error
        eval "${old_translations//declare -A/declare -gA}"
        _LEXIS_LANG_DIR="$old_lang_dir"
        _LEXIS_LOCALE="$old_locale"
        _LEXIS_FALLBACK_LOCALE="$old_fallback"
        _LEXIS_NAME="$old_name"
        _LEXIS_FILEPATH="$old_filepath"
    fi
    return $rc
}

lexis_keys() {
    # Return all loaded translation keys, one per line.
    # Returns:
    #   Keys from _LEXIS_RAW_TRANSLATIONS via printf
    (( ${#_LEXIS_RAW_TRANSLATIONS[@]} )) && printf '%s\n' "${!_LEXIS_RAW_TRANSLATIONS[@]}"
    return 0

}

lexis_len() {
    # Return the total number of loaded translation keys.
    # Returns:
    #   Integer count via printf
    printf '%d\n' "${#_LEXIS_RAW_TRANSLATIONS[@]}"
}

lexis_has() {
    # Check if a translation key exists.
    # Args:
    #   $1 — key: translation key to check
    # Returns:
    #   0 if key exists, 1 if not
    [[ -n "${_LEXIS_RAW_TRANSLATIONS[$1]+x}" ]]
}

lexis_clear() {
    # Clear the cache of processed values.
    # Raw translations and every other piece of state are kept, so the runtime
    # stays usable; the next lexis_get re-processes the escapes. Use
    # lexis_reload to reread the file.
    _LEXIS_CACHE_TRANSLATIONS=()
    _lexis_debug "cache cleared"
}

lexis_info() {
    # Print a snapshot of the runtime state, on one line.
    # Fields: locale, fallback_locale, lang_dir, name, filepath, keys, cached_keys.
    printf "Lexis(locale='%s', fallback_locale='%s', lang_dir='%s', name='%s', filepath='%s', keys=%d, cached_keys=%d)\n" \
        "$_LEXIS_LOCALE" "$_LEXIS_FALLBACK_LOCALE" "$_LEXIS_LANG_DIR" "$_LEXIS_NAME" "$_LEXIS_FILEPATH" \
        "${#_LEXIS_RAW_TRANSLATIONS[@]}" "${#_LEXIS_CACHE_TRANSLATIONS[@]}"
}

_main() {
    local lang_dir
    lang_dir="$(dirname "${BASH_SOURCE[0]}")/../../lang"
    if ! lexis_load "$lang_dir"; then
        printf '[lexis:demo] could not load lang dir: %s\n' "$lang_dir" >&2
        return 1
    fi
    lexis_info
    echo "---"
    lexis_get "welcome" "Lexis"
    lexis_get "modules_available"
    lexis_get "error_file" "foo.txt"
    echo "---"
    lexis_reload "en"
    lexis_get "welcome" "Lexis"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main
fi