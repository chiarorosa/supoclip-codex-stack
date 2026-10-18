# syntax=docker/dockerfile:1.7
#
# openai-oauth (EvanZhouDev/openai-oauth) pinned to the exact commit that was
# code-reviewed on 2026-10-18.  Serves an OpenAI-compatible API backed by a
# ChatGPT subscription login that lives ONLY in the `codex_auth` volume.

# ---- build: fetch the pinned commit, install with the frozen lockfile, compile
FROM oven/bun:1 AS build
ADD https://github.com/EvanZhouDev/openai-oauth.git#9079e62840a7f4b19114cb8f4bb0009b5bcf1773 /app
WORKDIR /app
ENV TURBO_TELEMETRY_DISABLED=1 DO_NOT_TRACK=1
RUN bun install --frozen-lockfile \
 && bunx turbo run build --filter=openai-oauth \
 && rm -rf apps

# ---- runtime: node (the CLI declares node >= 20) + the official Codex CLI,
# used only to perform the login inside this container.
FROM node:24-slim
# The Codex CLI is a Rust binary that validates TLS against the SYSTEM trust store
# (node bundles its own CAs, so node:slim ships without them).  Without this the
# login fails with "error sending request for url (https://auth.openai.com/...)".
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN npm install -g @openai/codex@0.163.0 && npm cache clean --force
ENV CODEX_HOME=/data/codex NODE_ENV=production
RUN mkdir -p /data/codex && chown -R node:node /data
COPY --from=build --chown=node:node /app /app
USER node
WORKDIR /app
EXPOSE 10531
# 0.0.0.0 is needed so other containers can reach it.  There is NO `ports:` entry
# in the compose file, so it is reachable only on the private compose network.
CMD ["node", "packages/openai-oauth/dist/cli.js", "--host", "0.0.0.0", "--port", "10531"]
