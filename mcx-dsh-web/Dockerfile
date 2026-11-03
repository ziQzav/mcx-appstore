# syntax=docker/dockerfile:1
# dsh-web plugin pack layered on top of the maintained community base image
# smanx/deepseek-harness (Docker Hub, ~190k pulls). The base already ships
# node 24, dsh 0.2.1-rc.5, the dev tools (git, build-essential, python3, uv),
# pnpm and a proxy that runs dsh on loopback and publishes 0.0.0.0:3080 with
# launch-token auto-login, Host rewriting and WS/gzip handling.
#
# Digest pin: devtools-0.2.1-rc.5 @ 2026-11-03, amd64 manifest.
ARG BASE_IMAGE=smanx/deepseek-harness:devtools-0.2.1-rc.5@sha256:c4385a722f7177dd6646578fb78fcae1f0704ad85ea02b517fafc306b524c976

FROM ${BASE_IMAGE} AS plugin

ARG PLUGIN_VERSION=0.4.14

# Build the web profile template with the plugin pack mounted. dsh-web needs
# three native builds (ssh2, cpu-features, cloudflared) that pnpm 10 refuses by
# default, and its packages are newer than the profile's minimumReleaseAge, so
# both have to be allowed before "dsh plugin add" runs.
ENV DSH_HOME=/opt/dsh-template
RUN dsh --profile web --dump-config > /dev/null \
    && printf '\nallowBuilds:\n  cloudflared: true\n  cpu-features: true\n  ssh2: true\n\nminimumReleaseAgeExclude:\n  - "@linxin666/*"\n' \
        >> /opt/dsh-template/profiles/web/pnpm-workspace.yaml \
    && dsh plugin --profile web add "@linxin666/dsh-web-all@${PLUGIN_VERSION}"

FROM ${BASE_IMAGE}

COPY --from=plugin /opt/dsh-template /opt/dsh-template
COPY entrypoint.sh /usr/local/bin/mcx-dsh-web-entrypoint.sh
RUN chmod 0755 /usr/local/bin/mcx-dsh-web-entrypoint.sh \
    && mkdir -p /data /workspace

ENV DSH_HOME=/data \
    DSH_TELEMETRY_DISABLED=1 \
    DSH_PORT=3079 \
    PROXY_PORT=3080

WORKDIR /workspace
EXPOSE 3080

ENTRYPOINT ["/usr/local/bin/mcx-dsh-web-entrypoint.sh"]
