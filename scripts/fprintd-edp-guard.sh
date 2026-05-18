#!/usr/bin/env bash
#
# fprintd-edp-guard.sh
#
# Diagnostic helper for docked laptops with more than one fingerprint reader.
#
# The intended situation:
#   - an internal laptop fingerprint reader exists,
#   - an external USB fingerprint reader is used at the dock,
#   - fprintd may see both,
#   - the user wants a readable status check and optionally a failing exit code
#     when the external reader is not visible.
#
# This script is intentionally conservative.
# It does not modify PAM.
# It does not delete fingerprints.
# It does not unload kernel modules.
# It does not change udev rules.
# It only inspects and reports.
#
# Exit codes:
#   0  success / no fatal issue found
#   1  --require-external was used and no external reader matched
#   2  fprintd-list failed or is unavailable
#   64 invalid usage

set -o nounset
set -o pipefail

PROGRAM_NAME="${0##*/}"
REQUIRE_EXTERNAL=0
VERBOSE=0
TARGET_USER="${SUDO_USER:-${USER:-}}"

# Hardware names vary. These defaults match the original setup reasonably well,
# but callers can override them without editing the script.
EXTERNAL_PATTERN="${FPRINTD_EXTERNAL_PATTERN:-Elan|ELAN|ElanTech|USB}"
INTERNAL_PATTERN="${FPRINTD_INTERNAL_PATTERN:-Synaptics|internal|builtin|built-in}"

usage() {
  cat <<EOF
Usage: ${PROGRAM_NAME} [options]

Options:
  --require-external     Exit with code 1 if no likely external reader is found.
  --user USER            Inspect fingerprints for USER. Defaults to current user.
  --verbose              Print raw fprintd-list output as part of the report.
  -h, --help             Show this help.

Environment:
  FPRINTD_EXTERNAL_PATTERN   Regex used to identify the external reader.
                             Default: ${EXTERNAL_PATTERN}

  FPRINTD_INTERNAL_PATTERN   Regex used to identify the internal reader.
                             Default: ${INTERNAL_PATTERN}

Examples:
  ${PROGRAM_NAME}
  ${PROGRAM_NAME} --require-external
  FPRINTD_EXTERNAL_PATTERN="ElanTech" ${PROGRAM_NAME} --verbose
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

fail_usage() {
  printf 'error: %s\n\n' "$*" >&2
  usage >&2
  exit 64
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-external)
      REQUIRE_EXTERNAL=1
      shift
      ;;
    --user)
      [[ $# -ge 2 ]] || fail_usage "--user requires a username"
      TARGET_USER="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail_usage "unknown argument: $1"
      ;;
  esac
done

if [[ -z "${TARGET_USER}" ]]; then
  warn "could not determine target user"
  warn "use --user USER"
  exit 64
fi

if ! command -v fprintd-list >/dev/null 2>&1; then
  warn "fprintd-list was not found"
  warn "install fprintd first, for example: sudo dnf install fprintd fprintd-pam"
  exit 2
fi

# Capture both stdout and stderr so the report is useful in systemd journals.
FPRINTD_OUTPUT=""
if ! FPRINTD_OUTPUT="$(fprintd-list "${TARGET_USER}" 2>&1)"; then
  warn "fprintd-list failed for user '${TARGET_USER}'"
  printf '%s\n' "${FPRINTD_OUTPUT}" >&2
  exit 2
fi

EXTERNAL_FOUND=0
INTERNAL_FOUND=0
DEVICE_COUNT="unknown"

if grep -Eiq "${EXTERNAL_PATTERN}" <<<"${FPRINTD_OUTPUT}"; then
  EXTERNAL_FOUND=1
fi

if grep -Eiq "${INTERNAL_PATTERN}" <<<"${FPRINTD_OUTPUT}"; then
  INTERNAL_FOUND=1
fi

if grep -Eio '^found [0-9]+ devices?' <<<"${FPRINTD_OUTPUT}" >/dev/null; then
  DEVICE_COUNT="$(grep -Eio '^found [0-9]+ devices?' <<<"${FPRINTD_OUTPUT}" | head -n1)"
fi

log "fprintd eDP guard report"
log "========================="
log "user:                 ${TARGET_USER}"
log "device count:         ${DEVICE_COUNT}"
log "external pattern:     ${EXTERNAL_PATTERN}"
log "internal pattern:     ${INTERNAL_PATTERN}"
log "external reader seen: $([[ ${EXTERNAL_FOUND} -eq 1 ]] && echo yes || echo no)"
log "internal reader seen: $([[ ${INTERNAL_FOUND} -eq 1 ]] && echo yes || echo no)"

if [[ ${VERBOSE} -eq 1 ]]; then
  log ""
  log "raw fprintd-list output"
  log "-----------------------"
  printf '%s\n' "${FPRINTD_OUTPUT}"
fi

log ""

if [[ ${EXTERNAL_FOUND} -eq 1 ]]; then
  log "OK: a likely external fingerprint reader is visible."
else
  warn "no likely external fingerprint reader matched the configured pattern"
fi

if [[ ${INTERNAL_FOUND} -eq 1 ]]; then
  log "note: a likely internal fingerprint reader is also visible."
  log "      This may be fine, but verify that enrollments belong to the reader you actually use."
fi

if [[ ${REQUIRE_EXTERNAL} -eq 1 && ${EXTERNAL_FOUND} -ne 1 ]]; then
  warn "strict mode requested external reader availability"
  exit 1
fi

exit 0
