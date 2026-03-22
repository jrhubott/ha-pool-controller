# =============================================================================
# Stage 1: Build nodejs-poolController from source
# =============================================================================
FROM node:20-bookworm-slim AS controller-build

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone the controller repo at a pinned version
ARG NJSPC_VERSION=8.3.0
RUN git clone --depth 1 --branch "v${NJSPC_VERSION}" \
    https://github.com/tagyoureit/nodejs-poolController.git .

# Apply any patches from the patches/ directory
COPY patches/ /tmp/patches/
RUN if ls /tmp/patches/*.patch 1>/dev/null 2>&1; then \
      echo "Applying patches..." && \
      git apply /tmp/patches/*.patch; \
    else \
      echo "No patches to apply."; \
    fi

# Install all dependencies, build TypeScript, then prune dev deps
RUN npm ci && npm run build && npm prune --production

# =============================================================================
# Stage 2: Reference dashPanel pre-built image (used only as a COPY source)
# =============================================================================
FROM ghcr.io/rstrouse/njspc-dash:latest AS dashpanel

# =============================================================================
# Stage 3: Final Home Assistant add-on image
# =============================================================================
ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install Node.js 20 from NodeSource and jq for config patching
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    jq \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Copy built controller from Stage 1
COPY --from=controller-build /build/dist /app/njspc/dist
COPY --from=controller-build /build/node_modules /app/njspc/node_modules
COPY --from=controller-build /build/package.json /app/njspc/package.json
COPY --from=controller-build /build/defaultConfig.json /app/njspc/defaultConfig.json
COPY --from=controller-build /build/web /app/njspc/web

# Copy dashPanel from Stage 2
COPY --from=dashpanel /app /app/dashpanel

# Create runtime directories (persistent data goes under /data, symlinked at startup)
RUN mkdir -p \
    /data/njspc \
    /data/dashpanel \
    /app/njspc/logs \
    /app/njspc/backups \
    /app/dashpanel/logs \
    /app/dashpanel/backups

# Copy s6-overlay service definitions and init scripts
COPY rootfs /
