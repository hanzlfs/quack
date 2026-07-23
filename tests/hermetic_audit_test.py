"""Hermeticity audit."""

import os
import shutil
import sys

# Host-state redirection must happen before any CUDA-related import (this
# test bypasses pytest_main.py, so it does its own).
_TMP = os.environ.get("TEST_TMPDIR")
if _TMP:
    os.environ["HOME"] = _TMP
    os.environ.setdefault("XDG_CACHE_HOME", os.path.join(_TMP, "cache"))
    os.environ.setdefault("CUTE_DSL_CACHE_DIR", os.path.join(_TMP, "cute_dsl_cache"))

# The driver is the declared platform boundary; its userland halves live in
# system paths and are the only CUDA libraries allowed from outside the
# dependency closure.
DRIVER_LIB_PREFIXES = ("libcuda.so", "libnvidia-", "libnvidia_")

# Substrings identifying CUDA userland libraries that MUST come from wheels.
CUDA_LIB_MARKERS = (
    "libcudart",
    "libcublas",
    "libcudnn",
    "libnvrtc",
    "libcufft",
    "libcurand",
    "libcusolver",
    "libcusparse",
    "libcupti",
    "libnvJitLink",
    "libcute_dsl_runtime",
)

FORBIDDEN_ENV = ("CUDA_HOME", "CUDA_PATH", "CUDA_ROOT")


def fail(msg: str) -> None:
    print(f"AUDIT FAIL: {msg}")
    sys.exit(1)


def allowed_roots() -> tuple:
    # Everything Bazel provides lives under the runfiles tree or the
    # external repos of the output base; TEST_TMPDIR holds the JIT cache.
    roots = [os.getcwd()]  # runfiles workspace dir (cwd of a bazel test)
    for var in ("TEST_SRCDIR", "RUNFILES_DIR", "TEST_TMPDIR"):
        value = os.environ.get(var)
        if value:
            roots.append(os.path.realpath(value))
    # sys.prefix covers the hermetic interpreter (external repo, reached
    # via realpath'd symlinks).
    roots.append(os.path.realpath(sys.prefix))
    # Wheel repos live under <output_base>/external; runfiles symlinks
    # resolve there, so cover it via any site-packages entry.
    for entry in sys.path:
        if "site-packages" in entry:
            roots.append(os.path.realpath(entry).split("site-packages")[0])
    return tuple(set(roots))


def main() -> None:
    for var in FORBIDDEN_ENV:
        if var in os.environ:
            fail(f"{var} leaked into the test environment: {os.environ[var]}")

    for tool in ("ptxas", "nvcc"):
        found = shutil.which(tool)
        if found and not os.path.realpath(found).startswith(allowed_roots()):
            fail(f"{tool} reachable from host PATH: {found}")

    import torch  # noqa: E402

    import quack  # noqa: E402

    x = torch.randn(64, 256, device="cuda", dtype=torch.bfloat16)
    w = torch.randn(256, device="cuda", dtype=torch.bfloat16)
    out = quack.rmsnorm(x, weight=w)  # forces a CuTe DSL JIT compile
    torch.cuda.synchronize()
    if out.shape != x.shape:
        fail(f"kernel smoke check failed: {out.shape} != {x.shape}")

    roots = allowed_roots()
    violations = []
    with open("/proc/self/maps") as maps:
        mapped = {
            line.split()[-1]
            for line in maps
            if line.rstrip().endswith(".so") or ".so." in line.split()[-1]
        }
    for path in sorted(mapped):
        base = os.path.basename(path)
        if not any(marker in base for marker in CUDA_LIB_MARKERS):
            continue  # not a CUDA userland library
        if base.startswith(DRIVER_LIB_PREFIXES):
            continue  # driver family: the declared boundary
        if not os.path.realpath(path).startswith(roots):
            violations.append(path)

    if violations:
        print("CUDA userland libraries loaded from OUTSIDE the dependency closure:")
        for v in violations:
            print(f"  {v}")
        fail("host CUDA leaked into the JIT/runtime path")

    audited = [p for p in mapped if any(m in os.path.basename(p) for m in CUDA_LIB_MARKERS)]
    print(f"AUDIT OK: {len(audited)} CUDA userland libraries, all from the dependency closure")


if __name__ == "__main__":
    main()
