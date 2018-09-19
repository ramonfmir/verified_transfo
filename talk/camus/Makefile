.PHONY: all 

all:
	latexmk -pdf main

loop:
	latexmk -pdf -pvc -view=pdf main

clean:
	latexmk -c 
	rm -f main.pdf
	rm -f _*
	rm -f *.nav *.snm *.vrb 

# rm -f *.fdb_latexmk *.fls *.toc

