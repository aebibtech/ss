# Use the official Bun image
FROM oven/bun:1.1-slim as base
WORKDIR /usr/src/app

# Install dependencies into temp directory to cache them
FROM base AS install
RUN mkdir -p /temp/dev
COPY package.json bun.lock /temp/dev/
RUN cd /temp/dev && bun install --frozen-lockfile

RUN mkdir -p /temp/prod
COPY package.json bun.lock /temp/prod/
RUN cd /temp/prod && bun install --frozen-lockfile --production

# Copy dependencies and source code
FROM base AS prerelease
COPY --from=install /temp/dev/node_modules node_modules
COPY . .

# Final release stage
FROM base AS release
COPY --from=install /temp/prod/node_modules node_modules
COPY --from=prerelease /usr/src/app/ .

# Expose port and run the service
USER bun
EXPOSE 8080
ENV PORT=8080
ENTRYPOINT [ "bun", "run", "index.ts" ]
