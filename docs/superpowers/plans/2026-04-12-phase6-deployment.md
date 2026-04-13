# Phase 6 — Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy BackyardGarden to Fly.io (SJC) with automatic DB migrations on deploy and GitHub Actions CI/CD.

**Architecture:** `fly launch` generates the Dockerfile and fly.toml baseline; we customize fly.toml for env vars and the migration release command; a deploy job is added to the existing CI workflow that runs `fly deploy --remote-only` after tests pass on pushes to `main`.

**Tech Stack:** Fly.io (flyctl), Elixir releases, Ecto.Migrator, GitHub Actions, `erlef/setup-beam`, `superfly/flyctl-actions`

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `lib/backyard_garden/release.ex` | Create | Release module — exposes `migrate/0` for the Fly release command |
| `Dockerfile` | Create (via fly launch) | Multi-stage Phoenix build |
| `fly.toml` | Create (via fly launch) + modify | App config, env vars, release command |
| `.github/workflows/ci.yml` | Modify | Add `deploy` job that runs `fly deploy` after tests pass on main |

---

## Task 1: Add the Release module

The release binary can't load Mix tasks, so DB migrations need a dedicated module that uses `Ecto.Migrator` directly. This is the standard Phoenix release pattern.

**Files:**
- Create: `lib/backyard_garden/release.ex`

- [ ] **Step 1: Create the release module**

```elixir
# lib/backyard_garden/release.ex
defmodule BackyardGarden.Release do
  @moduledoc """
  Tasks that run inside the production release binary, where Mix is unavailable.
  Called by the Fly.io release command before traffic switches to the new deployment.
  """

  @app :backyard_garden

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp load_app, do: Application.load(@app)

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
end
```

- [ ] **Step 2: Verify it compiles**

```bash
mix compile
```

Expected: no warnings or errors mentioning `BackyardGarden.Release`.

- [ ] **Step 3: Commit**

```bash
git add lib/backyard_garden/release.ex
git commit -m "feat: add Release module for production DB migrations"
```

---

## Task 2: Generate Dockerfile and fly.toml

`fly launch --no-deploy` detects the Phoenix project and generates a multi-stage Dockerfile and a `fly.toml` tuned for Phoenix on Fly.io.

**Prerequisites:** `flyctl` must be installed and authenticated (`fly auth login`). If not installed: `brew install flyctl`.

**Files:**
- Create: `Dockerfile` (generated)
- Create: `fly.toml` (generated)
- Create: `.dockerignore` (generated — if not already present)

- [ ] **Step 1: Run fly launch**

```bash
fly launch --no-deploy --region sjc
```

At the interactive prompts:
- **App name:** choose something like `backyard-garden` (must be globally unique on fly.io)
- **Organization:** personal
- **Region:** sjc (should be pre-selected from the flag)
- **Set up a Postgresql database?** → **No** (already attached from Phase 5.5)
- **Set up an Upstash Redis database?** → **No**
- **Create .dockerignore from .gitignore?** → **Yes**

This generates `Dockerfile`, `fly.toml`, and `.dockerignore`.

- [ ] **Step 2: Verify the generated files exist**

```bash
ls Dockerfile fly.toml .dockerignore
```

Expected: all three files listed.

- [ ] **Step 3: Check the Dockerfile compiles (dry run)**

```bash
head -20 Dockerfile
```

Expected: starts with `# Find eligible builder and runner images...` or a `FROM` instruction — confirms it's a valid multi-stage Phoenix Dockerfile.

---

## Task 3: Customize fly.toml

Add the migration release command and plain env vars. The generated `fly.toml` has most of what we need; we're adding the `[deploy]` block and `[env]` entries.

**Files:**
- Modify: `fly.toml`

- [ ] **Step 1: Open fly.toml and locate the `[env]` section**

If `[env]` already exists, add to it. If not, add the section. Set:

```toml
[env]
  PHX_SERVER = "true"
  PHX_HOST = "<appname>.fly.dev"
  DEFAULT_LOCATION = "Victoria,CA"
```

Replace `<appname>` with the actual app name chosen in Task 2 (e.g. `backyard-garden` → `backyard-garden.fly.dev`).

- [ ] **Step 2: Add the deploy release command**

Add (or replace) the `[deploy]` block:

```toml
[deploy]
  release_command = "/app/bin/backyard_garden eval BackyardGarden.Release.migrate()"
```

This runs after the new image is pulled but before traffic switches. If it exits non-zero, Fly aborts the deploy and keeps the old version live.

- [ ] **Step 3: Verify the region is sjc**

Look for `primary_region` in `fly.toml`:

```toml
primary_region = "sjc"
```

If it's set to something else, change it to `"sjc"`.

- [ ] **Step 4: Verify machine count and memory**

Look for a `[[vm]]` or `[machines]` section. The generated file typically has:

```toml
[[vm]]
  memory = "256mb"
  cpu_kind = "shared"
  cpus = 1
```

If memory is set higher (e.g. 1gb), change it to `"256mb"` — sufficient for this app and cheaper.

- [ ] **Step 5: Commit**

```bash
git add Dockerfile fly.toml .dockerignore
git commit -m "feat: add Dockerfile and fly.toml for Fly.io deployment"
```

---

## Task 4: Set Fly.io secrets — MANUAL STEP (done by you, not the agent)

> **CHECKPOINT — pause here.** Task 4 must be completed by the developer manually before the agent proceeds to Task 5. Do not continue until you confirm Task 4 is done.

Set all sensitive values as Fly secrets. These are injected at runtime and never stored in the repo.

**Prerequisites:** Fly app must exist (Task 2 created it). You'll need the values listed below.

- [ ] **Step 1: Generate SECRET_KEY_BASE**

```bash
mix phx.gen.secret
```

Copy the output — you'll use it in the next step.

- [ ] **Step 2: Generate CLOAK_KEY**

```bash
mix run -e 'IO.puts Base.encode64(:crypto.strong_rand_bytes(32))'
```

Copy the output.

- [ ] **Step 3: Set all secrets**

Run this command, substituting real values:

```bash
fly secrets set \
  SECRET_KEY_BASE="<output from step 1>" \
  CLOAK_KEY="<output from step 2>" \
  AUTH0_DOMAIN="<your-tenant>.auth0.com" \
  AUTH0_CLIENT_ID="<from Auth0 dashboard>" \
  AUTH0_CLIENT_SECRET="<from Auth0 dashboard>" \
  OPENWEATHERMAP_API_KEY="<your key>"
```

Note: `DATABASE_URL` should already be set from the Fly Postgres attachment in Phase 5.5. Verify:

```bash
fly secrets list
```

Expected output includes: `DATABASE_URL`, `SECRET_KEY_BASE`, `CLOAK_KEY`, `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`, `OPENWEATHERMAP_API_KEY`.

- [ ] **Step 4: Update Auth0 callback URL**

In the Auth0 dashboard → Applications → your app → Settings:

Add to **Allowed Callback URLs**:
```
https://<appname>.fly.dev/auth/auth0/callback
```

Add to **Allowed Logout URLs**:
```
https://<appname>.fly.dev
```

No commit needed — this is external config.

---

## Task 5: Add deploy job to CI workflow

Extend the existing `.github/workflows/ci.yml` to add a `deploy` job that runs after `quality` passes, but only on pushes to `main` (not PRs).

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add FLY_API_TOKEN to GitHub**

Generate a deploy token:

```bash
fly tokens create deploy
```

Copy the output. In GitHub: repo → Settings → Secrets and variables → Actions → New repository secret:
- Name: `FLY_API_TOKEN`
- Value: the token from above

- [ ] **Step 2: Add the deploy job to ci.yml**

Open `.github/workflows/ci.yml`. After the closing of the `quality` job, append:

```yaml
  deploy:
    name: Deploy to Fly.io
    runs-on: ubuntu-latest
    needs: [quality]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4

      - name: Set up flyctl
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy
        run: fly deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

This job:
- Only runs on pushes to `main` (skipped on PRs)
- Requires `quality` to pass first
- Builds the Docker image on Fly's remote builders (no local Docker needed)
- Runs migrations via the release command in fly.toml

- [ ] **Step 3: Verify the YAML is valid**

```bash
cat .github/workflows/ci.yml
```

Check that indentation is consistent (2 spaces) and the `deploy` job is at the same indentation level as `quality`.

- [ ] **Step 4: Commit and push**

```bash
git add .github/workflows/ci.yml
git commit -m "feat: add Fly.io deploy job to CI workflow"
git push origin phase6
```

The `deploy` job will NOT trigger yet (we're on `phase6`, not `main`). That's correct — it'll fire when the PR is merged.

---

## Task 6: First deploy and smoke test

Merge to main and verify the live app works end to end.

- [ ] **Step 1: Open PR and merge to main**

Create and merge the PR for `phase6` into `main`. Watch the GitHub Actions run:
1. `quality` job runs — tests + credo + sobelow
2. `deploy` job runs after quality passes — `fly deploy --remote-only`

You can watch Fly build logs in real time:

```bash
fly logs
```

- [ ] **Step 2: Verify the app is live**

```bash
fly status
```

Expected: `Machines: 1 running`

Visit `https://<appname>.fly.dev` in a browser. Expected: redirects to Auth0 login page.

- [ ] **Step 3: Log in and verify core features**

1. Log in via Auth0 → should land on the dashboard
2. Navigate to `/seeds` → verify seed library loads
3. Add a planting at `/garden` → verify DB read/write works
4. Check the weather card on dashboard → if blank, verify `OPENWEATHERMAP_API_KEY` is set (`fly secrets list`)

- [ ] **Step 4: Verify Oban is running**

```bash
fly ssh console -C "/app/bin/backyard_garden eval \"Oban.check_queue(:default)\""
```

Expected: returns `%{limit: ..., paused: false, ...}` — not an error.

- [ ] **Step 5: Update Plan.md and README.md**

In `Plan.md`, mark Phase 6 items complete:

```markdown
- [x] 6.1 Dockerfile (multi-stage, minimal image)
- [x] 6.2 fly.toml — Postgres-backed config
- [x] 6.3 Runtime config (env vars for Auth0 credentials, secrets, DATABASE_URL)
- [x] 6.4 fly.io deploy and smoke test
```

In `README.md`, add a **Deployment** section documenting:
- The live URL
- How to deploy (`git push origin main` triggers CI/CD)
- How to view logs (`fly logs`)
- How to SSH in (`fly ssh console`)
- Environment variables table (which are secrets vs fly.toml env vars)

- [ ] **Step 6: Commit**

```bash
git add Plan.md README.md
git commit -m "docs: mark Phase 6 complete, document deployment in README"
git push origin main
```
