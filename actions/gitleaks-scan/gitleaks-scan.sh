#!/usr/bin/env bash
# Run the open-source Gitleaks CLI with explicit PR or full-history scope.
set -euo pipefail

GITLEAKS_VERSION="8.30.1"
SCAN_SCOPE="${SCAN_SCOPE:-auto}"
BASE_SHA="${BASE_SHA:-}"
HEAD_SHA="${HEAD_SHA:-}"
CONFIG_PATH="${CONFIG_PATH:-.gitleaks.toml}"
RESULT_FILE="${RESULT_FILE:-gitleaks-results.sarif}"
EVENT_NAME="${EVENT_NAME:-}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"

set_output() { printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; }

resolve_scope() {
  case "$SCAN_SCOPE" in
    auto)
      if [ "$EVENT_NAME" = pull_request ]; then
        printf 'pr-diff\n'
      else
        printf 'full-history\n'
      fi
      ;;
    pr-diff|full-history) printf '%s\n' "$SCAN_SCOPE" ;;
    *) printf 'gitleaks-scan error: scan-scope must be auto, pr-diff, or full-history\n' >&2; return 1 ;;
  esac
}

install_gitleaks() {
  local machine
  local system
  local archive_os
  local archive_arch
  local expected_sha
  local archive
  local install_directory

  system="$(uname -s)"
  machine="$(uname -m)"
  case "$system:$machine" in
    Linux:x86_64|Linux:amd64)
      archive_os=linux
      archive_arch=x64
      expected_sha=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
      ;;
    Linux:arm64|Linux:aarch64)
      archive_os=linux
      archive_arch=arm64
      expected_sha=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080
      ;;
    Darwin:x86_64)
      archive_os=darwin
      archive_arch=x64
      expected_sha=dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709
      ;;
    Darwin:arm64)
      archive_os=darwin
      archive_arch=arm64
      expected_sha=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5
      ;;
    *) printf 'gitleaks-scan error: unsupported runner architecture: %s\n' "$machine" >&2; return 1 ;;
  esac

  install_directory="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ff-sec-gitleaks-${GITLEAKS_VERSION}-${archive_os}-${archive_arch}"
  if [ -x "$install_directory/gitleaks" ]; then
    printf '%s\n' "$install_directory/gitleaks"
    return
  fi

  mkdir -p "$install_directory"
  archive="$install_directory/gitleaks.tar.gz"
  curl --fail --silent --show-error --location \
    --proto '=https' --tlsv1.2 \
    --output "$archive" \
    "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_${archive_os}_${archive_arch}.tar.gz" \
    || return 1

  if command -v shasum >/dev/null 2>&1; then
    [ "$(shasum -a 256 "$archive" | awk '{print $1}')" = "$expected_sha" ] || return 1
  else
    printf '%s  %s\n' "$expected_sha" "$archive" | sha256sum --check --status || return 1
  fi
  tar -xzf "$archive" -C "$install_directory" gitleaks || return 1
  chmod +x "$install_directory/gitleaks" || return 1
  printf '%s\n' "$install_directory/gitleaks"
}

resolved_scope="$(resolve_scope)" || {
  set_output scanner_outcome failure
  exit 0
}
set_output scan_scope "$resolved_scope"
set_output result_file "$RESULT_FILE"

if [ "$resolved_scope" = pr-diff ]; then
  if [ -z "$BASE_SHA" ] || [ -z "$HEAD_SHA" ]; then
    printf 'gitleaks-scan error: base-sha and head-sha are required for pr-diff scope\n' >&2
    set_output scanner_outcome failure
    exit 0
  fi
  log_options="${BASE_SHA}..${HEAD_SHA}"
else
  log_options=--all
fi

gitleaks_binary="${GITLEAKS_BIN:-}"
if [ -z "$gitleaks_binary" ]; then
  if ! gitleaks_binary="$(install_gitleaks)"; then
    printf 'gitleaks-scan error: failed to install verified Gitleaks %s\n' "$GITLEAKS_VERSION" >&2
    set_output scanner_outcome failure
    exit 0
  fi
fi
if [ ! -x "$gitleaks_binary" ]; then
  printf 'gitleaks-scan error: Gitleaks executable is unavailable: %s\n' "$gitleaks_binary" >&2
  set_output scanner_outcome failure
  exit 0
fi

arguments=(
  git
  --no-banner
  --no-color
  --redact=100
  --report-format sarif
  --report-path "$RESULT_FILE"
  --exit-code 10
  --log-opts "$log_options"
)
if [ -n "$CONFIG_PATH" ] && [ -f "$CONFIG_PATH" ]; then
  arguments+=(--config "$CONFIG_PATH")
fi
arguments+=(.)

set +e
"$gitleaks_binary" "${arguments[@]}"
scan_exit="$?"
set -e

case "$scan_exit" in
  0|10)
    set_output scanner_outcome success
    ;;
  *)
    printf 'gitleaks-scan error: Gitleaks exited with operational status %s\n' "$scan_exit" >&2
    set_output scanner_outcome failure
    ;;
esac

# The scanner-outcome adapter owns validation and the final finding/error gate.
exit 0
