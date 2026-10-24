#!/bin/sh

set -eu

main() {
  repo="catalog-cmake/catalog"
  tag="${CATALOG_VERSION:-cli-nightly}"
  dir="${CATALOG_INSTALL_DIR:-}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --dir)
        [ $# -ge 2 ] || die "--dir needs a value"
        dir="$2"; shift 2 ;;
      --dir=*)
        dir="${1#--dir=}"; shift ;;
      --version)
        [ $# -ge 2 ] || die "--version needs a value"
        tag="$2"; shift 2 ;;
      --version=*)
        tag="${1#--version=}"; shift ;;
      -h|--help)
        usage
        return 0 ;;
      *)
        die "unknown option: $1 (see --help)" ;;
    esac
  done

  base="${CATALOG_RELEASE_URL:-https://github.com/$repo/releases/download/$tag}"

  if [ -z "$dir" ]; then
    dir="/usr/local/bin"
  fi

  if command -v curl >/dev/null 2>&1; then
    fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }
  elif command -v wget >/dev/null 2>&1; then
    fetch() { wget -q -O "$2" "$1"; }
  else
    die "neither curl nor wget found"
  fi

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT INT TERM

  say "downloading $base/catalog"
  fetch "$base/catalog" "$tmp/catalog" || die "could not download $base/catalog"
  fetch "$base/catalog.sha256" "$tmp/catalog.sha256" || die "could not download $base/catalog.sha256"

  expected="$(awk 'NR==1 {print $1}' "$tmp/catalog.sha256")"
  actual="$(sha256 "$tmp/catalog")" || actual=""
  if [ -z "$actual" ]; then
    warn "no sha256 tool found (sha256sum, shasum or openssl); the download was NOT verified"
  elif [ "$expected" != "$actual" ]; then
    die "checksum mismatch for the downloaded file (expected $expected, got $actual); nothing was installed"
  else
    say "checksum ok"
  fi

  priv=""
  if ! writable "$dir"; then
    if command -v doas >/dev/null 2>&1; then
      priv=doas
    elif command -v sudo >/dev/null 2>&1; then
      priv=sudo
    else
      die "no write access to $dir (try --dir, run as root, or install doas or sudo)"
    fi
    say "$dir is not writable by you; using $priv to copy the file there"
  fi
  as_root mkdir -p "$dir" \
    && as_root cp "$tmp/catalog" "$dir/.catalog.$$" \
    && as_root chmod 755 "$dir/.catalog.$$" \
    && as_root mv -f "$dir/.catalog.$$" "$dir/catalog" \
    || { as_root rm -f "$dir/.catalog.$$"; die "could not install into $dir"; }
  say "installed $dir/catalog"

  if command -v cmake >/dev/null 2>&1; then
    cmver="$(cmake --version 2>/dev/null | sed -n '1s/.* //p')"
    if ! printf '%s\n' "$cmver" | awk -F. '{ exit !($1 > 3 || ($1 == 3 && $2 >= 25)) }'; then
      warn "catalog needs CMake 3.25 or newer, found ${cmver:-an unknown version}"
    fi
  else
    warn "catalog needs CMake 3.25 or newer, which was not found in PATH"
  fi

  case ":$PATH:" in
    *":$dir:"*) ;;
    *) warn "$dir is not in your PATH; add it, e.g.:  export PATH=\"$dir:\$PATH\"" ;;
  esac
}

usage() {
  cat <<'USAGE'
Installs the Catalog command line interface (a single self-contained file).

  curl -fsSL https://raw.githubusercontent.com/catalog-cmake/catalog/main/install.sh | sh
  curl -fsSL https://raw.githubusercontent.com/catalog-cmake/catalog/main/install.sh | sh -s -- [options]

Options (or the environment variable in brackets):
  --dir DIR        where to put `catalog`  [CATALOG_INSTALL_DIR]
                   default: /usr/local/bin (doas/sudo is used for the final copy if you cannot write there)
  --version TAG    release to install      [CATALOG_VERSION]    default: cli-nightly
  -h, --help

[CATALOG_RELEASE_URL] overrides the download location (a directory containing `catalog` and
`catalog.sha256`), e.g. for a mirror.
USAGE
}

as_root() {
  if [ -n "$priv" ]; then "$priv" "$@"; else "$@"; fi
}

writable() {
  d="$1"
  while [ ! -e "$d" ] && [ "$d" != / ]; do d="$(dirname "$d")"; done
  [ -w "$d" ]
}

say()  { printf 'catalog install: %s\n' "$*"; }
warn() { printf 'catalog install: warning: %s\n' "$*" >&2; }
die()  { printf 'catalog install: error: %s\n' "$*" >&2; exit 1; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    return 1
  fi
}

main "$@"
