"""Repository rule materializing @cutlass_dsl from the libs wheels.

Environment knobs (both tracked; changing them refetches the repo):
  CUTLASS_DSL_CUDA_LINE   "cu13" (default) or "cu12" — which DSL runtime
                          wheel is materialized (set via --config=cu12/cu13).
  LOCAL_CUTLASS_DSL_PATH  escape hatch: symlink a local extracted tree
                          (editable-checkout workflow) instead of fetching.
"""

load(":wheels.bzl", "CUTLASS_DSL_WHEELS")

_COMPONENT_ORDER = ("libs_core", "libs_base")  # + the selected cuda line

def _platform(repository_ctx):
    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch
    if "linux" in os_name and arch in ("amd64", "x86_64"):
        return "x86_64-unknown-linux-gnu"
    fail("cutlass_dsl_repository: unsupported platform {}/{} (only linux x86_64 wheels are pinned)".format(os_name, arch))

def _impl(repository_ctx):
    version = repository_ctx.attr.version
    cuda_line = repository_ctx.getenv("CUTLASS_DSL_CUDA_LINE") or "cu13"
    if cuda_line not in ("cu12", "cu13"):
        fail("CUTLASS_DSL_CUDA_LINE must be cu12 or cu13, got: " + cuda_line)

    local_path = repository_ctx.getenv("LOCAL_CUTLASS_DSL_PATH")
    if local_path:
        repository_ctx.symlink(local_path + "/nvidia_cutlass_dsl", "nvidia_cutlass_dsl")
    else:
        by_version = CUTLASS_DSL_WHEELS.get(version)
        if not by_version:
            fail("cutlass_dsl_repository: version {} not in wheels.bzl (run tools/update_cutlass_dsl_wheels.py)".format(version))
        components = by_version[_platform(repository_ctx)]
        for component in _COMPONENT_ORDER + ("libs_" + cuda_line,):
            url, sha256 = components[component]
            zip_name = component + ".zip"  # wheels ARE zips; rename so extract() recognizes them
            repository_ctx.download(url = url, output = zip_name, sha256 = sha256)
            # The wheels' nvidia_cutlass_dsl/ trees are path-disjoint
            # (verified 2026-07-22: core=144, base=94, cu*=5 files, zero
            # overlap), so extracting into the repo root IS the merge.
            repository_ctx.extract(archive = zip_name)
            repository_ctx.delete(zip_name)

    repository_ctx.file(
        "version.bzl",
        'VERSION = "{}"\nCUDA_LINE = "{}"\n'.format(version, cuda_line),
    )
    repository_ctx.template(
        "BUILD.bazel",
        repository_ctx.attr._build_tpl,
        substitutions = {
            "%{version}": version,
            "%{cuda_line}": cuda_line,
        },
    )

cutlass_dsl_repository = repository_rule(
    implementation = _impl,
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "nvidia-cutlass-dsl version; must exist in wheels.bzl (lockstep across all components by construction).",
        ),
        "_build_tpl": attr.label(
            default = Label("//bazel/cutlass_dsl:cutlass.BUILD.tpl"),
        ),
    },
    doc = "Materializes the CuTe DSL from hash-pinned libs wheels as a native py_library (no pip semantics).",
)
