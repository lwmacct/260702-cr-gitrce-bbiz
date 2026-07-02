#!/bin/bash
# shellcheck disable=SC1090,SC1091
# author https://github.com/lwmacct
# target: keep /app/data/.gitrce worktree equal to remote origin/HEAD

set -o pipefail

__log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

__die() {
  __log "ERROR: $*"
  rm -rf /app/data/.gitrce
  pkill -f "/usr/bin/supervisord$"
  exit 1
}

__init_ssh() {
  _ssh_dir=/app/data/.ssh

  mkdir -p "$_ssh_dir"
  chmod 700 "$_ssh_dir"

  if [[ "$(readlink /root/.ssh 2>/dev/null || true)" != "$_ssh_dir" ]]; then
    rm -rf /root/.ssh
    ln -sfn "$_ssh_dir" /root/.ssh
  fi

  touch "$_ssh_dir/config"
  chmod 600 "$_ssh_dir/config"
  grep -qxF 'StrictHostKeyChecking no' "$_ssh_dir/config" || echo 'StrictHostKeyChecking no' >>"$_ssh_dir/config"

  if [[ -n "${SSH_SECRET_KEY:-}" && (! -f "$_ssh_dir/id_ed25519" || "${SSH_OVERWRITE:-0}" == "1") ]]; then
    echo "$SSH_SECRET_KEY" | base64 -d >"$_ssh_dir/id_ed25519"
    chmod 600 "$_ssh_dir/id_ed25519"
    ssh-keygen -y -f "$_ssh_dir/id_ed25519" >"$_ssh_dir/id_ed25519.pub"
    chmod 644 "$_ssh_dir/id_ed25519.pub"
  elif [[ ! -f "$_ssh_dir/id_ed25519" ]]; then
    ssh-keygen -t ed25519 -N '' -f "$_ssh_dir/id_ed25519" -C 'lwmacct'
  fi
}

__clone_repo() {
  rm -rf /app/data/.gitrce
  mkdir -p /app/data
  git clone --depth=1 "$GIT_REMOTE_REPO" /app/data/.gitrce
}

__repo_ok() {
  [[ -d /app/data/.gitrce/.git ]] || return 1
  find /app/data/.gitrce/.git -maxdepth 3 -name '*.lock' -print0 | xargs -0 -r rm -f
  git -C /app/data/.gitrce fsck --full >/dev/null 2>&1 || return 1
  [[ "$(git -C /app/data/.gitrce remote get-url origin 2>/dev/null || true)" == "$GIT_REMOTE_REPO" ]]
}

# return: 0 synced, 1 remote unavailable but local repo is usable, 2 fatal local/recovery failure
__sync_repo() {
  if ! __repo_ok; then
    __clone_repo || return 2
  fi

  if ! git -C /app/data/.gitrce fetch --prune; then
    __repo_ok && return 1
    __clone_repo || return 2
    git -C /app/data/.gitrce fetch --prune || return 2
  fi

  _remote_ref="$(git -C /app/data/.gitrce symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" || return 2
  git -C /app/data/.gitrce reset --hard "$_remote_ref" || return 2
  git -C /app/data/.gitrce clean -fd || return 2
}

__run_script() {
  _script_name="$1"
  _script_path="/app/data/.gitrce/boot/$_script_name.sh"

  [[ -f "$_script_path" ]] || __die "missing $_script_path"
  __log "running boot/$_script_name.sh"
  timeout "$INTERVAL_MIN" bash "$_script_path" >/dev/null 2>&1 &
  _script_pid=$!
}

__main() {
  export LANG=C.UTF-8
  INTERVAL_MIN="${INTERVAL_MIN:-500}"
  INTERVAL_MAX="${INTERVAL_MAX:-600}"

  [[ -n "${GIT_REMOTE_REPO:-}" ]] || __die "GIT_REMOTE_REPO is empty"
  [[ "$INTERVAL_MIN" =~ ^[0-9]+$ && "$INTERVAL_MAX" =~ ^[0-9]+$ && "$INTERVAL_MIN" -le "$INTERVAL_MAX" ]] || __die "invalid interval"
  mkdir -p /app/data/logs
  ln -sfn /app/data/.gitrce /app/gitrce
  __init_ssh

  __sync_repo
  _sync_status=$?
  if [[ "$_sync_status" == "1" && -f /app/data/.gitrce/boot/start.sh ]]; then
    __log "remote unavailable; start existing repo"
  elif [[ "$_sync_status" != "0" ]]; then
    __die "sync failed"
  fi
  __run_script start

  while true; do
    if [[ -f /app/data/.gitrce/boot/env.sh ]]; then
      set -a
      source /app/data/.gitrce/boot/env.sh 2>/dev/null
      set +a
    fi
    _before_commit="$(git -C /app/data/.gitrce rev-parse HEAD 2>/dev/null || true)"
    __sync_repo
    _sync_status=$?
    if [[ "$_sync_status" == "0" ]]; then
      _after_commit="$(git -C /app/data/.gitrce rev-parse HEAD 2>/dev/null || true)"
      if [[ -n "$_before_commit" && "$_before_commit" != "$_after_commit" && -f /app/data/.gitrce/boot/update.sh ]]; then
        if [[ -n "${_update_pid:-}" ]] && kill -0 "$_update_pid" 2>/dev/null; then
          __log "update still running; skip"
        else
          __run_script update
          _update_pid="$_script_pid"
        fi
      fi
    elif [[ "$_sync_status" == "1" ]]; then
      __log "remote unavailable; skip sync"
    else
      __die "sync failed"
    fi
    sleep "$(shuf -i "$INTERVAL_MIN-$INTERVAL_MAX" -n 1)"
  done
}

__main
