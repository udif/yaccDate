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
	"bytes"
	"errors"
	"fmt"
	"strings"
	"strconv"
	"time"
	"unicode"
	"github.com/tkuchiki/go-timezone"
)

type timeDateInfo struct {
	sec, min, hour int
	day, month, year int
	offset int
	tz  []*timezone.TzAbbreviationInfo // 3-letter timezone converted
	tz3 string // if 3-letter timezone
	mime string // if MIME string 
	offset_1st bool // true if offset appeared first
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

%token NUM2 NUM4 WEEKDAY MONTH TIMEZONE TIMEZONE0 UNKNOWN MIME '+' '-' ':' '(' ')' '/' '='

%type <tdi>  top date_string datetime2 datetime date time timezone TIMEZONE TIMEZONE0 MIME
%type <ival> year month day second minute hour sign tzoffset NUM2 NUM4 MONTH

%%

top:
	date_string
	{
        yaccDatelex.(*Lexer).result = $$
	}

date_string:
    datetime2 tzoffset '(' MIME ')'
	{
		$$ = $1
		$$.offset = $2
		$$.mime = $4.mime
		$$.offset_1st = true
	}
  | datetime2 tzoffset timezone
	{
		$$ = $1
		$$.offset = $2
		$$.tz = $3.tz
		$$.tz3 = $3.tz3
		$$.offset_1st = true
	}
  | datetime2 tzoffset
	{
		$$ = $1
		$$.offset = $2
		$$.offset_1st = true
	}
  | datetime2 timezone tzoffset
	{
		$$ = $1
		$$.tz = $2.tz
		$$.tz3 = $2.tz3
		$$.offset = $3
		$$.offset_1st = false
	}
  | datetime2 timezone
	{
		$$ = $1
		$$.tz = $2.tz
		$$.tz3 = $2.tz3
	}
  | datetime2 { $$ = $1 }

datetime2:
    weekday datetime { $$ = $2 }
  | datetime { $$ = $1 }

datetime:
	date time
	{
		$$.sec   = $2.sec
		$$.min   = $2.min
		$$.hour  = $2.hour
		$$.day   = $1.day
		$$.month = $1.month
		$$.year  = $1.year
	}

timezone:
    TIMEZONE { $$ = $1 }
  | TIMEZONE0 { $$ = $1 }
  | '(' TIMEZONE ')' { $$ = $2 }
  | '(' TIMEZONE0 ')' { $$ = $2 }
  | '(' TIMEZONE0 tzoffset ')'
	{
		$$ = $2
		$$.offset = $3
	}

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
		$$.sec = $5
		$$.min = $3
		$$.hour = $1
	}
	

hour: NUM2   { $$ = $1 }
minute: NUM2 { $$ = $1 }
second: NUM2 { $$ = $1 }

date:
    year '/' month '/' day
	{
		$$.year  = $1
		$$.month = $3
		$$.day   = $5
	}
  | day '-' month '-' year
	{
		$$.year  = $5
		$$.month = $3
		$$.day   = $1
	}
  | day     month     year
	{
		$$.year  = $3
		$$.month = $2
		$$.day   = $1
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

// enable/disable this as needed
func dbg(args ...interface{}) {
    //fmt.Println(args...)
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
				dbg(j, data[start:j],)
				return j, data[start:j], nil
			}
		}
	} else if unicode.IsDigit(rune(data[start])) {
	// If we see a digit, consume as a number.
		for j := start + 1; j < len(data); j++ {
			if !unicode.IsDigit(rune(data[j])) {
				dbg(j, data[start:j],)
				return j, data[start:j], nil
			}
		}
	} else if data[start] == '=' && data[start+1] == '?' {
		if i := bytes.Index(data[start+2:], []byte("?=")); i >= 0 {
			j := start + i + 4
			return j, data[start:j], nil
		}
	} else {
		// Otherwise, consume as a single rune.
		dbg(start + 1, data[start])
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
			dbg("UNKNOWN")
			return UNKNOWN
		}
		dbg("NUM2", lval.ival)
		return NUM2
	}

	// Check for four digit integers
	if len(token) == 4 && unicode.IsDigit(rune(token[0])) && unicode.IsDigit(rune(token[1])) && unicode.IsDigit(rune(token[2])) && unicode.IsDigit(rune(token[3])) {
		lval.ival, err = strconv.Atoi(token)
		if err != nil {
			dbg("UNKNOWN")
			return UNKNOWN
		}
		dbg("NUM4", lval.ival)
		return NUM4
	}

	if len(token) >= 4 && token[0] == '=' {
		lval.tdi.tz3 = token
		dbg("MIME: ", token)
		return MIME
	}

	// Check for week days
	if day, ok := weekDays[strings.ToLower(token)]; ok {
		lval.ival = day
		dbg("WEEKDAY", lval.ival)
		return WEEKDAY
	}

	// Check for month names
	if month, ok := monthNames[strings.ToLower(token)]; ok {
		lval.ival = int(month)
		dbg("MONTH", lval.ival)
		return MONTH
	}

	// Check for time zones
	// we don't calculate it ourselves because its offset may depend on the date (daylight saving time)
    tzAbbrInfos, _ := l.tz.GetTzAbbreviationInfo(strings.ToUpper(token))
    if len(tzAbbrInfos) > 0 {
		lval.tdi.tz = tzAbbrInfos
		lval.tdi.tz3 = token
		dbg("TZ: ", token)
		if len(tzAbbrInfos) == 1 {
			lval.tdi.offset = tzAbbrInfos[0].Offset()
			if lval.tdi.offset == 0 {
				return TIMEZONE0
			} else {
				return TIMEZONE
			}
		}
		return TIMEZONE
    }

	// Return other symbols as individual tokens
	if len(token) == 1 {
		switch r := rune(token[0]); r {
			case '+', '-', ':', '(', ')', '/', '=':
				dbg(token)
				return int(r)
			default:
				//
		}
	}
	dbg("No TZ: ", token)
	return UNKNOWN
}

func (l *Lexer) Error(e string) {
	fmt.Printf("Error: %s\n", e)
}

func FlexDateToTime(dateStr string) (time.Time, error) {
	var myZone *time.Location
	lexer := NewLexer(dateStr)
	if yaccDateParse(lexer) == 1 {
		return time.Time{}, errors.New("Cannot parse date")
	}
	if lexer.result.tz == nil {
		// No TZ given. The code below covers both offset given and no offset
		// Due to default initialization of  0 for lexer.result.offset
		myZone = time.FixedZone("UTC", lexer.result.offset)
	} else if !lexer.result.offset_1st { // offset last, we base on timezone
		if len(lexer.result.tz) > 1 {
			// timezone 1st, we plan to rely on it
			// but with more than one timezone matches, we don;t know which
			return time.Time{}, errors.New("Ambiguous timezones and no explicit offset")
		} else if len(lexer.result.tz) == 1 {
			// unambiguous timezone 1st, so we rely on it.
			// If there is an additional +/-offset, we'll add it
			myZone = time.FixedZone(lexer.result.tz3, lexer.result.tz[0].Offset() + lexer.result.offset)
			dbg(lexer.result.tz3)
		}
	} else { // offset 1st, we base on offset and annotate with timezone
		if len(lexer.result.tz) > 0 {
			// toffset given as well as multiple time zones.
			// we are OK if any of those matches the offset
			for _, tz := range lexer.result.tz {
				dbg(tz.Name())
				if lexer.result.offset == tz.Offset() {
					//myZone = time.FixedZone(tz.Name(), tz.Offset())
					myZone = time.FixedZone(lexer.result.tz3, tz.Offset())
					break
				}
			}
			if myZone == nil {
				return time.Time{}, errors.New("Timezone contradicts explicit offset given")
			}
		}
	}
	return time.Date(lexer.result.year, time.Month(lexer.result.month), lexer.result.day, lexer.result.hour, lexer.result.min, lexer.result.sec, 0, myZone), nil
}
