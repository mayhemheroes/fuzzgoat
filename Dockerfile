FROM ubuntu:22.04 AS builder
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y gcc make libc6-dbg afl++ && \
    rm -rf /var/lib/apt/lists/*
COPY . .
RUN make

ENTRYPOINT []
CMD /fuzzgoat @@
