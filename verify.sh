#!/usr/bin/env bash
# Official BAR Widget Verification Script
set -e

CONTAINER_CMD=""
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo "Error: Neither podman nor docker found on system."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$PROJECT_DIR/build"

echo "Running official BAR Workshop Builder validation via $CONTAINER_CMD..."

$CONTAINER_CMD run --rm \
    -v "$PROJECT_DIR/build:/app/build:z" \
    -v "$PROJECT_DIR:/app/Widgets:ro,z" \
    ghcr.io/beyond-all-reason/bar-workshop-builder:latest

echo "Verification completed successfully."
