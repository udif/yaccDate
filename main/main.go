package main

import (
	"bufio"
	"fmt"
	"os"

	"github.com/udif/yaccDate"
)

func main() {
	yaccDateDebug = 1
	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Print("Enter text: ")
		text, _ := reader.ReadString('\n')
		fmt.Println(yaccDate.FlexDateToTime(text))
	}
}
