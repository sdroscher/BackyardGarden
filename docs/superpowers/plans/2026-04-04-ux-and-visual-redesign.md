# UX & Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix disconnected workflows, add in-season signals throughout, improve calendar readability, and apply the Garden Journal visual aesthetic across all pages.

**Architecture:** UX logic changes (quick-log form, in-season status, calendar chips) live in existing LiveView modules and context helpers. Visual changes are purely template/CSS — no new modules needed. The layout is already wired up (`app.html.heex` exists and `live_view/0` sets it as the default layout).

**Tech Stack:** Elixir, Phoenix LiveView 1.8, Tailwind CSS (arbitrary values), SQLite3, HEEx templates. Tests use `ExUnit` with `async: false` for LiveView/DB tests and `async: true` for pure computation.

---

## File Map

| File | Role |
|---|---|
| `lib/backyard_garden_web/components/layouts/app.html.heex` | Nav with active state |
| `lib/backyard_garden_web/components/layouts/root.html.heex` | Page background colour |
| `lib/backyard_garden/weather/tips.ex` | New `contextual_message/2` function |
| `lib/backyard_garden_web/live/dashboard/index_live.ex` | Quick-log events + assigns, greeting, contextual message |
| `lib/backyard_garden_web/live/dashboard/index_live.html.heex` | Dashboard visual redesign + quick-log form |
| `lib/backyard_garden_web/live/seeds/index_live.ex` | In-season status precomputation |
| `lib/backyard_garden_web/live/seeds/index_live.html.heex` | Seed library visual + in-season column |
| `lib/backyard_garden_web/live/seeds/show_live.ex` | Log planting form events + in-season assign |
| `lib/backyard_garden_web/live/seeds/show_live.html.heex` | Seed detail visual + Log Planting form |
| `lib/backyard_garden_web/live/calendar/index_live.ex` | events_by_date → `{type, name}` tuples |
| `lib/backyard_garden_web/live/calendar/index_live.html.heex` | Named chips, today highlight, legend |
| `lib/backyard_garden_web/live/garden/index_live.html.heex` | Garden visual refresh |
| `lib/backyard_garden_web/live/seeds/edit_live.html.heex` | Edit visual refresh |
| `lib/backyard_garden_web/live/settings/zones_live.html.heex` | Zones visual refresh |
| `README.md` | Weather setup section |
| `test/backyard_garden/weather/tips_test.exs` | Tests for `contextual_message/2` |
| `test/backyard_garden_web/live/dashboard/index_live_test.exs` | Quick-log form tests |
| `test/backyard_garden_web/live/seeds/index_live_test.exs` | In-season badge tests |
| `test/backyard_garden_web/live/seeds/show_live_test.exs` | Log Planting form tests |
| `test/backyard_garden_web/live/calendar/index_live_test.exs` | Named chip tests |

---

## Task 1: Nav active state

**Files:**
- Modify: `lib/backyard_garden_web/components/layouts/app.html.heex`

The `@uri` assign is automatically available in LiveView layouts — it contains the current request URI. Use `@uri.path` to detect the active route. Prefix-match so `/seeds/abc` also highlights the Seeds link.

- [ ] **Step 1: Update `app.html.heex` to highlight the active nav link**

Replace the entire file content:

```heex
<header style="background: linear-gradient(90deg, #0f1f15 0%, #1a3a2a 60%, #2d6a4f 100%);" class="shadow-lg">
  <nav
    aria-label="Main navigation"
    class="px-8 flex items-center justify-between h-14"
  >
    <a href="/" class="flex items-center gap-2 hover:opacity-80 transition-opacity">
      <span class="text-xl">🌿</span>
      <span class="text-[#d8f3dc] text-base font-bold tracking-tight">BackyardGarden</span>
    </a>
    <div class="flex items-center gap-1 text-sm font-medium">
      <.nav_link href={~p"/"} current_path={@uri.path}>Dashboard</.nav_link>
      <.nav_link href={~p"/seeds"} current_path={@uri.path}>Seeds</.nav_link>
      <.nav_link href={~p"/garden"} current_path={@uri.path}>My Garden</.nav_link>
      <.nav_link href={~p"/calendar"} current_path={@uri.path}>Calendar</.nav_link>
      <.nav_link href={~p"/settings/zones"} current_path={@uri.path}>Zones</.nav_link>
    </div>
  </nav>
</header>

<main class="mx-auto max-w-[1280px] px-8 py-7">
  <.flash_group flash={@flash} />
  {@inner_content}
</main>
```

- [ ] **Step 2: Update `nav_link` in `layouts.ex` to accept `current_path` and highlight active link**

Replace the `defp nav_link` function:

```elixir
defp nav_link(assigns) do
  active = String.starts_with?(assigns.current_path, assigns.href) and
             (assigns.href == "/" and assigns.current_path == "/" or assigns.href != "/")

  assigns = assign(assigns, :active, active)

  ~H"""
  <a
    href={@href}
    class={[
      "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
      if(@active,
        do: "bg-white/10 text-white font-semibold",
        else: "text-[#95d5b2] hover:text-white hover:bg-white/5"
      )
    ]}
  >
    {render_slot(@inner_block)}
  </a>
  """
end
```

Also add the `attr` declaration above the function:

```elixir
attr :href, :string, required: true
attr :current_path, :string, required: true
slot :inner_block, required: true
```

- [ ] **Step 3: Run the tests**

```bash
mix test test/backyard_garden_web/live/dashboard/index_live_test.exs
```

Expected: all pass (existing tests don't check nav state).

- [ ] **Step 4: Commit**

```bash
git add lib/backyard_garden_web/components/layouts/app.html.heex \
        lib/backyard_garden_web/components/layouts.ex
git commit -m "feat: add nav active state — highlight current page link"
```

---

## Task 2: Global visual foundation

**Files:**
- Modify: `lib/backyard_garden_web/components/layouts/root.html.heex`

Change the page background from `bg-[#f0fdf4]` to `bg-[#fafdf9]` so white cards have somewhere to float.

- [ ] **Step 1: Update `root.html.heex` body class**

Change line 33 from:
```html
<body class="h-full bg-[#f0fdf4] text-[#14532d] antialiased">
```
to:
```html
<body class="h-full bg-[#fafdf9] text-[#14532d] antialiased">
```

- [ ] **Step 2: Compile and verify no errors**

```bash
mix compile
```

Expected: `Generated backyard_garden app` with no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/backyard_garden_web/components/layouts/root.html.heex
git commit -m "feat: update page background to fafdf9 for card contrast"
```

---

## Task 3: Weather contextual message

**Files:**
- Modify: `lib/backyard_garden/weather/tips.ex`
- Modify: `lib/backyard_garden_web/live/dashboard/index_live.ex`
- Modify: `test/backyard_garden/weather/tips_test.exs`

Add a `contextual_message/2` function to `Tips` that returns a single natural-language sentence combining weather + garden state (how many seeds are ready to plant).

- [ ] **Step 1: Write failing tests for `contextual_message/2`**

Add to `test/backyard_garden/weather/tips_test.exs` (after the existing tests):

```elixir
describe "contextual_message/2" do
  test "warm + dry + seeds ready" do
    msg = Tips.contextual_message(%{temp: 18.0, condition: "Clear"}, 5)
    assert msg =~ "5 seeds"
    assert msg =~ ~r/planting|ground/i
  end

  test "warm + dry + no seeds ready" do
    msg = Tips.contextual_message(%{temp: 18.0, condition: "Clear"}, 0)
    assert msg =~ ~r/outside|garden/i
    refute msg =~ "seeds ready"
  end

  test "rainy day" do
    msg = Tips.contextual_message(%{temp: 16.0, condition: "Rain"}, 3)
    assert msg =~ ~r/transplant|rain|moisture/i
  end

  test "cold day" do
    msg = Tips.contextual_message(%{temp: 3.0, condition: "Clear"}, 0)
    assert msg =~ ~r/cold|hardy/i
  end

  test "hot day" do
    msg = Tips.contextual_message(%{temp: 30.0, condition: "Clear"}, 2)
    assert msg =~ ~r/water|heat|hot/i
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/backyard_garden/weather/tips_test.exs
```

Expected: 5 failures — `Tips.contextual_message/2` undefined.

- [ ] **Step 3: Implement `contextual_message/2` in `tips.ex`**

Add after the existing `generate/2` function:

```elixir
@doc """
Returns a single natural-language sentence combining current weather with
garden state (how many seeds are ready to plant right now).
"""
def contextual_message(%{temp: temp, condition: condition}, plant_now_count) do
  cond do
    rainy?(condition) && plant_now_count > 0 ->
      "Good moisture in the soil today — perfect for transplanting seedlings. " <>
        "You have #{plant_now_count} #{pluralise(plant_now_count, "seed")} ready to go in."

    rainy?(condition) ->
      "Soil moisture is good today — great conditions for transplanting or weeding."

    temp >= 25 ->
      "Hot day — water any new seedlings well and avoid planting in afternoon sun."

    temp >= 15 && plant_now_count > 0 ->
      "Beautiful planting weather — mild and dry all day. " <>
        "You have #{plant_now_count} #{pluralise(plant_now_count, "seed")} ready to go in the ground."

    temp >= 15 ->
      "Great day to be outside. Check your garden for watering or weeding."

    temp >= 5 ->
      "Cool conditions — ideal for brassicas, greens, and root vegetables."

    true ->
      "Too cold for most seeds today — stick to cold-hardy crops like kale and spinach."
  end
end

defp pluralise(1, word), do: word
defp pluralise(_, word), do: word <> "s"
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/backyard_garden/weather/tips_test.exs
```

Expected: all pass.

- [ ] **Step 5: Update `Dashboard.IndexLive` to assign the contextual message**

In `lib/backyard_garden_web/live/dashboard/index_live.ex`, update `load_weather/1`:

```elixir
defp load_weather(socket) do
  location = Application.get_env(:backyard_garden, :default_location, "Victoria, BC")

  case Weather.get_weather(location) do
    {:ok, weather} ->
      has_planted = socket.assigns.recently_planted != []
      tips = Tips.generate(weather, has_planted)
      plant_now_count = length(socket.assigns.plant_now)
      message = Tips.contextual_message(weather, plant_now_count)

      socket
      |> assign(:weather, weather)
      |> assign(:weather_tips, tips)
      |> assign(:weather_message, message)

    {:error, _reason} ->
      socket
      |> assign(:weather, nil)
      |> assign(:weather_tips, [])
      |> assign(:weather_message, nil)
  end
end
```

- [ ] **Step 6: Run full test suite**

```bash
mix test
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/backyard_garden/weather/tips.ex \
        lib/backyard_garden_web/live/dashboard/index_live.ex \
        test/backyard_garden/weather/tips_test.exs
git commit -m "feat: add weather contextual message combining conditions + plant-now count"
```

---

## Task 4: Dashboard visual redesign + greeting

**Files:**
- Modify: `lib/backyard_garden_web/live/dashboard/index_live.html.heex`
- Modify: `lib/backyard_garden_web/live/dashboard/index_live.ex`

Replace the flat card layout with the Garden Journal bento grid. Add a personalised greeting line.

- [ ] **Step 1: Add greeting assign to `Dashboard.IndexLive`**

Add a `greeting/0` private function and assign it in `mount/3`:

```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page_title, "Dashboard")
   |> assign(:greeting, greeting())
   |> load_dashboard()
   |> load_weather()}
end

defp greeting do
  day = Date.utc_today() |> Calendar.strftime("%A")
  "Good #{time_of_day()}, happy #{day}"
end

defp time_of_day do
  hour = DateTime.utc_now().hour
  cond do
    hour < 12 -> "morning"
    hour < 17 -> "afternoon"
    true -> "evening"
  end
end
```

- [ ] **Step 2: Replace `index_live.html.heex` with Garden Journal layout**

```heex
<div class="space-y-0">
  <%!-- Greeting --%>
  <h1 class="text-3xl font-extrabold text-[#14532d] tracking-tight mb-5">
    {@greeting}
    <%= if @weather do %>
      <span class="text-2xl ml-1">
        {if String.contains?(String.downcase(@weather.condition), ["rain", "drizzle"]), do: "🌧️",
         else: if(String.contains?(String.downcase(@weather.condition), "cloud"), do: "🌤️", else: "☀️")}
      </span>
    <% end %>
  </h1>

  <%!-- Bento grid: 2-col desktop, stacked tablet/mobile --%>
  <div class="grid grid-cols-1 md:grid-cols-[2fr_1fr] gap-4 items-start">

    <%!-- Main column --%>
    <div class="flex flex-col gap-4">

      <%!-- Weather card --%>
      <%= if @weather do %>
        <div class="rounded-[22px] p-7 relative overflow-hidden"
             style="background: linear-gradient(150deg, #ecfdf5, #d1fae5);">
          <div class="absolute right-6 top-5 text-7xl opacity-40 pointer-events-none select-none">
            {if String.contains?(String.downcase(@weather.condition), ["rain", "drizzle"]), do: "🌧️",
             else: if(String.contains?(String.downcase(@weather.condition), "cloud"), do: "🌤️", else: "☀️")}
          </div>
          <div class="text-[11px] font-bold tracking-widest uppercase text-[#2d6a4f] mb-2">
            {@weather.city}
          </div>
          <div class="text-6xl font-black text-[#14532d] leading-none tracking-tight">
            {Float.round(@weather.temp, 0) |> trunc()}°
          </div>
          <div class="text-base text-[#52b788] font-medium mt-1 mb-5">
            {@weather.condition} · feels like {Float.round(@weather.feels_like, 0) |> trunc()}°
          </div>
          <%= if @weather_message do %>
            <div class="bg-white rounded-2xl px-5 py-4 shadow-sm text-sm text-[#374151] leading-relaxed italic">
              "{@weather_message}"
            </div>
          <% end %>
          <%= if Enum.any?(@weather_tips, &String.contains?(&1, "Frost")) do %>
            <div class="mt-4 flex items-center gap-2 rounded-xl bg-[#fef3c7] border border-[#fcd34d] px-4 py-3">
              <span class="text-base">🌡️</span>
              <span class="text-[#92400e] text-sm font-medium">
                {Enum.find(@weather_tips, &String.contains?(&1, "Frost"))}
              </span>
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- Plant Now card --%>
      <div class="rounded-[22px] overflow-hidden shadow-[0_2px_20px_rgba(0,0,0,0.07)]">
        <div class="px-6 py-4 flex items-center justify-between"
             style="background: linear-gradient(135deg, #2d6a4f, #52b788);">
          <span class="text-white text-base font-bold">🌱 Plant Now</span>
          <span class="bg-white/20 text-white text-xs font-bold px-3 py-1 rounded-full">
            {length(@plant_now)} seeds
          </span>
        </div>
        <div class="bg-white px-6 pb-4">
          <%= if @plant_now == [] do %>
            <p class="pt-4 text-sm text-[#6b7280] italic">
              No seeds are in their ideal window right now.
            </p>
          <% else %>
            <%= for seed <- @plant_now do %>
              <div class="border-b border-[#f3f4f6] last:border-0">
                <div class="flex items-center gap-3 py-3">
                  <div class="flex-1 min-w-0">
                    <a href={~p"/seeds/#{seed.id}"}
                       class="text-sm font-semibold text-[#111] hover:text-[#2d6a4f] truncate block">
                      {seed.name}
                    </a>
                    <div class="text-xs text-[#9ca3af] mt-0.5">{seed.type}</div>
                  </div>
                  <button
                    phx-click="expand_quick_log"
                    phx-value-id={seed.id}
                    class={[
                      "text-xs font-bold px-4 py-2 rounded-full transition-colors flex-shrink-0",
                      if(@expanded_seed_id == seed.id,
                        do: "bg-[#f0fdf4] text-[#2d6a4f] border border-[#bbf7d0]",
                        else: "text-white"
                      )
                    ]}
                    style={if @expanded_seed_id != seed.id, do: "background: linear-gradient(135deg, #2d6a4f, #52b788);"}
                  >
                    {if @expanded_seed_id == seed.id, do: "▲ Cancel", else: "Log it"}
                  </button>
                </div>

                <%!-- Inline quick-log form --%>
                <%= if @expanded_seed_id == seed.id do %>
                  <div class="bg-[#f0fdf4] rounded-xl p-4 mb-3">
                    <.form
                      id={"quick-log-form-#{seed.id}"}
                      for={@quick_log_form}
                      phx-submit="save_quick_log"
                      phx-change="validate_quick_log"
                      class="space-y-3"
                    >
                      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        <.input field={@quick_log_form[:date_planted]} type="date" label="Date planted" />
                        <.input
                          field={@quick_log_form[:status]}
                          type="select"
                          label="Status"
                          options={[{"Planted", "planted"}, {"Planned", "planned"}]}
                        />
                        <div>
                          <.input
                            field={@quick_log_form[:zone_id]}
                            type="select"
                            label="Garden zone"
                            options={[{"— no zone —", ""} | Enum.map(@quick_log_zones, &{"#{if(&1.score && &1.score > 0, do: "★ ", else: "")}#{&1.name}", &1.id})]}
                          />
                          <%= if @quick_log_zones != [] do %>
                            <p class="text-xs text-[#52b788] mt-1">Sorted by best match.</p>
                          <% end %>
                        </div>
                        <.input field={@quick_log_form[:location]} type="text" label="Location" placeholder="e.g. raised bed 2" />
                      </div>
                      <.input field={@quick_log_form[:notes]} type="textarea" label="Notes" rows="2" />
                      <div class="flex items-center gap-3 pt-1">
                        <button
                          type="submit"
                          class="text-white text-sm font-bold px-5 py-2 rounded-full"
                          style="background: linear-gradient(135deg, #2d6a4f, #52b788);"
                        >
                          Save Planting
                        </button>
                        <span class="text-xs text-[#6b7280]">
                          {seed.name} · {Phoenix.HTML.Form.input_value(@quick_log_form, :status)} · today
                        </span>
                      </div>
                    </.form>
                  </div>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

    </div>

    <%!-- Aside column --%>
    <div class="flex flex-col gap-4">

      <%!-- Recently Planted card --%>
      <div class="rounded-[22px] overflow-hidden shadow-[0_2px_20px_rgba(0,0,0,0.07)]">
        <div class="px-6 py-4"
             style="background: linear-gradient(135deg, #7c3aed, #a78bfa);">
          <span class="text-white text-base font-bold">✅ Recently Planted</span>
        </div>
        <div class="bg-white px-6 pb-4">
          <%= if @recently_planted == [] do %>
            <p class="pt-4 text-sm text-[#6b7280] italic">Nothing planted yet.</p>
          <% else %>
            <%= for planting <- @recently_planted do %>
              <div class="flex items-center justify-between py-3 border-b border-[#f3f4f6] last:border-0">
                <a href={~p"/seeds/#{planting.seed.id}"}
                   class="text-sm font-semibold text-[#14532d] hover:underline truncate">
                  {planting.seed.name}
                </a>
                <span class="text-xs font-semibold bg-[#f0fdf4] text-[#2d6a4f] px-3 py-1 rounded-full ml-3 flex-shrink-0">
                  {Calendar.strftime(planting.planted_at, "%b %d")}
                </span>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <%!-- Coming Up card --%>
      <div class="rounded-[22px] overflow-hidden shadow-[0_2px_20px_rgba(0,0,0,0.07)]">
        <div class="px-6 py-4"
             style="background: linear-gradient(135deg, #d97706, #fbbf24);">
          <span class="text-white text-base font-bold">📅 Coming Up</span>
        </div>
        <div class="bg-white px-6 pb-4">
          <%= if @upcoming == [] do %>
            <p class="pt-4 text-sm text-[#6b7280] italic">
              No upcoming windows in the next 60 days.
            </p>
          <% else %>
            <%= for {seed, open_date} <- @upcoming do %>
              <div class="flex items-center gap-3 py-3 border-b border-[#f3f4f6] last:border-0">
                <span class="text-xs font-bold text-[#9ca3af] w-11 flex-shrink-0">
                  {Calendar.strftime(open_date, "%b %d")}
                </span>
                <a href={~p"/seeds/#{seed.id}"}
                   class="text-sm font-semibold text-[#111] hover:text-[#2d6a4f] flex-1 truncate">
                  {seed.name}
                </a>
                <BackyardGardenWeb.Layouts.type_badge type={seed.type} />
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

    </div>
  </div>
</div>
```

- [ ] **Step 3: Run existing dashboard tests**

```bash
mix test test/backyard_garden_web/live/dashboard/index_live_test.exs
```

Expected: all pass. The template still renders the same data — only the markup changed.

- [ ] **Step 4: Commit**

```bash
git add lib/backyard_garden_web/live/dashboard/index_live.ex \
        lib/backyard_garden_web/live/dashboard/index_live.html.heex
git commit -m "feat: dashboard visual redesign — Garden Journal layout with greeting"
```

---

## Task 5: Dashboard Plant Now — quick-log inline form

**Files:**
- Modify: `lib/backyard_garden_web/live/dashboard/index_live.ex`
- Modify: `test/backyard_garden_web/live/dashboard/index_live_test.exs`

The template from Task 4 already renders the quick-log form — this task wires up the LiveView events.

- [ ] **Step 1: Write failing tests**

Add to `test/backyard_garden_web/live/dashboard/index_live_test.exs`:

```elixir
test "expand_quick_log shows inline form for that seed", %{conn: conn} do
  seed_fixture(%{name: "Log Me", ideal_planting_time: "spring"})

  {:ok, view, _html} = live(conn, ~p"/")
  html = render_click(view, "expand_quick_log", %{"id" => "some-id"})

  # form renders after click (even with invalid id — form still appears)
  # Use a real seed for a proper test
  {:ok, view2, _} = live(conn, ~p"/")
  seed = seed_fixture(%{name: "Quick Log Seed", ideal_planting_time: "spring"})
  html2 = render_click(view2, "expand_quick_log", %{"id" => seed.id})
  assert html2 =~ "Save Planting"
  assert html2 =~ "Date planted"
end

test "save_quick_log creates a planting and removes seed from Plant Now", %{conn: conn} do
  seed = seed_fixture(%{name: "Log It Now", ideal_planting_time: "spring"})

  {:ok, view, _html} = live(conn, ~p"/")
  render_click(view, "expand_quick_log", %{"id" => seed.id})

  html =
    view
    |> form("[id^=quick-log-form]", %{
      "planting" => %{
        "seed_id" => seed.id,
        "status" => "planted",
        "date_planted" => to_string(Date.utc_today()),
        "location" => "",
        "notes" => "",
        "zone_id" => ""
      }
    })
    |> render_submit()

  refute html =~ "Log It Now"
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/backyard_garden_web/live/dashboard/index_live_test.exs
```

Expected: 2 failures — events not handled.

- [ ] **Step 3: Add quick-log assigns and events to `Dashboard.IndexLive`**

Add aliases at the top of the module:

```elixir
alias BackyardGarden.{Dashboard, Plantings, GardenZones, Weather}
alias BackyardGarden.Weather.Tips
alias BackyardGardenWeb.Layouts
```

Update `mount/3` to add quick-log assigns:

```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page_title, "Dashboard")
   |> assign(:greeting, greeting())
   |> assign(:expanded_seed_id, nil)
   |> assign(:quick_log_form, nil)
   |> assign(:quick_log_zones, [])
   |> load_dashboard()
   |> load_weather()}
end
```

Add event handlers (after existing `handle_event` if any — this module currently has none, just add them):

```elixir
@impl true
def handle_event("expand_quick_log", %{"id" => seed_id}, socket) do
  if socket.assigns.expanded_seed_id == seed_id do
    {:noreply, socket |> assign(:expanded_seed_id, nil) |> assign(:quick_log_form, nil) |> assign(:quick_log_zones, [])}
  else
    zones = GardenZones.recommend_zones(%{id: seed_id})
    changeset = Plantings.change_planting(%Plantings.Planting{})
    form =
      changeset
      |> Ecto.Changeset.put_change(:seed_id, seed_id)
      |> Ecto.Changeset.put_change(:date_planted, Date.utc_today())
      |> Ecto.Changeset.put_change(:status, "planted")
      |> to_form(as: "planting")

    {:noreply,
     socket
     |> assign(:expanded_seed_id, seed_id)
     |> assign(:quick_log_form, form)
     |> assign(:quick_log_zones, zones)}
  end
end

@impl true
def handle_event("validate_quick_log", %{"planting" => params}, socket) do
  form =
    %Plantings.Planting{}
    |> Plantings.change_planting(normalise_planting_params(params))
    |> Map.put(:action, :validate)
    |> to_form(as: "planting")

  {:noreply, assign(socket, :quick_log_form, form)}
end

@impl true
def handle_event("save_quick_log", %{"planting" => params}, socket) do
  case Plantings.create_planting(normalise_planting_params(params)) do
    {:ok, _planting} ->
      {:noreply,
       socket
       |> assign(:expanded_seed_id, nil)
       |> assign(:quick_log_form, nil)
       |> assign(:quick_log_zones, [])
       |> load_dashboard()
       |> put_flash(:info, "Planting logged!")}

    {:error, changeset} ->
      {:noreply, assign(socket, :quick_log_form, to_form(changeset, as: "planting"))}
  end
end

# Coerce empty zone_id string to nil and map date_planted string to Date
defp normalise_planting_params(params) do
  params
  |> Map.update("zone_id", nil, fn v -> if v == "", do: nil, else: v end)
  |> Map.update("date_planted", nil, fn v ->
    case Date.from_iso8601(v) do
      {:ok, d} -> d
      _ -> nil
    end
  end)
  |> Map.put_new("planted_at", Map.get(params, "date_planted"))
end
```

- [ ] **Step 4: Check what `Plantings.change_planting/1` and `Plantings.change_planting/2` expect**

Run a quick check to confirm the function signatures:

```bash
grep -n "def change_planting" lib/backyard_garden/plantings.ex
```

Adjust the changeset calls in step 3 to match (typically `change_planting(%Planting{}, attrs)`).

- [ ] **Step 5: Run the tests**

```bash
mix test test/backyard_garden_web/live/dashboard/index_live_test.exs
```

Expected: all pass.

- [ ] **Step 6: Run full suite**

```bash
mix test
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/backyard_garden_web/live/dashboard/index_live.ex \
        test/backyard_garden_web/live/dashboard/index_live_test.exs
git commit -m "feat: dashboard Plant Now inline quick-log form"
```

---

## Task 6: Seed library — in-season status column

**Files:**
- Modify: `lib/backyard_garden_web/live/seeds/index_live.ex`
- Modify: `lib/backyard_garden_web/live/seeds/index_live.html.heex`
- Modify: `test/backyard_garden_web/live/seeds/index_live_test.exs`

- [ ] **Step 1: Write failing test**

Add to `test/backyard_garden_web/live/seeds/index_live_test.exs`:

```elixir
test "shows in-season badge for seed whose window includes today", %{conn: conn} do
  today = Date.utc_today()
  month_name = Calendar.strftime(today, "%B") |> String.downcase()

  {:ok, _} =
    Seeds.create_seed(%{
      name: "In Season Now",
      type: "Vegetable",
      ideal_planting_time: month_name
    })

  {:ok, _view, html} = live(conn, ~p"/seeds")
  assert html =~ "In season"
end

test "shows coming-soon badge for seed whose window opens within 30 days", %{conn: conn} do
  future = Date.utc_today() |> Date.add(14)
  month_name = Calendar.strftime(future, "%B") |> String.downcase()

  {:ok, _} =
    Seeds.create_seed(%{
      name: "Coming Soon Seed",
      type: "Vegetable",
      ideal_planting_time: month_name
    })

  {:ok, _view, html} = live(conn, ~p"/seeds")
  assert html =~ "week"
end
```

- [ ] **Step 2: Run to verify they fail**

```bash
mix test test/backyard_garden_web/live/seeds/index_live_test.exs
```

Expected: 2 failures.

- [ ] **Step 3: Add `season_status/1` helper to `Seeds.IndexLive`**

In `lib/backyard_garden_web/live/seeds/index_live.ex`, add at the bottom of the module (before the final `end`):

```elixir
# Returns :in_season, {:coming_soon, weeks}, or :out_of_season for a seed.
defp season_status(seed) do
  today = Date.utc_today()

  case BackyardGarden.PlantingCalendar.parse_ideal_months(seed.ideal_planting_time) do
    nil ->
      :out_of_season

    {start_m, end_m} ->
      m = today.month

      in_window =
        if start_m <= end_m do
          m >= start_m and m <= end_m
        else
          m >= start_m or m <= end_m
        end

      if in_window do
        :in_season
      else
        # Find days until window opens
        this_year_open = %{today | month: start_m, day: 1}

        open_date =
          if Date.compare(this_year_open, today) == :gt do
            this_year_open
          else
            %{this_year_open | year: today.year + 1}
          end

        days = Date.diff(open_date, today)

        if days <= 30 do
          weeks = max(1, div(days, 7))
          {:coming_soon, weeks}
        else
          :out_of_season
        end
      end
  end
end
```

Update the `assign_seeds/1` (or equivalent) and `handle_event("filter", ...)` to attach season status. In `index_live.ex`, wherever seeds are loaded for the assigns, map each seed to include its status:

```elixir
defp load_seeds(socket, filters \\ %{}) do
  seeds = Seeds.list_seeds(filters)
  seeds_with_status = Enum.map(seeds, fn s -> {s, season_status(s)} end)

  socket
  |> assign(:seeds, seeds)
  |> assign(:seeds_with_status, seeds_with_status)
  |> assign(:seed_count, length(seeds))
end
```

Check the existing `index_live.ex` for the exact function name that builds seeds assigns and adapt accordingly.

- [ ] **Step 4: Update `index_live.html.heex`** to add a Status column and use `@seeds_with_status`

In the desktop table, add a `Status` column header after `Plant in`:

```heex
<th class="px-4 py-3 font-semibold">Status</th>
```

In the table body, replace the `<tr :for={seed <- @seeds}>` loop with `<tr :for={{seed, status} <- @seeds_with_status}>` and add a status cell:

```heex
<td class="px-4 py-3">
  <%= case status do %>
    <% :in_season -> %>
      <span class="text-xs font-semibold px-2.5 py-1 rounded-full bg-[#dcfce7] text-[#16a34a] border border-[#86efac]">
        🌱 In season
      </span>
    <% {:coming_soon, weeks} -> %>
      <span class="text-xs font-semibold px-2.5 py-1 rounded-full bg-[#fef3c7] text-[#92400e] border border-[#fcd34d]">
        ⏳ In {weeks} {if weeks == 1, do: "week", else: "weeks"}
      </span>
    <% :out_of_season -> %>
      <span class="text-[#d1d5db] text-sm">—</span>
  <% end %>
</td>
```

Also add a green background tint to in-season rows:

```heex
<tr
  :for={{seed, status} <- @seeds_with_status}
  class={[
    "hover:bg-[#f0fdf4] transition-colors cursor-pointer",
    if(status == :in_season, do: "bg-[#f0fdf4]", else: "odd:bg-white even:bg-[#fafafa]")
  ]}
>
```

For the mobile card grid, replace the `🌱 {seed.ideal_planting_time}` line with the status badge:

```heex
<div class="grid grid-cols-2 gap-3 sm:hidden">
  <.link
    :for={{seed, status} <- @seeds_with_status}
    navigate={~p"/seeds/#{seed.id}"}
    class={["bg-white border border-[#bbf7d0] rounded-xl p-3 space-y-1.5 hover:bg-[#f0fdf4] transition-colors", mobile_card_border(seed.type)]}
  >
    <p class="font-bold text-[#14532d] text-sm leading-tight">{seed.name}</p>
    <Layouts.type_badge type={seed.type} />
    <p class="text-xs text-[#6b7280]">{seed.brand}</p>
    <%= case status do %>
      <% :in_season -> %>
        <span class="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-[#dcfce7] text-[#16a34a]">🌱 In season</span>
      <% {:coming_soon, weeks} -> %>
        <span class="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-[#fef3c7] text-[#92400e]">⏳ In {weeks}w</span>
      <% :out_of_season -> %>
        <p class="text-xs text-[#374151]">{seed.ideal_planting_time}</p>
    <% end %>
  </.link>
</div>
```

- [ ] **Step 5: Run the tests**

```bash
mix test test/backyard_garden_web/live/seeds/index_live_test.exs
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/backyard_garden_web/live/seeds/index_live.ex \
        lib/backyard_garden_web/live/seeds/index_live.html.heex \
        test/backyard_garden_web/live/seeds/index_live_test.exs
git commit -m "feat: seed library in-season status column and mobile badge"
```

---

## Task 7: Seed detail — in-season badge + Log Planting form

**Files:**
- Modify: `lib/backyard_garden_web/live/seeds/show_live.ex`
- Modify: `lib/backyard_garden_web/live/seeds/show_live.html.heex`
- Modify: `test/backyard_garden_web/live/seeds/show_live_test.exs`

- [ ] **Step 1: Write failing tests**

Add to `test/backyard_garden_web/live/seeds/show_live_test.exs`:

```elixir
test "shows in-season badge when seed window includes current month", %{conn: conn} do
  today = Date.utc_today()
  month_name = Calendar.strftime(today, "%B") |> String.downcase()

  {:ok, seed} =
    Seeds.create_seed(%{name: "In Season Herb", type: "Herb", ideal_planting_time: month_name})

  {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")
  assert html =~ "In season"
end

test "shows Log Planting button", %{conn: conn, seed: seed} do
  {:ok, _view, html} = live(conn, ~p"/seeds/#{seed.id}")
  assert html =~ "Log Planting"
end

test "clicking Log Planting shows the inline form", %{conn: conn, seed: seed} do
  {:ok, view, _html} = live(conn, ~p"/seeds/#{seed.id}")
  html = render_click(view, "show_log_form", %{})
  assert html =~ "Save Planting"
  assert html =~ "Date planted"
end

test "submitting log form creates a planting", %{conn: conn, seed: seed} do
  {:ok, view, _html} = live(conn, ~p"/seeds/#{seed.id}")
  render_click(view, "show_log_form", %{})

  html =
    view
    |> form("[id^=log-planting-form]", %{
      "planting" => %{
        "seed_id" => seed.id,
        "status" => "planted",
        "date_planted" => to_string(Date.utc_today()),
        "location" => "",
        "notes" => "",
        "zone_id" => ""
      }
    })
    |> render_submit()

  assert html =~ "Planting logged"
end
```

- [ ] **Step 2: Run to verify failures**

```bash
mix test test/backyard_garden_web/live/seeds/show_live_test.exs
```

Expected: 4 failures.

- [ ] **Step 3: Update `Seeds.ShowLive` with new assigns and events**

```elixir
alias BackyardGarden.{Seeds, Plantings, GardenZones}
alias BackyardGarden.PlantingCalendar

@impl true
def mount(%{"id" => id}, _session, socket) do
  seed = Seeds.get_seed!(id)
  status = season_status(seed)
  zones = GardenZones.recommend_zones(%{id: seed.id})

  {:ok,
   socket
   |> assign(:page_title, seed.name)
   |> assign(:seed, seed)
   |> assign(:season_status, status)
   |> assign(:show_log_form, false)
   |> assign(:log_form, nil)
   |> assign(:log_zones, zones)}
end

@impl true
def handle_event("show_log_form", _params, socket) do
  seed = socket.assigns.seed
  form =
    %Plantings.Planting{}
    |> Plantings.change_planting(%{
      seed_id: seed.id,
      date_planted: Date.utc_today(),
      status: "planted"
    })
    |> to_form(as: "planting")

  {:noreply, socket |> assign(:show_log_form, true) |> assign(:log_form, form)}
end

@impl true
def handle_event("hide_log_form", _params, socket) do
  {:noreply, socket |> assign(:show_log_form, false) |> assign(:log_form, nil)}
end

@impl true
def handle_event("validate_planting", %{"planting" => params}, socket) do
  form =
    %Plantings.Planting{}
    |> Plantings.change_planting(normalise_params(params))
    |> Map.put(:action, :validate)
    |> to_form(as: "planting")

  {:noreply, assign(socket, :log_form, form)}
end

@impl true
def handle_event("save_planting", %{"planting" => params}, socket) do
  case Plantings.create_planting(normalise_params(params)) do
    {:ok, _} ->
      {:noreply,
       socket
       |> assign(:show_log_form, false)
       |> assign(:log_form, nil)
       |> put_flash(:info, "Planting logged!")}

    {:error, changeset} ->
      {:noreply, assign(socket, :log_form, to_form(changeset, as: "planting"))}
  end
end

defp normalise_params(params) do
  params
  |> Map.update("zone_id", nil, fn v -> if v == "", do: nil, else: v end)
  |> Map.update("date_planted", nil, fn v ->
    case Date.from_iso8601(v) do
      {:ok, d} -> d
      _ -> nil
    end
  end)
end

defp season_status(seed) do
  today = Date.utc_today()

  case PlantingCalendar.parse_ideal_months(seed.ideal_planting_time) do
    nil -> :out_of_season
    {start_m, end_m} ->
      m = today.month
      in_window =
        if start_m <= end_m, do: m >= start_m and m <= end_m, else: m >= start_m or m <= end_m
      if in_window, do: :in_season, else: :out_of_season
  end
end
```

- [ ] **Step 4: Update `show_live.html.heex`** — add in-season badge + Log Planting button + inline form below the key facts card

In the left column, after the closing `</dl>` (before the supplier link button), add:

```heex
<%!-- In-season badge --%>
<%= if @season_status == :in_season do %>
  <div class="pt-1">
    <span class="text-xs font-semibold px-3 py-1 rounded-full bg-[#dcfce7] text-[#16a34a] border border-[#86efac]">
      🌱 In season now
    </span>
  </div>
<% end %>
```

After the supplier link (or at the bottom of the left column `<div>`), add:

```heex
<%!-- Log Planting button --%>
<button
  phx-click={if @show_log_form, do: "hide_log_form", else: "show_log_form"}
  class="mt-2 w-full text-sm font-bold py-2.5 rounded-xl text-white transition-colors"
  style="background: linear-gradient(135deg, #2d6a4f, #52b788);"
>
  {if @show_log_form, do: "✕ Cancel", else: "+ Log Planting"}
</button>

<%!-- Inline form --%>
<%= if @show_log_form do %>
  <div class="mt-3 bg-[#f0fdf4] rounded-xl p-4">
    <.form
      id="log-planting-form"
      for={@log_form}
      phx-submit="save_planting"
      phx-change="validate_planting"
      class="space-y-3"
    >
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <.input field={@log_form[:date_planted]} type="date" label="Date planted" />
        <.input
          field={@log_form[:status]}
          type="select"
          label="Status"
          options={[{"Planted", "planted"}, {"Planned", "planned"}]}
        />
        <div>
          <.input
            field={@log_form[:zone_id]}
            type="select"
            label="Garden zone"
            options={[{"— no zone —", ""} | Enum.map(@log_zones, &{"#{if(&1.score && &1.score > 0, do: "★ ", else: "")}#{&1.name}", &1.id})]}
          />
        </div>
        <.input field={@log_form[:location]} type="text" label="Location" placeholder="e.g. raised bed 2" />
      </div>
      <.input field={@log_form[:notes]} type="textarea" label="Notes" rows="2" />
      <button
        type="submit"
        class="w-full text-white text-sm font-bold py-2.5 rounded-xl"
        style="background: linear-gradient(135deg, #2d6a4f, #52b788);"
      >
        Save Planting
      </button>
    </.form>
  </div>
<% end %>
```

- [ ] **Step 5: Run the tests**

```bash
mix test test/backyard_garden_web/live/seeds/show_live_test.exs
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/backyard_garden_web/live/seeds/show_live.ex \
        lib/backyard_garden_web/live/seeds/show_live.html.heex \
        test/backyard_garden_web/live/seeds/show_live_test.exs
git commit -m "feat: seed detail in-season badge and Log Planting inline form"
```

---

## Task 8: Calendar — named event chips + today highlight

**Files:**
- Modify: `lib/backyard_garden_web/live/calendar/index_live.ex`
- Modify: `lib/backyard_garden_web/live/calendar/index_live.html.heex`
- Modify: `test/backyard_garden_web/live/calendar/index_live_test.exs`

Change `events_by_date` from `date → [atom]` to `date → [{type, name}]` so chips can show the seed name.

- [ ] **Step 1: Update the failing test to match the new chip format**

Replace the existing `"shows planted seed name"` test in `index_live_test.exs`:

```elixir
test "shows planted seed name chip on its planted_at date", %{conn: conn} do
  seed = seed_fixture(%{name: "Spinach"})
  today = Date.utc_today()

  {:ok, _} =
    Plantings.create_planting(%{
      seed_id: seed.id,
      status: "planted",
      planted_at: today
    })

  {:ok, _view, html} = live(conn, ~p"/calendar")
  assert html =~ "Spinach"
end
```

- [ ] **Step 2: Run to confirm current test fails or passes**

```bash
mix test test/backyard_garden_web/live/calendar/index_live_test.exs
```

Note whether it passes (old format) or fails. Either way proceed.

- [ ] **Step 3: Update `Calendar.IndexLive` — change `maybe_add_event` to carry seed name**

In `lib/backyard_garden_web/live/calendar/index_live.ex`, update `load_calendar_data/1`:

```elixir
events_by_date =
  Enum.reduce(plantings, %{}, fn planting, acc ->
    name = planting.seed.name
    acc
    |> maybe_add_event(planting.planted_at, {:planted, name})
    |> maybe_add_event(harvest_date(planting), {:harvest_due, name})
  end)
```

Update `maybe_add_event/3` — no changes needed to the signature, just the type is now a tuple instead of an atom.

Also assign today for the highlight:

```elixir
socket
|> assign(:weeks, weeks)
|> assign(:events_by_date, events_by_date)
|> assign(:ideal_seeds, ideal_seeds)
|> assign(:month_label, Calendar.strftime(month, "%B %Y"))
|> assign(:today, Date.utc_today())
```

- [ ] **Step 4: Update `index_live.html.heex`** — named chips, today highlight, updated legend

Replace the calendar grid cell content (the `<div class="min-h-[72px]...">` block for real dates):

```heex
<div class={[
  "min-h-[72px] p-1.5 text-xs border-b border-r border-[#f3f4f6] transition-colors",
  if(date == @today, do: "bg-[#f0fdf4] ring-2 ring-inset ring-[#52b788]", else: "bg-white hover:bg-[#f0fdf4]")
]}>
  <span class={["font-medium", if(date == @today, do: "text-[#14532d] font-bold", else: "text-[#374151]")]}>
    {date.day}{if date == @today, do: " ★"}
  </span>

  <%!-- Ideal window opens: first day of window only --%>
  <%= if date.day == 1 and @ideal_seeds != [] do %>
    <div class="mt-0.5 space-y-0.5">
      <%= for seed_name <- Enum.take(@ideal_seeds, 2) do %>
        <div class="text-[10px] text-[#2d6a4f] bg-[#dcfce7] rounded px-1 truncate">
          🌱 {seed_name}
        </div>
      <% end %>
      <%= if length(@ideal_seeds) > 2 do %>
        <div class="text-[10px] text-[#6b7280]">+{length(@ideal_seeds) - 2} more</div>
      <% end %>
    </div>
  <% end %>

  <%!-- Named event chips --%>
  <%= if Map.has_key?(@events_by_date, date) do %>
    <div class="mt-0.5 space-y-0.5">
      <%= for event <- Enum.take(Map.get(@events_by_date, date, []), 2) do %>
        <%= case event do %>
          <% {:planted, name} -> %>
            <div class="text-[10px] bg-[#dbeafe] text-[#1d4ed8] rounded px-1 truncate">✓ {name}</div>
          <% {:harvest_due, name} -> %>
            <div class="text-[10px] bg-[#fef9c3] text-[#854d0e] rounded px-1 truncate">⚡ {name}</div>
        <% end %>
      <% end %>
      <%= if length(Map.get(@events_by_date, date, [])) > 2 do %>
        <div class="text-[10px] text-[#6b7280]">+{length(Map.get(@events_by_date, date, [])) - 2} more</div>
      <% end %>
    </div>
  <% end %>
</div>
```

Replace the legend section:

```heex
<div class="bg-white border border-[#bbf7d0] rounded-xl p-4">
  <span class="text-[#52b788] uppercase tracking-wide text-xs font-semibold block mb-3">Legend</span>
  <div class="flex flex-wrap gap-4 text-xs text-[#374151]">
    <div class="flex items-center gap-1.5">
      <span class="text-[10px] text-[#2d6a4f] bg-[#dcfce7] rounded px-1">🌱 name</span> Ideal window opens
    </div>
    <div class="flex items-center gap-1.5">
      <span class="text-[10px] bg-[#dbeafe] text-[#1d4ed8] rounded px-1">✓ name</span> Planted
    </div>
    <div class="flex items-center gap-1.5">
      <span class="text-[10px] bg-[#fef9c3] text-[#854d0e] rounded px-1">⚡ name</span> Harvest due
    </div>
    <div class="flex items-center gap-1.5">
      <span class="bg-[#f0fdf4] ring-2 ring-[#52b788] rounded px-1 text-[10px]">★</span> Today
    </div>
  </div>
</div>
```

- [ ] **Step 5: Run the tests**

```bash
mix test test/backyard_garden_web/live/calendar/index_live_test.exs
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/backyard_garden_web/live/calendar/index_live.ex \
        lib/backyard_garden_web/live/calendar/index_live.html.heex \
        test/backyard_garden_web/live/calendar/index_live_test.exs
git commit -m "feat: calendar named event chips and today highlight"
```

---

## Task 9: Visual refresh — My Garden, Seeds Edit, Zones

**Files:**
- Modify: `lib/backyard_garden_web/live/garden/index_live.html.heex`
- Modify: `lib/backyard_garden_web/live/seeds/edit_live.html.heex`
- Modify: `lib/backyard_garden_web/live/settings/zones_live.html.heex`

Apply the Garden Journal card shell (gradient header, `rounded-[22px]`, shadow) to the remaining pages. No logic changes — template-only.

- [ ] **Step 1: Update `garden/index_live.html.heex`**

Replace every `<div class="bg-white border border-[#bbf7d0] rounded-xl p-6">` section card with the new shell. Each section (Planted, Planned, Harvested) gets a gradient header:

- Planted: `linear-gradient(135deg, #2d6a4f, #52b788)`
- Planned: `linear-gradient(135deg, #374151, #6b7280)`
- Harvested: `linear-gradient(135deg, #7c3aed, #a78bfa)`

Example for the Planted section:

```heex
<div class="rounded-[22px] overflow-hidden shadow-[0_2px_20px_rgba(0,0,0,0.07)]">
  <div class="px-6 py-4 flex items-center gap-3"
       style="background: linear-gradient(135deg, #2d6a4f, #52b788);">
    <span class="text-white text-base font-bold">Planted ({length(@planted)})</span>
  </div>
  <div class="bg-white px-6 pb-4">
    <%!-- existing content unchanged --%>
  </div>
</div>
```

Also update the "Log Planting" button to pill gradient style:

```heex
<button
  phx-click="show_form"
  class="text-white text-sm font-bold px-5 py-2 rounded-full"
  style="background: linear-gradient(135deg, #2d6a4f, #52b788);"
>
  + Log Planting
</button>
```

- [ ] **Step 2: Update `edit_live.html.heex`** — wrap form in card shell with a header bar

```heex
<div class="space-y-4">
  <.link navigate={~p"/seeds/#{@seed.id}"} class="text-sm text-[#2d6a4f] hover:underline">
    ← Back
  </.link>
  <div class="rounded-[22px] overflow-hidden shadow-[0_2px_20px_rgba(0,0,0,0.07)]">
    <div class="px-6 py-4" style="background: linear-gradient(135deg, #374151, #6b7280);">
      <h1 class="text-white text-base font-bold">Edit Seed</h1>
    </div>
    <div class="bg-white p-6">
      <%!-- existing form unchanged --%>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Update `zones_live.html.heex`** — same card shell treatment

Each zone card and the "Add Zone" form get the gradient header shell. Zone cards use `linear-gradient(135deg, #2d6a4f, #52b788)`, the add form uses `linear-gradient(135deg, #374151, #6b7280)`.

- [ ] **Step 4: Run the tests**

```bash
mix test
```

Expected: all pass (no logic changed).

- [ ] **Step 5: Commit**

```bash
git add lib/backyard_garden_web/live/garden/index_live.html.heex \
        lib/backyard_garden_web/live/seeds/edit_live.html.heex \
        lib/backyard_garden_web/live/settings/zones_live.html.heex
git commit -m "feat: visual refresh — My Garden, Edit Seed, Zones pages"
```

---

## Task 10: README weather setup docs

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Weather section to README**

Find the `## Setup` or `## Configuration` section (or add after the quick-start instructions) and insert:

```markdown
## Weather Integration

The dashboard shows current conditions and a contextual planting tip powered by [OpenWeatherMap](https://openweathermap.org/api).

**Setup:**

1. Sign up for a free account at openweathermap.org and copy your API key.
2. Set the environment variable before starting the server:
   ```bash
   export OPENWEATHERMAP_API_KEY=your_key_here
   ```
   Or add it to a `.env` file (if you use `direnv` or similar):
   ```
   OPENWEATHERMAP_API_KEY=your_key_here
   ```

**Configuration:**

The default location is `"Victoria, BC"`. To change it, add to `config/dev.exs`:
```elixir
config :backyard_garden, :default_location, "Your City, Country"
```

**If the API key is missing:** the weather card is silently hidden — the rest of the app works normally.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add weather API setup instructions to README"
```

---

## Task 11: Final check and precommit

- [ ] **Step 1: Run the full test suite**

```bash
mix test
```

Expected: all pass.

- [ ] **Step 2: Run precommit checks**

```bash
mix precommit
```

Expected: exits 0. Fix any credo or format issues before proceeding.

- [ ] **Step 3: Smoke-test the app manually**

```bash
mix phx.server
```

Visit each page and verify:
- Nav highlights active page on all routes
- Dashboard shows greeting, weather card, Plant Now with Log it buttons, Recently Planted and Coming Up side by side
- Clicking "Log it" expands the inline form; saving closes it and removes the seed from the list
- `/seeds` shows in-season badges on appropriate rows
- `/seeds/:id` shows in-season badge and Log Planting button; form expands and saves
- `/calendar` shows named chips instead of dots; today's cell is highlighted
- `/garden`, `/seeds/:id/edit`, `/settings/zones` all have gradient card headers
- Page resizes responsively at all widths

- [ ] **Step 4: Final commit if any small fixes were needed**

```bash
git add -p
git commit -m "fix: precommit and smoke-test fixes"
```
