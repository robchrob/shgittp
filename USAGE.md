(DRAFT)

Uses ssh + git (including bootstrapping on bare machine)

shgittp -A -r git@github.com:robchrob/dotfiles-bare.git -b shgittp -x "bash .config/setup.sh" devbox

Idea is to have minimal dependencies on host (network and basic linux) is enough to use git and bare git repo as dotfile manager.

It's pretty fast, steerable and overally cool.
