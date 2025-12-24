#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${CONFIG_PATH:-.github/project-board-config.json}"
OKR_DEFS_PATH="${OKR_DEFS_PATH:-.github/okr-definitions.md}"

PROJECT_ID=$(jq -r '.project.id' "$CONFIG_PATH")
OKR_OBJECTIVE_FIELD_ID=$(jq -r '.fields.okr_objective.id' "$CONFIG_PATH")
OKR_KEY_RESULT_FIELD_ID=$(jq -r '.fields.okr_key_result.id' "$CONFIG_PATH")

LOCK_LABEL=$(jq -r '.labels.automation_locked' "$CONFIG_PATH")
OKR_REVIEW_LABEL=$(jq -r '.labels.okr_review' "$CONFIG_PATH")

GRAPHQL_ENDPOINT_QUERY='mutation($input: AddProjectV2ItemByIdInput!){ addProjectV2ItemById(input:$input){ item { id } } }'

graphql() {
  local query=$1
  local variables_json=$2
  jq -n --arg query "$query" --argjson variables "$variables_json" '{query: $query, variables: $variables}' | gh api graphql --input -
}

add_item_to_project() {
  local content_id=$1
  local variables
  variables=$(jq -n --arg projectId "$PROJECT_ID" --arg contentId "$content_id" '{input:{projectId:$projectId, contentId:$contentId}}')
  graphql "$GRAPHQL_ENDPOINT_QUERY" "$variables" | jq -r '.data.addProjectV2ItemById.item.id'
}

update_field() {
  local item_id=$1
  local field_id=$2
  local option_id=$3

  local update_query='mutation($input: UpdateProjectV2ItemFieldValueInput!){ updateProjectV2ItemFieldValue(input:$input){ projectV2Item { id } } }'
  local update_vars
  update_vars=$(jq -n --arg projectId "$PROJECT_ID" --arg itemId "$item_id" --arg fieldId "$field_id" --arg optionId "$option_id" '{input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}}')
  graphql "$update_query" "$update_vars" >/dev/null
}

main() {
  local issue_number issue_node_id issue_title issue_body repo labels_json
  issue_number=$(jq -r '.issue.number // empty' "$GITHUB_EVENT_PATH")
  issue_node_id=$(jq -r '.issue.node_id // empty' "$GITHUB_EVENT_PATH")
  issue_title=$(jq -r '.issue.title // empty' "$GITHUB_EVENT_PATH")
  issue_body=$(jq -r '.issue.body // empty' "$GITHUB_EVENT_PATH")
  repo=$(jq -r '.repository.full_name // empty' "$GITHUB_EVENT_PATH")
  labels_json=$(jq -c '.issue.labels | map(.name)' "$GITHUB_EVENT_PATH" 2>/dev/null || echo '[]')

  if [ -z "$issue_number" ] || [ -z "$issue_node_id" ]; then
    exit 0
  fi

  local has_lock
  has_lock=$(jq -r --argjson labels "$labels_json" --arg lock "$LOCK_LABEL" '$labels | index($lock) != null' <<< "")
  if [ "$has_lock" = "true" ]; then
    exit 0
  fi

  if [ -z "${GEMINI_API_KEY:-}" ]; then
    gh issue edit "$issue_number" --repo "$repo" --add-label "$OKR_REVIEW_LABEL" >/dev/null
    exit 0
  fi

  local item_id
  item_id=$(add_item_to_project "$issue_node_id")

  local okr_definitions
  okr_definitions=$(cat "$OKR_DEFS_PATH")

  cat > /tmp/gemini_request.json << 'PAYLOAD_EOF'
{
  "systemInstruction": {
    "role": "system",
    "parts": [
      {
        "text": "You are the lead product manager for Goast. Assign the single most relevant OKR objective and key result. Write in UK English, plain language. No emojis. No markdown symbols. Keep the rationale short and clear."
      }
    ]
  },
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": ""
        }
      ]
    }
  ],
  "generationConfig": {
    "responseMimeType": "application/json",
    "responseSchema": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "okr_objective": {
          "type": "string",
          "enum": ["OKR 1", "OKR 2", "OKR 3", "OKR 4"],
          "description": "Most relevant OKR objective",
          "examples": ["OKR 2"]
        },
        "okr_key_result": {
          "type": "string",
          "enum": [
            "KR 1.1","KR 1.2","KR 1.3","KR 1.4",
            "KR 2.1","KR 2.2","KR 2.3","KR 2.4","KR 2.5",
            "KR 3.1","KR 3.2","KR 3.3","KR 3.4",
            "KR 4.1","KR 4.2","KR 4.3","KR 4.4"
          ],
          "description": "Most relevant key result",
          "examples": ["KR 2.3"]
        },
        "rationale": {
          "type": "string",
          "description": "Short explanation of the match",
          "examples": ["This change affects decision speed, so it maps to decision velocity."]
        },
        "confidence": {
          "type": "number",
          "description": "Confidence from 0 to 1",
          "examples": [0.74]
        }
      },
      "required": ["okr_objective", "okr_key_result", "rationale", "confidence"]
    }
  }
}
PAYLOAD_EOF

  USER_PROMPT=$(cat << PROMPT_EOF
You are assigning OKRs for the Goast public roadmap.

OKR definitions:
${okr_definitions}

Issue title: ${issue_title}
Issue labels: ${labels_json}
Issue body:
${issue_body}

Return JSON that matches the schema exactly.
PROMPT_EOF
  )

  jq --arg user "$USER_PROMPT" '.contents[0].parts[0].text = $user' /tmp/gemini_request.json > /tmp/gemini_request_final.json

  HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/gemini_response.json \
    -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent" \
    -H "Content-Type: application/json" \
    -H "x-goog-api-key: ${GEMINI_API_KEY}" \
    -d @/tmp/gemini_request_final.json)

  if [ "$HTTP_CODE" != "200" ]; then
    gh issue edit "$issue_number" --repo "$repo" --add-label "$OKR_REVIEW_LABEL" >/dev/null
    exit 0
  fi

  GENERATED=$(jq -r '.candidates[0].content.parts[0].text // empty' /tmp/gemini_response.json)
  if [ -z "$GENERATED" ] || ! echo "$GENERATED" | jq . >/dev/null 2>&1; then
    gh issue edit "$issue_number" --repo "$repo" --add-label "$OKR_REVIEW_LABEL" >/dev/null
    exit 0
  fi

  CONFIDENCE=$(echo "$GENERATED" | jq -r '.confidence // empty')
  if [ -z "$CONFIDENCE" ] || awk "BEGIN{exit !($CONFIDENCE < 0.7)}"; then
    gh issue edit "$issue_number" --repo "$repo" --add-label "$OKR_REVIEW_LABEL" >/dev/null
    exit 0
  fi

  OKR_OBJECTIVE=$(echo "$GENERATED" | jq -r '.okr_objective')
  OKR_KEY_RESULT=$(echo "$GENERATED" | jq -r '.okr_key_result')

  OKR_OBJECTIVE_OPTION=$(jq -r --arg value "$OKR_OBJECTIVE" '.fields.okr_objective.options[$value]' "$CONFIG_PATH")
  OKR_KEY_RESULT_OPTION=$(jq -r --arg value "$OKR_KEY_RESULT" '.fields.okr_key_result.options[$value]' "$CONFIG_PATH")

  update_field "$item_id" "$OKR_OBJECTIVE_FIELD_ID" "$OKR_OBJECTIVE_OPTION"
  update_field "$item_id" "$OKR_KEY_RESULT_FIELD_ID" "$OKR_KEY_RESULT_OPTION"

  gh issue edit "$issue_number" --repo "$repo" --remove-label "$OKR_REVIEW_LABEL" >/dev/null 2>&1 || true
}

main "$@"
