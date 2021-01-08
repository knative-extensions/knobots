#!/usr/bin/env bash

# Requires the following:
# - gh (https://github.com/cli/cli)
# - buoy (https://github.com/knative/test-infra/tree/master/buoy)
# - env has GITHUB_TOKEN set.
# invoke with:
#   ./hack/auto-fork.sh <org with repos to fork>

org=$1
if [ -z "$org" ]; then
  echo "invoke with ./hack/auto-fork.sh <org>, org is required."
    exit 1
fi

has () {
    local seeking=$1; shift
    local in=1
    for element; do
        if [[ $element == "$seeking" ]]; then
            in=0
            break
        fi
    done
    return $in
}

has_fork () {
  local repository=$1; shift
  echo "✅ ${repository} is already forked."
}

make_fork () {
  local repository=$1; shift
  echo "🐎 ${repository} will be forked."
  gh repo fork ${org}/${repo} --remote=false
  sleep 1
  if [ $? -eq 0 ]
  then
    echo "✅ ${repository} is forked."
  else
    echo "❌ ${repository} failed to fork."
  fi
}

forked=$(buoy repos knative-automation | sed 's/knative-automation\///')

for i in $(buoy repos ${org}); do
  repo=$(basename ${i})
  has $repo ${forked} && has_fork "${org}/${repo}" || make_fork "${org}/${repo}"
done
