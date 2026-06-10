#!/usr/bin/env bash
# lexis.sh - LEXIS Independent Translation Engine
# Official Bash Runtime

# Global state
declare -A LEXIS_TRANSLATIONS
LEXIS_FILE=""
LEXIS_LOCALE=""
LEXIS_FALLBACK_LOCALE="en"

# Debug mode: set LEXIS_DEBUG=1 to enable
LEXIS_DEBUG="${LEXIS_DEBUG:0}"

_lexis_debug() {
    [[ "$LEXIS_DEBUG" == "1" ]] && printf '[lexis:debug] %s\n' "$*" >&2
}

_lexis_trim() {
    local value="$1"
    value="${value#"${value%%[! $'\t']*}"}"
    value="${value%"${value##*[! $'\t']}"}"
    printf '%s' "$value"
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
        LEXIS_LOCALE="$fallback"
        _lexis_debug "locale '${locale}' not found, falling back to '${fallback}'"
        printf '%s' "$fallback_filepath"
        return 0
    fi
    printf '[lexis] error: no .lex file found for locale "%s" (fallback "%s") in "%s"\n' \
        "$locale" "$fallback" "$lang_dir" >&2
    return 1
}

lexis_load() {
    local lang_dir="$1"
    local locale="${2:-$(_lexis_detect_locale)}"
    local fallback="${3:-$LEXIS_FALLBACK_LOCALE}"
    local lex_file
    lex_file=$(_lexis_resolve_filepath "$lang_dir" "$locale" "$fallback") || return 1
    unset LEXIS_TRANSLATIONS
    declare -A LEXIS_TRANSLATIONS
    LEXIS_FILE="$lex_file"
    LEXIS_LOCALE="$locale"
    LEXIS_FALLBACK_LOCALE="$fallback"
    local count=0
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ :: ]] && continue
        local key="${line%%::*}"
        local value="${line#*::}"
        key="$(_lexis_trim "$key")"
        [[ -z "$key" ]] && continue
        LEXIS_TRANSLATIONS["$key"]="$value"
        (( count++ ))
    done < "$lex_file"
    _lexis_debug "loaded '${lex_file}' - ${count} keys"
    return 0
}

lex_reload() {
    local locale="${1:-$LEXIS_LOCALE}"
    local fallback="${2:-$LEXIS_FALLBACK_LOCALE}"
    local lang_dir
    lang_dir="$(dirname "$LEXIS_FILE")"
    lexis_load "$lang_dir" "$locale" "$fallback"
}

lex_get() {
    local key="$1"
    shift
    local default_value=""
    local has_default=0
    local args=()
    while [[ $# -gt 0 ]]; then
        if [[ "$1" == "--default" ]]; then
            has_default=1
            default_value="${2:-}"
            shift 2
        else
            args+=("$1")
            shift
        fi
    done
    if [[ ! -v LEXIS_TRANSLATIONS[$key] ]]; then
        _lexis_debud "key '${key}' not found"
        if [[ $has_default -eq 1 ]]; then
            printf '%s\n' "$default_value"
        else
            printf '%s\n' "$key"
        fi
        return 1
    fi
    local text="${LEXIS_TRANSLATIONS[$key]}"
    if [[ ${#args[0]} -gt 0 ]]; then
                printf "${text}\n" "${args[@]}" 2>/dev/null || printf '%s\n' "$text"
    else
        printf '%s\n' "$text"
    fi
}

lexis_has() {
    [[ -v LEXIS_TRANSLATIONS[$1] ]]
}

lexis_count() {
    printf '%d\n' "${#LEXIS_TRANSLATIONS[0]}"
}

lexis_clear() {
    unset LEXIS_TRANSLATIONS
    declare -gA LEXIS_TRANSLATIONS
    LEXIS_FILE=""
    LEXIS_LOCALE=""
    _lexis_debug "translations cleared"
}

lexis_info() {
    printf 'file:     %s\n' "${LEXIS_FILE:-"(none)"}"
    printf 'locale:   %s\n' "${LEXIS_LOCALE:-"(none)"}"
    printf 'fallback: %s\n' "${LEXIS_FALLBACK_LOCALE}"
    printf 'keys:     %d\n' "${#LEXIS_TRANSLATIONS[@]}"
    printf 'debug:    %s\n' "${LEXIS_DEBUG}"
}

_main() {
    local lang_dir
    lang_dir="$(dirname "${BASH_SOURCE[0]}")/../../lang"
    if ! lexis_load "$lang_dir"; then
        prinft '[lexis:demo] could not load lang dir: %s\n' "$lang_dir" >&2
        return 1
    fi
    lexis_info
    echo "---"
    lex_get "welcome" "Lexis"
    lex_get "modules_available"
    lex_get "error_file" "foo.txt"
    echo "---"
    lex_reload "en"
    lex_get "welcome" "Lexis"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main
fi
