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

function loadMatrix(dir, action, only) {
    const config = JSON.parse(fs.readFileSync(path.join(dir, "config.json")))
    let names = []
    let includes = []

    if (only) {
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
                "meta-organization": r.org,
                fork: r.fork,
                channel: r.slackChannel,
                assignees: r.gitHubAssignees,
                config: r.actions[action]
            })
        }
    }
    return [names, includes]
}

try {
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