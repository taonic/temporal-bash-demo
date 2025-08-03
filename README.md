# Temporal Bash Demo

A demo of Temporal workflow execution using pure bash and gRPC calls.

## Overview

<a href="https://asciinema.org/a/CNx6PUlOehsMGkv0Jtaya09kK"><img src="demo.gif" alt="Demo" autoplay loop></a>

This demo implements a complete but simple Temporal workflow lifecycle using bash scripts and `grpcurl`. It includes:

- Starting a workflow execution
- Polling for workflow tasks
- Scheduling and executing activities
- Completing workflows
- Retrieving workflow history and results

## Prerequisites

- **Temporal CLI**: For running Temporal Server
- **grpcurl**: For making gRPC calls
- **jq**: For JSON processing

### Installation

```bash
# Install Temporal CLI
curl -sSf https://temporal.download/cli.sh | sh

# macOS
brew install grpcurl jq

# Ubuntu/Debian
apt-get install grpcurl jq

# Or install grpcurl from: https://github.com/fullstorydev/grpcurl
```

### Start Temporal Server

```bash
temporal server start-dev
```

## Usage

### Interactive Mode
```bash
./run.sh -i
```
Prompts for a name input and runs the complete workflow demo.

### Default Mode
```bash
./run.sh
```
Runs the demo with "World" as the default name.

## Testing

Run the test suite:

```bash
cd tests
./test.sh
```

## Example Output

```
🚀 StartWorkflowExecution
┌────────┐          ┌────────┐
│ Worker │ -Start-> │ Server │
└────────┘          └────────┘

Generated workflow ID: bash-demo

Request: StartWorkflowExecution:
{
  "namespace": "default",
  "workflow_id": "bash-demo",
  "workflow_type": {
    "name": "TestWorkflow"
  },
  ...
}
```
