#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "namada" ]]; then
  shift
  HEIGHLINER_PATH="${HEIGHLINER_PATH:-./heighliner}"
  "$HEIGHLINER_PATH" build \
    -c namada \
    -g v101.0.0 \
    --tag v101.0.0 \
    --local \
    --no-cache \
    --no-build-cache
  exit 0
fi

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --repo-host HOST      Git host (default: github.com)
  --org ORG             GitHub org or user (required)
  --repo REPO           GitHub repo name (required)
  --branch REF          Git ref to checkout (branch or tag) (required)
  --tag VERSION         Tag or release version for Docker / heighliner (defaults to branch)
  --workdir DIR         Local clone directory (default: /tmp/\$repo)
  --dest-user USER      Remote SSH user for rsync (optional)
  --dest-host HOST      Remote SSH host for rsync (optional)
  --dest-path PATH      Remote path for rsync (optional)
  -h, --help            Show this help and exit
  namada                Run the Namada build (special command)

Env vars can override any of these flags.
EOF
  exit 1
}

# Default values
HEIGHLINER_PATH="${HEIGHLINER_PATH:-./heighliner}"
REPO_HOST="${REPO_HOST:-github.com}"
ORG="${ORG:-}"
REPO="${REPO:-}"
BRANCH="${BRANCH:-}"
TAG="${TAG:-}"
WORKDIR="${WORKDIR:-}"
DEST_USER="${DEST_USER:-}"
DEST_HOST="${DEST_HOST:-}"
DEST_PATH="${DEST_PATH:-}"

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo-host)   REPO_HOST="$2"; shift 2;;
    --org)         ORG="$2"; shift 2;;
    --repo)        REPO="$2"; shift 2;;
    --branch)      BRANCH="$2"; shift 2;;
    --tag)         TAG="$2"; shift 2;;
    --workdir)     WORKDIR="$2"; shift 2;;
    --dest-user)   DEST_USER="$2"; shift 2;;
    --dest-host)   DEST_HOST="$2"; shift 2;;
    --dest-path)   DEST_PATH="$2"; shift 2;;
    -h|--help)     usage;;
    namada)         ;;
    *)             echo "Unknown option: $1"; usage;;
  esac
done

# Validate required
[[ -n "$ORG"   ]] || { echo "Missing --org";   usage; }
[[ -n "$REPO"  ]] || { echo "Missing --repo";  usage; }
[[ -n "$BRANCH" ]] || { echo "Missing --branch"; usage; }

# Defaults
TAG="${TAG:-$BRANCH}"
WORKDIR="${WORKDIR:-/tmp/${REPO}}"

echo "Parameters:"
echo "  Repo Host: $REPO_HOST"
echo "  Org:       $ORG"
echo "  Repo:      $REPO"
echo "  Branch:    $BRANCH"
echo "  Tag:       $TAG"
echo "  Workdir:   $WORKDIR"
if [[ -n "$DEST_HOST" ]]; then
  echo "  Rsync to:  ${DEST_USER}@${DEST_HOST}:${DEST_PATH}"
fi
echo

rm -rf "$WORKDIR"
echo "Cloning ${REPO_HOST}/${ORG}/${REPO}@${BRANCH} into ${WORKDIR}"
git clone \
  --branch "$BRANCH" \
  --single-branch \
  "https://${REPO_HOST}/${ORG}/${REPO}.git" \
  "$WORKDIR"

echo "Building Go package in $WORKDIR"
pushd "$WORKDIR" >/dev/null
if [[ -f go.mod ]]; then
  go mod tidy
  go build ./...
  echo "Go build succeeded."
else
  echo "Warning: no go.mod found, skipping Go build."
fi
popd >/dev/null

echo "Running heighliner build for chain=$REPO tag=$TAG"
"$HEIGHLINER_PATH" build \
  -c "$REPO" \
  --git-ref "$BRANCH" \
  --tag "$TAG" \
  --local \
  --no-cache \
  --no-build-cache

if [[ -n "$DEST_HOST" ]]; then
  echo "Rsyncing $WORKDIR/ → ${DEST_USER}@${DEST_HOST}:${DEST_PATH}"
  rsync -avz --delete -e ssh "$WORKDIR/" \
    "${DEST_USER}@${DEST_HOST}:${DEST_PATH}"
  echo "Rsync complete."
fi

echo "All done."