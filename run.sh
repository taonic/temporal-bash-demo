#!/bin/bash

# Handle --interactive flag
if [ "$1" = "--interactive" ]; then
  read -p "Enter your name: " NAME
  NAME=${NAME:-"World"}
else
  NAME="World"
fi
echo "Using name: $NAME"

pause() {
  read -n 1 -s -r -p "Press any key to continue..."
  echo
  echo
}

start_workflow() {
  echo "🚀 Next operation: StartWorkflowExecution" >&2
  START_PAYLOAD=$(cat <<EOF
{
  "namespace": "default",
  "workflow_id": "test-workflow",
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
  echo "$START_PAYLOAD" | jq -C .  >&2
  START_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$START_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/StartWorkflowExecution)

  echo "StartWorkflowExecution response:"  >&2
  echo "$START_RESPONSE" | jq -C .
}

poll_workflow_task() {
  echo "📥 Next operation: PollWorkflowTaskQueue" >&2
  pause

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
  POLL_RESPONSE=$(grpcurl \
    -plaintext \
    -max-time 30 \
    -d "$POLL_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/PollWorkflowTaskQueue)

  echo "PollWorkflowTaskQueue response:" >&2
  echo "$POLL_RESPONSE" | jq -C . >&2
  echo "$POLL_RESPONSE" | jq -r '.taskToken // ""'
}

respond_workflow_task() {
  local task_token="$1"
  echo "📝 Next operation: RespondWorkflowTaskCompleted (schedule activity)" >&2
  pause

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
  RESPOND_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$RESPOND_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/RespondWorkflowTaskCompleted)

  echo "RespondWorkflowTaskCompleted response:" >&2
  echo "$RESPOND_RESPONSE" | jq -C .
}

poll_activity_task() {
  echo "🔄 Next operation: PollActivityTaskQueue" >&2
  pause

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
  ACTIVITY_RESPONSE=$(grpcurl \
    -plaintext \
    -max-time 30 \
    -d "$ACTIVITY_POLL_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/PollActivityTaskQueue)

  echo "PollActivityTaskQueue response:" >&2
  echo "$ACTIVITY_RESPONSE" | jq -C . >&2
  echo "$ACTIVITY_RESPONSE" | jq -r '.taskToken // ""'
}

respond_activity_task() {
  local activity_token="$1"
  echo "✅ Next operation: RespondActivityTaskCompleted" >&2
  pause
  
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
  ACTIVITY_RESPOND_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$ACTIVITY_RESPOND_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/RespondActivityTaskCompleted)

  echo "RespondActivityTaskCompleted response:" >&2
  echo "$ACTIVITY_RESPOND_RESPONSE" | jq -C . >&2
}

complete_workflow() {
  local task_token="$1"
  echo "🏁 Next operation: RespondWorkflowTaskCompleted (complete workflow)" >&2
  pause

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
  FINAL_RESPOND_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$FINAL_RESPOND_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/RespondWorkflowTaskCompleted)

  echo "RespondWorkflowTaskCompleted (final) response:" >&2
  echo "$FINAL_RESPOND_RESPONSE" | jq -C .
}

get_workflow_history() {
  echo "📜 Next operation: GetWorkflowExecutionHistory" >&2
  pause

  HISTORY_PAYLOAD=$(cat <<EOF
{
  "namespace": "default",
  "execution": {
    "workflow_id": "test-workflow"
  }
}
EOF
)
  HISTORY_RESPONSE=$(grpcurl \
    -plaintext \
    -d "$HISTORY_PAYLOAD" \
    localhost:7233 \
    temporal.api.workflowservice.v1.WorkflowService/GetWorkflowExecutionHistory)

  echo "GetWorkflowExecutionHistory response:"  >&2
  echo "$HISTORY_RESPONSE" | jq -C .  >&2

  # Extract and decode workflow result payload
  PAYLOAD_DATA=$(echo "$HISTORY_RESPONSE" | jq -r '.history.events[] | select(.eventType == "EVENT_TYPE_WORKFLOW_EXECUTION_COMPLETED") | .workflowExecutionCompletedEventAttributes.result.payloads[0].data // ""')
  if [ -n "$PAYLOAD_DATA" ]; then
    echo "Decoded workflow result:" >&2
    echo "$PAYLOAD_DATA" | base64 -d >&2
  fi
}

# Execute workflow
start_workflow
token=$(poll_workflow_task)
respond_workflow_task "$token"
token=$(poll_activity_task)
respond_activity_task "$token"
token=$(poll_workflow_task)
complete_workflow "$token"
get_workflow_history
