# syntax=docker/dockerfile:1.7
# Commit-image build for fuzzgoat — builds ON TOP of the org C/C++ base image, which already provides
# clang/llvm + libFuzzer + the build-contract ENV. This only adds the per-commit build.
FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
# SOURCE_DATE_EPOCH stays an ARG (available to build.sh); an empty ENV value breaks clang.
ARG SOURCE_DATE_EPOCH
# Declare SANITIZER_FLAGS WITHOUT a default so the base ENV flows through unless overridden.
ARG SANITIZER_FLAGS
ARG COVERAGE_FLAGS=
ARG MAYHEM_JOBS=

USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
