#!/usr/bin/env bash
set -euo pipefail

# Install required apt packages
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    python3.13 python3.13-venv python3.13-dev \
    gcc g++ make curl git docker.io

# Install Node.js 20 if not present
if ! command -v node >/dev/null || ! node -v | grep -q '^v20'; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Ensure pnpm is available
sudo npm install -g pnpm

# Install just if missing
if ! command -v just >/dev/null; then
    curl -LsSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
fi

# Install uv if missing
if ! command -v uv >/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | bash
fi

# Sync Python dependencies
uv sync --dev

# Install frontend dependencies
if [ -d "frontend" ]; then
    pushd frontend >/dev/null
    pnpm install
    popd >/dev/null
fi

# Install pre-commit hooks
uv run pre-commit install --hook-type commit-msg
