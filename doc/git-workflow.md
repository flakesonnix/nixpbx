# Git Workflow

Branch model: **main** is stable + deployable. All work goes through feature
branches and PRs. No direct pushes to main.

---

## Branch naming

```
feat/freepbx-<short-desc>     new capability
fix/freepbx-<short-desc>      bug fix
chore/<short-desc>             tooling, deps, formatting
nixos/<module-name>            NixOS module changes
doc/<topic>                    documentation only
```

---

## Day-to-day flow

```bash
# 1. Start from fresh main
git switch main && git pull --rebase origin main

# 2. Create feature branch
git switch -c feat/freepbx-add-fail2ban

# 3. Work in small atomic commits
#    Subject ≤ 50 chars, conventional prefix, imperative mood
git add nixos/modules/freepbx.nix
git commit -m "nixos/freepbx: integrate fail2ban for SIP auth failures"

# 4. Before pushing: rebase onto main to keep history linear
git fetch origin
git rebase origin/main

# 5. Push + open PR
git push -u origin feat/freepbx-add-fail2ban
gh pr create --fill
```

---

## Commit conventions

Follow nixpkgs commit message style:

```
<scope>: <short imperative description>

<optional body — explain WHY, not what>
<reference upstream issues/PRs if relevant>
```

Valid scopes:

| Scope | Use for |
|---|---|
| `freepbx` | Package derivation changes |
| `nixos/freepbx` | NixOS module changes |
| `tests` | Test additions or fixes |
| `doc` | Documentation |
| `flake` | flake.nix changes |
| `chore` | Formatting, tooling, deps |

Examples:

```
freepbx: update to 17.0.1

Upstream patched a PHP session race condition.
https://github.com/FreePBX/framework/issues/1234

nixos/freepbx: add services.freepbx.timezone option

Asterisk needs TZ set at the process level, not just system-wide,
because PHP-FPM pool inherits a bare environment.

chore: run nixpkgs-fmt over all Nix files
```

---

## Hash update workflow

When upstream tags a new release or module:

```bash
# Get the new hash for a single source
nix-prefetch-url --unpack \
  https://github.com/FreePBX/framework/archive/release/17.0.tar.gz

# Or use nix-update (in devShell):
nix develop
nix-update freepbx --version 17.0.1

# Update composer vendor hash after framework update:
# 1. Set outputHash = "" in composer-env.nix temporarily
# 2. nix build .#freepbx 2>&1 | grep 'got:'
# 3. Paste the printed hash back into outputHash
```

Commit hash updates as:

```
freepbx: update hashes for 17.0.1 release
```

---

## PR checklist

Before requesting review:

- [ ] `nixpkgs-fmt --check **/*.nix` — no formatting issues
- [ ] `statix check .` — no static analysis warnings
- [ ] `deadnix **/*.nix` — no dead code
- [ ] `nix flake check --no-build` — flake evaluates cleanly
- [ ] `nix eval .#packages.x86_64-linux.freepbx` — package evaluates
- [ ] `nix eval .#nixosModules.freepbx` — module evaluates
- [ ] At least one relevant test added or updated
- [ ] `doc/options.md` updated if new options were added

---

## Release tagging

```bash
# On main after merging a batch of changes:
git tag -a v17.0.1 -m "freepbx 17.0.1"
git push origin v17.0.1
```

Tag format: `v<upstream-version>[-nix<patch>]`  
- `v17.0.0` — first packaging of FreePBX 17.0.0  
- `v17.0.0-nix1` — Nix packaging fix, no upstream version change  
- `v17.0.1` — packaging of upstream 17.0.1  

---

## Running tests locally

```bash
# All checks (VM tests boot QEMU — requires KVM)
nix flake check

# Single test
nix build .#checks.x86_64-linux.basic
nix build .#checks.x86_64-linux.database

# Pure eval test (no VM, fast)
nix build .#checks.x86_64-linux.module-options

# Dev shell for linting tools
nix develop
nixpkgs-fmt **/*.nix
statix check .
deadnix --edit **/*.nix
```

---

## Merge policy

- Squash-merge is **not** used — preserve individual commits for `git blame` clarity.
- Rebase-merge onto main to keep linear history.
- Delete branch after merge.
- No force-push to main or to any branch with an open PR.
