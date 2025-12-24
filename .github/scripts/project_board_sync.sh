#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${CONFIG_PATH:-.github/project-board-config.json}"

PROJECT_ID=$(jq -r '.project.id' "$CONFIG_PATH")
PROJECT_OWNER=$(jq -r '.project.owner' "$CONFIG_PATH")
PROJECT_NUMBER=$(jq -r '.project.number' "$CONFIG_PATH")

STATUS_FIELD_ID=$(jq -r '.fields.status.id' "$CONFIG_PATH")
PRIORITY_FIELD_ID=$(jq -r '.fields.priority.id' "$CONFIG_PATH")
SIZE_FIELD_ID=$(jq -r '.fields.size.id' "$CONFIG_PATH")
AREA_FIELD_ID=$(jq -r '.fields.area.id' "$CONFIG_PATH")
FEATURE_FIELD_ID=$(jq -r '.fields.feature.id' "$CONFIG_PATH")
RELEASE_FIELD_ID=$(jq -r '.fields.release_phase.id' "$CONFIG_PATH")
OKR_QUARTER_FIELD_ID=$(jq -r '.fields.okr_quarter.id' "$CONFIG_PATH")

LOCK_LABEL=$(jq -r '.labels.automation_locked' "$CONFIG_PATH")
CROSS_AREA_LABEL=$(jq -r '.labels.cross_cutting_area' "$CONFIG_PATH")
CROSS_FEATURE_LABEL=$(jq -r '.labels.cross_cutting_feature' "$CONFIG_PATH")
EXPERIMENT_LABEL=$(jq -r '.labels.experiment' "$CONFIG_PATH")

graphql() {
  local query=$1
  local variables_json=$2
  jq -n --arg query "$query" --argjson variables "$variables_json" '{query: $query, variables: $variables}' | gh api graphql --input -
}

add_item_to_project() {
  local content_id=$1
  local query='mutation($input: AddProjectV2ItemByIdInput!){ addProjectV2ItemById(input:$input){ item { id } } }'
  local variables
  variables=$(jq -n --arg projectId "$PROJECT_ID" --arg contentId "$content_id" '{input:{projectId:$projectId, contentId:$contentId}}')
  graphql "$query" "$variables" | jq -r '.data.addProjectV2ItemById.item.id'
}

update_field() {
  local item_id=$1
  local field_id=$2
  local option_id=$3

  if [ -z "$option_id" ] || [ "$option_id" = "null" ]; then
    local clear_query='mutation($input: ClearProjectV2ItemFieldValueInput!){ clearProjectV2ItemFieldValue(input:$input){ projectV2Item { id } } }'
    local clear_vars
    clear_vars=$(jq -n --arg projectId "$PROJECT_ID" --arg itemId "$item_id" --arg fieldId "$field_id" '{input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId}}')
    graphql "$clear_query" "$clear_vars" >/dev/null
    return
  fi

  local update_query='mutation($input: UpdateProjectV2ItemFieldValueInput!){ updateProjectV2ItemFieldValue(input:$input){ projectV2Item { id } } }'
  local update_vars
  update_vars=$(jq -n --arg projectId "$PROJECT_ID" --arg itemId "$item_id" --arg fieldId "$field_id" --arg optionId "$option_id" '{input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}}')
  graphql "$update_query" "$update_vars" >/dev/null
}

pick_first_label() {
  local labels_json=$1
  local precedence_json=$2
  jq -r --argjson labels "$labels_json" --argjson precedence "$precedence_json" '
    ($precedence | map(select(. as $p | $labels | index($p))) | .[0]) // ""
  '
}

label_count() {
  local labels_json=$1
  local prefix=$2
  jq -r --argjson labels "$labels_json" --arg prefix "$prefix" '[$labels[] | select(startswith($prefix))] | length'
}

ensure_label_state() {
  local repo=$1
  local issue_number=$2
  local label=$3
  local should_have=$4

  if [ "$should_have" = "true" ]; then
    gh issue edit "$issue_number" --repo "$repo" --add-label "$label" >/dev/null
  else
    gh issue edit "$issue_number" --repo "$repo" --remove-label "$label" >/dev/null 2>&1 || true
  fi
}

map_labels_to_fields() {
  local repo=$1
  local issue_number=$2
  local issue_state=$3
  local labels_json=$4
  local item_id=$5

  local has_lock
  has_lock=$(jq -r --argjson labels "$labels_json" --arg lock "$LOCK_LABEL" '$labels | index($lock) != null' <<< "")

  if [ "$has_lock" = "true" ]; then
    return
  fi

  local area_count feature_count
  area_count=$(label_count "$labels_json" "area:")
  feature_count=$(label_count "$labels_json" "feature:")

  local area_label feature_label
  area_label=$(pick_first_label "$labels_json" "$(jq -c '.precedence.area' "$CONFIG_PATH")")
  feature_label=$(pick_first_label "$labels_json" "$(jq -c '.precedence.feature' "$CONFIG_PATH")")

  ensure_label_state "$repo" "$issue_number" "$CROSS_AREA_LABEL" $([ "$area_count" -gt 1 ] && echo true || echo false)
  ensure_label_state "$repo" "$issue_number" "$CROSS_FEATURE_LABEL" $([ "$feature_count" -gt 1 ] && echo true || echo false)

  local priority_label effort_label release_label
  priority_label=$(pick_first_label "$labels_json" "$(jq -c '.precedence.priority' "$CONFIG_PATH")")
  effort_label=$(pick_first_label "$labels_json" "$(jq -c '.precedence.effort' "$CONFIG_PATH")")
  release_label=$(pick_first_label "$labels_json" "$(jq -c '.precedence.release_phase' "$CONFIG_PATH")")

  local area_value feature_value priority_value effort_value release_value
  area_value=$(jq -r --arg label "$area_label" '.label_mappings.area[$label] // empty' "$CONFIG_PATH")
  feature_value=$(jq -r --arg label "$feature_label" '.label_mappings.feature[$label] // empty' "$CONFIG_PATH")
  priority_value=$(jq -r --arg label "$priority_label" '.label_mappings.priority[$label] // empty' "$CONFIG_PATH")
  effort_value=$(jq -r --arg label "$effort_label" '.label_mappings.effort[$label] // empty' "$CONFIG_PATH")
  release_value=$(jq -r --arg label "$release_label" '.label_mappings.release_phase[$label] // empty' "$CONFIG_PATH")

  local area_option feature_option priority_option size_option release_option
  area_option=$(jq -r --arg value "$area_value" '.fields.area.options[$value] // empty' "$CONFIG_PATH")
  feature_option=$(jq -r --arg value "$feature_value" '.fields.feature.options[$value] // empty' "$CONFIG_PATH")
  priority_option=$(jq -r --arg value "$priority_value" '.fields.priority.options[$value] // empty' "$CONFIG_PATH")
  size_option=$(jq -r --arg value "$effort_value" '.fields.size.options[$value] // empty' "$CONFIG_PATH")
  if [ -n "$release_value" ]; then
    release_option=$(jq -r --arg value "$release_value" '.fields.release_phase.options[$value]' "$CONFIG_PATH")
  else
    release_option=$(jq -r '.fields.release_phase.options["Not set"]' "$CONFIG_PATH")
  fi

  local okr_quarter_option=""
  if [ "$release_label" = "release:alpha" ]; then
    okr_quarter_option=$(jq -r '.fields.okr_quarter.options["Q1 2026"]' "$CONFIG_PATH")
  elif [ "$release_label" = "release:beta" ]; then
    okr_quarter_option=$(jq -r '.fields.okr_quarter.options["Q2 2026"]' "$CONFIG_PATH")
  elif [ "$release_label" = "release:v1" ]; then
    okr_quarter_option=$(jq -r '.fields.okr_quarter.options["Q3 2026"]' "$CONFIG_PATH")
  fi

  local status_value
  if [ "$issue_state" = "closed" ]; then
    if jq -r --argjson labels "$labels_json" --arg exp "$EXPERIMENT_LABEL" '$labels | index($exp) != null' <<< "" >/dev/null; then
      status_value="Shipped (experiment)"
    elif jq -r --argjson labels "$labels_json" '($labels | index("wontfix") != null) or ($labels | index("invalid") != null)' <<< "" >/dev/null; then
      status_value="Not proceeding"
    else
      status_value="Shipped (stable)"
    fi
  else
    if [ -n "$release_value" ]; then
      status_value="Planned"
    elif jq -r --argjson labels "$labels_json" '($labels | index("status:ready") != null) or ($labels | index("status:in-progress") != null) or ($labels | index("status:review") != null)' <<< "" >/dev/null; then
      status_value="Queued for development"
    else
      status_value="Under consideration"
    fi
  fi

  local status_option
  status_option=$(jq -r --arg value "$status_value" '.fields.status.options[$value]' "$CONFIG_PATH")

  update_field "$item_id" "$STATUS_FIELD_ID" "$status_option"
  update_field "$item_id" "$PRIORITY_FIELD_ID" "$priority_option"
  update_field "$item_id" "$SIZE_FIELD_ID" "$size_option"
  update_field "$item_id" "$AREA_FIELD_ID" "$area_option"
  update_field "$item_id" "$FEATURE_FIELD_ID" "$feature_option"
  update_field "$item_id" "$RELEASE_FIELD_ID" "$release_option"

  if [ -n "$okr_quarter_option" ]; then
    update_field "$item_id" "$OKR_QUARTER_FIELD_ID" "$okr_quarter_option"
  else
    update_field "$item_id" "$OKR_QUARTER_FIELD_ID" ""
  fi
}

process_issue() {
  local repo=$1
  local issue_number=$2
  local issue_node_id=$3
  local issue_state=$4
  local labels_json=$5
  local item_id=${6:-}

  if [ -z "$item_id" ]; then
    item_id=$(add_item_to_project "$issue_node_id")
  fi
  map_labels_to_fields "$repo" "$issue_number" "$issue_state" "$labels_json" "$item_id"
}

reconcile_project_items() {
  local end_cursor=null
  local has_next=true

  while [ "$has_next" = "true" ]; do
    local query
    query='query($projectId:ID!, $after:String){ node(id:$projectId){ ... on ProjectV2 { items(first:100, after:$after){ nodes{ id content{ ... on Issue { id number state repository{ nameWithOwner } labels(first:50){ nodes{ name } } } } } pageInfo{ hasNextPage endCursor } } } } }'

    local vars
    vars=$(jq -n --arg projectId "$PROJECT_ID" --arg after "$end_cursor" '{projectId:$projectId, after:($after=="null"?null:$after)}')

    local response
    response=$(graphql "$query" "$vars")

    local items
    items=$(echo "$response" | jq -c '.data.node.items.nodes[] | select(.content != null)')

    if [ -n "$items" ]; then
      while IFS= read -r item; do
        local issue_id issue_number issue_state repo labels_json item_id
        issue_id=$(echo "$item" | jq -r '.content.id')
        issue_number=$(echo "$item" | jq -r '.content.number')
        issue_state=$(echo "$item" | jq -r '.content.state' | tr '[:upper:]' '[:lower:]')
        repo=$(echo "$item" | jq -r '.content.repository.nameWithOwner')
        labels_json=$(echo "$item" | jq -c '.content.labels.nodes | map(.name)')
        item_id=$(echo "$item" | jq -r '.id')
        process_issue "$repo" "$issue_number" "$issue_id" "$issue_state" "$labels_json" "$item_id"
      done <<< "$items"
    fi

    has_next=$(echo "$response" | jq -r '.data.node.items.pageInfo.hasNextPage')
    end_cursor=$(echo "$response" | jq -r '.data.node.items.pageInfo.endCursor')
  done
}

main() {
  if [ "${GITHUB_EVENT_NAME:-}" = "schedule" ] || [ "${GITHUB_EVENT_NAME:-}" = "workflow_dispatch" ]; then
    reconcile_project_items
    return
  fi

  local issue_number issue_node_id issue_state repo labels_json
  issue_number=$(jq -r '.issue.number' "$GITHUB_EVENT_PATH")
  issue_node_id=$(jq -r '.issue.node_id' "$GITHUB_EVENT_PATH")
  issue_state=$(jq -r '.issue.state' "$GITHUB_EVENT_PATH" | tr '[:upper:]' '[:lower:]')
  repo=$(jq -r '.repository.full_name' "$GITHUB_EVENT_PATH")
  labels_json=$(jq -c '.issue.labels | map(.name)' "$GITHUB_EVENT_PATH")

  process_issue "$repo" "$issue_number" "$issue_node_id" "$issue_state" "$labels_json"
}

main "$@"
