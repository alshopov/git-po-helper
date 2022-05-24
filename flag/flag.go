// Package flag provides viper flags.
package flag

import (
	"strings"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

// Verbose returns option "--verbose".
func Verbose() int {
	return viper.GetInt("verbose")
}

// Quiet returns option "--quiet".
func Quiet() int {
	return viper.GetInt("quiet")
}

// Force returns option "--force".
func Force() bool {
	return viper.GetBool("check--force") || viper.GetBool("check-commits--force")
}

// GitHubActionEvent returns option "--github-action-event".
func GitHubActionEvent() string {
	return viper.GetString("github-action-event")
}

// NoGPG returns option "--no-gpg".
func NoGPG() bool {
	return GitHubActionEvent() != "" || viper.GetBool("check--no-gpg") || viper.GetBool("check-commits--no-gpg")
}

// ReportTyposAsErrors returns option "--report-typos-as-errors".
func ReportTyposAsErrors() bool {
	return viper.GetBool("check-po--report-typos-as-errors") ||
		viper.GetBool("check-commits--report-typos-as-errors") ||
		viper.GetBool("check--report-typos-as-errors")
}

// IgnoreTypos returns option "--ignore-typos".
func IgnoreTypos() bool {
	return viper.GetBool("check-po--ignore-typos") ||
		viper.GetBool("check-commits--ignore-typos") ||
		viper.GetBool("check--ignore-typos")
}

// CheckFileLocations returns option "--check-file-locations".
func CheckFileLocations() bool {
	return GitHubActionEvent() != "" ||
		viper.GetBool("check-po--check-file-locations")
}

const (
	CheckPotFileNone = iota
	CheckPotFileCurrent
	CheckPotFileUpdate
	CheckPotFileDownload
)

// CheckPotFile returns option "--check-pot-file".
func CheckPotFile() int {
	var (
		ret int
		opt = strings.ToLower(viper.GetString("check-pot-file"))
	)

	if opt == "" {
		opt = "download"
	}

	switch opt {
	case "no", "none", "false", "0":
		ret = CheckPotFileNone
	case "update", "make", "build":
		ret = CheckPotFileUpdate
	case "current":
		ret = CheckPotFileCurrent
	default:
		log.Warnf("unknown value for --check-pot-file=%s, fallback to 'download'", opt)
		fallthrough
	case "download", "yes", "true", "1":
		ret = CheckPotFileDownload
	}
	return ret
}

// Core returns option "--core".
func Core() bool {
	return viper.GetBool("check--core") || viper.GetBool("check-po--core")
}

// NoSpecialGettextVersions returns option "--no-special-gettext-versions".
func NoSpecialGettextVersions() bool {
	return viper.GetBool("no-special-gettext-versions")
}

// SetGettextUseMultipleVersions sets option "gettext-use-multiple-versions".
func SetGettextUseMultipleVersions(value bool) {
	viper.Set("gettext-use-multiple-versions", value)
}

// GettextUseMultipleVersions returns option "gettext-use-multiple-versions".
func GettextUseMultipleVersions() bool {
	return viper.GetBool("gettext-use-multiple-versions")
}
