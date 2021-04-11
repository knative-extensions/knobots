#!/bin/bash

# Copyright 2020 The Knative Authors.
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

# Determine the name of the go module.
if [[ -f go.mod ]]; then
    export MODULE_NAME=$(go mod graph | cut -d' ' -f 1 | grep -v '@' | head -1)

    # TODO(mattmoor): Move this into `./hack/update-codegen.sh`
    TMP_DIR="$(mktemp -d)"
    export GOPATH=${GOPATH:-${TMP_DIR}}
    export PATH="${PATH}:${TMP_DIR}/bin"
    TMP_REPO_PATH="${TMP_DIR}/src/${MODULE_NAME}"
    mkdir -p "$(dirname "${TMP_REPO_PATH}")" && ln -s "${GITHUB_WORKSPACE}" "${TMP_REPO_PATH}"

    release_flag=""
    # Test to see if this module is using the knative.dev/hack repo, if it is,
    # then we know it is safe to pass down the release flag.
    if [[ $(buoy needs go.mod --domain knative.dev | grep knative.dev/hack) ]]; then
        release_flag="--release ${{ needs.meta.outputs.release }}"
    fi

    echo "::set-output name=update-dep-cmd::./hack/update-deps.sh --upgrade ${release_flag}"
    ./hack/update-deps.sh --upgrade ${release_flag}
fi

# We may pull in code-generator updates, or not have generated code.
[[ ! -f hack/update-codegen.sh ]] || ./hack/update-codegen.sh

# If we don't run this before the "git diff-index" it seems to list
# every file that's been touched by codegen.
git status
echo "create_pr=false" >> $GITHUB_ENV  # TODO: re-incorporate "don't ignore go accounting" flag
for x in $(git diff-index --name-only HEAD --); do
    if [ "$(basename $x)" = "go.mod" ]; then
        continue
    elif [ "$(basename $x)" = "go.sum" ]; then
        continue
    elif [ "$(basename $x)" = "modules.txt" ]; then
        continue
    fi
    echo "Found non-module diff: $x"
    echo "create_pr=true" >> $GITHUB_ENV
    echo "::set-output name=create_pr::true"
    break
done

# capture logs for the module changes
deplog=$(modlog . HEAD dirty || true)
deplog="${deplog//$'\n'/'%0A'}"
deplog="${deplog//$'\r'/'%0D'}"
echo "::set-output name=deplog::$deplog"
