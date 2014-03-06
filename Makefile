FOLDERS := supercompilation:celestria

export TEXINPUTS := ${FOLDERS}:${TEXINPUTS}
export BIBINPUTS := ${FOLDERS}:${BIBINPUTS}
export BSTINPUTS := ${FOLDERS}:${BSTINPUTS}

issue = Issue23

lhssources = fizzbuzz.lhs
texsources = Editorial.tex fizzbuzz.tex supercompilation/supercompilation.tex mflow.tex nccb.tex

default: $(issue).pdf

$(issue).tex : $(issue).lhs $(texsources) $(lhssources)
	lhs2TeX $(issue).lhs > $(issue).tex

%.pdf: %.tex force
	pdflatex $<

%.tex: %.lhs
	lhs2TeX $< -o $@

clean:
	rm -f *.log *.aux *.toc *.out *.blg *.bbl *.ptb *~
	rm -f $(issue).tex

# put .bib files here
bib :
	bibtex supercompilation
	bibtex fizzbuzz
	bibtex mflow
	bibtex celestria_main

final : $(issue).pdf bib
	pdflatex $(issue).tex
	pdflatex $(issue).tex
	pdflatex $(issue).tex

.PHONY : force
