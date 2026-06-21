package main

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"syscall"

	"github.com/google/shlex"
)

// Exit true if passed the following as an argument to `bash -c`.
var shortCircuit = []string{
	"egrep \"^([0-9]+|\\*) ([0-9]+|\\*) ([0-9]+|\\*) ([0-9]+|\\*) ([0-9]+|\\*) root /usr/lib/fr24/fr24feed_updater\\.sh\" /etc/cron.d/fr24feed_updater 2>/dev/null",
	"/bin/netstat -nlt | grep 0.0.0.0:30005 | wc -l",
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format, args...)
	fmt.Fprintf(os.Stderr, "\n")
	os.Exit(1)
}

func exec(args []string) {
	execArgs := append([]string{filepath.Base(args[0])}, args[1:]...)
	if err := syscall.Exec(args[0], execArgs, os.Environ()); err != nil {
		fatal("syscall.Exec(%q, %v, os.Environ()): %s", args[0], execArgs, err)
	}
}

func main() {
	if len(os.Args) >= 3 && os.Args[0] == "bash" && os.Args[1] == "-c" {
		unparsed := os.Args[2]
		if slices.Contains(shortCircuit, unparsed) {
			os.Exit(0)
		}

		// Assume the rest of what's passed to `bash -c` is a simple
		// command that we can split and execute.
		args, err := shlex.Split(unparsed)
		if err != nil {
			fatal("shlex.Split(%q): %s", unparsed, err)
		}
		if len(args) < 1 {
			fatal("shlex.Split(%q) produced zero-length output", unparsed)
		}

		exec(args)
	}

	exec(os.Args)
}
