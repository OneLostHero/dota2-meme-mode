# Meme Mode — Codebase Review & New Mode Ideas

_Authored 2026-06-03 by Claude (Opus 4.8), during an autonomous overnight session after committing the UI redesign + custom-hero selection + preset save to `main` and wiring persistence Option B._

This document has two parts:
1. **Codebase review** — what's strong, what to improve, and the standing tech-debt items.
2. **New mode ideas** — grounded in the existing plugin framework, with buildable sketches for **Tag** and **Hide & Seek** (your two asks) plus a shortlist of other modes that fit the chaos theme.

---

## Part 1 — Codebase Review

### What's genuinely strong
- **The plugin architecture is excellent.** Every feature is an isolable plugin (`plugin.lua` / `plugin.txt` / `settings.txt`) with clean hook points: `StateRegistrations` (game-state callbacks), `FilterRegistrations` (damage/gold/xp/order/etc.), `CmdRegistrations` (chat commands). New features rarely need to touch the core. This is the right foundation and it's why new modes below are cheap to build.
- **Mutator presets with tag conflict-avoidance** (`add_tags` / `no_tags` / `overlap_tags`) is a smart, underrated system — it lets ~45 presets coexist without stepping on each other. Most mod frameworks don't have this.
- **The settings → net table → Panorama pipeline** is consistent and data-driven (typed settings auto-render in the setup UI). Adding a setting is one KV block.
- **FFA already solves multi-team spawns** (deletes default spawns, builds per-team spawns, 10-team support). Any team-based mode can lean on this.

### Improvement opportunities (roughly by value)

1. **Persistence — finish the decision (HIGH).** Option B (Valve account records) is now wired defensively, but it's a **Preview/Unreleased** API and very likely won't persist for the *published* game (tools-mode only). Recommendation: test B in-client; if presets don't survive a relaunch, switch to **Option A — a serverless HTTP backend** (Cloudflare Worker + KV, keyed by host SteamID, authed with the `Dedicated-Server-Key` header). The in-engine HTTP plumbing already exists and is used live (boosted / hero_builder / legends_of_dota pull online lists via `CreateHTTPRequestScriptVM`), so the Lua side is small. This is the reliable long-term path.

2. **Dead "report" path (MEDIUM).** The upgrade-drawer report flag sends `upgrade_report`, but the server handler is a no-op (the external report server was removed in the rebrand). Either (a) hide the report button until there's a backend, or (b) point it at the same backend you stand up for persistence. Right now it silently does nothing, which is worse than absent.

3. **Pastebin dependency for online lists (MEDIUM).** Boosted/LoD/hero_builder fetch lists from hardcoded `pastebin.com/raw/...` URLs. Pastebin can rate-limit, change, or remove raw access, which would silently break those features. Consider self-hosting these (same backend as #1) or bundling a known-good copy as the fallback when the fetch fails.

4. **Localization gaps (MEDIUM-LOW).** Many `#Plugin_..._Description` / option strings don't exist, so the UI shows raw token text in places. A pass over `resource/addon_english.txt` to fill the missing `_Description` and `_Option_*` keys would make the setup screen look finished. (The custom-hero option labels added this session are a template.)

5. **"Unique" upgrade tier is dormant scaffolding (LOW, your call).** The drawer fully supports rarity-4 "unique" upgrades (Select button, `#Unique_*` name/desc), the legend advertises them, but **nothing in the boosted roll ever produces one** and no `#Unique_*` text exists. You said keep it for now — when you revisit, the decision is: build a handful of hand-crafted uniques (a real feature) or hide the legend entry so it stops promising something that never drops.

6. **Loading "VERSUS screen" double-stall (PARKED).** Strong unconfirmed hypothesis: the `custom_hero_portrait.js` in-game burst (40× heavy full-tree `UpdateTopBar` walks at world-load) blocks the Panorama thread. One-launch confirm: comment out the `custom_hero_portrait` element in `custom_ui_manifest.xml`, run a bots match, see if the stall disappears.

7. **`boosted/lists.txt` malformed-KV bug (PARKED, pre-existing).** Flagged previously; worth a dedicated pass.

8. **Minor code hygiene (LOW).** A few dead/commented blocks remain (e.g., `SortElements` in `plugin_settings.js` is now defined-but-unused after the one-shot-sort change; the commented save-fn line is now superseded). Cheap cleanups, but tackle opportunistically — not worth a churny dedicated PR.

9. **No automated safety net (LOW, inherent).** Dota Lua/Panorama is hard to unit-test. A lightweight `luacheck` config + a manual smoke-test checklist (host lobby → toggle a mode → start bots → confirm no Lua errors in console) would catch the most common breakages. `docs/TESTING.md` exists — worth expanding into that checklist.

### One architectural lesson worth carrying forward
The Boost Juice HUD pain this session came from **two separate Panorama contexts** (`upgrade.js` + `currencies.js`) trying to position themselves independently and diverging. The fix was to make **one context own the combined element**. For any future multi-part HUD piece, put it in a single context (or drive both from one shared element) rather than coordinating across contexts.

---

## Part 2 — New Mode Ideas

All of these are buildable as **a plugin (+ optional mutator preset)** within the existing framework. I've gone deepest on your two: Tag and Hide & Seek.

### 🏷️ Tag ("It")

**Fantasy:** One player is "It" and glows. They chase everyone else; landing a hit passes "It" to the victim. The longer you're "It", the worse your score. Pure chaos with Dota movement/blink/stuns.

**Win condition:** Timed match — whoever has accumulated the **least total "It" time** when the clock ends wins. (Alternative: whoever is "It" when the timer hits zero loses; last-one-standing-not-It.)

**Mechanics (all supported):**
- **Setup:** FFA team layout (reuse `FreeForAllPlugin` spawn logic) so everyone can hit everyone. Pick a random starting "It".
- **"It" status = a modifier** (`modifier_it`): movespeed buff (so It can catch up), a bright particle/overhead marker, and an aura/glow. Apply via `AddNewModifier`.
- **Tag transfer:** register a **`DamageFilter`** (or `ModifierGainedFilter`) — when the current It deals hero damage to a non-It, transfer: remove `modifier_it` from old It, grant it to victim, brief immunity so it can't bounce straight back (a `modifier_tag_cooldown` for ~2s).
- **Scoring:** a per-player think (timer) accruing seconds-as-It; store on a net table so a small HUD can show "It time". Win = lowest at timeout.
- **Anti-degenerate:** the cooldown modifier prevents instant tag-backs; optionally reveal all players on the minimap so nobody just runs forever.

**Files:** `plugins/tag/{plugin.lua,plugin.txt,settings.txt}`, a `modifier_it.lua` (+ `modifier_tag_cooldown.lua`), a `mutator_tag.txt` bundling it with FFA + a sane time limit. Settings: `it_movespeed_bonus`, `tag_immunity_seconds`, `match_seconds`, `reveal_on_minimap`.

**Effort:** Small-to-medium. The only fiddly bit is the damage→transfer handshake and not double-firing it.

### 🙈 Hide & Seek

**Fantasy:** A few **Seekers** hunt many **Hiders**. Hiders get a head start, disguise/blend in, and try to survive the timer; Seekers try to find and kill them all.

**Win condition (round-based — reuse the `rounds` plugin pattern):** Hiders win if any survive when the round timer ends; Seekers win if they eliminate all Hiders first. `GameRules:SetGameWinner(team)`.

**Mechanics (all supported):**
- **Team split:** assign a small Seeker team and a large Hider team at setup (the team APIs + FFA spawn approach). Configurable Seeker count.
- **Head start:** Seekers rooted/blind (a `modifier_blinded` + hold in fountain) for N seconds via a pre-game timer while Hiders scatter.
- **Hider concealment options (pick one to start):**
  - *Invisibility-based:* Hiders get fading invis that breaks on action (simplest — a modifier).
  - *Disguise-based (Prop/Unit Hunt flavor):* swap the Hider's model to a creep/critter/ward using the existing model-swap know-how (the custom-hero model pipeline proves model swaps work), so they blend into the map. More fun, more work.
- **Vision tuning:** shrink Seeker vision / remove Hider minimap dots; give Seekers a periodic "ping pulse" that briefly reveals nearby Hiders so rounds can't stalemate.
- **Elimination:** on Hider death, move them to spectator or a "caught" team; check remaining Hider count on `entity_killed` → if zero, Seekers win.

**Files:** `plugins/hide_and_seek/{plugin.lua,plugin.txt,settings.txt}`, optional `modifier_hider_disguise.lua` / `modifier_seeker_blind.lua`, `mutator_hide_and_seek.txt`. Settings: `seeker_count`, `head_start_seconds`, `round_seconds`, `concealment_mode (invis|disguise)`, `reveal_pulse_interval`.

**Effort:** Medium. Team assignment + round timer + win check is straightforward; the concealment polish (especially disguise) is where the time goes. Start with invis-based to get the loop working, then upgrade to disguise.

### Shortlist of other modes that fit the theme
- **Infection / Juggernaut** — extend the existing `zombies` plugin: start with one Infected; killing a Survivor converts them to the Infected team; last Survivor wins. (Closest cousin to your two; cheapest to prototype because zombies infra exists.)
- **King of the Hill** — a capture zone (the currency plugin already handles outpost/lamp capture); the team accruing the most hold-time wins. Great with the team-time HUD you'd build for Tag.
- **Race** — checkpoint trigger zones across the map; first hero to hit them all wins. Pairs hilariously with blink/movement chaos and "Items × X".
- **Murder Mystery / Mafia** — secret role assignment (one Killer), others deduce via all-chat; Killer wins by eliminating, town wins by voting the Killer out. Leans on chat commands + role net table.
- **Boss Rush (co-op)** — all players vs a scaling custom boss (modifier_spawner + a custom unit); waves escalate. Co-op counterpoint to all the PvP chaos.

### Suggested build order
1. **Tag** first — smallest, self-contained, immediately fun, and it forces you to build the **team-time scoring HUD** that King-of-the-Hill and Infection reuse.
2. **Infection** second — reuses zombies infra + the scoring HUD; low marginal cost.
3. **Hide & Seek** third — biggest, but Tag + Infection will have shaken out the team-assignment / round-timer / win-check patterns it needs.

Each should ship as a plugin **plus** a one-click mutator preset so it shows up in QUICK SELECT alongside the existing modes.

---

## Immediate follow-ups (independent of new modes)
- **Test persistence (Option B)** in-client; if it doesn't survive relaunch, greenlight Option A (HTTP) — I can scope the Worker + Lua wiring.
- **Decide the report button** (hide vs. wire to backend).
- **Localization fill pass** for a finished-looking setup screen.
