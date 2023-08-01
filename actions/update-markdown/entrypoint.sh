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
ignore_file=$(mktemp)

echo '**/.git'        >> $ignore_file
echo '**/.github'     >> $ignore_file
echo '**/vendor'      >> $ignore_file
echo '**/third_party' >> $ignore_file
echo '**/docs/cmd'    >> $ignore_file

cd main

echo 'log<<EOF' >> "$GITHUB_OUTPUT"
prettier --ignore-path $ignore_file -l $(find . -name "*.md") &2>1 >> $GITHUB_OUTPUT
echo 'EOF' >> "$GITHUB_OUTPUT"

[ -z "$(git status --porcelain=v1 2>/dev/null)" ] || create_pr="true"

# Ensure files have the same owner as the checkout directory.
# See https://github.com/knative-extensions/knobots/issues/79
chown -R --reference=. .


echo "create_pr=${create_pr}" >> $GITHUB_ENV
