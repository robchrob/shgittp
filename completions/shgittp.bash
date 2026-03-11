#!/bin/bash
# bash completion for shgittp

_shgittp_completion() {
  local cur prev words cword
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  words=("${COMP_WORDS[@]}")
  cword=$COMP_CWORD

  local opts="-r --repo -b --branch -d --dir -w --work -x --run -c --config -i -q --quiet --full-clone --strict --dry-run -v --version -h --help --"

  case "$prev" in
    -r|--repo|-b|--branch|-d|--dir|-w|--work|-x|--run|-c|--config)
      # These flags expect arguments
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
  else
    # Try to complete hostnames from config or SSH known_hosts
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/shgittp/config"
    local hosts=""

    if [ -f "$config_file" ]; then
      hosts=$(grep -E '^\[[a-zA-Z0-9@._-]+\]' "$config_file" | sed 's/\[//;s/\]//' | sort -u)
    fi

    if [ -f "$HOME/.ssh/known_hosts" ]; then
      hosts="$hosts $(cut -d' ' -f1 "$HOME/.ssh/known_hosts" | grep -v '^\|' | sort -u)"
    fi

    COMPREPLY=( $(compgen -W "$hosts" -- "$cur") )
  fi
}

complete -o bashdefault -o default -o nospace -F _shgittp_completion shgittp
