#!/bin/bash

highlight() {
  echo -e "\033[1m$1\033[0m"
}

TIMELINE_STEP=0

show_timeline() {
  local steps=("Start Workflow" "Poll Workflow Task" "Schedule Activity" "Poll Activity" "Complete Activity" "Poll Workflow Task" "Complete Workflow" "Get Result")
  
  echo
  for i in "${!steps[@]}"; do
    [ "$i" -eq "$TIMELINE_STEP" ] && echo -ne "\033[36m[${steps[$i]}]\033[0m" || echo -n "${steps[$i]}"
    [ "$i" -lt $((${#steps[@]} - 1)) ] && echo -n " → "
  done
  echo
  echo
  TIMELINE_STEP=$((TIMELINE_STEP + 1))
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
  clear
  echo "🚀 StartWorkflowExecution"
  echo "┌────────┐                     ┌────────┐"
  echo "│ Worker │ ──Start Workflow──> │ Server │"
  echo "└────────┘                     └────────┘"
  show_timeline

  terminate_existing_workflow
  WORKFLOW_ID="bash-demo"
  echo "Generated workflow ID: $WORKFLOW_ID"
  echo

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
  echo "Request: $(highlight StartWorkflowExecution):"
  echo "$START_PAYLOAD" | jq -C .
  echo
  START_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$START_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/StartWorkflowExecution)

  echo "Response: $(highlight StartWorkflowExecutionResponse):"
  echo "$START_RESPONSE" | jq -C .
  echo
  pause
}

poll_workflow_task() {
  clear
  echo "┌────────┐                         ┌────────┐"
  echo "│ Client │ <──Poll Workflow Task── │ Server │"
  echo "└────────┘                         └────────┘"
  show_timeline

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
  echo "Request: $(highlight PollWorkflowTaskQueue):"
  echo "$POLL_PAYLOAD" | jq -C .
  echo
  POLL_RESPONSE=$(grpcurl \
    -plaintext \
    -max-time 30 \
    -d "$POLL_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/PollWorkflowTaskQueue)

  echo "Response: $(highlight PollWorkflowTaskQueueResponse):"
  # Show truncated response to fit on screen
  POLL_LINES=$(echo "$POLL_RESPONSE" | jq -C . | wc -l)
  if [ "$POLL_LINES" -gt 20 ]; then
    echo "$POLL_RESPONSE" | jq -C . | head -10
    echo "  ... (truncated $((POLL_LINES - 30)) lines) ..."
    echo "$POLL_RESPONSE" | jq -C . | tail -30
  else
    echo "$POLL_RESPONSE" | jq -C .
  fi
  echo
  pause

  TASK_TOKEN=$(echo "$POLL_RESPONSE" | jq -r '.taskToken // ""')
}

respond_workflow_task() {
  clear
  local task_token="$1"
  echo "┌────────┐                              ┌────────┐"
  echo "│ Worker │ ──Completed Workflow Task──> │ Server │"
  echo "└────────┘                              └────────┘"
  show_timeline

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
  echo "Request: $(highlight RespondWorkflowTaskCompleted):"
  echo "$RESPOND_PAYLOAD" | jq -C .
  echo -e "\033[33mNote: 'encoding' and 'data' fields are base64 encoded:\033[0m"
  echo -e "  \033[33mencoding: $(echo -n 'json/plain' | base64) -> 'json/plain'\033[0m"
  echo -e "  \033[33mdata: $(echo "{\"name\": \"$NAME\"}" | base64 | tr -d '\n') -> '{\"name\": \"$NAME\"}'\033[0m"
  echo
  RESPOND_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$RESPOND_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/RespondWorkflowTaskCompleted)

  echo "Response: $(highlight RespondWorkflowTaskCompletedResponse):"
  echo "$RESPOND_RESPONSE" | jq -C .
  echo
  pause
}

poll_activity_task() {
  clear
  echo "┌────────┐                    ┌────────┐"
  echo "│ Worker │ <──Poll Activity── │ Server │"
  echo "└────────┘                    └────────┘"
  show_timeline

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
  echo "Request: $(highlight PollActivityTaskQueue):"
  echo "$ACTIVITY_POLL_PAYLOAD" | jq -C .
  echo
  ACTIVITY_RESPONSE=$(grpcurl \
    -plaintext \
    -max-time 30 \
    -d "$ACTIVITY_POLL_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/PollActivityTaskQueue)

  echo "Response: $(highlight PollActivityTaskQueueResponse):"
  echo "$ACTIVITY_RESPONSE" | jq -C .
  echo
  pause

  ACTIVITY_TOKEN=$(echo "$ACTIVITY_RESPONSE" | jq -r '.taskToken // ""')
}

respond_activity_task() {
  clear
  local activity_token="$1"
  echo "┌────────┐                         ┌────────┐"
  echo "│ Worker │ ──Completed Activity──> │ Server │"
  echo "└────────┘                         └────────┘"
  show_timeline
  
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
  echo "Request: $(highlight RespondActivityTaskCompleted):"
  echo "$ACTIVITY_RESPOND_PAYLOAD" | jq -C .
  echo -e "\033[33mNote: The Activity concatenates the string. As the result, the 'data' field is '{\"message\":\"Hello $NAME!\"}' and base64 encoded into: $(echo -n "{\"message\":\"Hello $NAME!\"}" | base64)\033[0m"
  echo
  ACTIVITY_RESPOND_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$ACTIVITY_RESPOND_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/RespondActivityTaskCompleted)

  echo "Response: $(highlight RespondActivityTaskCompletedResponse):"
  echo "$ACTIVITY_RESPOND_RESPONSE" | jq -C .
  echo
  pause
}

complete_workflow() {
  clear
  local task_token="$1"
  echo "┌────────┐                         ┌────────┐"
  echo "│ Worker │ ──Completed Workflow──> │ Server │"
  echo "└────────┘                         └────────┘"
  show_timeline

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
  echo "Request: $(highlight RespondWorkflowTaskCompleted):"
  echo "$FINAL_RESPOND_PAYLOAD" | jq -C .
  echo -e "\033[33mNote: 'data' field is base64 encoded: $(echo -n "{\"message\":\"Hello $NAME!\"}" | base64) -> '{\"message\":\"Hello $NAME!\"}'\033[0m"
  echo
  FINAL_RESPOND_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$FINAL_RESPOND_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/RespondWorkflowTaskCompleted)

  echo "Response: $(highlight RespondWorkflowTaskCompletedResponse):"
  echo "$FINAL_RESPOND_RESPONSE" | jq -C .
  echo
  pause
}

get_workflow_history() {
  clear
  echo "┌────────┐                      ┌────────┐"
  echo "│ Client │ <──Workflow Result── │ Server │"
  echo "└────────┘                      └────────┘"
  show_timeline

  HISTORY_PAYLOAD=$(cat <<EOF
{
  "namespace": "default",
  "execution": {
    "workflow_id": "$WORKFLOW_ID"
  }
}
EOF
)
  echo "Request: $(highlight GetWorkflowExecutionHistory):"
  echo "$HISTORY_PAYLOAD" | jq -C .
  echo
  HISTORY_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$HISTORY_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/GetWorkflowExecutionHistory)

  echo "Response: $(highlight GetWorkflowExecutionHistoryResponse):"
  # Show truncated response to fit on screen
  HISTORY_LINES=$(echo "$HISTORY_RESPONSE" | jq -C . | wc -l)
  if [ "$HISTORY_LINES" -gt 40 ]; then
    echo "$HISTORY_RESPONSE" | jq -C . | head -5
    echo "  ... (truncated $((HISTORY_LINES - 40)) lines) ..."
    echo "$HISTORY_RESPONSE" | jq -C . | tail -22
  else
    echo "$HISTORY_RESPONSE" | jq -C .
  fi

  # Extract and decode workflow result payload
  PAYLOAD_DATA=$(echo "$HISTORY_RESPONSE" | jq -r '.history.events[] | select(.eventType == "EVENT_TYPE_WORKFLOW_EXECUTION_COMPLETED") | .workflowExecutionCompletedEventAttributes.result.payloads[0].data // ""')
  if [ -n "$PAYLOAD_DATA" ]; then
    echo
    echo "🎁 Workflow Result:"
    echo "$PAYLOAD_DATA" | base64 -d | jq -C
  fi
  echo
  echo "🌐 View workflow in Temporal Web UI:"
  echo "http://localhost:8233/namespaces/default/workflows/$WORKFLOW_ID"
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
  echo
  echo
}

# Execute workflow
restart_temporal_server
setup_name "$1"
start_workflow
poll_workflow_task
respond_workflow_task "$TASK_TOKEN"
poll_activity_task
respond_activity_task "$ACTIVITY_TOKEN"
poll_workflow_task
complete_workflow "$TASK_TOKEN"
get_workflow_history
