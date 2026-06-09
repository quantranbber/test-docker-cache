# =====================================================================
# Stage 1: base — shared env, build args, pinned pnpm via corepack
# =====================================================================
FROM node:24-bullseye AS base

ARG IMAGE_TAG=notagset

ENV IMAGE_TAG=${IMAGE_TAG} \
    NODE_OPTIONS=--max-old-space-size=6000 \
    PNPM_HOME=/root/.local/share/pnpm \
    PATH=/root/.local/share/pnpm:$PATH

WORKDIR /app

RUN corepack enable && corepack prepare pnpm@11.4.0 --activate && pnpm --version


# =====================================================================
# Stage 2: builder — full deps (dev + prod), compile TS
# =====================================================================
FROM base AS builder

# Pin the pnpm store to a fixed path so the prod-deps stage can COPY it
# and re-install fully offline (no registry calls = no flaky network).
ENV PNPM_STORE_DIR=/pnpm-store

# Copy dependency manifests + patches first so the install layer
# is cached as long as dependencies don't change.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.json ./
RUN pnpm install --frozen-lockfile --store-dir=${PNPM_STORE_DIR}

# Copy full source after deps are installed
COPY . .
RUN pnpm run build


# =====================================================================
# Stage 3: runtime
# =====================================================================
FROM builder AS runtime

COPY . .

# Run the app
CMD ["node", "dist/index.js"]
