# shgittp — Minimal SSH dotfiles bootstrap

Tiny, POSIX/Bash script to clone and deploy dotfiles over SSH.

#TODO add info about ssh-key
#TODO RENAME PARAMS, SIMPLIFY

## Install (TODO determine)
```sh
curl -fsSL https://github.com.org/robchrob/shgittp/raw/main/shgittp -o /tmp/shgittp && \
  install -Dm755 /tmp/shgittp /usr/local/bin/shgittp
```

## Quick use
Bare-repo (default):
```sh
shgittp -r git@github.com:you/dotfiles.git user@host
```

Full clone:
```sh
shgittp --full-clone -r https://github.com/you/dotfiles.git -w .dotfiles user@host
```

Dry-run / interactive / post-run:
```sh
shgittp --dry-run -i -x 'cd .dotfiles && ./bootstrap' -r <repo> user@host
```

## Options (essentials)
`-r` repo, `-b` branch, `-w` work-tree, `-x` run cmd, `-i` interactive, `-d` dry-run, `--full-clone`.

## Config
`${XDG_CONFIG_HOME:-$HOME/.config}/shgittp/config` — simple `KEY="value"` and optional `[host]` sections. CLI overrides config.

## Safety
* Overwrites → moves to `${WORK_TREE}/${BACKUP_DIR_PREFIX}-<id>-<ts>`.
* `set -euo pipefail` and `--dry-run` for verification.

## License
MIT

Inspired by shittp. ([github.com][1])

[1]: https://github.com/FOBshippingpoint/shittp "FOBshippingpoint/shittp - GitHub"

