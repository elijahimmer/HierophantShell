
name := "hsh"
# ./{{name}} --cmd ls
# gcc -g -Wall {{name}}.c -o {{name}}

run: build
    ./zig-out/bin/{{name}}

build:
    zig build

test:
    zig build test
