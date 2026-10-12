##
# Artem's CV
#
# Every target assumes ghc and texlive are on PATH, i.e. that make is running
# inside the nix shell:
#
#     nix-shell --run make
#
# `nix-build' is the other entry point; it runs `make' in the sandbox and leaves
# the PDFs and cv.txt in ./result.

.PHONY: all tex pdf teaching-first txt clean

all: pdf teaching-first txt

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

# The plain-text CV, from the same cv.tex as cv.pdf (the main variant).
# cv2txt.hs stops on any command it does not know rather than leave it out.
# cv.txt is tracked: it goes in the commit with the change that moved it.
# Via a temporary, like tex, so a failing cv2txt leaves cv.txt as it was.
txt: tex
	runhaskell ./cv2txt.hs < cv.tex > cv.txt.tmp
	mv cv.txt.tmp cv.txt

clean:
	latexmk -c cv.tex
	rm -f cv.tex.tmp cv.txt.tmp cv-teaching-first.aux cv-teaching-first.log cv-teaching-first.out
# end
