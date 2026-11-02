#!/data/data/com.termux/files/usr/bin/sh
set -eu

REPOSITORY="${OPENCODE_TERMUX_REPO:-samperez10/opencode-termux}"
VERSION="${OPENCODE_TERMUX_VERSION:-latest}"
ARCHIVE="opencode-termux-aarch64.tar.gz"
CHECKSUM="$ARCHIVE.sha256"
DRY_RUN=0

fail() {
    printf 'OpenCode installer: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run]

Installs the latest OpenCode v2 release packaged for ARM64 Termux.

Environment:
  OPENCODE_TERMUX_REPO       Release repository (default: samperez10/opencode-termux)
  OPENCODE_TERMUX_VERSION    Release version or "latest"
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unknown option: $1" ;;
    esac
    shift
done

[ -n "${PREFIX:-}" ] || fail "PREFIX is not set; run this installer inside Termux"
case "$PREFIX" in
    /data/data/com.termux/files/usr) ;;
    *) fail "unsupported PREFIX: $PREFIX" ;;
esac
[ "$(uname -m)" = "aarch64" ] || fail "only ARM64 Termux is supported"
command -v curl >/dev/null 2>&1 || fail "curl is required; run: pkg install curl"

if [ "$VERSION" = "latest" ]; then
    RELEASE_JSON="$(curl -fsSL --retry 3 \
        "https://api.github.com/repos/$REPOSITORY/releases/latest")" \
        || fail "could not find a published release in $REPOSITORY"
    TAG="$(printf '%s\n' "$RELEASE_JSON" |
        sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | sed -n '1p')"
    [ -n "$TAG" ] || fail "release metadata did not contain a tag"
else
    case "$VERSION" in v*) TAG="$VERSION" ;; *) TAG="v$VERSION" ;; esac
fi

printf '%s\n' "${TAG#v}" | grep -Eq '^2\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$' \
    || fail "release $TAG is not a supported OpenCode v2 release"

BASE_URL="https://github.com/$REPOSITORY/releases/download/$TAG"
printf 'OpenCode %s for ARM64 Termux\n' "${TAG#v}"

if [ "$DRY_RUN" -eq 1 ]; then
    printf 'Would install %s/%s\n' "$BASE_URL" "$ARCHIVE"
    exit 0
fi

if ! command -v sha256sum >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    printf 'Installing archive and checksum tools…\n'
    pkg install -y coreutils tar || fail "could not install coreutils and tar"
fi
if ! command -v grun >/dev/null 2>&1; then
    printf 'Installing the Termux glibc runtime…\n'
    pkg install -y glibc-repo || fail "could not enable the Termux glibc repository"
    pkg install -y glibc-runner || fail "could not install glibc-runner"
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/opencode-install.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

printf 'Downloading release…\n'
curl -fL --retry 3 -o "$WORK_DIR/$ARCHIVE" "$BASE_URL/$ARCHIVE" \
    || fail "release archive download failed"
curl -fsSL --retry 3 -o "$WORK_DIR/$CHECKSUM" "$BASE_URL/$CHECKSUM" \
    || fail "release checksum download failed"

(
    cd "$WORK_DIR"
    sha256sum --check "$CHECKSUM"
) || fail "release checksum verification failed"

mkdir -p "$WORK_DIR/payload"
tar -xzf "$WORK_DIR/$ARCHIVE" -C "$WORK_DIR/payload" \
    || fail "could not extract release"
PACKAGE="$WORK_DIR/payload/opencode-termux"
test -x "$PACKAGE/bin/opencode" || fail "release is missing the Termux launcher"
test -x "$PACKAGE/libexec/opencode/opencode.bin" || fail "release is missing the OpenCode binary"

grun "$PACKAGE/libexec/opencode/opencode.bin" --version >/dev/null \
    || fail "the downloaded OpenCode binary did not start"

mkdir -p "$PREFIX/bin" "$PREFIX/libexec/opencode"
install -m 755 "$PACKAGE/libexec/opencode/opencode.bin" \
    "$PREFIX/libexec/opencode/.opencode.bin.new"
install -m 644 "$PACKAGE/VERSION" "$PREFIX/libexec/opencode/.VERSION.new"
install -m 755 "$PACKAGE/bin/opencode" "$PREFIX/bin/.opencode.new"

mv -f "$PREFIX/libexec/opencode/.opencode.bin.new" "$PREFIX/libexec/opencode/opencode.bin"
mv -f "$PREFIX/libexec/opencode/.VERSION.new" "$PREFIX/libexec/opencode/VERSION"
mv -f "$PREFIX/bin/.opencode.new" "$PREFIX/bin/opencode"

printf 'Installed successfully: '
opencode --version
printf 'Run: opencode\n'
