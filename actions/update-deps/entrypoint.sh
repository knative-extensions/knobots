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

cd main

# Determine the name of the go module.
if [[ -f go.mod ]]; then
    MODULE_NAME=$(go list -m -f '{{.Path}}')
    export MODULE_NAME

    # TODO(mattmoor): Move this into `./hack/update-codegen.sh`
    TMP_DIR="$(mktemp -d)"
    export GOPATH=${GOPATH:-${TMP_DIR}}
    export PATH="${PATH}:${TMP_DIR}/bin"
    TMP_REPO_PATH="${TMP_DIR}/src/${MODULE_NAME}"
    mkdir -p "$(dirname "${TMP_REPO_PATH}")" && ln -s "${GITHUB_WORKSPACE}" "${TMP_REPO_PATH}"

    tokens=(${RELEASE//\./ })
    release_minor="${tokens[1]}"
    export MODULE_RELEASE="0.$(( release_minor + 27 ))"

    releaseFlags=()
    # Test to see if this module is using the knative.dev/hack repo, if it is,
    # then we know it is safe to pass down the release flag.
    if buoy needs go.mod --domain knative.dev | grep -Fq 'knative.dev/hack'; then
      releaseFlags+=(--release "$RELEASE" --module-release "$MODULE_RELEASE")
    fi

    echo "update-dep-cmd=./hack/update-deps.sh --upgrade ${releaseFlags[*]}" >> "$GITHUB_OUTPUT"
    ./hack/update-deps.sh --upgrade "${releaseFlags[@]}"
    # capture logs for the module changes
    # https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#multiline-strings
    # The log goes into the commit message, which create-pull-request gets as one
    # env var. Linux caps one env var at MAX_ARG_STRLEN (128 KiB). 64 KiB keeps
    # us well under that, and also under GitHub's 65536-character limit for a PR
    # body if the log ever goes there.
    max_log_bytes=65536
    EOF=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
    echo "log<<$EOF" >> "$GITHUB_OUTPUT"
      modlog . HEAD dirty \
        | LC_ALL=C awk -v max="${max_log_bytes}" '{ n += length($0) + 1; if (n > max) { print "  ... (truncated)"; exit } print }' \
        >> "$GITHUB_OUTPUT" || true
    echo "$EOF" >> "$GITHUB_OUTPUT"
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
vendor_dir=$(find . -type d -name vendor -print -quit)
# Use process substitution so create_pr changes persist outside the loop.
while IFS= read -r -d '' file; do
    if [[ -z "$vendor_dir" ]]; then
        echo "Found diff: $file"
        create_pr="true"
        break
    fi
    case "${file##*/}" in
        go.mod|go.sum|modules.txt) continue ;;
    esac
    echo "Found non-module diff: $file"
    create_pr="true"
    break
done < <(git diff-index --name-only -z HEAD --)

echo "pr_labels=skip-review" >> "$GITHUB_ENV"
echo "create_pr=${create_pr}" >> "$GITHUB_ENV"
