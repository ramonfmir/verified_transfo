.PHONY: all 

all:
	latexmk -pdf gallium
	latexmk -pdf camus

loop:
	latexmk -pdf -pvc -view=pdf main

clean:
	latexmk -c 
	rm -f gallium.pdf camus.pdf
	rm -f _*
	rm -f *.nav *.snm *.vrb 

# rm -f *.fdb_latexmk *.fls *.toc

