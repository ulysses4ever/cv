##
# Artem's CV
#

all:
	nix-build
	cp result/cv.pdf cv.pdf
	chmod u+w cv.pdf

pdf:
	runhaskell ./cv.hs > cv.tex
	latexmk -pdf -pdflatex='pdflatex -interaction=nonstopmode -file-line-error -synctex=1' cv.tex

clean:
	latexmk -c cv.tex
# end
