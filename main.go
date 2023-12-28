// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This file holds the go generate command to run yacc on the grammar in expr.y.
// To build expr:
//	% go generate
//	% go build

//go:generate goyacc -p yaccDate -o yaccDate.go yaccDate.y

// Expr is a simple expression evaluator that serves as a working example of
// how to use Go's yacc implementation.
package main

import (
	"bufio"
	"fmt"
	"os"
)

func main() {
	yaccDateDebug = 1
	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Print("Enter text: ")
		text, _ := reader.ReadString('\n')
		lexer := NewLexer(text)
		fmt.Println(yaccDateParse(lexer), lexer.result)
	}
}
