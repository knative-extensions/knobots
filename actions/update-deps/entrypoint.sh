#!/bin/bash

# Copyright 2021 The Knative Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

deplog=""

# The scripts below use `git` on the checked out .../main that has a
# different user than the docker user which gives an error. We thus have
# to explicitly allow it with the below command. For more info see:
# https://github.com/git/git/commit/8959555cee7ec045958f9b6dd62e541affb7e7d9
git config --global --add safe.directory /github/workspace/main

cd main

# Determine the name of the go module.
if [[ -f go.mod ]]; then
    export MODULE_NAME=$(go mod graph | cut -d' ' -f 1 | grep -v '@' | head -1)

    # TODO(mattmoor): Move this into `./hack/update-codegen.sh`
    TMP_DIR="$(mktemp -d)"
    export GOPATH=${GOPATH:-${TMP_DIR}}
    export PATH="${PATH}:${TMP_DIR}/bin"
    TMP_REPO_PATH="${TMP_DIR}/src/${MODULE_NAME}"
    mkdir -p "$(dirname "${TMP_REPO_PATH}")" && ln -s "${GITHUB_WORKSPACE}" "${TMP_REPO_PATH}"

    releaseFlags=()
    # Test to see if this module is using the knative.dev/hack repo, if it is,
    # then we know it is safe to pass down the release flag.
    if [[ $(buoy needs go.mod --domain knative.dev | grep knative.dev/hack) ]]; then
      releaseFlags+=("--release ${RELEASE} --module-release ${MODULE_RELEASE}")
    fi

    echo "::set-output name=update-dep-cmd::./hack/update-deps.sh --upgrade ${releaseFlags[@]}"
    ./hack/update-deps.sh --upgrade ${releaseFlags[@]}
    # capture logs for the module changes
    deplog=$(modlog . HEAD dirty || true)
    deplog="${deplog//$'\n'/'%0A'}"
    deplog="${deplog//$'\r'/'%0D'}"
fi

# We may pull in code-generator updates, or not have generated code.
[[ ! -f hack/update-codegen.sh ]] || ./hack/update-codegen.sh

# If we don't run this before the "git diff-index" it seems to list
# every file that's been touched by codegen.
git status
create_pr="false"
if [[ "${FORCE_DEPS}" == "true" ]]; then
  create_pr="true"
fi
for x in $(git diff-index --name-only HEAD --); do
    if [ "$(basename $x)" = "go.mod" ]; then
        continue
    elif [ "$(basename $x)" = "go.sum" ]; then
        continue
    elif [ "$(basename $x)" = "modules.txt" ]; then
        continue
    fi
    echo "Found non-module diff: $x"
    create_pr="true"
    break
done

# Ensure files have the same owner as the checkout directory.
# See https://github.com/knative-sandbox/knobots/issues/79
chown -R --reference=. .

echo "create_pr=${create_pr}" >> $GITHUB_ENV

echo "::set-output name=log::$deplog"
