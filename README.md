# poor-man's-computer-use (pmcu)

Drive Windows app windows from WSL2 (or natively on Windows 10) through an AI agent skill.

## Install

One standard method, no toolchain needed. Installs the `pmcu` binary and the `/pmcu` skill pack.

- WSL2 / Linux:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/tayaee/poor-mans-computer-use/main/install.sh | sh
  ```
- Windows 10 (PowerShell):
  ```powershell
  irm https://raw.githubusercontent.com/tayaee/poor-mans-computer-use/main/install.ps1 | iex
  ```

Then make sure the bin directory (`~/.local/bin` or `~/bin`) is on your `PATH`.
Requires WSL2 with `powershell.exe` interop (default) or PowerShell 5.1+. No admin.

## Ask your agent

Paste any of these to an agent with the `/pmcu` skill:

> From https://github.com/tayaee/poor-mans-computer-use, install the pmcu skill (/pmcu) with install.sh, then using the pmcu skill rearrange the Chrome browsers into a tile layout.

> Using the pmcu skill, bring all Chrome windows to the front and tile them.

> Using the pmcu skill, open the "Jiyun Song" KakaoTalk chat and type '테스트' in the input box without sending.

The agent runs `pmcu status` → `pmcu windows list` → acts (`foreground` / `tile` / `click-at` / `paste`) → re-reads `list` to verify, and reports back. Fixed flows can be replayed as plain shell scripts with zero tokens.

## How it works

- `pmcu` (Rust, std-only) shells out to `powershell.exe`.
- `scripts/pmcu.ps1` (on the Windows host) does the Win32 calls: `EnumWindows`, `SetForegroundWindow`, `ShowWindow`, `MoveWindow`, `SetCursorPos` + `mouse_event`, clipboard + `Ctrl+V`.
- Every command prints one JSON envelope: `{"ok":true,"data":...}` or `{"ok":false,"error":{"code","kind","suggestion"}}`.

## Known limits (MVP)

- `SetForegroundWindow` may report `foregrounded:false` (focus-steal guard); the next click still activates the window.
- Tile uses the primary monitor work area; DPI scaling ignored.
- `paste` overwrites the Windows clipboard; Korean input goes through clipboard + `Ctrl+V` and never presses Enter.
- Click targets are relative coords cached per app (`~/.pmcu/cache/*.json`); UIA tree snapshot is Phase 2.
