FROM alpine/kubectl:latest AS kubectl

FROM golang:alpine AS envsubst-build

# Build envsubst from Go
RUN apk add --no-cache git && \
    CGO_ENABLED=0 go install github.com/a8m/envsubst/cmd/envsubst@latest

FROM node:alpine AS build-env

# Update all packages to latest
RUN apk update && apk upgrade --no-cache

# Install build dependencies
RUN apk add --no-cache git yarn

# Build config-merge from source (it's a Node.js tool)
RUN git clone https://github.com/boxboat/config-merge.git /tmp/config-merge && \
    cd /tmp/config-merge && \
    yarn install && \
    mkdir -p /usr/local/config-merge && \
    cp config-merge.js source.sh package.json wrapper.sh /usr/local/config-merge/ && \
    ln -s /usr/local/config-merge/wrapper.sh /usr/local/bin/config-merge && \
    rm -rf /tmp/config-merge /root/.cache /root/.yarn

FROM alpine:latest

# Update all packages to latest
RUN apk update && apk upgrade --no-cache

# Install packages available from Alpine repos
RUN apk add --no-cache \
  bash \
  busybox \
  curl \
  gettext \
  jq \
  lz4 \
  nodejs \
  npm \
  wget \
  zstd-dev

# Copy envsubst from build stage (works for any architecture)
COPY --from=envsubst-build /go/bin/envsubst /usr/local/bin/envsubst

# Copy config-merge from build stage
COPY --from=build-env /usr/local/config-merge /usr/local/config-merge
COPY --from=build-env /usr/local/bin/config-merge /usr/local/bin/config-merge
RUN cd /usr/local/config-merge && npm install --production && rm -rf /root/.npm

# Create symlink for busybox at /busybox/busybox for compatibility with existing consumers
RUN mkdir -p /busybox && ln -s /bin/busybox /busybox/busybox

# Copy kubectl from alpine/kubectl image
COPY --from=kubectl /usr/local/bin/kubectl /usr/local/bin/kubectl