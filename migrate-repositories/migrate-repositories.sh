#!/bin/bash

# This script migrates all repositories from source to target organization.
#
# Sample invocation:
#   GH_SOURCE_PAT=<GH_SOURCE_PAT> \
#   GH_SOURCE_ORG=<GH_SOURCE_ORG> \
#   GH_TARGET_PAT=<GH_TARGET_PAT> \
#   GH_TARGET_ORG=<GH_TARGET_ORG> \
#   ./migrate-repositories.sh

require_env_var() {
  local var=$1
  if [ -z "${!var}" ]
  then
    echo "Environment variable '${var}' is required to run this script. Aborting..."
    exit 1
  fi
}

require_env_var "GH_SOURCE_PAT"
require_env_var "GH_SOURCE_ORG"
require_env_var "GH_TARGET_PAT"
require_env_var "GH_TARGET_ORG"

for REPO in $(GH_TOKEN="${GH_SOURCE_PAT}" gh api --paginate "/orgs/${GH_SOURCE_ORG}/repos" | jq -r .[].name | sort)
do
  TARGET_REPO_EXISTS=$(GH_TOKEN="${GH_TARGET_PAT}" gh api --silent "/repos/${GH_TARGET_ORG}/$REPO" 2> /dev/null && echo "true" || echo "false")
  if [[ TARGET_REPO_EXISTS = "false" ]]
  then
    echo "Queue repo: ${REPO}"

    MIGRATION_LOG=$(GH_PAT="${GH_TARGET_PAT}" GH_SOURCE_PAT="${GH_SOURCE_PAT}" gh gei migrate-repo \
      --github-source-org $GH_SOURCE_ORG \
      --source-repo="${REPO}" \
      --github-target-org $GH_TARGET_ORG \
      --target-repo="${REPO}" \
      --queue-only \
      --target-repo-visibility private)
    MIGRATION_ID=$(echo $MIGRATION_LOG | grep ID | sed -E 's/.*ID: (.*)\).*/\1/g')
    echo "Queued repo: ${REPO} with migration ID: ${MIGRATION_ID}"
  fi
done