#!/usr/bin/env bats

setup_file() {
  # Terminate existing workflow if it exists
  grpcurl -plaintext -d '{"namespace":"default","workflow_execution":{"workflow_id":"bash-demo"},"reason":"Test cleanup"}' localhost:7233 temporal.api.workflowservice.v1.WorkflowService/TerminateWorkflowExecution > /dev/null 2>&1 || true
}

@test "workflow is started and visible in Temporal" {
  run timeout 10 bash -c 'printf "TestUser\n" | ../run.sh -i'
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKFLOW_EXECUTION_STATUS_RUNNING"* ]]
}

@test "e2e to verify final result" {
  run timeout 10 bash -c 'printf "TestUser\n\n\n\n\n\n\n" | ../run.sh -i'

  [ "$status" -eq 0 ]
  [[ "$output" == *"Using name: TestUser"* ]]
  [[ "$output" == *"Hello TestUser!"* ]]
}
