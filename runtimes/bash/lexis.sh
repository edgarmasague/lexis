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

# Return buffer for functions that need to pass arrays back to callers.
declare -a _LEXIS_ARGS_RESULT=()

# Debug mode: set LEXIS_DEBUG=1 to enable
LEXIS_DEBUG="${LEXIS_DEBUG:-0}"

_lexis_debug() {
    # Print a debug message to stderr.
    # Only active when LEXIS_DEBUG=1.
    # Args:
    #   $@ — message to print
    [[ "$LEXIS_DEBUG" == "1" ]] && printf '[lexis:debug] %s\n' "$*" >&2
}

_lexis_trim() {
    # Strip leading and trailing whitespace from a string.
    # Args:
    #   $1 — input string
    # Returns:
    #   Trimmed string via printf
    local value="$1"
    # Remove leading whitespace
    value="${value#"${value%%[![:space:]]*}"}"
    # Remove trailing whitespace
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

_lexis_unescape() {
    # Process escape sequences in a raw value string.
    # Called lazily by _lexis_cache_fetch on first access — never during parsing.
    # Args:
    #   $1 — raw value string from .lex file
    # Returns:
    #   Value with escape sequences converted via printf
    local value="$1"
    local result=""
    local i=0
    local len=${#value}
    while (( i < len )); do
        local char="${value:$i:1}"
        if [[ "$char" == "\\" && $((i + 1)) -lt $len ]]; then
            local next="${value:$((i + 1)):1}"
            case "$next" in
                n)  result+=$'\n' ;;
                t)  result+=$'\t' ;;
                r)  result+=$'\r' ;;
                b)  result+=$'\b' ;;
                v)  result+=$'\v' ;;
                \") result+='"' ;;
                \\) result+=$'\\' ;;
                *)  result+="\\$next" ;;
            esac
            ((i += 2))
        else
            result+="$char"
            ((i++))
        fi
    done
    printf '%s' "$result"
}

_lexis_detect_locale() {
    # Detect system locale from $LANG.
    # Returns "en" for C, POSIX, empty, or missing.
    local lang="${LANG:-}"
    if [[ -z "$lang" || "$lang" == "C" || "$lang" == "POSIX" ]]; then
        printf '%s' "en"
        return
    fi
    # Strip encoding (e.g., .UTF-8)
    lang="${lang%%.*}"
    # Normalize hyphen to underscore
    lang="${lang//-/_}"
    # Extract language code, lowercase
    printf '%s' "${lang%%_*}" | tr '[:upper:]' '[:lower:]'
}

_lexis_resolve_filepath() {
    # Resolve the .lex file path with fallback support.
    # Mutates _LEXIS_FILEPATH and _LEXIS_LOCALE directly.
    # Args:
    #   $1 — lang_dir: directory containing .lex files
    #   $2 — locale: requested locale code
    #   $3 — fallback: fallback locale code
    # Returns:
    #   0 on success, 1 if neither file exists
    # Raises:
    #   LexFileNotFoundError to stderr if no file found
    local lang_dir="$1"
    local locale="$2"
    local fallback="$3"
    local filepath="${lang_dir}/${locale}.lex"
    local fallback_filepath="${lang_dir}/${fallback}.lex"
    if [[ -f "$filepath" ]]; then
        _LEXIS_FILEPATH="$filepath"
        _LEXIS_LOCALE="$locale"
        return 0
    fi
    if [[ -f "$fallback_filepath" ]]; then
        _lexis_debug "locale '${locale}' not found, falling back to '${fallback}'"
        _LEXIS_FILEPATH="$fallback_filepath"
        _LEXIS_LOCALE="$fallback"
        return 0
    fi
    printf '[lexis] LexFileNotFoundError: no .lex file found for locale "%s" (fallback "%s") in "%s"\n' \
        "$locale" "$fallback" "$lang_dir" >&2
    return 1
}

_lexis_parse_line() {
    # Parse a single line from a .lex file.
    # Skips empty lines and comments. Validates structure and checks for duplicates.
    # Does not process escape sequences — values are stored raw.
    # Args:
    #   $1 — raw_line: raw line string including line endings
    #   $2 — line_num: 1-based line number for error reporting
    #   $3 — filepath: file path for error reporting
    # Returns:
    #   0 on success or skipped line, 1 on parse error
    # Raises:
    #   LexParseError to stderr on malformed lines or duplicate keys
    local raw_line="$1"
    local line_num="$2"
    local filepath="$3"
    # Strip line endings
    local line="${raw_line%$'\r'}"
    line="${line%$'\n'}"
     # Skip empty lines or comments
    local stripped="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$stripped" || "$stripped" == \#* ]] && return 0
    # Every valid entry must contain the separator
    if [[ "$line" != *::* ]]; then
        printf '[lexis] LexParseError: malformed line %d in %s: missing :: separator\n' \
            "$line_num" "$filepath" >&2
        return 1
    fi
    # Split on first occurrence of separator
    local key="${line%%::*}"
    local value="${line#*::}"
    # Key cannot be empty after trimming
    key="$(_lexis_trim "$key")"
    if [[ -z "$key" ]]; then
        printf '[lexis] LexParseError: malformed line %d in %s: empty key\n' \
            "$line_num" "$filepath" >&2
        return 1
    fi
    # Duplicate keys are not allowed
    if [[ -n "${_LEXIS_RAW_TRANSLATIONS[$key]+x}" ]]; then
        printf '[lexis] LexParseError: duplicate key "%s" at line %d in %s\n' \
            "$key" "$line_num" "$filepath" >&2
        return 1
    fi
    # Left-trim value
    value="${value#"${value%%[![:space:]]*}"}"
    _LEXIS_RAW_TRANSLATIONS["$key"]="$value"
    return 0
}

_lexis_load_file() {
    # Load and parse entire .lex file into _LEXIS_RAW_TRANSLATIONS.
    # Clears both raw and cache translations before loading.
    # Args:
    #   $1 — filepath: absolute path to .lex file
    # Returns:
    #   0 on success, 1 on failure
    # Raises:
    #   LexFileNotFoundError to stderr if file does not exist
    #   LexParseError to stderr on malformed file content
    local filepath="$1"
    # Clear both raw and cache
    _LEXIS_RAW_TRANSLATIONS=()
    _LEXIS_CACHE_TRANSLATIONS=()
    if [[ ! -f "$filepath" ]]; then
        printf '[lexis] LexFileNotFoundError: file not found: %s\n' "$filepath" >&2
        return 1
    fi
    local line_num=0
    local line=""
    # Handle files both with and without trailing newline
    while IFS= read -r line; do
        ((line_num++))
        _lexis_parse_line "$line" "$line_num" "$filepath" || return 1
    done < "$filepath"
    if  [[ -n "$line" ]]; then
        ((line_num++))
        _lexis_parse_line "$line" "$line_num" "$filepath" || return 1
    fi
    _lexis_debug "Loaded '${filepath}' - ${#_LEXIS_RAW_TRANSLATIONS[@]} keys"
    return 0
}

_lexis_snapshot_save() {
    # Capture current translation state into named array references.
    # Used by lexis_reload to save state before attempting a new load.
    # Args:
    #   $1 — name of associative array to store raw translations (nameref)
    #   $2 — name of associative array to store cache translations (nameref)
    local -n _raw_out="$1"
    local -n _cache_out="$2"

    _raw_out=()
    for k in "${!_LEXIS_RAW_TRANSLATIONS[@]}"; do
        _raw_out["$k"]="${_LEXIS_RAW_TRANSLATIONS[$k]}"
    done

    _cache_out=()
    for k in "${!_LEXIS_CACHE_TRANSLATIONS[@]}"; do
        _cache_out["$k"]="${_LEXIS_CACHE_TRANSLATIONS[$k]}"
    done
}

_lexis_snapshot_restore() {
    # Restore translation state from named array references.
    # Used by lexis_reload to recover previous state on failure.
    # Args:
    #   $1 — name of associative array containing raw translations (nameref)
    #   $2 — name of associative array containing cache translations (nameref)
    local -n _raw_in="$1"
    local -n _cache_in="$2"

    _LEXIS_RAW_TRANSLATIONS=()
    for k in "${!_raw_in[@]}"; do
        _LEXIS_RAW_TRANSLATIONS["$k"]="${_raw_in[$k]}"
    done

    _LEXIS_CACHE_TRANSLATIONS=()
    for k in "${!_cache_in[@]}"; do
        _LEXIS_CACHE_TRANSLATIONS["$k"]="${_cache_in[$k]}"
    done
}

_lexis_cache_fetch() {
    # Fetch a processed value from cache.
    # On first access, calls _lexis_unescape and stores result in cache.
    # Subsequent calls return the cached value directly.
    # Args:
    #   $1 — key: translation key to look up
    # Returns:
    #   Unescaped value string via printf
    # Raises:
    #   LexKeyNotFoundError to stderr if key not found
    local key="$1"
    if [[ ! -n "${_LEXIS_RAW_TRANSLATIONS[$key]+x}" ]]; then
        printf '[lexis] LexKeyNotFoundError: key not found: "%s"\n' "$key" >&2
        return 1
    fi
    if [[ ! -n "${_LEXIS_CACHE_TRANSLATIONS[$key]+x}" ]]; then
        _LEXIS_CACHE_TRANSLATIONS["$key"]="$(_lexis_unescape "${_LEXIS_RAW_TRANSLATIONS[$key]}")"
    fi
    printf '%s' "${_LEXIS_CACHE_TRANSLATIONS[$key]}"
}

_lexis_prepare_args() {
    # Prepare printf arguments, converting integers to ASCII chars for %c.
    # Replaces %% with a placeholder before scanning to avoid false positives.
    # Stores result in _LEXIS_ARGS_RESULT global return buffer.
    # Args:
    #   $1  — fmt: format string (used to detect %c presence)
    #   $@  — remaining args to pass to printf
    # Returns:
    #   Populates _LEXIS_ARGS_RESULT array
    local fmt="$1"
    shift
    _LEXIS_ARGS_RESULT=()
    # Replace %% with placeholder to avoid false positives
    local _tmp="${fmt//%%/$'\x01'}"
    # Fast path: no %c means no conversion needed (O(1))
    if [[ "$_tmp" != *%*c* ]]; then
        _LEXIS_ARGS_RESULT=("$@")
        return
    fi
    local arg
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]] && (( arg >= 0 && arg <= 255 )); then
            _LEXIS_ARGS_RESULT+=("$(printf "\\x$(printf '%02x' "$arg")")")
        else
            _LEXIS_ARGS_RESULT+=("$arg")
        fi
    done
}

lexis_load() {
    # Load a .lex file from the given directory.
    # Auto-detects locale from $LANG if not provided.
    # Falls back to fallback_locale if the requested locale file does not exist.
    # Args:
    #   $1 — lang_dir: directory containing .lex files
    #   $2 — locale: locale code (optional, auto-detected if omitted)
    #   $3 — fallback_locale: fallback locale code (optional, default "en")
    # Returns:
    #   0 on success, 1 on failure
    # Raises:
    #   LexFileNotFoundError to stderr if no suitable file is found
    #   LexParseError to stderr if the file is malformed
    local lang_dir="$1"
    local locale="${2:-$(_lexis_detect_locale)}"
    local fallback_locale="${3:-$_LEXIS_FALLBACK_LOCALE}"
    _LEXIS_LANG_DIR="$lang_dir"
    _LEXIS_FALLBACK_LOCALE="$fallback_locale"
    _lexis_resolve_filepath "$lang_dir" "$locale" "$fallback_locale" || return 1
    _lexis_load_file "$_LEXIS_FILEPATH" || return 1
    return 0
}

lexis_get() {
    # Get a translation by key with optional printf-style formatting.
    # Escape sequences are processed on first access (lazy).
    # Args:
    #   $1  — key: translation key
    #   $@  — values for placeholders (%s, %d, %f, %c, etc.)
    # Returns:
    #   Formatted translation string via printf
    # Raises:
    #   LexKeyNotFoundError to stderr if key not found or format fails
    local key="$1"
    shift
    local value
    value="$(_lexis_cache_fetch "$key")" || return 1
    # Apply printf-style formatting if arguments provided
    if [[ $# -eq 0 ]]; then
        printf '%s\n' "${value//%%/%}"
        return 0
    fi
    _lexis_prepare_args "$value" "$@"
    # Force C locale for consistent numeric formatting.
    LC_NUMERIC=C printf "$value\n" "${_LEXIS_ARGS_RESULT[@]}" 2>/dev/null || {
        printf '[lexis] LexKeyNotFoundError: format error for key "%s"\n' "$key" >&2
        return 1
    }
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
    #   Formatted translation string or formatted default via printf
    local key="$1"
    local default_value="$2"
    shift 2
    local value
    value="$(_lexis_cache_fetch "$key" 2>/dev/null)"
    if [[ $? -ne 0 ]]; then
        if [[ $# -eq 0 ]]; then
            printf '%s\n' "$default_value"
        else
            _lexis_prepare_args "$default_value" "$@"
            LC_NUMERIC=C printf "$default_value\n" "${_LEXIS_ARGS_RESULT[@]}" 2>/dev/null || printf '%s\n' "$default_value"
        fi
        return 0
    fi
    if [[ $# -eq 0 ]]; then
        printf '%s\n' "${value//%%/%}"
    else
        _lexis_prepare_args "$value" "$@"
        # Force C locale for consistent numeric formatting.
        LC_NUMERIC=C printf "$value\n" "${_LEXIS_ARGS_RESULT[@]}" 2>/dev/null || {
            printf '[lexis] LexKeyNotFoundError: format error for key "%s"\n' "$key" >&2
            return 1
        }
    fi
}

lexis_reload() {
    # Reload translations from the same directory, optionally switching locale.
    # Saves full state before attempting reload and restores it on failure.
    # Args:
    #   $1 — locale: new locale code (optional, auto-detected if omitted)
    #   $2 — fallback_locale: new fallback locale code (optional, keeps previous if omitted)
    # Returns:
    #   0 on success, 1 on failure
    # Raises:
    #   LexFileNotFoundError to stderr if new locale not found
    #   LexParseError to stderr if new file is malformed
    local new_locale="${1:-$(_lexis_detect_locale)}"
    local new_fallback="${2:-$_LEXIS_FALLBACK_LOCALE}"
    # Save current state in memory for rollback on failure
    local old_lang_dir="$_LEXIS_LANG_DIR"
    local old_locale="$_LEXIS_LOCALE"
    local old_fallback="$_LEXIS_FALLBACK_LOCALE"
    local old_filepath="$_LEXIS_FILEPATH"
    declare -A _snapshot_raw=()
    declare -A _snapshot_cache=()
    _lexis_snapshot_save _snapshot_raw _snapshot_cache
    _LEXIS_FALLBACK_LOCALE="$new_fallback"
    _lexis_resolve_filepath "$old_lang_dir" "$new_locale" "$new_fallback"
    if [[ $? -ne 0 ]]; then
        _LEXIS_LANG_DIR="$old_lang_dir"
        _LEXIS_LOCALE="$old_locale"
        _LEXIS_FALLBACK_LOCALE="$old_fallback"
        _LEXIS_FILEPATH="$old_filepath"
        _lexis_snapshot_restore _snapshot_raw _snapshot_cache
        return 1
    fi
    if ! _lexis_load_file "$_LEXIS_FILEPATH"; then
        _LEXIS_LANG_DIR="$old_lang_dir"
        _LEXIS_LOCALE="$old_locale"
        _LEXIS_FALLBACK_LOCALE="$old_fallback"
        _LEXIS_FILEPATH="$old_filepath"
        _lexis_snapshot_restore _snapshot_raw _snapshot_cache
        return 1
    fi
    return 0
}

lexis_keys() {
    # Return all loaded translation keys, one per line.
    # Returns:
    #   Keys from _LEXIS_RAW_TRANSLATIONS via printf
    printf '%s\n' "${!_LEXIS_RAW_TRANSLATIONS[@]}"
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
    # Reset all runtime state.
    # Clears translations, locale, filepath, and resets fallback to "en".
    _LEXIS_RAW_TRANSLATIONS=()
    _LEXIS_CACHE_TRANSLATIONS=()
    _LEXIS_LANG_DIR=""
    _LEXIS_LOCALE=""
    _LEXIS_FALLBACK_LOCALE="en"
    _LEXIS_FILEPATH=""
    _lexis_debug "translations cleared"
}

lexis_info() {
    # Print current runtime state for debugging.
    # Shows locale, fallback, key counts, and filepath.
    printf 'Lexis(locale=%q, fallback=%q, keys=%d, cached_keys=%d, filepath=%q)\n' \
        "${_LEXIS_LOCALE:-\"(none)\"}" \
        "$_LEXIS_FALLBACK_LOCALE" \
        "${#_LEXIS_RAW_TRANSLATIONS[@]}" \
        "${#_LEXIS_CACHE_TRANSLATIONS[@]}" \
        "${_LEXIS_FILEPATH:-\"(none)\"}"
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
