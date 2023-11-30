# syntax = docker/dockerfile:latest

FROM debian:bookworm as base

ARG LANGUAGETOOL_VERSION=6.2
ARG TARGETARCH
LABEL maintainer='modem7'

FROM base AS base-amd64

FROM base AS base-arm64

FROM base-${TARGETARCH}${TARGETVARIANT} as build

ENV DEBIAN_FRONTEND=noninteractive

RUN <<EOF
    set -x
    if [ "$TARGETARCH" = "arm64" ]
    then
        echo "Installing additional packages for ARM"
        apt-get update -y
        apt-get install -y \
        build-essential    \
        cmake              \
        mercurial          \
        texlive            \
        wget               \
        zip
    else
        echo "Not installing ARM packages"
    fi
EOF

RUN <<EOF
    set -x
    apt-get update -y
    apt-get install -y          \
        bash                    \
        libgomp1                \
        locales                 \
        maven                   \
        openjdk-17-jdk-headless \
        unzip                   \
        xmlstarlet
EOF

RUN <<EOF
    set -x
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    dpkg-reconfigure --frontend=noninteractive locales
    update-locale LANG=en_US.UTF-8
EOF

ENV LANG en_US.UTF-8

ARG LANGUAGETOOL_VERSION
ADD --link --keep-git-dir=true https://github.com/languagetool-org/languagetool.git#v${LANGUAGETOOL_VERSION} /languagetool

WORKDIR /languagetool

RUN <<EOF
    set -x
    mvn --projects languagetool-standalone --also-make package -DskipTests -Daether.dependencyCollector.impl=bf --quiet
    LANGUAGETOOL_DIST_VERSION=$(xmlstarlet sel -N "x=http://maven.apache.org/POM/4.0.0" -t -v "//x:project/x:properties/x:revision" pom.xml)
    unzip /languagetool/languagetool-standalone/target/LanguageTool-${LANGUAGETOOL_DIST_VERSION}.zip -d /dist
    LANGUAGETOOL_DIST_FOLDER=$(find /dist/ -name 'LanguageTool-*')
    mv $LANGUAGETOOL_DIST_FOLDER /dist/LanguageTool
EOF

# Execute workarounds for ARM64 architectures.
# https://github.com/languagetool-org/languagetool/issues/4543
WORKDIR /

COPY arm64-workaround/bridj.sh arm64-workaround/bridj.sh
COPY arm64-workaround/hunspell.sh arm64-workaround/hunspell.sh

RUN <<EOF
    set -x
    if [ "$TARGETARCH" = "arm64" ]
    then
        echo "Implementing ARM workarounds"
        chmod +x arm64-workaround/bridj.sh
        bash -c "arm64-workaround/bridj.sh"
        chmod +x arm64-workaround/hunspell.sh
        bash -c "arm64-workaround/hunspell.sh"
    else
        echo "Not implementing ARM workarounds"
    fi
EOF

WORKDIR /languagetool

# Note: When changing the base image, verify that the hunspell.sh workaround is
# downloading the matching version of `libhunspell`. The URL may need to change.
FROM alpine:3.18.4

RUN <<EOF
    set -x
    apk add --no-cache \
        bash           \
        curl           \
        libc6-compat   \
        libstdc++      \
        openjdk17-jre-headless
EOF

# https://github.com/Erikvl87/docker-languagetool/issues/60
RUN <<EOF
    set -x
    ln -s /lib64/ld-linux-x86-64.so.2 /lib/ld-linux-x86-64.so.2
    addgroup -S languagetool && adduser -S languagetool -G languagetool
EOF

COPY --chown=languagetool --from=build /dist .

WORKDIR /LanguageTool

RUN <<EOF
    set -x
    mkdir /nonexistent
    touch /nonexistent/.languagetool.cfg
EOF

COPY --chown=languagetool start.sh config.properties .

USER languagetool

EXPOSE 8010

HEALTHCHECK --timeout=10s --start-period=5s CMD curl --fail --data "language=en-US&text=a simple test" http://localhost:8010/v2/check || exit 1

CMD [ "bash", "start.sh" ]
