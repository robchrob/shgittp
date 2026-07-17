# Changelog
## v0.6.2
- Rename the canonical post-deploy config key from `run` to `script`
- Keep `run` as a deprecated config alias; `script` wins if both are set
- Show `script=` in dry-run deployment plans
- Install Bash completion with `make install` and document explicit activation
- Support Bash 3.2 and fix host discovery and normal completion spacing

## v0.6.1
- **BREAKING**: Replace suffix keys (`repo_nvim`, `dir_nvim`) with `[host:job]` subsections
- Config format: `[host]` → primary job, `[host:job]` → named job subsections  
- Keys are now lowercase throughout: `repo`, `branch`, `dir`, `tree`, `user`, `run`, `backup`
- Job names are normalized to lowercase and sanitized (alphanumeric + underscore only)
- Old suffix keys are silently ignored for backward compatibility
- Cleaner config parsing with explicit key validation
- Updated test suite with comprehensive job subsection coverage

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
- Bash completion
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
