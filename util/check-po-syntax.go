package util

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"github.com/git-l10n/git-po-helper/flag"
	"github.com/git-l10n/git-po-helper/gettext"
	"github.com/git-l10n/git-po-helper/repository"
)

func checkGettextIncompatibleIssues(poFile string) error {
	f, err := os.Open(poFile)
	if err != nil {
		return err
	}
	defer f.Close()
	reader := bufio.NewReader(f)
	for {
		line, err := reader.ReadString('\n')
		if strings.HasPrefix(line, "#~| msgid ") {
			return fmt.Errorf("remove lines that start with '#~| msgid', for they are not compatible with gettext 0.14")
		}
		if err != nil {
			if err == io.EOF {
				break
			}
			return err
		}
	}
	return nil
}

func checkPoSyntax(poFile string) ([]error, bool) {
	var (
		progs []string
		errs  []error
		msgs  []string
	)

	if !Exist(poFile) {
		errs = append(errs, fmt.Errorf(`fail to check "%s", does not exist`, poFile))
		return errs, false
	}

	if flag.GettextUseMultipleVersions() {
		gettext.ShowHints()
	}

	// We want to run "msgfmt" twice using different versions of gettext,
	// because older version of gettext is not compatible with the comments
	// generated by new version of gettext. See:
	//
	//     https://lore.kernel.org/git/874l8rwrh2.fsf@evledraar.gmail.com/
	//
	if app, ok := gettext.GettextAppMap[gettext.VersionDefault]; ok {
		progs = append(progs, app.Program("msgfmt"))
	}
	for version := range gettext.GettextAppHints {
		if app, ok := gettext.GettextAppMap[version]; ok {
			progs = append(progs, app.Program("msgfmt"))
		}
	}
	for version := range gettext.GettextAppMap {
		if version == gettext.VersionDefault {
			continue
		}
		if _, ok := gettext.GettextAppHints[version]; ok {
			continue
		}
		progs = append(progs, gettext.GettextAppMap[version].Program("msgfmt"))
	}
	if len(progs) == 0 {
		errs = append(errs, fmt.Errorf("no gettext programs found"))
		return errs, false
	}

	for idx, prog := range progs {
		cmd := exec.Command(prog,
			"-o",
			os.DevNull,
			"--check",
			"--statistics",
			poFile)
		cmd.Dir = repository.WorkDir()
		stderr, err := cmd.StderrPipe()
		if err == nil {
			err = cmd.Start()
		}
		if err != nil {
			errs = append(errs, err)
			return errs, false
		}

		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			line := scanner.Text()
			if len(line) > 0 {
				msgs = append(msgs, line)
			}
		}
		if err = cmd.Wait(); err != nil {
			for _, line := range msgs {
				errs = append(errs, errors.New(line))
			}
			errs = append(errs, fmt.Errorf("fail to check po: %s", err))
			return errs, false
		}
		// We may check syntax using different versions of gettext, Eg:
		// gettext 0.14 and new version. Do not report duplicate output
		// messages, such as statistics.
		if idx == 0 {
			for _, line := range msgs {
				errs = append(errs, errors.New(line))
			}
		}
		msgs = []string{}
	}
	if err := checkGettextIncompatibleIssues(poFile); err != nil {
		errs = append(errs, err)
		return errs, false
	}

	return errs, true
}
