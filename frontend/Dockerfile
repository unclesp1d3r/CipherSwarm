# syntax=docker/dockerfile:1
# check=error=true

# SvelteKit Frontend Dockerfile
FROM node:20-slim

# Install pnpm globally and curl for health checks
RUN npm install -g pnpm && \
    apt-get update && apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Set environment variables for build
ENV NODE_OPTIONS="--max_old_space_size=4096"
ENV NODE_ENV=production
ENV PUBLIC_API_BASE_URL=http://localhost:8000
ENV API_BASE_URL=http://localhost:8000
ENV VITE_API_BASE_URL=http://localhost:8000

# Build the application with increased memory
RUN pnpm run build

# Expose port
EXPOSE 5173

# Health check - frontend health depends on backend availability
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:5173/ || exit 1

# Set runtime environment variables (these can be overridden)
ENV PUBLIC_API_BASE_URL=http://backend:8000
ENV API_BASE_URL=http://backend:8000

# Run the SSR application
CMD ["node", "build"] 