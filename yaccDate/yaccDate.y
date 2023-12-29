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

package yaccDate

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strings"
	"strconv"
	"time"
	"unicode"
	"github.com/tkuchiki/go-timezone"
)

type timeDateInfo struct {
	arr [7]int
	tz  string
	off bool // true if offset to be used, overrides tz
}

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
	tdi timeDateInfo
}

%token NUM2 NUM4 WEEKDAY MONTH TIMEZONE '+' '-' ':' '(' ')' '/' UNKNOWN

%type <tdi>  top date_string datetime2 datetime date time timezone TIMEZONE
%type <ival> year month day second minute hour sign tzoffset tzoffset2  NUM2 NUM4 MONTH

%%

top:
	date_string
	{
        yaccDatelex.(*Lexer).result = $$
	}

date_string:
    datetime2 tzoffset2
	{
		$$ = $1
		$$.arr[6] = $2
	}
  | datetime2 timezone
	{
		$$ = $1
		$$.tz = $2.tz
	}
  | datetime2 { $$ = $1 }

datetime2:
    weekday datetime { $$ = $2 }
  | datetime { $$ = $1 }

datetime:
	date time
	{
		$$.arr[0] = $2.arr[0]
		$$.arr[1] = $2.arr[1]
		$$.arr[2] = $2.arr[2]
		$$.arr[3] = $1.arr[3]
		$$.arr[4] = $1.arr[4]
		$$.arr[5] = $1.arr[5]
	}

timezone:
    TIMEZONE { $$ = $1 }
  | '(' TIMEZONE ')' { $$ = $2 }

// combinations of timezone and tzoffset, where tzoffset takes precedence
tzoffset2:
    tzoffset { $$ = $1 }
  | timezone tzoffset { $$ = $2 }
  | tzoffset timezone { $$ = $1 }

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
		$$.arr[0] = $5
		$$.arr[1] = $3
		$$.arr[2] = $1
	}
	

hour: NUM2   { $$ = $1 }
minute: NUM2 { $$ = $1 }
second: NUM2 { $$ = $1 }

date:
    year '/' month '/' day
	{
		$$.arr[5] = $1
		$$.arr[4] = $3
		$$.arr[3] = $5
	}
  | day '-' month '-' year
	{
		$$.arr[5] = $5
		$$.arr[4] = $3
		$$.arr[3] = $1
	}
  | day     month     year
	{
		$$.arr[5] = $3
		$$.arr[4] = $2
		$$.arr[3] = $1
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

type Lexer struct {
	result timeDateInfo
	scanner *bufio.Scanner
	tz *timezone.Timezone
}

func NewLexer(input string) *Lexer {
	scanner := bufio.NewScanner(strings.NewReader(input))
	tz := timezone.New()
	scanner.Split(customSplit)
	return &Lexer{scanner: scanner, tz: tz}
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
				//fmt.Println(j, data[start:j],)
				return j, data[start:j], nil
			}
		}
	} else if unicode.IsDigit(rune(data[start])) {
	// If we see a digit, consume as a number.
		for j := start + 1; j < len(data); j++ {
			if !unicode.IsDigit(rune(data[j])) {
				//fmt.Println(j, data[start:j],)
				return j, data[start:j], nil
			}
		}
	} else {
		// Otherwise, consume as a single rune.
		//fmt.Println(start + 1, data[start])
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
	// we don't calculate it ourselves because its offset may depend on the date (daylight saving time)
    tzAbbrInfos, _ := l.tz.GetTzAbbreviationInfo(strings.ToUpper(token))
    if len(tzAbbrInfos) > 0 {
		lval.tdi.tz = strings.ToUpper(token)
		//fmt.Println("TZ: ", token)
		return TIMEZONE
    }

	// Return other symbols as individual tokens
	if len(token) == 1 {
		switch r := rune(token[0]); r {
			case '+', '-', ':', '(', ')', '/':
				return int(r)
			default:
				//
		}
	}
	//fmt.Println("No TZ: ", token)
	return UNKNOWN
}

func (l *Lexer) Error(e string) {
	fmt.Printf("Error: %s\n", e)
}

func FlexDateToTime(dateStr string) time.Time {
	var myZone *time.Location
	lexer := NewLexer(dateStr)
	if yaccDateParse(lexer) == 1 {
		log.Fatal("Cannot parse date:", dateStr)
		os.Exit(1)
	}
	if lexer.result.tz != "" {
		myZone = time.FixedZone(lexer.result.tz, 0)
	} else {
		myZone = time.FixedZone("UTC", lexer.result.arr[6])
	}
	return time.Date(lexer.result.arr[5], time.Month(lexer.result.arr[4]), lexer.result.arr[3], lexer.result.arr[2], lexer.result.arr[1], lexer.result.arr[0], 0, myZone)
}
