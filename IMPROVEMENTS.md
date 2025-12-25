Requirements:
Minimalistic but complete (current parameters are enough), we need to work on determining if these below are done as we would expect.
Code must be highly specialized, concise, minimalistic but fully functional.
Must be ultra to the point, all heavylifting must be done in shgittp, but we also need to keep code readable and short.


TODO
- so, lets work on dotfiles-alpine repository with branching strategy (aarch64-v3.22.2-usr, aarch64-v3.22.2-root, aarch64-v3.22.2-etc...
- workflow for naming, branching etc... (docker-latest-* better?)
- conflicts checker cli tool (sh) - runs alongside with cfg-suffix  (so we can list all conflicts backups created sorted by most recent)

--

- minor, fix cfg lg log etc (diff-so-fancy dep)


so,

something like

<env>-<resource>-<subconfig>
