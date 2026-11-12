# poor-man's-computer-use (pmcu)

Drive Windows app through an AI agent skill.

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

Run claude:

```bash
% claude
```

Run your first prompt:

```text
From https://github.com/tayaee/poor-mans-computer-use, install the pmcu skill with install.sh, then tile the Chrome browsers.
```

Run another prompt:

```text
/pmcu Cascade the Chrome browsers.
```
