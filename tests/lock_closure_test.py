"""Guard: every nvidia-/cuda- package in the lock is in the Bazel dep graph.

rules_python drops wheel dependency edges gated on `extra == "..."` markers
(cuda-toolkit declares ALL of its libraries that way), so a package can be
hash-pinned in requirements_lock.txt yet silently absent from the Bazel
dependency closure — surfacing only as an import-time crash on the GPU box.
BUILD.bazel compensates with the explicit `:cuda_userland` target; this test
turns any future drift (new lock entry, upstream moving a dep behind an
extra) into a red test instead of a runtime failure.

Scoped to nvidia-/cuda- distributions because the lock also pins dev tools
(ruff, pre-commit, ...) that are intentionally not part of the library graph.

Needs no GPU: it only compares lock entries against installed distribution
metadata visible on sys.path.
"""

import importlib.metadata
import re
import sys
from pathlib import Path

PREFIXES = ("nvidia-", "cuda-")


def canonical(name: str) -> str:
    return name.lower().replace("_", "-")


def main() -> int:
    lock_text = Path("requirements_lock.txt").read_text()
    wanted = {
        canonical(m.group(1))
        for m in re.finditer(r"^([A-Za-z0-9_.-]+)==", lock_text, re.MULTILINE)
        if canonical(m.group(1)).startswith(PREFIXES)
    }
    if not wanted:
        print("ERROR: no nvidia-/cuda- entries parsed from requirements_lock.txt")
        return 1

    have = {
        canonical(dist.metadata["Name"])
        for dist in importlib.metadata.distributions()
        if dist.metadata["Name"]
    }
    missing = sorted(wanted - have)
    if missing:
        print(
            "Lock entries missing from the Bazel dependency graph "
            "(likely extras-gated edges dropped by rules_python; add them "
            "to :cuda_userland in BUILD.bazel):"
        )
        for name in missing:
            print(f"  {name}")
        return 1

    print(f"OK: all {len(wanted)} nvidia-/cuda- lock entries are in the graph")
    return 0


if __name__ == "__main__":
    sys.exit(main())
