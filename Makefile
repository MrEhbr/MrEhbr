print:
	go run github.com/muesli/markscribe@v0.6.0 README.md.tpl

.PHONY: README.md
README.md:
	go run github.com/muesli/markscribe@v0.6.0 -write README.md README.md.tpl