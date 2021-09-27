# Welcome to knobots

This repository contains a number of github actions, which perform routine
maintenance tasks for a variety of repositories, mostly for the knative org. In
particular, this repo exists separately from other repos like
https://github.com/knative/test-infra to enable using [repository
secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository)
to hold an access token for creating automated PRs.

If you just need to run a job periodically against a repo,
https://github.com/knative-sandbox/.github/ holds template actions (in
`workflow-templates`) which are copied to all the repos in Knative using the
`update-actions` workflow in this repo.

## Adding a repo

To add a repository here, there are two requirements:
1. Add an entry to `repos.yaml` containing an entry like this:

   ```yaml
    - # name is the repository to operate on, think: https://github.com/{name}.git
      name: 'knative/pkg'

      # meta-organization is the github organization from which to sync Github
      # actions, think: https://github.com/{meta-organization}/.github
      # Actions are pulled from the workflow-templates directory.
      meta-organization: 'knative'

      # fork is the name of the fork to push to (otherwise a branch on the
      # main repo is used)
      fork: 'knative-automation/pkg'

      # channel is the channel on knative.slack.com to post when these actions fail.
      # These can be a direct-message to a username if prefixed with `@`
      channel: 'serving-api'

      # The list of users to which the PR should be `/assign` (only matters for Prow)
      # These should bias toward Github teams, but must exist within the target
      # organization (so knative[-sandbox] should use the team in their respective org).
      assignees: knative/foo-wg-leads
   ```

2. `github.com/{fork}.git` must be a fork of `{name}` (if specified) and `knative-automation`
  must have push access.


Repos can also optionally exclude certain jobs by adding their name to the
appropriate `{foo}-exclude.yaml` file.

## Adding new automation

This repo exists to run [GitHub Actions](https://docs.github.com/en/actions) to
create automated management PRs against other repos in Knative. To add a new
automated PR workflow (or update one of the existing workflows), it's worth
understanding the different components in this repo:

* `.github/workflows` contains the actual GitHub Actions, in the Actions yaml format. These are (mostly) generated from the `actions` directories mentioned below, but a few are hand-maintained. For the generated workflows, run `go run ./cmd/gen-actions` at the root of the repo to regnerate the files, which will need to be checked in / PR'ed if changed.

* `actions` contains a set of GitHub Actions, either as Dockerfile actions or Javascript actions. Each directory under `actions` should contain the following:

   * `action.yaml` -- GitHub actions configuration. This file makes the directory an action.

   * `Dockerfile` (and probably `entrypoint.sh`) for [Docker-based Actions](https://docs.github.com/en/actions/creating-actions/creating-a-docker-container-action) **OR** `index.js` and `package-lock.json` et al for [Javascript actions](https://docs.github.com/en/actions/creating-actions/creating-a-javascript-action)

   * If you want the action to be run against _each_ repo configured in `repos.yaml`, add an `auto-apply.yaml` (schema [here](https://github.com/knative-sandbox/knobots/blob/main/cmd/gen-actions/main.go#L109)). This will cause the `gen-actions` tool (see below) to generate a `github/workflows` file which will fan out your command to all repos.

     It's expected that an auto-apply action will modify the checked-out workspace; these changes will export a `create_pr` variable (set to `true` if a PR shoud be created) and optionally a `log` output.

* `cmd/gen-actions` contains a script (`main.go`) and a template {`actions_template.yaml`) for generating fan-out PR generation workflows for all the `actions` directories which include an `auto-apply.yaml`.

  The parameters set in `auto-apply.yaml` are passed in to the `actions_template.yaml`, along with a `github` formatting function which passes through the remianing arguments to the _GitHub Actions_ templating system (both use the same `{{...}}` syntax for templating, so any GitHub templating needs to be escaped from the Go templates).

  This script _should_ stay fairly short; it's written in Go for two reasons:

   1. Go is a common language across Knative, and has sufficiently rich templating
   2. Using Go enables the script to work even on Windows machines, which is a nice benefit
