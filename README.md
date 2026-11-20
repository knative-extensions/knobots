# Welcome to knobots

This repository contains a number of github actions, which perform routine
maintenance tasks for a variety of repositories, mostly for the knative org. In
particular, this repo exists separately from other repos like
https://github.com/knative/test-infra to enable using [repository
secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository)
to hold an access token for creating automated PRs.

If you want to run a job periodically against a repo, the
[workload-templates](https://github.com/knative-extensions/knobots/tree/main/workflow-templates)
folder holds all the template actions which are copied to all the repos in
Knative using the `update-actions` workflow in this repo.

## Adding a repo

To add a repository here, there are two requirements:
1. Add an entry to `repos.yaml` containing an entry like this:

   ```yaml
    - # name is the repository to operate on, think: https://github.com/{name}.git
      name: 'knative/pkg'

      # meta-organization is the github organization from which to sync Github
      # actions, think: https://github.com/{meta-organization}/hack
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


3. Repos can also optionally exclude certain jobs by adding their name to the
appropriate `{foo}-exclude.yaml` file.

## Adding new automation

This repo exists to run [GitHub Actions](https://docs.github.com/en/actions) to
create automated management PRs against other repos in Knative. To add a new
automated PR workflow (or update one of the existing workflows), it's worth
understanding the different components in this repo:

* `.github/workflows` contains the GitHub Actions workflows. These files are maintained directly and are the source of truth for schedules, repository checkouts, action inputs, and PR settings. There is no workflow-generation step.

* `actions` contains a set of [composite GitHub Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action) that run directly on GitHub-hosted Ubuntu runners. Actions that use Go set it up with `knative/actions/setup-go@main`. They use the runner's preinstalled Node.js/npm, jq, Helm, and envsubst, installing only action-specific tools. Each directory under `actions` should contain the following:

   * `action.yaml` -- GitHub actions configuration and inline shell steps. Composite steps install any extra tools and forward script outputs through `action.yaml`. Keep simple scripts inline so the action is self-contained.

   * For longer implementations, such as dependency updates, an optional `entrypoint.sh` is invoked using `github.action_path`. No container build is required.

   * To run an action against each selected repo in `repos.yaml`, add a workflow under `.github/workflows`, following an existing `auto-update-*.yaml` workflow. Use `actions/calculate-matrix` to select repositories and pass only inputs declared by the action's `action.yaml`.

     Actions modify the repository checked out under `main/`, set `create_pr=true` through `$GITHUB_ENV` when a PR should be created, and may expose a `log` output for the commit message and PR body.

   * Go setup disables dependency caching with `cache: 'false'`: the actions install standalone tools without a dependency manifest or lockfile, rather than building this repository.

   * `update-misspell` only corrects comments in `.go` files. It excludes vendor, third-party, and Git metadata directories at every depth; other file types and Go string literals are left untouched.
