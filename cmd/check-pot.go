package cmd

import (
	"github.com/git-l10n/git-po-helper/repository"
	"github.com/git-l10n/git-po-helper/util"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

type checkPotCommand struct {
	OptShowAllConfigs       bool
	OptShowCamelCaseConfigs bool
	OptShowL10nConfigs      bool

	cmd *cobra.Command
}

func (v *checkPotCommand) Command() *cobra.Command {
	if v.cmd != nil {
		return v.cmd
	}

	v.cmd = &cobra.Command{
		Use:           "check-pot <XX.po>...",
		Short:         "Check syntax of XX.po file",
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return v.Execute(args)
		},
	}
	v.cmd.Flags().BoolVar(&v.OptShowCamelCaseConfigs,
		"show-camel-case-configs",
		false,
		"show CamelCase config variables in config manpage")
	v.cmd.Flags().BoolVar(&v.OptShowL10nConfigs,
		"show-l10n-configs",
		false,
		"show config variables in l10n strings")
	v.cmd.Flags().BoolVar(&v.OptShowAllConfigs,
		"show-all-configs",
		false,
		"show all config variables in config manpage")

	return v.cmd
}

func (v checkPotCommand) Execute(args []string) error {
	// Execute in root of worktree.
	repository.ChdirProjectRoot()

	n := 0
	if v.OptShowAllConfigs {
		n++
	}
	if v.OptShowL10nConfigs {
		n++
	}
	if v.OptShowCamelCaseConfigs {
		n++
	}
	if n > 1 {
		log.Errorf("cannot use --show-all-configs, --show-l10n-configs, and --show-camel-case-configs at the same time")
		return errExecute
	}

	if v.OptShowAllConfigs {
		return util.ShowManpageConfigs(false)
	}
	if v.OptShowL10nConfigs {
		return util.ShowL10nConfigs()
	}
	if v.OptShowCamelCaseConfigs {
		return util.ShowManpageConfigs(true)
	}

	if !util.CmdCheckPo(args...) {
		return errExecute
	}
	return nil
}

var checkPotCmd = checkPotCommand{}

func init() {
	rootCmd.AddCommand(checkPotCmd.Command())
}
