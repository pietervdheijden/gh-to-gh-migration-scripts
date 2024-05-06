#!/bin/bash

# This script migrates all packages from source to target repository
# Notes:
# - The script only supports maven and npm packages
# - The script assumes that the maven artifact ID does not contain a dot (.)
#
# Sample invocation:
#   GH_SOURCE_PAT=<GH_SOURCE_PAT> \
#   GH_SOURCE_ORG=<GH_SOURCE_ORG> \
#   GH_SOURCE_REPO=<GH_SOURCE_REPO> \
#   GH_TARGET_PAT=<GH_TARGET_PAT> \
#   GH_TARGET_ORG=<GH_TARGET_ORG> \
#   GH_TARGET_REPO=<GH_TARGET_REPO> \
#   ./migrate-packages.sh

require_env_var() {
  local var=$1
  if [ -z "${!var}" ]
  then
    echo "Environment variable '${var}' is required to run this script. Aborting..."
    exit 1
  fi
}

migrate_npm_package() {
  local PACKAGE=$1
  local VERSION=$2

  echo "Migrate NPM package: package=${PACKAGE}, version=${VERSION}"

  TMP_DIR="${SCRIPTPATH}/tmp"

  rm -rf $TMP_DIR
  mkdir $TMP_DIR

  cp package.json "${TMP_DIR}/package.json"
  cd $TMP_DIR

  npm set //npm.pkg.github.com/:_authToken=$GH_SOURCE_PAT
  npm set "@${GH_SOURCE_ORG}:registry=https://npm.pkg.github.com/"

  npm install @buildingblocksbv/$PACKAGE@$VERSION

  cd "node_modules/@${GH_SOURCE_ORG}/${GH_SOURCE_REPO}"
  sed -i "s/${GH_SOURCE_ORG}/${GH_TARGET_ORG}/g" package.json
  sed -i "s/\"https:\/\/github.com\/.*\"/\"https:\/\/github.com\/${GH_TARGET_ORG}\/${GH_TARGET_REPO}.git\""/g package.json

  npm set //npm.pkg.github.com/:_authToken=$GH_TARGET_PAT
  npm set "${GH_TARGET_ORG}@:registry=https://npm.pkg.github.com/"

  npm publish

  cd $SCRIPTPATH
}

set_up_maven_config() {
  # Create settings.xml
  rm -f $SETTINGS_XML_FILE
  cat "${SCRIPTPATH}/settings.xml.tpl" | \
    # Replace source variables
    sed "s/GH_SOURCE_USERNAME/${GH_SOURCE_USERNAME}/g" | \
    sed "s/GH_SOURCE_PAT/${GH_SOURCE_PAT}/g" | \
    sed "s/GH_SOURCE_ORG/${GH_SOURCE_ORG}/g" | \
    sed "s/GH_SOURCE_REPO/${GH_SOURCE_REPO}/g" | \

    # Replace target variables
    sed "s/GH_TARGET_USERNAME/${GH_TARGET_USERNAME}/g" | \
    sed "s/GH_TARGET_PAT/${GH_TARGET_PAT}/g" | \
    sed "s/GH_TARGET_ORG/${GH_TARGET_ORG}/g" | \
    sed "s/GH_TARGET_REPO/${GH_TARGET_REPO}/g"  > $SETTINGS_XML_FILE
}

migrate_maven_package() {
  local PACKAGE=$1
  local VERSION=$2

  echo "Migrate maven package: package=${PACKAGE}, version=${VERSION}"

  # Remove existing package from .m2 folder
  GROUP_ID_WITH_SLASHES=$(echo "$GROUP_ID" | sed 's/\./\//g')
  M2_DIR="~/.m2/repository/$GROUP_ID_WITH_SLASHES/${ARTIFACT_ID}/${VERSION}"
  echo "Remove existing package in m2 folder (if available): $M2_DIR"
  rm -rf $M2_DIR

  # Fetch POM
  echo "Fetch POM from source repo"
  mvn dependency:get \
      -DremoteRepositories=https://maven.pkg.github.com/${GH_SOURCE_ORG}/${GH_SOURCE_REPO} \
      -DartifactId=$ARTIFACT_ID \
      -DgroupId=$GROUP_ID \
      -Dversion=$VERSION \
      -Dpackaging=pom \
      -Dtransitive=false \
      -DrepositoryId=github-source \
      --global-settings $SETTINGS_XML_FILE >/dev/null || echo "Package version does not have a POM"

  # Fetch JAR (if available)
  echo "Fetch JAR from source repo"
  mvn dependency:get \
      -DremoteRepositories=https://maven.pkg.github.com/${GH_SOURCE_ORG}/${GH_SOURCE_REPO} \
      -DartifactId=$ARTIFACT_ID \
      -DgroupId=$GROUP_ID \
      -Dversion=$VERSION \
      -Dpackaging=jar \
      -Dtransitive=false \
      -DrepositoryId=github-source \
      --global-settings $SETTINGS_XML_FILE >/dev/null 2>&1 || echo "Package version does not have a JAR"

  # Fetch sources (if available)
  echo "Fetch sources from source repo"
  mvn dependency:get \
      -DremoteRepositories=https://maven.pkg.github.com/${GH_SOURCE_ORG}/${GH_SOURCE_REPO} \
      -DartifactId=$ARTIFACT_ID \
      -DgroupId=$GROUP_ID \
      -Dversion=$VERSION \
      -Dpackaging=jar \
      -Dclassifier=sources \
      -Dtransitive=false \
      -DrepositoryId=github-source \
      --global-settings $SETTINGS_XML_FILE >/dev/null 2>&1 || echo "Package version does not have sources"

  # Copy package to tmp folder
  # This is required by the latest mvn deploy-file plugin: https://stackoverflow.com/questions/14223221/why-cant-i-deploy-from-my-local-repository-to-a-remote-maven-repository/54508627#54508627
  TMP_DIR="tmp/maven/${ARTIFACT_ID}-${VERSION}"
  echo "Copy package to tmp folder: $TMP_DIR"
  rm -rf $TMP_DIR
  mkdir -p $TMP_DIR
  cp -r  ~/.m2/repository/$GROUP_ID_WITH_SLASHES/$ARTIFACT_ID/$VERSION/* $TMP_DIR
  ls $TMP_DIR

  # Upload package to target repo
  echo "Upload package to target repo"
  POM_FILE=$(find $TMP_DIR -maxdepth 1 -type f -a -name "*.pom")
  JAR_FILE=$(find $TMP_DIR -maxdepth 1 -type f -a -name "*.jar" -not -name "*sources.jar")
  SOURCES_FILE=$(find $TMP_DIR -maxdepth 1 -type f -a -name "*sources.jar")
  MAVEN_COMMAND="deploy:deploy-file -Durl=https://maven.pkg.github.com/${GH_TARGET_ORG}/${GH_TARGET_REPO} -DrepositoryId=github-target -DgroupId=${GROUP_ID} -DartifactId=${ARTIFACT_ID} -Dversion=${VERSION} --global-settings=${SETTINGS_XML_FILE}"
  if [[ -f $JAR_FILE ]]; then
      MAVEN_COMMAND="$MAVEN_COMMAND -Dfile=$JAR_FILE"
      if [[ -f $POM_FILE ]]; then
        MAVEN_COMMAND="${MAVEN_COMMAND} -DpomFile=$POM_FILE"
      fi
      if [[ -f $SOURCES_FILE ]]; then
        MAVEN_COMMAND="${MAVEN_COMMAND} -Dsources=$SOURCES_FILE"
      fi
  elif [[ -f $POM_FILE ]]; then
      MAVEN_COMMAND="${MAVEN_COMMAND} -Dfile=$POM_FILE"
  fi
  MAVEN_COMMAND="${MAVEN_COMMAND}"
  echo "Execute maven command: '$MAVEN_COMMAND'"
  mvn $MAVEN_COMMAND >/dev/null 2>&1 && echo "Successfully uploaded package" || echo "Failed to upload package"

  # Clean up tmp folder
  echo "Clean up tmp folder: $TMP_DIR"
  rm -rf $TMP_DIR

  echo "Migrated package version: ${PACKAGE}:${VERSION}"
}

migrate_packages() {
  local PACKAGE_TYPE=$1

  echo "Migrate packages with type: ${PACKAGE_TYPE}"

  for PACKAGE in $(GH_TOKEN="${GH_SOURCE_PAT}" gh api --paginate "/orgs/${GH_SOURCE_ORG}/packages?package_type=${PACKAGE_TYPE}" | jq -r .[].name | sort)
  do
    echo "Migrate package: ${PACKAGE}"

    # Get current target package versions
    TARGET_PACKAGE_EXISTS=$(GH_TOKEN="${GH_TARGET_PAT}" gh api --silent "/orgs/${GH_TARGET_ORG}/packages/${PACKAGE_TYPE}/${PACKAGE}" 2> /dev/null && echo "true" || echo "false")
    TARGET_PACKAGE_VERSIONS="[]"
    if [[ $TARGET_PACKAGE_EXISTS = "true" ]]
    then
        TARGET_PACKAGE_VERSIONS=$(GH_TOKEN="${GH_TARGET_PAT}" gh api --paginate "/orgs/${GH_TARGET_ORG}/packages/${PACKAGE_TYPE}/${PACKAGE}/versions")
    fi

    for VERSION in $(GH_TOKEN="${GH_SOURCE_PAT}" gh api --paginate "/orgs/${GH_SOURCE_ORG}/packages/${PACKAGE_TYPE}/${PACKAGE}/versions" | jq -r .[].name | sort -t. -n -k1,1 -k2,2 -k3,3)
    do
      # Check if package already exists in target
      TARGET_PACKAGE_VERSION_EXISTS=$(echo "$TARGET_PACKAGE_VERSIONS" | jq --arg v "${VERSION}" 'any(.[].name == $v; .)' 2> /dev/null || echo "false")

      # If package version does not exist, then migrate package to target GitHub repository
      if [[ $TARGET_PACKAGE_VERSION_EXISTS = "false" ]];
      then
        if [[ $PACKAGE_TYPE = "maven" ]]
        then
          migrate_maven_package $PACKAGE $VERSION
        elif [[ $PACKAGE_TYPE = "npm" ]]
        then
          migrate_npm_package $PACKAGE $VERSION
        else
          echo "Unsupported package type: '${PACKAGE_TYPE}'!"
          exit 1
        fi
        echo "----"
      fi
    done

    echo "--------"
  done
}


require_env_var "GH_SOURCE_USERNAME"
require_env_var "GH_SOURCE_PAT"
require_env_var "GH_SOURCE_ORG"
require_env_var "GH_SOURCE_REPO"
require_env_var "GH_TARGET_USERNAME"
require_env_var "GH_TARGET_PAT"
require_env_var "GH_TARGET_ORG"
require_env_var "GH_TARGET_REPO"

SCRIPT=$(realpath -s "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

SETTINGS_XML_FILE="${SCRIPTPATH}/settings.xml"
set_up_maven_config
migrate_packages "maven"
migrate_packages "npm"

