FROM lukemathwalker/cargo-chef:latest-rust-1.81.0-bookworm AS build-env

RUN apt update && apt install -y libssl-dev openssl libclang-dev clang cmake libstdc++6
RUN if [ "$(uname -m)" = "aarch64" ]; then\
  wget https://github.com/protocolbuffers/protobuf/releases/download/v21.8/protoc-21.8-linux-aarch_64.zip;\
  unzip protoc-21.8-linux-aarch_64.zip -d /usr;\
  elif [ "${TARGETARCH}" = "amd64" ]; then\
  wget https://github.com/protocolbuffers/protobuf/releases/download/v21.8/protoc-21.8-linux-x86_64.zip;\
  unzip protoc-21.8-linux-x86_64.zip -d /usr;\
  fi

ARG GITHUB_ORGANIZATION
ARG REPO_HOST

WORKDIR /build

ARG GITHUB_REPO
ARG VERSION
ARG BUILD_TIMESTAMP

RUN git clone -b ${VERSION} --single-branch https://${REPO_HOST}/${GITHUB_ORGANIZATION}/${GITHUB_REPO}.git --recursive

WORKDIR /build/${GITHUB_REPO}

ARG BUILD_TARGET
ARG BUILD_DIR

RUN if [ ! -z "$BUILD_TARGET" ]; then\
  if [ ! -z "$BUILD_DIR" ]; then cd "${BUILD_DIR}"; fi;\
  if [ ! -f "Cargo.toml" ]; then exit 0; fi;\
  fi

ARG BUILD_ENV
ARG BUILD_TAGS
ARG PRE_BUILD

# Install go if necessary for project
ARG GO_VERSION
RUN set -eux; \
  export ARCH=$(uname -m);\
  if [ "$ARCH" = "x86_64" ]; then BUILDARCH=amd64; elif [ "$ARCH" = "aarch64" ]; then BUILDARCH=arm64; fi;\
  if [ ! -z "$GO_VERSION" ]; then\
  wget https://go.dev/dl/go${GO_VERSION}.linux-${BUILDARCH}.tar.gz  -O - | tar -C /usr/local -xz;\
  fi

RUN set -eux;\
  if [ ! -z "$GO_VERSION" ]; then export PATH=$PATH:/usr/local/go/bin; fi;\
  export ARCH=$(uname -m);\
  export CARGO_BUILD_TARGET=${ARCH}-unknown-linux-gnu;\
  if [ "$ARCH" = "x86_64" ]; then export BUILDARCH=amd64 TARGETARCH=amd64; elif [ "$ARCH" = "aarch64" ]; then export BUILDARCH=arm64 TARGETARCH=arm64; fi;\
  [ ! -z "$PRE_BUILD" ] && sh -c "${PRE_BUILD}";\
  if [ ! -z "$BUILD_TARGET" ]; then\
  if [ ! -z "$BUILD_ENV" ]; then export ${BUILD_ENV}; fi;\
  if [ ! -z "$BUILD_TAGS" ]; then export "${BUILD_TAGS}"; fi;\
  if [ ! -z "$BUILD_DIR" ]; then cd "${BUILD_DIR}"; fi;\
  sh -c "${BUILD_TARGET}";\
  fi

# Copy all binaries to /root/bin, for a single place to copy into final image.
# If a colon (:) delimiter is present, binary will be renamed to the text after the delimiter.
RUN mkdir /root/bin
ARG BINARIES
ENV BINARIES_ENV ${BINARIES}
RUN bash -c 'set -eux;\
  export ARCH=$(uname -m);\
  echo "bins: $BINARIES_ENV";\
  BINARIES_ARR=();\
  IFS=, read -ra BINARIES_ARR <<< "$BINARIES_ENV";\
  for BINARY in "${BINARIES_ARR[@]}"; do\
  BINSPLIT=();\
  IFS=: read -ra BINSPLIT <<< "$BINARY";\
  BINPATH="${BINSPLIT[1]+"${BINSPLIT[1]}"}";\
  BIN="$(eval "echo "${BINSPLIT[0]+"${BINSPLIT[0]}"}"")";\
  if [ ! -z "$BINPATH" ]; then\
  if [[ $BINPATH == *"/"* ]]; then\
  mkdir -p "$(dirname "${BINPATH}")";\
  cp "$BIN" "${BINPATH}";\
  else\
  cp "$BIN" "/root/bin/${BINPATH}";\
  fi;\
  else\
  cp "$BIN" /root/bin/;\
  fi;\
  done'

RUN mkdir -p /root/lib
ARG LIBRARIES
ENV LIBRARIES_ENV ${LIBRARIES}
RUN bash -c 'set -eux;\
  export ARCH=$(uname -m);\
  LIBRARIES_ARR=($LIBRARIES_ENV); for LIBRARY in "${LIBRARIES_ARR[@]}"; do LIB="$(eval "echo "$LIBRARY"")"; cp $LIB /root/lib/; done'

# Determine shared library dependencies for both bins and libs
RUN mkdir -p /root/lib_abs && touch /root/lib_abs.list
RUN bash -c 'set -eux;\
    export ARCH=$(uname -m);\
    i=0; for BIN in /root/{bin,lib}/*; do\
    echo "Getting $(uname -m) libs for bin: $BIN";\
    readarray -t LIBS < <(ldd "$BIN");\
    for LIB in "${LIBS[@]}"; do\
      PATH1=$(echo $LIB | awk "{print \$1}");\
      if [ "$PATH1" = "linux-vdso.so.1" ]; then continue; fi;\
      PATH2=$(echo $LIB | awk "{print \$3}");\
      PATH3=$(echo $LIB | awk "{print \$4}");\
      if [ "$PATH2" == "not" ] && [ "$PATH3" == "found" ]; then continue; fi;\
      if [ ! -z "$PATH2" ]; then\
        if cat /root/lib_abs.list | grep -x "$PATH2"; then\
          echo "Skipping $PATH2, already accounted for";\
          continue;\
        else\
          echo "Copying lib2: $PATH2";\
          cp -L $PATH2 /root/lib_abs/$i;\
          echo $PATH2 >> /root/lib_abs.list;\
        fi;\
      else\
        if cat /root/lib_abs.list | grep -x "$PATH1"; then\
          echo "Skipping $PATH1, already accounted for";\
          continue;\
        else\
          echo "Copying lib1: $PATH1";\
          cp -L $PATH1 /root/lib_abs/$i;\
          echo $PATH1 >> /root/lib_abs.list;\
        fi;\
      fi;\
      ((i = i + 1));\
    done;\
  done'

ARG TARGET_LIBRARIES
ENV TARGET_LIBRARIES_ENV ${TARGET_LIBRARIES}
RUN bash -c 'set -eux;\
  export ARCH=$(uname -m);\
  i=$(wc -l < /root/lib_abs.list);\
  LIBRARIES_ARR=($TARGET_LIBRARIES_ENV); for LIBRARY in "${LIBRARIES_ARR[@]}"; do LIB="$(eval "echo "$LIBRARY"")";\
    if cat /root/lib_abs.list | grep -x "$LIB"; then\
      echo "Skipping $LIB, already accounted for";\
      continue;\
    else\
      echo "Copying lib2: $LIB";\
      cp -L $LIB /root/lib_abs/$i;\
      echo $LIB >> /root/lib_abs.list;\
      ((i = i + 1));\
    fi;\
  done'

# Copy over directories
RUN mkdir -p /root/dir_abs && touch /root/dir_abs.list
ARG DIRECTORIES
ENV DIRECTORIES_ENV ${DIRECTORIES}
RUN bash -c 'set -eux;\
  DIRECTORIES_ARR=($DIRECTORIES_ENV);\
  i=0;\
  for DIRECTORY in "${DIRECTORIES_ARR[@]}"; do \
    cp -R $DIRECTORY /root/dir_abs/$i;\
    echo $DIRECTORY >> /root/dir_abs.list;\
    ((i = i + 1));\
  done'

# Use minimal busybox from infra-toolkit image for final scratch image
FROM ghcr.io/p2p-org/cosmos-heighliner:infra-toolkit-v0.1.6 AS infra-toolkit
RUN addgroup --gid 1111 -S p2p && adduser --uid 1111 -S p2p -G p2p

# Use ln and rm from full featured busybox for assembling final image
FROM busybox:1.34.1-musl AS busybox-full

# Use alpine to source the latest CA certificates
FROM alpine:3 as alpine-3

# Build final image from scratch
FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/p2p-org/cosmos-heighliner"

ARG FINAL_IMAGE
RUN if [ ! -z "$FINAL_IMAGE" ]; then sh -c "$FINAL_IMAGE"; fi

WORKDIR /bin

# Install jq
COPY --from=infra-toolkit /usr/local/bin/jq /bin/

# Install chain binaries
COPY --from=build-env /root/bin /bin

# Install libraries
COPY --from=build-env /root/lib /lib

# # Install p2p user
# RUN addgroup --gid 1111 -S p2p && adduser --uid 1111 -S p2p -G p2p
# RUN chown 1111:1111 -R /home/p2p
# RUN chown 1111:1111 -R /etc/apk
# RUN chown 1111:1111 -R /tmp

WORKDIR /home/p2p
# USER p2p