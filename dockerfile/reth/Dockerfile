# Reth Dockerfile (based on cargo/geth patterns)
FROM --platform=$BUILDPLATFORM rust:1-bullseye AS build-env

RUN rustup component add rustfmt

ARG TARGETARCH
ARG BUILDARCH
ENV TARGETARCH ${TARGETARCH}

RUN if [ "${TARGETARCH}" = "arm64" ]; then\
  rustup target add aarch64-unknown-linux-gnu;\
  wget https://github.com/protocolbuffers/protobuf/releases/download/v21.8/protoc-21.8-linux-aarch_64.zip;\
  unzip protoc-21.8-linux-aarch_64.zip -d /usr;\
  if [ "${BUILDARCH}" != "arm64" ]; then\
  dpkg --add-architecture arm64;\
  apt update && apt install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu;\
  ln -s /usr/aarch64-linux-gnu/include/bits /usr/include/bits;\
  ln -s /usr/aarch64-linux-gnu/include/sys /usr/include/sys;\
  ln -s /usr/aarch64-linux-gnu/include/gnu /usr/include/gnu;\
  else\
  apt update;\
  fi;\
  apt install -y libssl1.1:arm64 libssl-dev:arm64 openssl:arm64 libclang-dev clang cmake libstdc++6:arm64;\
  elif [ "${TARGETARCH}" = "amd64" ]; then\
  rustup target add x86_64-unknown-linux-gnu;\
  wget https://github.com/protocolbuffers/protobuf/releases/download/v21.8/protoc-21.8-linux-x86_64.zip;\
  unzip protoc-21.8-linux-x86_64.zip -d /usr;\
  if [ "${BUILDARCH}" != "amd64" ]; then\
  dpkg --add-architecture amd64; apt update;\
  apt update && apt install -y gcc-x86_64-linux-gnu g++-x86_64-linux-gnu;\
  ln -s /usr/x86_64-linux-gnu/include/bits /usr/include/bits;\
  ln -s /usr/x86_64-linux-gnu/include/sys /usr/include/sys;\
  ln -s /usr/x86_64-linux-gnu/include/gnu /usr/include/gnu;\
  else\
  apt update;\
  fi;\
  apt install -y libssl1.1:amd64 libssl-dev:amd64 openssl:amd64 libclang-dev clang cmake libstdc++6:amd64;\
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
  if [ -f "Cargo.toml" ]; then\
  if [ "$TARGETARCH" = "arm64" ] && [ "$BUILDARCH" != "arm64" ]; then\
  cargo fetch --target aarch64-unknown-linux-gnu;\
  elif [ "$TARGETARCH" = "amd64" ] && [ "$BUILDARCH" != "amd64" ]; then\
  cargo fetch --target x86_64-unknown-linux-gnu;\
  else\
  cargo fetch;\
  fi;\
  fi;\
  fi

ARG BUILD_ENV
ARG BUILD_TAGS
ARG PRE_BUILD

ENV BUILDARCH=$BUILDARCH
ENV TARGETARCH=$TARGETARCH

RUN set -eux;\
  if [ "$TARGETARCH" = "arm64" ]; then export ARCH=aarch64 CAPS=AARCH64;\
  elif [ "$TARGETARCH" = "amd64" ]; then export ARCH=x86_64 CAPS=x86_64; fi;\
  export CARGO_BUILD_TARGET=${ARCH}-unknown-linux-gnu;\
  if [ "$TARGETARCH" != "$BUILDARCH" ]; then\
  export CARGO_TARGET_${CAPS}_UNKNOWN_LINUX_GNU_LINKER=${ARCH}-linux-gnu-gcc\
  CC_${ARCH}_unknown_linux_gnu=${ARCH}-linux-gnu-gcc\
  CXX_${ARCH}_unknown_linux_gnu=${ARCH}-linux-gnu-g++\
  PKG_CONFIG_SYSROOT_DIR=/usr/${ARCH}-linux-gnu;\
  fi;\
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
  if [ "${TARGETARCH}" = "arm64" ]; then export ARCH=aarch64;\
  elif [ "${TARGETARCH}" = "amd64" ]; then export ARCH=x86_64; fi;\
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
  if [ "${TARGETARCH}" = "arm64" ]; then export ARCH=aarch64;\
  elif [ "${TARGETARCH}" = "amd64" ]; then export ARCH=x86_64; fi;\
  LIBRARIES_ARR=($LIBRARIES_ENV); for LIBRARY in "${LIBRARIES_ARR[@]}"; do LIB="$(eval "echo "$LIBRARY"")"; cp $LIB /root/lib/; done'

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

# Use alpine to source the latest CA certificates
FROM alpine:latest AS alpine-3
RUN apk add --no-cache ca-certificates

# Build final image from scratch
FROM scratch

LABEL org.opencontainers.image.source="https://github.com/p2p-org/cosmos-heighliner"

WORKDIR /bin

# Install ln (for making hard links), rm (for cleanup), mv, mkdir, vi and dirname from full busybox image
COPY --from=infra-toolkit /busybox/full/ln /bin/ln
COPY --from=infra-toolkit /busybox/full/rm /bin/rm
COPY --from=infra-toolkit /busybox/full/mv /bin/mv
COPY --from=infra-toolkit /busybox/full/mkdir /bin/mkdir
COPY --from=infra-toolkit /busybox/full/vi /bin/vi
COPY --from=infra-toolkit /busybox/full/dirname /bin/dirname

# Install minimal busybox image as shell binary (will create hardlinks for the rest)
COPY --from=infra-toolkit /busybox/busybox /bin/sh

# Install jq
COPY --from=infra-toolkit /usr/local/bin/jq /bin/

# Add hard links for read-only utils
RUN for b in \
  cat \
  date \
  df \
  du \
  env \
  grep \
  head \
  less \
  ls \
  md5sum \
  pwd \
  sha1sum \
  sha256sum \
  sha3sum \
  sha512sum \
  sleep \
  stty \
  tail \
  tar \
  tee \
  tr \
  watch \
  which \
  ; do ln sh $b; done

# Copy over absolute path directories
COPY --from=build-env /root/dir_abs /root/dir_abs
COPY --from=build-env /root/dir_abs.list /root/dir_abs.list

# Move absolute path directories to their absolute locations
RUN sh -c 'i=0; while read DIR; do\
      echo "$i: $DIR";\
      PLACEDIR="$(dirname "$DIR")";\
      mkdir -p "$PLACEDIR";\
      mv /root/dir_abs/$i $DIR;\
      i=$((i+1));\
    done < /root/dir_abs.list'

RUN rm dirname

# Install chain binaries
COPY --from=build-env /root/bin /bin

# Install libraries
COPY --from=build-env /root/lib /usr/lib

# Install heighliner user
COPY --from=infra-toolkit /etc/passwd /etc/passwd
COPY --from=infra-toolkit --chown=1111:1111 /home/p2p /home/p2p

# Install trusted CA certificates
COPY --from=alpine-3 /etc/ssl/cert.pem /etc/ssl/cert.pem

WORKDIR /home/p2p
# USER p2p
