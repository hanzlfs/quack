"""py_test wrapper for quack's pytest-based tests.

Shadows rules_python's py_test with a thin macro holding the wiring every
pytest target shares, so tests/BUILD.bazel stays a flat, reviewable list
of explicit targets. The underlying rule is standard rules_python py_test.
"""

load("@rules_python//python:defs.bzl", _py_test = "py_test")

def py_test(name, src = None, size = "large", tags = [], deps = [], **kwargs):
    """Declares one standard py_test running `pytest -svvx <src>`.

    Entry point is tests/pytest_main.py, which redirects HOME and
    CUTE_DSL_CACHE_DIR into TEST_TMPDIR before pytest starts. Every target
    is tagged "gpu" (opt in with --config=gpu, see .bazelrc); multi-GPU
    tests additionally pass tags = ["manual"] so they only run by explicit
    label.

    Args:
        name: target name. Default src is "<name>.py"; for tests in
            subdirectories pass src explicitly (e.g. name
            "dsl_test_cute_tensor", src "dsl/test_cute_tensor.py").
        src: the pytest file.
        size: bazel test size, default "large".
        tags: extra tags appended after "gpu".
        deps: extra deps appended to the defaults.
        **kwargs: forwarded to py_test (timeout, flaky, ...).
    """
    src = src or name + ".py"
    _py_test(
        name = name,
        srcs = [
            "conftest.py",
            "pytest_main.py",
            src,
        ],
        args = [
            "-svvx",
            "$(location %s)" % src,
        ],
        data = ["//:pyproject.toml"],
        main = "pytest_main.py",
        size = size,
        tags = ["gpu"] + tags,
        deps = [
            "//:quack",
            "@local_pypi//pytest",
            "@local_pypi//pytest_xdist",
        ] + deps,
        **kwargs
    )
