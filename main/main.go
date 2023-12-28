//go:generate go build -o yaccDateDemo main.go

package main

import (
	"bufio"
	"fmt"
	"os"

	"github.com/udif/yaccDate/yaccDate"
)

func main() {
	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Print("Enter text: ")
		text, _ := reader.ReadString('\n')
		fmt.Println(yaccDate.FlexDateToTime(text))
	}
}
