// Copyright 2026 The Knative Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package actions_test

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"gopkg.in/yaml.v1"
)

type action struct {
	Outputs map[string]struct{ Value string }
	Runs    struct {
		Using string
		Steps []struct {
			ID, Shell, Run, Uses string
			Env                  map[string]string
		}
	}
}

func loadAction(t *testing.T, path string) action {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var a action
	if err := yaml.Unmarshal(data, &a); err != nil {
		t.Fatal(err)
	}
	return a
}

func TestCompositeActions(t *testing.T) {
	paths, err := filepath.Glob("*/action.yaml")
	if err != nil || len(paths) == 0 {
		t.Fatalf("finding actions: %v (found %d)", err, len(paths))
	}
	for _, path := range paths {
		t.Run(filepath.Dir(path), func(t *testing.T) {
			action := loadAction(t, path)
			if action.Runs.Using != "composite" {
				t.Fatalf("runs.using = %q, want composite", action.Runs.Using)
			}
			if _, err := os.Stat(filepath.Join(filepath.Dir(path), "Dockerfile")); !os.IsNotExist(err) {
				t.Fatalf("action must not require a Dockerfile: %v", err)
			}
			foundRun := false
			goReady := false
			for _, step := range action.Runs.Steps {
				if step.Uses == "knative/actions/setup-go@main" {
					goReady = true
				}
				if strings.Contains(step.Run, "go install ") && !goReady {
					t.Error("Go tools must be installed after knative/actions/setup-go@main")
				}
				if step.Run != "" && step.Shell != "bash" {
					t.Errorf("run step %q must specify bash", step.ID)
				}
				if step.Run != "" {
					cmd := exec.Command("bash", "-n")
					cmd.Stdin = strings.NewReader(step.Run)
					if out, err := cmd.CombinedOutput(); err != nil {
						t.Errorf("invalid shell in step %q: %v\n%s", step.ID, err, out)
					}
				}
				if step.ID == "run" {
					foundRun = true
					if step.Run == "" {
						t.Error("run step must contain shell commands")
					}
					if filepath.Dir(path) == "update-deps" {
						if step.Run != `bash "$ACTION_PATH/entrypoint.sh"` || step.Env["ACTION_PATH"] != "${{ github.action_path }}" {
							t.Error("external entrypoint must use the quoted action path")
						}
					} else if strings.Contains(step.Run, "entrypoint.sh") {
						t.Error("simple scripts should be inline")
					}
				}
			}
			if !foundRun {
				t.Error("missing run step")
			}
			if len(action.Outputs) == 0 {
				t.Error("missing action outputs")
			}
			for name, output := range action.Outputs {
				outputName := name
				if name == "include" {
					outputName = "includes" // Backward-compatible matrix alias.
				}
				if want := fmt.Sprintf("${{ steps.run.outputs.%s }}", outputName); output.Value != want {
					t.Errorf("output %s = %q, want %q", name, output.Value, want)
				}
			}
			if filepath.Dir(path) == "update-deps" {
				cmd := exec.Command("bash", "-n", filepath.Join(filepath.Dir(path), "entrypoint.sh"))
				if out, err := cmd.CombinedOutput(); err != nil {
					t.Fatalf("invalid entrypoint: %v\n%s", err, out)
				}
			} else if _, err := os.Stat(filepath.Join(filepath.Dir(path), "entrypoint.sh")); !os.IsNotExist(err) {
				t.Errorf("inlined action should not have an entrypoint.sh: %v", err)
			}
		})
	}
}

func TestCommunityAction(t *testing.T) {
	// Exercise the inline run block with the same shell options as GitHub Actions.
	var script string
	for _, step := range loadAction(t, "update-community/action.yaml").Runs.Steps {
		if step.ID == "run" {
			script = step.Run
		}
	}
	if script == "" {
		t.Fatal("missing community run block")
	}
	for _, present := range []bool{false, true} {
		t.Run(fmt.Sprintf("source-present=%t", present), func(t *testing.T) {
			workspace := filepath.Join(t.TempDir(), "workspace with spaces")
			for _, dir := range []string{"main", "meta/peribolos"} {
				if err := os.MkdirAll(filepath.Join(workspace, dir), 0755); err != nil {
					t.Fatal(err)
				}
			}
			const owners = "aliases:\n  team:\n    - contributor\n"
			if present {
				if err := os.WriteFile(filepath.Join(workspace, "meta/peribolos/knative-OWNERS_ALIASES"), []byte(owners), 0644); err != nil {
					t.Fatal(err)
				}
			}
			envFile := filepath.Join(workspace, "env")
			outputFile := filepath.Join(workspace, "output")
			cmd := exec.Command("bash", "--noprofile", "--norc", "-eo", "pipefail", "-c", script)
			cmd.Dir = workspace
			cmd.Env = append(os.Environ(), "GITHUB_WORKSPACE="+workspace, "GITHUB_ENV="+envFile, "GITHUB_OUTPUT="+outputFile, "ORGANIZATION=knative")
			if out, err := cmd.CombinedOutput(); err != nil {
				t.Fatalf("community run block: %v\n%s", err, out)
			}
			env, err := os.ReadFile(envFile)
			if err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(string(env), fmt.Sprintf("create_pr=%t\n", present)) || !strings.Contains(string(env), "pr_labels=skip-review\n") {
				t.Errorf("unexpected workflow environment: %s", env)
			}
			output, err := os.ReadFile(outputFile)
			if err != nil || string(output) != "log=\n" {
				t.Errorf("unexpected output: %q, error: %v", output, err)
			}
			if present {
				got, err := os.ReadFile(filepath.Join(workspace, "main/OWNERS_ALIASES"))
				if err != nil || string(got) != owners {
					t.Errorf("unexpected OWNERS_ALIASES: %q, error: %v", got, err)
				}
			}
		})
	}
}
