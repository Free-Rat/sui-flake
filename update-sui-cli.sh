#!/usr/bin/env bash
set -euo pipefail

if ! command -v python3 &>/dev/null; then
    echo "python3 not found, entering nix shell for it..."
    exec nix shell nixpkgs#python3 --command bash "$0" "$@"
fi

if [ $# -lt 1 ]; then
    echo "Usage: $0 <version> [owner/repo]"
    echo "  version:  e.g. 1.69.2 (the mainnet version number)"
    echo "  owner/repo:  e.g. MystenLabs/sui (default: MystenLabs/sui)"
    exit 1
fi

VERSION="$1"
REPO="${2:-MystenLabs/sui}"
OWNER="$(echo "$REPO" | cut -d/ -f1)"
PROJ="$(echo "$REPO" | cut -d/ -f2)"
TAG="mainnet-v${VERSION}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NIX_FILE="${SCRIPT_DIR}/sui-cli/default.nix"
CARGO_LOCK="${SCRIPT_DIR}/sui-cli/Cargo.lock"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== Updating sui-cli to ${TAG} ==="

echo ""
echo "[1/5] Fetching source tarball hash..."
SRC_HASH=$(nix-prefetch-url --unpack "https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz" 2>&1 \
    | tail -1)
SRC_HASH_SRI=$(nix hash convert --hash-algo sha256 --to sri "$SRC_HASH")
echo "  hash = ${SRC_HASH_SRI}"

echo ""
echo "[2/5] Downloading Cargo.lock..."
curl -sL "https://raw.githubusercontent.com/${REPO}/${TAG}/Cargo.lock" -o "${TMPDIR}/Cargo.lock"
cp "${TMPDIR}/Cargo.lock" "${CARGO_LOCK}"
echo "  saved to ${CARGO_LOCK}"

echo ""
echo "[3/5] Getting GIT_REVISION (full commit SHA)..."
GIT_REV=$(git ls-remote "https://github.com/${REPO}.git" "refs/tags/${TAG}^{}" "refs/tags/${TAG}" | head -1 | awk '{print $1}')
if [ -z "$GIT_REV" ]; then
    echo "  WARNING: could not resolve tag ${TAG} via ls-remote, trying GitHub API..."
    GIT_REV=$(curl -sL "https://api.github.com/repos/${REPO}/git/ref/tags/${TAG}" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['object']['sha'])" 2>/dev/null || true)
fi
if [ -z "$GIT_REV" ]; then
    echo "  ERROR: could not determine commit SHA for tag ${TAG}"
    echo "  Set GIT_REVISION manually in ${NIX_FILE}"
    GIT_REV="FIXME-SET-MANUALLY"
fi
echo "  GIT_REVISION = ${GIT_REV}"

echo ""
echo "[4/5] Parsing git dependencies from Cargo.lock..."
# Extract unique git SHAs and their representative name-version
# Format: each line is "name-version  git-url  sha"
python3 -c "
import tomllib, sys
with open('${CARGO_LOCK}', 'rb') as f:
    data = tomllib.load(f)
seen_shas = {}
for pkg in data.get('package', []):
    source = pkg.get('source', '')
    if source.startswith('git+'):
        sha = source.split('#')[-1]
        key = pkg['name'] + '-' + pkg['version']
        if sha not in seen_shas:
            # strip git+ prefix and ?rev=... suffix, keep just the URL
            url = source[4:].split('?')[0].split('#')[0]
            seen_shas[sha] = (key, url)
for sha, (key, url) in sorted(seen_shas.items()):
    print(f'{key}\t{url}\t{sha}')
" > "${TMPDIR}/git_deps.tsv"
DEP_COUNT=$(wc -l < "${TMPDIR}/git_deps.tsv")
echo "  Found ${DEP_COUNT} unique git dependencies"

echo ""
echo "[5/5] Computing outputHashes (this may take a while)..."
OUTPUT_HASHES=""
i=0
while IFS=$'\t' read -r key url sha; do
    i=$((i + 1))
    printf "  [%2d/%d] %s ... " "$i" "$DEP_COUNT" "$key"
    # Try fetching the archive tarball for this commit
    # Normalize URL: strip .git suffix for GitHub URLs
    GITHUB_URL="${url%.git}"
    TARBALL_URL="${GITHUB_URL}/archive/${sha}.tar.gz"
    HASH_SRI=""
    if [[ "$GITHUB_URL" == github.com/* ]]; then
        PREFETCH=$(nix-prefetch-url --unpack "$TARBALL_URL" 2>/dev/null || true)
        if [ -n "$PREFETCH" ]; then
            HASH_SRI=$(nix hash convert --hash-algo sha256 --to sri "$(echo "$PREFETCH" | tail -1)")
        fi
    fi
    # Fallback: use nix hash from a local clone via fetchgit
    if [ -z "$HASH_SRI" ]; then
        # Use nix-build to compute hash via fetchgit
        HASH_SRI=$(nix-build --expr "
            let pkgs = import <nixpkgs> {};
            in pkgs.fetchgit { url = \"${url}\"; rev = \"${sha}\"; sha256 = pkgs.lib.fakeHash; }
        " --no-out-link 2>&1 | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1 || true)
        if [ -z "$HASH_SRI" ]; then
            # Second attempt: build with fake hash to get the real one
            HASH_SRI=$(nix-build --expr "
                let pkgs = import <nixpkgs> {};
                in pkgs.fetchgit { url = \"${url}\"; rev = \"${sha}\"; sha256 = \"$(nix hash convert --hash-algo sha256 --to nix pkgs.lib.fakeHash || echo lib.fakeHash)\"; }
            " --no-out-link 2>&1 | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1 || true)
        fi
        if [ -z "$HASH_SRI" ]; then
            echo "FAILED (will need manual hash)"
            OUTPUT_HASHES+="      \"${key}\" = \"FIXME\";  # ${url} ${sha}\n"
            continue
        fi
    fi
    echo "${HASH_SRI}"
    OUTPUT_HASHES+="      \"${key}\" = \"${HASH_SRI}\";\n"
done < "${TMPDIR}/git_deps.tsv"

echo ""
echo "=== Updating ${NIX_FILE} ==="

# Build the outputHashes block
HASHES_BLOCK=$(echo -e "$OUTPUT_HASHES" | head -c -2) # remove trailing newline

# Update the file using sed
sed -i \
    -e "s|version = \".*\";|version = \"${VERSION}\";|" \
    -e "s|hash = \".*\";|hash = \"${SRC_HASH_SRI}\";|" \
    -e "s|GIT_REVISION = \".*\";|GIT_REVISION = \"${GIT_REV}\";|" \
    "$NIX_FILE"

# Replace the outputHashes block
python3 -c "
import re
with open('${NIX_FILE}', 'r') as f:
    content = f.read()
new_hashes = '''outputHashes = {
${HASHES_BLOCK}
    };'''
content = re.sub(
    r'outputHashes = \{[^}]*\};',
    new_hashes,
    content,
    count=1,
    flags=re.DOTALL,
)
with open('${NIX_FILE}', 'w') as f:
    f.write(content)
"

echo ""
echo "=== Done! Review changes in ${NIX_FILE} ==="
echo "  version:      ${VERSION}"
echo "  src hash:     ${SRC_HASH_SRI}"
echo "  GIT_REVISION: ${GIT_REV}"
echo ""
echo "Next steps:"
echo "  1. Review:    git diff"
echo "  2. Build:     nix build .#sui-cli"
echo "  3. Fix any FIXME hashes if fetches failed"
