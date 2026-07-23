#!/usr/bin/env bash

set -euo pipefail

BASE="${QUACK_TOOLS_BASE:-/workspace/users/$USER}"
BIN="$BASE/bin"
MARKER="# added by quack tools/install_bazel.sh"

case "$(uname -sm)" in
    "Linux x86_64") ASSET="bazelisk-linux-amd64" ;;
    "Linux aarch64") ASSET="bazelisk-linux-arm64" ;;
    *) echo "unsupported platform: $(uname -sm)" >&2; exit 1 ;;
esac

mkdir -p "$BIN" "$BASE/.cache/bazelisk"

if [ ! -x "$BIN/bazel" ]; then
    echo "installing bazelisk -> $BIN/bazel"
    curl -fsSL -o "$BIN/bazel" \
        "https://github.com/bazelbuild/bazelisk/releases/latest/download/$ASSET"
    chmod +x "$BIN/bazel"
else
    echo "bazelisk already present: $BIN/bazel"
fi

# Machine-local bazel config: build outputs on the volume, not in ~.
touch ~/.bazelrc
if ! grep -q "output_user_root=$BASE/.cache/bazel" ~/.bazelrc; then
    echo "startup --output_user_root=$BASE/.cache/bazel" >> ~/.bazelrc
    echo "wrote output_user_root to ~/.bazelrc"
fi

# Shell wiring (once).
touch ~/.bashrc
if ! grep -qF "$MARKER" ~/.bashrc; then
    {
        echo "$MARKER"
        echo "export PATH=\"$BIN:\$PATH\""
        echo "export BAZELISK_HOME=\"$BASE/.cache/bazelisk\""
    } >> ~/.bashrc
    echo "wired PATH/BAZELISK_HOME into ~/.bashrc"
fi

echo
echo "Done. For THIS shell, run:"
echo "  export PATH=\"$BIN:\$PATH\" BAZELISK_HOME=\"$BASE/.cache/bazelisk\""
echo "New shells pick it up automatically."
