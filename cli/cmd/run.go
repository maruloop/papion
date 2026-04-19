package cmd

import (
	"fmt"
	"strings"

	"github.com/maruloop/papion/cli/wasm"
	"github.com/spf13/cobra"
)

func newRunCmd(deps Dependencies, exitCode *int) *cobra.Command {
	var configPath string
	var format string
	var failOn string

	cmd := &cobra.Command{
		Use:   "run owner/repo@ref",
		Short: "Scan a GitHub Action",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if err := requireDeps(deps); err != nil {
				*exitCode = 2
				return err
			}

			target, err := parseTarget(args[0])
			if err != nil {
				*exitCode = 2
				return err
			}

			if format != "human" && format != "json" {
				*exitCode = 2
				return fmt.Errorf("invalid --format %q", format)
			}
			if failOn != "fail" && failOn != "warn" && failOn != "none" {
				*exitCode = 2
				return fmt.Errorf("invalid --fail-on %q", failOn)
			}

			policyJSON, err := deps.LoadConfig(configPath)
			if err != nil {
				*exitCode = 2
				return err
			}

			archive, err := deps.Client.DownloadArchive(cmd.Context(), target.Owner, target.Repo, target.GitRef)
			if err != nil {
				*exitCode = 2
				return err
			}

			yamlContent, err := deps.ExtractActionYML(archive)
			if err != nil {
				*exitCode = 2
				return err
			}

			result, err := deps.Scanner.Scan(target, yamlContent, policyJSON)
			if err != nil {
				*exitCode = 2
				return err
			}

			var output string
			switch format {
			case "json":
				output, err = deps.Scanner.FormatJSON(result)
			default:
				output, err = deps.Scanner.FormatHuman(result)
			}
			if err != nil {
				*exitCode = 2
				return err
			}

			if _, err := fmt.Fprintln(deps.Stdout, output); err != nil {
				*exitCode = 2
				return err
			}
			*exitCode = findingsExitCode(result, failOn)
			return nil
		},
	}

	cmd.Flags().StringVar(&configPath, "config", "", "Path to config file")
	cmd.Flags().StringVarP(&format, "format", "f", "human", "Output format: human or json")
	cmd.Flags().StringVarP(&failOn, "fail-on", "F", "fail", "Minimum level to exit 1: fail, warn, or none")

	return cmd
}

func parseTarget(input string) (wasm.ScanTarget, error) {
	at := strings.LastIndex(input, "@")
	if at <= 0 || at == len(input)-1 {
		return wasm.ScanTarget{}, fmt.Errorf("invalid target %q: expected owner/repo@ref", input)
	}

	repoPath := input[:at]
	ref := input[at+1:]
	parts := strings.Split(repoPath, "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return wasm.ScanTarget{}, fmt.Errorf("invalid target %q: expected owner/repo@ref", input)
	}

	return wasm.ScanTarget{
		Owner:  parts[0],
		Repo:   parts[1],
		GitRef: ref,
	}, nil
}

func findingsExitCode(result *wasm.ScanResult, failOn string) int {
	if result == nil {
		return 0
	}

	switch failOn {
	case "none":
		return 0
	case "warn":
		if result.Summary.Failures > 0 || result.Summary.Warnings > 0 {
			return 1
		}
	case "fail":
		if result.Summary.Failures > 0 {
			return 1
		}
	}

	return 0
}
