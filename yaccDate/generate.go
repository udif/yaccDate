// This file holds the go generate command to run yacc on the grammar in expr.y.
// To build expr:
//	% go generate
//	% go build

//go:generate goyacc -p yaccDate -o yaccDate.go yaccDate.y

package yaccDate
