# MC Desktop Controller vs Yamaha Controller — Feature Gap Analysis

> MC Desktop Controller v1.19.0 (Electron/React Native Web, by Mathias Berg)  
> Yamaha Controller v1.4.0 (native SwiftUI, by Dan Butuc)

This document lists everything MC Desktop Controller has that Yamaha Controller does not. Used as a selective roadmap — not everything here will be built, only what's actually useful in daily use.

**Effort key:** 🟢 < 2h &nbsp; 🟡 half day &nbsp; 🔴 full day

---

## 1. Audio Processing & Sound Controls

MC Desktop Controller exposes the full YXC sound processing chain. We expose only Sound Program cycling.

| Feature | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| **Balance** — Left/right audio balance | ✅ | ❌ | 🟢 |
| **Equalizer** — Low / Mid / High sliders, modes: auto / manual / bypass | ✅ | ❌ | 🟡 |
| **Mono** — Collapse to mono output | ✅ | ❌ | 🟢 |
| **Surround:AI** — AI-driven adaptive surround | ✅ | ❌ | 🟢 |
| **Direct Audio** — Direct audio mode (no DSP) | ✅ | ❌ | 🟢 |
| **Surround 3D** — 3D surround processing settings | ✅ | ❌ | 🟢 |
| **Adaptive DSP Level** — DSP level intensity | ✅ | ❌ | 🟢 |
| **Dialogue Lift** — Elevate dialogue in soundstage | ✅ | ❌ | 🟢 |
| **YPAO Volume** — Room calibration volume tracking | ✅ | ❌ | 🟢 |
| **Clear Voice** — Voice intelligibility mode | ✅ | ❌ | 🟢 |
| **Speaker A/B Output** — Toggle between Speaker A and B | ✅ | ❌ | 🟢 |
| **Audio Select** — Audio input format selector | ✅ | ❌ | 🟢 |
| **DFS** — Dynamic Frequency Shift settings | ✅ | ❌ | 🟢 |
| **Auro-Matic** — Auro-3D preset and strength | ✅ | ❌ | 🟡 |
| **Video Preset** — Video processing preset selection | ✅ | ❌ | 🟢 |
| **Speaker Pattern** — Speaker channel configuration | ✅ | ❌ | 🟡 |

---

## 2. Multi-Room (MusicCast)

The biggest structural gap. MC Desktop Controller is designed around multi-device, multi-room management.

| Feature | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| **Multiple device support** — manage N receivers simultaneously | ✅ | ❌ | 🔴 |
| **Room list** — all devices shown as named rooms | ✅ | ❌ | 🔴 |
| **Link rooms** — sync playback across rooms | ✅ | ❌ | 🔴 |
| **Unlink rooms** — remove from group | ✅ | ❌ | 🔴 |
| **Party Mode** — send same audio to all linked rooms | ✅ | ❌ | 🔴 |
| **Zone B** — control Zone B output independently | ✅ | ❌ | 🟡 |
| **Zone 2 / 3 / 4** — full multi-zone support | ✅ | ❌ | 🔴 |
| **Zone Indicator** — visual status per zone | ✅ | ❌ | 🟡 |
| **Audio distribution settings** — distribution delay/quality | ✅ | ❌ | 🔴 |
| **Link Audio Delay** — audio sync / lip sync / balanced modes | ✅ | ❌ | 🔴 |
| **Link Audio Quality** — compressed vs lossless link | ✅ | ❌ | 🔴 |
| **Link Control** — speed / stability / standard modes | ✅ | ❌ | 🔴 |
| **Stereo Pair** — pair two MusicCast speakers as stereo | ✅ | ❌ | 🔴 |
| **Send to Bluetooth** — route audio to BT device | ✅ | ❌ | 🟡 |

---

## 3. Playback Queue & Content Controls

| Feature | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| **Play Queue** — view and reorder current queue | ✅ | ❌ | 🔴 |
| **Add to Queue** — add tracks/albums | ✅ | ❌ | 🔴 |
| **Clear Queue** | ✅ | ❌ | 🟢 |
| **Save Queue as MusicCast Playlist** | ✅ | ❌ | 🔴 |
| **Favourites** — add track, album, artist, station | ✅ | ❌ | 🔴 |
| **Thumbs Up / Down** — Pandora/streaming rating | ✅ | ❌ | 🟢 |
| **Bookmarks** — bookmark stations/tracks | ✅ | ❌ | 🟡 |
| **Search** — search within streaming services | ✅ | ❌ | 🔴 |
| **MusicCast Playlists** — create, manage, add to playlists | ✅ | ❌ | 🔴 |
| **Browse mode** — browse service content (albums, artists) | ✅ | ❌ | 🔴 |
| **CD track info** — display CD metadata | ✅ | ❌ | 🟢 |

---

## 4. Scenes & Routines

| Feature | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| **Scenes** — recall receiver scenes with custom icons | ✅ | ❌ | 🟡 |
| **Routines** — automation: set room + source + volume + linked rooms | ✅ | ❌ | 🔴 |
| **Routine editor** — name, icon, room, source, volume, link config | ✅ | ❌ | 🔴 |

---

## 5. Alarm (Enhanced)

We have a basic alarm (one per receiver). MC has a much more complete alarm system.

| Feature | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| **Wake volume** — set alarm volume separately from current | ✅ | ❌ | 🟢 |
| **Gradual volume / fade-in** — volume ramps up over time | ✅ | ❌ | 🟡 |
| **Alarm duration** — auto-off after N minutes | ✅ | ❌ | 🟢 |
| **One-day mode** — fire once on a specific date (not recurring) | ✅ | ❌ (recurring only) | 🟡 |
| **Resume last track** — wake to previously playing track | ✅ | ❌ | 🟢 |
| **Beep option** — alarm beep when no music source | ✅ | ❌ | 🟢 |
| **Multiple alarms** per device | ✅ | ❌ (one only) | 🔴 |
| **Snooze** — snooze button on alarm notification | ✅ | ❌ | 🟡 |
| **Alarm synced with receiver** — sync app alarm with on-device alarm | ✅ | ❌ | 🔴 |

---

## 6. Sleep Timer

| Feature | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| **Sleep Timer** — turns receiver off after N minutes | ✅ | ❌ | 🟢 |

---

## 7. Device Management

| Feature | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| **Firmware update** — check and trigger OTA update | ✅ | ❌ | 🟡 |
| **Reboot device** — remote restart | ✅ | ❌ | 🟢 |
| **Clock auto-sync** — set receiver clock to Mac time | ✅ | ❌ | 🟢 |
| **Network standby control** — toggle network standby mode | ✅ | ❌ | 🟢 |
| **Rename device/room** — custom label in app (stored locally) | ✅ | ❌ | 🟢 |
| **Disable / hide device** — hide unused rooms from list | ✅ | ❌ | 🟢 |
| **Delete all rooms** — bulk remove | ✅ | ❌ | 🟢 |

---

## 8. Bluetooth

| Feature | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| **Bluetooth TX settings** — transmit mode toggle | ✅ | ❌ | 🟢 |
| **Paired device list** — view and forget BT devices | ✅ | ❌ | 🟡 |
| **Bluetooth type** — configure BT codec/type | ✅ | ❌ | 🟢 |

---

## 9. App UI & Settings

| Feature | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| **Dark / Light / System theme** — three theme options | ✅ | ❌ (accent color only) | 🟡 |
| **Source ordering** — drag to reorder input sources | ✅ | ❌ | 🟡 |
| **Filter sources** — hide unwanted input sources | ✅ | ❌ | 🟡 |
| **Zoom in / out** — resize popover window | ✅ | ❌ | 🟢 |
| **Tooltip settings** — toggle/adjust tooltips | ✅ | ❌ | 🟢 |
| **Animation settings** — control transition animations | ✅ | ❌ | 🟢 |
| **App cache clearing** — clear persisted state from settings | ✅ | ❌ | 🟢 |
| **Room/device ordering** — drag to reorder devices | ✅ | ❌ | 🟡 |
| **Room greeting** — custom greeting text per room | ✅ | ❌ | 🟢 |
| **Localization** — multiple language support | ✅ | ❌ (English only) | 🔴 |

---

## 10. Keyboard Shortcuts (extended)

We have volume up/down, mute, play/pause, shuffle, repeat, prev/next. MC has more.

| Shortcut | MC Desktop | Yamaha Controller | Effort |
|---------|-----------|------------------|--------|
| Play / Pause (P) | ✅ | ✅ | — |
| Shuffle (S) | ✅ | ✅ | — |
| Repeat (R) | ✅ | ✅ | — |
| Previous (Cmd+←) | ✅ | ✅ | — |
| Next (Cmd+→) | ✅ | ✅ | — |
| Tooltip on active controls | ✅ | ❌ | 🟢 |
| Long press arrow — jump to start/end of source row | ✅ | ❌ | 🟢 |

---

## Summary by Priority

Not everything here should be built — only features with clear daily-use value. The categories below reflect implementation complexity, not necessity.

### 🟢 Quick wins (< 2h each, high value)
- **Sleep Timer** — one picker + `setSleepTimer` API call
- **Device reboot** — one button + confirm dialog
- **Clock auto-sync** — `setClock` with current Mac time
- **Wake volume on alarm** — add volume picker to existing MorningAlarmView
- **Zoom in/out** — adjust popover frame size

### 🟡 Half-day features (worth doing, moderate effort)
- **Balance slider**
- **Equalizer** (3 sliders + mode)
- **Scenes row** — `getSceneInfo` + `setScene`, similar to SceneButtonsView
- **Firmware update check + trigger**
- **Dark/Light/System theme** — extend current color scheme system
- **Filter / reorder source buttons** — drag-reorder in Settings
- **Alarm: one-day mode + fade-in**

### 🔴 Skip or defer (structural changes, diminishing returns)
- **Multi-room / MusicCast linking** — entire architecture rethink
- **Multiple device support** — multi-receiver state management
- **Zone 2/3/4** — hardware-dependent, TSR-400 likely unsupported
- **Browse/search streaming content** — each service needs its own API
- **MusicCast playlists / queue management** — complex, low daily use
- **Multiple alarms** — refactor of alarm system
- **Routines** — significant automation engine
- **Localization** — overhead without benefit for personal use

---

*Generated 2026-05-12. Last updated 2026-05-19 for v1.4.0 — removed Tone Control, Pure Direct, Enhancer, Bass Extension, Subwoofer Volume, Adaptive DRC, Dialogue Level, Surround Decoder, Device info, Signal info (implemented in v1.3). Added Play/Pause (P), Shuffle (S), Repeat (R), Prev (Cmd+←), Next (Cmd+→) keyboard shortcuts as ✅ (implemented in v1.3). Removed Play/Pause shortcut from Quick Wins.*
