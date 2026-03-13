#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# test_e2e_shgittp.sh — shgittp End-to-End Execution Suite
# ──────────────────────────────────────────────────────────────────────
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHGITTP="${SHGITTP:-$SCRIPT_DIR/shgittp}"

[[ -f "$SHGITTP" ]] || { printf 'Error: shgittp not found\n' >&2; exit 1; }

# ── Appearance & Counters ─────────────────────────────────────────────
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
CYAN='\033[0;36m' BOLD='\033[1m' DIM='\033[2m' NC='\033[0m'
PASS=0 FAIL=0 TOTAL=0
declare -a FAILURES=()
_name="" _failed=false _exit=0

# ── Cleanup ──────────────────────────────────────────────────────────
WORK_DIR=""
cleanup() { [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Framework
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
begin() { _name="$1"; _failed=false; TOTAL=$((TOTAL + 1)); }
end() {
    if $_failed; then
        FAIL=$((FAIL + 1))
        printf "${RED}  ✗ FAIL${NC}  %s\n" "$_name"
    else
        PASS=$((PASS + 1))
        printf "${GREEN}  ✓ pass${NC}  %s\n" "$_name"
    fi
}
section() { printf "\n${BOLD}${CYAN}── %s ──${NC}\n" "$1"; }

# ── Filesystem Assertions ─────────────────────────────────────────────
assert_exit() {
    [[ "$_exit" == "$1" ]] && return 0; _failed=true
    FAILURES+=("$_name: exit $_exit ≠ $1")
}
assert_exists() {
    [[ -e "$1" ]] && return 0; _failed=true
    FAILURES+=("$_name: File missing: $1")
}
assert_contains_file() {
    local file="$1" needle="$2"
    [[ -f "$file" ]] || { _failed=true; FAILURES+=("$_name: Missing $file"); return 1; }
    grep -q "$needle" "$file" && return 0; _failed=true
    FAILURES+=("$_name: $file missing '$needle'")
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# E2E Sandbox
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
setup_e2e_sandbox() {
    local d="$1"
    export SANDBOX_HOME="$d/remote_home"
    mkdir -p "$SANDBOX_HOME" "$d/bin"

    # Mock SSH handles three distinct call patterns from shgittp:
    #
    #   1. Git availability check:
    #        ssh ... host 'command -v git >/dev/null 2>&1 && echo 1 || echo 0'
    #      → last arg is the shell command string; eval it directly.
    #
    #   2. Git-mode deploy (script piped to stdin):
    #        printf '%s\n' "$SCRIPT" | ssh ... host sh
    #      → last arg is literally "sh"; script arrives on stdin.
    #        Read stdin and run it with sh.
    #
    #   3. Bootstrap deploy (heredoc script as last arg):
    #        ssh ... host "set -e\ncd \$HOME\n..."
    #      → last arg is a multi-line shell script string; eval it.
    #
    # Distinguishing (2) from (1)/(3): when shgittp passes "sh" as the
    # sole command, the last argument is exactly "sh" (possibly preceded
    # only by SSH option flags that start with "-").
    cat > "$d/bin/ssh" << 'MOCK'
#!/bin/bash
export HOME="$SANDBOX_HOME"
cd "$SANDBOX_HOME" || exit 1

# Find the last non-flag argument (the remote command / program).
last_cmd=""
for arg in "$@"; do
    case "$arg" in
        -*) ;;          # skip SSH flags like -o ForwardAgent=yes
        *)  last_cmd="$arg" ;;
    esac
done

# Pattern 2: shgittp pipes the deploy script to `ssh ... sh`
if [[ "$last_cmd" == "sh" ]]; then
    sh
    exit $?
fi

# Patterns 1 & 3: the command is the last argument — eval it.
eval "$last_cmd"
MOCK
    chmod +x "$d/bin/ssh"
}

create_source_repo() {
    local d="$1"
    mkdir -p "$d"
    (
        cd "$d" || exit 1
        git init -q
        git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
        git config user.email "test@test.com"
        git config user.name "Test"
        mkdir -p .config/app
        printf 'alias mycmd="echo hello"\n' > .bashrc
        printf 'app_setting=true\n' > .config/app/settings.ini
        git add -A
        git commit -q -m "init"
    ) 2>/dev/null
}

run_e2e() {
    local out err; out=$(mktemp); err=$(mktemp); _exit=0
    # Inject our sandbox binaries into the PATH
    env PATH="$WORK_DIR/bin:$PATH" \
        SANDBOX_HOME="$SANDBOX_HOME" \
        "$SHGITTP" "$@" >"$out" 2>"$err" || _exit=$?
    rm -f "$out" "$err"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# E2E Tests
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_e2e_clean_deploy() {
    begin "E2E: Clean deploy populates files correctly"
    rm -rf "$SANDBOX_HOME"/* "$SANDBOX_HOME"/.[!.]* 2>/dev/null || true

    local cfg="$WORK_DIR/cfg_e2e_clean.ini"
    printf '[testhost]\nrepo = %s\nbranch = main\n' "$REPO_URL" > "$cfg"

    run_e2e -c "$cfg" testhost
    assert_exit 0

    # Assert side-effects happened on disk!
    assert_exists "$SANDBOX_HOME/.bashrc"
    assert_exists "$SANDBOX_HOME/.config/app/settings.ini"
    assert_contains_file "$SANDBOX_HOME/.bashrc" "mycmd"
    end
}

test_e2e_backup_conflict() {
    begin "E2E: Conflicting files trigger backup logic"
    rm -rf "$SANDBOX_HOME"/* "$SANDBOX_HOME"/.[!.]* 2>/dev/null || true

    # Create a conflict file that exists in the user's home dir
    printf 'OLD ALIASES\n' > "$SANDBOX_HOME/.bashrc"

    local cfg="$WORK_DIR/cfg_e2e_conflict.ini"
    printf '[testhost]\nrepo = %s\nbranch = main\n' "$REPO_URL" > "$cfg"

    run_e2e -c "$cfg" testhost
    assert_exit 0

    # Verify the new file overwrote it
    assert_contains_file "$SANDBOX_HOME/.bashrc" "mycmd"

    # Verify the backup was created and contains the old content
    local backup_dir
    backup_dir=$(ls -d "$SANDBOX_HOME"/.dotfiles-backup-* 2>/dev/null | head -1)
    assert_exists "$backup_dir"
    assert_contains_file "$backup_dir/.bashrc" "OLD ALIASES"
    end
}

test_e2e_ssh_failure_caught() {
    begin "E2E: SSH connection failure returns exit 1"

    # Sabotage the mock SSH: for the git-check command, output "0" (no git)
    # so we enter bootstrap mode, but return 255 to trigger deploy_nogit failure.
    # This properly tests the SSH failure path in bootstrap mode.
    cat > "$WORK_DIR/bin/ssh" << 'MOCK'
#!/bin/bash
export HOME="$SANDBOX_HOME"
cd "$SANDBOX_HOME" || exit 1

last_cmd=""
for arg in "$@"; do
    case "$arg" in
        -*) ;;
        *)  last_cmd="$arg" ;;
    esac
done

# Git availability check: return "0" (no git) so we enter bootstrap mode
if [[ "$last_cmd" == *"command -v git"* ]]; then
    printf '0'
    exit 0
fi

# All other SSH commands fail with exit 255
exit 255
MOCK

    local cfg="$WORK_DIR/cfg_e2e_fail.ini"
    printf '[testhost]\nrepo = %s\n' "$REPO_URL" > "$cfg"

    run_e2e -c "$cfg" testhost
    assert_exit 1 # shgittp MUST fail here
    end
}

test_e2e_interactive_mode() {
    begin "E2E: -i flag triggers interactive SSH session"

    # Reset the mock to handle interactive SSH (-t flag present, no remote command)
    cat > "$WORK_DIR/bin/ssh" << 'MOCK'
#!/bin/bash
export HOME="$SANDBOX_HOME"
cd "$SANDBOX_HOME" || exit 1

# Check for -t flag (interactive mode) - no remote command, just host
has_t=0
has_sh=0
for arg in "$@"; do
    case "$arg" in
        -t|-tt) has_t=1 ;;
        sh)     has_sh=1 ;;
    esac
done

# Interactive mode: has -t but no "sh" command at end
if [[ $has_t -eq 1 && $has_sh -eq 0 ]]; then
    # Mark that interactive SSH was invoked
    touch "$SANDBOX_HOME/.interactive_invoked"
    exit 0
fi

# Git availability check
last_cmd=""
for arg in "$@"; do
    case "$arg" in
        -*) ;;
        *)  last_cmd="$arg" ;;
    esac
done

if [[ "$last_cmd" == *"command -v git"* ]]; then
    printf '1'
    exit 0
fi

# Deploy script via sh
if [[ "$last_cmd" == "sh" ]]; then
    exit 0
fi

# Fallback
exit 0
MOCK
    chmod +x "$WORK_DIR/bin/ssh"

    rm -rf "$SANDBOX_HOME"/* "$SANDBOX_HOME"/.[!.]* 2>/dev/null || true

    local cfg="$WORK_DIR/cfg_e2e_interactive.ini"
    printf '[testhost]\nrepo = %s\nbranch = main\n' "$REPO_URL" > "$cfg"

    run_e2e -i -c "$cfg" testhost
    assert_exit 0
    assert_exists "$SANDBOX_HOME/.interactive_invoked"
    end
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Runner
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
main() {
    printf "${BOLD}shgittp E2E test suite${NC}\n"

    WORK_DIR=$(mktemp -d)
    REPO_URL="$WORK_DIR/source_repo"

    create_source_repo "$REPO_URL"
    setup_e2e_sandbox "$WORK_DIR"

    section "Integration / Execution"
    test_e2e_clean_deploy
    test_e2e_backup_conflict
    test_e2e_ssh_failure_caught
    test_e2e_interactive_mode

    printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "  ${GREEN}pass: %d${NC}" "$PASS"
    (( FAIL > 0 )) && printf "   ${RED}fail: %d${NC}" "$FAIL"
    printf "   total: %d\n\n" "$TOTAL"

    if (( FAIL > 0 )); then
        for f in "${FAILURES[@]}"; do printf "  ${RED}•${NC} %s\n" "$f"; done
        exit 1
    fi
    exit 0
}

main "$@"
