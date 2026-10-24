# Executed environment and reconstruction

The study uses project-local R 4.5.3 with OpenBLAS 0.3.34, Julia 1.10.10,
and the authors' AutoGP 0.1.19 source at commit
`2ad372db2b8bea176e3b32a769bfb5d6cff80866` from
https://github.com/probsys/AutoGP.jl. R uses one BLAS thread; the unchanged
native AutoGP driver uses two BLAS threads and one Julia thread. Large jobs
run sequentially under an 8 GiB memory limit. Light validation and integrity
checks can overlap them. Timings describe the observed environment.

After restoring the numeric evidence, `evidence/restored/validation/` contains
`R_environment.txt`, `R_packages.csv`, `conda_explicit.txt`,
`manual_dependency_sources.json`, `Python_environment.json`,
`Julia_runtime.json`, `hardware.json`, and the native Julia project's
`Project.toml`/`Manifest.toml`. These record executed versions and checksums.
The R source dependency tarballs for `crch` and `scoringRules` have explicit
versions, URLs and SHA256 hashes in the manual-dependency manifest.

To reconstruct the conda runtime with micromamba, convert the archived package
listing to conda's explicit-file format first:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('validation/autodesn/nonlinear_heteroscedastic/evidence/restored/validation')
urls = [x for x in (p/'conda_explicit.txt').read_text().splitlines()
        if x.startswith('https://')]
assert urls
Path('runtime-explicit.txt').write_text('@EXPLICIT\n' + '\n'.join(urls) + '\n')
PY
micromamba create --yes --prefix .runtime/r --file runtime-explicit.txt
export PATH="$PWD/.runtime/r/bin:$PATH"
export LD_LIBRARY_PATH="$PWD/.runtime/r/lib"
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
```

Install the two manual R source packages at their recorded versions after
checking their SHA256 values, then install this checkout with `R CMD INSTALL .`.
Use the recorded Python versions for NumPy, SciPy, pandas, matplotlib,
ReportLab, Pillow, pypdf and pdfplumber. The evidence restorer itself uses only
Python's standard library. Python 3.11 or later supplies `tomllib`.

Use the Julia binary and checksum in `Julia_runtime.json`. Clone the native
AutoGP repository, check out the exact commit above, place the archived
`Manifest.toml` beside its unchanged `Project.toml`, and instantiate/precompile
that project. Set `JULIA_DEPOT_PATH` to a project-local directory and
`JULIA_NUM_THREADS=1`. The new-series launcher clears the R-specific
`LD_LIBRARY_PATH` before starting Julia; this avoids substituting R's shared
libraries into the Julia runtime.

Run the experiments from the repository root using README.md. The executed
R/src and harness hashes in every fit's provenance take precedence over a
branch name or package version. Reusing a checkpoint with a changed target,
input, feature transform or executed source is rejected by the drivers.
The independent tests are distinct from the full-size convergence screens.
