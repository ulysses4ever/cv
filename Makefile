##
# Artem's CV
#
# Every target assumes ghc and texlive are on PATH, i.e. that make is running
# inside the nix shell:
#
#     nix-shell --run make
#
# `nix-build' is the other entry point; it runs `make' in the sandbox and leaves
# the PDFs in ./result.

.PHONY: all tex pdf teaching-first clean

all: pdf teaching-first

# Via a temporary so a failing runhaskell leaves the previous cv.tex intact
# rather than an empty file that later targets happily compile.
tex:
	runhaskell ./cv.hs > cv.tex.tmp
	mv cv.tex.tmp cv.tex

pdf: tex
	latexmk -pdf -pdflatex='pdflatex -interaction=nonstopmode -file-line-error -synctex=1' cv.tex

# Same cv.tex; \TEACHINGEARLY moves Teaching Experience up to just after
# Experience. Run twice because hyperref anchors need a second pass.
teaching-first: tex
	pdflatex -jobname=cv-teaching-first -interaction=nonstopmode -file-line-error '\def\TEACHINGEARLY{}\input{cv.tex}'
	pdflatex -jobname=cv-teaching-first -interaction=nonstopmode -file-line-error '\def\TEACHINGEARLY{}\input{cv.tex}'

clean:
	latexmk -c cv.tex
	rm -f cv.tex.tmp cv-teaching-first.aux cv-teaching-first.log cv-teaching-first.out
# end
