FROM docker.io/library/eclipse-temurin:11-focal
#FROM ubuntu:20.04

# Install wget
RUN (type -p wget >/dev/null || (apt update && apt-get install wget -y))

# Install Maven
ARG MAVEN_VERSION=3.8.8
RUN wget https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz -P /tmp \
    && tar xf /tmp/apache-maven-*.tar.gz -C /opt \
    && ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven
ENV M2_HOME=/opt/maven
ENV MAVEN_HOME=/opt/maven
RUN ln -s /opt/maven/bin/mvn /usr/local/bin/mvn

# Install curl + gpg
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install npm
RUN mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && NODE_MAJOR=20 \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
  && apt update \
  && apt install nodejs -y

# Install gh
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update \
    && apt install gh -y

# Install jq
RUN apt install jq -y

# Set user
RUN adduser runner
USER runner
WORKDIR /home/runner

# Copy files
COPY ./migrate-packages.sh .
COPY ./settings.xml.tpl .
COPY ./package.json .

ENTRYPOINT ./migrate-packages.sh