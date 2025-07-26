##
# Artem's CV
#

all:
	./cv.hs > cv.tex
	latexmk -pdf -pdflatex='pdflatex -file-line-error -synctex=1' cv.tex

# end
