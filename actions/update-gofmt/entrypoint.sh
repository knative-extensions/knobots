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

deplog=""

create_pr="false"

# Determine the name of the go module.
if [[ ! -f go.mod ]]; then
    echo "No go mod, skipping..."
    exit(0)
else

    export FILES=( $(find -path './vendor' -prune -o -path './third_party' -prune -o -name '*.pb.go' -prune -o -type f -name '*.go' -print) )
    export GENFILES= ( $(git ls-files | xargs git check-attr linguist-generated | grep 'true$' | cut -d: -f1) )
    for i in "${GENFILES[@]}"; do
        FILES=(${FILES[@]//*$i*})
    done
    if (( ${#FILES[@]} > 0 )); then
        deplog=$(goimports -w "${FILES[@]}")
        deplog=$deplog $(gofmt -s -w "${FILES[@]}")
        create_pr="true"
    else
        echo No Go files found.
    fi
fi
echo "create_pr=${create_pr}" >> $GITHUB_ENV
echo "::set-output name=create_pr::${create_pr}"

echo "::set-output name=deplog::$deplog"
