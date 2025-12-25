shgittp Dependencies Analysis

Client-Side Dependencies (Local Machine)
    Required
    - bash (v4.0+) inb4 moved to v3.2 & ported to sh - payload is bash 3.0 compatibile
    - git (v1.6.5+)
    - openssh-client
    - coreutils
    - findutils
    Notes
    - HTTPS URLs require manual token setup in ~/.git-credentials on remote
    - SSH URLs require agent forwarding (-A flag) for authentication

TODO:
The script utilizes specific features that are not available in the older Bash 3.2 (which is the default on macOS) or Bash 3.0:
    Associative Arrays (declare -A): Used in lines like declare -A CFG SETS BATCHES. This feature was introduced in Bash 4.0.
    Case Modification (${var,,}): Used in the line SUFFIX="${BASH_REMATCH[2],,}" to convert the string to lowercase. This parameter expansion was introduced in Bash 4.0.
