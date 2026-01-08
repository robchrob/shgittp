# shgittp
**POSIX-compliant remote SSH dotfile manager.**

`shgittp` is a zero-dependency deployment tool that pushes bare git repositories (usually dotfiles) with specific work-tree set to remote hosts via SSH. It automates the [Atlassian "Bare Repository" pattern](https://www.atlassian.com/git/tutorials/dotfiles) to manage dotfiles on virtually all POSIX-like platforms.

**Why use this?**
*   **Minimal:** Requires no software installation on the remote target other than standard `sh`, `ssh`, and `tar`.
*   **No-git bootstrap:** Supports servers that lack `git` by cloning locally and streaming a tarball over SSH.
*   **Backup:** Automatically detects file conflicts and moves existing files to timestamped backups before checkout to avoid data loss.
*   **Flexibility:** Supports post-deployment hooks (`-x`) to allow run of setup scripts after provisioning.

### Synopsis
```sh
shgittp [-r URL] [-b BRANCH] [-w DIR] [-d DIR] [-x CMD] [-i] [--dry-run] [--full-clone] [user@]host
```

### Dependencies
*   **Local:** `sh`, `ssh`, `git`, `tar`.
*   **Remote:** `sh`, `ssh`, `tar`. (`git` is optional; enables native cloning if present).

### Installation
Download directly to your executable path.

```sh
curl -sSfL "https://raw.githubusercontent.com/robchrob/dotfiles-bare/develop/shgittp" \
  -o ~/.local/bin/shgittp && chmod +x ~/.local/bin/shgittp
```

### Configuration
Configuration is read from `${XDG_CONFIG_HOME:-$HOME/.config}/shgittp/config`.
Format is standard INI. Sections denote hostnames.

**Hierarchy:** CLI Arguments > Host Section > Default Section > Hardcoded Fallbacks.

```ini
# ~/.config/shgittp/config
[default]
repo = https://github.com/username/dotfiles.git
branch = main
dir = .cfg           # Bare git-dir location (~/.cfg)
tree =               # Work tree (defaults to $HOME)

# Host specific override
[vps-01]
user = admin
branch = production
run = ./setup.sh     # Executed inside work tree after deploy

# Multi-repo deployment using suffixes
[workstation]
# 1. Main dotfiles (mapped to $HOME)
repo = https://github.com/username/dotfiles.git
dir = .cfg
tree = .

# 2. Neovim config (mapped to ~/.config/nvim)
repo_nvim = https://github.com/username/nvim-config.git
dir_nvim = .local/share/nvim/git
tree_nvim = .config/nvim

# 3. Scripts (mapped to ~/.local/bin)
repo_bin = https://github.com/username/scripts.git
dir_bin = .local/share/bin/git
tree_bin = .local/bin
```

### Deployment Modes
1.  **Native:** If `git` is detected on remote, `shgittp` enables agent forwarding and performs a direct checkout.
2.  **Bootstrap:** If `git` is missing on remote, `shgittp` clones locally, creates a tar stream, and pipes it to the target work tree.

### Options
| Flag | Description |
| :--- | :--- |
| `-r, --repo URL` | Source repository URL. |
| `-b, --branch NAME` | Branch to checkout (default: `main`). |
| `-d, --dotfiles DIR` | Directory for the `.git` folder (relative to `$HOME`). |
| `-w, --work DIR` | Work tree directory (default: `$HOME`). |
| `-x, --run CMD` | Post-deployment command to execute in work tree. |
| `-i` | Launch interactive SSH session upon success. |
| `--dry-run` | Print deployment plan without executing. |

### Examples
**Provision fresh VPS (Explicit args):**
```sh
shgittp -r https://github.com/robchrob/dotfiles.git -b main root@192.168.1.50
```

**Bootstrap minimal box and run installer (No-Git mode):**
```sh
shgittp -r https://github.com/robchrob/alpine-dots.git -b main -x "./install.sh" user@alpine-box
```

**Deploy using config defaults:**
```sh
shgittp my-server
```

### License
MIT License. See [LICENSE](LICENSE) file for details.

### Author
robchrob / [dotfiles-bare](https://github.com/robchrob/dotfiles-bare)
