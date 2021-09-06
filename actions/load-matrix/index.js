// Copyright 2021 The Knative Authors.
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

const core = require('@actions/core')
const fs = require('fs')
const path = require('path')

// Load the computed per-repo configuration for "action" from "config.json".
// If "only" is set, return only configuration for that repo.
// Returns two values:
// * A list of repos to run this action on.
// * A list of objects (in the same order as the first) containing additional
//   per-repo configuration.
// The dual-list approach is odd; we should consider refactoring actions to
// only need the second list and simplify this function.
function loadMatrix(dir, action, only) {
    const config = JSON.parse(fs.readFileSync(path.join(dir, "config.json")))
    let names = []
    let includes = []

    if (only) {
        // Note: we're not checking that config[only].actions contains only
        // This allows you to do a one-off run against a repo that this
        // action doesn't normally execute against.
        if (only in config) {
            names = [only]
            includes = [{ only: config[only] }]
        }
        return [names, includes]
    }

    for (const repo in config) {
        const r = config[repo]
        if (action in r.actions) {
            names.push(repo)
            includes.push({
                name: repo,
                // The organization this repo should act as if it belongs to.
                "meta-organization": r.actionsSource,
                fork: r.fork,
                channel: r.slackChannel,
                assignees: r.gitHubAssignees,
                config: r.actions[action]
            })
        }
    }
    return [names, includes]
}

// This is our main. We wrap it in a try to so we can consistently
// set failure messages on error.
try {
    // action-name is passed as the INPUT_ACTION-NAME env var internally.
    const action = core.getInput("action-name")
    const only = core.getInput("only-repo")

    const [names, includes] = loadMatrix(".", action, only)

    core.startGroup("Matrix names for " + action)
    console.log(names)
    core.endGroup()

    core.startGroup("Matrix includes for " + action)
    console.log(includes)
    core.endGroup()

    core.setOutput("names", names)
    core.setOutput("includes", includes)

} catch (error) {
    core.setFailed(error)
}