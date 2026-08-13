aks() (
  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  SCRIPT_LOCATION="$REPOSITORIES_DIR/infrastructure/3_Applications/containers/aks-shell/aks-shell.sh"

  if [[ ! -s "$SCRIPT_LOCATION" ]]; then
    echo "Error: The \"$SCRIPT_LOCATION\" file does not exist or is 0 bytes." >&2
    exit 1
  fi

  "$SCRIPT_LOCATION" "$@"
)

# "akspim" activates or deactivates AKS PIM role assignments for shared clusters.
akspim() (
  set -euo pipefail # Exit on errors and undefined variables.

  local role_name="Azure Kubernetes Service Cluster User Role"
  local duration="PT8H"
  local justification="AKS access"
  local auto_confirm="false"
  local target_env=""
  local activate_all="false"
  local deactivate="false"
  local readiness_interval_seconds=20

  local dev_subscription="LH-DevOps-Dev-001"
  local dev_resource_group="rg-aks-eus-dev"
  local dev_cluster_name="aks-eus-dev"

  local prod_subscription="LH-DevOps-Prod-001"
  local prod_resource_group="rg-aks-eus-prod"
  local prod_cluster_name="aks-eus-prod"

  local sbox_subscription="59161e1f-62f6-456e-93d6-162d6f3c6d91"
  local sbox_resource_group="rg-aks-eus-sbox"
  local sbox_cluster_name="aks-eus-sbox"

  local env_subscription=""
  local env_resource_group=""
  local env_cluster_name=""

  akspim-info() {
    echo "[INFO] $1"
  }

  akspim-success() {
    echo "[SUCCESS] $1"
  }

  akspim-warning() {
    echo "[WARNING] $1"
  }

  akspim-error() {
    echo "[ERROR] $1" >&2
  }

  akspim-usage() {
    cat << EOF
Usage: ${FUNCNAME[1]} [-e dev|prod|sbox] [-a] [-d] [-t duration] [-j justification] [-y] [-h]

  -e, --env <name>          Target one environment: dev, prod, or sbox
  -a, --all                 Target all environments
  -d, --deactivate          Deactivate instead of activate
  -t, --duration <iso8601>  Activation duration (default: PT8H)
  -j, --justification <txt> Justification text (default: AKS access)
  -y, --yes                 Skip confirmation prompt
  -h, --help                Show this help message

Examples:
  akspim -e dev
  akspim --all -y
  akspim -e prod -t PT2H
  akspim -e dev -d
EOF
  }

  akspim-generate-guid() {
    if command -v uuidgen &> /dev/null; then
      uuidgen | tr '[:upper:]' '[:lower:]'
      return
    fi

    powershell.exe -NoProfile -Command "[guid]::NewGuid().ToString().ToLower()" | tr -d '\r'
  }

  akspim-resolve-environment() {
    if [[ -z "${1:-}" ]]; then
      akspim-error "The environment is required."
      return 1
    fi
    local env_name="$1"

    case "$env_name" in
      dev)
        env_subscription="$dev_subscription"
        env_resource_group="$dev_resource_group"
        env_cluster_name="$dev_cluster_name"
        ;;
      prod)
        env_subscription="$prod_subscription"
        env_resource_group="$prod_resource_group"
        env_cluster_name="$prod_cluster_name"
        ;;
      sbox)
        env_subscription="$sbox_subscription"
        env_resource_group="$sbox_resource_group"
        env_cluster_name="$sbox_cluster_name"
        ;;
      *)
        akspim-error "Unknown environment: $env_name"
        return 1
        ;;
    esac
  }

  akspim-select-environment() {
    local choice

    akspim-info "Select AKS environment:"
    echo "  1) dev ($dev_cluster_name)"
    echo "  2) prod ($prod_cluster_name)"
    echo "  3) sbox ($sbox_cluster_name)"
    echo "  4) all"

    while true; do
      echo -n "Enter choice [1-4]: "
      read -r choice
      case "$choice" in
        1)
          target_env="dev"
          return
          ;;
        2)
          target_env="prod"
          return
          ;;
        3)
          target_env="sbox"
          return
          ;;
        4)
          activate_all="true"
          return
          ;;
        *)
          akspim-warning "Invalid selection. Enter 1, 2, 3, or 4"
          ;;
      esac
    done
  }

  akspim-wait-for-readiness() {
    if [[ -z "${1:-}" ]]; then
      akspim-error "The environment is required."
      return 1
    fi
    local env_name="$1"

    akspim-resolve-environment "$env_name"

    local elapsed=0
    local probe_kubeconfig
    probe_kubeconfig=$(mktemp)
    trap 'rm -f "$probe_kubeconfig"' RETURN

    akspim-info "Checking AKS credential readiness for $env_name (polling every ${readiness_interval_seconds}s)..."

    while true; do
      if az aks get-credentials \
        --subscription "$env_subscription" \
        --resource-group "$env_resource_group" \
        --name "$env_cluster_name" \
        --file "$probe_kubeconfig" \
        --overwrite-existing > /dev/null 2>&1; then
        rm -f "$probe_kubeconfig"
        akspim-success "AKS credential retrieval is effective for $env_name after ${elapsed}s"
        return 0
      fi

      akspim-info "Not effective yet for $env_name (${elapsed}s elapsed); retrying in ${readiness_interval_seconds}s..."
      sleep "$readiness_interval_seconds"
      elapsed=$((elapsed + readiness_interval_seconds))
    done
  }

  akspim-submit-activation-request() {
    if [[ -z "${1:-}" ]]; then
      akspim-error "The environment is required."
      return 1
    fi
    local env_name="$1"

    local scope
    local principal_id
    local eligibility_json
    local role_definition_id
    local linked_schedule_id
    local request_id
    local start_time
    local activation_response
    local activation_status

    akspim-resolve-environment "$env_name"

    akspim-info "Submitting activation for $env_name..."
    akspim-info "Subscription: $env_subscription, Cluster: $env_cluster_name"

    az account set --subscription "$env_subscription" > /dev/null

    # The Windows "az.exe" emits CRLF when invoked from WSL, which corrupts URLs built from these values.
    scope=$(az aks show --resource-group "$env_resource_group" --name "$env_cluster_name" --query id --output tsv | tr -d '\r')
    principal_id=$(az ad signed-in-user show --query id --output tsv | tr -d '\r')

    eligibility_json=$(az rest \
      --method get \
      --url "https://management.azure.com${scope}/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?api-version=2020-10-01&%24filter=asTarget()")

    role_definition_id=$(echo "$eligibility_json" | jq -r --arg role_name "$role_name" '.value[] | select(.properties.expandedProperties.roleDefinition.displayName == $role_name) | .properties.roleDefinitionId' | head -n 1)
    linked_schedule_id=$(echo "$eligibility_json" | jq -r --arg role_name "$role_name" '.value[] | select(.properties.expandedProperties.roleDefinition.displayName == $role_name) | .properties.roleEligibilityScheduleId' | head -n 1)

    if [[ -z "$role_definition_id" || "$role_definition_id" == "null" || -z "$linked_schedule_id" || "$linked_schedule_id" == "null" ]]; then
      akspim-error "No eligible $role_name assignment found for $env_name"
      return 1
    fi

    request_id=$(akspim-generate-guid)
    start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    activation_response=$(az rest \
      --method put \
      --url "https://management.azure.com${scope}/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/${request_id}?api-version=2020-10-01" \
      --body "{\"properties\":{\"principalId\":\"${principal_id}\",\"roleDefinitionId\":\"${role_definition_id}\",\"requestType\":\"SelfActivate\",\"linkedRoleEligibilityScheduleId\":\"${linked_schedule_id}\",\"justification\":\"${justification}\",\"scheduleInfo\":{\"startDateTime\":\"${start_time}\",\"expiration\":{\"type\":\"AfterDuration\",\"duration\":\"${duration}\"}}}}" 2>&1)

    if echo "$activation_response" | grep --quiet "RoleAssignmentExists"; then
      akspim-success "Role already active for $env_name (skipping activation)"
      return 0
    fi

    if echo "$activation_response" | grep --quiet '"error"'; then
      akspim-error "$activation_response"
      return 1
    fi

    activation_status=$(echo "$activation_response" | jq -r '.properties.status // "unknown"')
    akspim-success "Submitted $env_name (status: $activation_status)"
  }

  akspim-submit-deactivation-request() {
    if [[ -z "${1:-}" ]]; then
      akspim-error "The environment is required."
      return 1
    fi
    local env_name="$1"

    local scope
    local principal_id
    local eligibility_json
    local role_definition_id
    local linked_schedule_id
    local request_id
    local deactivation_response
    local deactivation_status

    akspim-resolve-environment "$env_name"

    akspim-info "Submitting deactivation for $env_name..."
    akspim-info "Subscription: $env_subscription, Cluster: $env_cluster_name"

    az account set --subscription "$env_subscription" > /dev/null

    # The Windows "az.exe" emits CRLF when invoked from WSL, which corrupts URLs built from these values.
    scope=$(az aks show --resource-group "$env_resource_group" --name "$env_cluster_name" --query id --output tsv | tr -d '\r')
    principal_id=$(az ad signed-in-user show --query id --output tsv | tr -d '\r')

    eligibility_json=$(az rest \
      --method get \
      --url "https://management.azure.com${scope}/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?api-version=2020-10-01&%24filter=asTarget()")

    role_definition_id=$(echo "$eligibility_json" | jq -r --arg role_name "$role_name" '.value[] | select(.properties.expandedProperties.roleDefinition.displayName == $role_name) | .properties.roleDefinitionId' | head -n 1)
    linked_schedule_id=$(echo "$eligibility_json" | jq -r --arg role_name "$role_name" '.value[] | select(.properties.expandedProperties.roleDefinition.displayName == $role_name) | .properties.roleEligibilityScheduleId' | head -n 1)

    if [[ -z "$role_definition_id" || "$role_definition_id" == "null" || -z "$linked_schedule_id" || "$linked_schedule_id" == "null" ]]; then
      akspim-error "No eligible $role_name assignment found for $env_name"
      return 1
    fi

    request_id=$(akspim-generate-guid)

    deactivation_response=$(az rest \
      --method put \
      --url "https://management.azure.com${scope}/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/${request_id}?api-version=2020-10-01" \
      --body "{\"properties\":{\"principalId\":\"${principal_id}\",\"roleDefinitionId\":\"${role_definition_id}\",\"requestType\":\"SelfDeactivate\",\"linkedRoleEligibilityScheduleId\":\"${linked_schedule_id}\"}}" 2>&1)

    if echo "$deactivation_response" | grep -qi "RoleAssignmentDoesNotExist\\|is not active\\|no active assignment"; then
      akspim-warning "Role is not active for $env_name (nothing to deactivate)"
      return 0
    fi

    # PIM refuses to deactivate a role that was activated less than 5 minutes ago.
    if echo "$deactivation_response" | grep --quiet "ActiveDurationTooShort"; then
      akspim-warning "Role for $env_name was activated too recently to deactivate (PIM requires 5 minutes); try again shortly"
      return 0
    fi

    if echo "$deactivation_response" | grep --quiet '"error"'; then
      akspim-error "$deactivation_response"
      return 1
    fi

    deactivation_status=$(echo "$deactivation_response" | jq -r '.properties.status // "unknown"')
    akspim-success "Deactivated $env_name (status: $deactivation_status)"
  }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e | --env)
        if [[ -z "${2:-}" ]]; then
          akspim-error "Missing value for --env"
          return 1
        fi
        target_env="$2"
        shift 2
        ;;
      -a | --all)
        activate_all="true"
        shift
        ;;
      -d | --deactivate)
        deactivate="true"
        shift
        ;;
      -t | --duration)
        if [[ -z "${2:-}" ]]; then
          akspim-error "Missing value for --duration"
          return 1
        fi
        duration="$2"
        shift 2
        ;;
      -j | --justification)
        if [[ -z "${2:-}" ]]; then
          akspim-error "Missing value for --justification"
          return 1
        fi
        justification="$2"
        shift 2
        ;;
      -y | --yes)
        auto_confirm="true"
        shift
        ;;
      -h | --help)
        akspim-usage
        return 0
        ;;
      *)
        akspim-error "Unknown option: $1"
        akspim-usage
        return 1
        ;;
    esac
  done

  if [[ "$activate_all" == "true" && -n "$target_env" ]]; then
    akspim-error "Use either --env or --all, not both"
    return 1
  fi

  if ! command -v az &> /dev/null; then
    akspim-error "az is not installed or not in PATH"
    return 1
  fi

  if ! command -v jq &> /dev/null; then
    akspim-error "jq is required for this command"
    return 1
  fi

  if ! az account show > /dev/null 2>&1; then
    akspim-warning "No active Azure session found. Starting login..."
    if declare -F azl > /dev/null; then
      if ! azl; then
        akspim-warning "azl failed. Falling back to az login."
        az login
      fi
    else
      az login
    fi

    if ! az account show > /dev/null 2>&1; then
      akspim-error "Azure login failed. Run azl or az login and try again."
      return 1
    fi
  fi

  if [[ -z "$target_env" && "$activate_all" == "false" ]]; then
    akspim-select-environment
  fi

  local action_verb="activation"
  if [[ "$deactivate" == "true" ]]; then
    action_verb="deactivation"
  fi

  if [[ "$auto_confirm" == "false" ]]; then
    if [[ "$activate_all" == "true" ]]; then
      akspim-warning "This will submit PIM ${action_verb} requests for dev, prod, and sbox"
    else
      akspim-warning "This will submit a PIM ${action_verb} request for ${target_env}"
    fi

    echo -n "Continue? (y/N): "
    local confirm
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      akspim-info "Cancelled"
      return 0
    fi
  fi

  if [[ "$deactivate" == "true" ]]; then
    if [[ "$activate_all" == "true" ]]; then
      akspim-info "Submitting deactivation requests for all environments..."
      echo

      akspim-submit-deactivation-request dev || true
      echo
      akspim-submit-deactivation-request prod || true
      echo
      akspim-submit-deactivation-request sbox || true
      return 0
    fi

    akspim-submit-deactivation-request "$target_env"
    return 0
  fi

  if [[ "$activate_all" == "true" ]]; then
    akspim-info "Submitting activation requests for all environments..."
    echo

    akspim-submit-activation-request dev || true
    akspim-submit-activation-request prod || true
    akspim-submit-activation-request sbox || true

    echo
    akspim-info "All requests submitted. Checking readiness concurrently..."
    echo

    akspim-wait-for-readiness dev &
    local pid_dev=$!

    akspim-wait-for-readiness prod &
    local pid_prod=$!

    akspim-wait-for-readiness sbox &
    local pid_sbox=$!

    wait "$pid_dev" || true
    wait "$pid_prod" || true
    wait "$pid_sbox" || true
    return 0
  fi

  akspim-submit-activation-request "$target_env"
  echo
  akspim-wait-for-readiness "$target_env"
)
