package wasm

type ScanTarget struct {
	Owner  string `json:"owner"`
	Repo   string `json:"repo"`
	GitRef string `json:"git_ref"`
}

type FindingLevel string

const (
	FindingLevelWarn FindingLevel = "Warn"
	FindingLevelFail FindingLevel = "Fail"
)

type Finding struct {
	Level      FindingLevel `json:"level"`
	Rule       string       `json:"rule"`
	Target     string       `json:"target"`
	Context    *string      `json:"context,omitempty"`
	Message    string       `json:"message"`
	Suggestion *string      `json:"suggestion,omitempty"`
}

type Summary struct {
	Failures int `json:"failures"`
	Warnings int `json:"warnings"`
}

type ScanResult struct {
	Target   ScanTarget `json:"target"`
	Findings []Finding  `json:"findings"`
	Summary  Summary    `json:"summary"`
}
