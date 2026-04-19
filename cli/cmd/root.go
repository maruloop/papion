package cmd

import (
	"context"
	"fmt"
	"io"

	gh "github.com/maruloop/papion/cli/github"
	"github.com/maruloop/papion/cli/wasm"
	"github.com/spf13/cobra"
)

type Dependencies struct {
	Stdout           io.Writer
	Stderr           io.Writer
	Client           gh.Client
	Scanner          wasm.Scanner
	LoadConfig       func(configFlag string) (string, error)
	ExtractActionYML func(data []byte) (string, error)
}

func Execute(ctx context.Context, args []string, deps Dependencies) (int, error) {
	exitCode := 0
	if deps.Stdout == nil {
		deps.Stdout = io.Discard
	}
	if deps.Stderr == nil {
		deps.Stderr = io.Discard
	}
	if deps.Scanner != nil {
		defer func() {
			_ = deps.Scanner.Close(ctx)
		}()
	}

	rootCmd := NewRootCmd(deps, &exitCode)
	rootCmd.SetArgs(args)
	rootCmd.SetOut(deps.Stdout)
	rootCmd.SetErr(deps.Stderr)
	rootCmd.SetContext(ctx)

	err := rootCmd.Execute()
	if err != nil && exitCode == 0 {
		exitCode = 2
	}
	return exitCode, err
}

func NewRootCmd(deps Dependencies, exitCode *int) *cobra.Command {
	root := &cobra.Command{
		Use:           "papion",
		Short:         "Scan GitHub Actions for policy violations",
		SilenceErrors: true,
		SilenceUsage:  true,
	}
	root.AddCommand(newRunCmd(deps, exitCode))
	return root
}

func requireDeps(deps Dependencies) error {
	switch {
	case deps.Client == nil:
		return fmt.Errorf("github client dependency is required")
	case deps.Scanner == nil:
		return fmt.Errorf("scanner dependency is required")
	case deps.LoadConfig == nil:
		return fmt.Errorf("config loader dependency is required")
	case deps.ExtractActionYML == nil:
		return fmt.Errorf("archive extractor dependency is required")
	default:
		return nil
	}
}
