# Welcome to knobots

This repository contains a number of github actions, which perform routine
maintenance tasks for a variety of repositories, mostly for the knative org.

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

      # Whether to notify channel when a PR has been staged (defaults to 'false')
      pr-notify: 'true'
   ```

2. `github.com/{fork}.git` must be a fork of `{name}` (if specified) and `knative-automation`
  must have push access.


Repos can also optionally exclude certain jobs by adding their name to the appropriate `{foo}-exclude.yaml` file.