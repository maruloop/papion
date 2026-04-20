FROM ghcr.io/moonbitlang/moon:latest AS builder

RUN apt-get update && apt-get install -y libcurl4-openssl-dev libarchive-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY core/ core/
WORKDIR /src/core

RUN moon update && MOON_CC=clang moon build --release --target native

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y libcurl4 libarchive13 ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/core/_build/native/release/build/cli/cli.exe /usr/local/bin/papion

ENTRYPOINT ["papion"]
