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
const v8 = require('v8')
const yaml = require('js-yaml')

function readRepos(dir) {
    const repoFilename = path.join(dir, "repos.yaml")
    const doc = yaml.load(fs.readFileSync(repoFilename))
    return doc
}

function forkFromRepo(repoName, repoInfo) {
    if ("fork" in repoInfo) {
        return repoInfo.fork
    }
    if ("forkOrg" in repoInfo) {
        return repoInfo.forkOrg + "/" + repoName
    }
    return "knative-automation/" + repoName
}

try {
    const configDir = core.getInput("configDir")
    const orgs = readRepos(configDir)
    let repoSummary = {}
    console.log("Loaded", orgs.length, "orgs")

    for (org of orgs) {
        const orgActions = org.actions
        for (repo in org.repos) {
            const repoInfo = org.repos[repo]
            let info = {
                "actionsSource": org.org,
                "fork": forkFromRepo(repo, repoInfo),
                "slackChannel": repoInfo.channel,
                "gitHubAssignees": repoInfo.assignees,
                "actions": v8.deserialize(v8.serialize(orgActions))  // deepcopy
            }
            if ("actionsSource" in repoInfo) {
                info.actionsSource = repoInfo.actionsSource
            }
            if ("exclude" in repoInfo) {
                for (action of repoInfo.exclude) {
                    delete info.actions[action]
                }
            }
            if ("actions" in repoInfo) {
                for (action in repoInfo.actions) {
                    info.actions[action] = repoInfo.actions[action]
                }
            }
            repoSummary[org.org + "/" + repo] = info
        }
    }

    const outFile = path.join(configDir, "config.json")
    fs.writeFileSync(outFile, JSON.stringify(repoSummary, null, space = 2))
    console.log("Wrote", Object.keys(repoSummary).length, "repos to", outFile)
} catch (error) {
    core.setFailed(error)
}