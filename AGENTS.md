# AGENTS.md

## Project Overview
`shgittp` is a minimal, highly specialized POSIX/Bash script designed to bootstrap dotfiles via SSH using bare git repositories.
**Core Philosophy:** Ultra-minimal dependencies, high portability, and concise code. The tool must function on a bare-metal remote host with only basic Linux utilities (coreutils), `git`, and `sshd`. Plans to include bootstrapping basic git functionality to support bare clone and checkout with tree-dir when git is not available (using methods to be discussed, like writting core functoinality and plumbing).

## Code Style & Constraints
- **Language:** Migrating from Bash 4.0+ to strict POSIX `sh` compatibility (see `shgittp-sh`).
- **Formatting:** Keep code concise. One-liners are acceptable if readable. Prefer readability and compactness over verbose structures.
- **Safety:** Always use `set -eu` (or `set -euo pipefail` where applicable).
- **Dependencies:**
  - **Local:** `ssh`, `git`, `make`.
  - **Remote:** Payload must rely *only* on standard `sh`, `git`, and coreutils. NO external dependencies (no Python, no Node, no rsync).
- **Validation** Always validate the solutions by running against real docker environment through make
- **Refactoring Goals:**
  - Remove Bash-isms (e.g., avoid `declare -A`, `${var,,}`, `[[ ]]`). Use POSIX alternatives.
  - The logic is split between **Local Orchestration** (parsing config, parallel SSH) and **Remote Execution** (heredoc payload sent via SSH).

## Development Environment
The project uses a Docker-based test harness to simulate bare-metal environments.

### Commands
- **Build/Start Test Env:** `./docker/manage.sh <variant> <command>`
  - Variants: `alpine-basic` (user dev), `alpine-root` (root access).
  - Example: `./docker/manage.sh alpine-basic restart`
- **Install/Run:** `make run` (restarts container, reinstalls binary, runs against container).

### Configuration
- Config parser must handle INI-style sections: `[default]`, `[host]`, `[user@host]`.
- Logic for parsing must remain in pure `sh` (no `git config` dependency for parsing local files).

## Architecture & Internals
1.  **Orchestrator:** Parses `~/.config/shgittp/config`, resolves inheritance (Host -> Default), and groups jobs by connection string.
2.  **Transport:** SSH is used with agent forwarding enabled by default.
3.  **Payload:** A generated shell function (`deploy()`) is piped into `ssh`.
    - **Logic:** Check if git repo exists -> Clone/Fetch -> Checkout -> **Conflict Handling** (Move conflicting files to `backup-id-ts`) -> Run post-hooks.

## Current Objectives (Roadmap)
- **POSIX Migration:** Finalize the move to `sh` (removing associative arrays).
- **Conflict Checker:** Implement a CLI tool to list backup folders created during conflict resolution.
- **Naming:** Refine backup folder naming convention (`<env>-<resource>-<subconfig>`).
- **Git boostrap** Script that works without git binary available
