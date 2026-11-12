---
name: pmcu
description: >
  poor man's computer use for WSL2 + Windows10. Call /pmcu to list/foreground/tile
  Windows host windows (chrome, KakaoTalk), click by relative coords, paste Korean
  text via clipboard+Ctrl+V, reuse cache on repeat runs. Triggers on: /pmcu,
  windows tile, kakaotalk click, chrome foreground, test paste.
---

# pmcu

`pmcu` is a CLI (Rust, std-only + powershell interop). No daemon, no AI inside.
Every Windows-host call prints one JSON envelope (`ok/data` or `ok:false/error`).

## First run

1. `pmcu status` — WSL_INTEROP, powershell reachable, script found.
2. `pmcu windows list --only chrome` — verify host windows visible.
3. Flags: `pmcu windows <list|foreground|tile|click-at|paste|launch> --help` is usage JSON.

## The loop (generic, app knowledge in recipes)

```
pmcu windows list --only KakaoTalk        # discover; launch if empty
pmcu windows launch --app kakao           # if not running
pmcu windows foreground --only KakaoTalk  # bring forward
pmcu windows click-at --only KakaoTalk --rel-x 0.5 --rel-y 0.9   # input area (cached)
pmcu windows paste --text '테스트'        # clipboard+Ctrl+V, no Enter
```

- App specifics live in `skills/pmcu/apps/<app>.md`, never in Rust. New app = 1 md.
- Repeat runs: `pmcu cache read kakaotalk` first; verify via fresh `list`, then reuse rel_xy. On miss, rediscover and `cache write`.
- Never press Enter after paste in tests. Eye-verify + `list` refocus check.

## References

- `apps/kakaotalk.md`: KakaoTalk recipe (Chats tab, list, input area).
- `../scripts/pmcu.ps1`: Win32 via powershell (EnumWindows/SetForeground/Move/SetCursorPos/mouse_event/clipboard).
