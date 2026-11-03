# syntax=docker/dockerfile:1
# DeepSeek Harness (dsh) web profile with the dsh-web plugin pack preinstalled.
FROM node:24-bookworm-slim AS build

ARG DSH_VERSION=0.2.1-rc.5
ARG PLUGIN_VERSION=0.4.14

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# pnpm is required by "dsh plugin"; the dsh install needs its own build scripts allowed.
# No corepack here: its pnpm shim collides with the npm-installed pnpm.
RUN npm install -g pnpm@10 --no-fund --no-audit \
    && npm install -g "@deepseek-ai/dsh@${DSH_VERSION}" --no-fund --no-audit \
        --allow-scripts=@deepseek-ai/dsh-subprocess-local,node-pty,koffi,@google/genai,protobufjs

ENV DSH_HOME=/opt/dsh-template

# Initialize the web profile, then allow the three native builds dsh-web's plugin
# needs BEFORE adding it (pnpm rejects them by default, and a retry after the fact
# mounts nothing).
RUN dsh --profile web --dump-config > /dev/null \
    && printf '\nallowBuilds:\n  cloudflared: true\n  cpu-features: true\n  ssh2: true\n\nminimumReleaseAgeExclude:\n  - "@linxin666/*"\n' \
        >> /opt/dsh-template/profiles/web/pnpm-workspace.yaml \
    && dsh plugin --profile web add "@linxin666/dsh-web-all@${PLUGIN_VERSION}"

FROM node:24-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash git curl ca-certificates \
        python3 python3-pip python3-venv \
        build-essential jq ripgrep unzip zip ffmpeg less procps gosu \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

COPY --from=build /usr/local/ /usr/local/
COPY --from=build /opt/dsh-template /opt/dsh-template
COPY entrypoint.sh /usr/local/bin/dsh-web-entrypoint.sh
RUN chmod 0755 /usr/local/bin/dsh-web-entrypoint.sh

ENV DSH_HOME=/data
WORKDIR /workspace
EXPOSE 3080

ENTRYPOINT ["/usr/local/bin/dsh-web-entrypoint.sh"]
