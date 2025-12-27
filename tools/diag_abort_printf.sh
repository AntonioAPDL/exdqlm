#!/usr/bin/env bash
set -euo pipefail

cd /data/muscat_data/jaguir26/exdqlm

echo "== R version =="
R --version | head -n 2
echo

echo "== Clean check dir =="
rm -rf exdqlm.Rcheck exdqlm_*.tar.gz
echo

echo "== Build tarball =="
R CMD build .
echo

echo "== Run check (expect WARNING until fixed) =="
R CMD check exdqlm_*.tar.gz --as-cran --no-clean || true
echo

SO_CHECK="exdqlm.Rcheck/exdqlm/libs/exdqlm.so"
echo "== SO_CHECK=$SO_CHECK =="
if [ -f "$SO_CHECK" ]; then
  nm -u "$SO_CHECK" | egrep '\b(abort|printf)\b' || echo "OK: no abort/printf"
else
  echo "MISSING: $SO_CHECK"
fi
echo

echo "== Installed package shared object path =="
SO_INST="$(Rscript -e 'cat(system.file("libs", paste0("exdqlm", .Platform$dynlib.ext), package="exdqlm"))')"
echo "SO_INST=$SO_INST"
if [ -f "$SO_INST" ]; then
  nm -u "$SO_INST" | egrep '\b(abort|printf)\b' || echo "OK: no abort/printf"
else
  echo "MISSING: installed exdqlm.so (is the package installed?)"
fi
echo

echo "== Rcpp include dir =="
RCPPINC="$(Rscript -e 'cat(system.file("include", package="Rcpp"))')"
echo "RCPPINC=$RCPPINC"
test -d "$RCPPINC"
echo

echo "== Where record_stack_trace is defined =="
grep -RIn --line-number "record_stack_trace" "$RCPPINC" | head -n 80 || true
echo

echo "== First 200 abort/printf hits in Rcpp headers (we will inspect the relevant one) =="
grep -RIn --line-number -E '\b(abort|printf)\b' "$RCPPINC" | head -n 200 || true
echo

echo "== Which objects in the CHECK build reference abort/printf =="
OBJDIR="exdqlm.Rcheck/00_pkg_src/exdqlm/src"
if [ -d "$OBJDIR" ]; then
  for o in "$OBJDIR"/*.o; do
    if nm -u "$o" 2>/dev/null | egrep -q '\b(abort|printf)\b'; then
      echo "-- $o"
      nm -u "$o" | egrep '\b(abort|printf)\b' || true
    fi
  done
else
  echo "MISSING: $OBJDIR"
fi
