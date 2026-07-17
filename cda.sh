#!/usr/bin/env bash

CDA_CONFIG_DIR="${CDA_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/cda}"
ALIASES_FILE="${CDA_ALIASES_FILE:-${CDA_CONFIG_DIR}/aliases}"

exit_or_return() {
  local code=$1
  # If sourced, return; if executed directly, exit.
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return "$code"
  fi
  exit "$code"
}

print_usage() {
  cat <<EOF
Usage:
  cda <alias>                 Change to directory mapped by <alias>
  cda -a                      Add/update alias named after current directory
  cda -a <alias> [directory]  Add/update alias (directory defaults to current)
  cda -r                      Remove aliases pointing to current directory
  cda -r <alias>              Remove an alias
  cda -R                      Remove all aliases (requires confirmation)
  cda -l                      List all configured aliases
  cda -h                      Show this help message

Config:
  ${ALIASES_FILE}
EOF
}

ensure_aliases_file() {
  if [[ ! -f "$ALIASES_FILE" ]]; then
    mkdir -p "$(dirname "$ALIASES_FILE")"
    touch "$ALIASES_FILE"
    chmod 600 "$ALIASES_FILE" 2>/dev/null || true
  fi
}

validate_alias_name() {
  local alias_name=$1

  if [[ ! "$alias_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid alias '$alias_name'. Use only letters, numbers, '.', '_', and '-'." >&2
    return 1
  fi
}

normalize_directory() {
  local directory=$1

  if [[ ! -d "$directory" ]]; then
    echo "Directory does not exist: $directory" >&2
    return 1
  fi

  (cd "$directory" && pwd -P)
}

write_aliases_without_name() {
  local alias_name=$1

  awk -F '\t' -v alias_name="$alias_name" '$1 != alias_name' "$ALIASES_FILE"
}

add_alias() {
  local alias_name=$1
  local directory=$2
  local tmp_file

  validate_alias_name "$alias_name" || return 1
  directory=$(normalize_directory "$directory") || return 1

  tmp_file="$(mktemp)"
  write_aliases_without_name "$alias_name" > "$tmp_file"
  printf '%s\t%s\n' "$alias_name" "$directory" >> "$tmp_file"
  mv "$tmp_file" "$ALIASES_FILE"
  chmod 600 "$ALIASES_FILE" 2>/dev/null || true

  echo "Saved alias '$alias_name' -> '$directory'."
}

remove_alias() {
  local alias_name=$1
  local removed
  local tmp_file

  validate_alias_name "$alias_name" || return 1

  removed=$(awk -F '\t' -v alias_name="$alias_name" '$1 == alias_name { print $1 "\t" $2 }' "$ALIASES_FILE")
  if [[ -z "$removed" ]]; then
    echo "Alias '$alias_name' was not found in '$ALIASES_FILE'."
    return 1
  fi

  tmp_file="$(mktemp)"
  write_aliases_without_name "$alias_name" > "$tmp_file"
  mv "$tmp_file" "$ALIASES_FILE"
  chmod 600 "$ALIASES_FILE" 2>/dev/null || true

  awk -F '\t' '{ printf "Removed alias '\''%s'\'' -> '\''%s'\''.\n", $1, $2 }' <<<"$removed"
}

remove_aliases_for_directory() {
  local directory
  local removed
  local tmp_file

  directory=$(pwd -P)
  removed=$(awk -F '\t' -v directory="$directory" '$2 == directory { print $1 "\t" $2 }' "$ALIASES_FILE")

  if [[ -z "$removed" ]]; then
    echo "No aliases point to '$directory'."
    return 1
  fi

  tmp_file="$(mktemp)"
  awk -F '\t' -v directory="$directory" '$2 != directory' "$ALIASES_FILE" > "$tmp_file"
  mv "$tmp_file" "$ALIASES_FILE"
  chmod 600 "$ALIASES_FILE" 2>/dev/null || true

  awk -F '\t' '{ printf "Removed alias '\''%s'\'' -> '\''%s'\''.\n", $1, $2 }' <<<"$removed"
}

remove_all_aliases() {
  echo "This will remove ALL aliases from '$ALIASES_FILE'."
  echo "This action cannot be undone."
  read -r -p "Type 'yes' to continue: " confirmation

  if [[ "$confirmation" != "yes" ]]; then
    echo "Aborted. No aliases were removed."
    return 1
  fi

  : > "$ALIASES_FILE"
  chmod 600 "$ALIASES_FILE" 2>/dev/null || true
  echo "Removed all aliases from '$ALIASES_FILE'."
}

list_aliases() {
  local aliases
  aliases=$(awk -F '\t' 'NF >= 2 && $1 != "" { printf "%-20s %s\n", $1, $2 }' "$ALIASES_FILE")

  if [[ -z "$aliases" ]]; then
    echo "No aliases configured in '$ALIASES_FILE'."
    return
  fi

  echo "Configured aliases:"
  echo "$aliases"
}

lookup_alias() {
  local alias_name=$1

  awk -F '\t' -v alias_name="$alias_name" '
    $1 == alias_name {
      print $2
      found = 1
      exit
    }
    END {
      if (found) {
        exit 0
      }
      exit 1
    }
  ' "$ALIASES_FILE"
}

_cda_alias_names() {
  [[ -f "$ALIASES_FILE" ]] || return 0

  awk -F '\t' 'NF >= 2 && $1 != "" { print $1 }' "$ALIASES_FILE"
}

_cda_completion() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"

  local flags="-h --help -l --list -a -r -R --remove-all"

  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$flags $(_cda_alias_names)" -- "$cur"))
    return 0
  fi

  if [[ ${COMP_WORDS[1]} == "-r" ]]; then
    if [[ $COMP_CWORD -eq 2 ]]; then
      COMPREPLY=($(compgen -W "$(_cda_alias_names)" -- "$cur"))
    fi
    return 0
  fi

  if [[ ${COMP_WORDS[1]} == "-a" ]]; then
    if [[ $COMP_CWORD -eq 2 ]]; then
      COMPREPLY=($(compgen -W "$(_cda_alias_names)" -- "$cur"))
      return 0
    fi
    if [[ $COMP_CWORD -eq 3 ]]; then
      COMPREPLY=($(compgen -d -- "$cur"))
      return 0
    fi
  fi
}

complete -F _cda_completion cda

cda() {
  if [[ $# -eq 0 ]]; then
    echo "No arguments provided."
    print_usage
    return 1
  fi

  ensure_aliases_file

  if [[ $1 == "-h" || $1 == "--help" ]]; then
    print_usage
  elif [[ $1 == "-l" || $1 == "--list" ]]; then
    if [[ $# -ne 1 ]]; then
      echo "Invalid usage for list."
      print_usage
      return 1
    fi
    list_aliases
  elif [[ $1 == "-r" ]]; then
    if [[ $# -eq 1 ]]; then
      remove_aliases_for_directory
    elif [[ $# -eq 2 ]]; then
      remove_alias "$2"
    else
      echo "Invalid usage for remove."
      print_usage
      return 1
    fi
  elif [[ $1 == "-R" || $1 == "--remove-all" ]]; then
    if [[ $# -ne 1 ]]; then
      echo "Invalid usage for remove-all."
      print_usage
      return 1
    fi
    remove_all_aliases
  elif [[ $1 == "-a" ]]; then
    if [[ $# -gt 3 ]]; then
      echo "Invalid usage for add."
      print_usage
      return 1
    fi

    local target_directory
    local alias_name

    if [[ $# -eq 3 ]]; then
      target_directory=$3
    else
      target_directory=$(pwd -P)
    fi

    if [[ $# -ge 2 ]]; then
      alias_name=$2
    else
      alias_name=$(basename -- "$target_directory")
    fi

    add_alias "$alias_name" "$target_directory"
  else
    if [[ $# -ne 1 ]]; then
      echo "Invalid usage for change-directory."
      print_usage
      return 1
    fi

    local directory
    if ! directory=$(lookup_alias "$1"); then
      echo "Alias '$1' was not found in '$ALIASES_FILE'."
      echo "Use 'cda -l' to see available aliases."
      return 1
    fi

    if [[ ! -d "$directory" ]]; then
      echo "Alias '$1' points to a missing directory:"
      echo "  $directory"
      return 1
    fi

    cd "$directory" || return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cda "$@"
  exit_or_return $?
fi
