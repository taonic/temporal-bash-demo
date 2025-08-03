#!/bin/bash

highlight() {
  echo -e "\033[1m$1\033[0m"
}

setup_name() {
  if [ "$1" = "-i" ]; then
    read -p "Enter your name: " NAME
    NAME=${NAME:-"World"}
  else
    NAME="World"
  fi
  echo "Using name: $NAME"
  echo
}

terminate_existing_workflow() {
  TERMINATE_PAYLOAD=$(cat <<EOF
{
  "namespace": "default",
  "workflow_execution": {
    "workflow_id": "bash-demo"
  },
  "reason": "Starting new demo"
}
EOF
)
  grpcurl -plaintext -d "$TERMINATE_PAYLOAD" localhost:7233 temporal.api.workflowservice.v1.WorkflowService/TerminateWorkflowExecution > /dev/null 2>&1
}

start_workflow() {
  clear >&2
  echo "🚀 StartWorkflowExecution" >&2
  echo "┌────────┐          ┌────────┐" >&2
  echo "│ Worker │ -Start-> │ Server │" >&2
  echo "└────────┘          └────────┘" >&2
  echo >&2

  terminate_existing_workflow
  WORKFLOW_ID="bash-demo"
  echo "Generated workflow ID: $WORKFLOW_ID" >&2
  echo >&2

  START_PAYLOAD=$(cat <<EOF
{
  "namespace": "default",
  "workflow_id": "$WORKFLOW_ID",
  "workflow_type": {
    "name": "TestWorkflow"
  },
  "task_queue": {
    "name": "test-queue"
  },
  "input": {
    "payloads": [{
      "metadata": {
        "encoding": "anNvbi9wbGFpbg=="
      },
      "data": "$(echo "{\"name\": \"$NAME\"}" | base64)"
    }]
  }
}
EOF
)
  echo "Request: $(highlight StartWorkflowExecution):" >&2
  echo "$START_PAYLOAD" | jq -C .  >&2
  echo >&2
  START_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$START_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/StartWorkflowExecution)

  echo "Response: $(highlight StartWorkflowExecutionResponse):" >&2
  echo "$START_RESPONSE" | jq -C . >&2
  echo >&2
  pause
}

poll_workflow_task() {
  clear >&2
  echo "📥 PollWorkflowTaskQueue" >&2
  echo "┌────────┐         ┌────────┐" >&2
  echo "│ Client │ <-Poll- │ Server │" >&2
  echo "└────────┘         └────────┘" >&2
  echo >&2

  POLL_PAYLOAD=$(cat <<EOF
{
  "namespace": "default",
  "task_queue": {
    "name": "test-queue"
  },
  "identity": "test-worker"
}
EOF
)
  echo "Request: $(highlight PollWorkflowTaskQueue):" >&2
  echo "$POLL_PAYLOAD" | jq -C .  >&2
  echo >&2
  POLL_RESPONSE=$(grpcurl \
    -plaintext \
    -max-time 30 \
    -d "$POLL_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/PollWorkflowTaskQueue)

  echo "Response: $(highlight PollWorkflowTaskQueueResponse):" >&2
  # Show truncated response to fit on screen
  POLL_LINES=$(echo "$POLL_RESPONSE" | jq -C . | wc -l)
  if [ "$POLL_LINES" -gt 20 ]; then
    echo "$POLL_RESPONSE" | jq -C . | head -10 >&2
    echo "  ... (truncated $((POLL_LINES - 30)) lines) ..." >&2
    echo "$POLL_RESPONSE" | jq -C . | tail -30 >&2
  else
    echo "$POLL_RESPONSE" | jq -C . >&2
  fi
  echo >&2
  pause

  echo "$POLL_RESPONSE" | jq -r '.taskToken // ""'
}

respond_workflow_task() {
  clear >&2
  local task_token="$1"
  echo "✅ RespondWorkflowTaskCompleted (schedule activity)" >&2
  echo "┌────────┐                   ┌────────┐" >&2
  echo "│ Worker │ -Completed Task-> │ Server │" >&2
  echo "└────────┘                   └────────┘" >&2
  echo >&2

  RESPOND_PAYLOAD=$(cat <<EOF
{
  "identity": "test-worker",
  "task_token": "$(echo $task_token | tr -d '\n')",
  "commands": [{
    "command_type": "COMMAND_TYPE_SCHEDULE_ACTIVITY_TASK",
    "schedule_activity_task_command_attributes": {
      "activity_id": "test-activity",
      "activity_type": {
        "name": "TestActivity"
      },
      "task_queue": {
        "name": "test-queue"
      },
      "start_to_close_timeout": "30s",
      "input": {
        "payloads": [{
          "metadata": {
            "encoding": "anNvbi9wbGFpbg=="
          },
          "data": "$(echo "{\"name\": \"$NAME\"}" | base64 | tr -d '\n')"
        }]
      }
    }
  }]
}
EOF
)
  echo "Request: $(highlight RespondWorkflowTaskCompleted):" >&2
  echo "$RESPOND_PAYLOAD" | jq -C .  >&2
  echo -e "\033[33mNote: 'encoding' and 'data' fields are base64 encoded:\033[0m" >&2
  echo -e "  \033[33mencoding: $(echo -n 'json/plain' | base64) -> 'json/plain'\033[0m" >&2
  echo -e "  \033[33mdata: $(echo "{\"name\": \"$NAME\"}" | base64 | tr -d '\n') -> '{\"name\": \"$NAME\"}'\033[0m" >&2
  echo >&2
  RESPOND_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$RESPOND_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/RespondWorkflowTaskCompleted)

  echo "Response: $(highlight RespondWorkflowTaskCompletedResponse):" >&2
  echo "$RESPOND_RESPONSE" | jq -C . >&2
  echo >&2
  pause
}

poll_activity_task() {
  clear >&2
  echo "📥 PollActivityTaskQueue" >&2
  echo "┌────────┐         ┌────────┐" >&2
  echo "│ Worker │ <-Poll- │ Server │" >&2
  echo "└────────┘         └────────┘" >&2
  echo >&2

  ACTIVITY_POLL_PAYLOAD=$(cat <<EOF
{
  "namespace": "default",
  "task_queue": {
    "name": "test-queue"
  },
  "identity": "test-worker"
}
EOF
)
  echo "Request: $(highlight PollActivityTaskQueue):" >&2
  echo "$ACTIVITY_POLL_PAYLOAD" | jq -C .  >&2
  echo  >&2
  ACTIVITY_RESPONSE=$(grpcurl \
    -plaintext \
    -max-time 30 \
    -d "$ACTIVITY_POLL_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/PollActivityTaskQueue)

  echo "Response: $(highlight PollActivityTaskQueueResponse):" >&2
  echo "$ACTIVITY_RESPONSE" | jq -C . >&2
  echo >&2
  pause

  echo "$ACTIVITY_RESPONSE" | jq -r '.taskToken // ""'
}

respond_activity_task() {
  clear >&2
  local activity_token="$1"
  echo "✅ RespondActivityTaskCompleted" >&2
  echo "┌────────┐                   ┌────────┐" >&2
  echo "│ Worker │ -Completed Task-> │ Server │" >&2
  echo "└────────┘                   └────────┘" >&2
  echo >&2
  
  ACTIVITY_RESPOND_PAYLOAD=$(cat <<EOF
{
  "identity": "test-worker",
  "task_token": "$(echo $activity_token | tr -d '\n')",
  "result": {
    "payloads": [{
      "metadata": {
        "encoding": "$(echo -n 'json/plain' | base64)"
      },
      "data": "$(echo -n "{\"message\":\"Hello $NAME!\"}" | base64)"
    }]
  }
}
EOF
)
  echo "Request: $(highlight RespondActivityTaskCompleted):" >&2
  echo "$ACTIVITY_RESPOND_PAYLOAD" | jq -C .  >&2
  echo -e "\033[33mNote: 'data' field is base64 encoded: $(echo -n "{\"message\":\"Hello $NAME!\"}" | base64) -> '{\"message\":\"Hello $NAME!\"}'\033[0m" >&2
  echo >&2
  ACTIVITY_RESPOND_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$ACTIVITY_RESPOND_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/RespondActivityTaskCompleted)

  echo "Response: $(highlight RespondActivityTaskCompletedResponse):" >&2
  echo "$ACTIVITY_RESPOND_RESPONSE" | jq -C . >&2
  echo >&2
  pause
}

complete_workflow() {
  clear >&2
  local task_token="$1"
  echo "✅ RespondWorkflowTaskCompleted" >&2
  echo "┌────────┐                       ┌────────┐" >&2
  echo "│ Worker │ -Completed Workflow-> │ Server │" >&2
  echo "└────────┘                       └────────┘" >&2
  echo

  FINAL_RESPOND_PAYLOAD=$(cat <<EOF
{
  "identity": "test-worker",
  "task_token": "$(echo $task_token | tr -d '\n')",
  "commands": [{
    "command_type": "COMMAND_TYPE_COMPLETE_WORKFLOW_EXECUTION",
    "complete_workflow_execution_command_attributes": {
      "result": {
        "payloads": [{
          "metadata": {
            "encoding": "$(echo -n 'json/plain' | base64)"
          },
          "data": "$(echo -n "{\"message\":\"Hello $NAME!\"}" | base64)"
        }]
      }
    }
  }]
}
EOF
)
  echo "Request: $(highlight RespondWorkflowTaskCompleted):" >&2
  echo "$FINAL_RESPOND_PAYLOAD" | jq -C .  >&2
  echo
  FINAL_RESPOND_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$FINAL_RESPOND_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/RespondWorkflowTaskCompleted)

  echo "Response: $(highlight RespondWorkflowTaskCompletedResponse):" >&2
  echo "$FINAL_RESPOND_RESPONSE" | jq -C . >&2
  echo >&2
}

get_workflow_history() {
  clear >&2
  echo "🎁 GetWorkflowExecutionHistory (For client to get the result back)" >&2
  echo "┌────────┐           ┌────────┐" >&2
  echo "│ Client │ <-Result- │ Server │" >&2
  echo "└────────┘           └────────┘" >&2
  echo

  HISTORY_PAYLOAD=$(cat <<EOF
{
  "namespace": "default",
  "execution": {
    "workflow_id": "$WORKFLOW_ID"
  }
}
EOF
)
  echo "Request: $(highlight GetWorkflowExecutionHistory):" >&2
  echo "$HISTORY_PAYLOAD" | jq -C .  >&2
  echo
  HISTORY_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$HISTORY_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/GetWorkflowExecutionHistory)

  echo "Response: $(highlight GetWorkflowExecutionHistoryResponse):"  >&2
  # Show truncated response to fit on screen
  HISTORY_LINES=$(echo "$HISTORY_RESPONSE" | jq -C . | wc -l)
  if [ "$HISTORY_LINES" -gt 40 ]; then
    echo "$HISTORY_RESPONSE" | jq -C . | head -5 >&2
    echo "  ... (truncated $((HISTORY_LINES - 40)) lines) ..." >&2
    echo "$HISTORY_RESPONSE" | jq -C . | tail -22 >&2
  else
    echo "$HISTORY_RESPONSE" | jq -C . >&2
  fi

  # Extract and decode workflow result payload
  PAYLOAD_DATA=$(echo "$HISTORY_RESPONSE" | jq -r '.history.events[] | select(.eventType == "EVENT_TYPE_WORKFLOW_EXECUTION_COMPLETED") | .workflowExecutionCompletedEventAttributes.result.payloads[0].data // ""')
  if [ -n "$PAYLOAD_DATA" ]; then
    echo
    echo "🎁 Workflow Result:" >&2
    echo "$PAYLOAD_DATA" | base64 -d | jq -C >&2
  fi
  echo
  echo "🌐 View workflow in Temporal Web UI:" >&2
  echo "http://localhost:8233/namespaces/default/workflows/$WORKFLOW_ID" >&2
}

check_server_config() {
  # Check if server is running with extended timeout by looking at process args
  if pgrep -f "temporal server start-dev.*defaultWorkflowTaskTimeout" >/dev/null 2>&1; then
    return 0  # Already configured
  else
    return 1  # Needs restart
  fi
}

restart_temporal_server() {
  if check_server_config; then
    echo "✅ Temporal server already running with extended task timeout."
    echo
    return
  fi
  echo "⚠️ Restarting Temporal server with extended task timeout for demo..."
  echo "This ensures workflow tasks don't timeout during manual step-through."
  echo
  read -p "Press 'y' to continue: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Demo cancelled."
    exit 1
  fi
  echo
  
  # Kill existing server
  pkill -f "temporal server start-dev" 2>/dev/null
  sleep 2
  temporal server start-dev --dynamic-config-value history.defaultWorkflowTaskTimeout=30 &
  while ! grpcurl -plaintext localhost:7233 list >/dev/null 2>&1; do
    sleep 1
  done
  echo "✅ Temporal server is ready!"
  echo
}

pause() {
  read -n 1 -s -r -p "Press any key to continue..."
  echo >&2
  echo >&2
}

# Execute workflow
restart_temporal_server
setup_name "$1"
start_workflow
token=$(poll_workflow_task)
respond_workflow_task "$token"
token=$(poll_activity_task)
respond_activity_task "$token"
token=$(poll_workflow_task)
complete_workflow "$token"
get_workflow_history
