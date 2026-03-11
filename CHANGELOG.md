# Changelog

## v0.5.0
- Color output with terminal detection
- `--full-clone`: opt into full git history (default: `--depth 1`)
- `--strict`: enable SSH strict host-key checking for remote git
- `-q, --quiet`: suppress non-essential output
- POSIX compliance: replace `xargs -0` with `while read` loop
- Robust job tracking (replaces `set | sed` heuristic)
- Config suffix sanitization (alphanumeric + underscore only)
- Flexible CLI parsing: options accepted in any order
- `[user@]host -- ssh-opts` for extra SSH arguments
- Deployment timing in summary output
- Repo URL validation before execution
- Man page (`man shgittp`)
- Bash and Zsh completions
- ShellCheck CI via GitHub Actions
- Proper `make install` / `make uninstall` with PREFIX

## v0.4.15
- Nicer README
- `-c` / `--config` custom configuration file flag
- `--dotfiles` → `--dir`

## v0.4.14
- Git bootstrapping: deploy to hosts without git installed
  - Auto-detects git availability on remote
  - Falls back to local clone + tar transfer
  - Transfers both bare repo and worktree
- Fix: config file detection uses `-f` instead of `-d`
- Fix: CLI `-r` flag now creates a default job
- Fix: variable name sanitization for hostnames with hyphens

## v0.4.13
- Simpler conf format
- Agent forwarding enabled by default (`-A` flag removed)
- Output alias info at the end of run

## v0.4.12
- Per-repo post-deploy scripts
- Better configuration handling (overwrite/precedence)
- Improved UX and output

## v0.4.11
- Smaller code
- Faster git / `--full-clone` for full history
- Parallel SSH per user (config suffix parsing)

## v0.4.10
- Code overhaul
- Customizable work-tree (`-w` / `--work`)
- Multi-repo mode, complex config (per host deployment)

## v0.4.5
- Interactive shell after installation (`-i`)
