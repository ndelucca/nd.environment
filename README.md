# My Environment

For a long time I've been playing around with several linux distributions.

Current environment: Fedora Sway Spin

## Setup

Clone with submodules (the nvim config lives in a submodule). The repo can live
anywhere — the scripts derive their own location, so the clone path is free:

```bash
git clone --recurse-submodules https://github.com/ndelucca/nd.environment.git "${HOME}/nd.environment"

cd "${HOME}/nd.environment"

./fedora-sway-spin/bootstraping.sh
```

The bootstrap also runs `git submodule update --init --recursive`, so an existing
clone without `--recurse-submodules` is fixed automatically.

## Updating an existing machine

The bootstrap is idempotent, so updating is just pulling and re-running it:

```bash
git -C "${HOME}/nd.environment" pull --recurse-submodules
./fedora-sway-spin/bootstraping.sh   # re-stows dotfiles, reinstalls packages
```

Then update Neovim plugins from inside nvim: `:lua vim.pack.update()`.

Machine-specific values (timezone, git identity, keyboard, output names) live once
in `fedora-sway-spin/vars.sh`; on a new machine check the output names against
`swaymsg -t get_outputs`. The temperature sensor is auto-detected. `nd-doctor`
(run at the end of the bootstrap) verifies that what `vars.sh` declares matches
the machine.

### SSH (manual, per machine)

SSH keys are not stored in this repo. On each new machine generate a key and add
the public part to GitHub:

```bash
ssh-keygen -t ed25519 -C "ndelucca@protonmail.com"
cat ~/.ssh/id_ed25519.pub   # add this to GitHub → Settings → SSH keys
```

`~/.ssh/id_ed25519` is one of the identities ssh tries by default, so no extra
git or ssh config is needed.
