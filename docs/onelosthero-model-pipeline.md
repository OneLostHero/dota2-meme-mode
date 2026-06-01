# OneLostHero — custom FBX model pipeline

Replaces the Kez placeholder model with a custom rigged mesh imported from
`OneLostHero.fbx`. Built 2026-05-31.

## What the FBX contained (parsed directly — no FBX SDK on this box)
- **Mesh** `char1`, 53,328 verts, **170 units tall**, Y-up (Source auto-converts to Z-up).
- **Skeleton:** 24-bone **Mixamo-style humanoid** rig — `Hips`, `LeftUpLeg/LeftLeg/LeftFoot/LeftToeBase`,
  `RightUpLeg/...`, `Spine`/`Spine01`/`Spine02`, `LeftShoulder/LeftArm/LeftForeArm/LeftHand`,
  `RightShoulder/...`, `neck`/`Head`/`head_end`/`headfront`.
- **1 material** `Material_1` + an **embedded 4096×4096 PNG** (base color), extracted to
  `content/.../materials/onelosthero_diffuse.png`.
- **Animation:** ONE take `clip0`, but **every curve has a single keyframe → it is a STATIC
  bind pose, not motion.** The FBX carries no walk/attack/cast/death clips.

## Files created
- `content/.../import/OneLostHero.fbx` — the source mesh.
- `content/.../materials/onelosthero_diffuse.png` — extracted embedded texture.
- `content/.../materials/onelosthero.vmat` — `global_lit_simple.vfx`, `TextureColor` → the PNG.
- `content/.../models/heroes/onelosthero/onelosthero.vmdl` — modeldoc31:
  `RenderMeshFile` (import/OneLostHero.fbx) + `ReplaceMeshMaterials` (`material_1.vmat` →
  `materials/onelosthero.vmat`) + `AttachmentList` (attach_origin=Hips, attach_hitloc=Spine01,
  attach_attack1=RightHand, attach_attack2=LeftHand, attach_eye=Head) + `AnimationList`
  (one `AnimFile` binding the static pose to `ACT_DOTA_IDLE`).
- Repointed `Model` KV on `npc_dota_hero_onelosthero` (npc_heroes_custom.txt) and
  `npc_onelosthero_echo` (npc_units_custom.txt) → `models/heroes/onelosthero/onelosthero.vmdl`.

## Compile
```
"R:\SteamLibrary\steamapps\common\dota 2 beta\game\bin\win64\resourcecompiler.exe" \
  -i "R:\...\content\dota_addons\dota2_meme_mode\materials\onelosthero.vmat" \
  -i "R:\...\content\dota_addons\dota2_meme_mode\models\heroes\onelosthero\onelosthero.vmdl"
```
Produces `game/.../onelosthero.vmdl_c`, `onelosthero.vmat_c`, `onelosthero_diffuse_*_vtex_c`.
The content dir is symlinked into the Dota tree, so output lands in this repo's `game/`.
Compile warnings are benign: "11 joint weights per vertex → truncated to 4" (skin quality),
and a `GetFbxMaterialPath Failed` note (the importer's auto-search; our remap overrides it).

## NOT verified yet — check in-game and report
1. **Facing.** Source = Z-up / **+X forward**; Mixamo front = +Z. If the hero faces the wrong
   way, add to the vmdl `rootNode.children` a `ModelModifierList` with
   `{ _class = "ModelModifier_Rotate"  angles = [ 0.0, 0.0, 90.0 ] }` (try 90 / -90 / 180 yaw),
   then recompile.
2. **Upright?** doom_barrel (also Y-up) imports upright with no rotation, so it should stand.
   If it's lying down, add a pitch (`angles = [ 90.0, 0.0, 0.0 ]`).
3. **Scale.** 170u ≈ a Dota hero. Too big/small → tweak `ModelScale` in npc_heroes_custom.txt
   (no recompile needed).
4. **Texture.** If untextured/wrong, `global_lit_simple` color param may differ — confirm
   `TextureColor` vs `g_tColor`.

## Animations — the real gap and how to close it
The hero will currently play the **static pose for everything** (idle/run/attack/cast all look
frozen; it slides when moving) because the FBX has no motion clips. Two ways forward:

**Path A — Mixamo clips (recommended; this rig is Mixamo-named).**
1. On mixamo.com, use this character (or any compatible upload) and download animations
   **"Without Skin" (animation only), FBX**: at minimum Idle, Walking/Running, a slash/attack,
   a cast, and a death.
2. Drop each FBX into `content/.../import/` (e.g. `olh_idle.fbx`, `olh_run.fbx`, …).
3. For each, add an `AnimFile` block to the vmdl's `AnimationList` (copy the existing one),
   set `source_filename` to that FBX and `activity_name` to the matching activity:
   `ACT_DOTA_IDLE`, `ACT_DOTA_RUN`, `ACT_DOTA_ATTACK`, `ACT_DOTA_CAST_ABILITY_1..6`,
   `ACT_DOTA_DIE`. Recompile. (Because the skeleton is identical, clips bind 1:1 — no retarget.)

**Path B — borrow Kez/PA animations. RULED OUT (2026-05-31, investigated by extracting the
compiled models from the VPK):**
- Dota bakes hero animation data *inside* the compiled `.vmdl_c` (kez_base.vmdl_c is 7.3 MB of
  embedded anim/morph data; PA 564 KB). There are **no external `.vanim_c`/`.vanmgrph` files** to
  reference from our vmdl, and `resourcecompiler` cannot decompile.
- The anims are keyed to **Valve's skeleton** (`root`, `spine1`, `clavicle_R`, `neck1`, `wristL`,
  `wrist_R`, `Thumb1_0_R`, `weapon0_0`, `toeBase_R_helper`…) — totally different names/hierarchy
  from our Mixamo rig (`Hips`, `Spine`/`Spine01/02`, `LeftShoulder`, `LeftHand`, `Head`). Keyframes
  address bones by name, so Valve clips drive nothing on our rig.
- Renaming our bones to Valve names doesn't help — there's still no shareable anim source to point
  at. The only way to reuse Valve motion: Source 2 Viewer (ValveResourceFormat) to export the
  hero `.vmdl_c` → FBX *with* anims, then retarget onto the Mixamo rig in Blender (Auto-Rig
  Pro/Rokoko), then feed the retargeted FBX here. Both are external GUI tools — not CLI/headless.

**Ready-to-paste AnimFile block** (per clip — add inside `AnimationList.children`, set
`source_filename` + `activity_name`):
```
{
	_class = "AnimFile"
	name = "run"
	activity_name = "ACT_DOTA_RUN"
	activity_weight = 1
	weight_list_name = ""
	fade_in_time = 0.2
	fade_out_time = 0.2
	looping = true
	delta = false
	worldSpace = false
	hidden = false
	anim_markup_ordered = false
	disable_compression = false
	animgraph_additive = false
	source_filename = "import/olh_run.fbx"
},
```
Recommended Mixamo clips → save name → activity: Idle→`olh_idle.fbx`→`ACT_DOTA_IDLE`;
Run→`olh_run.fbx`→`ACT_DOTA_RUN`; Slash→`olh_attack.fbx`→`ACT_DOTA_ATTACK`;
Spell Cast→`olh_cast.fbx`→`ACT_DOTA_CAST_ABILITY_1`(+2/3/4); Death→`olh_death.fbx`→`ACT_DOTA_DIE`.
Download FBX Binary, **"Without Skin"**, into `content/.../import/`. Skeleton matches → bind 1:1.

**Ability gestures:** `vanishing_point.lua` / its KV still request `ACT_DOTA_KEZ_*` activities.
Those don't exist on this model, but `Echo:PlayGesture` skips unknown activities safely (no
crash) — they simply won't animate until Path A clips + matching activities are added. Once the
cast clip exists, point those gestures at `ACT_DOTA_CAST_ABILITY_*`.

**Ability gestures:** `vanishing_point.lua` / its KV still request `ACT_DOTA_KEZ_*` activities.
Those don't exist on this model, but `Echo:PlayGesture` skips unknown activities safely (no
crash) — they simply won't animate until Path A clips + matching activities are added.
