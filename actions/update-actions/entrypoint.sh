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

set -e

log=""

create_pr="false"

mkdir -p "${GITHUB_WORKSPACE}/main/.github/workflows"
cp $(find "${GITHUB_WORKSPACE}/meta/workflow-templates" -type f -name '*.yaml') \
  "${GITHUB_WORKSPACE}/main/.github/workflows"
yaml2json < "${GITHUB_WORKSPACE}/config/actions-omitted.yaml" |
  jq -r '(.["${ORGANIZATION}/${REPO}"] // {"omit": []}).omit[] + "*"' | \
  while read GLOB; do
    rm "${GITHUB_WORKSPACE}/main/.github/workflows/${GLOB}"
  done

create_pr="true"

echo "create_pr=${create_pr}" >> $GITHUB_ENV
echo "::set-output name=create_pr::${create_pr}"

echo "::set-output name=log::$log"
