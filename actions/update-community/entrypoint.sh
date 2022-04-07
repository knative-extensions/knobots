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

log=""
create_pr="false"
# The label used for Prow Tide to auto-merge PRs that pass all the required presubmit checks.
# Must be configured in Prow to be effective. Example:
# https://github.com/knative/test-infra/blob/66d6a1f645ff585bfd1bce0eee0cb3446c7405b9/prow/config.yaml#L168
pr_labels="skip-review"

FILE="peribolos/${ORGANIZATION}-OWNERS_ALIASES"

if [ -f "${GITHUB_WORKSPACE}/meta/${FILE}" ]; then
  cp "${GITHUB_WORKSPACE}/meta/${FILE}" "${GITHUB_WORKSPACE}/main/OWNERS_ALIASES"
  echo "Copying ${GITHUB_WORKSPACE}/meta/${FILE} -> ${GITHUB_WORKSPACE}/main/OWNERS_ALIASES"
  create_pr="true"
else
  echo "Could not find ${FILE}, skipping"
fi
# TODO: copy other files over, like CODE-OF-CONDUCT.md

# Ensure files have the same owner as the checkout directory.
# See https://github.com/knative-sandbox/knobots/issues/79
chown -R --reference=. .

echo "create_pr=${create_pr}" >> $GITHUB_ENV
echo "pr_labels=${pr_labels}" >> $GITHUB_ENV

echo "::set-output name=log::${log}"
