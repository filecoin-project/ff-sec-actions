# Shared setup for the dev harness. Sourced, not executed.
# Resolves repo paths, loads scripts/dev/.env, and resolves $FIXTURE to a
# fixture directory.

set -euo pipefail

DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DEV_DIR/../.." && pwd)"
FIXTURES_DIR="$DEV_DIR/fixtures"

if [ -f "$DEV_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$DEV_DIR/.env"
  set +a
fi

# Resolve $FIXTURE (a directory name under fixtures/) into $fixture_dir.
# fetch.sh creates fixtures; every other stage requires one to exist.
require_fixture() {
  : "${FIXTURE:?FIXTURE is required (a directory name under scripts/dev/fixtures/)}"
  fixture_dir="$FIXTURES_DIR/$FIXTURE"
  [ -d "$fixture_dir" ] || {
    echo "error: fixture '$FIXTURE' not found under $FIXTURES_DIR/" >&2
    echo "available fixtures:" >&2
    ls "$FIXTURES_DIR" 2>/dev/null >&2 || echo "  (none — run fetch.sh first)" >&2
    exit 1
  }
}

require_file() {
  [ -f "$1" ] || { echo "error: missing $1 — run $2 first." >&2; exit 1; }
}
