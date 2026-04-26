package main

import (
	"archive/tar"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"syscall"

	"github.com/google/renameio/v2"
)

// prepareRootFS prepares a root directory for the new process.
func prepareRootFS(rootPath string, rootTar string, iniFile string) error {
	if err := unpackRoot(rootPath, rootTar); err != nil {
		return err
	}

	if err := copyIni(rootPath, iniFile); err != nil {
		return err
	}

	return nil
}

func unpackRoot(rootPath string, rootTar string) error {
	f, err := os.Open(rootTar)
	if err != nil {
		return err
	}

	defer f.Close()

	tr := tar.NewReader(f)
	for {
		h, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		path := filepath.Join(rootPath, h.Name)

		if h.FileInfo().IsDir() {
			if err := os.MkdirAll(path, 0700); err != nil {
				return err
			}
			continue
		}

		mode := h.FileInfo().Mode() & os.ModePerm
		out, err := renameio.NewPendingFile(path, renameio.WithStaticPermissions(mode))
		if err != nil {
			return err
		}
		if _, err := io.Copy(out, tr); err != nil {
			return err
		}
		if err := out.CloseAtomicallyReplace(); err != nil {
			return err
		}
	}

	return nil
}

func copyIni(rootPath string, iniFile string) error {
	f, err := os.Open(iniFile)
	if err != nil {
		return err
	}
	defer f.Close()

	dest := filepath.Join(rootPath, "/etc/fr24feed.ini")

	if err := os.MkdirAll(filepath.Dir(dest), 0700); err != nil {
		return err
	}

	// defer close
	out, err := renameio.NewPendingFile(dest, renameio.WithStaticPermissions(0700))
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, f); err != nil {
		return err
	}
	if err := out.CloseAtomicallyReplace(); err != nil {
		return err
	}

	return nil
}

func mountProc(root string) error {
	target := filepath.Join(root, "/proc")

	if err := os.MkdirAll(target, 0755); err != nil {
		return fmt.Errorf("mkdir(%s): %v", target, err)
	}

	if err := syscall.Mount("proc", target, "proc", 0, ""); err != nil {
		return fmt.Errorf("mount(%s): %v", target, err)
	}

	return nil
}

func mountDev(root string) error {
	target := filepath.Join(root, "/dev")

	if err := os.MkdirAll(target, 0755); err != nil {
		return fmt.Errorf("mkdir(%s): %v", target, err)
	}

	if err := syscall.Mount("/dev", target, "", syscall.MS_BIND|syscall.MS_REC, ""); err != nil {
		return fmt.Errorf("mount(%s): %v", target, err)
	}

	return nil
}

func pivotRoot(root string) error {
	putold := filepath.Join(root, "/.pivot_root")

	if err := syscall.Mount(root, root, "", syscall.MS_BIND|syscall.MS_REC, ""); err != nil {
		return fmt.Errorf("mount(%s): %s", root, err)
	}

	if err := os.MkdirAll(putold, 0700); err != nil {
		return fmt.Errorf("mkdir(%s): %s", putold, err)
	}

	if err := syscall.PivotRoot(root, putold); err != nil {
		return fmt.Errorf("pivot_root(%s, %s): %s", root, putold, err)
	}

	if err := os.Chdir("/"); err != nil {
		return fmt.Errorf("chdir(/): %s", err)
	}

	putold = "/.pivot_root"
	if err := syscall.Unmount(putold, syscall.MNT_DETACH); err != nil {
		return fmt.Errorf("umount(%s): %s", putold, err)
	}

	if err := os.RemoveAll(putold); err != nil {
		return fmt.Errorf("rmdir(%s): %s", putold, err)
	}

	return nil
}
