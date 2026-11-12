# pmcu.ps1 - Windows host helper. Called from WSL pmcu via powershell.exe interop,
# or natively on Windows10. Stdout = single JSON envelope, stderr empty on success.
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

$ErrorActionPreference = 'Stop'

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32 {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc f, IntPtr p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool rep);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint a, uint b, ref RECT c, uint d);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
}
"@

function Ok($data) { @{ ok=$true; data=$data } | ConvertTo-Json -Depth 6 -Compress }
function Fail($code,$kind,$suggestion) { @{ ok=$false; error=@{ code=$code; kind=$kind; suggestion=$suggestion } } | ConvertTo-Json -Depth 6 -Compress }

function ProcNameOf($procId) {
  try { (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { "" }
}

function ListWindows($only, $titleLike="") {
  $rows = New-Object System.Collections.ArrayList
  $cb = [Win32+EnumWindowsProc]{
    param($h,$p)
    if (-not [Win32]::IsWindowVisible($h)) { return $true }
    $len = [Win32]::GetWindowTextLength($h)
    if ($len -le 0) { return $true }
    $sb = New-Object System.Text.StringBuilder(($len+1))
    [void][Win32]::GetWindowText($h,$sb,$sb.Capacity)
    $title = $sb.ToString()
    if ([string]::IsNullOrWhiteSpace($title)) { return $true }
    [uint32]$wpid = 0; [void][Win32]::GetWindowThreadProcessId($h,[ref]$wpid)
    $pn = ProcNameOf $wpid
    if ($only -and $pn.ToLower() -notlike ("*" + $only.ToLower() + "*")) { return $true }
    if ($titleLike -and $title -notlike ("*" + $titleLike + "*")) { return $true }
    $r = New-Object Win32+RECT
    [void][Win32]::GetWindowRect($h,[ref]$r)
    [void]$rows.Add(@{ hwnd=$h.ToInt64(); pid=$wpid; proc=$pn; title=$title;
      rect=@{ l=$r.L; t=$r.T; r=$r.R; b=$r.B; w=($r.R-$r.L); h=($r.B-$r.T) } })
    return $true
  }.GetNewClosure()
  # keep refs alive during call
  $keeper = @($cb)
  [void][Win32]::EnumWindows($cb,[IntPtr]::Zero)
  return $rows
}

function ForegroundWindows($only, $titleLike="") {
  $wins = ListWindows $only $titleLike
  $out = @()
  foreach ($w in $wins) {
    $h = [IntPtr]$w.hwnd
    [void][Win32]::ShowWindow($h, 9)  # RESTORE (also un-minimizes)
    Start-Sleep -Milliseconds 150
    $ok = [Win32]::SetForegroundWindow($h)
    if (-not $ok) { Start-Sleep -Milliseconds 400; $ok = [Win32]::SetForegroundWindow($h) }
    $out += @{ hwnd=$w.hwnd; pid=$w.pid; proc=$w.proc; title=$w.title; foregrounded=[bool]$ok }
  }
  return $out
}

function TileWindows($only) {
  $wins = ListWindows $only ""
  if ($wins.Count -eq 0) { return @() }
  $wa = New-Object Win32+RECT
  [void][Win32]::SystemParametersInfo(0x0030, 0, [ref]$wa, 0)  # SPI_GETWORKAREA
  $ax=$wa.L; $ay=$wa.T; $aw=$wa.R-$wa.L; $ah=$wa.B-$wa.T
  $n=$wins.Count; $cols=[math]::Ceiling([math]::Sqrt($n)); $rowsN=[math]::Ceiling($n/$cols)
  $cw=[math]::Floor($aw/$cols); $ch=[math]::Floor($ah/$rowsN)
  $out=@()
  for ($i=0;$i -lt $n;$i++) {
    $c=$i%$cols; $r=[math]::Floor($i/$cols)
    $x=$ax+$c*$cw; $y=$ay+$r*$ch
    $w=$wins[$i]; $h=[IntPtr]$w.hwnd
    [void][Win32]::ShowWindow($h,9); Start-Sleep -Milliseconds 100
    [void][Win32]::SetForegroundWindow($h)
    [void][Win32]::MoveWindow($h,$x,$y,$cw,$ch,$true)
    $out+=@{ hwnd=$w.hwnd; title=$w.title; x=$x; y=$y; w=$cw; h=$ch }
  }
  return $out
}

function ClickAt($only,$rx,$ry,$titleLike="") {
  $wins = ListWindows $only $titleLike
  if ($wins.Count -eq 0) { throw "no_window" }
  # pick largest-area window of that app
  $w = $wins | Sort-Object { $_.rect.w * $_.rect.h } -Descending | Select-Object -First 1
  $x = [int]($w.rect.l + $w.rect.w * $rx); $y = [int]($w.rect.t + $w.rect.h * $ry)
  $h=[IntPtr]$w.hwnd
  [void][Win32]::ShowWindow($h,9); Start-Sleep -Milliseconds 120
  [void][Win32]::SetForegroundWindow($h); Start-Sleep -Milliseconds 250
  [void][Win32]::SetCursorPos($x,$y); Start-Sleep -Milliseconds 120
  [Win32]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 60
  [Win32]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
  return @{ hwnd=$w.hwnd; title=$w.title; x=$x; y=$y; rel=@($rx,$ry) }
}

function PasteText($text) {
  Set-Clipboard -Value $text
  Start-Sleep -Milliseconds 150
  # Ctrl+V via keybd_event: Ctrl down, V down/up, Ctrl up. VK_CONTROL=0x11, V=0x56
  [Win32]::keybd_event(0x11,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 60
  [Win32]::keybd_event(0x56,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 60
  [Win32]::keybd_event(0x56,0,2,[UIntPtr]::Zero); Start-Sleep -Milliseconds 60
  [Win32]::keybd_event(0x11,0,2,[UIntPtr]::Zero)
  return @{ pasted=$text; method="clipboard+ctrl+v" }
}

try {
  $cmd = if ($Args.Count -gt 0) { $Args[0].ToLower() } else { "" }
  switch ($cmd) {
    "list" {
      $only=""; $titleLike=""
      for ($i=1;$i -lt $Args.Count;$i++){ if($Args[$i] -eq "--only" -and $i+1 -lt $Args.Count){$only=$Args[$i+1];$i++} elseif($Args[$i] -eq "--title" -and $i+1 -lt $Args.Count){$titleLike=$Args[$i+1];$i++} }
      $lw = ListWindows $only $titleLike
      Ok @{ windows=$lw; count=$lw.Count }
    }
    "foreground" {
      $only=""; $titleLike=""
      for ($i=1;$i -lt $Args.Count;$i++){ if($Args[$i] -eq "--only" -and $i+1 -lt $Args.Count){$only=$Args[$i+1];$i++} elseif($Args[$i] -eq "--title" -and $i+1 -lt $Args.Count){$titleLike=$Args[$i+1];$i++} }
      Ok @{ windows=ForegroundWindows $only $titleLike }
    }
    "tile" {
      $only=""; for ($i=1;$i -lt $Args.Count;$i++){ if($Args[$i] -eq "--only" -and $i+1 -lt $Args.Count){$only=$Args[$i+1];$i++} }
      Ok @{ tiled=TileWindows $only }
    }
    "click-at" {
      $only=""; $rx=0.5; $ry=0.9; $titleLike=""
      for ($i=1;$i -lt $Args.Count;$i++){
        if($Args[$i] -eq "--only" -and $i+1 -lt $Args.Count){$only=$Args[$i+1];$i++}
        elseif($Args[$i] -eq "--rel-x" -and $i+1 -lt $Args.Count){$rx=[double]$Args[$i+1];$i++}
        elseif($Args[$i] -eq "--rel-y" -and $i+1 -lt $Args.Count){$ry=[double]$Args[$i+1];$i++}
        elseif($Args[$i] -eq "--title" -and $i+1 -lt $Args.Count){$titleLike=$Args[$i+1];$i++}
      }
      Ok (ClickAt $only $rx $ry $titleLike)
    }
    "paste" {
      $text=""
      for ($i=1;$i -lt $Args.Count;$i++){ if($Args[$i] -eq "--text" -and $i+1 -lt $Args.Count){$text=$Args[$i+1];$i++} }
      if ([string]::IsNullOrEmpty($text)) { throw "missing --text" }
      Ok (PasteText $text)
    }
    "launch" {
      $app=""
      for ($i=1;$i -lt $Args.Count;$i++){ if($Args[$i] -eq "--app" -and $i+1 -lt $Args.Count){$app=$Args[$i+1];$i++} }
      if ($app -eq "chrome") { Start-Process "chrome.exe" }
      elseif ($app -like "*kakao*") { $p="${env:ProgramFiles}\Kakao\KakaoTalk\KakaoTalk.exe"; if(Test-Path $p){Start-Process $p}else{Start-Process "kakaotalk.exe"} }
      else { Start-Process $app }
      Start-Sleep -Milliseconds 1500
      Ok @{ launched=$app }
    }
    default { Fail "INVALID_ARGS" "unknown_command" "list|foreground|tile|click-at|paste|launch" }
  }
} catch {
  Fail "ACTION_FAILED" $_.Exception.Message "see pmcu status; window may be missing"
}
