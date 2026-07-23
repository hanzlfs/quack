"""Hash-pinned uv resolver binaries (RFC rfc_pyproject_direct_resolution).

The resolver is itself a pinned input: same dict pattern as
bazel/cutlass_dsl/wheels.bzl. To bump: update the version/url and the
sha256 from the .sha256 asset published next to the release tarball
(https://github.com/astral-sh/uv/releases).
"""

UV_VERSION = "0.9.0"

UV_BINARIES = {
    "x86_64-unknown-linux-gnu": (
        "https://github.com/astral-sh/uv/releases/download/0.9.0/uv-x86_64-unknown-linux-gnu.tar.gz",
        "4dadaa5ff5009ccd6a0a43f6ccfa32bf36ed2eff18df7011275a9b1d81950e7b",
    ),
}
