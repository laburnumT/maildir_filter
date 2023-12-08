#!/bin/bash

PROGRAM="${0##*/}"
MAILBOXES=()
DESTINATION="HTML"
NEW_ONLY=0
COPY_OVER_MOVE=0
TEST_RUN=0
VERBOSE=0

cmd_help() {
    cat <<EOF
Usage:
  $PROGRAM -h
  $PROGRAM -m <mailbox> [-m <mailbox] [-d <mailbox>] [-n] [-c] [-t] [-v]

Options:
  -h           Show this help text
  -m <mailbox> Mailbox to operate on
  -d <mailbox> Destination mailbox (default: HTML)
  -n           Limit to new emails
  -c           Copy rather than move
  -t           Perform a test/dry run
  -v           Verbose output
EOF
}

check_mailbox() {
    if ! [[ -d "${1}" ]]; then
        echo "${1}" "does not exist" 1>&2
        exit 1
    fi
    if ! { [[ -d "${1}/cur" ]] \
        && [[ -d "${1}/new" ]] \
        && [[ -d "${1}/tmp" ]]; }; then
        echo "${1}" "does not have a proper maildir structure" 1>&2
        exit 1
    fi
}

operate() {
    local mailbox_dir="${1}"
    local mailbox
    local html_files

    mailbox="${mailbox_dir##*/}"

    if [[ "${NEW_ONLY}" -eq 1 ]]; then
        mailbox_dir="${mailbox_dir}/new"
    fi

    if ! html_files="$(
        grep -rPl '^Content-Type: text/html' "${mailbox_dir}"
    )"; then
        return
    fi

    for f in ${html_files}; do
        if ! grep -qP '^Content-Type: text/plain' "${f}" \
            && ! grep -qP '^From: .*.*no-?reply.*@.*$' "${f}"; then
            sin_bin="$(perl -pe "s|${mailbox}|${DESTINATION}|" <<<"${f}")"
            if [[ "${VERBOSE}" -eq 1 ]]; then
                echo "${f}" "->" "${sin_bin}"
            fi
            if [[ "${TEST_RUN}" -eq 1 ]]; then
                continue
            fi
            if [[ "${COPY_OVER_MOVE}" -eq 0 ]]; then
                mv "${f}" "${sin_bin}"
            else
                cp "${f}" "${sin_bin}"
            fi
        fi
    done
}

main() {
    for mailbox in "${MAILBOXES[@]}"; do
        operate "${mailbox}"
    done
}

while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
        -h)
            cmd_help
            exit 0
            ;;
        -m)
            shift
            check_mailbox "${1}"
            MAILBOXES+=("${1%%/}")
            shift
            ;;
        -d)
            shift
            DESTINATION="${1}"
            shift
            ;;
        -n)
            shift
            NEW_ONLY=1
            ;;
        -c)
            shift
            COPY_OVER_MOVE=1
            ;;
        -t)
            shift
            TEST_RUN=1
            ;;
        -v)
            shift
            VERBOSE=1
            ;;
        *)
            cmd_help
            exit 1
            ;;
    esac
done

if [[ "${#MAILBOXES[@]}" -eq 0 ]]; then
    echo "Must supply at least one mailbox" 1>&2
    cmd_help
    exit 1
fi

main
