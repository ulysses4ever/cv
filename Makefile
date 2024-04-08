##
# Artem's CV
#

all:
	latexmk -pdf -pdflatex='pdflatex -file-line-error -synctex=1' cv.tex

# end
