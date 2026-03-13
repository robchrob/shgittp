#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# test_e2e_shgittp.sh — shgittp Real E2E Suite (Docker)
#
# Uses the existing docker/ infra (manage.sh + three Dockerfiles).
# Requires: docker daemon running, ~/.ssh/id_rsa.pub present.
#
# Run:  ./test_e2e_shgittp.sh
#       SHGITTP=./shgittp ./test_e2e_shgittp.sh
#       KEEP_CONTAINERS=1 ./test_e2e_shgittp.sh   # don't teardown on exit
# ──────────────────────────────────────────────────────────────────────
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHGITTP="${SHGITTP:-$PROJECT_ROOT/shgittp}"
MANAGE="$PROJECT_ROOT/docker/manage.sh"

[[ -f "$SHGITTP" ]] || { printf 'Error: shgittp not found at %s\n' "$SHGITTP" >&2; exit 1; }
[[ -f "$MANAGE"  ]] || { printf 'Error: docker/manage.sh not found\n' "$MANAGE" >&2; exit 1; }

# ── Appearance & Counters ─────────────────────────────────────────────
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
CYAN='\033[0;36m' BOLD='\033[1m' NC='\033[0m'
PASS=0 FAIL=0 SKIP=0 TOTAL=0
declare -a FAILURES=()
_name="" _failed=false _exit=0

# ── Ports (avoid collisions with manage.sh default 2222) ─────────────
PORT_BASIC=2230
PORT_NOGIT=2231
PORT_ROOT=2232

# ── SSH helper (no host-key checking, explicit port) ──────────────────
SSH_OPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes"

ssh_remote() {
    # ssh_remote PORT CMD
    local port="$1"; shift
    ssh $SSH_OPT -p "$port" dev@localhost "$@"
}

ssh_remote_root() {
    local port="$1"; shift
    ssh $SSH_OPT -p "$port" root@localhost "$@"
}

scp_remote() {
    # scp_remote PORT local_src remote_dst
    local port="$1" src="$2" dst="$3"
    scp $SSH_OPT -P "$port" "$src" "dev@localhost:$dst"
}

# ── Cleanup ───────────────────────────────────────────────────────────
WORK_DIR=""
CONTAINERS_STARTED=()

cleanup() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
    if [[ "${KEEP_CONTAINERS:-0}" == "1" ]]; then
        printf '\n%sContainers kept (KEEP_CONTAINERS=1)%s\n' "$YELLOW" "$NC" >&2
        return
    fi
    for variant in "${CONTAINERS_STARTED[@]+"${CONTAINERS_STARTED[@]}"}"; do
        PORT="${_PORT_FOR[$variant]:-}" \
            "$MANAGE" "$variant" stop 2>/dev/null || true
        docker rm -f "shgittp-${variant}" 2>/dev/null || true
    done
}
trap cleanup EXIT

# Map variant → port for cleanup
declare -A _PORT_FOR=(
    [alpine-basic]=$PORT_BASIC
    [alpine-nogit]=$PORT_NOGIT
    [alpine-root]=$PORT_ROOT
)

# ── Framework ────────────────────────────────────────────────────────
begin()   { _name="$1"; _failed=false; TOTAL=$((TOTAL + 1)); }
end() {
    if $_failed; then
        FAIL=$((FAIL + 1))
        printf "${RED}  ✗ FAIL${NC}  %s\n" "$_name"
    else
        PASS=$((PASS + 1))
        printf "${GREEN}  ✓ pass${NC}  %s\n" "$_name"
    fi
}
skip()    { TOTAL=$((TOTAL + 1)); SKIP=$((SKIP + 1))
            printf "${YELLOW}  ○ skip${NC}  %s ${NC}(%s)\n" "$1" "$2"; }
section() { printf "\n${BOLD}${CYAN}── %s ──${NC}\n" "$1"; }

# ── Assertions ────────────────────────────────────────────────────────
assert_exit() {
    [[ "$_exit" == "$1" ]] && return 0
    _failed=true; FAILURES+=("$_name: exit $_exit ≠ $1")
}
assert_remote_exists() {
    # assert_remote_exists PORT PATH
    ssh_remote "$1" "test -e $2" 2>/dev/null && return 0
    _failed=true; FAILURES+=("$_name: remote path missing: $2")
}
assert_remote_not_exists() {
    ssh_remote "$1" "test ! -e $2" 2>/dev/null && return 0
    _failed=true; FAILURES+=("$_name: remote path unexpectedly exists: $2")
}
assert_remote_contains() {
    # assert_remote_contains PORT FILE NEEDLE
    ssh_remote "$1" "grep -q $3 $2" 2>/dev/null && return 0
    _failed=true; FAILURES+=("$_name: $2 missing '$3' on remote")
}
assert_remote_root_exists() {
    ssh_remote_root "$1" "test -e $2" 2>/dev/null && return 0
    _failed=true; FAILURES+=("$_name: remote root path missing: $2")
}
assert_stderr_contains() {
    local stderr="$1" needle="$2"
    [[ "$stderr" == *"$needle"* ]] && return 0
    _failed=true; FAILURES+=("$_name: stderr missing '$needle'")
}

# ── Container lifecycle ───────────────────────────────────────────────
start_container() {
    local variant="$1" port="$2"
    printf '   Starting %s on :%s ... ' "$variant" "$port" >&2

    # Stop+remove any stale instance first
    docker rm -f "shgittp-${variant}" 2>/dev/null || true

    PORT="$port" "$MANAGE" "$variant" start >/dev/null 2>&1
    CONTAINERS_STARTED+=("$variant")

    # Wait for sshd to accept connections (up to 20s)
    local i=0
    while ! ssh $SSH_OPT -p "$port" dev@localhost true 2>/dev/null; do
        i=$((i + 1))
        [[ $i -ge 40 ]] && { printf 'TIMEOUT\n' >&2; return 1; }
        sleep 0.5
    done
    printf 'ready\n' >&2
}

wipe_remote_home() {
    # Remove all dotfiles/dirs in remote $HOME except .ssh
    local port="$1"
    ssh_remote "$port" \
        'find $HOME -mindepth 1 -maxdepth 1 ! -name .ssh -exec rm -rf {} +' \
        2>/dev/null || true
}

wipe_remote_root_home() {
    local port="$1"
    ssh_remote_root "$port" \
        'find /root -mindepth 1 -maxdepth 1 ! -name .ssh -exec rm -rf {} +' \
        2>/dev/null || true
}

# ── Source repo fixture ───────────────────────────────────────────────
create_source_repo() {
    local d="$1"
    mkdir -p "$d"
    (
        cd "$d"
        git init -q
        git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
        git config user.email "test@test.com"
        git config user.name  "Test"
        mkdir -p .config/app
        printf 'alias mycmd="echo hello"\n'  > .bashrc
        printf 'export EDITOR=vim\n'         > .profile
        printf 'app_setting=true\n'          > .config/app/settings.ini
        printf '#!/bin/sh\ntouch $HOME/.run_marker\n' > setup.sh
        git add -A
        git commit -q -m "init"
    ) 2>/dev/null
}

# Convert host path to container-accessible path (for git mode - runs in container)
container_repo_path() {
    local host_path="$1"
    echo "$host_path" | sed 's|^/tmp/|/host/tmp/|'
}

# Host path (for bootstrap mode - runs on host)
host_repo_path() {
    echo "$1"
}

run_shgittp() {
    local out err; out=$(mktemp); err=$(mktemp); _exit=0
    "$SHGITTP" "$@" >"$out" 2>"$err" || _exit=$?
    _stdout=$(<"$out"); _stderr=$(<"$err"); rm -f "$out" "$err"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Section A — Git mode (alpine-basic, has git)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_git_clean_deploy() {
    begin "git mode: files land in correct remote paths"
    wipe_remote_home $PORT_BASIC

    local cfg="$WORK_DIR/cfg_git_clean.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\ndir = .dotfiles\n' \
        "$(container_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_BASIC
    assert_exit 0

    assert_remote_exists  $PORT_BASIC '$HOME/.bashrc'
    assert_remote_exists  $PORT_BASIC '$HOME/.profile'
    assert_remote_exists  $PORT_BASIC '$HOME/.config/app/settings.ini'
    assert_remote_contains $PORT_BASIC '$HOME/.bashrc' 'mycmd'
    assert_remote_exists  $PORT_BASIC '$HOME/.dotfiles'   # bare git dir
    end
}

test_git_idempotent_redeploy() {
    begin "git mode: second deploy (fetch path) succeeds cleanly"
    # Home already populated from previous test — do NOT wipe

    local cfg="$WORK_DIR/cfg_git_idem.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\ndir = .dotfiles\n' \
        "$(container_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_BASIC
    assert_exit 0
    assert_remote_contains $PORT_BASIC '$HOME/.bashrc' 'mycmd'
    end
}

test_git_backup_on_conflict() {
    begin "git mode: conflicting files are backed up"
    wipe_remote_home $PORT_BASIC

    # Plant a conflicting .bashrc
    ssh_remote $PORT_BASIC 'printf "OLD CONTENT\n" > $HOME/.bashrc'

    local cfg="$WORK_DIR/cfg_git_conflict.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\ndir = .dotfiles\n' \
        "$(container_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_BASIC
    assert_exit 0

    # New content deployed
    assert_remote_contains $PORT_BASIC '$HOME/.bashrc' 'mycmd'

    # Backup directory exists and has old content
    local backup
    backup=$(ssh_remote $PORT_BASIC \
        'ls -d $HOME/.dotfiles-backup-* 2>/dev/null | head -1' 2>/dev/null || true)
    [[ -n "$backup" ]] || { _failed=true; FAILURES+=("$_name: no backup dir found"); end; return; }
    assert_remote_contains $PORT_BASIC "$backup/.bashrc" 'OLD CONTENT'
    end
}

test_git_run_command_executes() {
    begin "git mode: run= command executes on remote"
    wipe_remote_home $PORT_BASIC

    local cfg="$WORK_DIR/cfg_git_run.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\ndir = .dotfiles\nrun = sh setup.sh\n' \
        "$(container_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_BASIC
    assert_exit 0

    assert_remote_exists $PORT_BASIC '$HOME/.run_marker'
    end
}

test_git_custom_work_tree() {
    begin "git mode: custom work tree (tree=) respected"
    wipe_remote_home $PORT_BASIC
    ssh_remote $PORT_BASIC 'mkdir -p $HOME/custom-tree'

    local cfg="$WORK_DIR/cfg_git_tree.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\ndir = .dotfiles-tree\ntree = custom-tree\n' \
        "$(container_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_BASIC
    assert_exit 0

    assert_remote_exists $PORT_BASIC '$HOME/custom-tree/.bashrc'
    assert_remote_contains $PORT_BASIC '$HOME/custom-tree/.bashrc' 'mycmd'
    end
}

test_git_multi_repo_single_connection() {
    begin "git mode: multi-repo jobs deploy via single SSH connection"
    wipe_remote_home $PORT_BASIC

    # Create a second source repo
    local repo2="$WORK_DIR/source_repo2"
    mkdir -p "$repo2"
    (
        cd "$repo2"
        git init -q
        git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
        git config user.email "test@test.com"
        git config user.name  "Test"
        printf 'set -g mouse on\n' > .tmux.conf
        git add -A; git commit -q -m "init"
    ) 2>/dev/null

    local cfg="$WORK_DIR/cfg_git_multi.ini"
    cat > "$cfg" <<EOF
[localhost]
repo   = $(container_repo_path "$REPO_URL")
dir    = .dotfiles
branch = main

repo_tmux   = $(container_repo_path "$repo2")
dir_tmux    = .dotfiles-tmux
branch_tmux = main
EOF

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_BASIC
    assert_exit 0

    assert_remote_exists  $PORT_BASIC '$HOME/.bashrc'
    assert_remote_exists  $PORT_BASIC '$HOME/.tmux.conf'
    assert_remote_contains $PORT_BASIC '$HOME/.tmux.conf' 'mouse'
    end
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Section B — Bootstrap mode (alpine-nogit, no git on remote)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_bootstrap_clean_deploy() {
    begin "bootstrap mode: files land correctly without remote git"
    wipe_remote_home $PORT_NOGIT

    local cfg="$WORK_DIR/cfg_boot_clean.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\ndir = .dotfiles\n' \
        "$(host_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_NOGIT
    assert_exit 0

    assert_remote_exists  $PORT_NOGIT '$HOME/.bashrc'
    assert_remote_exists  $PORT_NOGIT '$HOME/.config/app/settings.ini'
    assert_remote_contains $PORT_NOGIT '$HOME/.bashrc' 'mycmd'
    # Bare git dir also transferred
    assert_remote_exists  $PORT_NOGIT '$HOME/.dotfiles'
    end
}

test_bootstrap_backup_on_conflict() {
    begin "bootstrap mode: conflicting files are backed up"
    wipe_remote_home $PORT_NOGIT
    ssh_remote $PORT_NOGIT 'printf "STALE\n" > $HOME/.bashrc'

    local cfg="$WORK_DIR/cfg_boot_conflict.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\ndir = .dotfiles\n' \
        "$(host_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_NOGIT
    assert_exit 0

    assert_remote_contains $PORT_NOGIT '$HOME/.bashrc' 'mycmd'

    local backup
    backup=$(ssh_remote $PORT_NOGIT \
        'ls -d $HOME/.dotfiles-backup-* 2>/dev/null | head -1' 2>/dev/null || true)
    [[ -n "$backup" ]] || { _failed=true; FAILURES+=("$_name: no backup dir found"); end; return; }
    assert_remote_contains $PORT_NOGIT "$backup/.bashrc" 'STALE'
    end
}

test_bootstrap_run_command_executes() {
    begin "bootstrap mode: run= command executes on remote"
    wipe_remote_home $PORT_NOGIT

    local cfg="$WORK_DIR/cfg_boot_run.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\ndir = .dotfiles\nrun = sh setup.sh\n' \
        "$(host_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_NOGIT
    assert_exit 0

    assert_remote_exists $PORT_NOGIT '$HOME/.run_marker'
    end
}

test_bootstrap_custom_work_tree() {
    begin "bootstrap mode: custom work tree (tree=) respected"
    wipe_remote_home $PORT_NOGIT
    ssh_remote $PORT_NOGIT 'mkdir -p $HOME/my-tree'

    local cfg="$WORK_DIR/cfg_boot_tree.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\ndir = .dotfiles-bt\ntree = my-tree\n' \
        "$(host_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_NOGIT
    assert_exit 0

    assert_remote_exists  $PORT_NOGIT '$HOME/my-tree/.bashrc'
    assert_remote_contains $PORT_NOGIT '$HOME/my-tree/.bashrc' 'mycmd'
    end
}

test_bootstrap_stderr_mode_flag() {
    begin "bootstrap mode: 'bootstrap' appears in shgittp output"
    wipe_remote_home $PORT_NOGIT

    local cfg="$WORK_DIR/cfg_boot_flag.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\n' "$(host_repo_path "$REPO_URL")" > "$cfg"

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_NOGIT
    assert_exit 0
    assert_stderr_contains "$_stderr" "bootstrap"
    end
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Section C — Multi-user batching (alpine-root, dev + root users)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_multiuser_dev_and_root() {
    begin "multi-user: deploys to dev and root homes in one invocation"
    wipe_remote_home      $PORT_ROOT
    wipe_remote_root_home $PORT_ROOT

    local cfg="$WORK_DIR/cfg_mu.ini"
    cat > "$cfg" <<EOF
[localhost]
repo   = $(container_repo_path "$REPO_URL")
branch = main
dir    = .dotfiles

[localhost:root]
repo   = $(container_repo_path "$REPO_URL")
branch = main
dir    = .dotfiles
user   = root
EOF

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_ROOT
    assert_exit 0

    assert_remote_exists      $PORT_ROOT '$HOME/.bashrc'
    assert_remote_root_exists $PORT_ROOT '/root/.bashrc'
    assert_remote_contains    $PORT_ROOT '$HOME/.bashrc' 'mycmd'
    assert_root_file_contains $PORT_ROOT '/root/.bashrc' 'mycmd'
    end
}

# assert_remote_contains uses dev@localhost; use a dedicated check for root
assert_root_file_contains() {
    local port="$1" file="$2" needle="$3"
    ssh_remote_root "$port" "grep -q $needle $file" 2>/dev/null && return 0
    _failed=true; FAILURES+=("$_name: root $file missing '$needle'")
}

test_multiuser_separate_dirs() {
    begin "multi-user: separate dirs per user don't collide"
    wipe_remote_home      $PORT_ROOT
    wipe_remote_root_home $PORT_ROOT

    local cfg="$WORK_DIR/cfg_mu_dirs.ini"
    cat > "$cfg" <<EOF
[localhost]
repo   = $(container_repo_path "$REPO_URL")
branch = main
dir    = .dev-dots

[localhost:root]
repo   = $(container_repo_path "$REPO_URL")
branch = main
dir    = .root-dots
user   = root
EOF

    run_shgittp -c "$cfg" dev@localhost -- -p $PORT_ROOT
    assert_exit 0

    assert_remote_exists      $PORT_ROOT '$HOME/.dev-dots'
    assert_remote_root_exists $PORT_ROOT '/root/.root-dots'
    # Cross-contamination check
    assert_remote_not_exists  $PORT_ROOT '$HOME/.root-dots'
    end
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Section D — Connection failure handling
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_bad_port_fails() {
    begin "connection failure: unreachable host returns exit 1"
    local cfg="$WORK_DIR/cfg_badport.ini"
    printf '[localhost]\nrepo = %s\nbranch = main\n' "$(container_repo_path "$REPO_URL")" > "$cfg"

    # Port 19999 should not have anything listening
    run_shgittp -c "$cfg" dev@localhost -- -p 19999 -o ConnectTimeout=2
    assert_exit 1
    end
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Runner
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    printf "${BOLD}shgittp real E2E suite${NC}  (%s)\n" "$SHGITTP"

    # Preflight checks
    if ! command -v docker >/dev/null 2>&1; then
        printf '%sDocker not found — skipping all E2E tests%s\n' "$YELLOW" "$NC" >&2
        exit 0
    fi
    if ! docker info >/dev/null 2>&1; then
        printf '%sDocker daemon not running — skipping all E2E tests%s\n' "$YELLOW" "$NC" >&2
        exit 0
    fi
    if [[ ! -f "$HOME/.ssh/id_rsa.pub" ]]; then
        printf '%s~/.ssh/id_rsa.pub not found — cannot build containers%s\n' "$RED" "$NC" >&2
        exit 1
    fi

    WORK_DIR="/tmp/shgittp_test_$(date +%s)"
    mkdir -p "$WORK_DIR"
    REPO_URL="$WORK_DIR/source_repo"
    create_source_repo "$REPO_URL"

    # ── Build images (once, fast if cached) ──────────────────────────
    printf '\n%s── Building images ──%s\n' "$CYAN$BOLD" "$NC"
    "$MANAGE" alpine-basic build 2>&1 | grep -E '^(Step|Successfully|ERROR|---)' || true
    "$MANAGE" alpine-nogit build 2>&1 | grep -E '^(Step|Successfully|ERROR|---)' || true
    "$MANAGE" alpine-root  build 2>&1 | grep -E '^(Step|Successfully|ERROR|---)' || true

    # ── Start containers ─────────────────────────────────────────────
    printf '\n%s── Starting containers ──%s\n' "$CYAN$BOLD" "$NC"
    start_container alpine-basic $PORT_BASIC || {
        printf '%sFailed to start alpine-basic%s\n' "$RED" "$NC" >&2; exit 1; }
    start_container alpine-nogit $PORT_NOGIT || {
        printf '%sFailed to start alpine-nogit%s\n' "$RED" "$NC" >&2; exit 1; }
    start_container alpine-root  $PORT_ROOT  || {
        printf '%sFailed to start alpine-root%s\n'  "$RED" "$NC" >&2; exit 1; }

    # Fix git ownership issue for root user (needed for multi-user tests)
    ssh_remote_root $PORT_ROOT "git config --global --add safe.directory '*'" 2>/dev/null || true

    # ── Test sections ─────────────────────────────────────────────────
    section "Git Mode  (alpine-basic :$PORT_BASIC)"
    test_git_clean_deploy
    test_git_idempotent_redeploy
    test_git_backup_on_conflict
    test_git_run_command_executes
    test_git_custom_work_tree
    test_git_multi_repo_single_connection

    section "Bootstrap Mode  (alpine-nogit :$PORT_NOGIT)"
    test_bootstrap_clean_deploy
    test_bootstrap_backup_on_conflict
    test_bootstrap_run_command_executes
    test_bootstrap_custom_work_tree
    test_bootstrap_stderr_mode_flag

    section "Multi-User Batching  (alpine-root :$PORT_ROOT)"
    test_multiuser_dev_and_root
    test_multiuser_separate_dirs

    section "Connection Failure"
    test_bad_port_fails

    # ── Report ────────────────────────────────────────────────────────
    printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "  ${GREEN}pass: %d${NC}" "$PASS"
    (( FAIL > 0 )) && printf "   ${RED}fail: %d${NC}" "$FAIL"
    (( SKIP > 0 )) && printf "   ${YELLOW}skip: %d${NC}" "$SKIP"
    printf "   total: %d\n" "$TOTAL"
    printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if (( FAIL > 0 )); then
        printf "\n${RED}${BOLD}Failures:${NC}\n"
        local f
        for f in "${FAILURES[@]}"; do printf "  ${RED}•${NC} %s\n" "$f"; done
        printf "\n"
        exit 1
    fi

    printf "${GREEN}All E2E tests passed.${NC}\n\n"
    exit 0
}

main "$@"
