FROM debian:buster-slim as builder
RUN apt-get update && \
    apt-get install -y gcc make libc6-dbg afl++ && \
    rm -rf /var/lib/apt/lists/*
COPY . .
RUN make

ENTRYPOINT []
CMD /fuzzgoat @@
