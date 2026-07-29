#!/usr/bin/env bash
# This file models hostile fork content. Baseline workflows must never run it.
set -euo pipefail

touch fork-code-executed
printf '%s' "${FORK_SECRET_PROBE:-missing}" > fork-secret-probe
printf '%s' "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-missing}" > fork-oidc-probe
printf '%s' "${GITHUB_TOKEN:-missing}" > fork-token-probe
