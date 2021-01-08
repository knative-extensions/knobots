package main

import (
	"context"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/google/go-github/github"
	"golang.org/x/oauth2"
)

func main() {
	http.HandleFunc("/", Handler)
	http.ListenAndServe(":8080", nil)
}

func Handler(w http.ResponseWriter, r *http.Request) {
	payload, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Printf("ERROR: no payload: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// TODO(mattmoor): This should be:
	//     eventType := github.WebHookType(r)
	// https://github.com/knative/eventing-sources/issues/120
	// HACK HACK HACK
	parts := strings.Split(r.Header.Get("ce-eventtype"), ".")
	eventType := parts[len(parts)-1]

	event, err := github.ParseWebHook(eventType, payload)
	if err != nil {
		log.Printf("ERROR: unable to parse webhook: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// The set of events here should line up with what is in
	//   config/one-time/github-source.yaml
	switch event := event.(type) {
	case *github.PullRequestEvent:
		if err := HandlePullRequest(event); err != nil {
			log.Printf("Error handling %T: %v", event, err)
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	case *github.IssuesEvent:
		if err := HandleIssues(event); err != nil {
			log.Printf("Error handling %T: %v", event, err)
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	default:
		log.Printf("Unrecognized event: %T", event)
		http.Error(w, "Unknown event", http.StatusBadRequest)
		return
	}
}

func HandleIssues(ie *github.IssuesEvent) error {
	if ie.GetIssue().Milestone != nil {
		log.Printf("Issue #%v already has a milestone.", ie.GetIssue().GetNumber())
		return nil
	}
	if ie.GetIssue().GetState() == "closed" {
		log.Printf("Issue #%v is closed.", ie.GetIssue().GetNumber())
		return nil
	}

	return needsTriage(ie.Repo.Owner.GetLogin(), ie.Repo.GetName(), ie.GetIssue().GetNumber())
}

func HandlePullRequest(pre *github.PullRequestEvent) error {
	if pre.GetPullRequest().Milestone != nil {
		log.Printf("PR #%v already has a milestone.", pre.GetNumber())
		return nil
	}
	if pre.GetPullRequest().GetState() == "closed" {
		log.Printf("PR #%v is closed.", pre.GetNumber())
		return nil
	}

	return needsTriage(pre.Repo.Owner.GetLogin(), pre.Repo.GetName(), pre.GetNumber())
}

func needsTriage(owner, repo string, number int) error {
	ctx := context.Background()
	ghc := GetClient(ctx)
	m, err := getOrCreateMilestone(ctx, ghc, owner, repo, "Needs Triage")
	if err != nil {
		return err
	}

	_, _, err = ghc.Issues.Edit(ctx, owner, repo, number, &github.IssueRequest{
		Milestone: m.Number,
	})
	return err
}

func getOrCreateMilestone(ctx context.Context, client *github.Client,
	owner, repo, title string) (*github.Milestone, error) {
	// Walk the pages of milestones looking for one matching our title.
	lopt := &github.MilestoneListOptions{}
	for {
		ms, resp, err := client.Issues.ListMilestones(ctx, owner, repo, lopt)
		if err != nil {
			return nil, err
		}
		for _, m := range ms {
			if m.GetTitle() == title {
				return m, nil
			}
		}
		if lopt.Page == resp.NextPage {
			break
		}
		lopt.Page = resp.NextPage
	}

	m, _, err := client.Issues.CreateMilestone(ctx, owner, repo, &github.Milestone{
		Title: &title,
	})
	return m, err
}

func GetClient(ctx context.Context) *github.Client {
	return github.NewClient(
		oauth2.NewClient(ctx,
			oauth2.StaticTokenSource(
				&oauth2.Token{
					AccessToken: os.Getenv("GITHUB_ACCESS_TOKEN"),
				},
			),
		),
	)
}
