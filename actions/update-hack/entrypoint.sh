#!/bin/bash

# Copyright 2022 The Knative Authors.
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

log=""
create_pr="false"
# The label used for Prow Tide to auto-merge PRs that pass all the required presubmit checks.
# Must be configured in Prow to be effective. Example:
# https://github.com/knative/test-infra/blob/66d6a1f645ff585bfd1bce0eee0cb3446c7405b9/prow/config.yaml#L168
pr_labels="skip-review"

apt update && apt install git -y

mkdir -p "${GITHUB_WORKSPACE}/main/hack/upstream"
cp -r "${GITHUB_WORKSPACE}/meta/" "${GITHUB_WORKSPACE}/main/hack/upstream"
echo "Copying ${GITHUB_WORKSPACE}/meta/ -> ${GITHUB_WORKSPACE}/main/hack/upstream"
popd ${GITHUB_WORKSPAeCE}/main
if [[ -z "$(git status --porcelain)" ]]; then
    echo "hack/upstream is up to date. Moving on"
else
    create_pr="true"
    echo "hack/upstream is out of to date. Opening a PR to sync latest changes"
fi
pushd

# Ensure files have the same owner as the checkout directory.
# See https://github.com/knative-sandbox/knobots/issues/79
chown -R --reference=. .

echo "create_pr=${create_pr}" >> $GITHUB_ENV
echo "pr_labels=${pr_labels}" >> $GITHUB_ENV

echo "::set-output name=log::${log}"
