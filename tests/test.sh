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

# Run the tests
echo "Running bash script tests..."
bats e2e.bats
