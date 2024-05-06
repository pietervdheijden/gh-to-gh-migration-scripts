# GitHub to GitHub migration scripts

These scripts migrate data from one GitHub instance to another one.

To migrate repositories, run:

```shell
GH_SOURCE_PAT="<GH_SOURCE_PAT>" \
GH_SOURCE_ORG="<GH_SOURCE_ORG>" \
GH_TARGET_PAT="<GH_TARGET_PAT>" \
GH_TARGET_ORG="<GH_TARGET_ORG>" \
./migrate-repositories.sh
```

To migrate releases, run:

```shell
GH_SOURCE_PAT="<GH_SOURCE_PAT>" \
GH_SOURCE_ORG="<GH_SOURCE_ORG>" \
GH_SOURCE_REPO="<GH_SOURCE_REPO>" \
GH_TARGET_PAT="<GH_TARGET_PAT>" \
GH_TARGET_ORG="<GH_TARGET_ORG>" \
GH_TARGET_REPO="<GH_TARGET_REPO>" \
./migrate-releases.sh
```

To migrate maven and npm packages, run:

```shell
GH_SOURCE_PAT="<GH_SOURCE_PAT>" \
GH_SOURCE_ORG="<GH_SOURCE_ORG>" \
GH_SOURCE_REPO="<GH_SOURCE_REPO>" \
GH_TARGET_PAT="<GH_TARGET_PAT>" \
GH_TARGET_ORG="<GH_TARGET_ORG>" \
GH_TARGET_REPO="<GH_TARGET_REPO>" \
./migrate-packages.sh
```

Since migrating packages could take a long time, a Dockerfile has been included in folder `./migrate-packages`, such that the script can easily be run in a cluster.
