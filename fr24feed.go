package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/moby/sys/reexec"
)

const rootPath = "/run/fr24feed"

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format, args...)
	fmt.Fprintln(os.Stderr)
	os.Exit(1)
}

func init() {
	// run() will complete the setup inside the new mount namespace and exec
	// the fr24feed binary.
	reexec.Register("run", run)

	if reexec.Init() {
		// The binary was reexec'ed in a new process (and new mount namespace)
		// so the original process can exit.
		os.Exit(0)
	}
}

func run() {
	// Mount filesystems in new root and pivot into it.
	if err := mountProc(rootPath); err != nil {
		fatal("couldn't mount /proc: %s", err)
	}

	if err := mountDev(rootPath); err != nil {
		fatal("couldn't mount /dev: %s", err)
	}

	if err := pivotRoot(rootPath); err != nil {
		fatal("couldn't pivot root: %s", err)
	}

	// Exec the fr24feed binary over this process.
	if err := syscall.Exec("/usr/local/bin/fr24feed", nil, os.Environ()); err != nil {
		fatal("couldn't exec: %s", err)
	}
}

func cleanup() {
	if err := os.RemoveAll(rootPath); err != nil {
		fatal("cleaning up: %s", err)
	}
}

func main() {
	// Prepare the new directory hierarchy.
	if err := prepareRootFS(rootPath, "/fr24feed/root.tar", "/fr24feed/fr24feed.ini"); err != nil {
		fatal("couldn't prepare root: %s", err)
	}

	c := make(chan os.Signal)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		cleanup()
		os.Exit(1)
	}()

	// Reexec (in a new process) the current binary in a new mount namespace.
	cmd := reexec.Command("run")

	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags: syscall.CLONE_NEWNS,
	}

	if err := cmd.Start(); err != nil {
		fatal("couldn't run setup: %s", err)
	}

	if err := cmd.Wait(); err != nil {
		fatal("couldn't wait on setup: %s", err)
	}
}
