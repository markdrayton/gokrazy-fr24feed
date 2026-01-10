package main

import (
	"log"
	"os"
	"syscall"
)

func main() {
	if err := syscall.Exec("/usr/local/bin/fr24feed", os.Args, os.Environ()); err != nil {
		log.Fatal(err)
	}
}
