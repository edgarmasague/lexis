#!/usr/bin/env bash
# main.sh - LEX Independent Translation Engine

LEX_FILEPATH=""
LEX_LOCALE=""

declare -A LEX_CACHE

_lex_detect_locale() {
    echo "${LANG:0:2}"
}

_lex_resolve_filepath() {
    local lang_dir="$1"
    local locale="$2"
    local filepath="${lang_dir}/${locale}.lex"
    local fallback="${lang_dir}/en.lex"
    if [[ -f "$filepath" ]]; then
        echo "$filepath"
        return 0
    fi
    if [[ -f "$fallback" ]]; then
        LEX_LOCALE="en"
        echo "$fallback"
        return 0
    fi
    echo "[ERROR] No .lex file found for locale '${locale}' in '${lang_dir}'" >&2
    return 1
}

_lex_fetch_from_file() {
    local key="$1"
    local value
    if [[ ! -f "$LEX_FILEPATH" ]]; then
        echo "[ERROR] File not found: ${LEX_FILEPATH}" >&2
        return 1
    fi
    value=$(grep "${key}::" "$LEX_FILEPATH" | head -n1 | cut -d: -f3-)
    if [[ -z "$value" ]]; then
        echo "[ERROR] Key not found: '${key}'" >&2
        return 1
    fi
    echo "$value"
}

_lex_cache_fetch() {
    local key="$1"
    if [[ -z "${LEX_CACHE[$key]+x}" ]]; then
        local value
        value=$(_lex_fetch_from_file "$key") || return 1
        LEX_CACHE[$key]="$value"
    fi
    echo "${LEX_CACHE[$key]}"
}

lex_load() {
    local lang_dir="$1"
    local locale="${2:-$(_lex_detect_locale)}"
    LEX_LOCALE="$locale"
    LEX_FILEPATH=$(_lex_resolve_filepath "$lang_dir" "$locale") || return 1
    unset LEX_CACHE
    declare -gA LEX_CACHE
}

lex_get() {
    local key="$1"
    shift
    local value
    value=$(_lex_cache_fetch "$key") || {
        echo "$key"
        return 1
    }
    if [[ $# -gt 0 ]]; then
        printf "$value\n" "$@"
    else
        echo "$value"
    fi
}

lex_reload() {
    local lang_dir="$1"
    local locale="${2:-$LEX_LOCALE}"
    lex_load "$lang_dir" "$locale"
}

main() {
    lex_load "../lang"
    lex_get "welcome" "LEX"
    lex_get "modules_available"
    lex_get "error_file" "foo.txt"
    echo "---"
    lex_reload "../lang" "en"
    lex_get "welcome" "LEX"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
