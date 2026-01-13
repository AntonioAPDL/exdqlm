PDF=build/main.pdf
TEX=main.tex
OUTDIR=build

all: $(PDF)

$(PDF): $(TEX)
	@mkdir -p $(OUTDIR)
	@pdflatex -interaction=nonstopmode -halt-on-error -output-directory=$(OUTDIR) $(TEX)
	@pdflatex -interaction=nonstopmode -halt-on-error -output-directory=$(OUTDIR) $(TEX)

clean:
	@rm -f $(OUTDIR)/*.aux $(OUTDIR)/*.log $(OUTDIR)/*.nav $(OUTDIR)/*.out $(OUTDIR)/*.snm $(OUTDIR)/*.toc $(OUTDIR)/*.vrb $(OUTDIR)/*.pdf

.PHONY: all clean
