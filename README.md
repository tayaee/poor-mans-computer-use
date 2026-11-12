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

## Examples with Agent

Start your coding agent in a terminal, then invoke the `/pmcu` skill.

Claude Code:

```bash
% claude
```

```text
/pmcu From https://github.com/tayaee/poor-mans-computer-use, install the pmcu skill with install.sh, then rearrange the Chrome browsers into a tile layout.
```

pi:

```bash
% pi
```

```text
/pmcu Bring all Chrome windows to the front and tile them.
```

```text
/pmcu Open the "Ai 인사이더 클럽" KakaoTalk chat and type '테스트' in the input box without sending.
```

The agent runs `pmcu status` → `pmcu windows list` → acts (`foreground` / `tile` / `click-at` / `paste`) → re-reads `list` to verify, and reports back. Fixed flows can be replayed as plain shell scripts with zero tokens.
