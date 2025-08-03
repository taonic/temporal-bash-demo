#!/bin/bash

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo "bats is not installed. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install bats-core
    else
        echo "Please install bats manually:"
        echo "  macOS: brew install bats-core"
        echo "  Linux: apt-get install bats or yum install bats"
        exit 1
    fi
fi

if ! grpcurl -plaintext localhost:7233 list > /dev/null 2>&1; then
    echo "Starting Temporal server..."
    temporal server start-dev --dynamic-config-value history.defaultWorkflowTaskTimeout=30 &
    sleep 3
fi

# Run the tests
echo "Running bash script tests..."
bats --verbose-run e2e.bats
