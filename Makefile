##
# Artem's CV
#

all:
	nix-build
	cp result/cv.pdf cv.pdf
	chmod u+w cv.pdf

pdf:
	runhaskell ./cv.hs > cv.tex
	latexmk -pdf -pdflatex='pdflatex -file-line-error -synctex=1' cv.tex

dblp-bib:
	wget https://dblp.org/pid/165/7962.bib -o biblio.dplp.bib

clean:
	latexmk -c cv.tex
# end
