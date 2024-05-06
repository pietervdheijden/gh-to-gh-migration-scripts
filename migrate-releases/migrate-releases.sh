#!/bin/bash

# This script migrates all releases from source to target repository, including all assets.
#
# Sample invocation:
#   GH_SOURCE_PAT=<GH_SOURCE_PAT> \
#   GH_SOURCE_ORG=<GH_SOURCE_ORG> \
#   GH_SOURCE_REPO=<GH_SOURCE_REPO> \
#   GH_TARGET_PAT=<GH_TARGET_PAT> \
#   GH_TARGET_ORG=<GH_TARGET_ORG> \
#   GH_TARGET_REPO=<GH_TARGET_REPO> \
#   ./migrate-releases.sh

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
require_env_var "GH_SOURCE_REPO"
require_env_var "GH_TARGET_PAT"
require_env_var "GH_TARGET_ORG"
require_env_var "GH_TARGET_REPO"

SCRIPT=$(realpath -s "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
TMPDIR="${SCRIPTPATH}/tmp"

rm -rf $TMPDIR
mkdir $TMPDIR

SOURCE_RELEASES=$(GH_TOKEN="${GH_SOURCE_PAT}" gh api --paginate "/repos/${GH_SOURCE_ORG}/${GH_SOURCE_REPO}/releases")
TARGET_RELEASES=$(GH_TOKEN="${GH_TARGET_PAT}" gh api --paginate "/repos/${GH_TARGET_ORG}/${GH_TARGET_REPO}/releases")
for RELEASE_ID in $(echo "$SOURCE_RELEASES" | jq -r '.[].id' | sort)
do
  RELEASE=$(echo "${SOURCE_RELEASES}" | jq --argjson r "${RELEASE_ID}" '.[] | select(.id==$r)')
  RELEASE_NAME=$(echo "${RELEASE}" | jq -r .name)
  RELEASE_TAGNAME=$(echo "${RELEASE}" | jq -r .tag_name)
  RELEASE_PRERELEASE=$(echo "${RELEASE}" | jq -r .prerelease)
  RELEASE_DRAFT=$(echo "${RELEASE}" | jq -r .draft)
  RELEASE_BODY=$(echo "${RELEASE}" | jq -r .body)

  # Check if release already exists in target
  TARGET_RELEASE_EXISTS=$(echo "$TARGET_RELEASES" | jq --arg r "${RELEASE_NAME}" 'any(.[].name == $r; .)' 2> /dev/null || echo "false")

  #  # If package version does not exist, then migrate package to target GitHub repository
  if [[ $TARGET_RELEASE_EXISTS = "false" ]];
  then
    echo "Migrate release: ${RELEASE_NAME}"

    # Create target release
    TARGET_RELEASE_ID=$(GH_TOKEN="${GH_TARGET_PAT}" gh api "/repos/${GH_TARGET_ORG}/${GH_TARGET_REPO}/releases" \
      --method POST \
      --field "tag_name=$RELEASE_TAGNAME" \
      --field "name=$RELEASE_NAME" \
      --field "draft=$RELEASE_DRAFT" \
      --field "prerelease=$RELEASE_PRERELEASE" \
      --field "body=$RELEASE_BODY" | jq .id)

    # Fetch + upload each asset
    SOURCE_ASSETS=$(GH_TOKEN="${GH_SOURCE_PAT}" gh api --paginate "/repos/${GH_SOURCE_ORG}/${GH_SOURCE_REPO}/releases/${RELEASE_ID}/assets")
    for ASSET_ID in $(echo "${SOURCE_ASSETS}" | jq -r '.[].id' | sort)
    do
      ASSET=$(echo "${SOURCE_ASSETS}" | jq --argjson r "${ASSET_ID}" '.[] | select(.id==$r)')
      ASSET_NAME=$(echo "${ASSET}" | jq -r .name)

      # Fetch asset
      echo "Fetch asset: ${ASSET_NAME}"
      GH_TOKEN="${GH_SOURCE_PAT}" gh api --header Accept:application/octet-stream "/repos/${GH_SOURCE_ORG}/${GH_SOURCE_REPO}/releases/assets/${ASSET_ID}" > "$ASSET_NAME"

      # Upload asset
      echo "Upload asset: ${ASSET_NAME}"
      curl -L \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: token ${GH_TARGET_PAT}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/octet-stream" \
        "https://uploads.github.com/repos/${GH_TARGET_ORG}/${GH_TARGET_REPO}/releases/${TARGET_RELEASE_ID}/assets?name=${ASSET_NAME}" \
        --data-binary "@${ASSET_NAME}"
    done
  else
    echo "Skip release: ${RELEASE_NAME}. Release is already migrated."
  fi
  echo "---------------------"
done
