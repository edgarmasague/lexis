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

# Debug mode: set LEXIS_DEBUG=1 to enable
LEXIS_DEBUG="${LEXIS_DEBUG:-0}"

_lexis_debug() {
    [[ "$LEXIS_DEBUG" == "1" ]] && printf '[lexis:debug] %s\n' "$*" >&2
}

_lexis_trim() {
    local value="$1"
    # Remove leading whitespace
    value="${value#"${value%%[![:space:]]*}"}"
    # Remove trailing whitespace
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

_lexis_unescape() {
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
                \\) result+='\\' ;;
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
    local lang="${LANG:-}"
    if [[ -z "$lang" || "$lang" == "C" || "$lang" == "POSIX" ]]; then
        printf '%s' "en"
        return
    fi
    lang="${lang%%.*}"
    lang="${lang//-/_}"
    printf '%s' "${lang%%_*}" | tr '[:upper:]' '[:lower:]'
}

_lexis_resolve_filepath() {
    local lang_dir="$1"
    local locale="$2"
    local fallback="$3"
    local filepath="${lang_dir}/${locale}.lex"
    local fallback_filepath="${lang_dir}/${fallback}.lex"
    if [[ -f "$filepath" ]]; then
        printf '%s' "$filepath"
        return 0
    fi
    if [[ -f "$fallback_filepath" ]]; then
        _LEXIS_LOCALE="$fallback"
        _lexis_debug "locale '${locale}' not found, falling back to '${fallback}'"
        printf '%s' "$fallback_filepath"
        return 0
    fi
    printf '[lexis] LexFileNotFoundError: no .lex file found for locale "%s" (fallback "%s") in "%s"\n' \
        "$locale" "$fallback" "$lang_dir" >&2
    return 1
}

_lexis_parse_line() {
    local raw_line="$1"
    local line_num="$2"
    local filepath="$3"
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
    local filepath="$1"
    # Clear both raw and cache
    _LEXIS_RAW_TRANSLATIONS=()
    _LEXIS_CACHE_TRANSLATIONS=()
    if [[ ! -f "$filepath" ]]; then
        printf '[lexis] LexFileNotFoundError: file not found: %s\n' "$filepath" >&2
        return 1
    fi
    local line_num=0
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

_lexis_cache_fetch() {
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

lexis_load() {
    local lang_dir="$1"
    local locale="${2:-$(_lexis_detect_locale)}"
    local fallback_locale="${3:-$_LEXIS_FALLBACK_LOCALE}"
    _LEXIS_LANG_DIR="$lang_dir"
    _LEXIS_LOCALE="$locale"
    _LEXIS_FALLBACK_LOCALE="$fallback_locale"
    local filepath
    filepath=$(_lexis_resolve_filepath "$lang_dir" "$locale" "$fallback_locale") || return 1
    _LEXIS_FILEPATH="$filepath"
    _lexis_load_file "$filepath" || return 1
    return 0
}

lexis_get() {
    local key="$1"
    shift
    local value
    value="$(_lexis_cache_fetch "$key")" || return 1
    # Apply printf-style formatting if arguments provided
    if [[ $# -eq 0 ]]; then
        printf '%s\n' "${value//%%/%}"
        return 0
    fi
    printf "%s\n" "$(printf "$value" "$@")" 2>/dev/null || {
        printf '[lexis] LexKeyNotFoundError: format error for key "%s"\n' "$key" >&2
        return 1
    }
}

lexis_get_or_default() {
    local key="$1"
    local default_value="$2"
    shift 2
    local value
    value="$(_lexis_cache_fetch "$key" 2>/dev/null)"
    if [[ $? -ne 0 ]]; then
        if [[ $# -eq 0 ]]; then
            printf '%s\n' "$default_value"
        else
            printf "%s\n" "$(printf "$default_value" "$@")" 2>/dev/null || printf '%s\n' "$default_value"
        fi
        return 0
    fi
    if [[ $# -eq 0 ]]; then
        printf '%s\n' "${value//%%/%}"
    else
        printf "%s\n" "$(printf "$value" "$@")" 2>/dev/null || {
            printf '[lexis] LexKeyNotFoundError: format error for key "%s"\n' "$key" >&2
            return 1
        }
    fi
}

_lexis_rollback() {
    local old_lang_dir="$1"
    local old_locale="$2"
    local old_fallback="$3"
    local old_filepath="$4"
    local -n _raw_ref="$5"
    local -n _cache_ref="$6"
    _LEXIS_LANG_DIR="$old_lang_dir"
    _LEXIS_LOCALE="$old_locale"
    _LEXIS_FALLBACK_LOCALE="$old_fallback"
    _LEXIS_FILEPATH="$old_filepath"
    _LEXIS_RAW_TRANSLATIONS=()
    for k in "${!_raw_ref[@]}"; do
        _LEXIS_RAW_TRANSLATIONS["$k"]="${_raw_ref[$k]}"
    done
    _LEXIS_CACHE_TRANSLATIONS=()
    for k in "${!_cache_ref[@]}"; do
        _LEXIS_CACHE_TRANSLATIONS["$k"]="${_cache_ref[$k]}"
    done
}

lexis_reload() {
    local new_locale="${1:-$(_lexis_detect_locale)}"
    local new_fallback="${2:-$_LEXIS_FALLBACK_LOCALE}"
    # Save current state in memory for rollback on failure
    local old_lang_dir="$_LEXIS_LANG_DIR"
    local old_locale="$_LEXIS_LOCALE"
    local old_fallback="$_LEXIS_FALLBACK_LOCALE"
    local old_filepath="$_LEXIS_FILEPATH"
    declare -A _old_raw=()
    declare -A _old_cache=()
    for k in "${!_LEXIS_RAW_TRANSLATIONS[@]}"; do
        _old_raw["$k"]="${_LEXIS_RAW_TRANSLATIONS[$k]}"
    done
    for k in "${!_LEXIS_CACHE_TRANSLATIONS[@]}"; do
        _old_cache["$k"]="${_LEXIS_CACHE_TRANSLATIONS[$k]}"
    done
    _LEXIS_LOCALE="$new_locale"
    _LEXIS_FALLBACK_LOCALE="$new_fallback"
    local new_filepath
    new_filepath="$(_lexis_resolve_filepath "$old_lang_dir" "$new_locale" "$new_fallback")"
    if [[ $? -ne 0 ]]; then
        _lexis_rollback "$old_lang_dir" "$old_locale" "$old_fallback" "$old_filepath" _old_raw _old_cache
        return 1
    fi
    _LEXIS_FILEPATH="$new_filepath"
    if ! _lexis_load_file "$new_filepath"; then
        _lexis_rollback "$old_lang_dir" "$old_locale" "$old_fallback" "$old_filepath" _old_raw _old_cache
        return 1
    fi
    return 0
}

lexis_keys() {
    printf '%s\n' "${!_LEXIS_RAW_TRANSLATIONS[@]}"
}
lexis_len() {
    printf '%d\n' "${#_LEXIS_RAW_TRANSLATIONS[@]}"
}

lexis_has() {
    [[ -n "${_LEXIS_RAW_TRANSLATIONS[$1]+x}" ]]
}

lexis_clear() {
    _LEXIS_RAW_TRANSLATIONS=()
    _LEXIS_CACHE_TRANSLATIONS=()
    _LEXIS_LANG_DIR=""
    _LEXIS_LOCALE=""
    _LEXIS_FALLBACK_LOCALE="en"
    _LEXIS_FILEPATH=""
    _lexis_debug "translations cleared"
}

lexis_info() {
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
