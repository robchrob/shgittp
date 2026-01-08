Git without git.

Right, we want to handle systems without git - just sh/coreutils. We must do all the basic operations somehow or bootstrap ourselfs platform independently.
Looks like a complex and trick feature. It must be throughtly discussed and checked.

For that we want to have another docker environment without git and iterate on the solution.

--

The xargs -0 Issue:

    Line 124: ... ls-tree -rz ... | xargs -0 ...

    Critique: xargs -0 (and ls-tree -z) is not POSIX. It works on GNU (Linux) and BSD (macOS), but it will fail on Solaris, AIX, or stripped-down BusyBox environments found on some embedded routers/IoT devices.

    Verdict: For a dotfile manager, this is acceptable (you are likely targeting Linux/BSD servers), but if you want strict POSIX purity, you have to loop over the output or use find -exec.

mktemp:

    mktemp -d is widely supported but technically behaves differently on BSD vs GNU regarding template requirements. In your usage (mktemp -d), it will work on 99% of modern systems.


StrictHostKeyChecking=no:
    Line 115: export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no ...'
    Critique: This makes automation smooth but disables Man-in-the-Middle protection for the git clone operation. For a personal tool, this is usually a calculated risk, but be aware of it.

    flag to disable this (off by default, like --strict)


---

To achieve that "low-level Linux druid" status (think tools like `fzf`, `ripgrep`, or suckless tools), the repository structure needs to be flat, predictable, and standards-compliant.

Here is the blueprint to take `shgittp` from a script to a **Project**.

### 1. The Directory Structure

Keep it clean. Do not hide the script deep in a `src` folder.

```text
.
├── shgittp              # The executable script (no extension)
├── LICENSE              # MIT License
├── README.md            # The documentation we wrote
├── Makefile             # Standard UNIX install interface
├── man/
│   └── shgittp.1        # ROFF format manual page (The "Pro" move)
├── completions/         # Shell completions (optional but nice)
│   ├── _shgittp         # Zsh completion
│   └── shgittp.bash     # Bash completion
├── tests/
│   └── shellcheck.sh    # CI script
└── .github/
    └── workflows/
        └── ci.yml       # Github Actions config
```

### 2. The Missing "Pro" Artifacts

#### A. The Makefile
A true UNIX tool allows installation via `make install`. This signals you understand how system paths work.

```makefile
PREFIX ?= /usr/local
MANPREFIX ?= $(PREFIX)/share/man

install:
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f shgittp $(DESTDIR)$(PREFIX)/bin/shgittp
	chmod 755 $(DESTDIR)$(PREFIX)/bin/shgittp
	mkdir -p $(DESTDIR)$(MANPREFIX)/man1
	cp -f man/shgittp.1 $(DESTDIR)$(MANPREFIX)/man1/shgittp.1
	chmod 644 $(DESTDIR)$(MANPREFIX)/man1/shgittp.1

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/shgittp
	rm -f $(DESTDIR)$(MANPREFIX)/man1/shgittp.1

.PHONY: install uninstall
```

#### B. The Man Page (`man/shgittp.1`)
Nothing says "professional CLI" like typing `man shgittp` and seeing a properly formatted manual.
*   **Format:** It must be written in ROFF (groff).
*   **Content:** Synopsis, Description, Options, Exit Status, Bugs.
*   *Tip:* You can use `pandoc` to convert your README to a man page, but writing raw ROFF earns more geek cred.

#### C. Semantic Versioning & Releases
Don't just push to main.
1.  **Tags:** Create git tags for versions: `git tag -a v0.4.15 -m "release 0.4.15"`.
2.  **GitHub Releases:** When you push a tag, use GitHub's "Releases" feature. Attach the raw script as a binary asset. This allows users to download specific frozen versions rather than the unstable `develop` branch.

### 3. GitHub Metadata (The "Discovery" Layer)

To be found alongside tools like `chezmoi` or `yadm`, you need the right metadata.

**Description:**
> Zero-dependency POSIX shell bootstrapper for bare-git dotfiles over SSH.

**Topics (Tags):**
Add these to the "About" section of your repo:
*   `dotfiles`
*   `dotfiles-manager`
*   `git-bare`
*   `posix-sh`
*   `provisioning`
*   `ssh-automation`
*   `shell-script`

### 4. CI/CD (The Quality Gate)

Since you are writing POSIX sh, you **must** enforce it. If you break POSIX compliance, the "minimalist" crowd will eat you alive.

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on: [push, pull_request]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run ShellCheck
        # Check for POSIX sh compliance (-s sh)
        run: shellcheck -s sh shgittp
  
  # Optional: Test installation
  test-install:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: make install PREFIX=$HOME/.local
      - run: ~/.local/bin/shgittp --version
```

### 5. One "Gotcha" to Avoid

**Do not add an extension (`.sh`) to the file in the repo.**
Name it `shgittp`, not `shgittp.sh`.
*   **Why?** When people install it to `/usr/local/bin`, they want to type `shgittp`, not `shgittp.sh`.
*   **How:** Just add a shebang `#!/bin/sh` at the top (you already did) and `chmod +x shgittp`. Editors will recognize it as shell script automatically.

### Summary Checklist for v0.5

1.  [ ] Rename script to `shgittp` (no extension).
2.  [ ] Add the `Makefile`.
3.  [ ] Generate a `man` page.
4.  [ ] Add `.github/workflows/ci.yml` running `shellcheck`.
5.  [ ] Tag the release on GitHub.
