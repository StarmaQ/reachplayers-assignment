# FindJob – Career Match campaign (Roblox)

A drop-in branded campaign: an open-air FindJob job-fair stand appears in the host game, a
recruiter asks two questions, matches the player to **Software Engineer** or **Teacher**, a
pedestal opens that field's mini-mission, and the host game hears about the reward and shows it.

## Running it

1. `rojo serve --port 34872`. The stand and Maya are saved in the place, in `Workspace.FindJobCampaign` (see *Art* below).
   Don't use 58741/58742, those belong to the Roblox Studio MCP bridge.
2. Connect the Rojo plugin in Studio and press Play
3. Walk to Maya, on the grass at the front-right of the stand. The **Load / Unload FindJob** button (top right) toggles the whole campaign live.

## Player flow

```
walk by ─► Maya waves, dashed circle + arrow on her; the stand's screens show the player's own avatar
talk    ─► subtitle dialogue with Maya's animated portrait (she plays emotes in the world too)
          ─► clipboard questions ─► server classifies ─► "Your match" card
          ─► the matching pedestal's item spins faster, the other slows; the guide ring moves there
mission ─► Coding: a computer pops up on screen and boots ("FindJob OS"), then a tiny editor;
          drag/tap pieces into the gaps (3 exercises: a variable, an addition, reading the output)
          Grading: 3 quizzes, one at a time, tap a ✓ / X sticker per answer, A+ stamp when right
          (every step is checked by the server; wrong answers wiggle and show a hint)
done    ─► RewardGranted (the host shows its own popup) ─► "did that job feel like you?"
```

The player can leave at any point with the X button; the host can close everything with `CloseAllUi` or unload the campaign.

## Code layout

The whole campaign is one folder, `src/FindJobCampaign`, synced to `ServerScriptService.FindJobCampaign`:

| In the package | |
|---|---|
| `Loader` | on start, moves `Client`, `Libraries`, `Remotes`, `Assets` and `Interface` to `ReplicatedStorage.FindJobCampaign` (players need them) and starts `Server`, which stays private |
| `Server/` | server API, `Classifier`, `Missions/*` (validation), `Tracker` (tracking settings at the top), `World` |
| `Client/` | client API + modules (`Stand` screens/pedestals, `Dialogue`, `Clipboard`, `CodingGame`, `GradingGame`, `Guide`, `Recruiter`, `Feedback`, `Ui`); its `Start` script (RunContext Client) starts it on every player |
| `Libraries/` | `Config` (questions and points, jobs, missions and answers, reward, placement, text), `Signal` |
| `Remotes` | the RemoteEvents, real instances (`Remotes.model.json`); each one's `Description` attribute says who fires it and with what |
| `Interface` | the UI: a ScreenGui with one template per window (dialogue, clipboard, both missions, cards, toast), kept in the place file and edited in Studio. The client clones and fills them |
| `Assets` | optional fallback models, kept in the place file |

`src/host-example` is a stand-in host game, not part of the package: `HostGame` follows the campaign
and has the load/unload button, `RewardPopup` listens to `RewardGranted` and shows the host's own
reward popup (`StarterGui.RewardPopup`, made in Studio).

**Deploying into another game:** drop the `FindJobCampaign` folder into ServerScriptService and the
`Workspace.FindJobCampaign` models into the Workspace, then connect `RewardGranted`. Nothing else
in the host is touched.

### API for the host game

```lua
-- server
local Campaign = require(ServerScriptService.FindJobCampaign.Server)
Campaign.RewardGranted:Connect(function(player, reward) ... end) -- host decides how to grant it
-- where each player is: (player, ...)
Campaign.ConversationStarted / MissionStarted / MissionCompleted / CampaignFinished / PlayerExited
Campaign.EnabledChanged
Campaign:Exit(player)      -- stop the campaign for one player
Campaign:Disable()         -- remove it from the game (building, UI, sessions); :Enable() brings it back

-- client
local Campaign = require(ReplicatedStorage.FindJobCampaign.Client)
Campaign.CloseAllUi:Fire() -- or :Connect
Campaign.UiOpened / UiClosed
-- same flow events for the local player, e.g. close the host's menus on MissionStarted
Campaign.ConversationStarted / MissionStarted / MissionCompleted / CampaignFinished
Campaign:Exit()
```

## Security

The server owns the flow: every request is checked against the player's current step
(no mission before classification, no reward without a validated mission), payload shapes are
validated, answers are checked on the server (the puzzles sent to players leave them out), the reward is granted once per
player per server, and client analytics are whitelisted and sanitized. Station prompts are
`ProximityPrompt`s, so distance is enforced by the engine. All of this was exercised in a
playtest by firing the remotes directly.

## What we measure (and why)

Every event carries the same envelope (campaign, version, placeId, serverId, userId, time), so
data from different host games lines up. Printed as JSON to the output (`[FindJob:Track]`).

- **Funnel**: `NpcSeen` → `ConversationStarted` → `QuestionAnswered` → `Classified` → `MissionStarted`
  → `MissionAttempt` → `MissionCompleted` → `RewardGranted`, plus `Exited {step}`, so drop-off is visible per step.
- **Match quality**: the question we care about most is *was the job we picked actually right?*
  `Classified` records the score margin (how confident the questions were), missions record
  attempts and mistake types (e.g. teacher false ticks vs false crosses), and the player answers
  a fit check. `FitFeedback.verdict` combines them: `confirmed`, `likely`, `unsure_questions`
  (player disagreed and the questions were close) or `mismatch`. A rise in the last two means
  the questions need work.
- **Brand time**: `SessionEnded.seconds` – how long players spent with FindJob.
- **Health**: `RewardGranted.hostListening` (did the host wire up rewards?), `SubmissionRejected`
  (abuse attempts), `DialogueSkipped` (is the copy too long?), `returning` on replays.

## Cross-game challenges

- **Different host worlds**: the stand and Maya sit in one Workspace folder, so a host moves them
  in Studio like any model; `Disable()` parks that folder in ServerStorage and `Enable()` brings it
  back. A host that only has the code can drop the models in `Assets` instead and set
  `Config.World.Origin`. The stand and recruiter stream in as Atomic models, so
  games with StreamingEnabled never show half a stand. The UI uses its own ScreenGui, scales to the screen and
  emits `UiOpened`/`UiClosed` so hosts can hide their HUD.
- **Rewards without control of the host**: the campaign never touches host currency; it fires
  `RewardGranted` and warns (and tracks) if nobody is listening.
- **Consistent tracking**: shared envelope + versioned campaign id; client events are
  whitelisted so one host can't pollute the data.
- **Assets**: uploaded meshes/images are owned by one account and go through moderation (one
  image upload never cleared during development, so the exam paper is drawn in UI instead).
  Screens in the world show avatars as thumbnails, since ViewportFrames don't render on SurfaceGuis.
  A real rollout would publish assets under the brand's group and share them with host games.

## Art

Style "Expo Toy": an open-air job-fair stand (round platform, branded back wall, header
lightbox with 3D lettering, two totem screens with balloons, reception desk, LED strips,
spotlights, brochure rack) in chunky chamfered low-poly with flat colors. It is modelled big
and scaled to Roblox character size on import (desk and pedestals at about 3.4 studs).
Screens are dark panels with markers; the game draws live UI on them (`src/FindJobCampaign/Client/Stand.luau`),
so all text comes from `Config.Screens`.

- `art/blender/build_findjob.py` builds the stand and pedestals in Blender from code and exports `art/export/FindJob.fbx`
- `art/blender/build_sign.py` builds the big FindJob letters on the grass (Fredoka, `art/fonts`, OFL);
  `art/studio/place_sign.luau` puts them next to the stand, where the game makes them sparkle and hop
- `art/blender/build_ui_images.py` renders the clipboard image
- `art/blender/build_ui_sprites.py` draws the UI sprite kit (push button, panel, slot, sticker) as greyscale 9-slice PNGs; the game tints them, so the whole UI shares one look
- `art/upload.py` uploads through Open Cloud (`UPLOAD_KEY` in `.env`)
- `art/studio/build_interface.luau` builds the `Interface` templates from scratch (synced to
  `ServerStorage.FindJobTools.BuildInterface`; run `require(game.ServerStorage.FindJobTools.BuildInterface:Clone())`).
  After that the UI is edited in Studio; its header lists the names and attributes the code relies on
- `art/studio/post_import.luau` turns the inserted model into `Workspace.FindJobCampaign.Stand` (colors by
  name suffix, collisions, pedestal models with spinning items, recruiter spot and screens from
  markers, scale) and puts the game's own computer model (`monitor02`) on the programmer pedestal

The recruiter is a standard R15 rig (Bliss Interviewer shirt, TV presenter microphone, no face)
using Roblox's built-in emotes (wave, point, cheer, laugh, dance, set per moment in
`Recruiter.Moments`), so it animates in any game without uploading animations.
The models live in the place file; Rojo only manages code, so save the place after changing them.

## With more time

- Persist "already rewarded" with a DataStore (now per server) and send tracking through a batched HTTP queue
- A third field, and more questions picked at random so the match feels less obvious
- Mobile pass on touch drag-and-drop and controller support for the minigames
- Voice-over / sound effects, nicer celebration effects
- Unit tests for `Classifier` and mission validation
