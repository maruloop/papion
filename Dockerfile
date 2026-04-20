FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y \
  curl tar xz-utils wget git jq binutils ca-certificates \
  libcurl4-openssl-dev libarchive-dev \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.moon/bin
RUN curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash

ENV PATH="/root/.moon/bin:${PATH}"

RUN moon version --all

WORKDIR /src
COPY core/ core/
WORKDIR /src/core

RUN moon update && moon build --release --target native

FROM ubuntu:24.04

RUN apt-get update && apt-get install -y libcurl4 libarchive13 ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/core/_build/native/release/build/cli/cli.exe /usr/local/bin/papion

ENTRYPOINT ["papion"]
