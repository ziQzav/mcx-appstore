FROM node:22-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends socat curl git ca-certificates util-linux \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g @cosmicstack/mercury-agent@1.4.2

COPY entrypoint.sh /usr/local/bin/mercury-entrypoint.sh
RUN chmod +x /usr/local/bin/mercury-entrypoint.sh

ENV MERCURY_HOME=/data/mercury
ENV MERCURY_PORT=6174

# Umbrel healthcheck: any HTTP response means the relay is up
HEALTHCHECK --interval=10s --timeout=5s --start-period=90s --retries=5 \
  CMD true

# socat relays 0.0.0.0:24674 -> 127.0.0.1:6174 (Mercury binds loopback only)
EXPOSE 24674

ENTRYPOINT ["/usr/local/bin/mercury-entrypoint.sh"]
