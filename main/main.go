//go:generate go build -o yaccDateDemo main.go

package main

import (
	"bufio"
	"fmt"
	"os"

	_ "time/tzdata"

	"github.com/udif/yaccDate/yaccDate"
)

func main() {
	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Print("Enter text: ")
		text, _ := reader.ReadString('\n')
		d, err := yaccDate.FlexDateToTime(text)
		if err == nil {
			fmt.Println(d)
		} else {
			fmt.Println(err)
		}
	}
}
