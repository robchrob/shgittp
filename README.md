# shgittp
POSIX shell bootstrapper for bare-git dotfiles over SSH.
Single `sh` file, zero remote dependencies.

```sh
shgittp -r git@github.com:me/dots.git root@vps       # one-shot deploy
shgittp -i dev@devbox                                 # deploy + interactive shell
shgittp --dry-run my-server                           # show plan, skip execution
shgittp -x "./setup.sh" -b minimal user@alpine-box    # post-deploy hook
shgittp dev@endpoint -- -p 2222                       # extra SSH options
```

## Install
```sh
curl -fsSL \
  https://raw.githubusercontent.com/robchrob/shgittp/master/shgittp \
  -o ~/.local/bin/shgittp && chmod +x ~/.local/bin/shgittp
```

Or with make:
```sh
git clone https://github.com/robchrob/shgittp.git
cd shgittp && make install
```

## Output
```
$ shgittp dev@devbox
=> Deploying to dev@devbox (git)
[default] git@github.com:me/dots.git (minimal) -> ~/.dot

=> Done in 4s
   Git aliases for dotfile management:
  + alias cfg='git --git-dir=$HOME/.dot --work-tree=$HOME'
```

## Options
```
shgittp [options] [user@]host [-- ssh-opts]
```

| Flag | Description |
|------|-------------|
| `-r, --repo URL` | Repository URL |
| `-b, --branch NAME` | Branch (default: `main`) |
| `-d, --dir DIR` | Bare git-dir relative to `$HOME` |
| `-w, --work DIR` | Work tree (default: `$HOME`) |
| `-x, --run CMD` | Post-deploy command in work tree |
| `-c, --config FILE` | Config file path |
| `-i` | Interactive SSH session after deploy |
| `-q, --quiet` | Suppress non-essential output |
| `--full-clone` | Clone full history (default: shallow) |
| `--strict` | Enable strict SSH host-key checking |
| `--dry-run` | Show deployment plan, skip execution |
| `-v, --version` | Show version |
| `-h, --help` | Show help |

## Configuration
Config is read from `${XDG_CONFIG_HOME:-$HOME/.config}/shgittp/config`.
Standard INI format. Sections match hostnames.

**Precedence:** CLI flags → host section → `[default]` → built-in.

### Basics
```ini
[default]
branch = main
dir = .dotfiles

[my-vps]
repo = git@github.com:user/dotfiles.git
user = admin
run = ./setup.sh
```

```sh
shgittp my-vps    # uses config above
```

### Multi-repo (suffixes)
Append `_suffix` to any key to define additional repos on the same host.
Jobs deploy in parallel per connection.

```ini
[workstation]
# Main dotfiles → $HOME
repo = git@github.com:user/dotfiles.git
dir = .cfg

# Neovim config → ~/.config/nvim
repo_nvim = git@github.com:user/nvim-config.git
dir_nvim = .config/nvim/git
tree_nvim = .config/nvim

# Scripts → ~/.local/bin
repo_bin = git@github.com:user/scripts.git
dir_bin = .local/share/bin-git
tree_bin = .local/bin
```

### Mixed users
Deploy to multiple users on the same host by overriding `user_suffix`:

```ini
[endpoint]
repo = git@github.com:user/dotfiles.git
user = dev

repo_root = git@github.com:user/dotfiles.git
branch_root = minimal-root
dir_root = .cfg
tree_root = /root
user_root = root
```

## Deployment Modes
1. **Git mode** — remote has `git`: agent-forwarded bare clone +
   checkout directly on target. Updates via fetch on subsequent runs.
2. **Bootstrap mode** — remote lacks `git`: clone locally, pack into
   tarball, stream via SSH. Once `git` is installed remotely,
   subsequent runs use git mode automatically.

Both modes detect file conflicts and move existing files to
timestamped backups before checkout.

## Dependencies
| | Required |
|---|---|
| **Local** | `sh`, `ssh`, `git`, `tar` |
| **Remote** | `sh`, `ssh`, `tar` (`git` optional) |

## Contributing
Contributions welcome. Areas of interest:
- **Edge cases** — exotic platforms, connection scenarios.
- **Config features** — new per-host options.
- **Testing** — real-world feedback.

To contribute:
1. Edit `shgittp` / `README.md` / `CHANGELOG.md`
2. Run `make lint`
3. Open a PR

## License
MIT
