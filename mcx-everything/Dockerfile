# Builds all Puter "everything" apps (src/<app>) from the upstream monorepo
# at a pinned commit and serves them from one nginx container.

FROM node:22-bookworm-slim AS build
RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ARG EVERYTHING_REF
RUN git clone --depth 1 https://github.com/HeyPuter/everything.git /src
RUN test -n "$EVERYTHING_REF" && test "$(cd /src && git rev-parse HEAD)" = "$EVERYTHING_REF"

COPY build-apps.sh /build-apps.sh
COPY hub.html /tmp/hub-template.html
RUN chmod +x /build-apps.sh && /build-apps.sh

FROM nginx:1.27-alpine
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/everything.conf
COPY --from=build /src/customHttp.yml /etc/nginx/customHttp.yml

# Stage every app that produced a dist/ under /usr/share/nginx/html/apps/<name>/
COPY --from=build /src/src/ /src-src/
RUN mkdir -p /usr/share/nginx/html/apps \
  && for d in /src-src/*/; do \
       app=$(basename "$d"); \
       if [ -d "$d/dist" ]; then \
         mkdir -p "/usr/share/nginx/html/apps/$app"; \
         cp -a "$d/dist/." "/usr/share/nginx/html/apps/$app/"; \
         for i in icon-128.png icon.png; do \
           if [ -f "$d/$i" ]; then cp "$d/$i" "/usr/share/nginx/html/apps/$app/.icon.png"; break; fi; \
         done; \
       fi; \
     done \
  && rm -rf /src-src \
  && ls /usr/share/nginx/html/apps
COPY --from=build /tmp/hub-final.html /usr/share/nginx/html/index.html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
CMD ["nginx", "-g", "daemon off;"]
