package main

// Copyright 2020 The Knative Authors.
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

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"gopkg.in/yaml.v1"
)

func main() {
	// For each direction in actions:
	//   If there is an `auto-apply.yaml`:
	//     Read the yaml
	//     Use text.template to substitute values into `actions_template.yaml` from this dir
	//     Write the output to `.github/workflows/auto-$(dirname).yaml`

	// This should be run from the repo root.
	entries, err := os.ReadDir("actions")
	if err != nil {
		log.Print("Failed to open 'actions':", err)
		os.Exit(1)
	}
	templFuncs := map[string]interface{}{
		"split":  strings.Split,
		"join":   strings.Join,
		"github": GitHub,
	}
	templ := template.New("actions_template.yaml").Funcs(templFuncs)
	templ = template.Must(templ.ParseFiles(filepath.Join("cmd", "gen-actions", "actions_template.yaml")))
	for _, entry := range entries {
		if !entry.IsDir() {
			log.Printf("Skipping 'actions/%s', not a directory", entry.Name())
			continue
		}
		err := handleDir(entry.Name(), templ)
		if err != nil {
			log.Printf("Unable to process 'actions/%s': %s", entry.Name(), err)
			os.Exit(1)
		}
	}
}

func handleDir(path string, templ *template.Template) error {
	metafile := filepath.Join("actions", path, "auto-apply.yaml")
	fi, err := os.Stat(metafile)
	if os.IsNotExist(err) {
		log.Printf("Skipping %s, no auto-apply.yaml", path)
		return nil
	}
	if !fi.Mode().IsRegular() {
		return fmt.Errorf("%q is not a regular file", metafile)
	}
	bytes, err := os.ReadFile(metafile)
	if err != nil {
		return fmt.Errorf("Unable to read %q: %w", metafile, err)
	}
	c := conf{}
	c.Repos = map[string]RepoRef{}
	// Set defaults before parsing c
	c.PRBody = `${{ github.event.inputs.reason || "Cron" }} -${{ github.actor }}

	/cc ${{ matrix.assignees }}
	/assign ${{ matrix.assignees }}
  
	Produced by: ${{ github.repository }}/actions/${{}}
  
	Details:
	` + "```\n" + `${{ steps.updatedeps.outputs.deplog }}` + "\n```"
	c.Repos["config"] = RepoRef{} // Empty Name means "this repo"
	c.Repos["main"] = RepoRef{Name: "${{ matrix.name }}"}
	if err := yaml.Unmarshal(bytes, &c); err != nil {
		return fmt.Errorf("Unable to parse %q: %w", metafile, err)
	}
	c.Action = path
	// Deliberately using unix path convertion here.
	c.ActionRef = "${{ github.repository }}/actions/" + path + "@${{ github.sha }}"
	c.ActionRef = "./config/actions/" + path

	outfileName := filepath.Join(".github", "workflows", "auto-"+path+".yaml")
	outfile, err := os.OpenFile(outfileName, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("Unable to open %q: %w", outfileName, err)
	}
	if err := templ.Execute(outfile, &c); err != nil {
		os.Remove(outfileName)
		return fmt.Errorf("Failed to write %q: %w", outfileName, err)
	}
	log.Printf("Generated %q for %s", outfileName, path)
	return nil
}

type conf struct {
	Action        string `yaml:"-"`
	ActionRef     string `yaml:"-"`
	ShortName     string `yaml:"shortName"`
	Title         string
	PRTitle       string `yaml:"prTitle"`
	PRBody        string `yaml:"prBody"`
	CommitMessage string `yaml:"commitMessage"`
	Repos         map[string]RepoRef
	Inputs        []Input
	// With allows passing _extra_ inputs to the action; all inputs will automatically be passed
	With map[string]string
}

type Input struct {
	Name        string
	Description string
	Required    bool
	Default     string
}

type RepoRef struct {
	Name string
	Ref  string
}

// GitHub returns a github variable substitution
func GitHub(args ...string) string {
	return "${{ " + strings.Join(args, " ") + " }}"
}
