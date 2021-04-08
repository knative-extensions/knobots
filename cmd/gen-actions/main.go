package main

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
	templ := template.New("actions_template.yaml").Funcs(map[string]interface{}{"split": strings.Split, "join": strings.Join})
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
	if err := yaml.Unmarshal(bytes, &c); err != nil {
		return fmt.Errorf("Unable to parse %q: %w", metafile, err)
	}
	// Deliberately using unix path convertion here.
	c.ActionRef = "${{ github.repository }}/actions/" + path + "@${{ github.sha }}"
	c.Action = path

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
	Action        string
	ActionRef     string
	ShortName     string `yaml:"shortName"`
	PRTitle       string `yaml:"prTitle"`
	PRBody        string `yaml:"prBody"`
	CommitMessage string `yaml:"commitMessage"`
}

// GitHub returns a github variable substitution
func (c *conf) GitHub(args ...string) string {
	return "${{ " + strings.Join(args, " ") + " }}"
}
