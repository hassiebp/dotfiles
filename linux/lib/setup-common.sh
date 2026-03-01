#!/usr/bin/env bash

# Shared helpers for setup scripts. Requires bash >= 5.

SC_SCRIPT_NAME="${SC_SCRIPT_NAME:-setup-script}"
SC_DRY_RUN="${SC_DRY_RUN:-0}"
SC_VERBOSE="${SC_VERBOSE:-0}"
SC_ASSUME_YES="${SC_ASSUME_YES:-0}"
SC_MODE="${SC_MODE:-latest}"
SC_LOG_FILE="${SC_LOG_FILE:-}"
SC_USE_STATE="${SC_USE_STATE:-1}"
SC_STATE_DIR="${SC_STATE_DIR:-}"
SC_FORCE="${SC_FORCE:-0}"
SC_RETRY_ATTEMPTS="${SC_RETRY_ATTEMPTS:-3}"
SC_RETRY_DELAY_SECONDS="${SC_RETRY_DELAY_SECONDS:-3}"
SC_SUMMARY_LINES=()

SC_TMP_PATHS=()
SC_CLEANUP_TRAP_SET=0

sc_require_bash5() {
  if [[ -z "${BASH_VERSINFO:-}" ]] || ((BASH_VERSINFO[0] < 5)); then
    echo "[ERROR] $SC_SCRIPT_NAME requires bash >= 5." >&2
    exit 1
  fi
}

sc_load_config_file() {
  local config_file="$1"
  if [[ -n "$config_file" && -f "$config_file" ]]; then
    # shellcheck disable=SC1090
    source "$config_file"
  fi
}

sc_init_cleanup_trap() {
  if ((SC_CLEANUP_TRAP_SET)); then
    return
  fi
  trap sc_cleanup_tmp_paths EXIT
  SC_CLEANUP_TRAP_SET=1
}

sc_register_tmp_path() {
  local path="$1"
  SC_TMP_PATHS+=("$path")
}

sc_cleanup_tmp_paths() {
  local path
  for path in "${SC_TMP_PATHS[@]}"; do
    if [[ -n "$path" && -e "$path" ]]; then
      rm -rf "$path" >/dev/null 2>&1 || true
    fi
  done
}

sc_init_log_file() {
  local log_file="$1"
  SC_LOG_FILE="$log_file"

  if [[ -z "$SC_LOG_FILE" ]]; then
    return
  fi

  local log_dir
  log_dir="$(dirname "$SC_LOG_FILE")"
  mkdir -p "$log_dir"
  : > "$SC_LOG_FILE"
}

sc_now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

sc_log() {
  local level="$1"
  shift
  local message="$*"
  local line
  line="[$(sc_now_utc)] [$level] $message"

  echo "$line"
  if [[ -n "$SC_LOG_FILE" ]]; then
    echo "$line" >> "$SC_LOG_FILE"
  fi
}

sc_info() { sc_log "INFO" "$@"; }
sc_warn() { sc_log "WARN" "$@"; }
sc_error() { sc_log "ERROR" "$@"; }

sc_die() {
  sc_error "$@"
  exit 1
}

sc_add_summary() {
  SC_SUMMARY_LINES+=("$*")
}

sc_print_summary() {
  if ((${#SC_SUMMARY_LINES[@]} == 0)); then
    return
  fi

  sc_info "Summary:"
  local line
  for line in "${SC_SUMMARY_LINES[@]}"; do
    sc_info "  - $line"
  done
}

sc_print_cmd() {
  local arg
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

sc_quote() {
  printf '%q' "$1"
}

sc_join_quoted() {
  local joined=""
  local arg
  for arg in "$@"; do
    joined+=" $(sc_quote "$arg")"
  done
  printf '%s' "${joined# }"
}

sc_run() {
  if ((SC_DRY_RUN)); then
    printf '[DRY-RUN]'
    sc_print_cmd "$@"
    return 0
  fi

  if ((SC_VERBOSE)); then
    printf '[RUN]'
    sc_print_cmd "$@"
  fi

  "$@"
}

sc_run_sudo() {
  if ((EUID == 0)); then
    sc_run "$@"
  else
    sc_run sudo "$@"
  fi
}

sc_run_as_user() {
  local user="$1"
  local command="$2"

  if ((SC_DRY_RUN)); then
    printf '[DRY-RUN]'
    sc_print_cmd sudo -u "$user" -H bash -lc "$command"
    return 0
  fi

  if ((SC_VERBOSE)); then
    printf '[RUN]'
    sc_print_cmd sudo -u "$user" -H bash -lc "$command"
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo -u "$user" -H bash -lc "$command"
  else
    su - "$user" -c "$command"
  fi
}

sc_run_as_user_cmd() {
  local user="$1"
  shift
  (($# > 0)) || sc_die "sc_run_as_user_cmd requires command arguments"

  local command
  command="$(sc_join_quoted "$@")"
  sc_run_as_user "$user" "$command"
}

sc_confirm_or_exit() {
  local prompt="$1"

  if ((SC_ASSUME_YES)); then
    return 0
  fi

  local answer=""
  read -r -p "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || sc_die "Aborted by user."
}

sc_contains() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

sc_parse_csv_to_array() {
  local csv="$1"
  local -n out_ref="$2"
  out_ref=()

  local raw=()
  IFS=',' read -r -a raw <<< "$csv"

  local item
  for item in "${raw[@]}"; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ -n "$item" ]] && out_ref+=("$item")
  done
}

sc_validate_phase_list() {
  local -n phases_ref="$1"
  local -n valid_ref="$2"

  local phase
  for phase in "${phases_ref[@]}"; do
    sc_contains "$phase" "${valid_ref[@]}" || sc_die "Unknown phase '$phase'. Valid phases: ${valid_ref[*]}"
  done
}

sc_should_run_phase() {
  local phase="$1"
  local -n only_ref="$2"
  local -n skip_ref="$3"

  if ((${#only_ref[@]} > 0)) && ! sc_contains "$phase" "${only_ref[@]}"; then
    return 1
  fi

  if sc_contains "$phase" "${skip_ref[@]}"; then
    return 1
  fi

  return 0
}

sc_retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local try=1
  while true; do
    if "$@"; then
      return 0
    fi

    if ((try >= attempts)); then
      return 1
    fi

    sc_warn "Attempt $try failed for command. Retrying in ${delay}s..."
    sleep "$delay"
    try=$((try + 1))
    delay=$((delay * 2))
  done
}

sc_prepare_state_dir() {
  if ((SC_USE_STATE == 0)); then
    return
  fi

  [[ -n "$SC_STATE_DIR" ]] || return
  mkdir -p "$SC_STATE_DIR"
}

sc_state_marker_path() {
  local phase="$1"
  printf '%s/%s.done' "$SC_STATE_DIR" "$phase"
}

sc_phase_done() {
  local phase="$1"
  if ((SC_USE_STATE == 0)); then
    return 1
  fi
  [[ -n "$SC_STATE_DIR" ]] || return 1
  [[ -f "$(sc_state_marker_path "$phase")" ]]
}

sc_mark_phase_done() {
  local phase="$1"
  if ((SC_USE_STATE == 0)); then
    return
  fi
  [[ -n "$SC_STATE_DIR" ]] || return
  mkdir -p "$SC_STATE_DIR"
  : > "$(sc_state_marker_path "$phase")"
}

sc_reset_state_dir() {
  if ((SC_USE_STATE == 0)); then
    return
  fi
  [[ -n "$SC_STATE_DIR" ]] || return
  rm -rf "$SC_STATE_DIR"
}

sc_maybe_skip_phase_for_state() {
  local phase="$1"

  if ((SC_USE_STATE == 0)); then
    return 1
  fi
  if ((SC_FORCE)); then
    return 1
  fi
  if [[ "$phase" == "precheck" || "$phase" == "verify" ]]; then
    return 1
  fi

  sc_phase_done "$phase"
}

sc_require_commands() {
  local missing=0
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      sc_error "Missing command: $cmd"
      missing=1
    fi
  done

  ((missing == 0)) || return 1
}

sc_assert_ubuntu() {
  [[ -f /etc/os-release ]] || sc_die "Cannot detect operating system."
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || sc_die "This script supports Ubuntu only."
}
