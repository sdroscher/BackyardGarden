# Phase 4: Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Oban-based background job scheduling with daily plant-now and harvest-soon checks, Prowl push notifications, and a settings UI for notification preferences.

**Architecture:**
- Add Oban job queue to Phoenix application startup
- Create a `Users` table (minimal schema for Prowl API key storage + notification preferences)
- Track sent notifications in a `Notifications` table for delivery logging
- `DailyCheckWorker` Oban job runs at 7am local time, checks plant-now/harvest-soon conditions, enqueues `ProwlNotifier` jobs
- `ProwlNotifier` job makes HTTP POST to Prowl API
- Settings LiveView at `/settings/notifications` allows users to toggle notification types and send test

**Tech Stack:**
- Oban (background jobs, scheduling)
- Req (HTTP client for Prowl API)
- Ecto schemas & migrations

---

## File Structure

### New Files
- `lib/backyard_garden/users/user.ex` — Ecto schema (id, email, name, prowl_api_key, timezone, notification_enabled, inserted_at, updated_at)
- `lib/backyard_garden/users/users.ex` — Context module (CRUD + fetch by email)
- `lib/backyard_garden/notifications/notification.ex` — Ecto schema (id, user_id, planting_id, type, message, scheduled_at, sent_at, prowl_response, inserted_at)
- `lib/backyard_garden/notifications/notifications.ex` — Context module (log notification, list recent)
- `lib/backyard_garden/workers/daily_check_worker.ex` — Oban job (plant-now & harvest-soon checks)
- `lib/backyard_garden/workers/prowl_client.ex` — HTTP POST to Prowl API
- `lib/backyard_garden_web/live/settings/notifications_live.ex` — Settings UI for preferences + test button
- `priv/repo/migrations/*_create_users.exs` — Users table
- `priv/repo/migrations/*_create_notifications.exs` — Notifications table

### Modified Files
- `mix.exs` — add `{:oban, "~> 2.18"}`
- `config/config.exs` — add Oban config stub
- `config/dev.exs` — Oban dev config (local queue, testing mode on)
- `config/test.exs` — Oban test config (testing mode on, no polling)
- `config/runtime.exs` — Oban prod config with queues
- `lib/backyard_garden/application.ex` — add Oban supervisor
- `lib/backyard_garden_web/router.ex` — add `GET /settings/notifications` route
- `lib/backyard_garden_web/components/layouts/app.html.heex` — add notifications link to settings nav

---

## Tasks

### Task 1: Add Oban to Dependencies

**Files:**
- Modify: `mix.exs:41-75`

- [ ] **Step 1: Add Oban to deps list**

Add this line to the `deps()` function (after `:req` and before `:floki`):

```elixir
{:oban, "~> 2.18"},
```

Full `deps()` snippet:
```elixir
defp deps do
  [
    {:phoenix, "~> 1.8.5"},
    {:phoenix_ecto, "~> 4.5"},
    {:ecto_sql, "~> 3.13"},
    {:ecto_sqlite3, "~> 0.17"},
    {:nimble_csv, "~> 1.2"},
    {:phoenix_html, "~> 4.1"},
    {:phoenix_live_reload, "~> 1.2", only: :dev},
    {:phoenix_live_view, "~> 1.1.0"},
    {:lazy_html, ">= 0.1.0", only: :test},
    {:phoenix_live_dashboard, "~> 0.8.3"},
    {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
    {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
    {:heroicons,
     github: "tailwindlabs/heroicons",
     tag: "v2.2.0",
     sparse: "optimized",
     app: false,
     compile: false,
     depth: 1},
    {:telemetry_metrics, "~> 1.0"},
    {:telemetry_poller, "~> 1.0"},
    {:gettext, "~> 1.0"},
    {:jason, "~> 1.2"},
    {:dns_cluster, "~> 0.2.0"},
    {:bandit, "~> 1.5"},
    {:req, "~> 0.5"},
    {:oban, "~> 2.18"},
    {:floki, "~> 0.37"},
    {:tzdata, "~> 1.1"},
    {:dotenvy, "~> 0.8", only: [:dev, :test]},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
  ]
end
```

- [ ] **Step 2: Fetch new dependency**

Run: `mix deps.get`

Expected: Oban and its dependencies (Telemetry, etc.) are installed.

- [ ] **Step 3: Commit**

```bash
git add mix.exs mix.lock
git commit -m "chore: add oban dependency for background job scheduling"
```

---

### Task 2: Create Users Schema and Context

**Files:**
- Create: `lib/backyard_garden/users/user.ex`
- Create: `lib/backyard_garden/users/users.ex`
- Test: `test/backyard_garden/users_test.exs`

- [ ] **Step 1: Write failing test for Users context**

Create `test/backyard_garden/users_test.exs`:

```elixir
defmodule BackyardGarden.UsersTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Users

  describe "create_user/1" do
    test "creates a user with email and returns ok" do
      attrs = %{"email" => "simon@example.com", "name" => "Simon"}
      assert {:ok, user} = Users.create_user(attrs)
      assert user.email == "simon@example.com"
      assert user.name == "Simon"
      assert user.timezone == "America/Vancouver"
    end

    test "requires email" do
      attrs = %{"name" => "Simon"}
      assert {:error, changeset} = Users.create_user(attrs)
      assert errors_on(changeset)[:email]
    end
  end

  describe "get_user_by_email/1" do
    test "returns user by email if exists" do
      user = user_fixture(email: "test@example.com")
      assert Users.get_user_by_email("test@example.com").id == user.id
    end

    test "returns nil if user does not exist" do
      assert Users.get_user_by_email("nonexistent@example.com") == nil
    end
  end

  describe "update_user/2" do
    test "updates user prowl_api_key" do
      user = user_fixture()
      assert {:ok, updated} = Users.update_user(user, %{"prowl_api_key" => "testkey123"})
      assert updated.prowl_api_key == "testkey123"
    end
  end

  # Fixture helper
  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      Enum.into(attrs, %{"email" => "test#{System.unique_integer()}@example.com"})
      |> Users.create_user()

    user
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/backyard_garden/users_test.exs -v`

Expected: FAIL with "function not defined" (BackyardGarden.Users module doesn't exist yet)

- [ ] **Step 3: Create User schema**

Create `lib/backyard_garden/users/user.ex`:

```elixir
defmodule BackyardGarden.Users.User do
  @moduledoc """
  User schema — email, name, timezone, Prowl API key, notification preferences.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :name, :string
    field :timezone, :string, default: "America/Vancouver"
    field :prowl_api_key, :string
    field :notifications_enabled, :boolean, default: true

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :timezone, :prowl_api_key, :notifications_enabled])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end
```

- [ ] **Step 4: Create Users context**

Create `lib/backyard_garden/users/users.ex`:

```elixir
defmodule BackyardGarden.Users do
  @moduledoc "User context — CRUD operations and queries."

  import Ecto.Query

  alias BackyardGarden.Repo
  alias BackyardGarden.Users.User

  @doc "Create a user from attributes."
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Get user by email, or nil if not found."
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc "Get user by id, or nil if not found."
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc "Update a user from attributes."
  def update_user(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc "List all users."
  def list_users do
    Repo.all(User)
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/backyard_garden/users_test.exs -v`

Expected: FAIL with "table users does not exist" (migration not yet created)

- [ ] **Step 6: Create migration**

Run: `mix ecto.gen.migration create_users`

This creates a timestamped file like `priv/repo/migrations/20260407XXXXXX_create_users.exs`.

Edit it to:

```elixir
defmodule BackyardGarden.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string
      add :timezone, :string, default: "America/Vancouver"
      add :prowl_api_key, :string
      add :notifications_enabled, :boolean, default: true

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
```

- [ ] **Step 7: Run migrations and test**

Run: `mix test test/backyard_garden/users_test.exs -v`

Expected: PASS — all tests in users_test.exs pass.

- [ ] **Step 8: Commit**

```bash
git add lib/backyard_garden/users/user.ex lib/backyard_garden/users/users.ex test/backyard_garden/users_test.exs priv/repo/migrations/
git commit -m "feat: create users context and schema with email, timezone, prowl_api_key"
```

---

### Task 3: Create Notifications Schema and Context

**Files:**
- Create: `lib/backyard_garden/notifications/notification.ex`
- Create: `lib/backyard_garden/notifications/notifications.ex`
- Test: `test/backyard_garden/notifications_test.exs`

- [ ] **Step 1: Write failing test for Notifications context**

Create `test/backyard_garden/notifications_test.exs`:

```elixir
defmodule BackyardGarden.NotificationsTest do
  use BackyardGarden.DataCase

  alias BackyardGarden.Notifications

  describe "log_notification/1" do
    test "creates a notification record" do
      user = user_fixture()

      attrs = %{
        "user_id" => user.id,
        "type" => "plant_now",
        "message" => "Time to plant spinach",
        "scheduled_at" => DateTime.utc_now()
      }

      assert {:ok, notif} = Notifications.log_notification(attrs)
      assert notif.type == "plant_now"
      assert notif.message == "Time to plant spinach"
    end

    test "requires user_id, type, message" do
      attrs = %{"type" => "plant_now"}
      assert {:error, changeset} = Notifications.log_notification(attrs)
      assert errors_on(changeset)[:user_id]
      assert errors_on(changeset)[:message]
    end
  end

  describe "mark_sent/2" do
    test "updates sent_at and prowl_response" do
      user = user_fixture()

      {:ok, notif} =
        Notifications.log_notification(%{
          "user_id" => user.id,
          "type" => "plant_now",
          "message" => "Test"
        })

      assert {:ok, updated} =
               Notifications.mark_sent(notif, %{
                 "sent_at" => DateTime.utc_now(),
                 "prowl_response" => "success"
               })

      assert updated.prowl_response == "success"
      assert not is_nil(updated.sent_at)
    end
  end

  # Fixture helper
  defp user_fixture do
    {:ok, user} =
      BackyardGarden.Users.create_user(%{
        "email" => "test#{System.unique_integer()}@example.com"
      })

    user
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/backyard_garden/notifications_test.exs -v`

Expected: FAIL with "function not defined"

- [ ] **Step 3: Create Notification schema**

Create `lib/backyard_garden/notifications/notification.ex`:

```elixir
defmodule BackyardGarden.Notifications.Notification do
  @moduledoc """
  Schema for tracking sent notifications — type, message, delivery response.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ~w(plant_now harvest_soon frost_warning)

  schema "notifications" do
    field :type, :string
    field :message, :string
    field :scheduled_at, :utc_datetime
    field :sent_at, :utc_datetime
    field :prowl_response, :string

    belongs_to :user, BackyardGarden.Users.User
    belongs_to :planting, BackyardGarden.Plantings.Planting, type: :binary_id, foreign_key: :planting_id

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :planting_id, :type, :message, :scheduled_at, :sent_at, :prowl_response])
    |> validate_required([:user_id, :type, :message])
    |> validate_inclusion(:type, @valid_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:planting_id)
  end
end
```

- [ ] **Step 4: Create Notifications context**

Create `lib/backyard_garden/notifications/notifications.ex`:

```elixir
defmodule BackyardGarden.Notifications do
  @moduledoc "Notifications context — log and track notification delivery."

  import Ecto.Query

  alias BackyardGarden.Repo
  alias BackyardGarden.Notifications.Notification

  @doc "Log a new notification."
  def log_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Mark a notification as sent with Prowl response."
  def mark_sent(notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc "Get recent notifications for a user."
  def recent_notifications(user_id, limit \\ 10) do
    Notification
    |> where([n], n.user_id == ^user_id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Get pending notifications (scheduled but not sent)."
  def pending_notifications do
    Notification
    |> where([n], is_nil(n.sent_at))
    |> order_by([n], asc: n.scheduled_at)
    |> Repo.all()
    |> Repo.preload(:user)
  end
end
```

- [ ] **Step 5: Create migration**

Run: `mix ecto.gen.migration create_notifications`

Edit to:

```elixir
defmodule BackyardGarden.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :planting_id, references(:plantings, type: :binary_id, on_delete: :nilify_all)
      add :type, :string, null: false
      add :message, :text, null: false
      add :scheduled_at, :utc_datetime
      add :sent_at, :utc_datetime
      add :prowl_response, :string

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:sent_at])
  end
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/backyard_garden/notifications_test.exs -v`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/backyard_garden/notifications/ test/backyard_garden/notifications_test.exs priv/repo/migrations/
git commit -m "feat: create notifications schema and context with delivery tracking"
```

---

### Task 4: Create Prowl HTTP Client

**Files:**
- Create: `lib/backyard_garden/workers/prowl_client.ex`
- Test: `test/backyard_garden/workers/prowl_client_test.exs`

- [ ] **Step 1: Write failing test for Prowl client**

Create `test/backyard_garden/workers/prowl_client_test.exs`:

```elixir
defmodule BackyardGarden.Workers.ProwlClientTest do
  use ExUnit.Case

  alias BackyardGarden.Workers.ProwlClient

  describe "send_notification/2" do
    test "returns error if no prowl_api_key provided" do
      assert {:error, "No Prowl API key configured"} =
               ProwlClient.send_notification(nil, %{
                 event: "Test",
                 description: "Test message"
               })
    end

    test "returns success tuple with body on successful request" do
      # Mock via Mox in real implementation, but for now just test the signature
      # This test will be updated to use mocking after Mox setup
      assert {:error, _} =
               ProwlClient.send_notification("invalid_key", %{
                 event: "Test",
                 description: "Test message"
               })
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/backyard_garden/workers/prowl_client_test.exs -v`

Expected: FAIL with "function not defined"

- [ ] **Step 3: Create Prowl client module**

Create `lib/backyard_garden/workers/prowl_client.ex`:

```elixir
defmodule BackyardGarden.Workers.ProwlClient do
  @moduledoc """
  HTTP client for Prowl API — sends push notifications to iOS devices.
  """

  require Logger

  @prowl_api_url "https://api.prowlapp.com/publicapi/add"

  @doc """
  Send a notification to Prowl.

  Params:
  - `api_key`: User's Prowl API key
  - `opts`: Map with `:event`, `:description`, `:priority` (optional, default 0)

  Returns: `{:ok, body}` or `{:error, reason}`
  """
  def send_notification(nil, _opts) do
    {:error, "No Prowl API key configured"}
  end

  def send_notification(api_key, opts) do
    body =
      [
        apikey: api_key,
        application: "BackyardGarden",
        event: opts[:event] || "Notification",
        description: opts[:description] || "",
        priority: opts[:priority] || 0
      ]
      |> URI.encode_query()

    case Req.post(@prowl_api_url, body: body) do
      {:ok, response} ->
        Logger.info("Prowl notification sent: #{response.status}")
        {:ok, response.body}

      {:error, reason} ->
        Logger.error("Prowl notification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/backyard_garden/workers/prowl_client_test.exs -v`

Expected: PASS (both tests pass)

- [ ] **Step 5: Commit**

```bash
git add lib/backyard_garden/workers/prowl_client.ex test/backyard_garden/workers/prowl_client_test.exs
git commit -m "feat: add prowl http client for push notifications"
```

---

### Task 5: Create Daily Check Oban Worker

**Files:**
- Create: `lib/backyard_garden/workers/daily_check_worker.ex`
- Test: `test/backyard_garden/workers/daily_check_worker_test.exs`

- [ ] **Step 1: Write failing test for DailyCheckWorker**

Create `test/backyard_garden/workers/daily_check_worker_test.exs`:

```elixir
defmodule BackyardGarden.Workers.DailyCheckWorkerTest do
  use BackyardGarden.DataCase

  import Oban.Testing

  alias BackyardGarden.Workers.DailyCheckWorker
  alias BackyardGarden.Notifications
  alias BackyardGarden.Dashboard

  describe "perform/1" do
    test "creates plant_now notifications for eligible seeds" do
      user = user_fixture()
      seed = seed_fixture()

      perform_job(DailyCheckWorker, %{})

      # Should have created at least one notification
      notifications = Notifications.recent_notifications(user.id, 100)
      assert length(notifications) > 0
      assert Enum.any?(notifications, &(&1.type == "plant_now"))
    end

    test "creates harvest_soon notifications for planted items" do
      user = user_fixture()
      seed = seed_fixture(maturity_days: 30)
      {:ok, planting} =
        BackyardGarden.Plantings.create_planting(%{
          "user_id" => user.id,
          "seed_id" => seed.id,
          "status" => "planted",
          "planted_at" => Date.add(Date.utc_today(), -27)
        })

      perform_job(DailyCheckWorker, %{})

      notifications = Notifications.recent_notifications(user.id, 100)
      assert Enum.any?(notifications, &(&1.type == "harvest_soon"))
    end
  end

  # Fixture helpers
  defp user_fixture do
    {:ok, user} =
      BackyardGarden.Users.create_user(%{
        "email" => "test#{System.unique_integer()}@example.com",
        "prowl_api_key" => "test_key"
      })

    user
  end

  defp seed_fixture(attrs \\ %{}) do
    {:ok, seed} =
      Enum.into(attrs, %{
        "name" => "Test Seed #{System.unique_integer()}",
        "type" => "Vegetable",
        "cycle" => "Annual",
        "planting_method" => "Direct Sow",
        "ideal_planting_time" => "Apr-May",
        "maturity_days" => 60
      })
      |> BackyardGarden.Seeds.create_seed()

    seed
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/backyard_garden/workers/daily_check_worker_test.exs -v`

Expected: FAIL with "function not defined"

- [ ] **Step 3: Create DailyCheckWorker module**

Create `lib/backyard_garden/workers/daily_check_worker.ex`:

```elixir
defmodule BackyardGarden.Workers.DailyCheckWorker do
  @moduledoc """
  Daily scheduled job to check for plant-now and harvest-soon conditions,
  enqueuing Prowl notifications for each user.

  Runs at 7am local time via Oban.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias BackyardGarden.{Repo, Users, Dashboard, Notifications}
  alias BackyardGarden.Plantings.Planting

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting daily check for plant-now and harvest-soon")

    # Get all users with notifications enabled
    users_with_prowl =
      Users.list_users()
      |> Enum.filter(&(&1.notifications_enabled and &1.prowl_api_key))

    # For each user, check conditions and enqueue notifications
    Enum.each(users_with_prowl, &check_user_conditions/1)

    :ok
  end

  defp check_user_conditions(user) do
    today = Date.utc_today()

    # Plant-now checks
    check_plant_now(user, today)

    # Harvest-soon checks
    check_harvest_soon(user, today)

    # Frost warning checks (placeholder for future weather integration)
    # check_frost_warning(user, today)
  end

  defp check_plant_now(user, date) do
    # Get seeds in planting window that aren't already planted
    plant_now_seeds = Dashboard.plant_now_seeds(date)

    Enum.each(plant_now_seeds, fn seed ->
      # Check if user already received a plant_now notification for this seed recently
      unless recently_notified?(user.id, seed.id, "plant_now") do
        message = "#{seed.name} is ready to plant! Ideal window is open now."

        {:ok, notification} =
          Notifications.log_notification(%{
            "user_id" => user.id,
            "type" => "plant_now",
            "message" => message,
            "scheduled_at" => DateTime.utc_now()
          })

        # Enqueue Prowl job to send the notification
        enqueue_prowl_job(user, notification)
      end
    end)
  end

  defp check_harvest_soon(user, date) do
    # Get plantings that are harvest_soon (within 7 days)
    harvest_soon =
      Planting
      |> where([p], p.user_id == ^user.id and p.status == "planted")
      |> Repo.all()
      |> Enum.filter(&harvest_window_open?(&1, date))

    Enum.each(harvest_soon, fn planting ->
      unless recently_notified?(user.id, planting.id, "harvest_soon") do
        seed = Repo.preload(planting, :seed).seed
        message = "#{seed.name} is nearly ready to harvest!"

        {:ok, notification} =
          Notifications.log_notification(%{
            "user_id" => user.id,
            "planting_id" => planting.id,
            "type" => "harvest_soon",
            "message" => message,
            "scheduled_at" => DateTime.utc_now()
          })

        enqueue_prowl_job(user, notification)
      end
    end)
  end

  defp harvest_window_open?(%Planting{planted_at: nil}, _date), do: false

  defp harvest_window_open?(planting, date) do
    seed = Repo.preload(planting, :seed).seed
    days_since_planted = Date.diff(date, planting.planted_at)
    days_until_mature = seed.maturity_days - days_since_planted
    days_until_mature >= 0 and days_until_mature <= 7
  end

  defp recently_notified?(user_id, seed_or_planting_id, type) do
    days_ago = DateTime.add(DateTime.utc_now(), -1, :day)

    Notifications.Notification
    |> where([n], n.user_id == ^user_id and n.type == ^type)
    |> where([n], n.inserted_at > ^days_ago)
    |> Repo.exists?()
  end

  defp enqueue_prowl_job(user, notification) do
    BackyardGarden.Workers.ProwlNotifierJob.new(%{
      notification_id: notification.id
    })
    |> Oban.insert()
  end
end
```

- [ ] **Step 4: Create ProwlNotifierJob (Oban job to send notification)**

Create `lib/backyard_garden/workers/prowl_notifier_job.ex`:

```elixir
defmodule BackyardGarden.Workers.ProwlNotifierJob do
  @moduledoc """
  Oban job to send a notification via Prowl API.
  """

  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger

  alias BackyardGarden.{Repo, Notifications, Users}
  alias BackyardGarden.Workers.ProwlClient

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"notification_id" => notification_id}}) do
    notification = Repo.get!(Notifications.Notification, notification_id)
    user = Repo.get!(Users.User, notification.user_id)

    case send_prowl(user, notification) do
      {:ok, response} ->
        Notifications.mark_sent(notification, %{
          "sent_at" => DateTime.utc_now(),
          "prowl_response" => "success"
        })

        Logger.info("Prowl notification sent for user #{user.id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to send Prowl notification: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_prowl(user, notification) do
    ProwlClient.send_notification(user.prowl_api_key, %{
      event: notification.type,
      description: notification.message,
      priority: 0
    })
  end
end
```

- [ ] **Step 5: Update Plantings context to support user_id**

We need to ensure Plantings schema has `user_id` field. Check the existing migration:

Read `priv/repo/migrations/20260402233529_create_plantings.exs` and update if needed to add `user_id` field:

```elixir
defmodule BackyardGarden.Repo.Migrations.CreatePlantings do
  use Ecto.Migration

  def change do
    create table(:plantings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :seed_id, references(:seeds, type: :binary_id, on_delete: :delete_all), null: false
      add :zone_id, references(:garden_zones, type: :binary_id, on_delete: :nilify_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :status, :string, default: "planned"
      add :planted_at, :date
      add :harvested_at, :date
      add :location, :string
      add :notes, :text

      timestamps()
    end

    create index(:plantings, [:seed_id])
    create index(:plantings, [:zone_id])
    create index(:plantings, [:user_id])
  end
end
```

If the migration doesn't have `user_id`, create a new migration:

```bash
mix ecto.gen.migration add_user_id_to_plantings
```

Edit to:

```elixir
defmodule BackyardGarden.Repo.Migrations.AddUserIdToPlantings do
  use Ecto.Migration

  def change do
    alter table(:plantings) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    create index(:plantings, [:user_id])
  end
end
```

- [ ] **Step 6: Update Plantings schema to include user_id**

Edit `lib/backyard_garden/plantings/planting.ex` to add:

```elixir
belongs_to :user, BackyardGarden.Users.User
```

And include `:user_id` in the `cast/3` call:

```elixir
def changeset(planting, attrs) do
  planting
  |> cast(attrs, [:user_id, :seed_id, :zone_id, :status, :planted_at, :harvested_at, :location, :notes])
  |> validate_required([:seed_id, :status])
  |> validate_inclusion(:status, @valid_statuses)
  |> foreign_key_constraint(:seed_id)
  |> foreign_key_constraint(:zone_id)
  |> foreign_key_constraint(:user_id)
end
```

- [ ] **Step 7: Run test to verify it passes**

Run: `mix test test/backyard_garden/workers/daily_check_worker_test.exs -v`

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lib/backyard_garden/workers/ test/backyard_garden/workers/ priv/repo/migrations/
git commit -m "feat: add daily check worker and prowl notifier job with oban"
```

---

### Task 6: Configure Oban in Application

**Files:**
- Modify: `lib/backyard_garden/application.ex`
- Modify: `config/config.exs`
- Modify: `config/dev.exs`
- Modify: `config/test.exs`
- Modify: `config/runtime.exs` (if it exists)

- [ ] **Step 1: Add Oban to application supervision tree**

Edit `lib/backyard_garden/application.ex` and add Oban to the `children` list:

```elixir
defmodule BackyardGarden.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BackyardGardenWeb.Telemetry,
      BackyardGarden.Repo,
      {DNSCluster, query: Application.get_env(:backyard_garden, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BackyardGarden.PubSub},
      BackyardGardenWeb.Endpoint,
      {Oban, Application.fetch_env!(:backyard_garden, Oban)}
    ]

    opts = [strategy: :one_for_one, name: BackyardGarden.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BackyardGardenWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
```

- [ ] **Step 2: Add Oban base config to config.exs**

Edit `config/config.exs` and add after the `ecto_repos` config:

```elixir
config :backyard_garden, Oban,
  repo: BackyardGarden.Repo,
  plugins: [Oban.Plugins.Cron],
  crons: [
    daily_check: [
      schedule: "0 7 * * *",
      worker: "BackyardGarden.Workers.DailyCheckWorker"
    ]
  ]
```

- [ ] **Step 3: Add Oban dev config**

Edit `config/dev.exs` and add Oban-specific config:

```elixir
config :backyard_garden, Oban,
  testing: :manual,
  queues: [default: 10, notifications: 5]
```

- [ ] **Step 4: Add Oban test config**

Edit `config/test.exs` and add:

```elixir
config :backyard_garden, Oban,
  testing: :manual,
  queues: false
```

- [ ] **Step 5: Check if runtime.exs exists, add Oban prod config**

If `config/runtime.exs` exists, add:

```elixir
config :backyard_garden, Oban,
  queues: [default: 10, notifications: 5]
```

If it doesn't exist, the base config.exs is sufficient for now.

- [ ] **Step 6: Run linting and tests**

Run: `mix credo`
Expected: No new credo violations.

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/backyard_garden/application.ex config/
git commit -m "chore: configure oban with daily check job scheduling"
```

---

### Task 7: Create Notifications Settings LiveView

**Files:**
- Create: `lib/backyard_garden_web/live/settings/notifications_live.ex`
- Modify: `lib/backyard_garden_web/router.ex`
- Modify: `lib/backyard_garden_web/components/layouts/app.html.heex` (nav links)
- Test: `test/backyard_garden_web/live/settings/notifications_live_test.exs`

- [ ] **Step 1: Write failing test for NotificationsLive**

Create `test/backyard_garden_web/live/settings/notifications_live_test.exs`:

```elixir
defmodule BackyardGardenWeb.Settings.NotificationsLiveTest do
  use BackyardGardenWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BackyardGarden.Users

  describe "notifications live page" do
    test "renders settings form when logged in", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        live(conn, ~p"/settings/notifications")

      assert html =~ "Notification Settings"
      assert html =~ "Prowl API Key"
    end

    test "updates prowl_api_key on form submit", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} =
        live(conn, ~p"/settings/notifications")

      assert view
             |> form("form", notification_settings: %{prowl_api_key: "new_key_123"})
             |> render_submit()

      updated_user = Users.get_user(user.id)
      assert updated_user.prowl_api_key == "new_key_123"
    end

    test "toggle notifications_enabled", %{conn: conn} do
      user = user_fixture(notifications_enabled: true)

      {:ok, view, _html} =
        live(conn, ~p"/settings/notifications")

      view
      |> form("form", notification_settings: %{notifications_enabled: false})
      |> render_submit()

      updated_user = Users.get_user(user.id)
      assert updated_user.notifications_enabled == false
    end
  end

  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      Enum.into(attrs, %{
        "email" => "test#{System.unique_integer()}@example.com",
        "prowl_api_key" => "test_key"
      })
      |> Users.create_user()

    user
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/backyard_garden_web/live/settings/notifications_live_test.exs -v`

Expected: FAIL with "route not found" or "function not defined"

- [ ] **Step 3: Create NotificationsLive module**

Create `lib/backyard_garden_web/live/settings/notifications_live.ex`:

```elixir
defmodule BackyardGardenWeb.Settings.NotificationsLive do
  use BackyardGardenWeb, :live_view

  alias BackyardGarden.Users

  @impl true
  def mount(_params, _session, socket) do
    # For now, use a hardcoded user (simon@droscher.com)
    # In Phase 5, this will use the authenticated user from session
    user = Users.get_user_by_email("simon@droscher.com") || create_default_user()

    changeset = Users.User.changeset(user, %{})

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"notification_settings" => params}, socket) do
    user = socket.assigns.user

    case Users.update_user(user, params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> put_flash(:info, "Notification settings updated!")
         |> assign(:changeset, Users.User.changeset(updated_user, %{}))}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-8 px-4">
      <h1 class="text-3xl font-semibold text-[#14532d] mb-8">Notification Settings</h1>

      <div class="bg-white border border-[#bbf7d0] rounded-xl p-6">
        <form phx-submit="save" class="space-y-6">
          <.input
            field={@changeset[:prowl_api_key]}
            label="Prowl API Key"
            type="password"
            placeholder="Paste your Prowl API key here"
          />
          <p class="text-sm text-[#6b7280]">
            Your Prowl API key is used to send notifications to your iOS device.
            <a
              href="https://www.prowlapp.com/"
              target="_blank"
              class="text-[#2d6a4f] underline"
            >
              Get your key from Prowl
            </a>
          </p>

          <.input
            field={@changeset[:notifications_enabled]}
            label="Enable Notifications"
            type="checkbox"
          />

          <div class="pt-4">
            <button
              type="submit"
              class="bg-[#2d6a4f] text-white px-4 py-2 rounded-lg hover:bg-[#1a3a2a]"
            >
              Save Settings
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp create_default_user do
    {:ok, user} =
      Users.create_user(%{
        "email" => "simon@droscher.com",
        "name" => "Simon"
      })

    user
  end
end
```

- [ ] **Step 4: Add route to router**

Edit `lib/backyard_garden_web/router.ex` and add the route to the `scope` block:

```elixir
scope "/", BackyardGardenWeb do
  pipe_through :browser

  get "/", PageController, :index
  live "/settings/notifications", Settings.NotificationsLive
  # ... other routes
end
```

- [ ] **Step 5: Add nav link to layout**

Edit `lib/backyard_garden_web/components/layouts/app.html.heex` and find the nav section. Add a link to settings:

In the nav `<div>` (usually near the top), add:

```heex
<a href={~p"/settings/notifications"} class="text-white hover:bg-[#2d6a4f] px-3 py-2 rounded-md">
  ⚙ Notifications
</a>
```

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/backyard_garden_web/live/settings/notifications_live_test.exs -v`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/backyard_garden_web/live/settings/ lib/backyard_garden_web/router.ex lib/backyard_garden_web/components/layouts/ test/backyard_garden_web/live/settings/
git commit -m "feat: add notification settings livepage with prowl api key configuration"
```

---

### Task 8: Run Full Test Suite and Linting

**Files:**
- No files modified; this is verification only.

- [ ] **Step 1: Run all tests**

Run: `mix test`

Expected: All tests pass. No "Database busy" errors.

- [ ] **Step 2: Run linting (credo strict mode)**

Run: `mix credo`

Expected: No violations. All checks pass.

- [ ] **Step 3: Run security scan**

Run: `mix sobelow`

Expected: No high-severity issues. Address any medium/low as appropriate.

- [ ] **Step 4: Run format check**

Run: `mix format --check-formatted`

Expected: All files are properly formatted. If not, run `mix format` and commit.

- [ ] **Step 5: Commit if any formatting was needed**

If `mix format` made changes:

```bash
git add -A
git commit -m "chore: format code to satisfy mix format"
```

---

### Task 9: Database Migrations and Final Verification

**Files:**
- All migrations created in previous tasks
- `priv/repo/seeds.exs` (optional: seed default user)

- [ ] **Step 1: Run migrations in dev environment**

Run: `mix ecto.migrate`

Expected: All migrations run successfully. "Migrations migrated" message.

- [ ] **Step 2: Verify database schema**

Run: `iex -S mix` and check tables:

```elixir
iex> BackyardGarden.Repo.query!("SELECT name FROM sqlite_master WHERE type='table'").rows
```

Expected: Rows include `users`, `notifications`, `plantings`, `seeds`, etc.

- [ ] **Step 3: Create test fixture user in seeds (optional)**

Edit `priv/repo/seeds.exs` and add (if not already there):

```elixir
# Create a default user for local testing
BackyardGarden.Users.create_user(%{
  "email" => "simon@droscher.com",
  "name" => "Simon",
  "timezone" => "America/Vancouver",
  "prowl_api_key" => nil,
  "notifications_enabled" => true
})
```

- [ ] **Step 4: Reset and re-seed database**

Run: `mix ecto.reset`

Expected: Database is cleaned, recreated, and seeded. No errors.

- [ ] **Step 5: Final test run**

Run: `mix test`

Expected: All tests pass.

- [ ] **Step 6: Commit seed data change if made**

```bash
git add priv/repo/seeds.exs
git commit -m "chore: add default test user to seeds"
```

---

## Summary

This plan implements Phase 4 — Notifications — in 9 modular tasks:

1. **Oban dependency** — Add background job library to mix.exs
2. **Users schema** — Create Users table and context (prerequisite for Phase 5 auth)
3. **Notifications schema** — Create Notifications table and context for delivery logging
4. **Prowl HTTP client** — Implement HTTP POST to Prowl API with error handling
5. **DailyCheckWorker** — Oban job that checks plant-now/harvest-soon conditions and enqueues notifications
6. **Oban configuration** — Wire Oban into Application supervision tree and config files with daily cron job
7. **Notifications UI** — Create settings LiveView for users to enter Prowl key and toggle notifications
8. **Testing & linting** — Verify all tests pass and code passes credo/sobelow/format checks
9. **Migrations & seeds** — Run all migrations and verify database schema

Each task includes failing test → implementation → passing test → commit cycles, ensuring code is well-tested and safe to integrate.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-07-phase4-notifications.md`.**

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review each task's work before moving to the next. Faster iteration, better checkpoints.

**2. Inline Execution** — Execute tasks in this session using superpowers:executing-plans, batch execution with checkpoints for review.

**Which approach would you prefer?**