v0.4.15
    - Nicer README
    - -c / --config custom configuration file flag
    - --dotfiles -> --dir

v0.4.14
    - Git bootstrapping: deploy to hosts without git installed
      - Auto-detects git availability on remote
      - Falls back to local clone + tar transfer when git unavailable
      - Transfers both bare repo and worktree (git works after installing git)
      - Seamless transition: run again with git for normal updates
    - Fix: config file detection uses -f instead of -d
    - Fix: CLI -r flag now creates a default job
    - Fix: Variable name sanitization for hostnames with hyphens
    - New docker variant: alpine-nogit for testing git bootstrap
    - New Makefile target: runnogit

v0.4.13
    - no separate backup var
    - simpler conf format
    - remove -A agent forward and do it by default
    - output alias info at the end of run

v0.4.12
    - configure per repo post script
    - better configuration handling (overwrite/precedence)
    - better configuration overally
    - better output / flow / feel / ux
    - improved usage string

v0.4.11
    - Smaller code
    - Faster git / --clone-full for full history
    - Parallel ssh per user (config suffix parsing)

v0.4.10
    - Code overhaul
    - Customizable work-tree (defaults to $HOME), -w, or --work-dir
    - Multi repo mode, complex config (per host deployment)

v0.4.5
    - Simpler ensure git, no static portable git (yet)
    - dry-run removed
    - shell after installation (--interactive)
