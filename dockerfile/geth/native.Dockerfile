ARG BASE_VERSION
FROM golang:${BASE_VERSION} AS build-env

RUN apk update && apk upgrade --no-cache && \
    apk add --update --no-cache busybox && \
    apk add --update --no-cache binutils binutils-gold curl make git libc-dev bash gcc linux-headers eudev-dev ncurses-dev git-lfs g++ libstdc++

ARG CLONE_KEY

RUN if [ ! -z "${CLONE_KEY}" ]; then\
        mkdir -p ~/.ssh;\
        echo "${CLONE_KEY}" | base64 -d > ~/.ssh/id_ed25519;\
        chmod 600 ~/.ssh/id_ed25519;\
        apk add openssh;\
        git config --global --add url."ssh://git@github.com/".insteadOf "https://github.com/";\
        ssh-keyscan github.com >> ~/.ssh/known_hosts;\
    fi

ARG TARGETARCH
ARG BUILDARCH
ARG GITHUB_ORGANIZATION
ARG REPO_HOST

WORKDIR /go/src/${REPO_HOST}/${GITHUB_ORGANIZATION}

ARG GITHUB_REPO
ARG VERSION
ARG BUILD_TIMESTAMP
ARG SKIP_LFS

# Conditionally skip LFS smudging during clone if SKIP_LFS is set.
RUN if [ ! -z "${SKIP_LFS}" ]; then \
      GIT_LFS_SKIP_SMUDGE=1 git clone -b ${VERSION} --single-branch https://${REPO_HOST}/${GITHUB_ORGANIZATION}/${GITHUB_REPO}.git --recursive; \
    else \
      git clone -b ${VERSION} --single-branch https://${REPO_HOST}/${GITHUB_ORGANIZATION}/${GITHUB_REPO}.git --recursive \
      && cd ${GITHUB_REPO} \
      && git lfs install && git lfs pull; \
    fi

WORKDIR /go/src/${REPO_HOST}/${GITHUB_ORGANIZATION}/${GITHUB_REPO}

ARG BUILD_TARGET
ARG BUILD_ENV
ARG BUILD_TAGS
ARG PRE_BUILD
ARG BUILD_DIR

RUN set -eux;\
    export ARCH=$(uname -m);\
    export CGO_ENABLED=1 LDFLAGS='-linkmode external -extldflags "-static"';\
    if [ ! -z "$PRE_BUILD" ]; then sh -c "${PRE_BUILD}"; fi;\
    if [ ! -z "$BUILD_TARGET" ]; then\
      if [ ! -z "$BUILD_ENV" ]; then export ${BUILD_ENV}; fi;\
      if [ ! -z "$BUILD_TAGS" ]; then export "${BUILD_TAGS}"; fi;\
      if [ ! -z "$BUILD_DIR" ]; then cd "${BUILD_DIR}"; fi;\
      sh -c "${BUILD_TARGET}";\
    fi

# Copy all binaries to /root/bin, for a single place to copy into final image.
# If a colon (:) delimiter is present, binary will be renamed to the text after the delimiter.
RUN mkdir /root/bin
ARG RACE
ARG BINARIES
ENV BINARIES_ENV ${BINARIES}
RUN bash -c 'set -eux; \
  BINARIES_ARR=(); \
  IFS=, read -ra BINARIES_ARR <<< "$BINARIES_ENV"; \
  for BINARY in "${BINARIES_ARR[@]}"; do \
    BINSPLIT=(); \
    IFS=: read -ra BINSPLIT <<< "$BINARY"; \
    BINPATH=${BINSPLIT[1]+"${BINSPLIT[1]}"}; \
    BIN="$(eval "echo "${BINSPLIT[0]+"${BINSPLIT[0]}"}"")"; \
    if [ ! -z "$RACE" ] && GOVERSIONOUT=$(go version -m $BIN); then \
      if echo $GOVERSIONOUT | grep build | grep "-race=true"; then \
        echo "Race detection is enabled in binary"; \
      else \
        echo "Race detection not enabled in binary!"; \
        exit 1; \
      fi; \
    fi; \
    if [ ! -z "$BINPATH" ]; then \
      if [[ $BINPATH == *"/"* ]]; then \
        mkdir -p "$(dirname "${BINPATH}")"; \
        cp "$BIN" "${BINPATH}"; \
      else \
        cp "$BIN" "/root/bin/${BINPATH}"; \
      fi; \
    else \
      cp "$BIN" /root/bin/; \
    fi; \
  done'

RUN mkdir -p /root/lib
ARG LIBRARIES
ENV LIBRARIES_ENV ${LIBRARIES}
RUN bash -c 'set -eux; \
  LIBRARIES_ARR=($LIBRARIES_ENV); for LIBRARY in "${LIBRARIES_ARR[@]}"; do cp $LIBRARY /root/lib/; done'

# Copy over directories
RUN mkdir -p /root/dir_abs && touch /root/dir_abs.list
ARG DIRECTORIES
ENV DIRECTORIES_ENV ${DIRECTORIES}
RUN bash -c 'set -eux; \
  DIRECTORIES_ARR=($DIRECTORIES_ENV); \
  i=0; \
  for DIRECTORY in "${DIRECTORIES_ARR[@]}"; do \
    cp -R $DIRECTORY /root/dir_abs/$i; \
    echo $DIRECTORY >> /root/dir_abs.list; \
    ((i = i + 1)); \
  done'

# Build final image
FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/p2p-org/cosmos-heighliner"

RUN apk add --no-cache ca-certificates jq bash

WORKDIR /bin

# Copy over absolute path directories
COPY --from=build-env /root/dir_abs /root/dir_abs
COPY --from=build-env /root/dir_abs.list /root/dir_abs.list

# Move absolute path directories to their absolute locations.
RUN sh -c 'i=0; [ -f /root/dir_abs.list ] && while read DIR; do \
      echo "$i: $DIR"; \
      PLACEDIR="$(dirname "$DIR")"; \
      mkdir -p "$PLACEDIR"; \
      mv /root/dir_abs/$i $DIR; \
      i=$((i+1)); \
    done < /root/dir_abs.list || true'

# Install chain binaries
COPY --from=build-env /root/bin /bin

# Install libraries
COPY --from=build-env /root/lib /usr/lib

RUN addgroup --gid 1111 -S p2p && adduser --uid 1111 -S p2p -G p2p
WORKDIR /home/p2p
RUN chown -R p2p:p2p /home/p2p
USER p2p
