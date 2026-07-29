#!/usr/bin/env bash
# Run checksum-verified Zizmor offline and expose operational outcome separately from findings.
set -euo pipefail

ZIZMOR_VERSION="1.28.0"
INPUT_PATH="${INPUT_PATH:-.}"
CONFIG_PATH="${CONFIG_PATH:-}"
RESULT_FILE="${RESULT_FILE:-zizmor-results.sarif}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"

set_output() { printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; }

install_zizmor() {
  local machine
  local system
  local target
  local expected_sha
  local archive
  local install_directory

  system="$(uname -s)"
  machine="$(uname -m)"
  case "$system:$machine" in
    Linux:x86_64|Linux:amd64)
      target=x86_64-unknown-linux-gnu
      expected_sha=e87b67160194884e375a46a12c57ccc904f762b53845f254fab7f17d98809c09
      ;;
    Linux:arm64|Linux:aarch64)
      target=aarch64-unknown-linux-gnu
      expected_sha=324e43770cfacf4216f8aefb287263b5b5c733c85b03bf7583b5cc4a0460239e
      ;;
    Darwin:x86_64)
      target=x86_64-apple-darwin
      expected_sha=40a58d8560d65c71357b3977d0da425773bf8f10bf1ffd38099d963d3afdf3aa
      ;;
    Darwin:arm64)
      target=aarch64-apple-darwin
      expected_sha=54949bbd6b4c8527046bb8990bac9e0dab3eec787640f4e6199ae121dd1040be
      ;;
    *) printf 'zizmor-scan error: unsupported runner architecture: %s:%s\n' "$system" "$machine" >&2; return 1 ;;
  esac

  install_directory="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ff-sec-zizmor-${ZIZMOR_VERSION}-${target}"
  if [ -x "$install_directory/zizmor" ]; then
    printf '%s\n' "$install_directory/zizmor"
    return
  fi

  mkdir -p "$install_directory"
  archive="$install_directory/zizmor.tar.gz"
  curl --fail --silent --show-error --location \
    --proto '=https' --tlsv1.2 \
    --output "$archive" \
    "https://github.com/zizmorcore/zizmor/releases/download/v${ZIZMOR_VERSION}/zizmor-${target}.tar.gz" \
    || return 1

  if command -v shasum >/dev/null 2>&1; then
    [ "$(shasum -a 256 "$archive" | awk '{print $1}')" = "$expected_sha" ] || return 1
  else
    printf '%s  %s\n' "$expected_sha" "$archive" | sha256sum --check --status || return 1
  fi
  tar -xzf "$archive" -C "$install_directory" zizmor || return 1
  chmod +x "$install_directory/zizmor" || return 1
  printf '%s\n' "$install_directory/zizmor"
}

set_output result_file "$RESULT_FILE"
zizmor_binary="${ZIZMOR_BIN:-}"
if [ -z "$zizmor_binary" ]; then
  if ! zizmor_binary="$(install_zizmor)"; then
    printf 'zizmor-scan error: failed to install verified Zizmor %s\n' "$ZIZMOR_VERSION" >&2
    set_output scanner_outcome failure
    exit 0
  fi
fi
if [ ! -x "$zizmor_binary" ]; then
  printf 'zizmor-scan error: Zizmor executable is unavailable: %s\n' "$zizmor_binary" >&2
  set_output scanner_outcome failure
  exit 0
fi

arguments=(
  --offline
  --strict-collection
  --persona auditor
  --min-confidence low
  --min-severity medium
  --format sarif
  --color never
  --no-progress
)
if [ -n "$CONFIG_PATH" ]; then
  arguments+=(--config "$CONFIG_PATH")
else
  arguments+=(--no-config)
fi

set +e
"$zizmor_binary" "${arguments[@]}" -- "$INPUT_PATH" > "$RESULT_FILE"
scan_exit="$?"
set -e

if [ "$scan_exit" -eq 0 ]; then
  set_output scanner_outcome success
else
  printf 'zizmor-scan error: Zizmor exited with operational status %s\n' "$scan_exit" >&2
  set_output scanner_outcome failure
fi

# The Evaluation adapter validates SARIF and owns the final finding/error gate.
exit 0
