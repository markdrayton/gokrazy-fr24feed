package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/moby/sys/reexec"
	"golang.org/x/sys/unix"
)

const rootPath = "/run/fr24feed"

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}

func run() {
	// Kill the child process if the parent is killed. Preserved across execve.
	err := unix.Prctl(syscall.PR_SET_PDEATHSIG, uintptr(syscall.SIGKILL), 0, 0, 0)
	if err != nil {
		fatal("couldn't set parent death signal: %v", err)
	}

	// Mount filesystems in new root and pivot into it.
	if err := mountProc(rootPath); err != nil {
		fatal("couldn't mount /proc: %v", err)
	}

	if err := mountDev(rootPath); err != nil {
		fatal("couldn't mount /dev: %v", err)
	}

	if err := pivotRoot(rootPath); err != nil {
		fatal("couldn't pivot root: %v", err)
	}

	// Exec the fr24feed binary over this process.
	if err := syscall.Exec("/usr/local/bin/fr24feed", nil, os.Environ()); err != nil {
		fatal("couldn't exec: %v", err)
	}
}

func main() {
	// run() will complete the setup inside the new mount namespace and exec
	// the fr24feed binary.
	reexec.Register("run", run)
	if reexec.Init() {
		return
	}

	defer func() {
		os.RemoveAll(rootPath)
	}()

	if err := prepareRootFS(rootPath, "/fr24feed/root.tar", "/fr24feed/fr24feed.ini"); err != nil {
		fatal("couldn't prepare root: %v", err)
	}

	cmd := reexec.Command("run")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags: syscall.CLONE_NEWNS,
	}

	if err := cmd.Start(); err != nil {
		fatal("couldn't run setup: %v", err)
	}

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	doneChan := make(chan error, 1)
	go func() {
		doneChan <- cmd.Wait()
	}()

	select {
	case err := <-doneChan:
		if err != nil {
			fatal("child process exited with error: %v", err)
		}
	case sig := <-sigChan:
		fmt.Fprintf(os.Stderr, "Received signal %v, shutting down...\n", sig)
	}
}
