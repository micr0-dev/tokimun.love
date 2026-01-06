#!/bin/bash
set -e

# tokimun installer
# https://tokimun.love

REPO="micr0-dev/tokimun"
INSTALL_DIR="${TOKIMUN_INSTALL_DIR:-$HOME/.local/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

info() { echo -e "${CYAN}›${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; exit 1; }

echo ""
echo -e "${BOLD}  tokimun installer${NC}"
echo "  lua without the pet peeves"
echo ""

# Detect OS
OS="$(uname -s)"
case "$OS" in
  Linux*)  OS="linux" ;;
  Darwin*) OS="darwin" ;;
  *)       error "Unsupported OS: $OS" ;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)             error "Unsupported architecture: $ARCH" ;;
esac

info "Detected: ${OS}/${ARCH}"

# Get latest release
info "Fetching latest release..."

RELEASE_URL="https://api.github.com/repos/${REPO}/releases/latest"
RELEASE_DATA=$(curl -fsSL "$RELEASE_URL" 2>/dev/null) || {
  # Try getting any release if latest doesn't exist
  RELEASE_DATA=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases" 2>/dev/null | head -c 10000)
}

# Parse version
VERSION=$(echo "$RELEASE_DATA" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -z "$VERSION" ]; then
  error "Could not find any releases. Check https://github.com/${REPO}/releases"
fi

# Check if prerelease
IS_PRERELEASE=$(echo "$RELEASE_DATA" | grep -o '"prerelease": *true' | head -1 || true)
if [ -n "$IS_PRERELEASE" ]; then
  warn "This is a pre-release version"
fi

info "Latest version: ${VERSION}"

# Construct download URL
# Expected asset name: tokimun-linux-amd64, tokimun-linux-arm64, etc.
ASSET_NAME="tokimun-${OS}-${ARCH}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET_NAME}"

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download
TEMP_FILE=$(mktemp)
info "Downloading ${ASSET_NAME}..."

HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "$TEMP_FILE" "$DOWNLOAD_URL" 2>/dev/null) || HTTP_CODE="000"

if [ "$HTTP_CODE" != "200" ]; then
  rm -f "$TEMP_FILE"
  echo ""
  error "Download failed (HTTP $HTTP_CODE)
  
  Asset not found: ${ASSET_NAME}
  
  Available at: https://github.com/${REPO}/releases/tag/${VERSION}
  
  You may need to download manually or wait for builds to complete."
fi

# Install
chmod +x "$TEMP_FILE"
mv "$TEMP_FILE" "$INSTALL_DIR/tokimun"

success "Installed tokimun ${VERSION} to ${INSTALL_DIR}/tokimun"

# Check if in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  warn "Add ${INSTALL_DIR} to your PATH:"
  echo ""
  echo "  # Add to your ~/.bashrc or ~/.zshrc:"
  echo "  export PATH=\"\$PATH:${INSTALL_DIR}\""
  echo ""
fi

# Verify
if command -v tokimun &>/dev/null || [ -x "$INSTALL_DIR/tokimun" ]; then
  echo ""
  success "Run 'tokimun --help' to get started"
  echo ""
  echo "  pona pona ✨"
  echo ""
else
  warn "Installation complete but tokimun not found in PATH"
fi