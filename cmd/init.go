package cmd

import (
	"github.com/git-l10n/git-po-helper/util"
	"github.com/spf13/cobra"
)

type initCommand struct {
	cmd *cobra.Command
	O   struct {
		OnlyCore bool
	}
}

func (v *initCommand) Command() *cobra.Command {
	if v.cmd != nil {
		return v.cmd
	}

	v.cmd = &cobra.Command{
		Use:           "init <XX.po>",
		Short:         "Create XX.po file",
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return v.Execute(args)

		},
	}

	v.cmd.Flags().BoolVar(&v.O.OnlyCore,
		"core",
		false,
		"generate a small XX.po only includes core l10n entries in po-core/")

	return v.cmd
}

func (v initCommand) Execute(args []string) error {
	if len(args) != 1 {
		return newUserError("must given 1 argument for init command")
	}
	locale := args[0]
	if !util.CmdInit(locale, v.O.OnlyCore) {
		return executeError
	}
	return nil
}

var initCmd = initCommand{}

func init() {
	rootCmd.AddCommand(initCmd.Command())
}
