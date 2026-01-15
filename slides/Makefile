PDF=build/main.pdf
TEX=main.tex
OUTDIR=build
ROOT=$(abspath ..)
AUTO=build/sections/auto_runs.tex

all: $(PDF)

$(PDF): $(TEX) $(AUTO)
	@mkdir -p $(OUTDIR)
	@pdflatex -interaction=nonstopmode -halt-on-error -output-directory=$(OUTDIR) $(TEX)
	@pdflatex -interaction=nonstopmode -halt-on-error -output-directory=$(OUTDIR) $(TEX)

$(AUTO): $(ROOT)/scripts/build_slides_from_runs.R config/slide_runs.yaml config/slide_content.yaml
	@mkdir -p build/sections
	@Rscript $(ROOT)/scripts/build_slides_from_runs.R --root $(ROOT)

clean:
	@rm -f $(OUTDIR)/*.aux $(OUTDIR)/*.log $(OUTDIR)/*.nav $(OUTDIR)/*.out $(OUTDIR)/*.snm $(OUTDIR)/*.toc $(OUTDIR)/*.vrb $(OUTDIR)/*.pdf

.PHONY: all clean
