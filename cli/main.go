package main

import (
	"context"
	"fmt"
	"os"

	"github.com/maruloop/papion/cli/cmd"
	"github.com/maruloop/papion/cli/config"
	gh "github.com/maruloop/papion/cli/github"
	"github.com/maruloop/papion/cli/wasm"
)

func main() {
	code, err := cmd.Execute(context.Background(), os.Args[1:], cmd.Dependencies{
		Stdout:           os.Stdout,
		Stderr:           os.Stderr,
		Client:           gh.NewHTTPClient(nil),
		Scanner: &wasm.StubScanner{}, // TODO(WS8): replace with wasm.NewWazeroScanner() once core WASM artifact is available
		LoadConfig:       config.LoadConfig,
		ExtractActionYML: gh.ExtractActionYml,
	})
	if err != nil {
		_, _ = fmt.Fprintln(os.Stderr, err)
	}
	os.Exit(code)
}
