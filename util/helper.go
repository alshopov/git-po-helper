package util

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"

	"github.com/git-l10n/git-po-helper/data"
	log "github.com/sirupsen/logrus"
)

var (
	oidRegex = regexp.MustCompile(`^[0-9a-f]{7,40}[0-9]*$`)
)

// Exist check if path is exist.
func Exist(name string) bool {
	if _, err := os.Stat(name); err == nil {
		return true
	}
	return false
}

// IsFile returns true if path is exist and is a file.
func IsFile(name string) bool {
	fi, err := os.Stat(name)
	if err != nil || fi.IsDir() {
		return false
	}
	return true
}

// IsDir returns true if path is exist and is a directory.
func IsDir(name string) bool {
	fi, err := os.Stat(name)
	if err != nil || !fi.IsDir() {
		return false
	}
	return true
}

// ShowExecError will try to return error message of stderr
func ShowExecError(err error) {
	if err == nil {
		return
	}
	exitError, ok := err.(*exec.ExitError)
	if !ok {
		return
	}
	buf := bytes.NewBuffer(exitError.Stderr)
	for {
		line, eof := buf.ReadString('\n')
		if len(line) > 0 {
			log.Error(line)
		}
		if eof != nil {
			break
		}
	}
}

// GetPrettyLocaleName shows full language name and location
func GetPrettyLocaleName(locale string) (string, error) {
	var (
		langName string
		locName  string
	)
	items := strings.SplitN(locale, "_", 2)
	langName = data.GetLanguageName(items[0])
	if langName == "" {
		return "", fmt.Errorf("invalid language code for locale \"%s\"", locale)
	}
	if len(items) > 1 && items[1] != "" {
		locName = data.GetLocationName(items[1])
		if locName == "" {
			return "", fmt.Errorf(`invalid country or location code for locale "%s"`, locale)
		}
	}
	if locName != "" {
		return fmt.Sprintf("%s - %s", langName, locName), nil
	}
	return langName, nil
}

// GetUserInput reads user input from stdin
func GetUserInput(prompt, defaultValue string) string {
	fmt.Print(prompt)

	reader := bufio.NewReader(os.Stdin)
	text, _ := reader.ReadString('\n')
	text = strings.TrimSpace(text)

	if text == "" {
		return defaultValue
	}
	return text
}

// AnswerIsTrue indicates answer is a true value
func AnswerIsTrue(answer string) bool {
	answer = strings.ToLower(strings.TrimSpace(answer))
	if answer == "y" ||
		answer == "yes" ||
		answer == "t" ||
		answer == "true" ||
		answer == "on" ||
		answer == "1" {
		return true
	}
	return false
}

// AbbrevCommit returns abbrev commit id
func AbbrevCommit(oid string) string {
	if oidRegex.MatchString(oid) {
		return oid[:7]
	}
	return oid
}

func ReportInfoAndErrors(errs []string, prompt string, notError bool) {
	if notError {
		reportResultMessages(errs, prompt, log.InfoLevel)
	} else {
		reportResultMessages(errs, prompt, log.ErrorLevel)
	}
}

func ReportWarnAndErrors(errs []string, prompt string, notError bool) {
	if notError {
		reportResultMessages(errs, prompt, log.WarnLevel)
	} else {
		reportResultMessages(errs, prompt, log.ErrorLevel)
	}
}

func reportResultMessages(errs []string, prompt string, level log.Level) {
	var fn func(format string, args ...interface{})

	if len(errs) == 0 {
		return
	}

	switch level {
	case log.InfoLevel:
		fn = log.Printf
	case log.WarnLevel:
		fn = log.Warnf
	default:
		fn = log.Errorf
	}

	for _, err := range errs {
		if err == "" {
			fn("")
			continue
		}
		for _, line := range strings.Split(err, "\n") {
			fn("%s\t%s", prompt, line)
		}
	}
}
