
name := "hsh"

run: build
    ./{{name}} --cmd ls

build:
    gcc -g -Wall {{name}}.c -o {{name}}
