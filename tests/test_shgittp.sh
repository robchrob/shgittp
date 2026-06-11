#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# test_shgittp.sh — shgittp regression suite
# ──────────────────────────────────────────────────────────────────────
# Run:  chmod +x test_shgittp.sh && ./test_shgittp.sh
#       SHGITTP=./shgittp ./test_shgittp.sh
#       VERBOSE=1 ./test_shgittp.sh
# ──────────────────────────────────────────────────────────────────────
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHGITTP="${SHGITTP:-$PROJECT_ROOT/shgittp}"

[[ -f "$SHGITTP" ]] || { printf 'Error: shgittp not found at %s\n' "$SHGITTP" >&2; exit 1; }
chmod +x "$SHGITTP" 2>/dev/null || true
SHGITTP="$(cd "$(dirname "$SHGITTP")" && pwd)/$(basename "$SHGITTP")"

# ── Appearance ────────────────────────────────────────────────────────
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
CYAN='\033[0;36m' BOLD='\033[1m' DIM='\033[2m' NC='\033[0m'

# ── Counters ─────────────────────────────────────────────────────────
PASS=0 FAIL=0 SKIP=0 TOTAL=0
declare -a FAILURES=()
VERBOSE="${VERBOSE:-0}"
_name="" _failed=false _stdout="" _stderr="" _exit=0

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
        if [[ "$VERBOSE" == "1" ]]; then
            [[ -n "$_stdout" ]] && printf "    ${DIM}stdout: %.300s${NC}\n" "$_stdout"
            [[ -n "$_stderr" ]] && printf "    ${DIM}stderr: %.300s${NC}\n" "$_stderr"
        fi
    else
        PASS=$((PASS + 1))
        printf "${GREEN}  ✓ pass${NC}  %s\n" "$_name"
    fi
}

skip() {
    TOTAL=$((TOTAL + 1)); SKIP=$((SKIP + 1))
    printf "${YELLOW}  ○ skip${NC}  %s ${DIM}(%s)${NC}\n" "$1" "$2"
}

section() { printf "\n${BOLD}${CYAN}── %s ──${NC}\n" "$1"; }

run_shgittp() {
    local out err; out=$(mktemp); err=$(mktemp); _exit=0
    "$SHGITTP" "$@" >"$out" 2>"$err" || _exit=$?
    _stdout=$(<"$out"); _stderr=$(<"$err"); rm -f "$out" "$err"
}

# ── Assertions ────────────────────────────────────────────────────────

assert_exit() {
    [[ "$_exit" == "$1" ]] && return 0; _failed=true
    FAILURES+=("$_name: exit $_exit ≠ expected $1")
    printf "    ${RED}exit %d ≠ %d${NC}\n" "$_exit" "$1" >&2
}

assert_contains() {
    local hay="$1" needle="$2" label="${3:-stdout}"
    [[ "$hay" == *"$needle"* ]] && return 0; _failed=true
    FAILURES+=("$_name: $label missing '$needle'")
    printf "    ${RED}%s missing: %s${NC}\n" "$label" "$needle" >&2
}

assert_not_contains() {
    local hay="$1" needle="$2" label="${3:-stdout}"
    [[ "$hay" != *"$needle"* ]] && return 0; _failed=true
    FAILURES+=("$_name: $label has unexpected '$needle'")
    printf "    ${RED}%s unexpected: %s${NC}\n" "$label" "$needle" >&2
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Mock SSH
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_mock_ssh() {
    local d="$1"
    mkdir -p "$d/bin"
    printf '1' > "$d/git_available"
    cat > "$d/bin/ssh" << 'MOCK'
#!/bin/sh
MOCK_DIR="${MOCK_DIR:?}"
printf '%s\n' "$*" >> "${MOCK_DIR}/ssh.log"
case "$*" in
  *'command -v git'*)
    cat "${MOCK_DIR}/git_available" 2>/dev/null || printf '1'
    ;;
  *)
    cat >> "${MOCK_DIR}/deploy_stdin" 2>/dev/null || true
    ;;
esac
exit 0
MOCK
    chmod +x "$d/bin/ssh"
}

mock_git_on()  { printf '1' > "$MOCK_DIR/git_available"; }
mock_git_off() { printf '0' > "$MOCK_DIR/git_available"; }
mock_log()     { cat "$MOCK_DIR/ssh.log" 2>/dev/null || true; }
mock_stdin()   { cat "$MOCK_DIR/deploy_stdin" 2>/dev/null || true; }

run_mocked() {
    local mock_dir="$1"; shift
    rm -f "$mock_dir/ssh.log" "$mock_dir/deploy_stdin"
    local out err; out=$(mktemp); err=$(mktemp); _exit=0
    env MOCK_DIR="$mock_dir" PATH="$mock_dir/bin:$PATH" \
        "$SHGITTP" "$@" >"$out" 2>"$err" || _exit=$?
    _stdout=$(<"$out"); _stderr=$(<"$err"); rm -f "$out" "$err"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Fixtures
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_config() {
    local file="$1"; shift
    local line; for line in "$@"; do printf '%s\n' "$line"; done > "$file"
}

create_local_repo() {
    local d="$1"
    mkdir -p "$d"
    (
        cd "$d" || exit 1
        git init -q
        git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
        git config user.email "test@test.com"
        git config user.name "Test"
        printf 'dotfile content\n' > file.txt
        printf '#!/bin/sh\necho setup\n' > setup.sh
        git add -A
        git commit -q -m "init"
    ) 2>/dev/null
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tests
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── CLI Parsing ──────────────────────────────────────────────────────

test_version() {
    begin "-v shows version"
    run_shgittp -v
    assert_exit 0
    assert_contains "$_stdout" "shgittp v"
    end
}

test_help() {
    begin "-h shows usage on stderr"
    run_shgittp -h
    assert_exit 0
    assert_contains "$_stderr" "Usage:" "stderr"
    assert_contains "$_stderr" "--repo" "stderr"
    assert_contains "$_stderr" "--branch" "stderr"
    end
}

test_no_target() {
    begin "no target shows usage"
    run_shgittp
    assert_exit 0
    assert_contains "$_stderr" "Usage:" "stderr"
    end
}

test_unknown_option() {
    begin "unknown option errors"
    run_shgittp --bogus testhost
    assert_exit 1
    assert_contains "$_stderr" "Unknown option" "stderr"
    end
}

test_missing_required_args() {
    begin "options requiring arguments fail without value"
    local flag
    for flag in -r -b -d -w -x -c; do
        run_shgittp "$flag"
        [[ "$_exit" -ne 0 ]] || {
            _failed=true
            FAILURES+=("$_name: $flag without arg should error")
            printf "    ${RED}%s without arg: exit %d ≠ 1${NC}\n" \
                "$flag" "$_exit" >&2
        }
    done
    end
}

test_cli_full_args() {
    begin "-r -b -d -w -x populate deployment plan"
    local cfg="$WORK_DIR/cfg_full.ini"; printf '' > "$cfg"
    run_shgittp --dry-run -c "$cfg" \
        -r git@example.com:u/d.git -b dev -d .cfg \
        -w /opt -x "./setup.sh" testhost
    assert_exit 0
    assert_contains "$_stderr" "d.git" "stderr"
    assert_contains "$_stderr" "(dev)" "stderr"
    assert_contains "$_stderr" ".cfg" "stderr"
    assert_contains "$_stderr" "/opt" "stderr"
    assert_contains "$_stderr" "setup.sh" "stderr"
    end
}

# ── Bash Completion ──────────────────────────────────────────────────

test_bash_completion() {
    begin "Bash completion registers options and config hosts"
    local completion="$PROJECT_ROOT/completions/shgittp.bash"
    local home="$WORK_DIR/completion-home"
    local output
    mkdir -p "$home/.config/shgittp"
    create_config "$home/.config/shgittp/config" \
        '[default]' \
        'branch = main' \
        '' \
        '[workstation]' \
        'repo = git@example.com:user/dots.git' \
        '' \
        '[workstation:nvim]' \
        'repo = git@example.com:user/nvim.git'

    output=$(HOME="$home" XDG_CONFIG_HOME="$home/.config" \
        bash -c '
            source "$1"
            COMP_WORDS=(shgittp wo)
            COMP_CWORD=1
            _shgittp_completion
            printf "host:%s\n" "${COMPREPLY[@]}"
            COMP_WORDS=(shgittp --st)
            COMP_CWORD=1
            _shgittp_completion
            printf "option:%s\n" "${COMPREPLY[@]}"
            complete -p shgittp
        ' _ "$completion")

    assert_contains "$output" "host:workstation" "completion"
    assert_not_contains "$output" "host:default" "completion"
    assert_not_contains "$output" "host:workstation:nvim" "completion"
    assert_contains "$output" "option:--strict" "completion"
    assert_not_contains "$output" "nospace" "completion"
    end
}

# ── Config Parsing ───────────────────────────────────────────────────

test_config_default_fallback() {
    begin "[default] section provides fallback values"
    local cfg="$WORK_DIR/cfg_default.ini"
    create_config "$cfg" \
        '[default]' \
        'branch = develop' \
        'dir = .dots' \
        '' \
        '[testhost]' \
        'repo = git@example.com:user/dots.git'
    run_shgittp --dry-run -c "$cfg" testhost
    assert_exit 0
    assert_contains "$_stderr" "develop" "stderr"
    assert_contains "$_stderr" ".dots" "stderr"
    end
}

test_config_host_match() {
    begin "host section overrides [default]"
    local cfg="$WORK_DIR/cfg_host.ini"
    create_config "$cfg" \
        '[default]' \
        'branch = main' \
        '' \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        'branch = production'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "production" "stderr"
    end
}

test_config_user_at_host() {
    begin "user@host section matches full target"
    local cfg="$WORK_DIR/cfg_uah.ini"
    create_config "$cfg" \
        '[admin@myhost]' \
        'repo = git@example.com:user/dots.git' \
        'branch = admin-dots'
    run_shgittp --dry-run -c "$cfg" admin@myhost
    assert_exit 0
    assert_contains "$_stderr" "admin-dots" "stderr"
    end
}

test_config_non_matching_ignored() {
    begin "non-matching host sections ignored"
    local cfg="$WORK_DIR/cfg_nomatch.ini"
    create_config "$cfg" \
        '[other-host]' \
        'repo = git@example.com:user/other.git' \
        '' \
        '[myhost]' \
        'repo = git@example.com:user/mine.git'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "mine.git" "stderr"
    assert_not_contains "$_stderr" "other.git" "stderr"
    end
}

test_config_suffix_multirepo() {
    begin "suffix keys create multiple deployment jobs"
    local cfg="$WORK_DIR/cfg_suffix.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        'dir = .cfg' \
        '' \
        'repo_nvim = git@example.com:user/nvim.git' \
        'dir_nvim = .nvim-git' \
        'tree_nvim = .config/nvim'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "dots.git" "stderr"
    assert_contains "$_stderr" "nvim.git" "stderr"
    assert_contains "$_stderr" ".nvim-git" "stderr"
    assert_contains "$_stderr" ".config/nvim" "stderr"
    end
}

test_config_cli_overrides() {
    begin "CLI -b overrides config branch"
    local cfg="$WORK_DIR/cfg_override.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        'branch = develop'
    run_shgittp --dry-run -c "$cfg" -b production myhost
    assert_exit 0
    assert_contains "$_stderr" "production" "stderr"
    end
}

test_config_comments_blanks() {
    begin "comments and blank lines ignored"
    local cfg="$WORK_DIR/cfg_comments.ini"
    create_config "$cfg" \
        '# Global settings' \
        '' \
        '[myhost]' \
        '# Main repository' \
        'repo = git@example.com:user/dots.git' \
        '' \
        'branch = main'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "dots.git" "stderr"
    end
}

test_config_malformed_lines() {
    begin "malformed config lines skipped gracefully"
    local cfg="$WORK_DIR/cfg_malformed.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        'this is garbage' \
        'random = nonsense = here' \
        'branch = main'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "dots.git" "stderr"
    assert_contains "$_stderr" "(main)" "stderr"
    end
}

test_config_quoted_values() {
    begin "quoted config values have quotes stripped"
    local cfg="$WORK_DIR/cfg_quoted.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = "git@example.com:user/dots.git"' \
        "branch = 'main'" \
        'dir = .dotfiles'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "dots.git" "stderr"
    assert_contains "$_stderr" "(main)" "stderr"
    assert_contains "$_stderr" ".dotfiles" "stderr"
    # Make sure quotes don't appear in output
    assert_not_contains "$_stderr" '"' "stderr"
    assert_not_contains "$_stderr" "'" "stderr"
    end
}

test_config_uppercase_suffix() {
    begin "uppercase suffix normalized to lowercase"
    local cfg="$WORK_DIR/cfg_upper.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        '' \
        'repo_NVIM = git@example.com:user/nvim.git' \
        'dir_NVIM = .nvim'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "dots.git" "stderr"
    assert_contains "$_stderr" "nvim.git" "stderr"
    end
}

test_config_fallback_chain() {
    begin "get() chain: suffix → default → built-in"
    local cfg="$WORK_DIR/cfg_chain.ini"
    create_config "$cfg" \
        '[default]' \
        'branch = develop' \
        'dir = .dots' \
        '' \
        '[myhost]' \
        'repo = git@example.com:user/main.git' \
        '' \
        'repo_work = git@example.com:user/work.git' \
        'branch_work = feature'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "develop" "stderr"
    assert_contains "$_stderr" "feature" "stderr"
    assert_contains "$_stderr" "work.git" "stderr"
    assert_contains "$_stderr" ".dots" "stderr"
    end
}

test_config_script_key() {
    begin "script config key sets the post-deploy command"
    local cfg="$WORK_DIR/cfg_script.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        'script = ./setup.sh'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" 'script="./setup.sh"' "stderr"
    end
}

test_config_legacy_run_key() {
    begin "deprecated run config key remains compatible"
    local cfg="$WORK_DIR/cfg_legacy_run.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        'run = ./legacy-setup.sh'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "Config key 'run' is deprecated" "stderr"
    assert_contains "$_stderr" 'script="./legacy-setup.sh"' "stderr"
    end
}

test_config_script_precedes_run() {
    begin "script config key takes precedence over deprecated run"
    local cfg="$WORK_DIR/cfg_script_precedence.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        'script = ./canonical.sh' \
        'run = ./legacy.sh'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" 'script="./canonical.sh"' "stderr"
    assert_not_contains "$_stderr" 'script="./legacy.sh"' "stderr"
    end
}

test_cli_r_creates_job() {
    begin "-r creates job without config entries"
    local cfg="$WORK_DIR/cfg_empty.ini"; printf '' > "$cfg"
    run_shgittp --dry-run -c "$cfg" \
        -r git@example.com:user/dots.git testhost
    assert_exit 0
    assert_contains "$_stderr" "dots.git" "stderr"
    end
}

test_default_config_path() {
    begin "default config path discovered when -c omitted"
    # Create config in default location under XDG_CONFIG_HOME
    local default_dir="$WORK_DIR/xdg_config"
    mkdir -p "$default_dir/shgittp"
    create_config "$default_dir/shgittp/config" \
        '[testhost]' \
        'repo = git@example.com:user/default.git'
    # Run without -c, relying on default path via XDG_CONFIG_HOME
    local out err; out=$(mktemp); err=$(mktemp)
    XDG_CONFIG_HOME="$default_dir" "$SHGITTP" --dry-run testhost >"$out" 2>"$err" || _exit=$?
    _stdout=$(<"$out"); _stderr=$(<"$err"); rm -f "$out" "$err"
    assert_exit 0
    assert_contains "$_stderr" "default.git" "stderr"
    end
}

# ── Dry Run ──────────────────────────────────────────────────────────

test_dry_run_plan() {
    begin "--dry-run shows plan with all fields"
    local cfg="$WORK_DIR/cfg_dryplan.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        'branch = main' \
        'dir = .cfg' \
        'script = ./setup.sh'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "DRY RUN" "stderr"
    assert_contains "$_stderr" "dots.git" "stderr"
    assert_contains "$_stderr" ".cfg" "stderr"
    assert_contains "$_stderr" "setup.sh" "stderr"
    end
}

test_dry_run_multirepo() {
    begin "--dry-run shows all suffix jobs"
    local cfg="$WORK_DIR/cfg_drymulti.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        'repo_nvim = git@example.com:user/nvim.git'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "dots.git" "stderr"
    assert_contains "$_stderr" "nvim.git" "stderr"
    end
}

test_dry_run_quiet() {
    begin "--dry-run -q suppresses all plan output"
    local cfg="$WORK_DIR/cfg_dryq.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git'
    run_shgittp --dry-run -q -c "$cfg" myhost
    assert_exit 0
    assert_not_contains "$_stderr" "DRY RUN" "stderr"
    assert_not_contains "$_stderr" "dots.git" "stderr"
    end
}

test_quiet_deploy() {
    begin "-q suppresses output during real deploy"
    mock_git_on
    local cfg="$WORK_DIR/cfg_quiet.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'
    run_mocked "$MOCK_DIR" -q -c "$cfg" mockhost
    assert_exit 0
    assert_not_contains "$_stderr" "Deploying" "stderr"
    assert_not_contains "$_stderr" "Done in" "stderr"
    end
}

# ── Deployment — Git Mode ────────────────────────────────────────────

test_git_mode_deploy_called() {
    begin "git mode: SSH invoked for deployment"
    mock_git_on
    local cfg="$WORK_DIR/cfg_gm1.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    local log; log=$(mock_log)
    assert_contains "$log" "mockhost" "ssh.log"
    end
}

test_git_mode_script_content() {
    begin "git mode: remote script has deploy function and repo"
    mock_git_on
    local cfg="$WORK_DIR/cfg_gm2.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git' \
        'dir = .dotfiles'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    local script; script=$(mock_stdin)
    assert_contains "$script" "deploy()" "deploy_script"
    assert_contains "$script" "git clone" "deploy_script"
    assert_contains "$script" "dots.git" "deploy_script"
    assert_contains "$script" ".dotfiles" "deploy_script"
    end
}

test_git_mode_nonstrict_default() {
    begin "git mode: StrictHostKeyChecking=no by default"
    mock_git_on
    local cfg="$WORK_DIR/cfg_gm3.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    local script; script=$(mock_stdin)
    assert_contains "$script" "StrictHostKeyChecking=no" "deploy_script"
    end
}

test_git_mode_strict() {
    begin "git mode: --strict enables host-key checking"
    mock_git_on
    local cfg="$WORK_DIR/cfg_gm4.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'
    run_mocked "$MOCK_DIR" --strict -c "$cfg" mockhost
    assert_exit 0
    local script; script=$(mock_stdin)
    assert_not_contains "$script" "StrictHostKeyChecking=no" "deploy_script"
    end
}

test_git_mode_shallow_default() {
    begin "git mode: shallow clone (--depth 1) by default"
    mock_git_on
    local cfg="$WORK_DIR/cfg_gm5.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    local script; script=$(mock_stdin)
    assert_contains "$script" "depth 1" "deploy_script"
    end
}

test_git_mode_full_clone() {
    begin "git mode: --full-clone omits depth"
    mock_git_on
    local cfg="$WORK_DIR/cfg_gm6.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'
    run_mocked "$MOCK_DIR" --full-clone -c "$cfg" mockhost
    assert_exit 0
    local script; script=$(mock_stdin)
    assert_not_contains "$script" "depth" "deploy_script"
    end
}

test_git_mode_script_command() {
    begin "git mode: script command passed to remote deploy"
    mock_git_on
    local cfg="$WORK_DIR/cfg_gm7.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git' \
        'script = bash setup.sh'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    local script; script=$(mock_stdin)
    assert_contains "$script" "setup.sh" "deploy_script"
    end
}

# ── Deployment — Bootstrap ───────────────────────────────────────────

test_bootstrap_triggered() {
    begin "bootstrap mode: triggered when remote lacks git"
    if [[ -z "$REPO_FIX" ]]; then
        skip "bootstrap triggered" "git not available"
        return
    fi
    mock_git_off
    local cfg="$WORK_DIR/cfg_boot1.ini"
    create_config "$cfg" \
        '[mockhost]' \
        "repo = $REPO_FIX" \
        'branch = main'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    assert_contains "$_stderr" "bootstrap" "stderr"
    end
}

test_bootstrap_ssh_transfer() {
    begin "bootstrap mode: SSH receives extraction script"
    if [[ -z "$REPO_FIX" ]]; then
        skip "bootstrap SSH transfer" "git not available"
        return
    fi
    mock_git_off
    local cfg="$WORK_DIR/cfg_boot2.ini"
    create_config "$cfg" \
        '[mockhost]' \
        "repo = $REPO_FIX" \
        'branch = main'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    local log; log=$(mock_log)
    assert_contains "$log" "command -v git" "ssh.log"
    assert_contains "$log" "Extracting" "ssh.log"
    end
}

# ── Multi-User Batching ─────────────────────────────────────────────

test_user_suffix_batching() {
    begin "user suffix creates separate SSH connections"
    mock_git_on
    local cfg="$WORK_DIR/cfg_batch.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        '' \
        'repo_root = git@example.com:user/root.git' \
        'user_root = root'
    run_mocked "$MOCK_DIR" -c "$cfg" dev@myhost
    assert_exit 0
    local log; log=$(mock_log)
    assert_contains "$log" "dev@myhost" "ssh.log"
    assert_contains "$log" "root@myhost" "ssh.log"
    end
}

test_same_user_multirepo_batching() {
    begin "same user with multiple repos batches into ONE SSH call"
    mock_git_on
    local cfg="$WORK_DIR/cfg_batch_same.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/dots.git' \
        '' \
        'repo_nvim = git@example.com:user/nvim.git' \
        '' \
        'repo_zsh = git@example.com:user/zsh.git'
    run_mocked "$MOCK_DIR" -c "$cfg" myhost
    assert_exit 0
    local log; log=$(mock_log)
    # Should have exactly ONE ssh invocation for the deploy (not counting git check)
    # Count occurrences of "myhost sh" (deploy script call)
    local count; count=$(printf '%s' "$log" | grep -c "myhost.* sh" || true)
    if [[ "$count" -ne 1 ]]; then
        _failed=true
        FAILURES+=("$_name: expected 1 SSH deploy call for myhost, got $count")
        printf "    ${RED}expected 1 SSH deploy call, got %d${NC}\n" "$count" >&2
    fi
    end
}

test_git_mode_failure_propagates() {
    begin "git mode: SSH failure propagates to exit code"
    # Create a mock that returns failure for git-mode deploy
    local fail_mock="$WORK_DIR/fail_mock"
    mkdir -p "$fail_mock/bin"
    cat > "$fail_mock/bin/ssh" << 'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "${MOCK_DIR}/ssh.log"
case "$*" in
  *'command -v git'*)
    cat "${MOCK_DIR}/git_available" 2>/dev/null || printf '1'
    ;;
  *)
    # Git mode: last arg is "sh" - fail this to test failure path
    if [[ "$*" == *" sh"* ]]; then
        exit 1
    fi
    cat >> "${MOCK_DIR}/deploy_stdin" 2>/dev/null || true
    ;;
esac
exit 0
MOCK
    chmod +x "$fail_mock/bin/ssh"

    local cfg="$WORK_DIR/cfg_fail_git.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'

    local out err; out=$(mktemp); err=$(mktemp)
    env MOCK_DIR="$MOCK_DIR" PATH="$fail_mock/bin:$PATH" \
        "$SHGITTP" -c "$cfg" mockhost >"$out" 2>"$err" || _exit=$?
    _stdout=$(<"$out"); _stderr=$(<"$err"); rm -f "$out" "$err"

    assert_exit 1
    end
}

# ── Validation ───────────────────────────────────────────────────────

test_no_config_for_target() {
    begin "no config and no -r errors with message"
    local cfg="$WORK_DIR/cfg_noconf.ini"; printf '' > "$cfg"
    run_shgittp -c "$cfg" nowhere
    assert_exit 1
    assert_contains "$_stderr" "No config" "stderr"
    end
}

test_job_missing_repo() {
    begin "job without repo URL errors"
    local cfg="$WORK_DIR/cfg_norepo.ini"
    create_config "$cfg" \
        '[myhost]' \
        'branch = main' \
        'dir = .cfg'
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 1
    assert_contains "$_stderr" "no repository URL" "stderr"
    end
}

test_explicit_config_missing() {
    begin "-c with nonexistent file errors"
    run_shgittp -c /tmp/nonexistent_shgittp_cfg_$$ testhost
    assert_exit 1
    assert_contains "$_stderr" "Config not found" "stderr"
    end
}

# ── Integration ──────────────────────────────────────────────────────

test_extra_ssh_args() {
    begin "-- passes extra arguments to SSH"
    mock_git_on
    local cfg="$WORK_DIR/cfg_extra.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost -- -p 2222
    assert_exit 0
    local log; log=$(mock_log)
    assert_contains "$log" "-p 2222" "ssh.log"
    end
}

test_extra_ssh_args_bootstrap() {
    begin "-- passes extra arguments to SSH in bootstrap mode"
    if [[ -z "$REPO_FIX" ]]; then
        skip "bootstrap extra args" "git not available"
        return
    fi
    mock_git_off
    local cfg="$WORK_DIR/cfg_extra_boot.ini"
    create_config "$cfg" \
        '[mockhost]' \
        "repo = $REPO_FIX" \
        'branch = main'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost -- -p 2222
    assert_exit 0
    local log; log=$(mock_log)
    assert_contains "$log" "-p 2222" "ssh.log"
    end
}

test_suffix_sanitization() {
    begin "config suffix with special chars rejected"
    local cfg="$WORK_DIR/cfg_sanitize.ini"
    create_config "$cfg" \
        '[myhost]' \
        'repo = git@example.com:user/safe.git' \
        "repo_evil;rm = git@example.com:user/evil.git"
    run_shgittp --dry-run -c "$cfg" myhost
    assert_exit 0
    assert_contains "$_stderr" "safe.git" "stderr"
    assert_not_contains "$_stderr" "evil.git" "stderr"
    end
}

test_forward_agent() {
    begin "SSH connections use ForwardAgent=yes"
    mock_git_on
    local cfg="$WORK_DIR/cfg_agent.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    local log; log=$(mock_log)
    assert_contains "$log" "ForwardAgent=yes" "ssh.log"
    end
}

test_alias_output() {
    begin "alias suggestions shown after deploy"
    mock_git_on
    local cfg="$WORK_DIR/cfg_alias.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git' \
        'dir = .cfg'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    assert_contains "$_stderr" "alias" "stderr"
    assert_contains "$_stderr" ".cfg" "stderr"
    end
}

test_elapsed_time() {
    begin "elapsed time shown in summary"
    mock_git_on
    local cfg="$WORK_DIR/cfg_time.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'
    run_mocked "$MOCK_DIR" -c "$cfg" mockhost
    assert_exit 0
    assert_contains "$_stderr" "Done in" "stderr"
    end
}

test_summary_suppressed_on_failure() {
    begin "summary output suppressed when deploy fails"
    # Use the failure mock from earlier test
    local fail_mock="$WORK_DIR/fail_mock2"
    mkdir -p "$fail_mock/bin"
    cat > "$fail_mock/bin/ssh" << 'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "${MOCK_DIR}/ssh.log"
case "$*" in
  *'command -v git'*)
    cat "${MOCK_DIR}/git_available" 2>/dev/null || printf '1'
    ;;
  *)
    if [[ "$*" == *" sh"* ]]; then
        exit 1
    fi
    ;;
esac
exit 0
MOCK
    chmod +x "$fail_mock/bin/ssh"

    local cfg="$WORK_DIR/cfg_fail_summary.ini"
    create_config "$cfg" \
        '[mockhost]' \
        'repo = git@example.com:user/dots.git'

    local out err; out=$(mktemp); err=$(mktemp)
    env MOCK_DIR="$MOCK_DIR" PATH="$fail_mock/bin:$PATH" \
        "$SHGITTP" -c "$cfg" mockhost >"$out" 2>"$err" || _exit=$?
    _stdout=$(<"$out"); _stderr=$(<"$err"); rm -f "$out" "$err"

    assert_exit 1
    assert_not_contains "$_stderr" "Done in" "stderr"
    assert_not_contains "$_stderr" "alias" "stderr"
    end
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Runner
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    printf "${BOLD}shgittp test suite${NC}  (%s)\n" "$SHGITTP"

    WORK_DIR=$(mktemp -d)
    MOCK_DIR="$WORK_DIR/mock"
    setup_mock_ssh "$MOCK_DIR"

    REPO_FIX=""
    if command -v git >/dev/null 2>&1; then
        REPO_FIX="$WORK_DIR/local_repo"
        create_local_repo "$REPO_FIX" 2>/dev/null || REPO_FIX=""
    fi

    section "CLI Parsing"
    test_version
    test_help
    test_no_target
    test_unknown_option
    test_missing_required_args
    test_cli_full_args
    test_default_config_path

    section "Bash Completion"
    test_bash_completion

    section "Config Parsing"
    test_config_default_fallback
    test_config_host_match
    test_config_user_at_host
    test_config_non_matching_ignored
    test_config_suffix_multirepo
    test_config_cli_overrides
    test_config_comments_blanks
    test_config_malformed_lines
    test_config_quoted_values
    test_config_uppercase_suffix
    test_config_fallback_chain
    test_config_script_key
    test_config_legacy_run_key
    test_config_script_precedes_run
    test_cli_r_creates_job

    section "Dry Run"
    test_dry_run_plan
    test_dry_run_multirepo
    test_dry_run_quiet
    test_quiet_deploy

    section "Deployment — Git Mode"
    test_git_mode_deploy_called
    test_git_mode_script_content
    test_git_mode_nonstrict_default
    test_git_mode_strict
    test_git_mode_shallow_default
    test_git_mode_full_clone
    test_git_mode_script_command
    test_git_mode_failure_propagates

    section "Deployment — Bootstrap"
    test_bootstrap_triggered
    test_bootstrap_ssh_transfer

    section "Multi-User Batching"
    test_user_suffix_batching
    test_same_user_multirepo_batching

    section "Validation"
    test_no_config_for_target
    test_job_missing_repo
    test_explicit_config_missing

    section "Integration"
    test_extra_ssh_args
    test_extra_ssh_args_bootstrap
    test_suffix_sanitization
    test_forward_agent
    test_alias_output
    test_elapsed_time
    test_summary_suppressed_on_failure

    # ── Report ───────────────────────────────────────────────────────
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

    printf "${GREEN}All tests passed.${NC}\n\n"
    exit 0
}

main "$@"
