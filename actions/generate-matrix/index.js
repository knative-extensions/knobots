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
const yaml = require('js-yaml')

function readRepos(dir) {
    const repoFilename = path.join(dir, "repos.yaml")
    const doc = yaml.load(fs.readFileSync(repoFilename))
    return doc
}

function getActionExcludes(dir) {
    const items = fs.readdirSync(dir)
    const suffixLen = ("-exclude.yaml".length)
    let actionInfos = {}
    for (const item of items) {
        if (!item.endsWith("-exclude.yaml")) {
            continue
        }
        fileName = path.join(dir, item)
        const prefix = item.substr(0, item.length - suffixLen)
        info = {
            exclude: yaml.load(fs.readFileSync(fileName)),
            config: true
        }
        optionsFile = path.join(dir, prefix + "-omitted.yaml")
        if (fs.existsSync(optionsFile)) {
            info.config = yaml.load(fs.readFileSync(optionsFile))
        }
        actionInfos[prefix] = info
    }
    return actionInfos
}

function orgFromRepo(repoInfo) {
    if ("meta-organization" in repoInfo) {
        return repoInfo["meta-organization"]
    }
    return repo.substr(0, repo.indexOf("/"))
}

function forkFromRepo(repoInfo) {
    if ("fork" in repoInfo) {
        return repoInfo.fork
    }
    if ("forkOrg" in repoInfo) {
        return repoInfo.forkOrg + "/" + orgFromRepo(repoInfo.name)
    }
    return "knative-automation/" + orgFromRepo(repoInfo.name)
}

try {
    const configDir = core.getInput("configDir")
    const repos = readRepos(configDir)
    const actionExcludes = getActionExcludes(configDir)
    let repoSummary = {}
    console.log("Loaded", repos.length, "repos")
    for (repoInfo of repos) {
        const name = repoInfo.name
        let info = {
            "actionsSource": orgFromRepo(repoInfo),
            "fork": forkFromRepo(repoInfo),
            "slackChannel": repoInfo.channel,
            "gitHubAssignees": repoInfo.assignees,
            "actions": {}
        }
        for (a in actionExcludes) {
            const excludes = actionExcludes[a].exclude
            if (excludes.includes(name) || excludes.includes(info.org)) {
                continue
            }
            if (actionExcludes[a].config === true) {
                info.actions[a] = {}
            } else if (name in actionExcludes[a].config) {
                info.actions[a] = actionExcludes[a].config[name]
            } else {
                info.actions[a] = {}
            }
        }
        repoSummary[name] = info
    }
    const outFile = path.join(configDir, "config.json")
    fs.writeFileSync(outFile, JSON.stringify(repoSummary, null, space = 2))
    console.log("Wrote", Object.keys(repoSummary).length, "repos to", outFile)
} catch (error) {
    core.setFailed(error)
}