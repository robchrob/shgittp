#!/usr/bin/env bash
# bash completion for shgittp

_shgittp_completion() {
  local cur prev config_file hosts candidate i
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local opts="-r --repo -b --branch -d --dir -w --work -x --run -c --config -i -q --quiet --full-clone --strict --dry-run -v --version -h --help --"

  for ((i = 1; i < COMP_CWORD; i++)); do
    [[ "${COMP_WORDS[i]}" == "--" ]] && return 0
  done

  case "$prev" in
    -c|--config)
      while IFS= read -r candidate; do
        COMPREPLY[${#COMPREPLY[@]}]="$candidate"
      done < <(compgen -f -- "$cur")
      return 0
      ;;
    -r|--repo|-b|--branch|-d|--dir|-w|--work|-x|--run)
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    while IFS= read -r candidate; do
      COMPREPLY[${#COMPREPLY[@]}]="$candidate"
    done < <(compgen -W "$opts" -- "$cur")
  else
    config_file="${XDG_CONFIG_HOME:-$HOME/.config}/shgittp/config"
    hosts=$(
      {
        if [[ -f "$config_file" ]]; then
          awk '
            /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
              section = $0
              sub(/^[[:space:]]*\[/, "", section)
              sub(/\][[:space:]]*$/, "", section)
              if (section == "default") next
              sub(/:.*/, "", section)
              print section
            }
          ' "$config_file"
        fi

        if [[ -f "$HOME/.ssh/known_hosts" ]]; then
          awk '
            $1 !~ /^\|/ {
              count = split($1, entries, ",")
              for (i = 1; i <= count; i++) print entries[i]
            }
          ' "$HOME/.ssh/known_hosts"
        fi
      } | sort -u
    )

    while IFS= read -r candidate; do
      COMPREPLY[${#COMPREPLY[@]}]="$candidate"
    done < <(compgen -W "$hosts" -- "$cur")
  fi
}

complete -o bashdefault -o default -F _shgittp_completion shgittp
