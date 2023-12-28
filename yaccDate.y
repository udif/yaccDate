// Copyright 2013 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This is an example of a goyacc program.
// To build it:
// goyacc -p "expr" expr.y (produces y.go)
// go build -o expr y.go
// expr
// > <type an expression>

%{

package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strings"
	"strconv"
	"time"
	"unicode"
)

%}

%union {
	// 0 - sec
	// 1 - min
	// 2 - hour
	// 3 - day
	// 4 - month
	// 5 - year
	// 6 - timezone offset (seconds)
	ival int
	arr [7]int
}

%token NUM2 NUM4 WEEKDAY MONTH TIMEZONE '+' '-' ':' UNKNOWN

%type <arr>  top date_string datetime2 datetime date time
%type <ival> year month day second minute hour sign tzoffset timezone TIMEZONE NUM2 NUM4 MONTH

%%

top:
	date_string
	{
        yaccDatelex.(*Lexer).result = $$
	}

date_string:
    datetime2 timezone
	{
		$$ = $1
		$$[6] = $2
	}
  | datetime2 { $$ = $1 }

datetime2:
    weekday datetime { $$ = $2 }
  | datetime { $$ = $1 }

datetime:
	date time
	{
		$$[0] = $2[0]
		$$[1] = $2[1]
		$$[2] = $2[2]
		$$[3] = $1[3]
		$$[4] = $1[4]
		$$[5] = $1[5]
	}

timezone:
    TIMEZONE { $$ = $1 }
  | tzoffset { $$ = $1 }

tzoffset:
    sign NUM2 { $$ = $1 * $2 * 3600}
  | sign NUM4 { $$ = $1 * (($2 / 100) * 3600) + ($2 % 100) * 60 }
  | sign NUM2 ':' NUM2 { $$ = $1 * ($2 * 3600 + $4 * 60) }

sign:
    '+' { $$ =  1 }
  | '-' { $$ = -1 }

weekday:
    WEEKDAY 

time:
	hour ':' minute ':' second
	{
		$$[0] = $5
		$$[1] = $3
		$$[2] = $1
	}
	

hour: NUM2   { $$ = $1 }
minute: NUM2 { $$ = $1 }
second: NUM2 { $$ = $1 }

date:
    day '-' month '-' year
	{
		$$[5] = $5
		$$[4] = $3
		$$[3] = $1
	}
  | day     month     year
	{
		$$[5] = $3
		$$[4] = $2
		$$[3] = $1
	}

day:
    NUM2 { $$ = $1 }

month:
    MONTH { $$ = $1 }
  | NUM2 { $$ = $1 }

year:
    NUM2 { $$ = $1 }
  | NUM4 { $$ = $1 }

%%

var weekDays = map[string]int{
	"sun": 0,
	"mon": 1,
	"tue": 2,
	"wed": 3,
	"thu": 4,
	"fri": 5,
	"sat": 6,
	// Add more week days as needed
}

var monthNames = map[string]time.Month{
	"jan": time.January ,
	"feb": time.February,
	"mar": time.March,
	"apr": time.April,
	"may": time.May,
	"jun": time.June,
	"jul": time.July,
	"aug": time.August,
	"sep": time.September,
	"oct": time.October,
	"nov": time.November,
	"dec": time.December,
	// Add more month names as needed
}

var timeZones = map[string]int{
	"PST": -8 * 60 * 60,
	"PDT": -7 * 60 * 60,
	"EST": -5 * 60 * 60,
	"EDT": -4 * 60 * 60,
	"CST": -6 * 60 * 60,
	"CDT": -5 * 60 * 60,
	"MST": -7 * 60 * 60,
	"MDT": -6 * 60 * 60,
	"UTC": 0,
	"UT":  0,
	"GMT": 0,
	// Add more time zones as needed
}

type Lexer struct {
	result [7]int
	scanner *bufio.Scanner
}

func NewLexer(input string) *Lexer {
	scanner := bufio.NewScanner(strings.NewReader(input))
	scanner.Split(customSplit)
	return &Lexer{scanner: scanner}
}

func customSplit(data []byte, atEOF bool) (advance int, token []byte, err error) {
	// Skip leading spaces or commas.
	start := 0
	for ; start < len(data); start++ {
		if !unicode.IsSpace(rune(data[start])) && data[start] != ',' {
			break
		}
	}
	// Scan until space, comma, or symbol, marking end of word.
	// If we see a letter, consume as a symbol.
	if start >= len(data) {
		// Request more data.
		return start, nil, nil
	}
	if unicode.IsLetter(rune(data[start])) {
		for j := start + 1; j < len(data); j++ {
			if !unicode.IsLetter(rune(data[j])) {
				fmt.Println(j, data[start:j],)
				return j, data[start:j], nil
			}
		}
	} else if unicode.IsDigit(rune(data[start])) {
	// If we see a digit, consume as a number.
		for j := start + 1; j < len(data); j++ {
			if !unicode.IsDigit(rune(data[j])) {
				fmt.Println(j, data[start:j],)
				return j, data[start:j], nil
			}
		}
	} else {
		// Otherwise, consume as a single rune.
		fmt.Println(start + 1, data[start])
		return start + 1, data[start:start+1], nil
	}
	// Return the remaining bytes if we're at EOF.
	if atEOF && len(data) > start {
		return len(data), data[start:], nil
	}

	// Request more data.
	return start, nil, nil
}

func (l *Lexer) Lex(lval *yaccDateSymType) int {
	var err error
	if !l.scanner.Scan() {
		return 0
	}
	token := l.scanner.Text()
	le := len(token)

	// Check for one or two digit integer numbers
	if le <= 2 && unicode.IsDigit(rune(token[0])) && (le == 1 || unicode.IsDigit(rune(token[1]))) {
		lval.ival, err = strconv.Atoi(token)
		if err != nil {
			return UNKNOWN
		}
		return NUM2
	}

	// Check for four digit integers
	if len(token) == 4 && unicode.IsDigit(rune(token[0])) && unicode.IsDigit(rune(token[1])) && unicode.IsDigit(rune(token[2])) && unicode.IsDigit(rune(token[3])) {
		lval.ival, err = strconv.Atoi(token)
		if err != nil {
			return UNKNOWN
		}
		return NUM4
	}

	// Check for week days
	if day, ok := weekDays[strings.ToLower(token)]; ok {
		lval.ival = day
		return WEEKDAY
	}

	// Check for month names
	if month, ok := monthNames[strings.ToLower(token)]; ok {
		lval.ival = int(month)
		return MONTH
	}

	// Check for time zones
	if offset, ok := timeZones[strings.ToUpper(token)]; ok {
		lval.ival = offset
		return TIMEZONE
	}

	// Return other symbols as individual tokens
	if len(token) == 1 {
		if rune(token[0]) == '+' {
			return '+'
		}
		if rune(token[0]) == '-' {
			return '-'
		}
		if rune(token[0]) == ':' {
			return ':'
		}
	}
	return UNKNOWN
}

func (l *Lexer) Error(e string) {
	fmt.Printf("Error: %s\n", e)
}

func FlexDateToTime(dateStr string) time.Time {
	lexer := NewLexer(dateStr)
	if yaccDateParse(lexer) == 1 {
		log.Fatal("Cannot parse date:", dateStr)
		os.Exit(1)
	}
	myzone := time.FixedZone("my_time_zone", lexer.result[6])
	return time.Date(lexer.result[5], time.Month(lexer.result[4]), lexer.result[3], lexer.result[2], lexer.result[1], lexer.result[0], 0, myzone)
}
