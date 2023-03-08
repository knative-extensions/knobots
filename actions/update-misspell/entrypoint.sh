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

cd main

export files=( $(find . -type f -not -path './vendor/*' -not -path './third-party/*' -not -path './.git/*') )

if (( ${#FILES[@]} > 0 )); then
    log=$(misspell -i importas -w "${FILES[@]}" )
    create_pr="true"
else
    echo No files found.
fi

# Ensure files have the same owner as the checkout directory.
# See https://github.com/knative-sandbox/knobots/issues/79
chown -R --reference=. .

echo "create_pr=${create_pr}" >> $GITHUB_ENV

echo "log=$log" >> $GITHUB_OUTPUT
