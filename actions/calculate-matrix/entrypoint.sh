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

function filtered_repos() {
  local EXCLUDE="${1}"
  local EXACT="${2}"
  local FILTER=$(cat "${EXCLUDE}" | yaml2json | jq "join(\"|\")")
  if [[ "$FILTER" != "" ]]; then
    FILTER=".name | test(${FILTER}) | not"
  else
    FILTER="true"
  fi
  if [[ "$EXACT" != "" ]]; then
    FILTER="(${FILTER}) and (.name == \"${EXACT}\")"
  fi

  cat repos.yaml | yaml2json | jq -c "map(select(${FILTER}))"
}

function filtered_names() {
    filtered_repos "${1}" "${2}" | jq -c "map(.name)"
}

SELECTED_NAMES="$(filtered_names "${NAME}-exclude.yaml" "${ONLY}")"
SELECTED_REPOS="$(filtered_repos "${NAME}-exclude.yaml" "${ONLY}")"

echo "::group::Matrix names for ${NAME}"
echo "${SELECTED_NAMES}" | jq .
echo "::endgroup::"

echo "::group::Matrix includes for ${NAME}"
echo "${SELECTED_REPOS}" | jq .
echo "::endgroup::"

echo "::set-output name=includes::${SELECTED_REPOS}"
echo "::set-output name=names::${SELECTED_NAMES}"
