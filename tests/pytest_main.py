"""Entry point for running quack's pytest suite under `bazel test`.

Redirects every host-state escape hatch into Bazel's per-test TEST_TMPDIR
before anything CUDA-related is imported, so tests start from a clean JIT
cache and never write outside the sandbox:

- HOME: cutlass-dsl, torch inductor, and quack's own cache all default to
  paths under ~/.cache.
- CUTE_DSL_CACHE_DIR: cutlass-dsl compile cache, set explicitly for clarity.

Usage (wired by tests/BUILD.bazel): pytest_main.py -svvx <test file>
"""

import os
import sys


def _redirect_host_state() -> None:
    tmp = os.environ.get("TEST_TMPDIR")
    if not tmp:
        return
    os.environ["HOME"] = tmp
    os.environ.setdefault("XDG_CACHE_HOME", os.path.join(tmp, "cache"))
    os.environ.setdefault("CUTE_DSL_CACHE_DIR", os.path.join(tmp, "cute_dsl_cache"))


if __name__ == "__main__":
    _redirect_host_state()
    import pytest

    sys.exit(pytest.main(sys.argv[1:]))
