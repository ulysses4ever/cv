##
# Artem's CV
#

all:
	runhaskell ./cv.hs > cv.tex
	latexmk -pdf -pdflatex='pdflatex -file-line-error -synctex=1' cv.tex

dblp-bib:
	wget https://dblp.org/pid/165/7962.bib -o biblio.dplp.bib

clean:
	latexmk -c cv.tex
# end
