# Planning document build

This directory contains documentation only. No model, sampler, forecast, benchmark, or executable experiment configuration is implemented here. The Markdown is the editable statistical specification; the PDF is its reviewed rendering. All experiment controls are proposed future controls.

The PDF was built with Pandoc, XeLaTeX, DejaVu Serif/Sans/Sans Mono, the included header, A4 paper, 19 mm margins and 10 pt body text. Build from the repository root. The following commands generate the document only:

```bash
mkdir -p /tmp/autodesn-plan-build
python - <<'PY'
from pathlib import Path
import subprocess
s = subprocess.check_output(['pandoc', '-D', 'latex'], text=True)
s = s.replace('\\maketitle', '\\maketitle\n\\thispagestyle{empty}\n\\newpage')
s = s.replace('\\tableofcontents\n}', '\\tableofcontents\n}\\newpage')
Path('/tmp/autodesn-plan-build/template.tex').write_text(s)
PY
pandoc validation/autodesn/nonlinear_heteroscedastic/plans/REMEDIATION_PLAN.md \
  --from markdown+tex_math_dollars+raw_tex --pdf-engine=xelatex \
  --template=/tmp/autodesn-plan-build/template.tex \
  --include-in-header=validation/autodesn/nonlinear_heteroscedastic/plans/pdf_header.tex \
  --toc --toc-depth=1 --number-sections \
  -V documentclass=article -V fontsize=10pt -V papersize=a4 \
  -V geometry:margin=19mm -V mainfont='DejaVu Serif' \
  -V sansfont='DejaVu Sans' -V monofont='DejaVu Sans Mono' \
  -V colorlinks=true -V linkcolor=planblue -V urlcolor=planblue \
  -o validation/autodesn/nonlinear_heteroscedastic/plans/output/pdf/AutoDESN_Remediation_Plan.pdf
```

Render every page with Poppler and inspect equations, tables, links, contents, page breaks and margins. The committed `document_review.json` binds the actual visual review to the delivered PDF/source hashes. It validates the planning artifact, not any of its proposed statistical implementation or experiments. Byte-identical PDFs across different TeX/font versions are not promised.
