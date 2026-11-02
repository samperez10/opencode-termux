#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 VERSION OPENCODE_BINARY OUTPUT_DIR" >&2
    exit 2
fi

VERSION="$1"
BINARY="$2"
OUTPUT_DIR="$3"
ARCHIVE="opencode-termux-aarch64.tar.gz"
PACKAGE_DIR="$OUTPUT_DIR/opencode-termux"

if [[ ! "$VERSION" =~ ^2\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
    echo "Unsupported OpenCode v2 version: $VERSION" >&2
    exit 1
fi

test -x "$BINARY"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR/bin" "$PACKAGE_DIR/libexec/opencode"
install -m 755 "$BINARY" "$PACKAGE_DIR/libexec/opencode/opencode.bin"
printf '%s\n' "$VERSION" > "$PACKAGE_DIR/VERSION"

cat > "$PACKAGE_DIR/bin/opencode" <<'WRAPPER'
#!/data/data/com.termux/files/usr/bin/sh
set -eu

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BINARY="$PREFIX/libexec/opencode/opencode.bin"
VERSION_FILE="$PREFIX/libexec/opencode/VERSION"

# Check once per day. A failed or offline check never prevents OpenCode startup.
if [ "${OPENCODE_TERMUX_NO_UPDATE_CHECK:-0}" != "1" ] && command -v curl >/dev/null 2>&1; then
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/opencode-termux"
    STAMP="$CACHE_DIR/update-check"
    now="$(date +%s 2>/dev/null || echo 0)"
    checked=0
    [ ! -f "$STAMP" ] || checked="$(stat -c %Y "$STAMP" 2>/dev/null || echo 0)"
    if [ "$now" -eq 0 ] || [ $((now - checked)) -ge 86400 ]; then
        mkdir -p "$CACHE_DIR"
        : > "$STAMP"
        repository="${OPENCODE_TERMUX_REPO:-samperez10/opencode-termux}"
        latest="$(curl -fsSL --connect-timeout 3 --max-time 5 \
            "https://github.com/$repository/releases/latest/download/release.json" 2>/dev/null |
            sed -n 's/.*"version": "\([^"]*\)".*/\1/p' | sed -n '1p' || true)"
        installed="$(sed -n '1p' "$VERSION_FILE" 2>/dev/null || true)"
        if [ -n "$latest" ] && [ -n "$installed" ] && [ "$latest" != "$installed" ]; then
            echo "OpenCode Termux update available: $installed -> $latest" >&2
            echo "Update with: curl -fsSL https://raw.githubusercontent.com/$repository/main/install.sh | sh" >&2
        fi
    fi
fi

if ! command -v grun >/dev/null 2>&1; then
    echo "opencode: glibc-runner is required; run: pkg install glibc-repo && pkg install glibc-runner" >&2
    exit 127
fi
if [ ! -x "$BINARY" ]; then
    echo "opencode: missing executable: $BINARY" >&2
    exit 127
fi

exec grun "$BINARY" "$@"
WRAPPER
chmod 755 "$PACKAGE_DIR/bin/opencode"

tar -C "$OUTPUT_DIR" -czf "$OUTPUT_DIR/$ARCHIVE" opencode-termux
(
    cd "$OUTPUT_DIR"
    sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
)

cat > "$OUTPUT_DIR/release.json" <<EOF
{
  "version": "$VERSION",
  "target": "aarch64-linux-android",
  "runtime": "termux-glibc-runner",
  "archive": "$ARCHIVE"
}
EOF

rm -rf "$PACKAGE_DIR"
