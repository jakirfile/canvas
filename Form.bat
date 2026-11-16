<# : batch portion
@echo off
rem Form.bat - IJTC-ComBox. The application and its interface are in this file.
setlocal
set "COMBOX_FORM_SELF=%~f0"
set "COMBOX_FORM_POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if /I "%~1"=="/shortcut" goto shortcut
rem Start the complete application without a console window.
set "COMBOX_FORM_ACTION=launch"
"%COMBOX_FORM_POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABzAHQAYQByAHQASQBuAGYAbwAgAD0AIABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBEAGkAYQBnAG4AbwBzAHQAaQBjAHMALgBQAHIAbwBjAGUAcwBzAFMAdABhAHIAdABJAG4AZgBvAAoAJABzAHQAYQByAHQASQBuAGYAbwAuAEYAaQBsAGUATgBhAG0AZQAgAD0AIAAkAGUAbgB2ADoAQwBPAE0AQgBPAFgAXwBGAE8AUgBNAF8AUABPAFcARQBSAFMASABFAEwATAAKACQAcwB0AGEAcgB0AEkAbgBmAG8ALgBBAHIAZwB1AG0AZQBuAHQAcwAgAD0AIAAnAC0ATgBvAFAAcgBvAGYAaQBsAGUAIAAtAEUAeABlAGMAdQB0AGkAbwBuAFAAbwBsAGkAYwB5ACAAQgB5AHAAYQBzAHMAIAAtAFMAVABBACAALQBXAGkAbgBkAG8AdwBTAHQAeQBsAGUAIABIAGkAZABkAGUAbgAgAC0AQwBvAG0AbQBhAG4AZAAgACIAJgAgACgAWwBzAGMAcgBpAHAAdABiAGwAbwBjAGsAXQA6ADoAQwByAGUAYQB0AGUAKABbAEkATwAuAEYAaQBsAGUAXQA6ADoAUgBlAGEAZABBAGwAbABUAGUAeAB0ACgAJABlAG4AdgA6AEMATwBNAEIATwBYAF8ARgBPAFIATQBfAFMARQBMAEYAKQApACkAIgAnAAoAJABzAHQAYQByAHQASQBuAGYAbwAuAFUAcwBlAFMAaABlAGwAbABFAHgAZQBjAHUAdABlACAAPQAgACQAZgBhAGwAcwBlAAoAJABzAHQAYQByAHQASQBuAGYAbwAuAEMAcgBlAGEAdABlAE4AbwBXAGkAbgBkAG8AdwAgAD0AIAAkAHQAcgB1AGUACgAkAHMAdABhAHIAdABJAG4AZgBvAC4AVwBvAHIAawBpAG4AZwBEAGkAcgBlAGMAdABvAHIAeQAgAD0AIABTAHAAbABpAHQALQBQAGEAdABoACAALQBQAGEAcgBlAG4AdAAgACQAZQBuAHYAOgBDAE8ATQBCAE8AWABfAEYATwBSAE0AXwBTAEUATABGAAoAWwB2AG8AaQBkAF0AWwBTAHkAcwB0AGUAbQAuAEQAaQBhAGcAbgBvAHMAdABpAGMAcwAuAFAAcgBvAGMAZQBzAHMAXQA6ADoAUwB0AGEAcgB0ACgAJABzAHQAYQByAHQASQBuAGYAbwApAA==
exit /b 0
:shortcut
rem Create the IJTC desktop shortcut directly from this application file.
set "COMBOX_FORM_ACTION=shortcut"
"%COMBOX_FORM_POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -STA -Command "& ([scriptblock]::Create([IO.File]::ReadAllText($env:COMBOX_FORM_SELF)))"
if errorlevel 1 (
  pause
  exit /b 1
)
timeout /t 3 >nul
exit /b 0
#>
param(
  [switch]$UploadWorker,
  [string]$RepositoryUrl,
  [string]$GitHubUser,
  [string]$ProgressFile,
  [string]$ResultFile,
  [string]$SourceFolder,
  [string]$OnlyListFile,
  [switch]$RenameWorker,
  [string]$RenameRoot,
  [string]$RenameMappingFile,
  [string]$RenameProtectedNames,
  [switch]$DeleteRepoWorker,
  [string]$DeleteRepoUrl
)

$ErrorActionPreference = 'Stop'
$script:defaultRepositoryUrl = 'https://github.com/jakirfile/rubelapp'

function Invoke-EmbeddedRenameWorker {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$MappingFile,
    [string]$ProtectedNames
  )

  if (-not (Test-Path -LiteralPath $MappingFile -PathType Leaf)) {
    throw "Mapping file not found: $MappingFile"
  }
  $mappingInput = [IO.File]::ReadAllText($MappingFile).Trim()
  $mappingParts = $mappingInput.Split(',')
  if ($mappingParts.Count -ne 2) {
    throw 'Enter exactly two mappings separated by a comma.'
  }

  $renameMappings = @()
  foreach ($index in 0, 1) {
    $mapping = $mappingParts[$index].Trim()
    $separator = $mapping.IndexOf('=')
    if ($separator -le 0 -or $separator -eq ($mapping.Length - 1)) {
      $label = if ($index -eq 0) { 'upper-case' } else { 'lower-case' }
      throw "The $label mapping must use SOURCE=REPLACEMENT format."
    }
    $old = $mapping.Substring(0, $separator)
    $new = $mapping.Substring($separator + 1)
    if ([string]::IsNullOrWhiteSpace($old) -or [string]::IsNullOrWhiteSpace($new)) {
      throw 'Mapping source and replacement values must not be blank.'
    }
    if ($old -ceq $new) {
      $label = if ($index -eq 0) { 'upper-case' } else { 'lower-case' }
      throw "The $label source and replacement values are identical."
    }
    $renameMappings += [pscustomobject]@{
      Old = $old
      New = $new
    }
  }

  $rootPath = [IO.Path]::GetFullPath($Root)
  if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
    throw "Project folder does not exist: $rootPath"
  }
  $protectedScriptPaths = @(
    @('Rename.bat', 'Rename-Everything.bat', 'Rename-Everything.ps1') + @($ProtectedNames -split ',') |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { [IO.Path]::GetFullPath((Join-Path $rootPath $_)) }
  )

  $pendingDirectories = [System.Collections.Generic.Stack[string]]::new()
  $pendingDirectories.Push($rootPath)
  $scopedEntries = [System.Collections.Generic.List[System.IO.FileSystemInfo]]::new()
  while ($pendingDirectories.Count -gt 0) {
    $directory = $pendingDirectories.Pop()
    foreach ($entry in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
      if ($entry.Name -ieq '.git' -or
          $protectedScriptPaths -contains [IO.Path]::GetFullPath($entry.FullName)) {
        continue
      }
      $scopedEntries.Add($entry)
      if ($entry.PSIsContainer -and
          ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        $pendingDirectories.Push($entry.FullName)
      }
    }
  }

  $files = @($scopedEntries | Where-Object { -not $_.PSIsContainer })
  $paths = @($scopedEntries | Sort-Object { $_.FullName.Length } -Descending)
  Write-Host 'Scanning project files and folders (excluding .git)...'
  Write-Host "Found $($files.Count) files and $($paths.Count - $files.Count) folders."
  Write-Host 'Replacing text in files...'

  $updatedFiles = 0
  $processedFiles = 0
  foreach ($file in $files) {
    $processedFiles++
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -eq 0) {
      if ($processedFiles % 50 -eq 0) {
        Write-Host "Checked $processedFiles of $($files.Count) files..."
      }
      continue
    }

    $encoding = [Text.UTF8Encoding]::new($false, $true)
    $offset = 0
    if ($bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
      $encoding = [Text.UTF8Encoding]::new($true, $true)
      $offset = 3
    } elseif ($bytes.Length -ge 4 -and (
        ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) -or
        ($bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF)
    )) {
      continue
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
      $encoding = [Text.UnicodeEncoding]::new($false, $true, $true)
      $offset = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
      $encoding = [Text.UnicodeEncoding]::new($true, $true, $true)
      $offset = 2
    }

    try {
      $content = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
    } catch {
      if ($processedFiles % 50 -eq 0) {
        Write-Host "Checked $processedFiles of $($files.Count) files..."
      }
      continue
    }
    if ($content.Contains([char]0)) {
      if ($processedFiles % 50 -eq 0) {
        Write-Host "Checked $processedFiles of $($files.Count) files..."
      }
      continue
    }

    $updated = $content
    foreach ($renameMapping in $renameMappings) {
      $updated = $updated.Replace($renameMapping.Old, $renameMapping.New)
    }

    if ($updated -cne $content) {
      $newBytes = $encoding.GetBytes($updated)
      if ($offset -gt 0) {
        $newBytes = $encoding.GetPreamble() + $newBytes
      }
      [IO.File]::WriteAllBytes($file.FullName, $newBytes)
      $updatedFiles++
    }
    if ($processedFiles % 50 -eq 0 -or $processedFiles -eq $files.Count) {
      Write-Host "Checked $processedFiles of $($files.Count) files..."
    }
  }

  $renamedPaths = 0
  Write-Host 'Renaming matching files and folders...'
  $processedPaths = 0
  foreach ($item in $paths) {
    $processedPaths++
    $newName = $item.Name
    foreach ($renameMapping in $renameMappings) {
      $newName = $newName.Replace($renameMapping.Old, $renameMapping.New)
    }
    if ($newName -cne $item.Name) {
      $parentPath = if ($item.PSIsContainer) { $item.Parent.FullName } else { $item.DirectoryName }
      $destination = Join-Path $parentPath $newName
      if (Test-Path -LiteralPath $destination) {
        throw "Cannot rename '$($item.FullName)': destination already exists: $destination"
      }
      Rename-Item -LiteralPath $item.FullName -NewName $newName
      $renamedPaths++
    }
    if ($processedPaths % 50 -eq 0 -or $processedPaths -eq $paths.Count) {
      Write-Host "Checked $processedPaths of $($paths.Count) paths..."
    }
  }

  Write-Output "Upper-case mapping: $($mappingParts[0].Trim())"
  Write-Output "Lower-case mapping: $($mappingParts[1].Trim())"
  Write-Output "Updated text files: $updatedFiles"
  Write-Output "Renamed files/folders: $renamedPaths"
}

function Invoke-EmbeddedDeleteRepoWorker {
  param([Parameter(Mandatory = $true)][string]$RepositoryUrl)

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git was not found. Install Git for Windows and try again.'
  }
  if ($RepositoryUrl -notmatch '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?/?$') {
    throw 'Enter a valid HTTPS GitHub repository URL.'
  }

  $remoteOutput = @(& git ls-remote --symref $RepositoryUrl HEAD 2>&1)
  if ($LASTEXITCODE -ne 0) {
    $diagnostic = ($remoteOutput | ForEach-Object { "$_" } |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      Select-Object -Last 5) -join [Environment]::NewLine
    if ($diagnostic) {
      throw "Could not read the GitHub default branch. Check account access and network connection:`r`n$diagnostic"
    }
    throw 'Could not read the GitHub default branch. Check account access and network connection.'
  }
  $refLine = $remoteOutput | Where-Object { $_ -match '^ref:\s+refs/heads/' } | Select-Object -First 1
  if (-not $refLine -or $refLine -notmatch '^ref:\s+(refs/heads/\S+)\s+HEAD$') {
    throw 'Could not read the GitHub default branch.'
  }
  $defaultRef = $Matches[1]
  $branch = $defaultRef.Substring('refs/heads/'.Length)
  if (-not $branch) {
    throw "GitHub returned an unexpected default branch reference: $defaultRef"
  }

  $repositoryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("rre-web-source-delete-remote-$([Guid]::NewGuid().ToString('N'))")
  Write-Output ''
  Write-Output "WARNING: This will create and push a commit deleting every tracked file from $RepositoryUrl on its default branch: $branch"
  Write-Output 'The repository, its commit history, and other branches will remain.'
  Write-Output 'This operation changes GitHub and must not be run accidentally.'
  if (Test-Path -LiteralPath $repositoryDirectory) {
    throw "Temporary clone path already exists; refusing to use it: $repositoryDirectory"
  }

  Write-Output 'Cloning the default branch into a separate temporary directory...'
  $cloneOutput = New-Object 'System.Collections.Generic.List[string]'
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    & git clone --progress --single-branch --branch $branch $RepositoryUrl $repositoryDirectory 2>&1 | ForEach-Object {
      $line = [string]$_
      Write-Output $line
      if ($cloneOutput.Count -ge 8) {
        $cloneOutput.RemoveAt(0)
      }
      $cloneOutput.Add($line)
    }
    $cloneExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($cloneExitCode -ne 0) {
    $diagnostic = ($cloneOutput -join [Environment]::NewLine).Trim()
    if ($diagnostic) {
      throw "Clone failed (exit code $cloneExitCode). Git reported:`r`n$diagnostic`r`nNo push was attempted. Check GitHub authentication and repository access. Temporary path, if created: $repositoryDirectory"
    }
    throw "Clone failed with exit code $cloneExitCode and no Git output. Check GitHub authentication and repository access. No push was attempted. Temporary path, if created: $repositoryDirectory"
  }

  Write-Output 'Clone completed; staging deletion of tracked files...'
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $removeOutput = @(& git -C $repositoryDirectory rm -r -- . 2>&1 | ForEach-Object { "$_" })
    $removeExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  foreach ($line in $removeOutput) {
    Write-Output $line
  }
  if ($removeExitCode -ne 0) {
    throw "Could not stage deletion of all tracked files (exit code $removeExitCode). No push was attempted. Temporary checkout kept at: $repositoryDirectory"
  }

  Write-Output 'Deletion staged; creating the commit...'
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $commitOutput = @(& git -C $repositoryDirectory commit -m "Delete all tracked files from $branch" -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>' 2>&1 | ForEach-Object { "$_" })
    $commitExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  foreach ($line in $commitOutput) {
    Write-Output $line
  }
  if ($commitExitCode -ne 0) {
    throw "Commit failed (exit code $commitExitCode). No push was attempted. Check your Git author name and email configuration. Temporary checkout kept at: $repositoryDirectory"
  }

  Write-Output 'Commit created; pushing the deletion to GitHub...'
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $pushOutput = @(& git -C $repositoryDirectory push origin "HEAD:refs/heads/$branch" 2>&1 | ForEach-Object { "$_" })
    $pushExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  foreach ($line in $pushOutput) {
    Write-Output $line
  }
  if ($pushExitCode -ne 0) {
    throw "Push failed (exit code $pushExitCode). The remote branch was not force-updated. The deletion commit is kept at: $repositoryDirectory. Check authentication, branch protection, or whether the remote changed."
  }

  Write-Output ''
  Write-Output 'All tracked files have been deleted from the default branch.'
  Write-Output 'The repository, its history, and other branches remain on GitHub.'
  Remove-Item -LiteralPath $repositoryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $repositoryDirectory) {
    Write-Output "Could not remove the temporary clone: $repositoryDirectory"
  }
}

if ($RenameWorker -or $DeleteRepoWorker) {
  try {
    if ($RenameWorker -and $DeleteRepoWorker) {
      throw 'Select only one embedded worker.'
    }
    if ($RenameWorker) {
      Invoke-EmbeddedRenameWorker -Root $RenameRoot -MappingFile $RenameMappingFile -ProtectedNames $RenameProtectedNames
    } else {
      Invoke-EmbeddedDeleteRepoWorker -RepositoryUrl $DeleteRepoUrl
    }
    exit 0
  } catch {
    Write-Output $_
    exit 1
  }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class UploadWindowNative {
  public static void ShowMessage(string message, string title, bool isError) {
    MessageBox.Show(
      message,
      title,
      MessageBoxButtons.OK,
      isError ? MessageBoxIcon.Error : MessageBoxIcon.Information
    );
  }
}
'@ -ReferencedAssemblies 'System.Windows.Forms.dll'

# Form.bat is the application and worker script.
$applicationScriptPath = $env:COMBOX_FORM_SELF
if ([string]::IsNullOrWhiteSpace($applicationScriptPath)) {
  $applicationScriptPath = $MyInvocation.MyCommand.Path
}
$toolDirectory = Split-Path -Parent $applicationScriptPath
$projectDirectory = Split-Path -Parent $toolDirectory
# Inside a project (e.g. <project>\CommandBox) the parent folder is the default
# project; when this tool lives in its own folder (e.g. D:\IJTC-ComBox) that
# folder itself is the default.
if (-not (Test-Path -LiteralPath (Join-Path $projectDirectory 'wrangler.jsonc') -PathType Leaf) -and
    -not (Test-Path -LiteralPath (Join-Path $projectDirectory '.git') -PathType Container)) {
  $projectDirectory = $toolDirectory
}

$script:notificationSoundAlias = 'comboxNotification'
$script:notificationSoundOpen = $false
if (-not ('IjtcNotificationAudio' -as [type])) {
  Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class IjtcNotificationAudio {
  [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
  public static extern int mciSendString(string command, StringBuilder result, int resultLength, IntPtr callback);

  [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
  public static extern bool mciGetErrorString(int errorCode, StringBuilder errorText, int errorTextLength);
}
'@
}

function Send-NotificationAudioCommand {
  param([string]$Command)
  $result = [IjtcNotificationAudio]::mciSendString($Command, $null, 0, [IntPtr]::Zero)
  if ($result -ne 0) {
    $errorText = New-Object System.Text.StringBuilder 256
    if (-not [IjtcNotificationAudio]::mciGetErrorString($result, $errorText, $errorText.Capacity)) {
      throw "Audio command failed with MCI error $result."
    }
    throw $errorText.ToString()
  }
}

function Play-NotificationSound {
  if (-not $script:notificationSoundOpen) {
    $soundPath = Join-Path $toolDirectory 'beep.mp3'
    if (-not (Test-Path -LiteralPath $soundPath -PathType Leaf)) {
      throw "Notification sound was not found: $soundPath"
    }
    $escapedPath = $soundPath.Replace('"', '""')
    Send-NotificationAudioCommand "open `"$escapedPath`" type mpegvideo alias $script:notificationSoundAlias"
    $script:notificationSoundOpen = $true
  } else {
    Send-NotificationAudioCommand "stop $script:notificationSoundAlias"
    Send-NotificationAudioCommand "seek $script:notificationSoundAlias to start"
  }
  Send-NotificationAudioCommand "play $script:notificationSoundAlias"
}

function Close-NotificationSound {
  if ($script:notificationSoundOpen) {
    [void][IjtcNotificationAudio]::mciSendString(
      "close $script:notificationSoundAlias",
      $null,
      0,
      [IntPtr]::Zero
    )
    $script:notificationSoundOpen = $false
  }
}

# ===========================================================================
# PowerShell form and application.
# ===========================================================================

# ---------------------------------------------------------------------------
# 1. LAYOUT SETTINGS - change these to change the form's structure.
# ---------------------------------------------------------------------------
$FormLayout = @{
  Title           = 'IJTC-ComBox'
  Width           = 980                    # window width (pixels)
  StartHeight     = 544                    # first height; each tab then sets its own
  Font            = @('Segoe UI', 10)
  BackColor       = @(246, 248, 251)       # window background
  CaptionColor    = @(242, 242, 242)       # title bar background
  AccentColor     = @(38, 105, 176)        # blue: panel titles, active tab text
  BorderColor     = @(176, 192, 212)       # outer border and tab bar border
  LineColor       = @(214, 221, 230)       # thin lines inside panels
  ActiveTabColor  = @(222, 233, 246)       # background of the open tab
  TabTextColor    = @(110, 110, 110)       # text/icon colour of the other tabs
  TabBarHeight    = 46                     # tab bar row (button row 38 + gap)
  FolderBarHeight = 44                     # folder bar row under the tabs

  # Title bar buttons, right to left on screen. X = left edge, W = width,
  # Glyph = Segoe MDL2 Assets symbol, Size = symbol size.
  Caption = @{
    undo     = @{ X = 678; W = 42; Glyph = 0xE7A7; Size = 12; Tip = 'Undo' }
    redo     = @{ X = 720; W = 42; Glyph = 0xE7A6; Size = 12; Tip = 'Redo' }
    account  = @{ X = 762; W = 42; Glyph = 0xE77B; Size = 12; Tip = 'GitHub account' }
    shortcut = @{ X = 804; W = 42; Glyph = 0xE7F4; Size = 12; Tip = 'Create the "IJTC" shortcut on the desktop' }
    minimize = @{ X = 848; W = 42; Glyph = 0xE921; Size = 9;  Tip = 'Minimize' }
    restart  = @{ X = 890; W = 44; Glyph = 0xE72C; Size = 13; Tip = 'Restart IJTC-ComBox' }
    close    = @{ X = 934; W = 46; Glyph = 0xE8BB; Size = 9;  Tip = 'Close' }
  }

  # Tab bar, left to right. Reorder the lines to reorder the tabs.
  #   Style: logo  = the site's own icon (downloaded once), Glyph until then
  #          icon  = Glyph only
  #          textSymbol = Label followed by Glyph
  #          text  = Label only
  #   Width: fixed width in pixels (optional; other tabs share the rest)
  #   Color / ActiveBack / HoverBack: fixed colours for this tab (optional)
  #   Action = 'toggleTabs': not a tab; shows/hides every tab to its right
  Tabs = @(
    @{ Key = 'home';        Var = 'homeToggleButton';       Style = 'icon';       Label = 'Home';         Glyph = 0xE80F; Width = 50; Tip = 'Home' }
    @{ Key = 'tabtoggle';   Var = 'tabToggleButton';        Style = 'icon';       Label = 'Show/Hide tabs'; Glyph = 0xE76B; GlyphSize = 11; Width = 40; Action = 'toggleTabs'; Tip = 'Hide the tabs on the right' }
    @{ Key = 'diagram';     Var = 'diagramToggleButton';    Style = 'icon';       Label = 'Diagram';      Glyph = 0xE9D5; Tip = 'Show the blank Diagram page' }
    @{ Key = 'cloudflare';  Var = 'cloudflareToggleButton'; Style = 'icon';       Label = 'Cloudflare';   Glyph = 0xE753; Tip = 'Cloudflare' }
    @{ Key = 'relation';    Var = 'relationToggleButton';   Style = 'icon';       Label = 'Relation';     Glyph = 0xE71B; Tip = 'Show the worker.js file relation graph' }
    @{ Key = 'rename';      Var = 'renameToggleButton';     Style = 'icon';       Label = 'Rename';       Glyph = 0xE8AC; Tip = 'Rename' }
    @{ Key = 'adb';         Var = 'adbToggleButton';        Style = 'text';       Label = 'ADB';          Tip = 'Show the ADB section' }
    @{ Key = 'runlocal';    Var = 'runLocalToggleButton';   Style = 'icon';       Label = 'Server';       Glyph = 0xE774; Tip = 'Server' }
  )
  HomeFieldLeft = 110                      # Home: left edge of the URL and Folder boxes
  FirstTab = 'home'                        # tab shown when the form opens

  # Each tab's area under the folder bar.
  #   Height:    how much the window grows for this tab
  #   HeightVar: variable that holds the height (some tabs adjust it at run time)
  #   Flag:      variable that is $true while the tab is open
  #   Controls:  controls shown only on this tab (Cloudflare has its own list)
  Sections = [ordered]@{
    home        = @{ Height = 394; HeightVar = 'homeSectionHeight';        Flag = 'showHomeSection';        Controls = @('homePanel', 'homeRepoLabel', 'homeRepoBox', 'homeUploadButton', 'homeDownloadButton', 'homeCopyButton', 'homeCleanButton', 'homeLocalDeleteButton', 'homeOpenButton', 'homeRepoSearchButton', 'homeStatusLabel') }
    diagram     = @{ Height = 394; HeightVar = 'diagramSectionHeight';      Flag = 'showDiagramSection';      Controls = @('diagramProjectLabel', 'diagramProjectBox', 'diagramProjectBrowseButton', 'diagramRepoBrowseButton', 'diagramLocalButton', 'diagramRepoButton', 'diagramBackButton', 'diagramPageLabel', 'diagramPageBox', 'diagramPageSaveButton', 'diagramBrowsePathLabel', 'diagramFileList', 'diagramEditorStatusLabel', 'diagramSearchBox', 'diagramSearchButton', 'diagramUndoButton', 'diagramRedoButton', 'diagramRefreshButton', 'diagramImportButton', 'diagramExportButton', 'diagramLineNumberGutter', 'diagramFileEditor', 'diagramFileGrid') }
    cloudflare  = @{ Height = 279; HeightVar = 'cloudflareSectionHeight';  Flag = 'showCloudflareSection';  Controls = @() }
    relation    = @{ Height = 394; HeightVar = 'relationSectionHeight';     Flag = 'showRelationSection';     Controls = @('relationFolderLabel', 'relationFolderBox', 'relationBrowseButton', 'relationRepoLabel', 'relationRepoBox', 'relationRepoSearchButton', 'relationStatusLabel', 'relationRefreshButton', 'relationCopyButton', 'relationFixButton', 'relationGraphViewport') }
    rename      = @{ Height = 225; HeightVar = 'renameSectionHeight';      Flag = 'showRenameSection';      Controls = @('renamePanel', 'renameStatusLabel', 'renameSearchLabel', 'renameSearchBox', 'renameSearchButton', 'renameSearchRefreshButton') }
    adb         = @{ Height = 267; HeightVar = 'adbSectionHeight';         Flag = 'showAdbSection';         Controls = @('adbPanel') }
    runlocal            = @{ Height = 210; HeightVar = 'toolSectionHeight';        Flag = 'showRunLocalSection';    Controls = @('runLocalPanel', 'runLocalStatusLabel') }
  }

  # Bordered panels: title and position (X, Y, W, H) inside the tab area.
  # Y is counted from the top of the tab area (the form moves it below the bars).
  Panels = @{
    home                = @{ Title = 'Details :';                  X = 35;  Y = 88;  W = 910; H = 300 }   # Home: empty box (under the GitHub repo row)
    cloudflareDeploy    = @{ Title = 'Cloudflare deploy';          X = 35;  Y = 135; W = 446; H = 134 }
    cloudflareSecrets   = @{ Title = 'Cloudflare secrets';         X = 499; Y = 135; W = 446; H = 134 }
    cloudflareWebpage   = @{ Title = 'Manage Deploy';              X = 35;  Y = 48;  W = 910; H = 84 }
    rename              = @{ Title = 'Rename files and folders';   X = 35;  Y = 44;  W = 910; H = 175 }
    runlocal            = @{ Title = 'Upload Info';                X = 35;  Y = 44;  W = 910; H = 160 }
    adb                 = @{ Title = 'ADB';                        X = 35;  Y = 44;  W = 910; H = 217 }
  }

  # Folder bar of each tab: its label, tooltip and default folder.
  # Default is worked out when the form starts ($projectDirectory = this tool's project).
  Folders = [ordered]@{
    home        = @{ Label = 'Folder :';         Hint = 'Home folder';                                             Default = { $projectDirectory } }
    relation    = @{ Label = 'PC Folder';        Hint = 'Local project folder for the worker.js relation graph';   Default = { $projectDirectory }; Hidden = $true }
    # Hidden = $true: the tab shows no folder bar (it still uses its saved folder).
    cloudflare  = @{ Label = 'Project folder';   Hint = 'Folder deployed to Cloudflare (uses its wrangler.jsonc)'; Default = { $projectDirectory }; Hidden = $true }
    rename      = @{ Label = 'Rename folder';    Hint = 'Folder whose text and file/folder names are renamed';     Default = { $projectDirectory } }
    adb         = @{ Label = 'Android project';  Hint = 'Android project folder used by the ADB tab';    Default = { if (Test-Path -LiteralPath 'D:\AllApp-Android-Source' -PathType Container) { 'D:\AllApp-Android-Source' } else { $projectDirectory } } }
    runlocal    = @{ Label = 'Local';            Hint = 'Folder served by the Server (uses its scripts and Data)'; Default = { $projectDirectory } }
  }
}

# ---------------------------------------------------------------------------
# 2. HELPERS used by the form and by every tab.
# ---------------------------------------------------------------------------
# Windows calls that let the borderless window be dragged by its title bar.
if (-not ('ComBoxFormNative' -as [type])) {
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ComBoxFormNative {
  [DllImport("user32.dll")]
  public static extern bool ReleaseCapture();
  [DllImport("user32.dll")]
  public static extern IntPtr SendMessage(IntPtr handle, int message, IntPtr wParam, IntPtr lParam);
}
'@
}

# Starts IJTC-ComBox as a process without any
# console window, so no cmd/PowerShell window appears in the taskbar.
function Start-ComBoxHidden {
  param([switch]$PreserveLocalServer)
  $formPath = if ($env:COMBOX_FORM_SELF) { $env:COMBOX_FORM_SELF } else { Join-Path $toolDirectory 'Form.bat' }
  if (-not (Test-Path -LiteralPath $formPath -PathType Leaf)) {
    throw "Form.bat was not found: $formPath"
  }
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command "& ([scriptblock]::Create([IO.File]::ReadAllText($env:COMBOX_FORM_SELF)))"'
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.WorkingDirectory = Split-Path -Parent $formPath
  $startInfo.EnvironmentVariables['COMBOX_FORM_SELF'] = $formPath
  $startInfo.EnvironmentVariables.Remove('COMBOX_FORM_ACTION')
  $startInfo.EnvironmentVariables.Remove('COMBOX_PRESERVE_LOCAL_SERVER')
  if ($PreserveLocalServer) {
    $startInfo.EnvironmentVariables['COMBOX_PRESERVE_LOCAL_SERVER'] = '1'
  }
  [void][System.Diagnostics.Process]::Start($startInfo)
}

# Creates the "IJTC" desktop shortcut that opens this application in PowerShell. Returns its path.
function New-ComBoxShortcut {
  $formPath = if ($env:COMBOX_FORM_SELF) { $env:COMBOX_FORM_SELF } else { Join-Path $toolDirectory 'Form.bat' }
  if (-not (Test-Path -LiteralPath $formPath -PathType Leaf)) {
    throw "Form.bat was not found: $formPath"
  }
  $desktop = [Environment]::GetFolderPath('Desktop')
  $linkPath = Join-Path $desktop 'IJTC.lnk'
  $shell = New-Object -ComObject WScript.Shell
  try {
    $link = $shell.CreateShortcut($linkPath)
    $link.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $shortcutCommand = '$env:COMBOX_FORM_SELF = ''' + $formPath.Replace("'", "''") + '''; $env:COMBOX_FORM_ACTION = ''launch''; & ([scriptblock]::Create([IO.File]::ReadAllText($env:COMBOX_FORM_SELF)))'
    $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($shortcutCommand))
    $link.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -EncodedCommand ' + $encodedCommand
    $link.WindowStyle = 7
    $link.WorkingDirectory = Split-Path -Parent $formPath
    $link.IconLocation = (Join-Path $env:SystemRoot 'System32\shell32.dll') + ',43'
    $link.Description = $FormLayout.Title
    $link.Save()
  } finally {
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
  }
  return $linkPath
}

# Message window for every tab. Short messages: a normal message box. Long ones
# (deploy / upload logs): a resizable window with a scrollable, copyable text box.
function Show-ComBoxMessage {
  param([string]$Message, [string]$Title = 'IJTC-ComBox', [bool]$IsError = $false)
  $lineCount = ($Message -split "`n").Count
  if ($lineCount -le 12 -and $Message.Length -le 700) {
    $icon = if ($IsError) { [System.Windows.Forms.MessageBoxIcon]::Error } else { [System.Windows.Forms.MessageBoxIcon]::Information }
    [void][System.Windows.Forms.MessageBox]::Show($form, $Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
    return
  }
  $dialog = New-Object System.Windows.Forms.Form
  $dialog.Text = $Title
  $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
  $dialog.Size = New-Object System.Drawing.Size(820, 520)
  $dialog.MinimumSize = New-Object System.Drawing.Size(420, 260)
  $dialog.ShowInTaskbar = $false
  $dialog.MinimizeBox = $false
  $dialog.MaximizeBox = $true
  $dialog.BackColor = [System.Drawing.Color]::White
  $box = New-Object System.Windows.Forms.TextBox
  $box.Multiline = $true
  $box.ReadOnly = $true
  $box.WordWrap = $false
  $box.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
  $box.Font = New-Object System.Drawing.Font('Consolas', 9.5)
  $box.BackColor = [System.Drawing.Color]::White
  $box.ForeColor = if ($IsError) { [System.Drawing.Color]::Firebrick } else { [System.Drawing.Color]::FromArgb(40, 50, 60) }
  $box.Location = New-Object System.Drawing.Point(12, 12)
  $box.Size = New-Object System.Drawing.Size(($dialog.ClientSize.Width - 24), ($dialog.ClientSize.Height - 64))
  $box.Anchor = 'Top, Bottom, Left, Right'
  $box.Text = ($Message -replace "(?<!`r)`n", "`r`n")
  $dialog.Controls.Add($box)
  $copy = New-Object System.Windows.Forms.Button
  $copy.Text = 'Copy'
  $copy.Size = New-Object System.Drawing.Size(90, 30)
  $copy.Location = New-Object System.Drawing.Point(($dialog.ClientSize.Width - 204), ($dialog.ClientSize.Height - 42))
  $copy.Anchor = 'Bottom, Right'
  $copy.Add_Click({ [System.Windows.Forms.Clipboard]::SetText($box.Text) })
  $dialog.Controls.Add($copy)
  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = 'OK'
  $ok.Size = New-Object System.Drawing.Size(90, 30)
  $ok.Location = New-Object System.Drawing.Point(($dialog.ClientSize.Width - 102), ($dialog.ClientSize.Height - 42))
  $ok.Anchor = 'Bottom, Right'
  $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $dialog.Controls.Add($ok)
  $dialog.AcceptButton = $ok
  $dialog.CancelButton = $ok
  $dialog.Add_Shown({ $box.SelectionStart = $box.TextLength; $box.ScrollToCaret(); $ok.Focus() })
  Register-FormButtonSoundControl $dialog
  try {
    if ($form -and $form.Visible) { [void]$dialog.ShowDialog($form) } else { [void]$dialog.ShowDialog() }
  } finally {
    $dialog.Dispose()
  }
}

function Get-FormColor {
  param([object[]]$Rgb)
  return [System.Drawing.Color]::FromArgb($Rgb[0], $Rgb[1], $Rgb[2])
}

function New-CaptionButton {
  param([string]$Text, [string]$AccessibleName, [int]$X, [int]$Width, [bool]$Emphasized = $false)
  $button = New-Object System.Windows.Forms.Button
  $button.Text = $Text
  $button.AccessibleName = $AccessibleName
  $button.Location = New-Object System.Drawing.Point($X, 0)
  $button.Size = New-Object System.Drawing.Size($Width, 36)
  $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $button.FlatAppearance.BorderSize = 0
  $button.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  if ($Emphasized) {
    $button.BackColor = Get-FormColor $FormLayout.AccentColor
    $button.ForeColor = [System.Drawing.Color]::White
  } else {
    $button.BackColor = $captionBar.BackColor
    $button.ForeColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
  }
  $captionBar.Controls.Add($button)
  return $button
}

# Title bar button from the Caption settings above (symbol, position, tooltip).
function New-FormCaptionButton {
  param([string]$Key)
  $info = $FormLayout.Caption[$Key]
  $button = New-CaptionButton ([string][char]$info.Glyph) $info.Tip $info.X $info.W
  $button.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', $info.Size)
  $toolTip.SetToolTip($button, $info.Tip)
  return $button
}

function New-Label {
  param([string]$Text, [int]$X, [int]$Y, [int]$Width = 900, [int]$Height = 24)
  $label = New-Object System.Windows.Forms.Label
  $label.Text = $Text
  $label.Location = New-Object System.Drawing.Point($X, $Y)
  $label.Size = New-Object System.Drawing.Size($Width, $Height)
  $label.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $form.Controls.Add($label)
  return $label
}

function New-ActionButton {
  param([string]$AccessibleName, [int]$GlyphCode, [int]$X, [int]$Y, [int]$Width = 32, [int]$Height = 30)
  $button = New-Object System.Windows.Forms.Button
  $button.Text = [string][char]$GlyphCode
  $button.Location = New-Object System.Drawing.Point($X, $Y)
  $button.Size = New-Object System.Drawing.Size($Width, $Height)
  $button.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $button.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $button.Cursor = [System.Windows.Forms.Cursors]::Hand
  $button.AccessibleName = $AccessibleName
  $button.AccessibleDescription = $AccessibleName
  $toolTip.SetToolTip($button, $AccessibleName)
  $form.Controls.Add($button)
  return $button
}

function New-SectionPanel {
  param([string]$Title, [int]$X, [int]$Y, [int]$Width, [int]$Height)
  $panel = New-Object System.Windows.Forms.Panel
  $panel.Location = New-Object System.Drawing.Point($X, $Y)
  $panel.Size = New-Object System.Drawing.Size($Width, $Height)
  $panel.BackColor = [System.Drawing.Color]::White
  $panel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
  $panel.Add_Paint({
    param($sender, $eventArgs)
    $pen = New-Object System.Drawing.Pen (Get-FormColor $FormLayout.LineColor)
    try {
      $eventArgs.Graphics.DrawRectangle($pen, 0, 0, $sender.Width - 1, $sender.Height - 1)
      $eventArgs.Graphics.DrawLine($pen, 14, 32, $sender.Width - 15, 32)
    } finally {
      $pen.Dispose()
    }
  })
  $titleLabel = New-Object System.Windows.Forms.Label
  $titleLabel.Text = $Title
  $titleLabel.Location = New-Object System.Drawing.Point(14, 7)
  $titleLabel.Size = New-Object System.Drawing.Size(($Width - 28), 22)
  $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
  $titleLabel.ForeColor = Get-FormColor $FormLayout.AccentColor
  $panel.Controls.Add($titleLabel)
  $panel.Tag = $titleLabel
  $form.Controls.Add($panel)
  return $panel
}

# Bordered panel from the Panels settings above. -BelowBars: for panels made
# after the bars were added (their Y is moved below the tab and folder bars).
function New-FormSectionPanel {
  param([string]$Key, [switch]$BelowBars)
  $info = $FormLayout.Panels[$Key]
  $y = $info.Y
  if ($BelowBars) {
    $y += $FormLayout.TabBarHeight + $FormLayout.FolderBarHeight
  }
  return (New-SectionPanel $info.Title $info.X $y $info.W $info.H)
}

function Move-IntoPanel {
  param($Panel, [object[]]$Layout)
  foreach ($item in $Layout) {
    $control = $item[0]
    $form.Controls.Remove($control)
    $control.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $control.Location = New-Object System.Drawing.Point($item[1], $item[2])
    $control.Size = New-Object System.Drawing.Size($item[3], $item[4])
    $Panel.Controls.Add($control)
  }
}

# Folder bar settings with each default folder worked out now.
function Get-FormFolderInfo {
  $info = [ordered]@{}
  foreach ($key in $FormLayout.Folders.Keys) {
    $entry = $FormLayout.Folders[$key]
    $info[$key] = @{ Label = $entry.Label; Hint = $entry.Hint; Default = [string](& $entry.Default); Hidden = [bool]$entry.Hidden }
  }
  return $info
}

# ---------------------------------------------------------------------------
# 3. WINDOW: the borderless window, title bar and its buttons, outer border.
#    Run with ". $FormParts.Window".
# ---------------------------------------------------------------------------
$FormParts = @{}
$FormParts.Window = {
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $FormLayout.Title
  $form.StartPosition = 'CenterScreen'
  $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
  $form.ClientSize = New-Object System.Drawing.Size($FormLayout.Width, $FormLayout.StartHeight)
  $form.MinimumSize = $form.ClientSize
  $form.MaximumSize = $form.ClientSize
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.ShowInTaskbar = $true
  $form.Font = New-Object System.Drawing.Font($FormLayout.Font[0], $FormLayout.Font[1])
  $form.BackColor = Get-FormColor $FormLayout.BackColor
  $toolTip = New-Object System.Windows.Forms.ToolTip

  $captionBar = New-Object System.Windows.Forms.Panel
  $captionBar.Location = New-Object System.Drawing.Point(0, 0)
  $captionBar.Size = New-Object System.Drawing.Size($FormLayout.Width, 36)
  $captionBar.BackColor = Get-FormColor $FormLayout.CaptionColor
  $captionBar.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
  $form.Controls.Add($captionBar)
  $captionTitle = New-Object System.Windows.Forms.Label
  $captionTitle.Text = $FormLayout.Title
  $captionTitle.Location = New-Object System.Drawing.Point(12, 0)
  $captionTitle.Size = New-Object System.Drawing.Size(310, 36)
  $captionTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
  $captionTitle.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $captionTitle.ForeColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
  $captionBar.Controls.Add($captionTitle)

  $minimizeButton = New-FormCaptionButton 'minimize'
  $restartButton = New-FormCaptionButton 'restart'
  $closeButton = New-FormCaptionButton 'close'
  $shortcutButton = New-FormCaptionButton 'shortcut'

  $minimizeButton.Add_Click({ $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized })
  $closeButton.Add_Click({ $form.Close() })
  $restartButton.Add_Click({
    try {
      # Save first, so the new window opens in the same state.
      Save-FormState
      Start-ComBoxHidden -PreserveLocalServer:$script:runLocalStartedByForm
      $script:runLocalStartedByForm = $false
      $form.Close()
    } catch {
      Show-ComBoxMessage ($_.Exception.Message) 'Could not restart' $true
    }
  })
  # Desktop shortcut button: creates "IJTC" on the desktop that opens Form.bat.
  $shortcutButton.Add_Click({
    try {
      $linkPath = New-ComBoxShortcut
      Show-SectionMessage "Desktop shortcut created: $linkPath"
    } catch {
      Show-ComBoxMessage ($_.Exception.Message) 'Could not create the desktop shortcut' $true
    }
  })
  # Drag the borderless window by its title bar.
  $captionDrag = {
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
      [void][ComBoxFormNative]::ReleaseCapture()
      [void][ComBoxFormNative]::SendMessage($form.Handle, 0xA1, [IntPtr]2, [IntPtr]::Zero)
    }
  }
  $captionBar.Add_MouseDown($captionDrag)
  $captionTitle.Add_MouseDown($captionDrag)

  # One border around the visible tab, with the folder bar at its top.
  $form.Add_Paint({
    param($sender, $eventArgs)
    $pen = New-Object System.Drawing.Pen (Get-FormColor $FormLayout.BorderColor)
    try {
      $eventArgs.Graphics.DrawRectangle($pen, 25, (39 + $tabBarHeight), ($FormLayout.Width - 51), ($sender.ClientSize.Height - 49 - $tabBarHeight))
      $linePen = New-Object System.Drawing.Pen (Get-FormColor $FormLayout.LineColor)
      try {
        $lineY = 39 + $tabBarHeight + $folderBarHeight - 4
        if (-not (Test-FolderBarHidden)) {
          $eventArgs.Graphics.DrawLine($linePen, 35, $lineY, ($FormLayout.Width - 36), $lineY)
        }
      } finally {
        $linePen.Dispose()
      }
    } finally {
      $pen.Dispose()
    }
  })

  # Which tab is open, and the height each tab needs.
  $script:currentSection = $FormLayout.FirstTab
  foreach ($key in $FormLayout.Sections.Keys) {
    $section = $FormLayout.Sections[$key]
    Set-Variable -Scope Script -Name $section.Flag -Value ($key -eq $FormLayout.FirstTab)
    Set-Variable -Scope Script -Name $section.HeightVar -Value $section.Height
  }
  $script:cloudflareLocalFilesExpanded = $false
}

# ---------------------------------------------------------------------------
# 4. BARS: moves every tab's controls below the tab bar and folder bar.
#    Run once all tabs are built, before the folder bar: ". $FormParts.Bars".
# ---------------------------------------------------------------------------
$FormParts.Bars = {
  $tabBarHeight = $FormLayout.TabBarHeight
  $folderBarHeight = $FormLayout.FolderBarHeight
  foreach ($control in @($form.Controls)) {
    if ($control -ne $captionBar) {
      $control.Top += $tabBarHeight + $folderBarHeight
    }
  }
}

# ---------------------------------------------------------------------------
# 5. FOLDER BAR: label, folder box and its buttons (copy / change / open / reset).
#    Run with ". $FormParts.FolderBar" after $sectionFolderInfo is loaded.
# ---------------------------------------------------------------------------
$FormParts.FolderBar = {
  $runLocalRepoLabel = New-Label 'Repo' 37 (48 + $tabBarHeight) 48 22
  $runLocalRepoLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
  $runLocalRepoLabel.ForeColor = Get-FormColor $FormLayout.AccentColor
  $runLocalPrefixBox = New-Object System.Windows.Forms.TextBox
  $runLocalPrefixBox.Location = New-Object System.Drawing.Point(90, (45 + $tabBarHeight))
  $runLocalPrefixBox.Size = New-Object System.Drawing.Size(300, 26)
  $runLocalPrefixBox.BackColor = [System.Drawing.Color]::White
  $runLocalPrefixBox.ReadOnly = $true
  $runLocalPrefixBox.Visible = $false
  $toolTip.SetToolTip($runLocalPrefixBox, 'Choose a repository with the search button; manual editing is disabled.')
  $runLocalRepoFile = Join-Path $repositorySettingsDirectory 'runlocal-repo-url.txt'
  $script:runLocalLastUploadTimeFile = Join-Path $repositorySettingsDirectory 'runlocal-repo-last-upload-time.txt'
  $script:runLocalLastUploadTimeLoaded = $false
  $script:runLocalLastUploadTime = $null
  try {
    if (Test-Path -LiteralPath $runLocalRepoFile -PathType Leaf) {
      $runLocalPrefixBox.Text = [IO.File]::ReadAllText($runLocalRepoFile).Trim()
    }
  } catch {
    Set-ColoredStatus $runLocalUploadStatusLabel ('Could not restore the Local Repo URL: ' + $_.Exception.Message) 'error'
  }
  $runLocalPrefixBox.Add_TextChanged({
    try {
      if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force -ErrorAction Stop | Out-Null
      }
      [IO.File]::WriteAllText($runLocalRepoFile, $runLocalPrefixBox.Text.Trim(), (New-Object System.Text.UTF8Encoding($false)))
      if ($script:currentSection -eq 'runlocal' -and -not (Test-GitHubBusy)) {
        Set-RunLocalUploadInfo
      }
    } catch {
      Set-ColoredStatus $runLocalUploadStatusLabel ('Could not save the Local Repo URL: ' + $_.Exception.Message) 'error'
    }
  })
  $form.Controls.Add($runLocalPrefixBox)
  $runLocalRepoSearchButton = New-ActionButton "Choose a repository from the signed-in GitHub account" 0xE721 395 (43 + $tabBarHeight)
  $runLocalRepoSearchButton.Visible = $false
  $runLocalRepoSearchButton.Add_Click({
    Show-RepoPicker -Box $runLocalPrefixBox -Button $runLocalRepoSearchButton -Status { param($Text, $Kind) Set-ColoredStatus $runLocalUploadStatusLabel $Text $Kind }
  })
  $runLocalLeftArrowButton = New-ActionButton 'Upload checked Local items to GitHub' 0xE898 435 (43 + $tabBarHeight)
  $runLocalLeftArrowButton.Visible = $false
  $runLocalLeftArrowButton.Add_Click({
    if ((Test-GitHubBusy) -and $script:uploadStatusTarget -eq 'runlocal') {
      Stop-RunLocalUpload
      return
    }
    if ($script:uploadProcess -and $script:uploadStatusTarget -eq 'runlocal') {
      Set-ColoredStatus $runLocalUploadStatusLabel 'The upload is finishing. Wait for its status to update.' 'busy'
      return
    }
    Invoke-RunLocalRepoUpload
  })
  $script:runLocalFilesExpanded = $false
  $runLocalFilesList = New-Object System.Windows.Forms.DataGridView
  $runLocalFilesList.Size = New-Object System.Drawing.Size(430, 180)
  $runLocalFilesList.AllowUserToAddRows = $false
  $runLocalFilesList.AllowUserToDeleteRows = $false
  $runLocalFilesList.AllowUserToResizeRows = $false
  $runLocalFilesList.ReadOnly = $false
  $runLocalFilesList.RowHeadersVisible = $false
  $runLocalFilesList.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
  $runLocalFilesList.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
  $runLocalFilesList.MultiSelect = $false
  $runLocalFilesList.BackgroundColor = [System.Drawing.Color]::White
  $runLocalFilesList.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
  [void]$runLocalFilesList.Columns.Add('Name', 'Name')
  $runLocalFilesList.Columns['Name'].FillWeight = 100
  $runLocalFilesList.Columns['Name'].ReadOnly = $true
  $runLocalUploadColumn = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
  $runLocalUploadColumn.Name = 'Upload'
  $runLocalUploadColumn.HeaderText = 'Upload'
  $runLocalUploadColumn.FillWeight = 24
  $runLocalFilesList.Columns.Add($runLocalUploadColumn) | Out-Null
  $runLocalFilesList.Columns['Upload'].DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
  $runLocalFilesList.Columns['Upload'].HeaderCell.Style.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
  $script:runLocalFilesLoading = $false
  $script:runLocalUploadSelectionFile = Join-Path $repositorySettingsDirectory 'runlocal-upload-selection.json'
  $runLocalFilesList.Add_CurrentCellDirtyStateChanged({
    if ($runLocalFilesList.IsCurrentCellDirty) {
      $runLocalFilesList.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
    }
  })
  $runLocalFilesList.Add_CellValueChanged({
    param($sender, $eventArgs)
    if ($script:runLocalFilesLoading -or $eventArgs.RowIndex -lt 0 -or $eventArgs.ColumnIndex -ne $sender.Columns['Upload'].Index) {
      return
    }
    try {
      Save-RunLocalUploadSelection
      if ($script:currentSection -eq 'runlocal' -and -not (Test-GitHubBusy)) {
        Set-RunLocalUploadInfo
      }
    } catch {
      Set-ColoredStatus $runLocalUploadStatusLabel ('Could not remember the Upload checkboxes: ' + $_.Exception.Message) 'error'
    }
  })
  $form.Add_FormClosing({
    param($sender, $eventArgs)
    try {
      if ($runLocalFilesList.IsCurrentCellDirty) {
        $runLocalFilesList.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
      }
      $runLocalFilesList.EndEdit()
      Save-RunLocalUploadSelection
    } catch {
      $eventArgs.Cancel = $true
      Set-ColoredStatus $runLocalUploadStatusLabel ('Could not save Local Upload selections; the form will stay open: ' + $_.Exception.Message) 'error'
    }
  })
  $runLocalFilesList.Visible = $false
  $form.Controls.Add($runLocalFilesList)
  $runLocalFilesEyeButton = New-ActionButton 'Show or hide Local folder files' 0xE890 914 (43 + $tabBarHeight)
  $runLocalFilesEyeButton.Visible = $false
  $runLocalFilesEyeButton.Add_Click({
    Set-RunLocalFilesExpanded (-not $script:runLocalFilesExpanded)
  })
  $folderBarLabel = New-Label 'Source folder' 37 (48 + $tabBarHeight) 140 22
  $folderBarLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
  $folderBarLabel.ForeColor = Get-FormColor $FormLayout.AccentColor
  $folderBarBox = New-Object System.Windows.Forms.TextBox
  $folderBarBox.Location = New-Object System.Drawing.Point(180, (45 + $tabBarHeight))
  $folderBarBox.Size = New-Object System.Drawing.Size(($FormLayout.Width - 370), 26)
  $folderBarBox.ReadOnly = $true
  $folderBarBox.BackColor = [System.Drawing.Color]::White
  $form.Controls.Add($folderBarBox)
  $folderChangeButton = New-ActionButton 'Change folder' 0xE721 ($FormLayout.Width - 142) (43 + $tabBarHeight)
  $folderOpenButton = New-ActionButton 'Open folder in File Explorer' 0xE72B ($FormLayout.Width - 104) (43 + $tabBarHeight)
  $folderCopyButton = New-ActionButton 'Copy this folder path' 0xE8C8 ($FormLayout.Width - 180) (43 + $tabBarHeight)
  $folderCopyButton.Add_Click({
    $text = $folderBarBox.Text.Trim()
    if (-not $text) {
      Show-SectionMessage 'There is no folder path to copy.' $true
      return
    }
    try {
      [System.Windows.Forms.Clipboard]::SetText($text)
      Show-SectionMessage "Folder path copied: $text"
    } catch {
      Show-SectionMessage ('Could not copy: ' + $_.Exception.Message) $true
    }
  })
}

# True when the open tab hides the folder bar (Folders setting Hidden = $true).
function Test-FolderBarHidden {
  $key = $script:currentSection
  return [bool]($sectionFolderInfo -and $sectionFolderInfo.Contains($key) -and $sectionFolderInfo[$key].Hidden)
}

function Update-FolderBar {
  $key = $script:currentSection
  $info = $sectionFolderInfo[$key]
  # Home: the GitHub repo row is on top, so the folder bar sits one row lower.
  $rowShift = if ($key -eq 'home') { $FormLayout.FolderBarHeight } else { 0 }
  if ($null -eq $script:folderBarBaseTop) {
    $script:folderBarBaseTop = @{}
    foreach ($control in @($runLocalRepoLabel, $runLocalPrefixBox, $runLocalRepoSearchButton, $runLocalLeftArrowButton, $runLocalFilesList, $runLocalFilesEyeButton, $folderBarLabel, $folderBarBox, $folderCopyButton, $folderChangeButton, $folderOpenButton)) {
      $script:folderBarBaseTop[$control] = $control.Top
    }
  }
  foreach ($control in @($script:folderBarBaseTop.Keys)) {
    $control.Top = $script:folderBarBaseTop[$control] + $rowShift
  }
  # Home: short label, so the folder box starts further left (wider box).
  if ($null -eq $script:folderBarBaseBox) {
    $script:folderBarBaseBox = @{ LabelWidth = $folderBarLabel.Width; Left = $folderBarBox.Left; Width = $folderBarBox.Width; CopyLeft = $folderCopyButton.Left; ChangeLeft = $folderChangeButton.Left; ChangeText = $folderChangeButton.Text; OpenLeft = $folderOpenButton.Left; EyeLeft = $runLocalFilesEyeButton.Left }
  }
  if ($key -eq 'home') {
    $folderBarLabel.Left = 37
    $folderBarLabel.Width = $FormLayout.HomeFieldLeft - 40
    $folderBarBox.Left = $FormLayout.HomeFieldLeft
    # Home's folder row: [box] choose folder (search icon), open, upload, copy, delete.
    $folderChangeButton.Left = $FormLayout.Width - 218
    $folderChangeButton.Text = [string][char]0xE721
    $folderOpenButton.Left = $FormLayout.Width - 180
    $folderCopyButton.Left = $FormLayout.Width - 104
    $folderBarBox.Width = $FormLayout.Width - 228 - $FormLayout.HomeFieldLeft
  } elseif ($key -eq 'runlocal') {
    $folderBarLabel.Left = 478
    $folderBarLabel.Width = 39
    $folderBarBox.Left = 517
    $folderBarBox.Width = $FormLayout.Width - 707
    $runLocalRepoSearchButton.Left = 395
    $runLocalLeftArrowButton.Left = 435
    $runLocalFilesEyeButton.Left = $script:folderBarBaseBox.OpenLeft
    $folderCopyButton.Left = $script:folderBarBaseBox.ChangeLeft
    $folderChangeButton.Left = $script:folderBarBaseBox.CopyLeft
    $folderOpenButton.Left = $script:folderBarBaseBox.EyeLeft
    $folderChangeButton.Text = $script:folderBarBaseBox.ChangeText
  } else {
    $folderBarLabel.Left = 37
    $folderBarLabel.Width = $script:folderBarBaseBox.LabelWidth
    $folderBarBox.Left = $script:folderBarBaseBox.Left
    $folderBarBox.Width = $script:folderBarBaseBox.Width
    $folderCopyButton.Left = $script:folderBarBaseBox.CopyLeft
    $folderChangeButton.Left = $script:folderBarBaseBox.ChangeLeft
    $folderOpenButton.Left = $script:folderBarBaseBox.OpenLeft
    $folderChangeButton.Text = if ($key -eq 'runlocal') { [string][char]0xE721 } else { $script:folderBarBaseBox.ChangeText }
  }
  # Tabs without a folder hide the whole folder bar.
  $hasFolder = $sectionFolderInfo.Contains($key) -and -not (Test-FolderBarHidden)
  $runLocalRepoLabel.Visible = $hasFolder -and $key -eq 'runlocal'
  $runLocalPrefixBox.Visible = $hasFolder -and $key -eq 'runlocal'
  $runLocalRepoSearchButton.Visible = $hasFolder -and $key -eq 'runlocal'
  $runLocalLeftArrowButton.Visible = $hasFolder -and $key -eq 'runlocal'
  $runLocalFilesEyeButton.Visible = $hasFolder -and $key -eq 'runlocal'
  $runLocalFilesList.Visible = $hasFolder -and $key -eq 'runlocal' -and $script:runLocalFilesExpanded
  if ($runLocalFilesList.Visible) {
    $runLocalFilesList.Location = New-Object System.Drawing.Point($folderBarBox.Left, ($folderBarBox.Bottom + 3))
    $runLocalFilesList.Width = [Math]::Min(430, ($form.ClientSize.Width - $runLocalFilesList.Left - 25))
    $runLocalFilesList.BringToFront()
  }
  foreach ($control in @($folderBarLabel, $folderBarBox, $folderCopyButton, $folderChangeButton, $folderOpenButton)) {
    if (-not $hasFolder) {
      $control.Visible = $false
    } else {
      $control.Visible = $true
    }
  }
  if (-not $hasFolder) {
    return
  }
  if ($key -eq 'home') {
    Update-HomeRepo
    Update-HomeFiles
  }
  $folderBarLabel.Text = $info.Label
  $folderBarBox.Text = $script:sectionFolders[$key]
  $folderBarBox.SelectionStart = $folderBarBox.Text.Length
  $toolTip.SetToolTip($folderBarLabel, $info.Hint)
  $toolTip.SetToolTip($folderBarBox, $info.Hint + ': ' + $script:sectionFolders[$key])
}

function Update-RunLocalFilesList {
  $script:runLocalFilesLoading = $true
  $script:runLocalFilesLoadedFor = ''
  try {
    $runLocalFilesList.Rows.Clear()
    $folder = $folderBarBox.Text.Trim()
    if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
      [void]$runLocalFilesList.Rows.Add('Choose a valid Local folder.', $false)
      if ($folder) {
        Set-ColoredStatus $runLocalUploadStatusLabel "Local folder not found: $folder" 'error'
      }
      return
    }
    $normalizedFolder = [IO.Path]::GetFullPath($folder)
    $script:runLocalFilesLoadedFor = $normalizedFolder
    $savedSelection = Get-RunLocalUploadSelection $normalizedFolder
    $entries = @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction Stop |
      Sort-Object @{ Expression = { if ($_.PSIsContainer) { 0 } else { 1 } } }, Name)
    if ($entries.Count -eq 0) {
      [void]$runLocalFilesList.Rows.Add('(Folder is empty)', $false)
      return
    }
    foreach ($entry in $entries) {
      $displayName = if ($entry.PSIsContainer) { '[Folder] ' + $entry.Name } else { $entry.Name }
      $isChecked = if ($savedSelection.ContainsKey($entry.Name)) { [bool]$savedSelection[$entry.Name] } else { $true }
      if ($entry.Name -ieq '.git') { $isChecked = $false }
      $rowIndex = $runLocalFilesList.Rows.Add($displayName, $isChecked)
      if ($entry.Name -ieq '.git') {
        $runLocalFilesList.Rows[$rowIndex].Cells['Upload'].ReadOnly = $true
        $runLocalFilesList.Rows[$rowIndex].Cells['Upload'].ToolTipText = 'Git metadata is not uploaded.'
      }
    }
  } catch {
    $runLocalFilesList.Rows.Clear()
    [void]$runLocalFilesList.Rows.Add('Could not read this folder.', $false)
    Set-ColoredStatus $runLocalUploadStatusLabel ('Could not list Local files: ' + $_.Exception.Message) 'error'
  } finally {
    $script:runLocalFilesLoading = $false
  }
}

function Get-RunLocalUploadSelection {
  param([string]$Folder)
  $selection = @{}
  if (-not (Test-Path -LiteralPath $script:runLocalUploadSelectionFile -PathType Leaf)) {
    return $selection
  }
  $state = [IO.File]::ReadAllText($script:runLocalUploadSelectionFile) | ConvertFrom-Json -ErrorAction Stop
  foreach ($savedFolder in @($state.Folders)) {
    if ([string]$savedFolder.Path -ine $Folder) { continue }
    foreach ($item in @($savedFolder.Items)) {
      $selection[[string]$item.Name] = [bool]$item.Checked
    }
    break
  }
  return $selection
}

function Save-RunLocalUploadSelection {
  $folder = [IO.Path]::GetFullPath([string]$script:sectionFolders['runlocal'])
  if (-not $script:runLocalFilesLoadedFor -or $script:runLocalFilesLoadedFor -ine $folder) {
    return
  }
  $state = [ordered]@{ Folders = @() }
  if (Test-Path -LiteralPath $script:runLocalUploadSelectionFile -PathType Leaf) {
    $savedState = [IO.File]::ReadAllText($script:runLocalUploadSelectionFile) | ConvertFrom-Json -ErrorAction Stop
    foreach ($savedFolder in @($savedState.Folders)) {
      if ([string]$savedFolder.Path -ine $folder) {
        $state.Folders += [pscustomobject]@{
          Path = [string]$savedFolder.Path
          Items = @($savedFolder.Items | ForEach-Object {
            [pscustomobject]@{ Name = [string]$_.Name; Checked = [bool]$_.Checked }
          })
        }
      }
    }
  }
  $items = @(
    foreach ($row in $runLocalFilesList.Rows) {
      $name = [string]$row.Cells['Name'].Value
      if (-not $name -or $name.StartsWith('(') -or $name.StartsWith('Choose a valid') -or $name.StartsWith('Could not read')) {
        continue
      }
      [pscustomobject]@{
        Name = $name -replace '^\[Folder\] ', ''
        Checked = [bool]$row.Cells['Upload'].Value
      }
    }
  )
  $state.Folders += [pscustomobject]@{ Path = $folder; Items = $items }
  if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force -ErrorAction Stop | Out-Null
  }
  [IO.File]::WriteAllText(
    $script:runLocalUploadSelectionFile,
    ($state | ConvertTo-Json -Depth 6),
    (New-Object System.Text.UTF8Encoding($false))
  )
}

function Set-RunLocalFilesExpanded {
  param([bool]$Expanded)
  $script:runLocalFilesExpanded = $Expanded
  if ($Expanded) {
    Update-RunLocalFilesList
  }
  Update-FolderBar
}

function Get-RunLocalLastUploadTimeText {
  if (-not $script:runLocalLastUploadTimeLoaded) {
    $script:runLocalLastUploadTime = $null
    $script:runLocalLastUploadTimeError = ''
    try {
      if (Test-Path -LiteralPath $script:runLocalLastUploadTimeFile -PathType Leaf) {
        $saved = [IO.File]::ReadAllText($script:runLocalLastUploadTimeFile).Trim()
        $parsed = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse(
          $saved,
          [Globalization.CultureInfo]::InvariantCulture,
          [Globalization.DateTimeStyles]::None,
          [ref]$parsed
        )) {
          throw "Saved last-upload time is invalid: $script:runLocalLastUploadTimeFile"
        }
        $script:runLocalLastUploadTime = $parsed
      }
    } catch {
      $script:runLocalLastUploadTimeError = $_.Exception.Message
    }
    $script:runLocalLastUploadTimeLoaded = $true
  }
  if ($null -eq $script:runLocalLastUploadTime) {
    if ($script:runLocalLastUploadTimeError) {
      return 'Unavailable'
    }
    return 'Never'
  }
  return $script:runLocalLastUploadTime.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
}

function Save-RunLocalLastUploadTime {
  $now = [DateTimeOffset]::Now
  if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force -ErrorAction Stop | Out-Null
  }
  [IO.File]::WriteAllText(
    $script:runLocalLastUploadTimeFile,
    $now.ToString('o', [Globalization.CultureInfo]::InvariantCulture),
    (New-Object System.Text.UTF8Encoding($false))
  )
  $script:runLocalLastUploadTime = $now
  $script:runLocalLastUploadTimeError = ''
  $script:runLocalLastUploadTimeLoaded = $true
}

function Set-RunLocalUploadInfo {
  $folder = [IO.Path]::GetFullPath([string]$script:sectionFolders['runlocal'])
  [void](Get-RunLocalLastUploadTimeText)
  if ($script:runLocalFilesLoadedFor -ine $folder) {
    Set-ColoredStatus $runLocalUploadStatusLabel 'Choose a GitHub Repo, review Local Upload ticks, then click the Upload button.' 'info'
    return
  }
  $checkedCount = @(
    foreach ($row in $runLocalFilesList.Rows) {
      if ([bool]$row.Cells['Upload'].Value) {
        $name = ([string]$row.Cells['Name'].Value) -replace '^\[Folder\] ', ''
        if ($name -and $name -notin @('.git', '.', '..') -and -not $name.StartsWith('(') -and -not $name.StartsWith('Could not')) {
          $name
        }
      }
    }
  ).Count
  $repo = $runLocalPrefixBox.Text.Trim()
  $repoInfo = if ($repo) { Get-DisplayRepositoryUrl $repo } else { 'No Repo selected' }
  $text = "Repo: $repoInfo   |   $checkedCount item(s) checked; Upload sends only these items."
  if ($script:runLocalLastUploadTimeError) {
    $text += "   |   Could not read the saved upload time: $script:runLocalLastUploadTimeError"
  }
  Set-ColoredStatus $runLocalUploadStatusLabel $text 'info'
}

# ---------------------------------------------------------------------------
# 6. TAB BAR: one button per entry in $FormLayout.Tabs. Each button is stored in
#    the variable named by its Var (e.g. $adbToggleButton). Run with ". $FormParts.Tabs".
# ---------------------------------------------------------------------------
$tabLogoDirectory = Join-Path $env:LOCALAPPDATA 'IJTC\tab-logos'

# Draws a tab: logo / icon / label+symbol / label, centred.
$tabPainter = {
  param($sender, $eventArgs)
  $tab = $sender.Tag
  $graphics = $eventArgs.Graphics
  $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $color = if ($tab.Color) { Get-FormColor $tab.Color } else { $sender.ForeColor }
  $brush = New-Object System.Drawing.SolidBrush ($color)
  $glyphSize = if ($tab.GlyphSize) { $tab.GlyphSize } elseif ($tab.Style -eq 'textSymbol') { 11 } else { 14 }
  $symbolFont = New-Object System.Drawing.Font('Segoe MDL2 Assets', $glyphSize)
  try {
    $format = [System.Drawing.StringFormat]::GenericTypographic
    $glyph = if ($tab.Glyph) { [string][char]$tab.Glyph } else { '' }
    switch ($tab.Style) {
      'logo' {
        if ($tab.Image) {
          $logoSize = 20
          $graphics.DrawImage($tab.Image, [single](($sender.Width - $logoSize) / 2), [single](($sender.Height - $logoSize) / 2), [single]$logoSize, [single]$logoSize)
        } else {
          $size = $graphics.MeasureString($glyph, $symbolFont, 1000, $format)
          $graphics.DrawString($glyph, $symbolFont, $brush, ($sender.Width - $size.Width) / 2, ($sender.Height - $size.Height) / 2, $format)
        }
      }
      'icon' {
        $size = $graphics.MeasureString($glyph, $symbolFont, 1000, $format)
        $graphics.DrawString($glyph, $symbolFont, $brush, ($sender.Width - $size.Width) / 2, ($sender.Height - $size.Height) / 2 + 1, $format)
      }
      'textSymbol' {
        $labelSize = $graphics.MeasureString($tab.Label, $sender.Font, 1000, $format)
        $symbolSize = $graphics.MeasureString($glyph, $symbolFont, 1000, $format)
        $gap = 6
        $x = ($sender.Width - ($labelSize.Width + $gap + $symbolSize.Width)) / 2
        $graphics.DrawString($tab.Label, $sender.Font, $brush, $x, ($sender.Height - $labelSize.Height) / 2, $format)
        $graphics.DrawString($glyph, $symbolFont, $brush, $x + $labelSize.Width + $gap, ($sender.Height - $symbolSize.Height) / 2 + 1, $format)
      }
      default {
        $labelSize = $graphics.MeasureString($tab.Label, $sender.Font, 1000, $format)
        $graphics.DrawString($tab.Label, $sender.Font, $brush, ($sender.Width - $labelSize.Width) / 2, ($sender.Height - $labelSize.Height) / 2, $format)
      }
    }
  } finally {
    $brush.Dispose()
    $symbolFont.Dispose()
  }
}

function Read-TabLogo {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -eq 0) {
    return $null
  }
  try {
    $icon = New-Object System.Drawing.Icon($Path, 32, 32)
    try { return $icon.ToBitmap() } finally { $icon.Dispose() }
  } catch {
  }
  try {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $stream = New-Object IO.MemoryStream(, $bytes)
    $image = [System.Drawing.Image]::FromStream($stream)
    try {
      return New-Object System.Drawing.Bitmap($image)
    } finally {
      $image.Dispose()
      $stream.Dispose()
    }
  } catch {
    return $null
  }
}

function Get-DiagramRelativePagePath {
  param([string]$Root, [string]$File)
  $rootPath = [IO.Path]::GetFullPath($Root)
  $filePath = [IO.Path]::GetFullPath($File)
  $rootUri = New-Object System.Uri(($rootPath.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar))
  $fileUri = New-Object System.Uri($filePath)
  if (-not $rootUri.IsBaseOf($fileUri)) {
    throw 'The selected file is outside the Project folder.'
  }
  $relative = [Uri]::UnescapeDataString($rootUri.MakeRelativeUri($fileUri).ToString())
  return '/' + $relative.Replace('\', '/')
}

function Get-DiagramPageFilePath {
  param([string]$Page)
  $root = [IO.Path]::GetFullPath($diagramProjectBox.Text.Trim()).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $relative = $Page.Trim().TrimStart('/', '\').Replace('/', [IO.Path]::DirectorySeparatorChar)
  if ([string]::IsNullOrWhiteSpace($relative) -or $relative -match '^[A-Za-z]:|^[\\/]{2}') {
    throw 'Select a file inside the Project folder.'
  }
  $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
  $rootPrefix = $root + [IO.Path]::DirectorySeparatorChar
  if (-not $path.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The selected file is outside the Project folder.'
  }
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "File not found: $path"
  }
  if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Editing a linked file is not allowed.'
  }
  return $path
}

function Test-DiagramCsvFile {
  param([string]$Path)
  $extension = [IO.Path]::GetExtension($Path)
  $dataDirectory = [IO.Path]::GetFullPath((Join-Path $diagramProjectBox.Text.Trim() 'data')).TrimEnd([IO.Path]::DirectorySeparatorChar)
  $parentDirectory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)).TrimEnd([IO.Path]::DirectorySeparatorChar)
  return $extension -ieq '.csv' -or
    $extension -ieq '.tsv' -or
    $extension -ieq '.txt' -or
    ([string]::IsNullOrEmpty($extension) -and $parentDirectory -ieq $dataDirectory)
}

function Test-DiagramXlsxPackage {
  param([string]$Path)
  $stream = [IO.File]::OpenRead($Path)
  try {
    if ($stream.Length -lt 4) { return $false }
    return $stream.ReadByte() -eq 0x50 -and $stream.ReadByte() -eq 0x4B
  } finally {
    $stream.Dispose()
  }
}

function Initialize-DiagramCompression {
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
}

function Get-DiagramWorkbookSheetPath {
  param([System.IO.Compression.ZipArchive]$Archive)
  $workbookEntry = $Archive.GetEntry('xl/workbook.xml')
  $relationshipsEntry = $Archive.GetEntry('xl/_rels/workbook.xml.rels')
  if (-not $workbookEntry -or -not $relationshipsEntry) {
    throw 'This is not a valid Excel workbook.'
  }
  $workbook = New-Object System.Xml.XmlDocument
  $workbook.XmlResolver = $null
  $workbookStream = $workbookEntry.Open()
  try { $workbook.Load($workbookStream) } finally { $workbookStream.Dispose() }
  $workbookNs = New-Object System.Xml.XmlNamespaceManager($workbook.NameTable)
  $workbookNs.AddNamespace('x', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
  $workbookNs.AddNamespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
  $sheet = $workbook.SelectSingleNode('/x:workbook/x:sheets/x:sheet[1]', $workbookNs)
  if (-not $sheet) {
    throw 'The Excel workbook does not contain a worksheet.'
  }
  $relationshipId = $sheet.GetAttribute('id', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
  $relationships = New-Object System.Xml.XmlDocument
  $relationships.XmlResolver = $null
  $relationshipsStream = $relationshipsEntry.Open()
  try { $relationships.Load($relationshipsStream) } finally { $relationshipsStream.Dispose() }
  $relationshipsNs = New-Object System.Xml.XmlNamespaceManager($relationships.NameTable)
  $relationshipsNs.AddNamespace('r', 'http://schemas.openxmlformats.org/package/2006/relationships')
  $relationship = $relationships.SelectSingleNode("/r:Relationships/r:Relationship[@Id='$relationshipId']", $relationshipsNs)
  if (-not $relationship -or $relationship.GetAttribute('TargetMode') -eq 'External') {
    throw 'The first worksheet reference in the Excel workbook is invalid.'
  }
  $baseUri = New-Object System.Uri('http://package.local/xl/workbook.xml')
  $sheetUri = New-Object System.Uri($baseUri, $relationship.GetAttribute('Target'))
  $sheetPath = [Uri]::UnescapeDataString($sheetUri.AbsolutePath.TrimStart('/'))
  if (-not $sheetPath.StartsWith('xl/worksheets/', [StringComparison]::OrdinalIgnoreCase) -or
      $sheetPath.Contains('../')) {
    throw 'The first worksheet path in the Excel workbook is invalid.'
  }
  if (-not $Archive.GetEntry($sheetPath)) {
    throw 'The first worksheet data is missing from the Excel workbook.'
  }
  return $sheetPath
}

function Get-DiagramExcelColumnIndex {
  param([string]$Letters)
  $index = 0
  foreach ($character in $Letters.ToUpperInvariant().ToCharArray()) {
    $index = ($index * 26) + ([int]$character - [int][char]'A' + 1)
  }
  return $index - 1
}

function Read-DiagramXlsxWorkbook {
  param([string]$Path)
  Initialize-DiagramCompression
  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $sheetPath = Get-DiagramWorkbookSheetPath $archive
    $sheetEntry = $archive.GetEntry($sheetPath)
    $worksheet = New-Object System.Xml.XmlDocument
    $worksheet.XmlResolver = $null
    $worksheetStream = $sheetEntry.Open()
    try { $worksheet.Load($worksheetStream) } finally { $worksheetStream.Dispose() }
    $spreadsheetNsUri = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
    $worksheetNs = New-Object System.Xml.XmlNamespaceManager($worksheet.NameTable)
    $worksheetNs.AddNamespace('x', $spreadsheetNsUri)

    $sharedStrings = New-Object 'System.Collections.Generic.List[string]'
    $sharedStringsEntry = $archive.GetEntry('xl/sharedStrings.xml')
    if ($sharedStringsEntry) {
      $sharedStringsXml = New-Object System.Xml.XmlDocument
      $sharedStringsXml.XmlResolver = $null
      $sharedStringsStream = $sharedStringsEntry.Open()
      try { $sharedStringsXml.Load($sharedStringsStream) } finally { $sharedStringsStream.Dispose() }
      $sharedStringsNs = New-Object System.Xml.XmlNamespaceManager($sharedStringsXml.NameTable)
      $sharedStringsNs.AddNamespace('x', $spreadsheetNsUri)
      foreach ($stringItem in $sharedStringsXml.SelectNodes('/x:sst/x:si', $sharedStringsNs)) {
        $text = New-Object System.Text.StringBuilder
        foreach ($textNode in $stringItem.SelectNodes('.//x:t', $sharedStringsNs)) {
          [void]$text.Append($textNode.InnerText)
        }
        $sharedStrings.Add($text.ToString())
      }
    }

    $rowData = New-Object 'System.Collections.Generic.SortedDictionary[int,object]'
    $maxColumn = 0
    foreach ($cell in $worksheet.SelectNodes('/x:worksheet/x:sheetData/x:row/x:c', $worksheetNs)) {
      if ($cell.GetAttribute('r') -notmatch '^([A-Z]+)(\d+)$') {
        continue
      }
      $columnIndex = Get-DiagramExcelColumnIndex $Matches[1]
      $rowIndex = [int]$Matches[2] - 1
      if ($columnIndex -lt 0 -or $columnIndex -ge 16384 -or $rowIndex -lt 0) {
        continue
      }
      if (-not $rowData.ContainsKey($rowIndex)) {
        $rowData[$rowIndex] = @{}
      }
      $valueNode = $cell.SelectSingleNode('x:v', $worksheetNs)
      $value = if ($valueNode) { $valueNode.InnerText } else { '' }
      switch ($cell.GetAttribute('t')) {
        's' {
          $sharedIndex = 0
          if ([int]::TryParse($value, [ref]$sharedIndex) -and
              $sharedIndex -ge 0 -and $sharedIndex -lt $sharedStrings.Count) {
            $value = $sharedStrings[$sharedIndex]
          }
        }
        'inlineStr' {
          $inlineText = New-Object System.Text.StringBuilder
          foreach ($textNode in $cell.SelectNodes('.//x:is//x:t', $worksheetNs)) {
            [void]$inlineText.Append($textNode.InnerText)
          }
          $value = $inlineText.ToString()
        }
        'b' {
          if ($value -eq '1') { $value = 'TRUE' } elseif ($value -eq '0') { $value = 'FALSE' }
        }
      }
      $rowData[$rowIndex][$columnIndex] = [string]$value
      $maxColumn = [Math]::Max($maxColumn, $columnIndex + 1)
    }
    $maxRow = if ($rowData.Count -gt 0) { ($rowData.Keys | Measure-Object -Maximum).Maximum } else { -1 }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    for ($rowIndex = 0; $rowIndex -le $maxRow; $rowIndex++) {
      $values = New-Object 'System.Collections.Generic.List[string]'
      for ($columnIndex = 0; $columnIndex -lt $maxColumn; $columnIndex++) {
        $value = ''
        if ($rowData.ContainsKey($rowIndex) -and $rowData[$rowIndex].ContainsKey($columnIndex)) {
          $value = [string]$rowData[$rowIndex][$columnIndex]
        }
        $values.Add($value)
      }
      $rows.Add($values.ToArray())
    }
    return [pscustomobject]@{
      Rows = [object[]]$rows.ToArray()
      ColumnCount = $maxColumn
      SheetPath = $sheetPath
    }
  } finally {
    $archive.Dispose()
  }
}

function ConvertFrom-DiagramCsv {
  param(
    [string]$Text,
    [char]$Delimiter = ','
  )
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $row = New-Object 'System.Collections.Generic.List[string]'
  $cell = New-Object System.Text.StringBuilder
  $quoted = $false
  for ($index = 0; $index -lt $Text.Length; $index++) {
    $character = $Text[$index]
    if ($quoted) {
      if ($character -eq '"' -and $index + 1 -lt $Text.Length -and $Text[$index + 1] -eq '"') {
        [void]$cell.Append('"')
        $index++
      } elseif ($character -eq '"') {
        $quoted = $false
      } else {
        [void]$cell.Append($character)
      }
    } elseif ($character -eq '"' -and $cell.Length -eq 0) {
      $quoted = $true
    } elseif ($character -eq $Delimiter) {
      $row.Add($cell.ToString())
      [void]$cell.Clear()
    } elseif ($character -eq "`r" -or $character -eq "`n") {
      if ($character -eq "`r" -and $index + 1 -lt $Text.Length -and $Text[$index + 1] -eq "`n") {
        $index++
      }
      $row.Add($cell.ToString())
      if ($row.Count -gt 1 -or $row[0].Length -gt 0) {
        $rows.Add($row.ToArray())
      }
      $row.Clear()
      [void]$cell.Clear()
    } else {
      [void]$cell.Append($character)
    }
  }
  if ($quoted) {
    throw 'The CSV file has an unclosed quoted cell.'
  }
  if ($cell.Length -gt 0 -or $row.Count -gt 0) {
    $row.Add($cell.ToString())
    if ($row.Count -gt 1 -or $row[0].Length -gt 0) {
      $rows.Add($row.ToArray())
    }
  }
  return [pscustomobject]@{
    Rows = [object[]]$rows.ToArray()
    ColumnCount = [int](($rows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum)
  }
}

function Get-DiagramDelimitedFormat {
  param(
    [string]$Path,
    [string]$Text
  )
  $extension = [IO.Path]::GetExtension($Path)
  if ($extension -ieq '.tsv') { return [pscustomobject]@{ Delimiter = [char]"`t"; Name = 'tab' } }
  $firstLine = ($Text -split "`r`n|`n|`r" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
  if ($extension -ieq '.csv') { return [pscustomobject]@{ Delimiter = [char]','; Name = 'comma' } }
  if ($firstLine -match "`t" -and $firstLine -notmatch ',') {
    return [pscustomobject]@{ Delimiter = [char]"`t"; Name = 'tab' }
  }
  foreach ($candidate in @(';', '|')) {
    if ($firstLine.Contains([string]$candidate) -and -not $firstLine.Contains(',')) {
      return [pscustomobject]@{ Delimiter = [char]$candidate; Name = [string]$candidate }
    }
  }
  return [pscustomobject]@{ Delimiter = [char]','; Name = 'comma' }
}

function Get-DiagramColumnName {
  param([int]$Index)
  $name = ''
  $value = $Index + 1
  while ($value -gt 0) {
    $value--
    $name = [char](65 + ([int]$value % 26)) + $name
    $value = [int][Math]::Floor($value / 26)
  }
  return $name
}

function Get-DiagramGridRows {
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $lastUsedRow = -1
  for ($rowIndex = 0; $rowIndex -lt $diagramFileGrid.Rows.Count; $rowIndex++) {
    $gridRow = $diagramFileGrid.Rows[$rowIndex]
    if ($gridRow.IsNewRow) {
      continue
    }
    $values = New-Object 'System.Collections.Generic.List[string]'
    $lastUsedColumn = -1
    foreach ($cell in $gridRow.Cells) {
      $value = if ($null -eq $cell.Value) { '' } else { [string]$cell.Value }
      if ($value -ne '') { $lastUsedColumn = $values.Count }
      $values.Add($value)
    }
    if ($lastUsedColumn -ge 0) {
      $rows.Add([string[]]$values.ToArray())
      $lastUsedRow = $rows.Count - 1
    } else {
      $rows.Add([string[]]@())
    }
  }
  if ($lastUsedRow -lt 0) {
    return ,([object[]]@())
  }
  return ,([object[]]$rows.ToArray()[0..$lastUsedRow])
}

function Set-DiagramGridHeaderRow {
  for ($rowIndex = 0; $rowIndex -lt [Math]::Min(2, $diagramFileGrid.Rows.Count); $rowIndex++) {
    $gridRow = $diagramFileGrid.Rows[$rowIndex]
    if ($gridRow.IsNewRow) { continue }
    $gridRow.Frozen = $true
    $gridRow.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(255, 250, 205)
    $gridRow.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
    $gridRow.HeaderCell.Style.BackColor = [System.Drawing.Color]::FromArgb(255, 250, 205)
    $gridRow.HeaderCell.Style.ForeColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
    if ($rowIndex -eq 0) {
      $gridRow.DefaultCellStyle.Font = New-Object System.Drawing.Font('Nirmala UI', 9, [System.Drawing.FontStyle]::Regular)
    }
  }
}

function Get-DiagramGridSnapshot {
  $columns = New-Object 'System.Collections.Generic.List[string]'
  foreach ($column in $diagramFileGrid.Columns) {
    $columns.Add([string]$column.HeaderText)
  }
  $rows = New-Object 'System.Collections.Generic.List[object]'
  foreach ($gridRow in $diagramFileGrid.Rows) {
    if ($gridRow.IsNewRow) { continue }
    $values = New-Object 'System.Collections.Generic.List[string]'
    $hasValue = $false
    foreach ($cell in $gridRow.Cells) {
      $value = if ($null -eq $cell.Value) { '' } else { [string]$cell.Value }
      if ($value -ne '') { $hasValue = $true }
      $values.Add($value)
    }
    if ($hasValue) { $rows.Add([string[]]$values.ToArray()) }
  }
  return [pscustomobject]@{
    Columns = [string[]]$columns.ToArray()
    Rows = [object[]]$rows.ToArray()
  }
}

function Get-DiagramGridSnapshotKey {
  param($Snapshot)
  return ConvertTo-Json -InputObject $Snapshot -Depth 6 -Compress
}

function Update-DiagramGridHistoryButtons {
  if (-not $script:diagramUndoButton -or $script:diagramUndoButton.IsDisposed) { return }
  $gridIsVisible = $null -ne $diagramFileGrid -and $diagramFileGrid.Visible
  $script:diagramUndoButton.Enabled = $gridIsVisible -and $script:diagramGridHistoryIndex -gt 0
  $script:diagramRedoButton.Enabled = $gridIsVisible -and $script:diagramGridHistoryIndex -lt ($script:diagramGridHistory.Count - 1)
}

function Reset-DiagramGridHistory {
  $script:diagramGridHistory = New-Object 'System.Collections.Generic.List[object]'
  $snapshot = Get-DiagramGridSnapshot
  $script:diagramGridHistory.Add($snapshot)
  $script:diagramGridHistoryIndex = 0
  Update-DiagramGridHistoryButtons
}

function Record-DiagramGridHistory {
  if ($script:diagramEditorLoading -or -not $script:diagramFileGrid.Visible) { return }
  $snapshot = Get-DiagramGridSnapshot
  if ($script:diagramGridHistory.Count -eq 0) {
    $script:diagramGridHistory.Add($snapshot)
    $script:diagramGridHistoryIndex = 0
    Update-DiagramGridHistoryButtons
    return
  }
  $current = $script:diagramGridHistory[$script:diagramGridHistoryIndex]
  if ((Get-DiagramGridSnapshotKey $current) -ceq (Get-DiagramGridSnapshotKey $snapshot)) { return }
  if ($script:diagramGridHistoryIndex -lt ($script:diagramGridHistory.Count - 1)) {
    $script:diagramGridHistory.RemoveRange(
      ($script:diagramGridHistoryIndex + 1),
      ($script:diagramGridHistory.Count - $script:diagramGridHistoryIndex - 1)
    )
  }
  $script:diagramGridHistory.Add($snapshot)
  $script:diagramGridHistoryIndex = $script:diagramGridHistory.Count - 1
  if ($script:diagramGridHistory.Count -gt 101) {
    $script:diagramGridHistory.RemoveAt(0)
    $script:diagramGridHistoryIndex--
  }
  Update-DiagramGridHistoryButtons
}

function Restore-DiagramGridSnapshot {
  param($Snapshot)
  $script:diagramEditorLoading = $true
  try {
    $diagramFileGrid.Rows.Clear()
    $diagramFileGrid.Columns.Clear()
    foreach ($header in $Snapshot.Columns) {
      $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
      $column.Name = "column$($diagramFileGrid.Columns.Count)"
      $column.HeaderText = [string]$header
      $column.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
      $column.Width = 150
      [void]$diagramFileGrid.Columns.Add($column)
    }
    foreach ($values in $Snapshot.Rows) {
      $rowIndex = $diagramFileGrid.Rows.Add()
      for ($columnIndex = 0; $columnIndex -lt [Math]::Min($values.Count, $diagramFileGrid.Columns.Count); $columnIndex++) {
        $diagramFileGrid.Rows[$rowIndex].Cells[$columnIndex].Value = [string]$values[$columnIndex]
      }
    }
    Set-DiagramGridHeaderRow
  } finally {
    $script:diagramEditorLoading = $false
  }
  Update-DiagramEditorStatus
  Update-DiagramGridHistoryButtons
}

function Invoke-DiagramGridHistory {
  param([ValidateSet('Undo', 'Redo')][string]$Action)
  if ($Action -eq 'Undo') {
    if ($script:diagramGridHistoryIndex -le 0) { return }
    $script:diagramGridHistoryIndex--
  } else {
    if ($script:diagramGridHistoryIndex -ge ($script:diagramGridHistory.Count - 1)) { return }
    $script:diagramGridHistoryIndex++
  }
  Restore-DiagramGridSnapshot $script:diagramGridHistory[$script:diagramGridHistoryIndex]
}

function Find-DiagramGridText {
  $query = $script:diagramSearchBox.Text
  if ([string]::IsNullOrWhiteSpace($query)) { return }
  if ($diagramFileGrid.Visible -and $diagramFileGrid.Rows.Count -gt 0 -and $diagramFileGrid.Columns.Count -gt 0) {
    $cellCount = $diagramFileGrid.Rows.Count * $diagramFileGrid.Columns.Count
    $startAt = if ($diagramFileGrid.CurrentCell) {
      ($diagramFileGrid.CurrentCell.RowIndex * $diagramFileGrid.Columns.Count) + $diagramFileGrid.CurrentCell.ColumnIndex + 1
    } else {
      0
    }
    for ($offset = 0; $offset -lt $cellCount; $offset++) {
      $cellIndex = ($startAt + $offset) % $cellCount
      $rowIndex = [int][Math]::Floor($cellIndex / $diagramFileGrid.Columns.Count)
      $columnIndex = $cellIndex % $diagramFileGrid.Columns.Count
      if ($diagramFileGrid.Rows[$rowIndex].IsNewRow) { continue }
      $cellValue = [string]$diagramFileGrid.Rows[$rowIndex].Cells[$columnIndex].Value
      if ($cellValue.IndexOf($query, [StringComparison]::CurrentCultureIgnoreCase) -ge 0) {
        $diagramFileGrid.CurrentCell = $diagramFileGrid.Rows[$rowIndex].Cells[$columnIndex]
        $diagramFileGrid.Rows[$rowIndex].Cells[$columnIndex].Selected = $true
        $diagramFileGrid.Focus()
        return
      }
    }
  } elseif ($diagramFileEditor.Visible) {
    $startAt = [Math]::Min($diagramFileEditor.SelectionStart + $diagramFileEditor.SelectionLength, $diagramFileEditor.TextLength)
    $matchIndex = $diagramFileEditor.Find($query, $startAt, [System.Windows.Forms.RichTextBoxFinds]::None)
    if ($matchIndex -lt 0 -and $startAt -gt 0) {
      $matchIndex = $diagramFileEditor.Find($query, 0, [System.Windows.Forms.RichTextBoxFinds]::None)
    }
    if ($matchIndex -ge 0) { $diagramFileEditor.Focus() }
  }
}

function Add-DiagramGridColumn {
  param([int]$Index = -1)
  if ($diagramFileGrid.Columns.Count -ge 256) {
    [void][System.Windows.Forms.MessageBox]::Show($form, 'This grid cannot contain more than 256 columns.', 'Column limit', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    return
  }
  if ($Index -lt 0 -or $Index -ge $diagramFileGrid.Columns.Count) {
    $Index = $diagramFileGrid.Columns.Count
  } else {
    $Index++
  }
  $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
  $column.Name = 'diagramColumn' + [Guid]::NewGuid().ToString('N')
  $column.HeaderText = Get-DiagramColumnName $Index
  $column.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
  $column.Width = 150
  [void]$diagramFileGrid.Columns.Insert($Index, $column)
  for ($columnIndex = 0; $columnIndex -lt $diagramFileGrid.Columns.Count; $columnIndex++) {
    $diagramFileGrid.Columns[$columnIndex].Name = 'diagramColumn' + [Guid]::NewGuid().ToString('N')
  }
  for ($columnIndex = 0; $columnIndex -lt $diagramFileGrid.Columns.Count; $columnIndex++) {
    $diagramFileGrid.Columns[$columnIndex].Name = "column$columnIndex"
    $diagramFileGrid.Columns[$columnIndex].HeaderText = Get-DiagramColumnName $columnIndex
  }
  Update-DiagramEditorStatus
  Record-DiagramGridHistory
}

function Remove-DiagramGridColumn {
  param([int]$Index = -1)
  if ($diagramFileGrid.Columns.Count -le 1) {
    return
  }
  if ($Index -lt 0 -or $Index -ge $diagramFileGrid.Columns.Count) {
    if ($null -eq $diagramFileGrid.CurrentCell) {
      return
    }
    $Index = $diagramFileGrid.CurrentCell.ColumnIndex
  }
  if ($Index -lt 0 -or $Index -ge $diagramFileGrid.Columns.Count) {
    return
  }
  $diagramFileGrid.Columns.RemoveAt($Index)
  for ($columnIndex = 0; $columnIndex -lt $diagramFileGrid.Columns.Count; $columnIndex++) {
    $diagramFileGrid.Columns[$columnIndex].Name = "column$columnIndex"
    $diagramFileGrid.Columns[$columnIndex].HeaderText = Get-DiagramColumnName $columnIndex
  }
  Update-DiagramEditorStatus
  Record-DiagramGridHistory
}

function Save-DiagramXlsxWorkbook {
  param(
    [string]$Path,
    [string]$Destination,
    [object[]]$Rows
  )
  Initialize-DiagramCompression
  $sourceArchive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  $outputArchive = $null
  $outputStream = $null
  try {
    $sheetPath = Get-DiagramWorkbookSheetPath $sourceArchive
    $sheetEntry = $sourceArchive.GetEntry($sheetPath)
    $worksheet = New-Object System.Xml.XmlDocument
    $worksheet.XmlResolver = $null
    $worksheetStream = $sheetEntry.Open()
    try { $worksheet.Load($worksheetStream) } finally { $worksheetStream.Dispose() }
    $spreadsheetNsUri = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
    $worksheetNs = New-Object System.Xml.XmlNamespaceManager($worksheet.NameTable)
    $worksheetNs.AddNamespace('x', $spreadsheetNsUri)
    $sheetData = $worksheet.SelectSingleNode('/x:worksheet/x:sheetData', $worksheetNs)
    if (-not $sheetData) {
      throw 'The first worksheet does not contain sheet data.'
    }

    $existingRows = @{}
    foreach ($rowNode in @($sheetData.SelectNodes('x:row', $worksheetNs))) {
      $rowNumber = 0
      if ([int]::TryParse($rowNode.GetAttribute('r'), [ref]$rowNumber)) {
        $existingRows[$rowNumber] = $rowNode
      }
    }
    $lastDataRow = $Rows.Count
    foreach ($rowNumber in @($existingRows.Keys)) {
      if ([int]$rowNumber -gt $lastDataRow) {
        [void]$sheetData.RemoveChild($existingRows[$rowNumber])
        [void]$existingRows.Remove($rowNumber)
      }
    }

    $columnCount = 0
    foreach ($rowValues in $Rows) {
      $columnCount = [Math]::Max($columnCount, $rowValues.Count)
    }
    $columnCount = [Math]::Max(1, $columnCount)
    foreach ($rowNode in @($sheetData.SelectNodes('x:row', $worksheetNs))) {
      foreach ($cellNode in @($rowNode.SelectNodes('x:c', $worksheetNs))) {
        if ($cellNode.GetAttribute('r') -match '^([A-Z]+)\d+$' -and
            (Get-DiagramExcelColumnIndex $Matches[1]) -ge $columnCount) {
          [void]$rowNode.RemoveChild($cellNode)
        }
      }
    }
    for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
      $rowNumber = $rowIndex + 1
      if ($existingRows.ContainsKey($rowNumber)) {
        $rowNode = $existingRows[$rowNumber]
      } else {
        $rowNode = $worksheet.CreateElement('row', $spreadsheetNsUri)
        $rowNode.SetAttribute('r', [string]$rowNumber)
        $nextRow = $null
        foreach ($candidate in @($sheetData.SelectNodes('x:row', $worksheetNs))) {
          $candidateNumber = 0
          if ([int]::TryParse($candidate.GetAttribute('r'), [ref]$candidateNumber) -and $candidateNumber -gt $rowNumber) {
            $nextRow = $candidate
            break
          }
        }
        if ($nextRow) {
          [void]$sheetData.InsertBefore($rowNode, $nextRow)
        } else {
          [void]$sheetData.AppendChild($rowNode)
        }
        $existingRows[$rowNumber] = $rowNode
      }

      $existingCells = @{}
      foreach ($cellNode in @($rowNode.SelectNodes('x:c', $worksheetNs))) {
        if ($cellNode.GetAttribute('r') -match '^([A-Z]+)\d+$') {
          $existingCells[(Get-DiagramExcelColumnIndex $Matches[1])] = $cellNode
        }
      }
      $rowValues = $Rows[$rowIndex]
      for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
        $value = if ($columnIndex -lt $rowValues.Count) { [string]$rowValues[$columnIndex] } else { '' }
        if (-not $value) {
          if ($existingCells.ContainsKey($columnIndex)) {
            [void]$rowNode.RemoveChild($existingCells[$columnIndex])
          }
          continue
        }
        if ($existingCells.ContainsKey($columnIndex)) {
          $cellNode = $existingCells[$columnIndex]
        } else {
          $cellNode = $worksheet.CreateElement('c', $spreadsheetNsUri)
          $cellNode.SetAttribute('r', "$(Get-DiagramColumnName $columnIndex)$rowNumber")
          $nextCell = $null
          foreach ($candidate in @($rowNode.SelectNodes('x:c', $worksheetNs))) {
            if ($candidate.GetAttribute('r') -match '^([A-Z]+)\d+$' -and
                (Get-DiagramExcelColumnIndex $Matches[1]) -gt $columnIndex) {
              $nextCell = $candidate
              break
            }
          }
          if ($nextCell) {
            [void]$rowNode.InsertBefore($cellNode, $nextCell)
          } else {
            [void]$rowNode.AppendChild($cellNode)
          }
          $existingCells[$columnIndex] = $cellNode
        }
        while ($cellNode.HasChildNodes) {
          [void]$cellNode.RemoveChild($cellNode.FirstChild)
        }
        $cellNode.SetAttribute('t', 'inlineStr')
        $inlineString = $worksheet.CreateElement('is', $spreadsheetNsUri)
        $textNode = $worksheet.CreateElement('t', $spreadsheetNsUri)
        [void]$textNode.SetAttribute('space', 'http://www.w3.org/XML/1998/namespace', 'preserve')
        $textNode.InnerText = $value
        [void]$inlineString.AppendChild($textNode)
        [void]$cellNode.AppendChild($inlineString)
      }
    }

    $dimension = $worksheet.SelectSingleNode('/x:worksheet/x:dimension', $worksheetNs)
    if ($dimension) {
      if ($Rows.Count -gt 0) {
        $dimension.SetAttribute('ref', "A1:$(Get-DiagramColumnName ($columnCount - 1))$($Rows.Count)")
      } else {
        $dimension.SetAttribute('ref', 'A1')
      }
    }

    $outputStream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $outputArchive = New-Object System.IO.Compression.ZipArchive($outputStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
    foreach ($entry in $sourceArchive.Entries) {
      $newEntry = $outputArchive.CreateEntry($entry.FullName)
      $newStream = $newEntry.Open()
      try {
        if ($entry.FullName -eq $sheetPath) {
          $xmlBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($worksheet.OuterXml)
          $newStream.Write($xmlBytes, 0, $xmlBytes.Length)
        } else {
          $entryStream = $entry.Open()
          try { $entryStream.CopyTo($newStream) } finally { $entryStream.Dispose() }
        }
      } finally {
        $newStream.Dispose()
      }
    }
  } finally {
    if ($outputArchive) { $outputArchive.Dispose() }
    if ($outputStream) { $outputStream.Dispose() }
    $sourceArchive.Dispose()
  }
}

function Export-DiagramXlsxWorkbook {
  param(
    [string]$Destination,
    [object[]]$Rows
  )
  if ($Rows.Count -gt 1048576) {
    throw 'An Excel worksheet cannot contain more than 1,048,576 rows.'
  }
  $columnCount = 0
  foreach ($rowValues in $Rows) {
    $columnCount = [Math]::Max($columnCount, $rowValues.Count)
  }
  if ($columnCount -gt 16384) {
    throw 'An Excel worksheet cannot contain more than 16,384 columns.'
  }
  $columnCount = [Math]::Max(1, $columnCount)
  $lastCell = if ($Rows.Count -gt 0) { "$(Get-DiagramColumnName ($columnCount - 1))$($Rows.Count)" } else { 'A1' }
  $sheet = New-Object System.Text.StringBuilder
  [void]$sheet.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
  [void]$sheet.Append('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:')
  [void]$sheet.Append($lastCell)
  [void]$sheet.Append('"/><sheetViews><sheetView workbookViewId="0"/></sheetViews><sheetFormatPr defaultRowHeight="15"/><sheetData>')
  for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
    $rowNumber = $rowIndex + 1
    [void]$sheet.Append("<row r=`"$rowNumber`">")
    $rowValues = $Rows[$rowIndex]
    for ($columnIndex = 0; $columnIndex -lt $rowValues.Count; $columnIndex++) {
      $value = [string]$rowValues[$columnIndex]
      if ($value.Length -eq 0) { continue }
      [void][System.Xml.XmlConvert]::VerifyXmlChars($value)
      $escapedValue = [System.Security.SecurityElement]::Escape($value)
      $cellReference = "$(Get-DiagramColumnName $columnIndex)$rowNumber"
      [void]$sheet.Append("<c r=`"$cellReference`" t=`"inlineStr`"><is><t xml:space=`"preserve`">$escapedValue</t></is></c>")
    }
    [void]$sheet.Append('</row>')
  }
  [void]$sheet.Append('</sheetData></worksheet>')

  $entries = [ordered]@{
    '[Content_Types].xml' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>'
    '_rels/.rels' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'
    'xl/workbook.xml' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>'
    'xl/_rels/workbook.xml.rels' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'
    'xl/worksheets/sheet1.xml' = $sheet.ToString()
  }

  Initialize-DiagramCompression
  $fileStream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  $archive = $null
  try {
    $archive = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
    foreach ($entryName in $entries.Keys) {
      $entry = $archive.CreateEntry([string]$entryName)
      $entryStream = $entry.Open()
      try {
        $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes([string]$entries[$entryName])
        $entryStream.Write($bytes, 0, $bytes.Length)
      } finally {
        $entryStream.Dispose()
      }
    }
  } finally {
    if ($archive) { $archive.Dispose() }
    $fileStream.Dispose()
  }
}

function Get-DiagramEditorContent {
  if ($script:diagramEditorMode -in @('csv', 'xlsx')) {
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $delimiter = if ($script:diagramEditorMode -eq 'xlsx') { ',' } else { [string]$script:diagramCsvDelimiter }
    foreach ($gridRow in (Get-DiagramGridRows)) {
      $values = New-Object 'System.Collections.Generic.List[string]'
      foreach ($rawValue in $gridRow) {
        $value = [string]$rawValue
        if ($value.Contains($delimiter) -or $value -match '["\r\n]') {
          $value = '"' + $value.Replace('"', '""') + '"'
        }
        $values.Add($value)
      }
      $lines.Add(($values -join $delimiter))
    }
    if ($lines.Count -eq 0) { return '' }
    return ($lines -join "`r`n") + "`r`n"
  }
  return $diagramFileEditor.Text
}

function Set-DiagramBrowseSource {
  param([ValidateSet('local', 'repo')][string]$Source)
  $script:diagramBrowseSource = $Source
  $selectedBackColor = [System.Drawing.Color]::FromArgb(220, 234, 248)
  $unselectedBackColor = [System.Drawing.Color]::White
  if ($diagramLocalButton) {
    $diagramLocalButton.BackColor = if ($Source -eq 'local') { $selectedBackColor } else { $unselectedBackColor }
  }
  if ($diagramRepoButton) {
    $diagramRepoButton.BackColor = if ($Source -eq 'repo') { $selectedBackColor } else { $unselectedBackColor }
  }
  if (Get-Command Request-FormStateSave -ErrorAction SilentlyContinue) {
    Request-FormStateSave
  }
}

function Get-DiagramPageState {
  $openedFile = ''
  $openedFileSource = ''
  if ($script:diagramEditorRemoteFile) {
    $openedFile = [string]$script:diagramEditorRemoteFile.Path
    $openedFileSource = 'repo'
  } elseif ($script:diagramEditorLoadedPath -and -not $script:diagramEditorRemoteFile) {
    $openedFile = [string]$script:diagramEditorLoadedPath
    $openedFileSource = 'local'
  }
  $selectedItem = ''
  if ($diagramFileList -and $diagramFileList.SelectedItems.Count -gt 0) {
    $tag = $diagramFileList.SelectedItems[0].Tag
    $selectedItem = if ($script:diagramBrowseSource -eq 'repo') { [string]$tag.Path } else { [string]$tag }
  }
  $editorContent = ''
  if ($script:diagramEditorLoadedPath) {
    $editorContent = Get-DiagramEditorContent
  }
  $gridRowIndex = -1
  $gridColumnIndex = -1
  $gridFirstDisplayedRowIndex = -1
  $gridFirstDisplayedColumnIndex = -1
  if ($diagramFileGrid.CurrentCell) {
    $gridRowIndex = [int]$diagramFileGrid.CurrentCell.RowIndex
    $gridColumnIndex = [int]$diagramFileGrid.CurrentCell.ColumnIndex
  }
  if ($diagramFileGrid.Visible -and $diagramFileGrid.Rows.Count -gt 0) {
    $gridFirstDisplayedRowIndex = [int]$diagramFileGrid.FirstDisplayedScrollingRowIndex
  }
  if ($diagramFileGrid.Visible -and $diagramFileGrid.Columns.Count -gt 0) {
    $gridFirstDisplayedColumnIndex = [int]$diagramFileGrid.FirstDisplayedScrollingColumnIndex
  }
  $topItem = ''
  if ($diagramFileList -and $diagramFileList.Items.Count -gt 0 -and $diagramFileList.TopItem) {
    $topTag = $diagramFileList.TopItem.Tag
    $topItem = if ($script:diagramBrowseSource -eq 'repo') { [string]$topTag.Path } else { [string]$topTag }
  }
  $gridColumnWidths = @(
    foreach ($column in $diagramFileGrid.Columns) {
      [int]$column.Width
    }
  )
  return [pscustomobject]@{
    Source = [string]$script:diagramBrowseSource
    RepositoryUrl = [string]$diagramPageBox.Text
    LocalRoot = [string]$diagramProjectBox.Text
    LocalDirectory = [string]$script:diagramBrowseDirectory
    RepoPath = [string]$script:diagramBrowseRepoPath
    SelectedItem = $selectedItem
    TopItem = $topItem
    OpenedFile = $openedFile
    OpenedFileSource = $openedFileSource
    EditorMode = [string]$script:diagramEditorMode
    EditorContent = $editorContent
    EditorOriginalText = [string]$script:diagramEditorOriginalText
    CsvDelimiter = [string]$script:diagramCsvDelimiter
    SearchText = [string]$diagramSearchBox.Text
    EditorSelectionStart = [int]$diagramFileEditor.SelectionStart
    EditorSelectionLength = [int]$diagramFileEditor.SelectionLength
    GridRowIndex = $gridRowIndex
    GridColumnIndex = $gridColumnIndex
    GridFirstDisplayedRowIndex = $gridFirstDisplayedRowIndex
    GridFirstDisplayedColumnIndex = $gridFirstDisplayedColumnIndex
    GridColumnWidths = $gridColumnWidths
  }
}

function Restore-DiagramEditorContent {
  param($State)
  $mode = [string]$State.EditorMode
  $content = [string]$State.EditorContent
  $script:diagramEditorLoading = $true
  try {
    if ($mode -in @('csv', 'xlsx')) {
      $delimiterText = [string]$State.CsvDelimiter
      $delimiter = if ($mode -eq 'xlsx' -or -not $delimiterText) { [char]',' } else { [char]$delimiterText }
      $gridData = ConvertFrom-DiagramCsv $content $delimiter
      $diagramFileGrid.Columns.Clear()
      $diagramFileGrid.Rows.Clear()
      $columnCount = [Math]::Max(1, [int]$gridData.ColumnCount)
      for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
        $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $column.Name = "column$columnIndex"
        $column.HeaderText = Get-DiagramColumnName $columnIndex
        $column.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
        $column.Width = 150
        [void]$diagramFileGrid.Columns.Add($column)
      }
      foreach ($dataRow in $gridData.Rows) {
        $rowIndex = $diagramFileGrid.Rows.Add()
        for ($columnIndex = 0; $columnIndex -lt $dataRow.Count; $columnIndex++) {
          $diagramFileGrid.Rows[$rowIndex].Cells[$columnIndex].Value = $dataRow[$columnIndex]
        }
      }
      Set-DiagramGridHeaderRow
      $diagramFileEditor.Visible = $false
      $diagramLineNumberGutter.Visible = $false
      $diagramFileGrid.Visible = $true
      $script:diagramEditorMode = $mode
      if ($mode -ne 'xlsx') { $script:diagramCsvDelimiter = [string]$delimiter }
    } elseif ($mode -eq 'text') {
      $diagramFileEditor.Text = $content
      $diagramFileGrid.Visible = $false
      $diagramLineNumberGutter.Visible = $true
      $diagramFileEditor.Visible = $true
      $script:diagramEditorMode = 'text'
    }
  } finally {
    $script:diagramEditorLoading = $false
  }
  $script:diagramEditorOriginalText = [string]$State.EditorOriginalText
  if ($State.EditorSelectionStart -ge 0 -and $diagramFileEditor.Visible) {
    $start = [Math]::Min([int]$State.EditorSelectionStart, $diagramFileEditor.TextLength)
    $length = [Math]::Min([int]$State.EditorSelectionLength, $diagramFileEditor.TextLength - $start)
    $diagramFileEditor.Select($start, $length)
  }
  if ($diagramFileGrid.Visible -and $State.GridRowIndex -ge 0 -and $State.GridColumnIndex -ge 0 -and
      $State.GridRowIndex -lt $diagramFileGrid.Rows.Count -and $State.GridColumnIndex -lt $diagramFileGrid.Columns.Count) {
    $diagramFileGrid.CurrentCell = $diagramFileGrid.Rows[[int]$State.GridRowIndex].Cells[[int]$State.GridColumnIndex]
  }
  if ($diagramFileGrid.Visible -and $State.GridFirstDisplayedRowIndex -ge 0 -and
      $diagramFileGrid.Rows.Count -gt 0) {
    $diagramFileGrid.FirstDisplayedScrollingRowIndex = [Math]::Max(
      0,
      [Math]::Min([int]$State.GridFirstDisplayedRowIndex, $diagramFileGrid.Rows.Count - 1)
    )
  }
  if ($diagramFileGrid.Visible -and $State.GridFirstDisplayedColumnIndex -ge 0 -and
      $State.GridFirstDisplayedColumnIndex -lt $diagramFileGrid.Columns.Count) {
    $diagramFileGrid.FirstDisplayedScrollingColumnIndex = [int]$State.GridFirstDisplayedColumnIndex
  }
  if ($diagramFileGrid.Visible) {
    for ($columnIndex = 0; $columnIndex -lt [Math]::Min($State.GridColumnWidths.Count, $diagramFileGrid.Columns.Count); $columnIndex++) {
      $width = [int]$State.GridColumnWidths[$columnIndex]
      if ($width -ge $diagramFileGrid.Columns[$columnIndex].MinimumWidth) {
        $diagramFileGrid.Columns[$columnIndex].Width = $width
      }
    }
  }
  Reset-DiagramGridHistory
  Update-DiagramEditorStatus
}

function Restore-DiagramPageState {
  param($State)
  if ($null -eq $State) { return }
  $source = if ([string]$State.Source -eq 'repo') { 'repo' } else { 'local' }
  $repositoryUrl = [string]$State.RepositoryUrl
  if ($repositoryUrl -match '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?/?$') {
    $diagramPageBox.Text = $repositoryUrl -replace '\.git/?$', ''
  }
  $root = [string]$State.LocalRoot
  if ($root) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
      if ($source -eq 'local') { throw "Saved Local folder not found: $root" }
    } else {
      $diagramProjectBox.Text = [IO.Path]::GetFullPath($root)
    }
  }
  $script:diagramBrowseDirectory = [string]$State.LocalDirectory
  $script:diagramBrowseRepoPath = [string]$State.RepoPath
  Set-DiagramBrowseSource $source
  $diagramSearchBox.Text = [string]$State.SearchText
  if ($source -eq 'repo') {
    Update-DiagramRepositoryFileList
  } else {
    Update-DiagramFileList
  }

  $selectedPath = [string]$State.SelectedItem
  if ($selectedPath) {
    foreach ($item in $diagramFileList.Items) {
      $itemPath = if ($source -eq 'repo') { [string]$item.Tag.Path } else { [string]$item.Tag }
      if ($itemPath -ieq $selectedPath) {
        $item.Selected = $true
        $item.Focused = $true
        break
      }
    }
  }
  $topPath = [string]$State.TopItem
  if ($topPath) {
    foreach ($item in $diagramFileList.Items) {
      $itemPath = if ($source -eq 'repo') { [string]$item.Tag.Path } else { [string]$item.Tag }
      if ($itemPath -ieq $topPath) {
        $diagramFileList.TopItem = $item
        break
      }
    }
  }

  $openedFile = [string]$State.OpenedFile
  if ($openedFile) {
    $openedFileSource = if ([string]$State.OpenedFileSource -eq 'repo') { 'repo' } else { $source }
    if ($openedFileSource -eq 'repo') {
      [void](Open-DiagramRepositoryFile ([pscustomobject]@{ Type = 'file'; Path = $openedFile }))
    } elseif (Test-Path -LiteralPath $openedFile -PathType Leaf) {
      if (-not (Load-DiagramEditorFile $openedFile)) { return }
      $script:diagramLocalPagePath = Get-DiagramRelativePagePath $diagramProjectBox.Text $openedFile
    }
    if ($script:diagramEditorLoadedPath) {
      Restore-DiagramEditorContent $State
    }
  }
  Request-FormStateSave
}

function Update-DiagramEditorStatus {
  if (-not $script:diagramEditorLoadedPath -or $script:diagramEditorLoading) {
    return
  }
  $changed = (Get-DiagramEditorContent) -cne $script:diagramEditorOriginalText
  if ($script:diagramEditorRemoteFile) {
    $displayPath = "Opened from GitHub: $($script:diagramEditorRemoteFile.Repository)/$($script:diagramEditorRemoteFile.Path)"
  } else {
    $displayPath = $script:diagramEditorLoadedPath
  }
  $state = if ($changed) { ' (Modified)' } else { '' }
  $script:diagramEditorStatusLabel.Text = $displayPath + $state
}

function Save-DiagramEditorFile {
  param([string]$Path)
  if ($script:diagramEditorMode -in @('csv', 'xlsx')) {
    [void]$diagramFileGrid.EndEdit()
  }
  $fullPath = [IO.Path]::GetFullPath($Path)
  $root = [IO.Path]::GetFullPath($diagramProjectBox.Text.Trim()).TrimEnd([IO.Path]::DirectorySeparatorChar)
  if (-not $fullPath.StartsWith(($root + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The selected file is outside the Project folder.'
  }
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf) -or
      ((Get-Item -LiteralPath $fullPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'The selected file no longer exists or is a linked file.'
  }
  $temporaryPath = $fullPath + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
  $backupPath = $fullPath + '.' + [Guid]::NewGuid().ToString('N') + '.bak'
  $content = Get-DiagramEditorContent
  try {
    if ($script:diagramEditorMode -eq 'xlsx') {
      Save-DiagramXlsxWorkbook -Path $fullPath -Destination $temporaryPath -Rows (Get-DiagramGridRows)
    } else {
      $bytes = [IO.File]::ReadAllBytes($fullPath)
      $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
      [IO.File]::WriteAllText($temporaryPath, $content, (New-Object System.Text.UTF8Encoding($hasBom)))
    }
    [IO.File]::Replace($temporaryPath, $fullPath, $backupPath)
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction Stop
    }
    if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
      Remove-Item -LiteralPath $backupPath -Force -ErrorAction Stop
    }
  }
  $script:diagramEditorLoadedPath = $fullPath
  $script:diagramEditorOriginalText = $content
  $diagramEditorStatusLabel.Text = "Saved: $fullPath"
  Request-FormStateSave
}

function Get-DiagramGitHubApiHeaders {
  $user = Get-HomeRepoAccount $homeRepoBox.Text
  $token = Get-HomeGitHubToken $user
  $headers = @{ 'User-Agent' = 'IJTC-ComBox'; 'Accept' = 'application/vnd.github+json' }
  if ($token) { $headers['Authorization'] = 'Bearer ' + $token }
  return $headers
}

function Get-DiagramRepositoryContentApiUrl {
  param([string]$Path)
  $segments = @()
  $relativePath = ([string]$Path).Trim().Trim('/')
  if ($relativePath) {
    $segments = @($relativePath -split '/')
    if ($segments -contains '.' -or $segments -contains '..' -or
        ($segments | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
      throw 'The Repo path must be a repository-relative path without empty, . or .. segments.'
    }
  }
  $repository = Get-DiagramGitHubRepositoryInfo
  $encodedPath = ($segments | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
  $apiUrl = "https://api.github.com/repos/$($repository.Owner)/$($repository.Name)/contents"
  if ($encodedPath) { $apiUrl += "/$encodedPath" }
  return $apiUrl
}

function Confirm-DiagramRepositoryUpdate {
  param($RemoteFile)
  $answer = [System.Windows.Forms.MessageBox]::Show(
    $form,
    "Commit changes to $($RemoteFile.Repository)/$($RemoteFile.Path) on GitHub?",
    'Update repository file',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Warning,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button2
  )
  return $answer -eq [System.Windows.Forms.DialogResult]::Yes
}

function Save-DiagramRepositoryFile {
  if (-not $script:diagramEditorRemoteFile) {
    throw 'Select and open a repository file before saving.'
  }
  if ($script:diagramEditorMode -in @('csv', 'xlsx')) {
    [void]$diagramFileGrid.EndEdit()
  }
  $content = Get-DiagramEditorContent
  if ($content -ceq $script:diagramEditorOriginalText) {
    $diagramEditorStatusLabel.Text = "No changes to save: $($script:diagramEditorRemoteFile.Path)"
    return $true
  }
  $remote = $script:diagramEditorRemoteFile
  if (-not (Confirm-DiagramRepositoryUpdate $remote)) {
    return $false
  }

  $temporaryPath = [IO.Path]::Combine(
    [IO.Path]::GetTempPath(),
    'IJTC-ComBox-' + [Guid]::NewGuid().ToString('N') + [IO.Path]::GetExtension($remote.Path)
  )
  try {
    if ($script:diagramEditorMode -eq 'xlsx') {
      Save-DiagramXlsxWorkbook -Path $remote.TempPath -Destination $temporaryPath -Rows (Get-DiagramGridRows)
      $bytes = [IO.File]::ReadAllBytes($temporaryPath)
    } else {
      $originalBytes = [byte[]]$remote.Bytes
      $hasBom = $originalBytes.Length -ge 3 -and $originalBytes[0] -eq 0xEF -and
        $originalBytes[1] -eq 0xBB -and $originalBytes[2] -eq 0xBF
      $bytes = (New-Object System.Text.UTF8Encoding($hasBom)).GetBytes($content)
    }

    $body = @{
      message = "Update $($remote.Path)"
      content = [Convert]::ToBase64String($bytes)
      sha = [string]$remote.Sha
    } | ConvertTo-Json -Compress
    $headers = Get-DiagramGitHubApiHeaders
    try {
      $result = Invoke-RestMethod -Uri $remote.ApiUrl -Method Put -Headers $headers `
        -ContentType 'application/json; charset=utf-8' -Body $body -ErrorAction Stop
    } catch {
      $statusCode = 0
      if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
        $statusCode = [int]$_.Exception.Response.StatusCode
      }
      if ($statusCode -eq 409 -or $statusCode -eq 422) {
        throw 'GitHub rejected the update because the file may have changed remotely. Reload the file and try again.'
      }
      if ($statusCode -eq 401 -or $statusCode -eq 403) {
        throw 'GitHub denied the update. Verify that the connected account has permission to write repository contents and that the branch allows direct commits.'
      }
      throw "Could not update '$($remote.Repository)/$($remote.Path)': $($_.Exception.Message)"
    }
    if (-not $result.content.sha) {
      throw "GitHub did not confirm the update to '$($remote.Path)'."
    }
    [IO.File]::WriteAllBytes($remote.TempPath, $bytes)
    $remote.Sha = [string]$result.content.sha
    $remote.Bytes = $bytes
    $script:diagramEditorOriginalText = $content
    $diagramEditorStatusLabel.Text = "Updated on GitHub: $($remote.Repository)/$($remote.Path)"
    Request-FormStateSave
    return $true
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction Stop
    }
  }
}

function Save-DiagramCurrentFile {
  if ($script:diagramEditorRemoteFile) {
    return Save-DiagramRepositoryFile
  }
  Save-DiagramEditorFile $script:diagramEditorLoadedPath
  return $true
}

function Confirm-DiagramEditorCanChangeFile {
  if ($script:diagramEditorMode -in @('csv', 'xlsx')) {
    [void]$diagramFileGrid.EndEdit()
  }
  if (-not $script:diagramEditorLoadedPath -or
      (Get-DiagramEditorContent) -ceq $script:diagramEditorOriginalText) {
    return $true
  }
  $answer = [System.Windows.Forms.MessageBox]::Show(
    $form,
    'Save changes to the current file before loading another file?',
    'Unsaved changes',
    [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
    [System.Windows.Forms.MessageBoxIcon]::Warning,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button1
  )
  if ($answer -eq [System.Windows.Forms.DialogResult]::Cancel) {
    return $false
  }
  if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
    if (-not (Save-DiagramCurrentFile)) {
      return $false
    }
  }
  return $true
}

function Load-DiagramEditorFile {
  param(
    [string]$Path,
    [switch]$Delimited
  )
  $fullPath = [IO.Path]::GetFullPath($Path)
  if ($script:diagramEditorLoadedPath -ieq $fullPath) {
    return $true
  }
  if (-not (Confirm-DiagramEditorCanChangeFile)) {
    return $false
  }
  $extension = [IO.Path]::GetExtension($fullPath)
  $isXlsx = $extension -ieq '.xlsx' -and (Test-DiagramXlsxPackage $fullPath)
  $isDelimited = (Test-DiagramCsvFile $fullPath) -or $Delimited
  $isTextXlsxFallback = $extension -ieq '.xlsx' -and -not $isXlsx
  $isGridFile = $isDelimited -or $isXlsx -or $isTextXlsxFallback
  if ($isXlsx) {
    $gridData = Read-DiagramXlsxWorkbook $fullPath
    $script:diagramCsvDelimiter = ','
  } elseif ($isDelimited -or $extension -ieq '.xlsx') {
    $bytes = [IO.File]::ReadAllBytes($fullPath)
    if ([Array]::IndexOf($bytes, [byte]0) -ge 0) {
      throw 'This file contains binary data and cannot be shown in the text editor.'
    }
    $text = [IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    $delimitedFormat = Get-DiagramDelimitedFormat $fullPath $text
    $script:diagramCsvDelimiter = [string]$delimitedFormat.Delimiter
    $gridData = ConvertFrom-DiagramCsv $text $delimitedFormat.Delimiter
  } else {
    $bytes = [IO.File]::ReadAllBytes($fullPath)
    if ([Array]::IndexOf($bytes, [byte]0) -ge 0) {
      throw 'This file contains binary data and cannot be shown in the text editor.'
    }
    $text = [IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
  }
  if ($isGridFile -and $gridData.ColumnCount -gt 256) {
    throw 'This file has more than 256 columns and cannot be displayed.'
  }
  $script:diagramEditorLoading = $true
  try {
    if ($isGridFile) {
      $diagramFileGrid.Columns.Clear()
      $diagramFileGrid.Rows.Clear()
      $columnCount = [Math]::Max(1, $gridData.ColumnCount)
      for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
        $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $column.Name = "column$columnIndex"
        $column.HeaderText = Get-DiagramColumnName $columnIndex
        $column.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
        $column.Width = 150
        [void]$diagramFileGrid.Columns.Add($column)
      }
      foreach ($dataRow in $gridData.Rows) {
        $rowIndex = $diagramFileGrid.Rows.Add()
        for ($columnIndex = 0; $columnIndex -lt $dataRow.Count; $columnIndex++) {
          $diagramFileGrid.Rows[$rowIndex].Cells[$columnIndex].Value = $dataRow[$columnIndex]
        }
      }
      Set-DiagramGridHeaderRow
      $diagramFileEditor.Visible = $false
      $diagramLineNumberGutter.Visible = $false
      $diagramFileGrid.Visible = $true
      $script:diagramEditorMode = if ($isXlsx) { 'xlsx' } else { 'csv' }
    } else {
      $diagramFileEditor.Text = $text
      $diagramFileGrid.Visible = $false
      $diagramLineNumberGutter.Visible = $true
      $diagramFileEditor.Visible = $true
      $script:diagramEditorMode = 'text'
    }
  } finally {
    $script:diagramEditorLoading = $false
  }
  $script:diagramEditorLoadedPath = $fullPath
  $script:diagramEditorOriginalText = Get-DiagramEditorContent
  Reset-DiagramGridHistory
  if ($script:diagramEditorRemoteFile) {
    $oldRemoteTempPath = [string]$script:diagramEditorRemoteFile.TempPath
    $script:diagramEditorRemoteFile = $null
    if ($oldRemoteTempPath -and (Test-Path -LiteralPath $oldRemoteTempPath -PathType Leaf)) {
      Remove-Item -LiteralPath $oldRemoteTempPath -Force -ErrorAction Stop
    }
  }
  $diagramEditorStatusLabel.Text = if ($isTextXlsxFallback) {
    $fullPath + ' (Delimited text, not an Excel workbook)'
  } else {
    $fullPath
  }
  return $true
}

function Update-DiagramFileList {
  Set-DiagramBrowseSource 'local'
  $root = [IO.Path]::GetFullPath($diagramProjectBox.Text.Trim())
  if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Project folder not found: $root"
  }
  $script:diagramBrowseRoot = $root
  $current = if ($script:diagramBrowseDirectory) {
    [IO.Path]::GetFullPath($script:diagramBrowseDirectory)
  } else {
    $root
  }
  $rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if ($current.TrimEnd([IO.Path]::DirectorySeparatorChar) -ine $root.TrimEnd([IO.Path]::DirectorySeparatorChar) -and
      -not $current.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    $current = $root
  }
  $script:diagramBrowseDirectory = $current

  $diagramFileList.BeginUpdate()
  try {
    $diagramFileList.Items.Clear()
    $diagramBrowsePathLabel.Text = $current
    $entries = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop |
      Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 } |
      Sort-Object @{ Expression = { -not $_.PSIsContainer } }, Name)
    foreach ($entry in $entries) {
      $item = New-Object System.Windows.Forms.ListViewItem($entry.Name)
      [void]$item.SubItems.Add($(if ($entry.PSIsContainer) { 'Folder' } else { 'File' }))
      $item.Tag = $entry.FullName
      [void]$diagramFileList.Items.Add($item)
    }
  } finally {
    $diagramFileList.EndUpdate()
  }
}

function Get-DiagramGitHubRepositoryInfo {
  $repositoryUrl = [string]$diagramPageBox.Text.Trim()
  if ($repositoryUrl -notmatch '^https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?$') {
    throw 'Choose a connected GitHub repository with the Repo search button first.'
  }
  return [pscustomobject]@{
    Owner = $Matches[1]
    Name = $Matches[2]
  }
}

function Update-DiagramRepositoryFileList {
  $repository = Get-DiagramGitHubRepositoryInfo
  $repoPath = [string]$script:diagramBrowseRepoPath
  $segments = @()
  if ($repoPath) {
    $segments = @($repoPath -split '/')
    if ($segments -contains '.' -or $segments -contains '..' -or
        ($segments | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
      throw 'The Repo path must be a repository-relative path without empty, . or .. segments.'
    }
  }
  $encodedPath = ($segments | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
  $apiUrl = "https://api.github.com/repos/$($repository.Owner)/$($repository.Name)/contents"
  if ($encodedPath) { $apiUrl += "/$encodedPath" }
  $user = Get-HomeRepoAccount $homeRepoBox.Text
  $token = Get-HomeGitHubToken $user
  $headers = @{ 'User-Agent' = 'IJTC-ComBox'; 'Accept' = 'application/vnd.github+json' }
  if ($token) { $headers['Authorization'] = "Bearer $token" }
  try {
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
  } catch {
    $statusCode = 0
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }
    if ($statusCode -eq 404) {
      if ($repoPath) {
        throw "GitHub could not find path '/$repoPath' in '$($repository.Owner)/$($repository.Name)'. Check the Repo path and the repository's default branch. If the repository is private, verify that the signed-in GitHub account has access."
      }
      throw "GitHub could not find repository '$($repository.Owner)/$($repository.Name)', or the signed-in GitHub account does not have access. Verify the selected repository and account."
    }
    throw "Could not read '$($repository.Owner)/$($repository.Name)' at '/$repoPath': $($_.Exception.Message)"
  }
  if ([string]$response.type -eq 'file' -and [string]$response.path -eq $repoPath) {
    Set-DiagramBrowseSource 'repo'
    $script:diagramBrowseRepoPath = $repoPath
    [void](Open-DiagramRepositoryFile ([pscustomobject]@{ Type = 'file'; Path = $repoPath }))
    return
  }
  $entries = @($response)
  Set-DiagramBrowseSource 'repo'
  $script:diagramBrowseRepoPath = $repoPath
  $diagramFileList.BeginUpdate()
  try {
    $diagramFileList.Items.Clear()
    foreach ($entry in ($entries | Sort-Object @{ Expression = { $_.type -ne 'dir' } }, name)) {
      $isDirectory = [string]$entry.type -eq 'dir'
      $item = New-Object System.Windows.Forms.ListViewItem([string]$entry.name)
      [void]$item.SubItems.Add($(if ($isDirectory) { 'Folder' } else { 'File' }))
      $relativePath = if ($repoPath) { "$repoPath/$($entry.name)" } else { [string]$entry.name }
      $item.Tag = [pscustomobject]@{
        Source = 'repo'
        Path = $relativePath
        Type = [string]$entry.type
        DownloadUrl = [string]$entry.download_url
      }
      [void]$diagramFileList.Items.Add($item)
    }
  } finally {
    $diagramFileList.EndUpdate()
  }
  $displayPath = if ($repoPath) { $repoPath } else { '/' }
  $diagramBrowsePathLabel.Text = "$($repository.Owner)/$($repository.Name)/$displayPath"
}

function Open-DiagramRepositoryFile {
  param($Entry)
  if ([string]$Entry.Type -ne 'file') {
    throw 'Select a repository file to open.'
  }
  $relativePath = [string]$Entry.Path
  $apiUrl = Get-DiagramRepositoryContentApiUrl $relativePath
  $headers = Get-DiagramGitHubApiHeaders
  try {
    $remoteFile = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
  } catch {
    $statusCode = 0
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }
    if ($statusCode -eq 404) {
      throw "GitHub could not find '$relativePath' in the selected repository, or the connected account does not have access."
    }
    if ($statusCode -eq 401 -or $statusCode -eq 403) {
      throw "GitHub denied access to '$relativePath'. Verify the connected account's repository access."
    }
    throw "Could not open repository file '$relativePath': $($_.Exception.Message)"
  }
  if ([string]$remoteFile.type -ne 'file') {
    throw "GitHub did not return a file for '$relativePath'."
  }
  if ([string]::IsNullOrWhiteSpace([string]$remoteFile.sha)) {
    throw "GitHub did not return the file version needed to safely update '$relativePath'."
  }
  if ([string]$remoteFile.encoding -ne 'base64' -or $null -eq $remoteFile.content) {
    throw "GitHub did not return editable file content for '$relativePath'. The file may be too large or binary."
  }
  try {
    $encodedContent = [string]$remoteFile.content
    $encodedContent = $encodedContent -replace '\s', ''
    $bytes = [Convert]::FromBase64String($encodedContent)
  } catch {
    throw "GitHub returned invalid file content for '$relativePath'."
  }
  $extension = [IO.Path]::GetExtension($relativePath)
  $temporaryPath = [IO.Path]::Combine(
    [IO.Path]::GetTempPath(),
    'IJTC-ComBox-' + [Guid]::NewGuid().ToString('N') + $extension
  )
  $loaded = $false
  try {
    [IO.File]::WriteAllBytes($temporaryPath, $bytes)
    $isDelimitedDataFile = $relativePath -match '^(?i:data)/'
    if (-not (Load-DiagramEditorFile -Path $temporaryPath -Delimited:$isDelimitedDataFile)) {
      return $false
    }
    $repository = Get-DiagramGitHubRepositoryInfo
    $script:diagramEditorRemoteFile = [pscustomobject]@{
      Path = $relativePath
      Repository = "$($repository.Owner)/$($repository.Name)"
      ApiUrl = $apiUrl
      Sha = [string]$remoteFile.sha
      Bytes = $bytes
      TempPath = $temporaryPath
    }
    $script:diagramEditorStatusLabel.Text = "Opened from GitHub: $($script:diagramEditorRemoteFile.Repository)/$relativePath"
    $loaded = $true
    Request-FormStateSave
    return $true
  } finally {
    if (-not $loaded -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
      Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction Stop
    }
  }
}

function Set-DiagramParentDirectory {
  if ($script:diagramBrowseSource -eq 'repo') {
    $repoPath = [string]$script:diagramBrowseRepoPath
    if (-not $repoPath) { return }
    $separator = $repoPath.LastIndexOf('/')
    $parentPath = if ($separator -ge 0) { $repoPath.Substring(0, $separator) } else { '' }
    $script:diagramBrowseRepoPath = $parentPath
    Update-DiagramRepositoryFileList
    return
  }
  $root = [IO.Path]::GetFullPath($diagramProjectBox.Text.Trim())
  $current = [IO.Path]::GetFullPath($script:diagramBrowseDirectory)
  if ($current.TrimEnd([IO.Path]::DirectorySeparatorChar) -ieq $root.TrimEnd([IO.Path]::DirectorySeparatorChar)) {
    return
  }
  $parent = Split-Path -Parent $current
  $rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $parent -or
      ($parent.TrimEnd([IO.Path]::DirectorySeparatorChar) -ine $root.TrimEnd([IO.Path]::DirectorySeparatorChar) -and
       -not $parent.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase))) {
    $parent = $root
  }
  $script:diagramBrowseDirectory = $parent
  Update-DiagramFileList
}

function Move-DiagramFileSelection {
  param([ValidateSet('Up', 'Down')][string]$Direction)
  if ($diagramFileList.Items.Count -eq 0) {
    return
  }
  $selectedIndex = if ($diagramFileList.SelectedIndices.Count -gt 0) { $diagramFileList.SelectedIndices[0] } else { -1 }
  if ($Direction -eq 'Down') {
    $nextIndex = [Math]::Min($diagramFileList.Items.Count - 1, $selectedIndex + 1)
  } else {
    $nextIndex = if ($selectedIndex -lt 0) { $diagramFileList.Items.Count - 1 } else { [Math]::Max(0, $selectedIndex - 1) }
  }
  $diagramFileList.Items[$nextIndex].Selected = $true
  $diagramFileList.Items[$nextIndex].Focused = $true
  $diagramFileList.EnsureVisible($nextIndex)
  $diagramFileList.Focus()
}

function Enter-DiagramSelectedFolder {
  if ($diagramFileList.SelectedItems.Count -eq 0) {
    return
  }
  $selectedItem = $diagramFileList.SelectedItems[0]
  if ($script:diagramBrowseSource -eq 'repo') {
    $selectedEntry = $selectedItem.Tag
    if ($selectedEntry.Type -eq 'dir') {
      $script:diagramBrowseRepoPath = [string]$selectedEntry.Path
      Update-DiagramRepositoryFileList
    }
    return
  }
  $selectedPath = [string]$selectedItem.Tag
  if (-not (Test-Path -LiteralPath $selectedPath -PathType Container)) {
    return
  }
  $root = [IO.Path]::GetFullPath($diagramProjectBox.Text.Trim())
  $rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  $fullPath = [IO.Path]::GetFullPath($selectedPath)
  if (-not $fullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The selected folder is outside the Project folder.'
  }
  $script:diagramBrowseDirectory = $fullPath
  Update-DiagramFileList
}

function Browse-DiagramProjectFolder {
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  try {
    $dialog.Description = 'Choose a local Project folder on this PC'
    $dialog.ShowNewFolderButton = $false
    $currentProject = $diagramProjectBox.Text.Trim()
    if (Test-Path -LiteralPath $currentProject -PathType Container) {
      $dialog.SelectedPath = $currentProject
    }
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
      $selectedFolder = [IO.Path]::GetFullPath($dialog.SelectedPath)
      $diagramProjectBox.Text = $selectedFolder
      $script:diagramBrowseDirectory = $selectedFolder
      Update-DiagramFileList
    }
  } catch {
    $diagramBrowsePathLabel.Text = $_.Exception.Message
  } finally {
    $dialog.Dispose()
  }
}

function Import-DiagramXlsxFile {
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $copiedPath = ''
  $imported = $false
  try {
    $dialog.Title = 'Import an Excel workbook'
    $dialog.Filter = 'Excel workbook (*.xlsx)|*.xlsx'
    $dialog.DefaultExt = 'xlsx'
    $dialog.CheckFileExists = $true
    $dialog.Multiselect = $false
    if ($script:diagramBrowseDirectory -and (Test-Path -LiteralPath $script:diagramBrowseDirectory -PathType Container)) {
      $dialog.InitialDirectory = $script:diagramBrowseDirectory
    } elseif (Test-Path -LiteralPath $diagramProjectBox.Text -PathType Container) {
      $dialog.InitialDirectory = $diagramProjectBox.Text
    }
    if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
      return
    }
    $sourcePath = [IO.Path]::GetFullPath($dialog.FileName)
    if ([IO.Path]::GetExtension($sourcePath) -ine '.xlsx') {
      throw 'Choose an .xlsx Excel workbook.'
    }
    if (-not (Confirm-DiagramEditorCanChangeFile)) {
      return
    }
    $projectRoot = [IO.Path]::GetFullPath($diagramProjectBox.Text.Trim())
    if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) {
      throw "Local folder not found: $projectRoot"
    }
    $destinationDirectory = [IO.Path]::GetFullPath($script:diagramBrowseDirectory)
    $rootPrefix = $projectRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($destinationDirectory.TrimEnd([IO.Path]::DirectorySeparatorChar) -ine $projectRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) -and
        -not $destinationDirectory.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      $destinationDirectory = $projectRoot
    }
    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
      $destinationDirectory = $projectRoot
    }
    $sourcePrefix = $projectRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $sourceIsInProject = $sourcePath.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase)
    if ($sourceIsInProject -or $sourcePath -ieq $projectRoot) {
      $destinationPath = $sourcePath
    } else {
      $destinationPath = Join-Path $destinationDirectory ([IO.Path]::GetFileName($sourcePath))
      if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
        $suffix = 2
        do {
          $destinationPath = Join-Path $destinationDirectory ("$baseName ($suffix).xlsx")
          $suffix++
        } while (Test-Path -LiteralPath $destinationPath)
      }
      [IO.File]::Copy($sourcePath, $destinationPath, $false)
      $copiedPath = $destinationPath
    }
    if (-not (Load-DiagramEditorFile $destinationPath)) {
      return
    }
    $script:diagramBrowseDirectory = [IO.Path]::GetDirectoryName($destinationPath)
    $script:diagramLocalPagePath = Get-DiagramRelativePagePath $projectRoot $destinationPath
    Set-DiagramBrowseSource 'local'
    Update-DiagramFileList
    foreach ($item in $diagramFileList.Items) {
      if ([string]$item.Tag -ieq $destinationPath) {
        $item.Selected = $true
        $item.Focused = $true
        break
      }
    }
    $diagramEditorStatusLabel.Text = "Imported Excel workbook: $destinationPath"
    Request-FormStateSave
    $imported = $true
  } catch {
    [void][System.Windows.Forms.MessageBox]::Show(
      $form, $_.Exception.Message, 'Import Excel workbook',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    )
  } finally {
    if ($copiedPath -and -not $imported -and (Test-Path -LiteralPath $copiedPath -PathType Leaf)) {
      Remove-Item -LiteralPath $copiedPath -Force -ErrorAction Stop
    }
    $dialog.Dispose()
  }
}

function Export-DiagramCurrentSheet {
  if (-not $diagramFileGrid.Visible) {
    throw 'Open a spreadsheet sheet before exporting to Excel.'
  }
  [void]$diagramFileGrid.EndEdit()
  $dialog = New-Object System.Windows.Forms.SaveFileDialog
  $temporaryPath = ''
  $backupPath = ''
  try {
    $dialog.Title = 'Export the current sheet to Excel'
    $dialog.Filter = 'Excel workbook (*.xlsx)|*.xlsx'
    $dialog.DefaultExt = 'xlsx'
    $dialog.AddExtension = $true
    $dialog.OverwritePrompt = $true
    $sourceFileName = if ($script:diagramEditorRemoteFile) {
      [string]$script:diagramEditorRemoteFile.Path
    } elseif ($script:diagramEditorLoadedPath) {
      [string]$script:diagramEditorLoadedPath
    } else {
      ''
    }
    $exportBaseName = if ($sourceFileName) {
      [IO.Path]::GetFileNameWithoutExtension($sourceFileName)
    } else {
      'Sheet'
    }
    $dialog.FileName = $exportBaseName + '.xlsx'
    if ($script:diagramBrowseDirectory -and (Test-Path -LiteralPath $script:diagramBrowseDirectory -PathType Container)) {
      $dialog.InitialDirectory = $script:diagramBrowseDirectory
    }
    if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
      return
    }
    $destinationPath = [IO.Path]::GetFullPath($dialog.FileName)
    if ([IO.Path]::GetExtension($destinationPath) -ine '.xlsx') {
      $destinationPath += '.xlsx'
    }
    $temporaryPath = $destinationPath + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    Export-DiagramXlsxWorkbook -Destination $temporaryPath -Rows (Get-DiagramGridRows)
    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
      $backupPath = $destinationPath + '.' + [Guid]::NewGuid().ToString('N') + '.bak'
      [IO.File]::Replace($temporaryPath, $destinationPath, $backupPath)
    } else {
      [IO.File]::Move($temporaryPath, $destinationPath)
    }
    $diagramEditorStatusLabel.Text = "Exported Excel workbook: $destinationPath"
    Request-FormStateSave
  } finally {
    if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
      Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction Stop
    }
    if ($backupPath -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
      Remove-Item -LiteralPath $backupPath -Force -ErrorAction Stop
    }
    $dialog.Dispose()
  }
}

$FormParts.Tabs = {
  $relationRowY = 43 + $tabBarHeight
  $relationFolderLabel = New-Label 'Local' 467 ($relationRowY + 3) 76 22
  $form.Controls.Add($relationFolderLabel)
  $relationFolderBox = New-Object System.Windows.Forms.TextBox
  $relationFolderBox.Location = New-Object System.Drawing.Point(546, $relationRowY)
  $relationFolderBox.Size = New-Object System.Drawing.Size(230, 26)
  $relationFolderBox.ReadOnly = $true
  $relationFolderBox.AccessibleName = 'PC Folder for the relation graph'
  $relationFolderBox.Text = [string]$script:sectionFolders['relation']
  $form.Controls.Add($relationFolderBox)
  $relationBrowseButton = New-Object System.Windows.Forms.Button
  $relationBrowseButton.Location = New-Object System.Drawing.Point(782, $relationRowY)
  $relationBrowseButton.Size = New-Object System.Drawing.Size(30, 26)
  $relationBrowseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $relationBrowseButton.FlatAppearance.BorderSize = 0
  $relationBrowseButton.BackColor = [System.Drawing.Color]::White
  $relationBrowseButton.ForeColor = Get-FormColor $FormLayout.AccentColor
  $relationBrowseButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $relationBrowseButton.Text = [string][char]0xE721
  $relationBrowseButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $relationBrowseButton.Tag = 'noButtonSound'
  $relationBrowseButton.AccessibleName = 'Choose a PC folder for the relation graph'
  $toolTip.SetToolTip($relationBrowseButton, 'Choose a PC folder')
  $form.Controls.Add($relationBrowseButton)
  $relationRepoLabel = New-Label 'Repo' 37 ($relationRowY + 3) 72 22
  $form.Controls.Add($relationRepoLabel)
  $relationRepoBox = New-Object System.Windows.Forms.TextBox
  $relationRepoBox.Location = New-Object System.Drawing.Point(113, $relationRowY)
  $relationRepoBox.Size = New-Object System.Drawing.Size(304, 26)
  $relationRepoBox.ReadOnly = $true
  $relationRepoBox.AccessibleName = 'GitHub Repository for the relation graph'
  $form.Controls.Add($relationRepoBox)
  $relationRepoSearchButton = New-Object System.Windows.Forms.Button
  $relationRepoSearchButton.Location = New-Object System.Drawing.Point(423, $relationRowY)
  $relationRepoSearchButton.Size = New-Object System.Drawing.Size(30, 26)
  $relationRepoSearchButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $relationRepoSearchButton.FlatAppearance.BorderSize = 0
  $relationRepoSearchButton.BackColor = [System.Drawing.Color]::White
  $relationRepoSearchButton.ForeColor = Get-FormColor $FormLayout.AccentColor
  $relationRepoSearchButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $relationRepoSearchButton.Text = [string][char]0xE721
  $relationRepoSearchButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $relationRepoSearchButton.Tag = 'noButtonSound'
  $relationRepoSearchButton.AccessibleName = 'Search and select a GitHub repository'
  $toolTip.SetToolTip($relationRepoSearchButton, 'Choose a GitHub repository')
  $form.Controls.Add($relationRepoSearchButton)
  $relationRefreshButton = New-Object System.Windows.Forms.Button
  $relationRefreshButton.Location = New-Object System.Drawing.Point(818, $relationRowY)
  $relationRefreshButton.Size = New-Object System.Drawing.Size(30, 26)
  $relationRefreshButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $relationRefreshButton.FlatAppearance.BorderSize = 0
  $relationRefreshButton.BackColor = [System.Drawing.Color]::White
  $relationRefreshButton.ForeColor = Get-FormColor $FormLayout.AccentColor
  $relationRefreshButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $relationRefreshButton.Text = [string][char]0xE72C
  $relationRefreshButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $relationRefreshButton.Tag = 'noButtonSound'
  $relationRefreshButton.AccessibleName = 'Refresh worker.js relation graph'
  $toolTip.SetToolTip($relationRefreshButton, 'Refresh relation graph')
  $form.Controls.Add($relationRefreshButton)
  $relationCopyButton = New-Object System.Windows.Forms.Button
  $relationCopyButton.Location = New-Object System.Drawing.Point(854, $relationRowY)
  $relationCopyButton.Size = New-Object System.Drawing.Size(30, 26)
  $relationCopyButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $relationCopyButton.FlatAppearance.BorderSize = 0
  $relationCopyButton.BackColor = [System.Drawing.Color]::White
  $relationCopyButton.ForeColor = Get-FormColor $FormLayout.AccentColor
  $relationCopyButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $relationCopyButton.Text = [string][char]0xE8C8
  $relationCopyButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $relationCopyButton.Tag = 'noButtonSound'
  $relationCopyButton.AccessibleName = 'Copy Local and Repo relation differences'
  $toolTip.SetToolTip($relationCopyButton, 'Copy Local/Repo relation differences for AI')
  $form.Controls.Add($relationCopyButton)
  $relationFixButton = New-Object System.Windows.Forms.Button
  $relationFixButton.Location = New-Object System.Drawing.Point(890, $relationRowY)
  $relationFixButton.Size = New-Object System.Drawing.Size(30, 26)
  $relationFixButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $relationFixButton.FlatAppearance.BorderSize = 0
  $relationFixButton.BackColor = [System.Drawing.Color]::White
  $relationFixButton.ForeColor = Get-FormColor $FormLayout.AccentColor
  $relationFixButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $relationFixButton.Text = [string][char]0xE90F
  $relationFixButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $relationFixButton.Tag = 'noButtonSound'
  $relationFixButton.AccessibleName = 'Copy matching missing files from the other source and play the completion sound'
  $toolTip.SetToolTip($relationFixButton, 'Copy safe matching files to fix missing imports')
  $form.Controls.Add($relationFixButton)
  $relationStatusLabel = New-Label 'Choose a PC folder or GitHub repository to scan worker.js and its local dependencies.' 37 ($relationRowY + 29) 850 20
  $relationStatusLabel.AutoEllipsis = $true
  $relationStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $form.Controls.Add($relationStatusLabel)
  $relationGraphViewport = New-Object System.Windows.Forms.Panel
  $relationGraphViewport.Location = New-Object System.Drawing.Point(35, ($relationRowY + 54))
  $relationGraphViewport.Size = New-Object System.Drawing.Size(($FormLayout.Width - 70), 340)
  $relationGraphViewport.BackColor = [System.Drawing.Color]::White
  $relationGraphViewport.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
  $relationGraphViewport.AutoScroll = $true
  $relationGraphViewport.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
  $relationGraphCanvas = New-Object System.Windows.Forms.Panel
  $relationGraphCanvas.Location = New-Object System.Drawing.Point(0, 0)
  $relationGraphCanvas.Size = $relationGraphViewport.ClientSize
  $relationGraphCanvas.BackColor = [System.Drawing.Color]::White
  $relationGraphCanvas.Add_Paint({
    param($sender, $eventArgs)
    Draw-RelationGraph $eventArgs.Graphics
  })
  $relationGraphViewport.Controls.Add($relationGraphCanvas)
  $relationGraphViewport.Add_Resize({
    if (-not $script:relationGraphData) {
      $relationGraphCanvas.Size = $relationGraphViewport.ClientSize
    }
  })
  $form.Controls.Add($relationGraphViewport)
  $script:relationGraphData = $null

  $diagramRowY = 43 + $tabBarHeight
  $diagramProjectLabel = New-Label 'Local' 500 ($diagramRowY + 3) 50 22
  $diagramProjectBox = New-Object System.Windows.Forms.TextBox
  $diagramProjectBox.Location = New-Object System.Drawing.Point(552, $diagramRowY)
  $diagramProjectBox.Size = New-Object System.Drawing.Size(260, 26)
  $diagramProjectBox.Text = [string]$script:sectionFolders['runlocal']
  $diagramProjectBox.ReadOnly = $true
  $diagramProjectBox.AccessibleName = 'Local'
  $form.Controls.Add($diagramProjectBox)
  $diagramProjectBrowseButton = New-Object System.Windows.Forms.Button
  $diagramRepoBrowseButton = New-Object System.Windows.Forms.Button
  $diagramProjectBrowseButton.Location = New-Object System.Drawing.Point(820, $diagramRowY)
  $diagramProjectBrowseButton.Size = New-Object System.Drawing.Size(30, 26)
  $diagramProjectBrowseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $diagramProjectBrowseButton.FlatAppearance.BorderSize = 0
  $diagramProjectBrowseButton.BackColor = [System.Drawing.Color]::White
  $diagramProjectBrowseButton.ForeColor = Get-FormColor $FormLayout.AccentColor
  $diagramProjectBrowseButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $diagramProjectBrowseButton.Text = [string][char]0xE721
  $diagramProjectBrowseButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $diagramProjectBrowseButton.AccessibleName = 'Browse for a local Project folder'
  $diagramProjectBrowseButton.Tag = 'noButtonSound'
  $toolTip.SetToolTip($diagramProjectBrowseButton, 'Browse for a local folder on this PC')
  $form.Controls.Add($diagramProjectBrowseButton)
  $diagramPageLabel = New-Label 'Repo' 37 ($diagramRowY + 3) 50 22
  $diagramPageBox = New-Object System.Windows.Forms.TextBox
  $diagramPageBox.Location = New-Object System.Drawing.Point(98, $diagramRowY)
  $diagramPageBox.Size = New-Object System.Drawing.Size(260, 26)
  $diagramPageBox.Text = $script:defaultRepositoryUrl
  $diagramPageBox.ReadOnly = $true
  $diagramPageBox.AccessibleName = 'Repository URL'
  $diagramPageBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
  $script:diagramPageBox = $diagramPageBox
  $script:diagramBrowseRepoPath = ''
  $script:diagramLocalPagePath = ''
  $form.Controls.Add($diagramPageBox)
  $diagramRepoBrowseButton.Location = New-Object System.Drawing.Point(366, $diagramRowY)
  $diagramRepoBrowseButton.Size = New-Object System.Drawing.Size(30, 26)
  $diagramRepoBrowseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $diagramRepoBrowseButton.FlatAppearance.BorderSize = 0
  $diagramRepoBrowseButton.BackColor = [System.Drawing.Color]::White
  $diagramRepoBrowseButton.ForeColor = Get-FormColor $FormLayout.AccentColor
  $diagramRepoBrowseButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $diagramRepoBrowseButton.Text = [string][char]0xE721
  $diagramRepoBrowseButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $diagramRepoBrowseButton.AccessibleName = 'Choose a connected GitHub repository'
  $diagramRepoBrowseButton.Tag = 'noButtonSound'
  $toolTip.SetToolTip($diagramRepoBrowseButton, 'Choose a connected GitHub repository')
  $form.Controls.Add($diagramRepoBrowseButton)

  $diagramBrowsePathLabel = New-Label '' 37 ($diagramRowY + 75) ($FormLayout.Width - 75) 22
  $diagramBrowsePathLabel.AutoEllipsis = $true
  $diagramFileList = New-Object System.Windows.Forms.ListView
  $diagramFileList.Location = New-Object System.Drawing.Point(37, ($diagramRowY + 100))
  $diagramFileList.Size = New-Object System.Drawing.Size(225, 112)
  $diagramFileList.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
  $diagramFileList.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $diagramFileList.View = [System.Windows.Forms.View]::Details
  $diagramFileList.Scrollable = $true
  $diagramFileList.FullRowSelect = $true
  $diagramFileList.HideSelection = $false
  $diagramFileList.MultiSelect = $false
  $diagramFileList.Columns.Add('Name', 170) | Out-Null
  $diagramFileList.Columns.Add('Type', 55) | Out-Null
  $form.Controls.Add($diagramFileList)
  $diagramLocalButton = New-Object System.Windows.Forms.Button
  $diagramLocalButton.Text = 'Local'
  $diagramRepoButton = New-Object System.Windows.Forms.Button
  $diagramRepoButton.Text = 'Repo'
  $diagramBackButton = New-Object System.Windows.Forms.Button
  $diagramBackButton.Text = '←'
  $diagramButtonIndex = 0
  foreach ($buttonInfo in @(
      @{ Control = $diagramLocalButton; Name = 'Choose a local folder' },
      @{ Control = $diagramRepoButton; Name = 'Choose a connected repository' },
      @{ Control = $diagramBackButton; Name = 'Go to parent folder' }
    )) {
    $button = $buttonInfo.Control
    $button.Location = New-Object System.Drawing.Point(270, ($diagramRowY + 100 + (32 * $diagramButtonIndex)))
    $button.Size = New-Object System.Drawing.Size(92, 26)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = [System.Drawing.Color]::White
    $button.ForeColor = Get-FormColor $FormLayout.AccentColor
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.Tag = 'noButtonSound'
    $button.AccessibleName = $buttonInfo.Name
    $toolTip.SetToolTip($button, $buttonInfo.Name)
    $form.Controls.Add($button)
    $diagramButtonIndex++
  }
  $diagramBackButton.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 12, [System.Drawing.FontStyle]::Bold)
  $diagramEditorStatusLabel = New-Label 'Select a text file to view or edit it.' 37 ($diagramRowY + 218) ($FormLayout.Width - 75) 20
  $diagramEditorStatusLabel.AutoEllipsis = $true
  $script:diagramEditorStatusLabel = $diagramEditorStatusLabel
  $diagramLineNumberGutter = New-Object System.Windows.Forms.Panel
  $diagramLineNumberGutter.Location = New-Object System.Drawing.Point(37, ($diagramRowY + 240))
  $diagramLineNumberGutter.Size = New-Object System.Drawing.Size(42, 156)
  $diagramLineNumberGutter.BackColor = [System.Drawing.Color]::FromArgb(238, 241, 245)
  $diagramLineNumberGutter.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
  $form.Controls.Add($diagramLineNumberGutter)
  $diagramFileEditor = New-Object System.Windows.Forms.RichTextBox
  $diagramFileEditor.Location = New-Object System.Drawing.Point(79, ($diagramRowY + 240))
  $diagramFileEditor.Size = New-Object System.Drawing.Size(($FormLayout.Width - 120), 156)
  $diagramFileEditor.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
  $diagramFileEditor.AcceptsTab = $true
  $diagramFileEditor.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both
  $diagramFileEditor.WordWrap = $false
  $diagramFileEditor.Font = New-Object System.Drawing.Font('Nirmala UI', 9)
  $form.Controls.Add($diagramFileEditor)
  $diagramFileGrid = New-Object System.Windows.Forms.DataGridView
  $diagramFileGrid.Location = New-Object System.Drawing.Point(37, ($diagramRowY + 240))
  $diagramFileGrid.Size = New-Object System.Drawing.Size(($FormLayout.Width - 79), 156)
  $diagramFileGrid.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
  $diagramFileGrid.BackgroundColor = [System.Drawing.Color]::White
  $diagramFileGrid.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
  $diagramFileGrid.RowHeadersVisible = $true
  $diagramFileGrid.RowHeadersWidth = 48
  $diagramFileGrid.AllowUserToAddRows = $true
  $diagramFileGrid.AllowUserToDeleteRows = $true
  $diagramFileGrid.AllowUserToResizeRows = $false
  $diagramFileGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
  $diagramFileGrid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
  $diagramFileGrid.EnableHeadersVisualStyles = $false
  $diagramFileGrid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(238, 241, 245)
  $diagramFileGrid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
  $diagramFileGrid.DefaultCellStyle.Font = New-Object System.Drawing.Font('Nirmala UI', 9)
  $diagramFileGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Nirmala UI', 9)
  $diagramFileGrid.RowHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $diagramFileGrid.RowHeadersDefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleRight
  $diagramFileGrid.Visible = $false
  $form.Controls.Add($diagramFileGrid)
  $diagramColumnMenu = New-Object System.Windows.Forms.ContextMenuStrip
  $addDiagramColumnItem = $diagramColumnMenu.Items.Add('Add column')
  $removeDiagramColumnItem = $diagramColumnMenu.Items.Add('Delete column')
  $diagramFileGrid.ContextMenuStrip = $diagramColumnMenu
  $diagramFileGrid.Add_MouseDown({
    param($sender, $eventArgs)
    if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
      $hit = $sender.HitTest($eventArgs.X, $eventArgs.Y)
      if ($hit.Type -eq [System.Windows.Forms.DataGridViewHitTestType]::ColumnHeader) {
        $script:diagramColumnMenuIndex = $hit.ColumnIndex
      } else {
        $script:diagramColumnMenuIndex = -1
      }
    }
  })
  $addDiagramColumnItem.Add_Click({ Add-DiagramGridColumn $script:diagramColumnMenuIndex })
  $removeDiagramColumnItem.Add_Click({ Remove-DiagramGridColumn $script:diagramColumnMenuIndex })
  $diagramColumnMenu.Add_Opening({
    $removeDiagramColumnItem.Enabled = $diagramFileGrid.Columns.Count -gt 1
  })
  $diagramFileGrid.Add_RowPostPaint({
    param($sender, $eventArgs)
    if (-not $sender.Rows[$eventArgs.RowIndex].IsNewRow) {
      $bounds = New-Object System.Drawing.Rectangle(
        $eventArgs.RowBounds.X,
        $eventArgs.RowBounds.Y,
        ($sender.RowHeadersWidth - 6),
        $eventArgs.RowBounds.Height
      )
      [System.Windows.Forms.TextRenderer]::DrawText(
        $eventArgs.Graphics,
        [string]($eventArgs.RowIndex + 1),
        $sender.RowHeadersDefaultCellStyle.Font,
        $bounds,
        $sender.RowHeadersDefaultCellStyle.ForeColor,
        ([System.Windows.Forms.TextFormatFlags]::Right -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)
      )
    }
  })
  $diagramFileGrid.Add_CellValueChanged({
    Update-DiagramEditorStatus
    Request-FormStateSave
  })
  $diagramFileGrid.Add_RowsRemoved({
    if (-not $script:diagramEditorLoading) { Set-DiagramGridHeaderRow }
    Update-DiagramEditorStatus
    Request-FormStateSave
  })
  $diagramFileGrid.Add_RowsAdded({
    if (-not $script:diagramEditorLoading) { Set-DiagramGridHeaderRow }
    Update-DiagramEditorStatus
    Request-FormStateSave
  })
  $diagramFileGrid.Add_ColumnRemoved({ Update-DiagramEditorStatus })
  $diagramLineNumberGutter.Add_Paint({
    param($sender, $eventArgs)
    $eventArgs.Graphics.Clear($sender.BackColor)
    $eventArgs.Graphics.DrawLine([System.Drawing.Pens]::Silver, ($sender.Width - 1), 0, ($sender.Width - 1), $sender.Height)
    if (-not $diagramFileEditor.IsHandleCreated -or $diagramFileEditor.Lines.Count -eq 0) {
      return
    }
    $firstVisibleChar = $diagramFileEditor.GetCharIndexFromPosition((New-Object System.Drawing.Point(1, 1)))
    $firstVisibleLine = [Math]::Max(0, $diagramFileEditor.GetLineFromCharIndex($firstVisibleChar))
    for ($line = $firstVisibleLine; $line -lt $diagramFileEditor.Lines.Count; $line++) {
      $charIndex = $diagramFileEditor.GetFirstCharIndexFromLine($line)
      if ($charIndex -lt 0) {
        continue
      }
      $position = $diagramFileEditor.GetPositionFromCharIndex($charIndex)
      if ($position.Y -ge $sender.Height) {
        break
      }
      if ($position.Y -ge -$diagramFileEditor.Font.Height) {
        $number = ($line + 1).ToString()
        $size = $eventArgs.Graphics.MeasureString($number, $diagramFileEditor.Font)
        $eventArgs.Graphics.DrawString(
          $number,
          $diagramFileEditor.Font,
          [System.Drawing.SystemBrushes]::ControlDarkDark,
          ($sender.Width - $size.Width - 7),
          $position.Y
        )
      }
    }
  })
  $diagramFileEditor.Add_VScroll({ $diagramLineNumberGutter.Invalidate() })
  $diagramFileEditor.Add_Resize({ $diagramLineNumberGutter.Invalidate() })
  $diagramPageSaveButton = New-Object System.Windows.Forms.Button
  $diagramPageSaveButton.Text = [string][char]0xE73E
  $diagramPageSaveButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $diagramPageSaveButton.Location = New-Object System.Drawing.Point(796, ($diagramRowY + 212))
  $diagramPageSaveButton.Size = New-Object System.Drawing.Size(30, 26)
  $diagramPageSaveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $diagramPageSaveButton.FlatAppearance.BorderSize = 0
  $diagramPageSaveButton.BackColor = [System.Drawing.Color]::White
  $diagramPageSaveButton.ForeColor = Get-FormColor $FormLayout.AccentColor
  $diagramPageSaveButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $diagramPageSaveButton.AccessibleName = 'Save file changes'
  $diagramPageSaveButton.Tag = 'noButtonSound'
  $toolTip.SetToolTip($diagramPageSaveButton, 'Save locally or commit the opened repository file to GitHub')
  $form.Controls.Add($diagramPageSaveButton)
  $diagramSearchBox = New-Object System.Windows.Forms.TextBox
  $diagramSearchBox.Location = New-Object System.Drawing.Point(500, ($diagramRowY + 212))
  $diagramSearchBox.Size = New-Object System.Drawing.Size(166, 26)
  $diagramSearchBox.AccessibleName = 'Search in the open file'
  $toolTip.SetToolTip($diagramSearchBox, 'Search in the open sheet or text file, then press Enter')
  $form.Controls.Add($diagramSearchBox)
  $script:diagramSearchBox = $diagramSearchBox
  $diagramSearchButton = New-Object System.Windows.Forms.Button
  $diagramUndoButton = New-Object System.Windows.Forms.Button
  $diagramRedoButton = New-Object System.Windows.Forms.Button
  $diagramRefreshButton = New-Object System.Windows.Forms.Button
  $diagramImportButton = New-Object System.Windows.Forms.Button
  $diagramExportButton = New-Object System.Windows.Forms.Button
  $script:diagramUndoButton = $diagramUndoButton
  $script:diagramRedoButton = $diagramRedoButton
  $script:diagramGridHistory = New-Object 'System.Collections.Generic.List[object]'
  $script:diagramGridHistoryIndex = -1
  foreach ($buttonInfo in @(
      @{ Control = $diagramSearchButton; Glyph = 0xE721; Name = 'Search in file'; X = 668 },
      @{ Control = $diagramUndoButton; Glyph = 0xE7A7; Name = 'Undo sheet edit'; X = 700 },
      @{ Control = $diagramRedoButton; Glyph = 0xE7A6; Name = 'Redo sheet edit'; X = 732 },
      @{ Control = $diagramRefreshButton; Glyph = 0xE72C; Name = 'Refresh file or folder'; X = 764 },
      @{ Control = $diagramImportButton; Glyph = 0xE8B5; Name = 'Import Excel workbook'; X = 852 },
      @{ Control = $diagramExportButton; Glyph = 0xE8B6; Name = 'Export sheet to Excel'; X = 892 }
    )) {
    $button = $buttonInfo.Control
    $button.Text = [string][char]$buttonInfo.Glyph
    $button.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
    $button.Location = New-Object System.Drawing.Point($buttonInfo.X, ($diagramRowY + 212))
    $button.Size = New-Object System.Drawing.Size(30, 26)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = [System.Drawing.Color]::White
    $button.ForeColor = Get-FormColor $FormLayout.AccentColor
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.AccessibleName = $buttonInfo.Name
    $button.Tag = 'noButtonSound'
    $toolTip.SetToolTip($button, $buttonInfo.Name)
    $form.Controls.Add($button)
  }
  Update-DiagramGridHistoryButtons
  $diagramEditorStatusLabel.Location = New-Object System.Drawing.Point(37, ($diagramRowY + 214))
  $diagramEditorStatusLabel.Size = New-Object System.Drawing.Size(455, 22)
  $diagramSearchButton.Add_Click({ Find-DiagramGridText })
  $diagramSearchBox.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
      $eventArgs.SuppressKeyPress = $true
      Find-DiagramGridText
    }
  })
  $diagramUndoButton.Add_Click({ Invoke-DiagramGridHistory 'Undo' })
  $diagramRedoButton.Add_Click({ Invoke-DiagramGridHistory 'Redo' })
  $diagramRefreshButton.Add_Click({
    try {
      if ($script:diagramEditorRemoteFile) {
        $remote = $script:diagramEditorRemoteFile
        [void](Open-DiagramRepositoryFile ([pscustomobject]@{ Type = 'file'; Path = $remote.Path }))
      } elseif ($script:diagramEditorLoadedPath -and $script:diagramBrowseSource -ne 'repo') {
        if (Confirm-DiagramEditorCanChangeFile) {
          $path = $script:diagramEditorLoadedPath
          $script:diagramEditorLoadedPath = $null
          [void](Load-DiagramEditorFile $path)
        }
      } elseif ($script:diagramBrowseSource -eq 'repo') {
        Update-DiagramRepositoryFileList
      } else {
        Update-DiagramFileList
      }
    } catch {
      $script:diagramEditorStatusLabel.Text = $_.Exception.Message
      $script:diagramEditorStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick
    }
  })
  $diagramImportButton.Add_Click({ Import-DiagramXlsxFile })
  $diagramExportButton.Add_Click({
    try {
      Export-DiagramCurrentSheet
    } catch {
      [void][System.Windows.Forms.MessageBox]::Show(
        $form, $_.Exception.Message, 'Export Excel workbook',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
      )
    }
  })
  $script:diagramEditorLoadedPath = $null
  $script:diagramEditorOriginalText = ''
  $script:diagramEditorRemoteFile = $null
  $diagramFileGrid.Add_CellValueChanged({
    Update-DiagramEditorStatus
    Record-DiagramGridHistory
  })
  $diagramFileGrid.Add_RowsRemoved({
    if (-not $script:diagramEditorLoading) { Set-DiagramGridHeaderRow }
    Update-DiagramEditorStatus
    Record-DiagramGridHistory
  })
  $diagramFileGrid.Add_RowsAdded({
    if (-not $script:diagramEditorLoading) { Set-DiagramGridHeaderRow }
    Update-DiagramEditorStatus
    Record-DiagramGridHistory
  })
  $diagramFileEditor.Add_TextChanged({
    $diagramLineNumberGutter.Invalidate()
    Update-DiagramEditorStatus
    Request-FormStateSave
  })
  $diagramSearchBox.Add_TextChanged({ Request-FormStateSave })
  $diagramPageSaveButton.Add_Click({
    try {
      if ($script:diagramEditorRemoteFile) {
        [void](Save-DiagramRepositoryFile)
      } elseif ($script:diagramBrowseSource -eq 'repo') {
        throw 'Select and open a repository file before saving.'
      } else {
        if (-not $script:diagramLocalPagePath) {
          throw 'Select a local file from the list before saving.'
        }
        $path = Get-DiagramPageFilePath $script:diagramLocalPagePath
        if (-not (Load-DiagramEditorFile $path)) {
          return
        }
        Save-DiagramEditorFile $path
      }
    } catch {
      [void][System.Windows.Forms.MessageBox]::Show(
        $form, $_.Exception.Message, 'Save file',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
      )
    }
  })
  $diagramProjectBrowseButton.Add_Click({ Browse-DiagramProjectFolder })
  $diagramLocalButton.Add_Click({
    try {
      Set-DiagramBrowseSource 'local'
      $localRoot = [IO.Path]::GetFullPath($diagramProjectBox.Text.Trim())
      if (-not (Test-Path -LiteralPath $localRoot -PathType Container)) {
        throw "Local folder not found: $localRoot"
      }
      $script:diagramBrowseDirectory = $localRoot
      Update-DiagramFileList
    } catch {
      $diagramBrowsePathLabel.Text = $_.Exception.Message
    }
  })
  $diagramRepoBrowseButton.Add_Click({
    Show-RepoPicker -Box $diagramPageBox -Button $diagramRepoBrowseButton -Status {
      param($Text, $Kind)
      if ($Kind -eq 'success') {
        $script:diagramBrowseRepoPath = ''
        try {
          Update-DiagramRepositoryFileList
          Request-FormStateSave
        } catch {
          Set-ColoredStatus $diagramBrowsePathLabel $_.Exception.Message 'error'
        }
      } else {
        Set-ColoredStatus $diagramBrowsePathLabel $Text $Kind
      }
    }
  })
  $diagramRepoButton.Add_Click({
    try {
      $wasBrowsingRepo = $script:diagramBrowseSource -eq 'repo'
      Set-DiagramBrowseSource 'repo'
      if (-not $wasBrowsingRepo) {
        $script:diagramBrowseRepoPath = ''
      }
      Update-DiagramRepositoryFileList
    } catch {
      Set-ColoredStatus $diagramBrowsePathLabel $_.Exception.Message 'error'
    }
  })
  $diagramFileList.Add_SelectedIndexChanged({
    if ($script:formStateRestoring) { return }
    if ($diagramFileList.SelectedItems.Count -eq 0) {
      return
    }
    $selected = $diagramFileList.SelectedItems[0]
    if ($script:diagramBrowseSource -eq 'repo') {
      if ([string]$selected.Tag.Type -eq 'file') {
        try {
          [void](Open-DiagramRepositoryFile $selected.Tag)
        } catch {
          $script:diagramEditorStatusLabel.Text = $_.Exception.Message
          $script:diagramEditorStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick
        }
      } else {
        $script:diagramEditorStatusLabel.Text = "Repository folder selected: $($selected.Tag.Path)"
        Request-FormStateSave
      }
      return
    }
    if (Test-Path -LiteralPath ([string]$selected.Tag) -PathType Leaf) {
      try {
        if (Load-DiagramEditorFile ([string]$selected.Tag)) {
          $script:diagramLocalPagePath = Get-DiagramRelativePagePath $diagramProjectBox.Text ([string]$selected.Tag)
          Request-FormStateSave
        }
      } catch {
        $diagramBrowsePathLabel.Text = $_.Exception.Message
      }
    } else {
      Request-FormStateSave
    }
  })
  $diagramFileList.Add_DoubleClick({ Enter-DiagramSelectedFolder })
  $script:diagramBrowseDirectory = [IO.Path]::GetFullPath($diagramProjectBox.Text)
  $diagramProjectBox.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
      $eventArgs.SuppressKeyPress = $true
      try {
        $script:diagramBrowseDirectory = [IO.Path]::GetFullPath($diagramProjectBox.Text.Trim())
        Update-DiagramFileList
      } catch {
        $diagramBrowsePathLabel.Text = $_.Exception.Message
      }
    }
  })
  $diagramBackButton.Add_Click({
    try { Set-DiagramParentDirectory } catch { $diagramBrowsePathLabel.Text = $_.Exception.Message }
  })
  try {
    Update-DiagramFileList
  } catch {
    $diagramBrowsePathLabel.Text = $_.Exception.Message
  }

  # Home tab: an empty box that belongs to the form only (fill it here if needed).
  $homePanel = New-FormSectionPanel 'home' -BelowBars
  $homePanel.BringToFront()
  $homeRefreshButton = New-Object System.Windows.Forms.Button
  $homeRefreshButton.Text = [string][char]0xE72C
  $homeRefreshButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $homeRefreshButton.Location = New-Object System.Drawing.Point(($homePanel.Width - 46), 3)
  $homeRefreshButton.Size = New-Object System.Drawing.Size(32, 28)
  $homeRefreshButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $homeRefreshButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $toolTip.SetToolTip($homeRefreshButton, 'Refresh the list of files and folders')
  $homePanel.Controls.Add($homeRefreshButton)
  $homeRefreshButton.BringToFront()
  $homeRefreshButton.Add_Click({ Update-HomeFiles })
  # Tick all / none (left of refresh): ticks or clears every item's Upload box.
  $homeCheckAll = New-Object System.Windows.Forms.CheckBox
  $homeCheckAll.Text = 'All'
  $homeCheckAll.Tag = 'noUndo'
  $homeCheckAll.AutoSize = $true
  $homeCheckAll.Location = New-Object System.Drawing.Point(($homePanel.Width - 98), 8)
  $homeCheckAll.ForeColor = [System.Drawing.Color]::FromArgb(64, 52, 126)
  $homeCheckAll.Cursor = [System.Windows.Forms.Cursors]::Hand
  $toolTip.SetToolTip($homeCheckAll, 'Tick all / clear all (Upload column)')
  $homePanel.Controls.Add($homeCheckAll)
  $homeCheckAll.BringToFront()
  $homeCheckAll.Add_Click({
    # Not everything ticked yet -> tick all; everything ticked -> clear all.
    $tickable = @($homeFileList.Items | Where-Object { $_.Name -ne '.git' }).Count
    Set-HomeCheckedAll ($script:homeChecked.Count -lt $tickable)
  })

  # Home box: files and folders of the Folder field (double-click opens one).
  $homeFileList = New-Object System.Windows.Forms.ListView
  $homeFileList.Location = New-Object System.Drawing.Point(14, 42)
  $homeFileList.Size = New-Object System.Drawing.Size(($homePanel.Width - 28), ($homePanel.Height - 54))
  $homeFileList.View = [System.Windows.Forms.View]::Details
  $homeFileList.FullRowSelect = $true
  $homeFileList.HideSelection = $false
  $homeFileList.ShowItemToolTips = $true
  $homeFileList.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  [void]$homeFileList.Columns.Add('Name', 380)
  [void]$homeFileList.Columns.Add('Type', 130)
  [void]$homeFileList.Columns.Add('Size', 110, [System.Windows.Forms.HorizontalAlignment]::Right)
  [void]$homeFileList.Columns.Add('Modified', 180)
  [void]$homeFileList.Columns.Add('Upload', 60, [System.Windows.Forms.HorizontalAlignment]::Center)
  $homePanel.Controls.Add($homeFileList)

  # Right-hand "Upload" column: a tick box per file/folder. Only ticked items are
  # uploaded by the URL row's upload button (none ticked = the whole folder).
  # Click the "Upload" header to tick or clear all.
  $script:homeChecked = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  $homeUploadColumn = 4
  $homeFileList.OwnerDraw = $true
  $homeFileList.Add_DrawColumnHeader({
    param($sender, $eventArgs)
    $eventArgs.DrawDefault = $true
  })
  $homeFileList.Add_DrawItem({
    param($sender, $eventArgs)
    $eventArgs.DrawDefault = $false
  })
  $homeFileList.Add_DrawSubItem({
    param($sender, $eventArgs)
    if ($eventArgs.ColumnIndex -ne $homeUploadColumn) {
      $eventArgs.DrawDefault = $true
      return
    }
    $bounds = $eventArgs.Bounds
    if ($eventArgs.Item.Selected) {
      $eventArgs.Graphics.FillRectangle([System.Drawing.SystemBrushes]::Highlight, $bounds)
    } else {
      $eventArgs.Graphics.FillRectangle([System.Drawing.Brushes]::White, $bounds)
    }
    if ($eventArgs.Item.Name -eq '.git') {
      return
    }
    $state = if ($script:homeChecked.Contains([string]$eventArgs.Item.Tag)) { [System.Windows.Forms.VisualStyles.CheckBoxState]::CheckedNormal } else { [System.Windows.Forms.VisualStyles.CheckBoxState]::UncheckedNormal }
    $box = [System.Windows.Forms.CheckBoxRenderer]::GetGlyphSize($eventArgs.Graphics, $state)
    $point = New-Object System.Drawing.Point(($bounds.X + [int](($bounds.Width - $box.Width) / 2)), ($bounds.Y + [int](($bounds.Height - $box.Height) / 2)))
    [System.Windows.Forms.CheckBoxRenderer]::DrawCheckBox($eventArgs.Graphics, $point, $state)
  })
  $homeFileList.Add_MouseClick({
    param($sender, $eventArgs)
    $hit = $homeFileList.HitTest($eventArgs.Location)
    if (-not $hit.Item -or -not $hit.SubItem) {
      return
    }
    if ($hit.Item.SubItems.IndexOf($hit.SubItem) -eq $homeUploadColumn) {
      Switch-HomeChecked $hit.Item
    }
  })
  $homeFileList.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Space) {
      $eventArgs.SuppressKeyPress = $true
      foreach ($item in @($homeFileList.SelectedItems)) {
        Switch-HomeChecked $item
      }
    }
  })
  $homeFileList.Add_ColumnClick({
    param($sender, $eventArgs)
    if ($eventArgs.Column -ne $homeUploadColumn) {
      return
    }
    $items = @($homeFileList.Items | Where-Object { $_.Name -ne '.git' })
    $all = @($items | Where-Object { -not $script:homeChecked.Contains([string]$_.Tag) }).Count -eq 0
    $before = @($script:homeChecked)
    foreach ($item in $items) {
      if ($all) { [void]$script:homeChecked.Remove([string]$item.Tag) } else { [void]$script:homeChecked.Add([string]$item.Tag) }
    }
    Add-UndoAction 'ticks' 'Upload ticks' @{ Old = $before; New = @($script:homeChecked) }
    $homeFileList.Invalidate()
    Update-HomeCheckedStatus
  })
  $homeFileList.Add_DoubleClick({
    $item = $homeFileList.SelectedItems | Select-Object -First 1
    if (-not $item) {
      return
    }
    try {
      Start-Process -FilePath ([string]$item.Tag) -ErrorAction Stop | Out-Null
    } catch {
      Set-HomeStatus ('Could not open: ' + $_.Exception.Message) 'error'
    }
  })

  # Home: GitHub repository row at the top (link + Upload / Download / Copy);
  # on Home the folder bar moves to the row below it (see Update-FolderBar).
  $homeRowY = 42 + $tabBarHeight
  $homeRepoLabel = New-Label 'URL :' 37 ($homeRowY + 6) ($FormLayout.HomeFieldLeft - 40) 22
  $homeRepoLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
  $homeRepoLabel.ForeColor = Get-FormColor $FormLayout.AccentColor
  $homeRepoBox = New-Object System.Windows.Forms.TextBox
  $homeRepoBox.Location = New-Object System.Drawing.Point($FormLayout.HomeFieldLeft, ($homeRowY + 3))
  $homeRepoBox.Size = New-Object System.Drawing.Size(($FormLayout.Width - 228 - $FormLayout.HomeFieldLeft), 26)
  $homeRepoBox.Text = $script:defaultRepositoryUrl
  $homeRepoBox.ReadOnly = $true
  $form.Controls.Add($homeRepoBox)
  $toolTip.SetToolTip($homeRepoBox, 'Choose a repository with the search button')
  # Upload sits in the Folder row (after copy); it uploads that folder to the URL above.
  $homeUploadButton = New-ActionButton 'Upload this folder to the GitHub repository in the URL box' 0xE898 ($FormLayout.Width - 142) ($homeRowY + 1 + $FormLayout.FolderBarHeight)
  $homeDownloadButton = New-ActionButton 'Download: put this GitHub repository''s files into the folder below' 0xE896 ($FormLayout.Width - 142) ($homeRowY + 1)
  $homeCopyButton = New-ActionButton 'Copy this GitHub repository link' 0xE8C8 ($FormLayout.Width - 104) ($homeRowY + 1)
  $homeCleanButton = New-ActionButton 'Clean the repository: delete all its files on GitHub' 0xE74D ($FormLayout.Width - 66) ($homeRowY + 1)
  $homeCleanButton.ForeColor = [System.Drawing.Color]::Firebrick
  $homeCleanButton.Add_Click({ Invoke-HomeRepoAction 'clean' })
  # Folder row (Home): delete the ticked files/folders of the local folder.
  $homeLocalDeleteButton = New-ActionButton 'Delete the ticked files and folders from this folder (to the Recycle Bin)' 0xE74D ($FormLayout.Width - 66) ($homeRowY + 1 + $FormLayout.FolderBarHeight)
  $homeLocalDeleteButton.ForeColor = [System.Drawing.Color]::Firebrick
  $homeLocalDeleteButton.Add_Click({ Remove-HomeCheckedItems })
  $homeOpenButton = New-ActionButton 'Open this link in Chrome' 0xE8A7 ($FormLayout.Width - 180) ($homeRowY + 1)
  $homeOpenButton.Add_Click({ Open-HomeRepoInChrome })
  $homeRepoSearchButton = New-ActionButton "Choose one of the account's GitHub repositories" 0xE721 ($FormLayout.Width - 218) ($homeRowY + 1)
  $homeRepoSearchButton.Add_Click({
    if ($homeRepoPickerForm.Visible) { Hide-HomeRepoDropDown } else { $script:repoPickTarget = $null; Select-HomeRepository }
  })

  # Shared repository-picker popup for the URL search buttons.
  $homeRepoPickerForm = New-Object System.Windows.Forms.Form
  $homeRepoPickerForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $homeRepoPickerForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $homeRepoPickerForm.ShowInTaskbar = $false
  $homeRepoPickerForm.ControlBox = $false
  $homeRepoPickerForm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
  $homeRepoPickerForm.BackColor = [System.Drawing.Color]::White
  $homeRepoDropDown = New-Object System.Windows.Forms.Panel
  $homeRepoDropDown.Location = New-Object System.Drawing.Point(0, 0)
  $homeRepoDropDown.Size = New-Object System.Drawing.Size(($FormLayout.Width - 38 - $FormLayout.HomeFieldLeft), 320)
  $homeRepoDropDown.BackColor = [System.Drawing.Color]::White
  $homeRepoDropDown.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
  $homeRepoDropDown.Visible = $false
  $homeRepoPickerForm.ClientSize = $homeRepoDropDown.Size
  $homeRepoPickerForm.Controls.Add($homeRepoDropDown)
  $homeRepoFilter = New-Object System.Windows.Forms.TextBox
  $homeRepoFilter.Location = New-Object System.Drawing.Point(6, 6)
  $homeRepoFilter.Size = New-Object System.Drawing.Size(($homeRepoDropDown.Width - 48), 24)
  $homeRepoFilter.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $homeRepoDropDown.Controls.Add($homeRepoFilter)
  $toolTip.SetToolTip($homeRepoFilter, 'Type to filter; Enter picks the selected repository, Esc closes the list')
  $homeRepoClose = New-Object System.Windows.Forms.Button
  $homeRepoClose.Text = [string][char]0xE711
  $homeRepoClose.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 9)
  $homeRepoClose.Location = New-Object System.Drawing.Point(($homeRepoDropDown.Width - 38), 4)
  $homeRepoClose.Size = New-Object System.Drawing.Size(30, 26)
  $homeRepoClose.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $homeRepoDropDown.Controls.Add($homeRepoClose)
  $toolTip.SetToolTip($homeRepoClose, 'Close the list')
  $homeRepoClose.Add_Click({ Hide-HomeRepoDropDown })
  $homeRepoListView = New-Object System.Windows.Forms.ListView
  $homeRepoListView.Location = New-Object System.Drawing.Point(6, 36)
  $homeRepoListView.Size = New-Object System.Drawing.Size(($homeRepoDropDown.Width - 14), ($homeRepoDropDown.Height - 44))
  $homeRepoListView.View = [System.Windows.Forms.View]::Details
  $homeRepoListView.FullRowSelect = $true
  $homeRepoListView.MultiSelect = $false
  $homeRepoListView.HideSelection = $false
  $homeRepoListView.ShowItemToolTips = $true
  $homeRepoListView.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  [void]$homeRepoListView.Columns.Add('Repository', 250)
  [void]$homeRepoListView.Columns.Add('Visibility', 70)
  [void]$homeRepoListView.Columns.Add('Updated', 140)
  [void]$homeRepoListView.Columns.Add('Description', 250)
  $homeRepoDropDown.Controls.Add($homeRepoListView)
  $homeRepoFilter.Add_TextChanged({ Update-HomeRepoDropDown })
  $homeRepoFilter.Add_KeyDown({
    param($sender, $eventArgs)
    switch ($eventArgs.KeyCode) {
      'Down' {
        $eventArgs.SuppressKeyPress = $true
        if ($homeRepoListView.Items.Count -gt 0) {
          $homeRepoListView.Focus()
          if ($homeRepoListView.SelectedItems.Count -eq 0) { $homeRepoListView.Items[0].Selected = $true }
        }
      }
      'Enter' {
        $eventArgs.SuppressKeyPress = $true
        if ($homeRepoListView.SelectedItems.Count -eq 0 -and $homeRepoListView.Items.Count -gt 0) { $homeRepoListView.Items[0].Selected = $true }
        Use-HomeRepoSelection
      }
      'Escape' {
        $eventArgs.SuppressKeyPress = $true
        Hide-HomeRepoDropDown
      }
    }
  })
  $homeRepoListView.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.KeyCode -eq 'Enter') { $eventArgs.SuppressKeyPress = $true; Use-HomeRepoSelection }
    elseif ($eventArgs.KeyCode -eq 'Escape') { $eventArgs.SuppressKeyPress = $true; Hide-HomeRepoDropDown }
  })
  $homeRepoListView.Add_MouseClick({ Use-HomeRepoSelection })
  $homeStatusLabel = New-Label '' 37 ($homePanel.Bottom + 8) ($FormLayout.Width - 80) 24
  $homeStatusLabel.AutoEllipsis = $true
  foreach ($control in @($homeRepoLabel, $homeRepoBox, $homeUploadButton, $homeDownloadButton, $homeCopyButton, $homeCleanButton, $homeLocalDeleteButton, $homeOpenButton, $homeRepoSearchButton, $homeStatusLabel)) {
    $control.BringToFront()
  }
  $homeCopyButton.Add_Click({
    $text = $homeRepoBox.Text.Trim()
    if (-not $text) {
      Set-HomeStatus 'There is no GitHub repository link to copy.' 'error'
      return
    }
    try {
      [System.Windows.Forms.Clipboard]::SetText($text)
      Set-HomeStatus "GitHub repository link copied: $text" 'success'
    } catch {
      Set-HomeStatus ('Could not copy: ' + $_.Exception.Message) 'error'
    }
  })
  $homeUploadButton.Add_Click({ Invoke-HomeRepoAction 'upload' })
  $homeDownloadButton.Add_Click({ Invoke-HomeRepoAction 'download' })
  $tabBar = New-Object System.Windows.Forms.Panel
  $tabBar.Location = New-Object System.Drawing.Point(25, 39)
  $tabBar.Size = New-Object System.Drawing.Size(($FormLayout.Width - 51), 38)
  $tabBar.BackColor = [System.Drawing.Color]::White
  $tabBar.Add_Paint({
    param($sender, $eventArgs)
    $pen = New-Object System.Drawing.Pen (Get-FormColor $FormLayout.BorderColor)
    try {
      $eventArgs.Graphics.DrawRectangle($pen, 0, 0, $sender.Width - 1, $sender.Height - 1)
    } finally {
      $pen.Dispose()
    }
  })
  $form.Controls.Add($tabBar)

  # Fixed-width tabs keep their width; the others share the rest equally.
  $fixedWidth = 0
  $sharedCount = 0
  foreach ($tab in $FormLayout.Tabs) {
    if ($tab.Width) { $fixedWidth += $tab.Width } else { $sharedCount++ }
  }
  $sharedWidth = if ($sharedCount -gt 0) { [int][Math]::Floor(($tabBar.Width - 2 - $fixedWidth) / $sharedCount) } else { 0 }

  $tabButtons = @()
  $script:tabLogoDownloads = @()
  $x = 1
  foreach ($tab in $FormLayout.Tabs) {
    $width = if ($tab.Width) { [int]$tab.Width } else { $sharedWidth }
    $button = New-Object System.Windows.Forms.Button
    $button.Text = ''
    $button.AccessibleName = $tab.Label
    $button.Location = New-Object System.Drawing.Point($x, 1)
    $button.Size = New-Object System.Drawing.Size($width, 36)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    if ($tab.HoverBack) {
      $button.FlatAppearance.MouseOverBackColor = Get-FormColor $tab.HoverBack
    }
    $button.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $button.BackColor = [System.Drawing.Color]::White
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.UseMnemonic = $false
    $state = @{}
    foreach ($name in $tab.Keys) { $state[$name] = $tab[$name] }
    $state.Image = $null
    $button.Tag = $state
    $button.Add_Paint($tabPainter)
    $toolTip.SetToolTip($button, $tab.Tip)
    $button.Add_Click({
      param($sender, $eventArgs)
      if ($sender.Tag.Action -eq 'toggleTabs') {
        Set-TabBarItemsVisible (-not $script:tabsShown)
      } else {
        Show-Section $sender.Tag.Key
      }
    })
    $tabBar.Controls.Add($button)
    Set-Variable -Name $tab.Var -Value $button
    $tabButtons += $button
    $x += $width

    if ($tab.Style -eq 'logo' -and $tab.LogoFile) {
      $path = Join-Path $tabLogoDirectory $tab.LogoFile
      $state.Image = Read-TabLogo $path
      if (-not $state.Image -and $tab.LogoUrl) {
        try {
          if (-not (Test-Path -LiteralPath $tabLogoDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $tabLogoDirectory -Force | Out-Null
          }
          [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
          $client = New-Object System.Net.WebClient
          $client.Headers.Add('User-Agent', 'IJTC-ComBox')
          $temporary = $path + '.download'
          $script:tabLogoDownloads += @{ Button = $button; Path = $path; Temporary = $temporary; Client = $client; Task = $client.DownloadFileTaskAsync($tab.LogoUrl, $temporary) }
        } catch {
        }
      }
    }
  }

  # Show/Hide button: restore the last choice.
  $script:tabsShown = $true
  try {
    if ((Test-Path -LiteralPath $tabsHiddenFile -PathType Leaf) -and ([IO.File]::ReadAllText($tabsHiddenFile).Trim() -eq '1')) {
      $script:tabsShown = $false
    }
  } catch {
  }
  Set-TabBarItemsVisible $script:tabsShown $false

  # Logos still downloading: swap them in when ready.
  if ($script:tabLogoDownloads.Count -gt 0) {
    $tabLogoTimer = New-Object System.Windows.Forms.Timer
    $tabLogoTimer.Interval = 500
    $tabLogoTimer.Add_Tick({
      $pending = @()
      foreach ($download in $script:tabLogoDownloads) {
        if (-not $download.Task.IsCompleted) {
          $pending += $download
          continue
        }
        $download.Client.Dispose()
        if (-not $download.Task.IsFaulted -and -not $download.Task.IsCanceled) {
          try {
            Move-Item -LiteralPath $download.Temporary -Destination $download.Path -Force
            $image = Read-TabLogo $download.Path
            if ($image) {
              $download.Button.Tag.Image = $image
              $download.Button.Invalidate()
            } else {
              Remove-Item -LiteralPath $download.Path -Force -ErrorAction SilentlyContinue
            }
          } catch {
          }
        }
        Remove-Item -LiteralPath $download.Temporary -Force -ErrorAction SilentlyContinue
      }
      $script:tabLogoDownloads = $pending
      if ($pending.Count -eq 0) {
        $tabLogoTimer.Stop()
        $tabLogoTimer.Dispose()
      }
    })
    $tabLogoTimer.Start()
  }
}

# Home status line (under the Home box).
function Set-HomeStatus {
  param([string]$Text, [string]$Kind = 'info')
  $homeStatusLabel.Text = $Text
  $toolTip.SetToolTip($homeStatusLabel, $Text)
  switch ($Kind) {
    'error'   { $homeStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick }
    'success' { $homeStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 130, 60) }
    default   { $homeStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103) }
  }
}

# A message for the open tab, shown in that tab's status line.
function Show-SectionMessage {
  param([string]$Text, [bool]$IsError = $false)
  $kind = 'info'
  if ($IsError) {
    $kind = 'error'
  }
  switch ($script:currentSection) {
    'cloudflare' { Set-CloudflareStatus $Text $IsError }
    'rename'     { Set-RenameStatus $Text $kind }
    'adb'        { $toolTip.SetToolTip($adbHost, $Text) }
    'runlocal'   { Set-ColoredStatus $runLocalUploadStatusLabel $Text $kind }
    'home'       { Set-HomeStatus $Text $kind }
  }
}

# Home box: lists the files and folders of the Home folder (folders first).
function Update-HomeFiles {
  $folder = [string]$script:sectionFolders['home']
  $homeFileList.BeginUpdate()
  try {
    $homeFileList.Items.Clear()
    if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
      Set-HomeStatus "Folder not found: $folder" 'error'
      return
    }
    $entries = @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue |
      Sort-Object @{ Expression = { -not $_.PSIsContainer } }, Name)
    foreach ($entry in $entries) {
      $item = New-Object System.Windows.Forms.ListViewItem ($entry.Name)
      if ($entry.PSIsContainer) {
        [void]$item.SubItems.Add('Folder')
        [void]$item.SubItems.Add('')
      } else {
        [void]$item.SubItems.Add($(if ($entry.Extension) { $entry.Extension.TrimStart('.').ToUpper() + ' file' } else { 'File' }))
        $size = $entry.Length
        $sizeText = if ($size -ge 1MB) { '{0:N1} MB' -f ($size / 1MB) } elseif ($size -ge 1KB) { '{0:N0} KB' -f [Math]::Ceiling($size / 1KB) } else { "$size B" }
        [void]$item.SubItems.Add($sizeText)
      }
      [void]$item.SubItems.Add($entry.LastWriteTime.ToString('dd-MMM-yyyy hh:mm tt'))
      [void]$item.SubItems.Add('')   # Upload column cell (the tick box is drawn here)
      $item.Tag = $entry.FullName
      $item.Name = $entry.Name
      $item.ToolTipText = $entry.FullName
      if ($entry.Attributes -band [IO.FileAttributes]::Hidden) {
        $item.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
      }
      [void]$homeFileList.Items.Add($item)
    }
    # Forget ticks of items that are no longer in this folder.
    $present = @($entries | ForEach-Object { $_.FullName })
    foreach ($path in @($script:homeChecked)) {
      if ($present -notcontains $path) {
        [void]$script:homeChecked.Remove($path)
      }
    }
    Update-HomeCheckedStatus
  } finally {
    $homeFileList.EndUpdate()
  }
}

# Ticks or clears one item's Upload box.
function Switch-HomeChecked {
  param($Item)
  if ($Item.Name -eq '.git') {
    return
  }
  $path = [string]$Item.Tag
  $before = @($script:homeChecked)
  if (-not $script:homeChecked.Remove($path)) {
    [void]$script:homeChecked.Add($path)
  }
  Add-UndoAction 'ticks' "Upload tick of $($Item.Name)" @{ Old = $before; New = @($script:homeChecked) }
  $homeFileList.Invalidate($Item.Bounds)
  Update-HomeCheckedStatus
}

# Tick all (or clear all) items' Upload boxes; one Undo step.
function Set-HomeCheckedAll {
  param([bool]$All)
  $before = @($script:homeChecked)
  foreach ($item in @($homeFileList.Items)) {
    if ($item.Name -eq '.git') { continue }
    if ($All) { [void]$script:homeChecked.Add([string]$item.Tag) } else { [void]$script:homeChecked.Remove([string]$item.Tag) }
  }
  $homeFileList.Invalidate()
  Add-UndoAction 'ticks' $(if ($All) { 'Tick all' } else { 'Clear all ticks' }) @{ Old = $before; New = @($script:homeChecked) }
  Update-HomeCheckedStatus
}

# Status line: folder, counts and how many items are ticked for upload.
function Update-HomeCheckedStatus {
  $folder = [string]$script:sectionFolders['home']
  $folders = @($homeFileList.Items | Where-Object { $_.SubItems[1].Text -eq 'Folder' }).Count
  $files = $homeFileList.Items.Count - $folders
  $ticked = $script:homeChecked.Count
  $tickText = if ($ticked -gt 0) { "   |   $ticked ticked for upload" } else { '   |   none ticked: upload sends the whole folder' }
  Set-HomeStatus "$folder   |   $folders folder(s), $files file(s)$tickText"
  Request-FormStateSave
  # All box: ticked when every item is ticked, half when some are.
  if ($homeCheckAll) {
    $tickable = @($homeFileList.Items | Where-Object { $_.Name -ne '.git' }).Count
    $state = if ($tickable -gt 0 -and $ticked -ge $tickable) { 'Checked' } elseif ($ticked -gt 0) { 'Indeterminate' } else { 'Unchecked' }
    $homeCheckAll.CheckState = [System.Windows.Forms.CheckState]$state
  }
}

# Folder row's delete button: moves the ticked files/folders of the Home folder
# to the Recycle Bin (they can be restored from there).
function Remove-HomeCheckedItems {
  $paths = @($script:homeChecked | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
  if ($paths.Count -eq 0) {
    Set-HomeStatus 'Tick the files or folders to delete first (Upload column).' 'error'
    return
  }
  $names = @($paths | ForEach-Object { Split-Path -Leaf $_ })
  $shown = @($names | Select-Object -First 12) -join "`r`n   "
  if ($names.Count -gt 12) { $shown += "`r`n   ... and $($names.Count - 12) more" }
  $answer = [System.Windows.Forms.MessageBox]::Show($form, "Delete these $($names.Count) item(s) from the folder?`r`n`r`n   $shown`r`n`r`nThey go to the Recycle Bin.", 'Delete files', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
  if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
    Set-HomeStatus 'Delete cancelled.'
    return
  }
  Add-Type -AssemblyName Microsoft.VisualBasic
  $failed = @()
  foreach ($path in $paths) {
    try {
      if (Test-Path -LiteralPath $path -PathType Container) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($path, 'OnlyErrorDialogs', 'SendToRecycleBin')
      } else {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($path, 'OnlyErrorDialogs', 'SendToRecycleBin')
      }
      [void]$script:homeChecked.Remove($path)
    } catch {
      $failed += "$(Split-Path -Leaf $path): $($_.Exception.Message)"
    }
  }
  Update-HomeFiles
  if ($failed.Count -gt 0) {
    Set-HomeStatus "$($paths.Count - $failed.Count) deleted, $($failed.Count) could not be deleted (in use or no permission)." 'error'
    Show-ComBoxMessage (($failed -join "`r`n")) 'Some items were not deleted' $true
  } else {
    Set-HomeStatus "$($paths.Count) item(s) moved to the Recycle Bin." 'success'
  }
}

# Names (relative to the Home folder) of the ticked items, for the upload.
function Get-HomeCheckedNames {
  $folder = ([string]$script:sectionFolders['home']).TrimEnd('\')
  $names = @()
  foreach ($item in $homeFileList.Items) {
    if ($script:homeChecked.Contains([string]$item.Tag)) {
      $names += $item.Name
    }
  }
  return $names
}

# Home: opens the URL box's link in Google Chrome (default browser if Chrome is not installed).
function Open-HomeRepoInChrome {
  $url = $homeRepoBox.Text.Trim()
  if (-not $url) {
    Set-HomeStatus 'There is no link to open.' 'error'
    return
  }
  if ($url -match '^https?://(www\.)?github\.com/') {
    $url = $url -replace '\.git$', ''
  }
  if ($url -notmatch '^[a-z][a-z0-9+.-]*://') {
    $url = 'https://' + $url
  }
  $chrome = Get-ChromeExecutable
  try {
    if ($chrome) {
      Start-Process -FilePath $chrome -ArgumentList ('"' + $url + '"') -ErrorAction Stop | Out-Null
      Set-HomeStatus "Opened in Chrome: $url" 'success'
    } else {
      Start-Process -FilePath $url -ErrorAction Stop | Out-Null
      Set-HomeStatus "Chrome was not found; opened in the default browser: $url"
    }
  } catch {
    Set-HomeStatus ('Could not open the link: ' + $_.Exception.Message) 'error'
  }
}

function Get-ChromeExecutable {
  $chrome = ''
  foreach ($key in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe')) {
    try {
      $value = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).'(default)'
      if ($value -and (Test-Path -LiteralPath $value -PathType Leaf)) { $chrome = $value; break }
    } catch {
    }
  }
  if (-not $chrome) {
    foreach ($candidate in @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")) {
      if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { $chrome = $candidate; break }
    }
  }
  return $chrome
}

# Home: remember the repository chosen with the search button.
$homeRepoUrlFile = Join-Path $env:LOCALAPPDATA 'IJTC\home-repository-url.txt'

function Save-HomeRepoUrl {
  param([string]$Url)
  $normalizedUrl = $Url.Trim()
  if (-not (Test-GitHubRepositoryUrl $normalizedUrl)) {
    throw 'Choose a valid GitHub repository before saving the Home URL.'
  }
  $directory = Split-Path -Parent $homeRepoUrlFile
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
    New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
  }
  [IO.File]::WriteAllText($homeRepoUrlFile, $normalizedUrl, (New-Object System.Text.UTF8Encoding($false)))
}

# Home URL box: restores the last selected repository.
function Update-HomeRepo {
  param([bool]$Announce = $false)
  $repositoryUrl = $script:defaultRepositoryUrl
  try {
    if (Test-Path -LiteralPath $homeRepoUrlFile -PathType Leaf) {
      $savedUrl = [IO.File]::ReadAllText($homeRepoUrlFile).Trim()
      if (Test-GitHubRepositoryUrl $savedUrl) {
        $repositoryUrl = $savedUrl -replace '\.git/?$', ''
      } else {
        Set-HomeStatus "Saved repository URL is invalid: $homeRepoUrlFile" 'error'
      }
    }
  } catch {
    Set-HomeStatus ('Could not read the saved repository URL: ' + $_.Exception.Message) 'error'
  }
  $script:homeRepoLoading = $true
  try { $homeRepoBox.Text = $repositoryUrl } finally { $script:homeRepoLoading = $false }
  if ($Announce) { Set-HomeStatus "Using repository: $repositoryUrl" 'success' }
}

# GitHub account whose repositories the search button lists: the account chosen
# with the title bar's account button, else the owner in the URL box.
function Get-HomeRepoAccount {
  param([string]$RepositoryUrl)
  $user = ''
  if ($script:githubAccount) {
    $user = [string]$script:githubAccount
  }
  if (Get-Command Read-GitHubAccount -ErrorAction SilentlyContinue) {
    if (-not $user) {
      $user = [string](Read-GitHubAccount)
    }
  }
  if (-not $user) {
    $accountUrl = if ($RepositoryUrl) { $RepositoryUrl } else { [string]$homeRepoBox.Text }
    if ($accountUrl -match 'github\.com/([A-Za-z0-9-]+)/') {
      $user = $Matches[1]
    }
  }
  return $user.Trim()
}

# Token for the GitHub API from Git Credential Manager (same sign-in git uses).
# Returns '' when there is none; then only public repositories are listed.
function Get-HomeGitHubToken {
  param([string]$User)
  try {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = 'git'
    $startInfo.Arguments = 'credential fill'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $request = "protocol=https`nhost=github.com`n"
    if ($User) { $request += "username=$User`n" }
    $process.StandardInput.Write($request + "`n")
    $process.StandardInput.Close()
    $output = $process.StandardOutput.ReadToEndAsync()
    $until = (Get-Date).AddSeconds(90)
    while (-not $process.HasExited -and (Get-Date) -lt $until) {
      [System.Windows.Forms.Application]::DoEvents()
      Start-Sleep -Milliseconds 100
    }
    if (-not $process.HasExited) {
      try { $process.Kill() } catch { }
      return ''
    }
    foreach ($line in ($output.Result -split "`r?`n")) {
      if ($line -like 'password=*') {
        return $line.Substring(9)
      }
    }
  } catch {
  }
  return ''
}

# Lists the account's repositories (all pages). Signed in: public and private
# repositories the account owns; otherwise its public ones.
function Get-HomeRepositories {
  param([string]$User, [string]$Token)
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $headers = @{ 'User-Agent' = 'IJTC-ComBox'; 'Accept' = 'application/vnd.github+json' }
  $base = "https://api.github.com/users/$User/repos?type=owner&sort=updated&per_page=100"
  if ($Token) {
    $headers['Authorization'] = "Bearer $Token"
    try {
      $me = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers -ErrorAction Stop
      if ($me.login) {
        # Signed in: every repository of the account (public and private, its own,
        # shared with it, and those of its organizations).
        $base = 'https://api.github.com/user/repos?visibility=all&affiliation=owner,collaborator,organization_member&sort=updated&per_page=100'
      }
    } catch {
      $headers.Remove('Authorization')
    }
  }
  $all = @()
  for ($page = 1; $page -le 20; $page++) {
    # Windows PowerShell returns a JSON array as ONE object; the pipe splits it into items.
    $response = Invoke-RestMethod -Uri ($base + "&page=$page") -Headers $headers -ErrorAction Stop
    $batch = @($response | ForEach-Object { $_ })
    $all += $batch
    if ($batch.Count -lt 100) {
      break
    }
  }
  return $all
}

# Repository list: used by Home's search button and by other tabs' search buttons
# (Show-RepoPicker). $script:repoPickTarget = @{ Box; Button; Status } or $null for Home.
function Set-RepoPickStatus {
  param([string]$Text, [string]$Kind = 'info')
  if ($script:repoPickTarget) {
    & $script:repoPickTarget.Status $Text $Kind
  } else {
    Set-HomeStatus $Text $Kind
  }
}

# Opens the repository list beside a box: the chosen repository's link goes into it.
#   Show-RepoPicker -Box $deployRepoBox -Button $deployRepoSearchButton -Status { param($t, $k) Set-CloudflareStatus $t ($k -eq 'error') }
function Show-RepoPicker {
  param($Box, $Button, [scriptblock]$Status, [switch]$OpenAboveLeft, $SelectionBox)
  if ($homeRepoPickerForm.Visible) {
    if ($script:repoPickTarget -and $script:repoPickTarget.Box -eq $Box) {
      Hide-HomeRepoDropDown
      return
    }
    Hide-HomeRepoDropDown
  }
  $script:repoPickTarget = @{ Box = $Box; SelectionBox = $SelectionBox; Button = $Button; Status = $Status; OpenAboveLeft = $OpenAboveLeft.IsPresent }
  Select-HomeRepository
}

function Show-HomeRepoPickerWindow {
  param($Box, [switch]$OpenAboveLeft)
  $owner = $Box.FindForm()
  if (-not $owner) {
    throw 'The repository field is not attached to a window.'
  }
  if ($OpenAboveLeft) {
    $workingArea = [System.Windows.Forms.Screen]::FromControl($Box).WorkingArea
    $boxTopLeft = $Box.PointToScreen([System.Drawing.Point]::Empty)
    $width = [Math]::Min(720, $workingArea.Width - 16)
    $height = [Math]::Min(260, $boxTopLeft.Y - $workingArea.Top - 8)
    if ($width -lt 240 -or $height -lt 120) {
      throw 'There is not enough room above and to the left of this field to display the repository list.'
    }
    $boxRight = $Box.PointToScreen((New-Object System.Drawing.Point($Box.Width, 0))).X
    $x = [Math]::Max($workingArea.Left + 8, [Math]::Min($boxRight - $width, $workingArea.Right - $width - 8))
    $y = $boxTopLeft.Y - $height - 4
    $screenPoint = New-Object System.Drawing.Point($x, $y)
    $homeRepoPickerForm.Location = $screenPoint
    $homeRepoPickerForm.ClientSize = New-Object System.Drawing.Size($width, $height)
    Set-RepoDropDownBounds 0 0 $width $height
    $homeRepoDropDown.Visible = $true
    $homeRepoPickerForm.Show($owner)
    $homeRepoPickerForm.BringToFront()
    return
  }
  $screenPoint = $Box.PointToScreen((New-Object System.Drawing.Point(0, ($Box.Height + 2))))
  $workingArea = [System.Windows.Forms.Screen]::FromControl($Box).WorkingArea
  $width = [Math]::Min(720, $workingArea.Right - $screenPoint.X - 8)
  $height = 260
  $below = $workingArea.Bottom - $screenPoint.Y - 8
  $above = $screenPoint.Y - $workingArea.Top - $Box.Height - 8
  if ($below -ge 120) {
    $height = [Math]::Min($height, $below)
  } elseif ($above -ge 120) {
    $height = [Math]::Min($height, $above)
    $screenPoint.Y -= ($height + $Box.Height + 4)
  } else {
    throw 'There is not enough room to display the repository list next to this field.'
  }
  if ($width -lt 240 -or $height -lt 120) {
    throw 'There is not enough room to display the repository list next to this field.'
  }
  $homeRepoPickerForm.Location = $screenPoint
  $homeRepoPickerForm.ClientSize = New-Object System.Drawing.Size($width, $height)
  Set-RepoDropDownBounds 0 0 $width $height
  $homeRepoDropDown.Visible = $true
  $homeRepoPickerForm.Show($owner)
  $homeRepoPickerForm.BringToFront()
}

function Set-RepoDropDownBounds {
  param([int]$X, [int]$Y, [int]$Width, [int]$Height)
  $homeRepoDropDown.Location = New-Object System.Drawing.Point($X, $Y)
  $homeRepoDropDown.Size = New-Object System.Drawing.Size($Width, $Height)
  $homeRepoFilter.Width = $Width - 48
  $homeRepoClose.Left = $Width - 38
  $homeRepoListView.Size = New-Object System.Drawing.Size(($Width - 14), ($Height - 44))
}

# Search button: shows the account's repositories; the chosen one goes into the URL box.
function Select-HomeRepository {
  $target = $script:repoPickTarget
  $pickerBox = if ($target) { $target.Box } else { $homeRepoBox }
  Show-HomeRepoPickerWindow $pickerBox -OpenAboveLeft:([bool]($target -and $target.OpenAboveLeft))
  $script:homeRepoList = @()
  $homeRepoFilter.Text = ''
  $homeRepoListView.BeginUpdate()
  try {
    $homeRepoListView.Items.Clear()
    $loadingItem = New-Object System.Windows.Forms.ListViewItem 'Loading repositories...'
    $loadingItem.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    [void]$homeRepoListView.Items.Add($loadingItem)
  } finally {
    $homeRepoListView.EndUpdate()
  }
  $homeRepoListView.Enabled = $false
  $searchButton = if ($target) { $target.Button } else { $homeRepoSearchButton }
  $repositoryUrl = if ($target -and $target.SelectionBox) {
    [string]$target.SelectionBox.Text
  } elseif ($target) {
    [string]$target.Box.Text
  } else {
    [string]$homeRepoBox.Text
  }
  $user = Get-HomeRepoAccount $repositoryUrl
  if (-not $user) {
    $homeRepoListView.Items[0].Text = 'No GitHub account is selected.'
    $homeRepoListView.Enabled = $true
    Set-RepoPickStatus 'No GitHub account: choose one with the account button in the title bar, or put a github.com link in the URL box.' 'error'
    return
  }
  $searchButton.Enabled = $false
  try {
    Set-RepoPickStatus "Reading the repositories of $user..."
    [System.Windows.Forms.Application]::DoEvents()
    $token = Get-HomeGitHubToken $user
    if (-not $token) {
      $token = Get-HomeGitHubToken ''
    }
    $repositories = @(Get-HomeRepositories $user $token)
  } catch {
    $message = "Could not read the repositories of ${user}: " + $_.Exception.Message
    $homeRepoListView.Items[0].Text = $message
    $homeRepoListView.Enabled = $true
    Set-RepoPickStatus $message 'error'
    return
  } finally {
    $searchButton.Enabled = $true
  }
  if ($repositories.Count -eq 0) {
    $homeRepoListView.Items[0].Text = "No repositories found for $user."
    $homeRepoListView.Enabled = $true
    Set-RepoPickStatus "No repositories found for $user." 'error'
    return
  }
  Set-RepoPickStatus "$($repositories.Count) repositories of $user$(if (-not $token) { ' (public only: not signed in)' })."

  $script:homeRepoList = $repositories
  Update-HomeRepoDropDown
  $homeRepoListView.Enabled = $true
  $homeRepoPickerForm.BringToFront()
  $homeRepoFilter.Focus()
}

# Fills the repository list under the URL box (filtered by the box above the list).
function Update-HomeRepoDropDown {
  $text = $homeRepoFilter.Text.Trim()
  $currentBox = if ($script:repoPickTarget -and $script:repoPickTarget.SelectionBox) {
    $script:repoPickTarget.SelectionBox
  } elseif ($script:repoPickTarget) {
    $script:repoPickTarget.Box
  } else {
    $homeRepoBox
  }
  $current = ($currentBox.Text.Trim() -replace '\.git/?$', '').TrimEnd('/')
  $homeRepoListView.BeginUpdate()
  try {
    $homeRepoListView.Items.Clear()
    foreach ($repository in @($script:homeRepoList)) {
      if ($text -and ([string]$repository.name -notlike "*$text*") -and ([string]$repository.description -notlike "*$text*")) {
        continue
      }
      $item = New-Object System.Windows.Forms.ListViewItem ([string]$repository.full_name)
      [void]$item.SubItems.Add($(if ($repository.private) { 'Private' } else { 'Public' }))
      $updated = ''
      try { $updated = ([datetime]$repository.pushed_at).ToLocalTime().ToString('dd-MMM-yyyy hh:mm tt') } catch { }
      [void]$item.SubItems.Add($updated)
      [void]$item.SubItems.Add([string]$repository.description)
      $item.Tag = [string]$repository.clone_url
      $item.ToolTipText = [string]$repository.html_url
      [void]$homeRepoListView.Items.Add($item)
      if ($current -and ([string]$repository.html_url).TrimEnd('/') -ieq $current) {
        $item.Selected = $true
        $item.EnsureVisible()
      }
    }
  } finally {
    $homeRepoListView.EndUpdate()
  }
}

# Puts the chosen repository's link into the URL box and closes the list.
function Use-HomeRepoSelection {
  if ($homeRepoListView.SelectedItems.Count -eq 0) {
    return
  }
  $url = [string]$homeRepoListView.SelectedItems[0].Tag
  $target = $script:repoPickTarget
  if ($target) {
    $url = $url -replace '\.git$', ''
    $destinationBox = if ($target.SelectionBox) { $target.SelectionBox } else { $target.Box }
    try {
      $destinationBox.Text = $url
      if ($destinationBox -eq $homeRepoBox) {
        Save-HomeRepoUrl $url
      }
      & $target.Status "Repository link set: $url" 'success'
    } catch {
      & $target.Status ('Could not save repository link: ' + $_.Exception.Message) 'error'
    }
    Hide-HomeRepoDropDown
    return
  }
  $url = $url -replace '\.git$', ''
  try {
    $homeRepoBox.Text = $url
    Save-HomeRepoUrl $url
    Set-HomeStatus "Repository link set: $url" 'success'
  } catch {
    Set-HomeStatus ('Could not save repository link: ' + $_.Exception.Message) 'error'
  }
  Hide-HomeRepoDropDown
}

function Hide-HomeRepoDropDown {
  if ($homeRepoPickerForm) {
    $homeRepoPickerForm.Hide()
  }
  if ($homeRepoDropDown) {
    $homeRepoDropDown.Visible = $false
  }
  $script:repoPickTarget = $null
}

# Home Upload / Download: uploads the folder to the selected GitHub repository.
function Invoke-HomeRepoAction {
  param([string]$Action)
  $url = $homeRepoBox.Text.Trim()
  if (-not (Test-GitHubRepositoryUrl $url)) {
    Set-HomeStatus 'Enter a valid GitHub repository link (https://github.com/owner/repo).' 'error'
    return
  }
  if (Test-GitHubBusy) {
    # Something is still running (maybe stuck): say what, and offer to stop it.
    if (Get-Command Stop-GitHubOperation -ErrorAction SilentlyContinue) {
      Stop-GitHubOperation -Ask
    } else {
      Set-HomeStatus 'Wait for the current GitHub operation to finish.' 'error'
    }
    return
  }
  if ($Action -eq 'clean') {
    # Clean from Home: delete every tracked file after explicit confirmation.
    if ($script:deleteRepoJob) {
      Set-HomeStatus 'A repository delete is already running.' 'error'
      return
    }
    Start-DeleteRepo -RepositoryUrl $url
    return
  }
  if ($Action -eq 'upload') {
    # Upload from Home: the Home folder goes to the link on its left; progress and
    # result show in Home's status line.
    $folder = [string]$script:sectionFolders['home']
    if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
      Set-HomeStatus "Folder not found: $folder" 'error'
      return
    }
    $onlyNames = @(Get-HomeCheckedNames)
    if ($onlyNames.Count -gt 0) {
      $shown = @($onlyNames | Select-Object -First 12) -join "`r`n   "
      if ($onlyNames.Count -gt 12) { $shown += "`r`n   ... and $($onlyNames.Count - 12) more" }
      $question = "Upload only the ticked items to GitHub?`r`n`r`nFolder:  $folder`r`nRepository:  $url`r`n`r`n   $shown`r`n`r`nThese items replace the same files/folders on GitHub (branch main). Everything else in the repository stays as it is."
    } else {
      $question = "Nothing is ticked, so the WHOLE folder will be uploaded.`r`n`r`nFolder:  $folder`r`nRepository:  $url`r`n`r`nAll existing files in the repository (branch main) will be replaced by this folder's files."
    }
    $answer = [System.Windows.Forms.MessageBox]::Show($form, $question, 'Upload to GitHub', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
      Set-HomeStatus 'Upload cancelled.'
      return
    }
    $script:githubDirectory = $folder
    Set-HomeStatus "Preparing the upload of $folder..."
    try {
      Initialize-GitHubSourceRepository
    } catch {
      Set-HomeStatus ('Could not prepare the upload: ' + $_.Exception.Message) 'error'
      Show-ComBoxMessage ($_.Exception.Message) 'Upload preparation failed' $true
      return
    }
    Start-GitHubUpload -OnlyPaths $onlyNames -RepositoryUrl $url -SourceFolder $folder -Confirmed -HomeStatus
  } else {
    Start-HomeDownload $url
  }
}

# Download from Home: puts the repository's files into the Home folder (stays on Home).
# Same-named files are replaced; other files in the folder are kept; .git is not copied.
function Start-HomeDownload {
  param([string]$Url)
  if ($script:homeDownloadJob) {
    Set-HomeStatus 'A download is already running.' 'error'
    return
  }
  $folder = ([string]$script:sectionFolders['home']).TrimEnd('\')
  if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
    Set-HomeStatus "Folder not found: $folder" 'error'
    return
  }
  $answer = [System.Windows.Forms.MessageBox]::Show($form, "Download the repository's files into this folder?`r`n`r`nRepository:  $Url`r`nFolder:  $folder`r`n`r`nFiles with the same name in the folder will be replaced. Other files in the folder are kept.", 'Download from GitHub', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
  if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
    Set-HomeStatus 'Download cancelled.'
    return
  }
  $temporary = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-home-download-' + [Guid]::NewGuid().ToString('N'))
  $logFile = $temporary + '.log'
  try {
    # cmd: clone into a temp folder, then copy it into the Home folder (robocopy, without .git).
    $command = '(git clone --depth 1 --progress "' + $Url + '" "' + $temporary + '" > "' + $logFile + '" 2>&1 || exit 200)' +
      ' & robocopy "' + $temporary + '" "' + $folder + '" /E /XD .git /R:1 /W:1 /NP /NFL /NDL >> "' + $logFile + '" 2>&1' +
      ' & if errorlevel 8 (exit 201) else (exit 0)'
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $env:ComSpec
    $startInfo.Arguments = '/d /s /c "' + $command + '"'
    $startInfo.WorkingDirectory = [IO.Path]::GetTempPath()
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $process) {
      throw 'Could not start git.'
    }
  } catch {
    Set-HomeStatus ('Download could not start: ' + $_.Exception.Message) 'error'
    return
  }
  $script:homeDownloadJob = [pscustomobject]@{ Process = $process; Log = $logFile; Temp = $temporary; Folder = $folder; Url = $Url; Start = Get-Date }
  $homeDownloadButton.Enabled = $false
  $homeUploadButton.Enabled = $false
  Set-HomeStatus "Downloading $Url into $folder..."
  if (-not $script:homeDownloadTimer) {
    $script:homeDownloadTimer = New-Object System.Windows.Forms.Timer
    $script:homeDownloadTimer.Interval = 500
    $script:homeDownloadTimer.Add_Tick({ Update-HomeDownload })
  }
  $script:homeDownloadTimer.Start()
}

function Update-HomeDownload {
  $job = $script:homeDownloadJob
  if (-not $job) {
    $script:homeDownloadTimer.Stop()
    return
  }
  $log = ''
  try {
    $stream = New-Object IO.FileStream($job.Log, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $log = (New-Object IO.StreamReader($stream)).ReadToEnd() } finally { $stream.Dispose() }
  } catch {
  }
  $elapsed = [int]((Get-Date) - $job.Start).TotalSeconds
  if (-not $job.Process.HasExited) {
    $last = @($log -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 1)
    $step = if ($last.Count -gt 0) { $last[0].Trim() } else { 'Connecting to GitHub...' }
    Set-HomeStatus "Downloading   |   $elapsed s   |   $step"
    return
  }
  $script:homeDownloadTimer.Stop()
  $exitCode = $job.Process.ExitCode
  $job.Process.Dispose()
  $script:homeDownloadJob = $null
  $homeDownloadButton.Enabled = $true
  $homeUploadButton.Enabled = $true
  Remove-Item -LiteralPath $job.Temp -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $job.Temp) {
    $null = & cmd.exe /d /c "rd /s /q `"$($job.Temp)`"" 2>&1
  }
  Remove-Item -LiteralPath $job.Log -Force -ErrorAction SilentlyContinue
  if ($script:currentSection -eq 'home') {
    Update-HomeFiles
  }
  if ($exitCode -eq 0) {
    Set-HomeStatus "Downloaded $($job.Url) into $($job.Folder) ($elapsed s)." 'success'
  } else {
    $tail = (@($log -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 12)) -join "`r`n"
    $what = if ($exitCode -eq 200) { 'git clone failed' } elseif ($exitCode -eq 201) { 'Copying the files into the folder failed' } else { "Download failed (exit code $exitCode)" }
    Set-HomeStatus "$what. See the message for details." 'error'
    Show-ComBoxMessage ("$what.`r`n`r`n$tail") 'Download failed' $true
  }
}

# Show/Hide button in the tab bar: shows or hides every tab to its right
# (the choice is remembered for the next start).
$tabsHiddenFile = Join-Path $env:LOCALAPPDATA 'IJTC\tabs-hidden.txt'
function Set-TabBarItemsVisible {
  param([bool]$Visible, [bool]$Save = $true)
  $script:tabsShown = $Visible
  $after = $false
  foreach ($tab in $FormLayout.Tabs) {
    $button = Get-Variable -Name $tab.Var -ValueOnly -ErrorAction SilentlyContinue
    if (-not $button) {
      continue
    }
    if ($tab.Action -eq 'toggleTabs') {
      $after = $true
      $button.Tag.Glyph = if ($Visible) { 0xE76B } else { 0xE76C }
      $toolTip.SetToolTip($button, $(if ($Visible) { 'Hide the tabs on the right' } else { 'Show the tabs on the right' }))
      $button.Invalidate()
      continue
    }
    if ($after) {
      $button.Visible = $Visible
    }
  }
  if ($Save) {
    try {
      $directory = Split-Path -Parent $tabsHiddenFile
      if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
      }
      [IO.File]::WriteAllText($tabsHiddenFile, $(if ($Visible) { '0' } else { '1' }))
    } catch {
    }
  }
}

# ---------------------------------------------------------------------------
# 7. SWITCHING TABS
#    The application may define Invoke-SectionShowing / Invoke-SectionShown
#    for work a tab needs when it opens (load the ADB tab, start timers, ...).
# ---------------------------------------------------------------------------
function Set-ToggleButtonStyle {
  param($Button, [bool]$Active)
  $tab = $Button.Tag
  if ($Active) {
    $Button.BackColor = if ($tab -and $tab.ActiveBack) { Get-FormColor $tab.ActiveBack } else { Get-FormColor $FormLayout.ActiveTabColor }
    $Button.ForeColor = Get-FormColor $FormLayout.AccentColor
    $Button.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
  } else {
    $Button.BackColor = [System.Drawing.Color]::White
    $Button.ForeColor = Get-FormColor $FormLayout.TabTextColor
    $Button.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  }
  $Button.Invalidate()
}

function Update-SectionLayout {
  # Position Cloudflare controls within their tab area.
  foreach ($item in $cloudflareSectionItems) {
    $item.Control.Visible = $script:showCloudflareSection
    $item.Control.Top = $item.Top - $(if ($script:showCloudflareSection -and (Test-FolderBarHidden)) { $folderBarHeight } else { 0 })
  }
  if ($null -ne $localDeployFilesList -and -not $localDeployFilesList.IsDisposed) {
    $localDeployFilesList.Visible = $script:showCloudflareSection -and $script:cloudflareLocalFilesExpanded
    if ($localDeployFilesList.Visible) {
      $rowTop = $form.PointToClient($localDeployFolderBox.PointToScreen([System.Drawing.Point]::Empty))
      $localDeployFilesList.Location = New-Object System.Drawing.Point(($deployPanel.Left + 8), [Math]::Max(0, ($rowTop.Y - $localDeployFilesList.Height - 4)))
      $localDeployFilesList.BringToFront()
    }
  }

  $height = 39 + $tabBarHeight + $folderBarHeight
  if (Test-FolderBarHidden) {
    # This tab has no folder bar: its area moves up into that row.
    $height -= $folderBarHeight
  }
  foreach ($key in $FormLayout.Sections.Keys) {
    $section = $FormLayout.Sections[$key]
    $active = [bool](Get-Variable -Name $section.Flag -ValueOnly -ErrorAction SilentlyContinue)
    foreach ($name in @($section.Controls)) {
      $control = Get-Variable -Name $name -ValueOnly -ErrorAction SilentlyContinue
      if ($control) {
        $control.Visible = $active
      }
    }
    if ($active) {
      $sectionHeight = Get-Variable -Scope Script -Name $section.HeightVar -ValueOnly -ErrorAction SilentlyContinue
      if ($null -eq $sectionHeight) {
        $sectionHeight = $section.Height
      }
      $height += [int]$sectionHeight
    }
  }
  if ($height -lt 44) {
    $height = 44
  }
  $form.MinimumSize = New-Object System.Drawing.Size(0, 0)
  $form.MaximumSize = New-Object System.Drawing.Size(0, 0)
  $form.ClientSize = New-Object System.Drawing.Size($FormLayout.Width, $height)
  $form.MinimumSize = $form.Size
  $form.MaximumSize = $form.Size

  foreach ($tab in $FormLayout.Tabs) {
    $button = Get-Variable -Name $tab.Var -ValueOnly -ErrorAction SilentlyContinue
    if ($button) {
      Set-ToggleButtonStyle $button ($script:currentSection -eq $tab.Key)
    }
  }
  $form.Invalidate()
}

function Show-Section {
  param([string]$Name)
  if (Get-Command Hide-HomeRepoDropDown -ErrorAction SilentlyContinue) {
    Hide-HomeRepoDropDown
  }
  foreach ($key in $FormLayout.Sections.Keys) {
    Set-Variable -Scope Script -Name $FormLayout.Sections[$key].Flag -Value ($Name -eq $key)
  }
  $script:currentSection = $Name
  if (Get-Command Invoke-SectionShowing -ErrorAction SilentlyContinue) {
    Invoke-SectionShowing $Name
  }
  Update-SectionLayout
  Update-FolderBar
  if (Get-Command Invoke-SectionShown -ErrorAction SilentlyContinue) {
    Invoke-SectionShown $Name
  }
  Request-FormStateSave
}

# ---------------------------------------------------------------------------
# 8. UNDO / REDO (title bar): step back and forward through changes made to the
#    text boxes of every tab (typed, pasted, reset or set by a button).
#    Run with ". $FormParts.UndoRedo" once every tab is built.
# ---------------------------------------------------------------------------
# Name of a text box for messages: its label on the same row, else its panel title.
function Get-UndoBoxName {
  param($Box)
  if ($Box -is [System.Windows.Forms.CheckBox] -and $Box.Text) {
    return $Box.Text
  }
  $best = $null
  $center = $Box.Top + $Box.Height / 2
  foreach ($control in @($Box.Parent.Controls)) {
    if ($control -is [System.Windows.Forms.Label] -and $control.Text -and $control.Right -le $Box.Left -and [Math]::Abs(($control.Top + $control.Height / 2) - $center) -le 12) {
      if (-not $best -or $control.Right -gt $best.Right) {
        $best = $control
      }
    }
  }
  if ($best) {
    return $best.Text
  }
  $parent = $Box.Parent
  while ($parent -and $parent -ne $form) {
    foreach ($control in $parent.Controls) {
      if ($control -is [System.Windows.Forms.Label] -and $control.Text -and $control.Top -lt 12) {
        return $control.Text
      }
    }
    $parent = $parent.Parent
  }
  return 'text box'
}

function Update-UndoButtons {
  $undoButton.Enabled = $script:undoStack.Count -gt 0
  $redoButton.Enabled = $script:redoStack.Count -gt 0
  $undoTip = if ($script:undoStack.Count -gt 0) { 'Undo: ' + $script:undoStack[$script:undoStack.Count - 1].Name } else { 'Undo (nothing to undo)' }
  $redoTip = if ($script:redoStack.Count -gt 0) { 'Redo: ' + $script:redoStack[$script:redoStack.Count - 1].Name } else { 'Redo (nothing to redo)' }
  $toolTip.SetToolTip($undoButton, $undoTip)
  $toolTip.SetToolTip($redoButton, $redoTip)
}

$undoTextChanged = {
  param($sender, $eventArgs)
  $old = [string]$script:undoLastText[$sender]
  $new = [string]$sender.Text
  $script:undoLastText[$sender] = $new
  if ($script:undoApplying -or $old -ceq $new -or $sender -eq $folderBarBox -or $sender.ReadOnly -or $sender.Multiline) {
    return
  }
  $now = Get-Date
  $top = if ($script:undoStack.Count -gt 0) { $script:undoStack[$script:undoStack.Count - 1] } else { $null }
  if ($top -and $top.Box -eq $sender -and ($now - $top.Time).TotalMilliseconds -lt 1500) {
    # Typing: one undo step per burst of keystrokes.
    $top.New = $new
    $top.Time = $now
  } else {
    $script:undoStack.Add(@{ Box = $sender; Old = $old; New = $new; Time = $now; Name = (Get-UndoBoxName $sender) })
    if ($script:undoStack.Count -gt 200) {
      $script:undoStack.RemoveAt(0)
    }
  }
  $script:redoStack.Clear()
  Update-UndoButtons
}

function Register-UndoControl {
  param($Control)
  if (-not $Control -or -not $script:undoHooked.Add($Control)) {
    return
  }
  if ($Control -is [System.Windows.Forms.TextBox]) {
    $script:undoLastText[$Control] = [string]$Control.Text
    $Control.Add_TextChanged($undoTextChanged)
  } elseif ($Control -is [System.Windows.Forms.CheckBox]) {
    $Control.Add_CheckedChanged($undoCheckChanged)
  }
  foreach ($child in @($Control.Controls)) {
    Register-UndoControl $child
  }
  $Control.Add_ControlAdded({
    param($sender, $eventArgs)
    Register-UndoControl $eventArgs.Control
  })
}

# Adds a step that is not a text box change. Kind (with its Data):
#   ticks  - Home Upload ticks:   Old / New = arrays of ticked paths
#   folder - a tab's folder:      Key, Old / New = folder paths
#   check  - a tick box control:  Box, Old / New = $true/$false
function Add-UndoAction {
  param([string]$Kind, [string]$Name, [hashtable]$Data)
  if ($script:undoApplying -or $null -eq $script:undoStack) {
    return
  }
  $entry = @{ Kind = $Kind; Name = $Name; Time = [datetime]::MinValue }
  foreach ($key in $Data.Keys) { $entry[$key] = $Data[$key] }
  $script:undoStack.Add($entry)
  if ($script:undoStack.Count -gt 200) {
    $script:undoStack.RemoveAt(0)
  }
  $script:redoStack.Clear()
  Update-UndoButtons
}

# Applies one step backwards (Undo) or forwards (Redo). Returns a short description.
function Invoke-UndoEntry {
  param($Entry, [bool]$Redo)
  $value = if ($Redo) { $Entry.New } else { $Entry.Old }
  switch ($Entry.Kind) {
    'ticks' {
      $script:homeChecked.Clear()
      foreach ($path in @($value)) { [void]$script:homeChecked.Add([string]$path) }
      $homeFileList.Invalidate()
      Update-HomeCheckedStatus
      return "$($Entry.Name): $(@($value).Count) ticked"
    }
    'folder' {
      Set-SectionFolder $Entry.Key ([string]$value)
      return "$($Entry.Name) is now $value"
    }
    'check' {
      if ($Entry.Box.IsDisposed) { return $null }
      $Entry.Box.Checked = [bool]$value
      return "$($Entry.Name) is now $(if ($value) { 'ticked' } else { 'not ticked' })"
    }
    default {
      if ($Entry.Box.IsDisposed) { return $null }
      $Entry.Box.Text = [string]$value
      $script:undoLastText[$Entry.Box] = [string]$value
      if ($Entry.Box.Visible -and $Entry.Box.Enabled) {
        $Entry.Box.Focus()
        $Entry.Box.SelectionStart = $Entry.Box.Text.Length
      }
      return "$($Entry.Name) is now '$value'"
    }
  }
}

function Invoke-UndoStep {
  param([bool]$Redo)
  # (Assigned in if/else, not "$x = if ...": that would unroll the list.)
  if ($Redo) {
    $from = $script:redoStack
    $to = $script:undoStack
  } else {
    $from = $script:undoStack
    $to = $script:redoStack
  }
  while ($from.Count -gt 0) {
    $entry = $from[$from.Count - 1]
    $from.RemoveAt($from.Count - 1)
    $script:undoApplying = $true
    try {
      $done = Invoke-UndoEntry $entry $Redo
    } catch {
      $done = $null
      try { Show-SectionMessage ('Could not undo/redo: ' + $_.Exception.Message) $true } catch { }
    } finally {
      $script:undoApplying = $false
    }
    if (-not $done) {
      continue
    }
    $entry.Time = [datetime]::MinValue
    $to.Add($entry)
    $word = if ($Redo) { 'Redo' } else { 'Undo' }
    try { Show-SectionMessage "${word}: $done." } catch { }
    break
  }
  Update-UndoButtons
}

# Tick boxes on the form: a click by the user (box has focus) is one undo step.
$undoCheckChanged = {
  param($sender, $eventArgs)
  if ($script:undoApplying -or -not $sender.Focused -or $sender.Tag -eq 'noUndo') {
    return
  }
  Add-UndoAction 'check' (Get-UndoBoxName $sender) @{ Box = $sender; Old = (-not $sender.Checked); New = $sender.Checked }
}

# ---------------------------------------------------------------------------
# 9. REMEMBER THE FORM: on close/restart the form's state is saved and on the
#    next start it comes back: open tab, window position, Home's ticks, Diagram
#    page state, and typed text (not passwords/secrets, not read-only boxes).
#    Folders, links and the tab bar's show/hide already have their own files.
# ---------------------------------------------------------------------------
$formStateFile = Join-Path $env:LOCALAPPDATA 'IJTC\form-state.json'
# Text boxes that are not restored (saved elsewhere, filled by the form, or one-off).
$formStateSkipBoxes = @('folderBarBox', 'homeRepoBox', 'renameFolderBox', 'accountNameBox', 'homeRepoFilter', 'githubTokenBox', 'sessionCodeBox', 'webpageUrlInputBox', 'deployRepoBox', 'diagramProjectBox', 'diagramPageBox')

function Get-FormStateBoxes {
  $boxes = [ordered]@{}
  foreach ($variable in @(Get-Variable -ErrorAction SilentlyContinue | Sort-Object Name -Unique)) {
    $box = $variable.Value
    if ($box -isnot [System.Windows.Forms.TextBox] -or $box.IsDisposed) { continue }
    if ($formStateSkipBoxes -contains $variable.Name) { continue }
    if ($box.ReadOnly -or $box.Multiline -or $box.UseSystemPasswordChar -or [int]$box.PasswordChar -ne 0) { continue }
    $boxes[$variable.Name] = $box
  }
  return $boxes
}

function Save-FormState {
  try {
    if ($diagramFileGrid -and -not $diagramFileGrid.IsDisposed -and $diagramFileGrid.Visible) {
      [void]$diagramFileGrid.EndEdit()
    }
    $texts = @{}
    $boxes = Get-FormStateBoxes
    foreach ($name in $boxes.Keys) { try { $texts[$name] = [string]$boxes[$name].Text } catch { } }
    $bounds = if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) { $form.Bounds } else { $form.RestoreBounds }
    $state = [ordered]@{
      Tab         = [string]$script:currentSection
      Left        = $bounds.Left
      Top         = $bounds.Top
      HomeChecked = @($script:homeChecked)
      Texts       = $texts
      RelationRepoUrl = [string]$relationRepoBox.Text
      Diagram     = Get-DiagramPageState
    }
    $directory = Split-Path -Parent $formStateFile
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
      New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [IO.File]::WriteAllText($formStateFile, ($state | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
  } catch {
  }
}

function Restore-FormState {
  if (-not (Test-Path -LiteralPath $formStateFile -PathType Leaf)) {
    return
  }
  try {
    $state = [IO.File]::ReadAllText($formStateFile) | ConvertFrom-Json
  } catch {
    return
  }
  $script:formStateRestoring = $true
  $problems = @()
  try {
    if ($state.PSObject.Properties['RelationRepoUrl'] -and $relationRepoBox) {
      $relationRepoBox.Text = [string]$state.RelationRepoUrl
    }
    # Window position, only if it is still on a screen.
    try {
      $point = New-Object System.Drawing.Point([int]$state.Left, [int]$state.Top)
      $onScreen = @([System.Windows.Forms.Screen]::AllScreens | Where-Object { $_.WorkingArea.Contains($point.X + 60, $point.Y + 20) }).Count -gt 0
      if ($onScreen) {
        $form.StartPosition = 'Manual'
        $form.Location = $point
      }
    } catch {
      $problems += 'window position'
    }
    # Home's Upload ticks (only items that still exist).
    try {
      foreach ($path in @($state.HomeChecked)) {
        if ($path -and (Test-Path -LiteralPath ([string]$path))) { [void]$script:homeChecked.Add([string]$path) }
      }
      if ($null -ne $homeFileList) { $homeFileList.Invalidate() }
    } catch {
      $problems += 'ticks'
    }
    # The tab that was open.
    try {
      $tab = [string]$state.Tab
      if ($tab -and $tab -ne $script:currentSection -and $FormLayout.Sections.Contains($tab)) {
        Show-Section $tab
      }
    } catch {
      $problems += 'tab'
    }
    # Typed text, box by box (not an Undo step).
    if ($state.Texts) {
      $boxes = Get-FormStateBoxes
      foreach ($property in @($state.Texts.PSObject.Properties)) {
        try {
          if ($boxes.Contains($property.Name) -and $boxes[$property.Name].Text -ne [string]$property.Value) {
            $script:undoApplying = $true
            $boxes[$property.Name].Text = [string]$property.Value
            if ($null -ne $script:undoLastText) { $script:undoLastText[$boxes[$property.Name]] = [string]$property.Value }
          }
        } catch {
          $problems += $property.Name
        } finally {
          $script:undoApplying = $false
        }
      }
    }
    if ($state.Diagram) {
      try {
        Restore-DiagramPageState $state.Diagram
      } catch {
        $script:diagramEditorStatusLabel.Text = 'Could not restore the Diagram page: ' + $_.Exception.Message
        $script:diagramEditorStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick
        $problems += 'Diagram page'
      }
    }
  } finally {
    $script:formStateRestoring = $false
  }
  if ($script:currentSection -eq 'home' -and (Get-Command Update-HomeCheckedStatus -ErrorAction SilentlyContinue)) {
    Update-HomeCheckedStatus
  }
  if ($problems.Count -gt 0) {
    try { Show-SectionMessage ('Could not bring back: ' + ($problems -join ', ')) $true } catch { }
  }
}

# Saves shortly after a change (tab, ticks), so the state is kept even if the
# window is not closed normally.
function Request-FormStateSave {
  if ($script:formStateRestoring -or -not $form -or -not $form.Visible) {
    return
  }
  if (-not $script:formStateTimer) {
    $script:formStateTimer = New-Object System.Windows.Forms.Timer
    $script:formStateTimer.Interval = 800
    $script:formStateTimer.Add_Tick({
      $script:formStateTimer.Stop()
      Save-FormState
    })
  }
  $script:formStateTimer.Stop()
  $script:formStateTimer.Start()
}

$script:formButtonSoundPending = 0
$script:formButtonSoundHookedButtons = New-Object 'System.Collections.Generic.HashSet[System.Windows.Forms.Button]'
$script:formButtonSoundHookedContainers = New-Object 'System.Collections.Generic.HashSet[System.Windows.Forms.Control]'
$script:formButtonSoundTimer = New-Object System.Windows.Forms.Timer
$script:formButtonSoundTimer.Interval = 250

function Test-FormButtonActionBusy {
  foreach ($job in @(
    $script:homeDownloadJob
    $script:accountSignInProcess
    $script:uploadProcess
    $script:cloudflareJob
    $script:renameJob
    $script:deleteRepoJob
  )) {
    if ($job) {
      return $true
    }
  }
  return [bool]$script:runLocalStarting
}

function Queue-FormButtonCompletionSound {
  $script:formButtonSoundPending++
  $script:formButtonSoundTimer.Stop()
  $script:formButtonSoundTimer.Start()
}

function Register-FormButtonSoundControl {
  param([System.Windows.Forms.Control]$Control)
  if (-not $Control) {
    return
  }
  if ($Control -is [System.Windows.Forms.Button] -and
      $Control.Tag -ne 'noButtonSound' -and
      $script:formButtonSoundHookedButtons.Add($Control)) {
    $Control.Add_Click({ Queue-FormButtonCompletionSound })
  }
  if ($script:formButtonSoundHookedContainers.Add($Control)) {
    $Control.Add_ControlAdded({
      param($sender, $eventArgs)
      Register-FormButtonSoundControl $eventArgs.Control
    })
  }
  foreach ($child in @($Control.Controls)) {
    Register-FormButtonSoundControl $child
  }
}

$script:formButtonSoundTimer.Add_Tick({
  if ($script:formButtonSoundPending -le 0) {
    $script:formButtonSoundTimer.Stop()
    return
  }
  if (Test-FormButtonActionBusy) {
    return
  }
  $script:formButtonSoundPending--
  try {
    Play-NotificationSound
  } catch {
    try {
      Set-Status ('Button action finished, but the notification sound could not play: ' + $_.Exception.Message) $true
    } catch {
    }
  }
  if ($script:formButtonSoundPending -le 0) {
    $script:formButtonSoundTimer.Stop()
  }
})

$FormParts.UndoRedo = {
  $undoButton = New-FormCaptionButton 'undo'
  $redoButton = New-FormCaptionButton 'redo'
  $script:undoStack = New-Object System.Collections.Generic.List[object]
  $script:redoStack = New-Object System.Collections.Generic.List[object]
  $script:undoLastText = @{}
  $script:undoHooked = New-Object System.Collections.Generic.HashSet[object]
  $script:undoApplying = $false
  $undoButton.Add_Click({ Invoke-UndoStep $false })
  $redoButton.Add_Click({ Invoke-UndoStep $true })
  Register-UndoControl $form
  Update-UndoButtons
  # Remember the form (section 9): restore when shown, save on close/restart.
  $form.Add_Load({ Restore-FormState })
  $form.Add_FormClosing({ Save-FormState })
  $form.Add_FormClosed({
    Save-FormState
    Close-NotificationSound
  })
}

# ---------------------------------------------------------------------------
#    Opening the form: first tab, then the window. Run with ". $FormParts.Start"
#    as the last line of the application setup. Tab work needed once the window is
#    up goes in Invoke-FormShown.
# ---------------------------------------------------------------------------
$FormParts.Start = {
  Show-Section $FormLayout.FirstTab
  Register-FormButtonSoundControl $form
  if ($accountDialog) {
    Register-FormButtonSoundControl $accountDialog
  }
  $form.Add_Shown({
    $form.Activate()
    if (Get-Command Invoke-FormShown -ErrorAction SilentlyContinue) {
      Invoke-FormShown
    }
    try {
      Play-NotificationSound
    } catch {
      try {
        Set-Status ('Form is ready, but the notification sound could not play: ' + $_.Exception.Message) $true
      } catch {
      }
    }
  })
  [System.Windows.Forms.Application]::Run($form)
}

if ($env:COMBOX_FORM_ACTION -eq 'shortcut') {
  $env:COMBOX_FORM_ACTION = ''
  try {
    Write-Host ('Shortcut created: ' + (New-ComBoxShortcut))
    exit 0
  } catch {
    Write-Host ('Could not create the desktop shortcut: ' + $_.Exception.Message)
    exit 1
  }
}
$script:githubDirectory = $projectDirectory
if (-not [string]::IsNullOrWhiteSpace($SourceFolder)) {
  $script:githubDirectory = [System.IO.Path]::GetFullPath($SourceFolder)
}
$script:cloudflareDirectory = $projectDirectory
$script:runLocalDirectory = $projectDirectory
$defaultRepositoryUrl = 'https://github.com/jakirfile/RubelApp-Web-Source.git'
$repositorySettingsDirectory = Join-Path $env:LOCALAPPDATA 'IJTC'
$repositorySettingsFile = Join-Path $repositorySettingsDirectory 'github-repository-url.txt'
$uploadErrorLogFile = Join-Path $repositorySettingsDirectory 'github-upload-error.log'
$deployUrlSettingsFile = Join-Path $repositorySettingsDirectory 'latest-deploy-url.txt'
$comboxDataFile = Join-Path $toolDirectory 'FormData'
$comboxDataActiveAppFile = Join-Path $repositorySettingsDirectory 'cloudflare-active-app.txt'
$mainBranch = 'main'
$script:uploadProcess = $null
$script:uploadProgressFile = ''
$script:uploadResultFile = ''
$script:uploadOnlyListFile = ''
$script:uploadCancelled = $false

function Read-SavedRepositoryUrl {
  if (-not (Test-Path -LiteralPath $repositorySettingsFile -PathType Leaf)) {
    return $defaultRepositoryUrl
  }

  $savedUrl = (Get-Content -LiteralPath $repositorySettingsFile -TotalCount 1 -ErrorAction Stop).Trim()
  if (-not (Test-GitHubRepositoryUrl $savedUrl)) {
    throw "Saved GitHub repository URL is invalid. Enter a valid URL in Home and restart. Settings file: $repositorySettingsFile"
  }
  return $savedUrl
}

function Save-RepositoryUrl {
  param([Parameter(Mandatory = $true)][string]$Url)
  if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force -ErrorAction Stop | Out-Null
  }
  Set-Content -LiteralPath $repositorySettingsFile -Value $Url -Encoding UTF8 -ErrorAction Stop
}

function Read-LatestDeployUrl {
  if (-not (Test-Path -LiteralPath $deployUrlSettingsFile -PathType Leaf)) {
    return ''
  }

  $savedUrl = (Get-Content -LiteralPath $deployUrlSettingsFile -TotalCount 1 -ErrorAction Stop).Trim()
  $parsedUrl = $null
  if (-not [Uri]::TryCreate($savedUrl, [UriKind]::Absolute, [ref]$parsedUrl) -or $parsedUrl.Scheme -notin @('http', 'https')) {
    throw "Saved Cloudflare deploy link is invalid: $deployUrlSettingsFile"
  }
  return $savedUrl
}

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,
    [string]$IndexPath,
    [int[]]$AllowedExitCodes = @(0)
  )

  $previousIndex = $env:GIT_INDEX_FILE
  if ($IndexPath) {
    $env:GIT_INDEX_FILE = $IndexPath
  }

  try {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      $gitArguments = @()
      if ($script:githubCredentialUser) {
        $gitArguments += @('-c', "credential.https://github.com.username=$($script:githubCredentialUser)")
      }
      $gitArguments += @('-C', $script:githubDirectory) + $Arguments
      $output = @(& git @gitArguments 2>&1 | ForEach-Object { "$_" })
      $exitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($AllowedExitCodes -notcontains $exitCode) {
      $details = $output -join [Environment]::NewLine
      $command = $Arguments -join ' '
      if ($details) {
        throw "git $command failed (exit code $exitCode).`r`n$details"
      }
      throw "git $command failed (exit code $exitCode)."
    }

    return [pscustomobject]@{
      ExitCode = $exitCode
      Output   = $output
    }
  } finally {
    if ($null -eq $previousIndex) {
      Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue
    } else {
      $env:GIT_INDEX_FILE = $previousIndex
    }
  }
}

# Starts a program with no console window at all (-WindowStyle Hidden is ignored
# when Windows Terminal is the default console, which leaves a window in the taskbar).
function Start-NoWindowProcess {
  param(
    [string]$FilePath,
    [string]$Arguments,
    [string]$WorkingDirectory,
    [string]$GitHubUser
  )
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $FilePath
  $startInfo.Arguments = $Arguments
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  if ($WorkingDirectory) {
    $startInfo.WorkingDirectory = $WorkingDirectory
  }
  if ($GitHubUser) {
    $startInfo.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $startInfo.EnvironmentVariables['GCM_INTERACTIVE'] = 'never'
    $startInfo.EnvironmentVariables['GIT_CONFIG_COUNT'] = '1'
    $startInfo.EnvironmentVariables['GIT_CONFIG_KEY_0'] = 'credential.https://github.com.username'
    $startInfo.EnvironmentVariables['GIT_CONFIG_VALUE_0'] = $GitHubUser
  }
  $process = [System.Diagnostics.Process]::Start($startInfo)
  if (-not $process) {
    throw "Could not start $FilePath."
  }
  return $process
}

function New-TemporaryIndexPath {
  return Join-Path ([IO.Path]::GetTempPath()) ('ijtc-upload-' + [Guid]::NewGuid().ToString('N') + '.index')
}

function Test-GitHubRepositoryUrl {
  param([string]$Url)
  return $Url -match '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?/?$'
}

function Get-DisplayRepositoryUrl {
  param([string]$Url)
  return $Url -replace '\.git/?$', ''
}

function Write-UploadProgress {
  param(
    [string]$Message,
    [System.ComponentModel.BackgroundWorker]$Worker,
    [string]$ProgressFile
  )

  if ($Worker) {
    $Worker.ReportProgress(0, $Message)
  } elseif ($ProgressFile) {
    $temporaryFile = $ProgressFile + '.tmp'
    [System.IO.File]::WriteAllText($temporaryFile, $Message, [System.Text.Encoding]::UTF8)
    Move-Item -LiteralPath $temporaryFile -Destination $ProgressFile -Force -ErrorAction Stop
  }
}

# Uploads the source folder to the main branch. With -OnlyPaths (top-level files
# or folders of the source folder) only those are replaced on GitHub; every other
# file in the repository stays as it is.
function Invoke-UploadSnapshot {
  param(
    [string]$RepositoryUrl,
    [System.ComponentModel.BackgroundWorker]$Worker,
    [string]$ProgressFile,
    [string[]]$OnlyPaths = @()
  )

  $indexPath = New-TemporaryIndexPath
  $temporaryGitDirectory = ''
  $previousGitDirectory = $env:GIT_DIR
  $previousGitWorkTree = $env:GIT_WORK_TREE
  try {
    if (-not (Test-Path -LiteralPath (Join-Path $script:githubDirectory '.git'))) {
      $temporaryGitDirectory = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-upload-git-' + [Guid]::NewGuid().ToString('N'))
      $initOutput = @(& git -C $script:githubDirectory init --bare --quiet $temporaryGitDirectory 2>&1 | ForEach-Object { "$_" })
      $initExitCode = $LASTEXITCODE
      if ($initExitCode -ne 0) {
        $details = $initOutput -join [Environment]::NewLine
        if ($details) {
          throw "Could not create temporary Git metadata for the upload (exit code $initExitCode).`r`n$details"
        }
        throw "Could not create temporary Git metadata for the upload (exit code $initExitCode)."
      }
      $env:GIT_DIR = $temporaryGitDirectory
      $env:GIT_WORK_TREE = $script:githubDirectory
    }

    Write-UploadProgress -Message 'Checking Git and GitHub sign-in...' -Worker $Worker -ProgressFile $ProgressFile
    $null = Invoke-Git -Arguments @('--version')
    $null = Invoke-Git -Arguments @('credential-manager', '--version')

    Write-UploadProgress -Message 'Checking the GitHub main branch...' -Worker $Worker -ProgressFile $ProgressFile
    $remoteRefs = @((Invoke-Git -Arguments @('ls-remote', '--heads', $RepositoryUrl, "refs/heads/$mainBranch")).Output)
    $remoteCommit = ''
    if ($remoteRefs.Count -gt 0 -and $remoteRefs[0] -match '^([0-9a-fA-F]+)\s') {
      $remoteCommit = $Matches[1]
      Write-UploadProgress -Message 'Fetching the current main branch...' -Worker $Worker -ProgressFile $ProgressFile
      try {
        $null = Invoke-Git -Arguments @('fetch', '--no-tags', $RepositoryUrl, "refs/heads/$mainBranch")
      } catch {
        $firstFetchError = $_.Exception.Message
        Write-UploadProgress -Message 'The main-branch fetch failed; retrying once...' -Worker $Worker -ProgressFile $ProgressFile
        Start-Sleep -Seconds 2
        try {
          $null = Invoke-Git -Arguments @('fetch', '--no-tags', $RepositoryUrl, "refs/heads/$mainBranch")
        } catch {
          throw "Could not fetch the current main branch after retry. First attempt: $firstFetchError`r`nRetry: $($_.Exception.Message)"
        }
      }
      $remoteCommit = ((Invoke-Git -Arguments @('rev-parse', 'FETCH_HEAD')).Output | Select-Object -First 1).Trim()
      $null = Invoke-Git -Arguments @('read-tree', $remoteCommit) -IndexPath $indexPath
    } else {
      $null = Invoke-Git -Arguments @('read-tree', '--empty') -IndexPath $indexPath
    }

    $OnlyPaths = @($OnlyPaths | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim().Replace('\', '/') })
    if ($OnlyPaths.Count -gt 0) {
      Write-UploadProgress -Message "Preparing the selected items ($($OnlyPaths.Count))..." -Worker $Worker -ProgressFile $ProgressFile
      foreach ($path in $OnlyPaths) {
        $null = Invoke-Git -Arguments @('rm', '-r', '-f', '--cached', '--ignore-unmatch', '--', $path) -IndexPath $indexPath
        # A file or folder ticked on purpose is uploaded even if .gitignore lists it.
        $null = Invoke-Git -Arguments @('add', '-f', '--all', '--', $path) -IndexPath $indexPath
      }
    } else {
    Write-UploadProgress -Message 'Preparing the fresh project snapshot...' -Worker $Worker -ProgressFile $ProgressFile
    $null = Invoke-Git -Arguments @('rm', '-r', '-f', '--cached', '--ignore-unmatch', '--', '.') -IndexPath $indexPath
    $null = Invoke-Git -Arguments @('add', '--all', '--', '.') -IndexPath $indexPath

    $forcedPaths = @()
    foreach ($path in @('Data', 'File', 'public', 'node_modules', '.next', 'out')) {
      if (Test-Path -LiteralPath (Join-Path $script:githubDirectory $path) -PathType Container) {
        $forcedPaths += $path
      }
    }
    if ($forcedPaths.Count -gt 0) {
      Write-UploadProgress -Message ('Including ignored folders: ' + ($forcedPaths -join ', ')) -Worker $Worker -ProgressFile $ProgressFile
      $null = Invoke-Git -Arguments (@('add', '-f', '--all', '--') + $forcedPaths) -IndexPath $indexPath
    }
    }

    if ($remoteCommit) {
      $comparison = Invoke-Git -Arguments @('diff', '--cached', '--quiet', $remoteCommit, '--') -IndexPath $indexPath -AllowedExitCodes @(0, 1)
      if ($comparison.ExitCode -eq 0) {
        return "GitHub already matches the fresh project snapshot: $(Get-DisplayRepositoryUrl $RepositoryUrl)/tree/$mainBranch"
      }
    }

    $tree = ((Invoke-Git -Arguments @('write-tree') -IndexPath $indexPath).Output | Select-Object -First 1).Trim()
    if (-not $tree) {
      throw 'Git could not create the upload tree.'
    }

    $commitArguments = @(
      '-c', 'user.name=jakirfile',
      '-c', 'user.email=jakirfile@users.noreply.github.com',
      'commit-tree', $tree
    )
    if ($remoteCommit) {
      $commitArguments += @('-p', $remoteCommit)
    }
    $commitArguments += @('-m', $(if ($OnlyPaths.Count -gt 0) { 'Upload selected files: ' + ($OnlyPaths -join ', ') } else { 'Upload project files' }))
    $uploadCommit = ((Invoke-Git -Arguments $commitArguments -IndexPath $indexPath).Output | Select-Object -First 1).Trim()
    if (-not $uploadCommit) {
      throw 'Git could not create the upload commit.'
    }

    Write-UploadProgress -Message 'Uploading the fresh project snapshot to the GitHub repository root...' -Worker $Worker -ProgressFile $ProgressFile
    $null = Invoke-Git -Arguments @('push', $RepositoryUrl, "$uploadCommit`:refs/heads/$mainBranch")

    Write-UploadProgress -Message 'Verifying the fresh snapshot on GitHub...' -Worker $Worker -ProgressFile $ProgressFile
    $verifiedRefs = @((Invoke-Git -Arguments @('ls-remote', '--heads', $RepositoryUrl, "refs/heads/$mainBranch")).Output)
    if ($verifiedRefs.Count -eq 0 -or $verifiedRefs[0] -notmatch ('^' + [regex]::Escape($uploadCommit) + '\s')) {
      throw "Upload verification failed. Check the GitHub main branch for commit $uploadCommit."
    }

    return "Fresh GitHub upload verified: commit $uploadCommit`r`n$(Get-DisplayRepositoryUrl $RepositoryUrl)/tree/$mainBranch"
  } finally {
    Remove-Item -LiteralPath $indexPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath ($indexPath + '.lock') -Force -ErrorAction SilentlyContinue
    if ($null -eq $previousGitDirectory) {
      Remove-Item Env:GIT_DIR -ErrorAction SilentlyContinue
    } else {
      $env:GIT_DIR = $previousGitDirectory
    }
    if ($null -eq $previousGitWorkTree) {
      Remove-Item Env:GIT_WORK_TREE -ErrorAction SilentlyContinue
    } else {
      $env:GIT_WORK_TREE = $previousGitWorkTree
    }
    if ($temporaryGitDirectory -and (Test-Path -LiteralPath $temporaryGitDirectory -PathType Container)) {
      Remove-Item -LiteralPath $temporaryGitDirectory -Recurse -Force -ErrorAction Stop
    }
  }
}

$script:cloudflareDeploymentSource = @'
@echo off
setlocal
if defined RUBELAPP_PROJECT_DIR (cd /d "%RUBELAPP_PROJECT_DIR%") else (cd /d "%~dp0..")
if errorlevel 1 (
  echo Could not open the project folder.
  exit /b 1
)

set "WORKER_NAME=rubelapp"
if not "%~2"=="" set "WORKER_NAME=%~2"
set "DEFAULT_DEPLOY_URL=https://%WORKER_NAME%.jakirfile.workers.dev"
set "DEPLOY_URL=%DEFAULT_DEPLOY_URL%"
set "LINK_DIRECTORY=%LOCALAPPDATA%\IJTC"
set "LINK_FILE=%LINK_DIRECTORY%\latest-deploy-url.txt"
set "LEGACY_LINK_FILE=%LOCALAPPDATA%\RRE\latest-deploy-url.txt"

where node >nul 2>&1
if errorlevel 1 (
  echo Node.js is not installed or is not available on PATH.
  exit /b 1
)

if not exist "%LINK_FILE%" if exist "%LEGACY_LINK_FILE%" (
  if not exist "%LINK_DIRECTORY%" mkdir "%LINK_DIRECTORY%"
  if errorlevel 1 (
    echo Could not create the folder for saving the latest deploy link.
    exit /b 1
  )
  copy /y "%LEGACY_LINK_FILE%" "%LINK_FILE%" >nul
  if errorlevel 1 (
    echo Could not migrate the saved Cloudflare deploy link.
    exit /b 1
  )
)

rem Projects that keep their pages ready in "public" (like All-Web) have no prepare step.
if exist "scripts\prepare-static-assets.js" (
  echo Preparing static frontend files...
  node scripts\prepare-static-assets.js
  if errorlevel 1 (
    echo Could not prepare the static frontend files.
    exit /b 1
  )
)

echo Deploying worker %WORKER_NAME% to %DEFAULT_DEPLOY_URL%...
call npx.cmd --yes wrangler@latest deploy --config "%CD%\wrangler.jsonc" --name %WORKER_NAME%
if errorlevel 1 (
  echo Cloudflare deployment failed. Check the Wrangler output above.
  exit /b 1
)

if exist "%LINK_FILE%" (
  set /p "DEPLOY_URL="<"%LINK_FILE%"
)
if not defined DEPLOY_URL set "DEPLOY_URL=%DEFAULT_DEPLOY_URL%"
if not exist "%LINK_FILE%" (
  if not exist "%LINK_DIRECTORY%" mkdir "%LINK_DIRECTORY%"
  if errorlevel 1 (
    echo Could not create the folder for saving the latest deploy link.
    goto :SHOW_DEPLOY_LINK
  )
  >"%LINK_FILE%" echo %DEPLOY_URL%
  if errorlevel 1 echo Could not save the latest deploy link.
)

:SHOW_DEPLOY_LINK
if /I "%~1"=="/noninteractive" (
  echo Cloudflare deployment complete.
  setlocal EnableDelayedExpansion
  echo Latest deploy link: !DEPLOY_URL!
  endlocal
  exit /b 0
)
echo.
echo Cloudflare deployment complete.
setlocal EnableDelayedExpansion
echo Latest deploy link: !DEPLOY_URL!
endlocal
echo.
echo 1. Open the latest deploy link
echo 2. Enter and save a new latest link
set "CHOICE="
set /p "CHOICE=Choose 1 or 2: "
if "%CHOICE%"=="1" (
  setlocal EnableDelayedExpansion
  start "" "!DEPLOY_URL!"
  endlocal
  if errorlevel 1 (
    echo Could not open the deploy link.
    exit /b 1
  )
  exit /b 0
)
if "%CHOICE%"=="2" goto :ENTER_NEW_LINK
echo Please choose 1 or 2.
goto :SHOW_DEPLOY_LINK

:ENTER_NEW_LINK
set "NEW_DEPLOY_URL="
set /p "NEW_DEPLOY_URL=Enter the new deploy URL: "
if not defined NEW_DEPLOY_URL (
  echo The URL cannot be empty.
  goto :SHOW_DEPLOY_LINK
)
if /i "%NEW_DEPLOY_URL:~0,8%"=="https://" goto :SAVE_NEW_LINK
if /i "%NEW_DEPLOY_URL:~0,7%"=="http://" goto :SAVE_NEW_LINK
echo Enter a URL that starts with http:// or https://.
goto :ENTER_NEW_LINK

:SAVE_NEW_LINK
if not exist "%LINK_DIRECTORY%" mkdir "%LINK_DIRECTORY%"
if errorlevel 1 (
  echo Could not create the folder for saving the latest deploy link.
  exit /b 1
)
setlocal EnableDelayedExpansion
>"!LINK_FILE!" echo(!NEW_DEPLOY_URL!
if errorlevel 1 (
  endlocal
  echo Could not save the latest deploy link.
  exit /b 1
)
endlocal
set "DEPLOY_URL="
set /p "DEPLOY_URL="<"%LINK_FILE%"
goto :SHOW_DEPLOY_LINK

goto :EOF

/*__CLOUDFLARE_WORKER_TEMPLATE__*/
'use strict';

const { withRuntimeEnv } = require('./api/_lib/runtime-env');
const { hasValidSession } = require('./api/_lib/auth');
const auth = require('./api/auth');
const banks = require('./api/banks');
const bankFiles = require('./api/bank-files');
const buttons = require('./api/buttons');
const contacts = require('./api/contacts');
const entries = require('./api/entries');
const fields = require('./api/fields');
const jobs = require('./api/jobs');
const landlist = require('./api/landlist');
const products = require('./api/products');
const questions = require('./api/questions');
const registerPhoto = require('./api/register-photo');
const registerUser = require('./api/register-user');
const saveLandlist = require('./api/save-landlist');
const sessionOut = require('./api/session-out');
const sms = require('./api/sms');
const trips = require('./api/trips');
const tripFiles = require('./api/trip-files');
const setups = require('./api/setups');
const students = require('./api/students');
const units = require('./api/units');
const users = require('./api/users');
const vehicles = require('./api/vehicles');
const work = require('./api/work');

const MAX_REQUEST_BYTES = 6 * 1024 * 1024;
const SESSION_PATHS = new Set(['/Session', '/Session/index.html']);
const apiHandlers = new Map([
  ['/api/auth', auth],
  ['/api/login', auth],
  ['/api/logout', auth],
  ['/api/session', auth],
  ['/api/session-out', sessionOut],
  ['/api/complete-login', auth],
  ['/api/banks', banks],
  ['/api/bank-files', bankFiles],
  ['/api/buttons', buttons],
  ['/api/contacts', contacts],
  ['/api/entries', entries],
  ['/api/fields', fields],
  ['/api/jobs', jobs],
  ['/api/landlist', landlist],
  ['/api/logics', fields],
  ['/api/products', products],
  ['/api/questions', questions],
  ['/api/register-photo', registerPhoto],
  ['/api/register-user', registerUser],
  ['/api/save-landlist', saveLandlist],
  ['/api/sms', sms],
  ['/api/trips', trips],
  ['/api/trip-files', tripFiles],
  ['/api/setups', setups],
  ['/api/students', students],
  ['/api/units', units],
  ['/api/users', users],
  ['/api/vehicles', vehicles],
  ['/api/work', work],
]);

const redirects = new Map([
  ['/', ['/Session', 302]],
  ['/Session/index.html', ['/Session', 308]],
  ['/Session/', ['/Session', 308]],
  ['/Question/index.html', ['/QuestionList', 308]],
  ['/Question/', ['/QuestionList', 308]],
  ['/Question', ['/QuestionList', 308]],
  ['/QuestionList/index.html', ['/QuestionList', 308]],
  ['/QuestionList/', ['/QuestionList', 308]],
  ['/Survey/index.html', ['/SurveyList', 308]],
  ['/Survey/', ['/SurveyList', 308]],
  ['/Survey', ['/SurveyList', 308]],
  ['/SurveyList/index.html', ['/SurveyList', 308]],
  ['/SurveyList/', ['/SurveyList', 308]],
  ['/Land/index.html', ['/SurveyList', 308]],
  ['/Land/', ['/SurveyList', 308]],
  ['/Land', ['/SurveyList', 308]],
  ['/data/Login', ['/Login', 308]],
  ['/data/Login/', ['/Login', 308]],
  ['/data/Login/index.html', ['/Login', 308]],
  ['/Login/index.html', ['/Login', 308]],
  ['/Claim/index.html', ['/Claim', 308]],
  ['/Claim/', ['/Claim', 308]],
  ['/Register/index.html', ['/Login?register=1', 308]],
  ['/Register/', ['/Login?register=1', 308]],
  ['/Register', ['/Login?register=1', 308]],
  ['/AddTrip/index.html', ['/TripList/index.html?view=trip', 308]],
  ['/AddTrip/', ['/TripList/index.html?view=trip', 308]],
  ['/AddTrip', ['/TripList/index.html?view=trip', 308]],
  ['/Contact/index.html', ['/TripList/index.html?view=contact', 308]],
  ['/Contact/', ['/TripList/index.html?view=contact', 308]],
  ['/Contact', ['/TripList/index.html?view=contact', 308]],
  ['/TripList/add-trip.html', ['/TripList/index.html?view=trip', 308]],
  ['/TripList/add-contact.html', ['/TripList/index.html?view=contact', 308]],
  ['/Login/', ['/Login', 308]],
  ['/work.html', ['/SurveyList', 308]],
  ['/work', ['/SurveyList', 308]],
  ['/work/', ['/SurveyList', 308]],
  ['/Work/index.html', ['/WorkList', 308]],
  ['/Work/', ['/WorkList', 308]],
  ['/Work', ['/WorkList', 308]],
  ['/WorkList/index.html', ['/WorkList', 308]],
  ['/WorkList/', ['/WorkList', 308]],
  ['/User/index.html', ['/UserList', 308]],
  ['/User/', ['/UserList', 308]],
  ['/User', ['/UserList', 308]],
  ['/UserList/index.html', ['/UserList', 308]],
  ['/UserList/', ['/UserList', 308]],
  ['/Vehicle/index.html', ['/VehicleList', 308]],
  ['/Vehicle/', ['/VehicleList', 308]],
  ['/Vehicle', ['/VehicleList', 308]],
  ['/VehicleList/index.html', ['/VehicleList', 308]],
  ['/VehicleList/', ['/VehicleList', 308]],
  ['/BankList/index.html', ['/BankList', 308]],
  ['/BankList/', ['/BankList', 308]],
  ['/FieldList/index.html', ['/FieldList', 308]],
  ['/FieldList/', ['/FieldList', 308]],
  ['/FieldList/LogicList.html', ['/FieldList', 308]],
  ['/LogicList/index.html', ['/FieldList', 308]],
  ['/LogicList/', ['/FieldList', 308]],
  ['/LogicList', ['/FieldList', 308]],
  ['/SMS/index.html', ['/SMSList', 308]],
  ['/SMS/', ['/SMSList', 308]],
  ['/SMS', ['/SMSList', 308]],
  ['/SMSList/index.html', ['/SMSList', 308]],
  ['/SMSList/', ['/SMSList', 308]],
  ['/Institute/index.html', ['/Institute', 308]],
  ['/Institute/', ['/Institute', 308]],
  ['/SetupList', ['/Institute', 308]],
  ['/SetupList/', ['/Institute', 308]],
  ['/SetupList/index.html', ['/Institute', 308]],
  ['/UnitList/index.html', ['/UnitList', 308]],
  ['/UnitList/', ['/UnitList', 308]],
  ['/ContactList/index.html', ['/ContactList', 308]],
  ['/ContactList/', ['/ContactList', 308]],
  ['/JobList/index.html', ['/JobList', 308]],
  ['/JobList/', ['/JobList', 308]],
]);

function queryValues(searchParams) {
  const values = {};
  for (const [key, value] of searchParams) {
    if (Object.hasOwn(values, key)) {
      values[key] = Array.isArray(values[key])
        ? [...values[key], value]
        : [values[key], value];
    } else {
      values[key] = value;
    }
  }
  return values;
}

async function readRequestBody(request) {
  const declaredLength = Number(request.headers.get('content-length') || 0);
  if (declaredLength > MAX_REQUEST_BYTES) {
    return { error: new Response('Request body is too large.', { status: 413 }) };
  }
  if (!request.body) return { body: Buffer.alloc(0) };

  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_REQUEST_BYTES) {
        await reader.cancel();
        return { error: new Response('Request body is too large.', { status: 413 }) };
      }
      chunks.push(Buffer.from(value));
    }
  } finally {
    reader.releaseLock();
  }
  return { body: Buffer.concat(chunks, size) };
}

function makeResponse() {
  const headers = new Headers();
  let status = 200;
  let body = null;
  let ended = false;

  return {
    headers,
    get statusCode() {
      return status;
    },
    set statusCode(value) {
      status = value;
    },
    setHeader(name, value) {
      headers.delete(name);
      for (const item of Array.isArray(value) ? value : [value]) {
        headers.append(name, String(item));
      }
    },
    end(value) {
      body = value === undefined ? null : value;
      ended = true;
    },
    toResponse() {
      if (!ended) throw new Error('API handler did not complete its response');
      return new Response(status === 204 || status === 304 ? null : body, {
        status,
        headers,
      });
    },
  };
}

function makeRequest(request, url, body) {
  const headers = Object.fromEntries(request.headers.entries());
  headers.host = url.host;
  headers['x-forwarded-host'] = url.host;
  headers['x-forwarded-proto'] = url.protocol.slice(0, -1);
  headers['x-forwarded-for'] = request.headers.get('cf-connecting-ip') || '';
  const contentType = request.headers.get('content-type') || '';
  const isJson = /(?:application\/json|[\w.+-]+\/[\w.+-]+\+json)/i.test(contentType);
  const req = {
    method: request.method,
    url: `${url.pathname}${url.search}`,
    originalUrl: `${url.pathname}${url.search}`,
    headers,
    query: queryValues(url.searchParams),
    socket: { remoteAddress: headers['x-forwarded-for'] },
    rawBody: body,
  };
  if (body.length && isJson) req.body = body.toString('utf8');
  return req;
}

function requireSessionForPage(response, request, url, env) {
  if (!response.headers.get('content-type')?.includes('text/html')) {
    return response;
  }

  if (
    !SESSION_PATHS.has(url.pathname)
    && !withRuntimeEnv(env, () => hasValidSession({
      headers: { cookie: request.headers.get('cookie') || '' },
    }))
  ) {
    return new Response(null, {
      status: 302,
      headers: {
        'Cache-Control': 'no-store',
        Location: new URL('/Session?expired=1', url.origin).toString(),
      },
    });
  }

  const headers = new Headers(response.headers);
  headers.set('Cache-Control', 'private, no-store');
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

async function handleApi(request, env, url, handler) {
  const read = await readRequestBody(request);
  if (read.error) return read.error;

  const req = makeRequest(request, url, read.body);
  const isSessionRoute = handler === auth &&
    ['login', 'session'].includes(String(req.query.action || ({
      '/api/login': 'login',
      '/api/session': 'session',
    })[url.pathname] || ''));
  if (!isSessionRoute && !withRuntimeEnv(env, () => hasValidSession(req))) {
    return Response.json(
      { error: 'আগে Session সম্পন্ন করুন।' },
      { status: 401, headers: { 'Cache-Control': 'no-store' } }
    );
  }

  const res = makeResponse();
  try {
    await withRuntimeEnv(env, () => handler(req, res));
    return res.toResponse();
  } catch (error) {
    console.error('API request failed:', url.pathname, error);
    return Response.json(
      { error: 'সেবা সাময়িকভাবে চালু নেই।' },
      { status: 500, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}

async function fetchRequest(request, env) {
  const url = new URL(request.url);
  let decodedPath;
  try {
    decodedPath = decodeURIComponent(url.pathname);
  } catch {
    return new Response(null, { status: 404 });
  }
  if (decodedPath.startsWith('/__local_data/')) {
    return new Response(null, { status: 404 });
  }

  const redirect = redirects.get(url.pathname);
  if (redirect) {
    const [destination, status] = redirect;
    const redirectUrl = new URL(destination, url.origin);
    if (redirectUrl.pathname === '/TripList/index.html' && redirectUrl.searchParams.has('view')) {
      const view = redirectUrl.searchParams.get('view');
      redirectUrl.search = url.search;
      redirectUrl.searchParams.set('view', view);
    } else if (['/VehicleList', '/QuestionList', '/UserList', '/WorkList', '/SurveyList']
      .includes(redirectUrl.pathname)) {
      redirectUrl.search = url.search;
    }
    return Response.redirect(redirectUrl, status);
  }

  const handler = apiHandlers.get(url.pathname);
  if (handler) return handleApi(request, env, url, handler);
  if (url.pathname.startsWith('/api/')) {
    return Response.json(
      { error: 'অনুরোধ করা API পাওয়া যায়নি।' },
      { status: 404, headers: { 'Cache-Control': 'no-store' } }
    );
  }

  if (
    (request.method === 'GET' || request.method === 'HEAD')
    && !url.pathname.split('/').pop().includes('.')
  ) {
    const pageUrl = new URL(url);
    pageUrl.pathname = `${url.pathname.replace(/\/?$/, '/')}index.html`;
    const page = await env.ASSETS.fetch(new Request(pageUrl, request));
    if (page.status !== 404) {
      return requireSessionForPage(page, request, url, env);
    }
  }
  const response = await env.ASSETS.fetch(request);
  return requireSessionForPage(response, request, url, env);
}

module.exports = {
  async fetch(request, env) {
    return fetchRequest(request, env);
  },
};
/*__END_CLOUDFLARE_WORKER_TEMPLATE__*/
'@

function New-CloudflareDeploymentScript {
  $path = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-cloudflare-deploy-' + [Guid]::NewGuid().ToString('N') + '.bat')
  try {
    [IO.File]::WriteAllText($path, $script:cloudflareDeploymentSource, (New-Object System.Text.UTF8Encoding($false)))
  } catch {
    $writeError = $_.Exception.Message
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      try {
        Remove-Item -LiteralPath $path -Force -ErrorAction Stop
      } catch {
        $writeError += "`r`nCould not remove the incomplete temporary script: $($_.Exception.Message)"
      }
    }
    throw "Could not create the temporary Cloudflare deployment script: $writeError"
  }
  return $path
}

# Window, title bar, Minimize/Restart/Close/Shortcut buttons, outer border: Form.bat
. $FormParts.Window

# ---------------------------------------------------------------------------
# GitHub account button: chooses which GitHub account every git call of this
# form uses (preview, upload, Delete-Repo). Sign-in is handled by Git
# Credential Manager; the chosen account is passed to git as
# credential.https://github.com.username through GIT_CONFIG_* variables.
$githubAccountFile = Join-Path $repositorySettingsDirectory 'github-account.txt'
$githubAccountButton = New-FormCaptionButton 'account'

function Read-GitHubAccount {
  try {
    if (Test-Path -LiteralPath $githubAccountFile -PathType Leaf) {
      return ([System.IO.File]::ReadAllText($githubAccountFile)).Trim()
    }
  } catch {
  }
  return ''
}

function Save-GitHubAccount {
  param([string]$User)
  if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($githubAccountFile, $User, (New-Object System.Text.UTF8Encoding($false)))
}

function Set-GitHubAccount {
  param([string]$User)
  $script:githubAccount = $User
  if ($User) {
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', '1', 'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_KEY_0', 'credential.https://github.com.username', 'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_VALUE_0', $User, 'Process')
    $captionTitle.Text = "$($FormLayout.Title)   |   $User"
    $toolTip.SetToolTip($githubAccountButton, "GitHub account: $User (click to change)")
  } else {
    foreach ($name in @('GIT_CONFIG_COUNT', 'GIT_CONFIG_KEY_0', 'GIT_CONFIG_VALUE_0')) {
      [Environment]::SetEnvironmentVariable($name, $null, 'Process')
    }
    $captionTitle.Text = $FormLayout.Title
    $toolTip.SetToolTip($githubAccountButton, 'GitHub account: not chosen (click to sign in)')
  }
}

function Invoke-CredentialManager {
  param([string[]]$Arguments)
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = @(& git credential-manager @Arguments 2>&1 | ForEach-Object { "$_" })
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

function Get-GitHubSignedInAccounts {
  $result = Invoke-CredentialManager @('github', 'list')
  if ($result.ExitCode -ne 0) {
    throw ('Could not list GitHub accounts: ' + ($result.Output -join ' '))
  }
  return @($result.Output | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '\s' })
}

function Get-GitHubCredentialUser {
  param([Parameter(Mandatory = $true)][string]$RepositoryUrl)

  if ($script:githubAccount) {
    return [string]$script:githubAccount
  }
  if ($RepositoryUrl -notmatch '^https://github\.com/([A-Za-z0-9_.-]+)/') {
    throw 'Enter a valid HTTPS GitHub repository URL.'
  }
  $repositoryOwner = $Matches[1]
  $signedInAccounts = @(Get-GitHubSignedInAccounts)
  if ($signedInAccounts -contains $repositoryOwner) {
    return $repositoryOwner
  }
  if ($signedInAccounts.Count -eq 1) {
    return [string]$signedInAccounts[0]
  }
  if ($signedInAccounts.Count -gt 1) {
    throw 'Select the GitHub account with access to this repository, then try again.'
  }
  throw 'Sign in to GitHub with an account that can access this repository, then try again.'
}

Set-GitHubAccount (Read-GitHubAccount)

# Account dialog
$accountDialog = New-Object System.Windows.Forms.Form
$accountDialog.Text = 'GitHub account'
$accountDialog.StartPosition = 'CenterParent'
$accountDialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$accountDialog.MaximizeBox = $false
$accountDialog.MinimizeBox = $false
$accountDialog.ShowInTaskbar = $false
$accountDialog.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$accountDialog.ClientSize = New-Object System.Drawing.Size(520, 330)
$accountDialog.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$accountDialog.BackColor = [System.Drawing.Color]::White

function Add-DialogControl {
  param($Control, [int]$X, [int]$Y, [int]$Width, [int]$Height)
  $Control.Location = New-Object System.Drawing.Point($X, $Y)
  $Control.Size = New-Object System.Drawing.Size($Width, $Height)
  $accountDialog.Controls.Add($Control)
  return $Control
}

function New-DialogButton {
  param([string]$Text, [int]$X, [int]$Y, [int]$Width = 120, [bool]$Primary = $false)
  $button = New-Object System.Windows.Forms.Button
  $button.Text = $Text
  $button.Cursor = [System.Windows.Forms.Cursors]::Hand
  if ($Primary) {
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = [System.Drawing.Color]::FromArgb(38, 105, 176)
    $button.ForeColor = [System.Drawing.Color]::White
  }
  return (Add-DialogControl $button $X $Y $Width 32)
}

$accountActiveTitle = New-Object System.Windows.Forms.Label
$accountActiveTitle.Text = 'Account used by this form'
$accountActiveTitle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$accountActiveTitle.ForeColor = [System.Drawing.Color]::FromArgb(38, 105, 176)
$null = Add-DialogControl $accountActiveTitle 16 14 300 22
$accountActiveLabel = New-Object System.Windows.Forms.Label
$accountActiveLabel.ForeColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$null = Add-DialogControl $accountActiveLabel 16 38 360 22
$accountClearButton = New-DialogButton 'Use default' 384 32 120

$accountListTitle = New-Object System.Windows.Forms.Label
$accountListTitle.Text = 'Signed-in GitHub accounts on this PC'
$accountListTitle.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
$null = Add-DialogControl $accountListTitle 16 76 360 22
$accountList = New-Object System.Windows.Forms.ListBox
$accountList.IntegralHeight = $false
$null = Add-DialogControl $accountList 16 100 360 100
$accountUseButton = New-DialogButton 'Use selected' 384 100 120 $true
$accountSignOutButton = New-DialogButton 'Sign out' 384 138 120
$accountRefreshButton = New-DialogButton 'Refresh' 384 176 120

$accountNameTitle = New-Object System.Windows.Forms.Label
$accountNameTitle.Text = 'Add account (GitHub user name)'
$accountNameTitle.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
$null = Add-DialogControl $accountNameTitle 16 214 360 22
$accountNameBox = New-Object System.Windows.Forms.TextBox
$null = Add-DialogControl $accountNameBox 16 239 360 26
$accountSignInButton = New-DialogButton 'Sign in' 384 236 120 $true

$accountStatusLabel = New-Object System.Windows.Forms.Label
$accountStatusLabel.AutoEllipsis = $true
$accountStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
$null = Add-DialogControl $accountStatusLabel 16 286 360 24
$accountCloseButton = New-DialogButton 'Close' 384 284 120
$accountDialog.CancelButton = $accountCloseButton
$accountCloseButton.Add_Click({ $accountDialog.Close() })

function Set-AccountStatus {
  param([string]$Text, [bool]$IsError = $false)
  $accountStatusLabel.Text = $Text
  $toolTip.SetToolTip($accountStatusLabel, $Text)
  if ($IsError) {
    $accountStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick
  } else {
    $accountStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  }
}

function Update-AccountDialog {
  if ($script:githubAccount) {
    $accountActiveLabel.Text = $script:githubAccount
  } else {
    $accountActiveLabel.Text = 'Not chosen (Git uses its default sign-in)'
  }
  $accountList.Items.Clear()
  try {
    foreach ($user in (Get-GitHubSignedInAccounts)) {
      [void]$accountList.Items.Add($user)
    }
    if ($script:githubAccount -and $accountList.Items.Contains($script:githubAccount)) {
      $accountList.SelectedItem = $script:githubAccount
    } elseif ($accountList.Items.Count -gt 0) {
      $accountList.SelectedIndex = 0
    }
    if ($accountList.Items.Count -eq 0) {
      Set-AccountStatus 'No GitHub account is signed in yet. Enter a user name and press Sign in.'
    } else {
      Set-AccountStatus "$($accountList.Items.Count) account(s) signed in."
    }
  } catch {
    Set-AccountStatus $_.Exception.Message $true
  }
}

function Use-GitHubAccount {
  param([string]$User)
  Save-GitHubAccount $User
  Set-GitHubAccount $User
  Update-AccountDialog
  if ($User) {
    Set-AccountStatus "This form now reads and writes GitHub as $User."
  } else {
    Set-AccountStatus 'This form now uses the default Git sign-in.'
  }
}

$accountUseButton.Add_Click({
  if (-not $accountList.SelectedItem) {
    Set-AccountStatus 'Select an account in the list first.' $true
    return
  }
  Use-GitHubAccount ([string]$accountList.SelectedItem)
})

$accountClearButton.Add_Click({ Use-GitHubAccount '' })
$accountRefreshButton.Add_Click({ Update-AccountDialog })

$accountSignOutButton.Add_Click({
  $user = [string]$accountList.SelectedItem
  if (-not $user) {
    Set-AccountStatus 'Select an account in the list first.' $true
    return
  }
  $answer = [System.Windows.Forms.MessageBox]::Show("Sign out $user from GitHub on this PC?", 'Sign out',
    [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
  if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
    return
  }
  $result = Invoke-CredentialManager @('github', 'logout', $user)
  if ($result.ExitCode -ne 0) {
    Set-AccountStatus ('Sign out failed: ' + ($result.Output -join ' ')) $true
    return
  }
  if ($script:githubAccount -eq $user) {
    Save-GitHubAccount ''
    Set-GitHubAccount ''
  }
  Update-AccountDialog
  Set-AccountStatus "$user signed out."
})

$script:accountSignInProcess = $null
$script:accountSignInUser = ''
$script:accountSignInBefore = @()
$accountSignInTimer = New-Object System.Windows.Forms.Timer
$accountSignInTimer.Interval = 500
$accountSignInTimer.Add_Tick({
  $process = $script:accountSignInProcess
  if (-not $process) {
    $accountSignInTimer.Stop()
    return
  }
  if (-not $process.HasExited) {
    return
  }
  $accountSignInTimer.Stop()
  $exitCode = $process.ExitCode
  $process.Dispose()
  $script:accountSignInProcess = $null
  foreach ($control in @($accountSignInButton, $accountUseButton, $accountSignOutButton, $accountRefreshButton, $accountClearButton, $accountNameBox)) {
    $control.Enabled = $true
  }
  if ($exitCode -ne 0) {
    Update-AccountDialog
    Set-AccountStatus "Sign in was not completed (exit code $exitCode)." $true
    return
  }
  $user = $script:accountSignInUser
  if (-not $user) {
    try {
      $after = @(Get-GitHubSignedInAccounts)
      $new = @($after | Where-Object { $script:accountSignInBefore -notcontains $_ })
      if ($new.Count -gt 0) {
        $user = $new[0]
      }
    } catch {
    }
  }
  if ($user) {
    Use-GitHubAccount $user
  } else {
    Update-AccountDialog
    Set-AccountStatus 'Signed in. Select the account and press Use selected.'
  }
  $accountNameBox.Clear()
})

$accountSignInButton.Add_Click({
  if ($script:accountSignInProcess) {
    return
  }
  $user = $accountNameBox.Text.Trim()
  if ($user -and $user -notmatch '^[A-Za-z0-9-]+$') {
    Set-AccountStatus 'A GitHub user name has only letters, numbers and dashes.' $true
    return
  }
  try {
    $script:accountSignInBefore = @(Get-GitHubSignedInAccounts)
  } catch {
    $script:accountSignInBefore = @()
  }
  $arguments = 'credential-manager github login'
  if ($user) {
    $arguments += ' --username ' + $user
  }
  try {
    $script:accountSignInUser = $user
    $script:accountSignInProcess = Start-NoWindowProcess 'git' $arguments
  } catch {
    Set-AccountStatus ('Could not start the GitHub sign-in: ' + $_.Exception.Message) $true
    return
  }
  foreach ($control in @($accountSignInButton, $accountUseButton, $accountSignOutButton, $accountRefreshButton, $accountClearButton, $accountNameBox)) {
    $control.Enabled = $false
  }
  Set-AccountStatus 'Finish the GitHub sign-in in the window or browser that opened...'
  $accountSignInTimer.Start()
})

$accountDialog.Add_FormClosing({
  param($sender, $eventArgs)
  if ($script:accountSignInProcess) {
    $eventArgs.Cancel = $true
    Set-AccountStatus 'Wait for the GitHub sign-in to finish.' $true
  }
})

$githubAccountButton.Add_Click({
  if ((Test-GitHubBusy) -or $script:deleteRepoJob) {
    Show-ComBoxMessage ('Wait for the current GitHub operation to finish before changing the account.') 'GitHub account' $true
    return
  }
  if (-not $accountNameBox.Text) {
    $match = [regex]::Match($homeRepoBox.Text, 'github\.com/([A-Za-z0-9-]+)/')
    if ($match.Success -and $accountList.Items.Count -eq 0) {
      $accountNameBox.Text = $match.Groups[1].Value
    }
  }
  Update-AccountDialog
  [void]$accountDialog.ShowDialog($form)
})
$startupRepositoryError = $null
try {
  $script:savedRepositoryUrl = Read-SavedRepositoryUrl
} catch {
  $script:savedRepositoryUrl = $defaultRepositoryUrl
  $startupRepositoryError = $_.Exception.Message
}

$localDeployFolderLabel = New-Label 'Local' 37 403 500
$localDeployFolderBox = New-Object System.Windows.Forms.TextBox
$localDeployFolderBox.Location = New-Object System.Drawing.Point(35, 430)
$localDeployFolderBox.Size = New-Object System.Drawing.Size(300, 32)
$localDeployFolderBox.ReadOnly = $true
$localDeployFolderBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($localDeployFolderBox)
$localDeployFolderFile = Join-Path $repositorySettingsDirectory 'cloudflare-local-folder.txt'
$webpageUrlBox = New-Object System.Windows.Forms.TextBox
$webpageUrlBox.Location = New-Object System.Drawing.Point(285, 550)
$webpageUrlBox.Size = New-Object System.Drawing.Size(540, 26)
$webpageUrlBox.ReadOnly = $true
$webpageUrlBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($webpageUrlBox)
$toolTip.SetToolTip($webpageUrlBox, 'Automatically generated from AppName; this link cannot be edited here.')
$webpageUrlInputBox = New-Object System.Windows.Forms.TextBox
$webpageUrlInputBox.Location = New-Object System.Drawing.Point(49, 550)
$webpageUrlInputBox.Size = New-Object System.Drawing.Size(112, 26)
$webpageUrlInputBox.BackColor = [System.Drawing.Color]::White
$webpageUrlInputBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($webpageUrlInputBox)
$toolTip.SetToolTip($webpageUrlInputBox, 'App / Cloudflare worker name')
$webpageUrlAppNameLabel = New-Label 'AppName' 285 550 58 26
$webpageUrlLabel = New-Label 'Link' 285 550 36 26
$webpageUrlNewButton = New-ActionButton 'Start a new app name' 0xE710 49 548
$webpageUrlCopyButton = New-ActionButton 'Copy deployed webpage URL' 0xE8C8 835 548
$webpageUrlOpenButton = New-ActionButton 'Open deployed webpage' 0xE8A7 873 548
$webpageUrlRefreshButton = New-ActionButton 'Refresh deployed webpage URL' 0xE72C 911 548
$webpageUrlSearchButton = New-ActionButton 'Show saved app records to select and edit' 0xE721 213 548
$cloudflareDataSaveButton = New-ActionButton 'Save Cloudflare fields to Data' 0xE74E 251 548
$cloudflareDataSaveButton.Enabled = $false
$toolTip.SetToolTip($cloudflareDataSaveButton, 'No Cloudflare fields have changed.')
function Set-ComBoxDataPendingChanges {
  param([bool]$Pending)
  $cloudflareDataSaveButton.Enabled = $Pending
  if ($Pending) {
    $toolTip.SetToolTip($cloudflareDataSaveButton, 'Click this Save button to add a new app or update the selected record.')
  } else {
    $toolTip.SetToolTip($cloudflareDataSaveButton, 'No Cloudflare fields have changed.')
  }
}
$localDeployBrowseButton = New-ActionButton 'Browse for a local project folder on this PC' 0xE721 345 427
$localDeployBrowseButton.Add_Click({
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description = 'Choose the local project folder to deploy to Cloudflare'
  $dialog.ShowNewFolderButton = $false
  if (-not [string]::IsNullOrWhiteSpace($localDeployFolderBox.Text) -and (Test-Path -LiteralPath $localDeployFolderBox.Text -PathType Container)) {
    $dialog.SelectedPath = $localDeployFolderBox.Text
  } elseif (Test-Path -LiteralPath $script:cloudflareDirectory -PathType Container) {
    $dialog.SelectedPath = $script:cloudflareDirectory
  }
  try {
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
      $localDeployFolderBox.Text = $dialog.SelectedPath
    }
  } finally {
    $dialog.Dispose()
  }
})
$toolTip.SetToolTip($localDeployFolderBox, 'Local project folder selected from this PC')
$deployIconButton = New-ActionButton 'Deploy from the GitHub Repo link saved in the Repo field' 0xE753 390 427
$localDeployIconButton = New-ActionButton 'From AppName, update Worker/GitHub links and only name + existing vars.GITHUB_REPO in wrangler.jsonc; preserve all other settings' 0xE713 390 427
$localDeployUploadButton = New-ActionButton 'Upload checked Local files and folders to the GitHub Repo' 0xE898 390 427
$localDeployViewButton = New-ActionButton 'View files in the selected local folder' 0xE890 390 427
$localDeployViewButton.Add_Click({
  Set-LocalDeployFilesExpanded (-not $script:cloudflareLocalFilesExpanded)
})

# GitHub repo to deploy from (empty = deploy the local folder).
$deployRepoLabel = New-Label 'Repo' 37 470 70
$deployRepoBox = New-Object System.Windows.Forms.TextBox
$deployRepoBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($deployRepoBox)
$deployRepoDeleteButton = New-ActionButton 'Delete all tracked files from this GitHub repository' 0xE74D 400 470
$deployRepoDeleteButton.ForeColor = [System.Drawing.Color]::Firebrick
$deployRepoSearchButton = New-ActionButton "Choose one of the account's GitHub repositories" 0xE721 400 470
$deployRepoSearchButton.Add_Click({
  Show-RepoPicker -Box $deployRepoBox -Button $deployRepoSearchButton -Status { param($Text, $Kind) Set-CloudflareStatus $Text ($Kind -eq 'error') }   # Form.bat
})
$toolTip.SetToolTip($deployRepoBox, 'GitHub repo to deploy (e.g. https://github.com/jakirfile/rubelapp). Empty: deploy the local folder.')
$deployRepoFile = Join-Path $repositorySettingsDirectory 'cloudflare-repo-url.txt'
try {
  if (Test-Path -LiteralPath $deployRepoFile -PathType Leaf) {
    $deployRepoBox.Text = ([string](Get-Content -LiteralPath $deployRepoFile -TotalCount 1 -ErrorAction Stop)).Trim()
  }
} catch {
}
$deployRepoBox.Add_TextChanged({
  try {
    [System.IO.File]::WriteAllText($deployRepoFile, $deployRepoBox.Text.Trim(), (New-Object System.Text.UTF8Encoding($false)))
  } catch {
  }
})

$githubTokenLabel = New-Label 'GITHUB_TOKEN' 470 376 280
$githubTokenBox = New-Object System.Windows.Forms.TextBox
$githubTokenBox.Location = New-Object System.Drawing.Point(468, 403)
$githubTokenBox.Size = New-Object System.Drawing.Size(230, 32)
$githubTokenBox.UseSystemPasswordChar = $true
$githubTokenBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($githubTokenBox)
$githubTokenPasteButton = New-ActionButton 'Paste GITHUB_TOKEN from the clipboard' 0xE77F 710 400
$githubTokenUploadButton = New-ActionButton 'Upload filled secrets to the Cloudflare worker (Production)' 0xE898 710 400

$sessionCodeLabel = New-Label 'SESSION_CODE' 470 445 280
$sessionCodeBox = New-Object System.Windows.Forms.TextBox
$sessionCodeBox.Location = New-Object System.Drawing.Point(468, 472)
$sessionCodeBox.Size = New-Object System.Drawing.Size(230, 32)
$sessionCodeBox.UseSystemPasswordChar = $true
$sessionCodeBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($sessionCodeBox)
$sessionCodeUploadButton = New-ActionButton 'Upload filled secrets to the Cloudflare worker (Production)' 0xE898 710 469

# Cloudflare boxes: deploy controls and secret controls in two separate bordered panels (positions: Form.bat)
$deployPanel = New-FormSectionPanel 'cloudflareDeploy'
$secretPanel = New-FormSectionPanel 'cloudflareSecrets'
$webpagePanel = New-FormSectionPanel 'cloudflareWebpage'
$localDeployFilesList = New-Object System.Windows.Forms.DataGridView
$localDeployFilesList.Size = New-Object System.Drawing.Size(370, 150)
$localDeployFilesList.AllowUserToAddRows = $false
$localDeployFilesList.AllowUserToDeleteRows = $false
$localDeployFilesList.AllowUserToResizeRows = $false
$localDeployFilesList.RowHeadersVisible = $false
$localDeployFilesList.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$localDeployFilesList.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$localDeployFilesList.MultiSelect = $false
$localDeployFilesList.BackgroundColor = [System.Drawing.Color]::White
$localDeployFilesList.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$localDeployFilesList.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnEnter
$localDeployFilesList.Columns.Add('Name', 'Name') | Out-Null
$localDeployFilesList.Columns['Name'].FillWeight = 100
$localDeployFilesList.Columns['Name'].ReadOnly = $true
$uploadColumn = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$uploadColumn.Name = 'Upload'
$uploadColumn.HeaderText = 'Upload'
$uploadColumn.FillWeight = 24
$localDeployFilesList.Columns.Add($uploadColumn) | Out-Null
$localDeployFilesList.Columns['Upload'].DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$localDeployFilesList.Columns['Upload'].HeaderCell.Style.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$script:cloudflareFilesLoading = $false
$script:cloudflareUploadSelectionFile = Join-Path $repositorySettingsDirectory 'cloudflare-local-upload-selection.json'
$localDeployFilesList.Add_CurrentCellDirtyStateChanged({
  if ($localDeployFilesList.IsCurrentCellDirty) {
    $localDeployFilesList.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
  }
})
$localDeployFilesList.Add_CellValueChanged({
  param($sender, $eventArgs)
  if ($script:cloudflareFilesLoading -or $eventArgs.RowIndex -lt 0 -or $eventArgs.ColumnIndex -ne $sender.Columns['Upload'].Index) {
    return
  }
  try {
    Save-LocalDeployUploadSelection
  } catch {
    Set-CloudflareStatus ('Could not remember the Upload checkboxes: ' + $_.Exception.Message) $true
  }
})
$localDeployFilesList.Visible = $false
$form.Controls.Add($localDeployFilesList)
$script:cloudflareSecretsEditable = $false
$script:cloudflareDeployFieldsEditable = $false

Move-IntoPanel $deployPanel @(
  ,@($deployRepoLabel,          14,  48,  38, 22)
  ,@($deployRepoBox,            56,  45, 262, 26)
  ,@($deployRepoDeleteButton,  362,  43,  32, 30)
  ,@($deployRepoSearchButton,  324,  43,  32, 30)
  ,@($deployIconButton,        400,  43,  32, 30)
  ,@($localDeployFolderLabel,   14,  92,  38, 22)
  ,@($localDeployFolderBox,     56,  89, 236, 26)
  ,@($localDeployUploadButton, 298,  87,  29, 30)
  ,@($localDeployViewButton,   331,  87,  29, 30)
  ,@($localDeployBrowseButton, 364,  87,  29, 30)
  ,@($localDeployIconButton,   397,  87,  29, 30)
)
$cloudflareDeployEditButton = New-ActionButton 'Enable editing of Local and Repo' 0xE70F 0 0
$form.Controls.Remove($cloudflareDeployEditButton)
$cloudflareDeployEditButton.Text = [string][char]0x270E
$cloudflareDeployEditButton.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 12)
$cloudflareDeployEditButton.Location = New-Object System.Drawing.Point(400, 4)
$cloudflareDeployEditButton.Size = New-Object System.Drawing.Size(32, 28)
$cloudflareDeployEditButton.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
$cloudflareDeployEditButton.Visible = $true
$deployPanel.Tag.Size = New-Object System.Drawing.Size(350, 22)
$deployPanel.Controls.Add($cloudflareDeployEditButton)
$cloudflareDeployEditButton.Add_Click({
  $script:cloudflareDeployFieldsEditable = -not $script:cloudflareDeployFieldsEditable
  if ($script:cloudflareDeployFieldsEditable) {
    $cloudflareDeployEditButton.Text = [string][char]0x2713
    $cloudflareDeployEditButton.BackColor = [System.Drawing.Color]::FromArgb(220, 240, 225)
    $toolTip.SetToolTip($cloudflareDeployEditButton, 'Editing enabled. Click to lock Local and Repo.')
  } else {
    $cloudflareDeployEditButton.Text = [string][char]0x270E
    $cloudflareDeployEditButton.BackColor = [System.Drawing.SystemColors]::Control
    $toolTip.SetToolTip($cloudflareDeployEditButton, 'Editing locked. Click to edit Local and Repo.')
  }
  $localDeployFolderBox.ReadOnly = -not $script:cloudflareDeployFieldsEditable
  $localDeployFolderBox.Enabled = $script:cloudflareDeployFieldsEditable
  $deployRepoBox.Enabled = $script:cloudflareDeployFieldsEditable
})
$localDeployFolderBox.Enabled = $script:cloudflareDeployFieldsEditable
$deployRepoBox.Enabled = $script:cloudflareDeployFieldsEditable
$toolTip.SetToolTip($cloudflareDeployEditButton, 'Editing locked. Click to edit Local and Repo.')
function Get-LocalDeployUploadSelection {
  param([string]$Folder)
  $selection = @{}
  if (-not (Test-Path -LiteralPath $script:cloudflareUploadSelectionFile -PathType Leaf)) {
    return $selection
  }
  $state = [IO.File]::ReadAllText($script:cloudflareUploadSelectionFile) | ConvertFrom-Json -ErrorAction Stop
  foreach ($savedFolder in @($state.Folders)) {
    if ([string]$savedFolder.Path -ine $Folder) {
      continue
    }
    foreach ($item in @($savedFolder.Items)) {
      $selection[[string]$item.Name] = [bool]$item.Checked
    }
    break
  }
  return $selection
}
function Save-LocalDeployUploadSelection {
  $folder = [IO.Path]::GetFullPath($localDeployFolderBox.Text.Trim())
  $state = [ordered]@{ Folders = @() }
  if (Test-Path -LiteralPath $script:cloudflareUploadSelectionFile -PathType Leaf) {
    $savedState = [IO.File]::ReadAllText($script:cloudflareUploadSelectionFile) | ConvertFrom-Json -ErrorAction Stop
    foreach ($savedFolder in @($savedState.Folders)) {
      if ([string]$savedFolder.Path -ine $folder) {
        $state.Folders += [pscustomobject]@{
          Path = [string]$savedFolder.Path
          Items = @($savedFolder.Items | ForEach-Object {
            [pscustomobject]@{ Name = [string]$_.Name; Checked = [bool]$_.Checked }
          })
        }
      }
    }
  }
  $items = @(
    foreach ($row in $localDeployFilesList.Rows) {
      $name = [string]$row.Cells['Name'].Value
      if (-not $name -or $name.StartsWith('(') -or $name.StartsWith('Select a valid') -or $name.StartsWith('Could not read')) {
        continue
      }
      [pscustomobject]@{
        Name = $name -replace '^\[Folder\] ', ''
        Checked = [bool]$row.Cells['Upload'].Value
      }
    }
  )
  $state.Folders += [pscustomobject]@{ Path = $folder; Items = $items }
  if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force -ErrorAction Stop | Out-Null
  }
  [IO.File]::WriteAllText(
    $script:cloudflareUploadSelectionFile,
    ($state | ConvertTo-Json -Depth 6),
    (New-Object System.Text.UTF8Encoding($false))
  )
}
function Update-LocalDeployFilesList {
  $script:cloudflareFilesLoading = $true
  try {
    $localDeployFilesList.Rows.Clear()
  $folder = $localDeployFolderBox.Text.Trim()
  if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
    [void]$localDeployFilesList.Rows.Add('Select a valid local folder to view its contents.', $false)
    return
  }
  try {
    $normalizedFolder = [IO.Path]::GetFullPath($folder)
    $savedSelection = Get-LocalDeployUploadSelection $normalizedFolder
    $entries = @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction Stop |
      Sort-Object @{ Expression = { if ($_.PSIsContainer) { 0 } else { 1 } } }, Name)
    if ($entries.Count -eq 0) {
      [void]$localDeployFilesList.Rows.Add('(Folder is empty)', $false)
      return
    }
    foreach ($entry in $entries) {
      $displayName = if ($entry.PSIsContainer) { '[Folder] ' + $entry.Name } else { $entry.Name }
      $isChecked = if ($savedSelection.ContainsKey($entry.Name)) { [bool]$savedSelection[$entry.Name] } else { $true }
      if ($entry.Name -ieq '.git') {
        $isChecked = $false
      }
      $rowIndex = $localDeployFilesList.Rows.Add($displayName, $isChecked)
      if ($entry.Name -ieq '.git') {
        $localDeployFilesList.Rows[$rowIndex].Cells['Upload'].ReadOnly = $true
        $localDeployFilesList.Rows[$rowIndex].Cells['Upload'].ToolTipText = 'Git metadata is not uploaded.'
      }
    }
  } catch {
    $localDeployFilesList.Rows.Clear()
    [void]$localDeployFilesList.Rows.Add('Could not read this folder.', $false)
    Set-CloudflareStatus ('Could not read the local folder contents: ' + $_.Exception.Message) $true
  }
  } finally {
    $script:cloudflareFilesLoading = $false
  }
}
function Set-LocalDeployFilesExpanded {
  param([bool]$Expanded)
  $script:cloudflareLocalFilesExpanded = $Expanded
  $localDeployFilesList.Visible = $Expanded -and $script:showCloudflareSection
  if ($Expanded) {
    Update-LocalDeployFilesList
  }
  Update-SectionLayout
}
Move-IntoPanel $secretPanel @(
  ,@($githubTokenLabel,         14,  48, 120, 22)
  ,@($githubTokenBox,          138,  45, 216, 26)
  ,@($githubTokenPasteButton,  362,  43,  32, 30)
  ,@($githubTokenUploadButton, 400,  43,  32, 30)
  ,@($sessionCodeLabel,         14,  92, 120, 22)
  ,@($sessionCodeBox,          138,  89, 252, 26)
  ,@($sessionCodeUploadButton, 400,  87,  32, 30)
)
$cloudflareSecretsEditButton = New-ActionButton 'Enable editing of GITHUB_TOKEN and SESSION_CODE' 0xE70F 0 0
$form.Controls.Remove($cloudflareSecretsEditButton)
$cloudflareSecretsEditButton.Text = [string][char]0x270E
$cloudflareSecretsEditButton.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 12)
$cloudflareSecretsEditButton.Location = New-Object System.Drawing.Point(400, 4)
$cloudflareSecretsEditButton.Size = New-Object System.Drawing.Size(32, 28)
$cloudflareSecretsEditButton.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
$cloudflareSecretsEditButton.Visible = $true
$secretPanel.Tag.Size = New-Object System.Drawing.Size(310, 22)
$secretPanel.Controls.Add($cloudflareSecretsEditButton)
$githubActionsSecretsButton = New-ActionButton 'Set CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID as GitHub Actions secrets' 0xE898 0 0
$form.Controls.Remove($githubActionsSecretsButton)
$githubActionsSecretsButton.Location = New-Object System.Drawing.Point(362, 4)
$githubActionsSecretsButton.Size = New-Object System.Drawing.Size(32, 28)
$secretPanel.Controls.Add($githubActionsSecretsButton)
$toolTip.SetToolTip($githubActionsSecretsButton, 'Upload Cloudflare deploy credentials to the selected GitHub Repo Actions secrets (requires GitHub CLI).')
$githubActionsSecretsButton.Add_Click({ Show-GitHubActionsSecretsDialog })
$cloudflareSecretsEditButton.Add_Click({
  $script:cloudflareSecretsEditable = -not $script:cloudflareSecretsEditable
  if ($script:cloudflareSecretsEditable) {
    $cloudflareSecretsEditButton.Text = [string][char]0x2713
    $cloudflareSecretsEditButton.BackColor = [System.Drawing.Color]::FromArgb(220, 240, 225)
    $toolTip.SetToolTip($cloudflareSecretsEditButton, 'Editing enabled. Click to lock GITHUB_TOKEN and SESSION_CODE.')
  } else {
    $cloudflareSecretsEditButton.Text = [string][char]0x270E
    $cloudflareSecretsEditButton.BackColor = [System.Drawing.SystemColors]::Control
    $toolTip.SetToolTip($cloudflareSecretsEditButton, 'Editing locked. Click to edit GITHUB_TOKEN and SESSION_CODE.')
  }
  $githubTokenBox.Enabled = $script:cloudflareSecretsEditable
  $sessionCodeBox.Enabled = $script:cloudflareSecretsEditable
})
$githubTokenBox.Enabled = $script:cloudflareSecretsEditable
$sessionCodeBox.Enabled = $script:cloudflareSecretsEditable
$toolTip.SetToolTip($cloudflareSecretsEditButton, 'Editing locked. Click to edit GITHUB_TOKEN and SESSION_CODE.')
$githubTokenPasteButton.Add_Click({
  try {
    if (-not $script:cloudflareSecretsEditable) {
      Set-CloudflareStatus 'Click the pencil icon to enable editing before pasting GITHUB_TOKEN.' $true
      return
    }
    if (-not [System.Windows.Forms.Clipboard]::ContainsText()) {
      Set-CloudflareStatus 'Clipboard does not contain text to paste as GITHUB_TOKEN.' $true
      return
    }
    $token = [System.Windows.Forms.Clipboard]::GetText().Trim()
    if (-not $token) {
      Set-CloudflareStatus 'Clipboard text is empty; GITHUB_TOKEN was not changed.' $true
      return
    }
    $githubTokenBox.Text = $token
    Set-CloudflareStatus 'GITHUB_TOKEN pasted from clipboard. Save the Data fields to keep it.'
  } catch {
    Set-CloudflareStatus ('Could not paste GITHUB_TOKEN from clipboard: ' + $_.Exception.Message) $true
  }
})
Move-IntoPanel $webpagePanel @(
  ,@($webpageUrlNewButton,      14,  43,  32, 30)
  ,@($webpageUrlAppNameLabel,   52,  47,  70, 22)
  ,@($webpageUrlInputBox,      124,  45, 112, 26)
  ,@($webpageUrlSearchButton,  240,  43,  32, 30)
  ,@($cloudflareDataSaveButton,278,  43,  32, 30)
  ,@($webpageUrlLabel,         314,  47,  36, 22)
  ,@($webpageUrlBox,           352,  45, 438, 26)
  ,@($webpageUrlCopyButton,    800,  43,  32, 30)
  ,@($webpageUrlOpenButton,    838,  43,  32, 30)
  ,@($webpageUrlRefreshButton, 876,  43,  32, 30)
)
$cloudflareStatusLabel = New-Label 'Cloudflare ready.' 37 280 900 24
$cloudflareStatusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$cloudflareStatusLabel.AutoEllipsis = $true
$cloudflareOAuthAccountLabel = New-Label '' 560 7 304 20
$cloudflareOAuthAccountLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$cloudflareOAuthAccountLabel.AutoEllipsis = $true
$cloudflareOAuthAccountLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$toolTip.SetToolTip($cloudflareOAuthAccountLabel, 'Cloudflare OAuth account')
$cloudflareAccountNameFile = Join-Path $repositorySettingsDirectory 'cloudflare-account-name.txt'
if (Test-Path -LiteralPath $cloudflareAccountNameFile -PathType Leaf) {
  try {
    $savedCloudflareAccountName = [IO.File]::ReadAllText($cloudflareAccountNameFile).Trim()
    if ($savedCloudflareAccountName) {
      $cloudflareOAuthAccountLabel.Text = $savedCloudflareAccountName
      $toolTip.SetToolTip($cloudflareOAuthAccountLabel, 'Cloudflare OAuth account: ' + $savedCloudflareAccountName)
    }
  } catch {
    Set-CloudflareStatus ('Could not restore the saved Cloudflare account name: ' + $_.Exception.Message) $true
  }
}
$form.Controls.Remove($cloudflareOAuthAccountLabel)
$cloudflareOAuthAccountLabel.Location = New-Object System.Drawing.Point(560, 7)
$cloudflareOAuthAccountLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$webpagePanel.Controls.Add($cloudflareOAuthAccountLabel)
$cloudflareOAuthLogo = Read-TabLogo (Join-Path $tabLogoDirectory 'cloudflare.ico')
if ($cloudflareOAuthLogo) {
  $cloudflareOAuthButton = New-Object System.Windows.Forms.PictureBox
  $cloudflareOAuthButton.Image = $cloudflareOAuthLogo
  $cloudflareOAuthButton.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
  $cloudflareOAuthButton.BackColor = [System.Drawing.Color]::Transparent
  $cloudflareOAuthButton.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $cloudflareOAuthButton.Location = New-Object System.Drawing.Point(876, 3)
  $cloudflareOAuthButton.Size = New-Object System.Drawing.Size(30, 28)
  $cloudflareOAuthButton.AccessibleName = 'Authorize Wrangler with Cloudflare OAuth in Google Chrome'
  $cloudflareOAuthButton.AccessibleDescription = $cloudflareOAuthButton.AccessibleName
  $cloudflareOAuthButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $toolTip.SetToolTip($cloudflareOAuthButton, $cloudflareOAuthButton.AccessibleName)
} else {
  $cloudflareOAuthButton = New-ActionButton 'Authorize Wrangler with Cloudflare OAuth in Google Chrome' 0xE753 0 0
  $form.Controls.Remove($cloudflareOAuthButton)
  $cloudflareOAuthButton.Location = New-Object System.Drawing.Point(876, 3)
  $cloudflareOAuthButton.Size = New-Object System.Drawing.Size(30, 28)
  $cloudflareOAuthButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $cloudflareOAuthButton.FlatAppearance.BorderSize = 0
  $cloudflareOAuthButton.BackColor = [System.Drawing.Color]::FromArgb(243, 128, 32)
  $cloudflareOAuthButton.ForeColor = [System.Drawing.Color]::White
  $cloudflareOAuthButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 12)
  $cloudflareOAuthButton.Text = [string][char]0xE753
}
$webpagePanel.Controls.Add($cloudflareOAuthButton)
$cloudflareOAuthAccountLabel.BringToFront()
$cloudflareOAuthButton.BringToFront()

$script:cloudflareOAuthProcess = $null
$script:cloudflareOAuthLogFile = ''
$script:cloudflareOAuthBrowserOpened = $false
$script:cloudflareOAuthMode = ''
$cloudflareOAuthTimer = New-Object System.Windows.Forms.Timer
$cloudflareOAuthTimer.Interval = 500
$cloudflareOAuthTimer.Add_Tick({
  $process = $script:cloudflareOAuthProcess
  if (-not $process) {
    $cloudflareOAuthTimer.Stop()
    return
  }
  $log = ''
  if ($script:cloudflareOAuthLogFile -and (Test-Path -LiteralPath $script:cloudflareOAuthLogFile -PathType Leaf)) {
    try {
      $log = Read-CloudflareJobLog $script:cloudflareOAuthLogFile
    } catch {
      Set-CloudflareStatus ('Could not read the Cloudflare OAuth output: ' + $_.Exception.Message) $true
    }
  }
  if ($script:cloudflareOAuthMode -eq 'login' -and -not $script:cloudflareOAuthBrowserOpened) {
    $match = [regex]::Match($log, 'https://dash\.cloudflare\.com/oauth2/auth[^\s"''<>]*')
    if ($match.Success) {
      $url = $match.Value.TrimEnd([char[]]@('.', ',', ';', ')', ']'))
      try {
        $chrome = Get-ChromeExecutable
        if (-not $chrome) {
          throw 'Google Chrome was not found. Install Chrome, then click the Cloudflare icon again.'
        }
        Start-Process -FilePath $chrome -ArgumentList ('"' + $url + '"') -ErrorAction Stop | Out-Null
        $script:cloudflareOAuthBrowserOpened = $true
        Set-CloudflareStatus 'Cloudflare OAuth opened in Chrome. Complete authorization there...'
      } catch {
        $script:cloudflareOAuthBrowserOpened = $true
        Set-CloudflareStatus ('Could not open Cloudflare OAuth in Chrome: ' + $_.Exception.Message) $true
      }
    }
  }
  if (-not $process.HasExited) {
    return
  }
  $cloudflareOAuthTimer.Stop()
  $exitCode = $process.ExitCode
  $process.Dispose()
  if ($script:cloudflareOAuthMode -eq 'login' -and $exitCode -eq 0) {
    if ($script:cloudflareOAuthLogFile -and (Test-Path -LiteralPath $script:cloudflareOAuthLogFile -PathType Leaf)) {
      Remove-Item -LiteralPath $script:cloudflareOAuthLogFile -Force -ErrorAction SilentlyContinue
    }
    $whoamiLogFile = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-cloudflare-whoami-' + [Guid]::NewGuid().ToString('N') + '.log')
    $whoamiStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $whoamiStartInfo.FileName = $env:ComSpec
    $whoamiStartInfo.Arguments = '/d /c call npx.cmd --yes wrangler@latest whoami > "' + $whoamiLogFile + '" 2>&1'
    $whoamiStartInfo.WorkingDirectory = $projectDirectory
    $whoamiStartInfo.UseShellExecute = $false
    $whoamiStartInfo.CreateNoWindow = $true
    $whoamiStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $whoamiProcess = New-Object System.Diagnostics.Process
    $whoamiProcess.StartInfo = $whoamiStartInfo
    try {
      if (-not $whoamiProcess.Start()) {
        throw 'Could not start Wrangler whoami.'
      }
      $script:cloudflareOAuthProcess = $whoamiProcess
      $script:cloudflareOAuthLogFile = $whoamiLogFile
      $script:cloudflareOAuthMode = 'whoami'
      Set-CloudflareStatus 'OAuth completed. Loading the Cloudflare account name...'
      $cloudflareOAuthTimer.Start()
      return
    } catch {
      $whoamiProcess.Dispose()
      $script:cloudflareOAuthMode = ''
      $script:cloudflareOAuthProcess = $null
      $script:cloudflareOAuthLogFile = ''
      Set-CloudflareControlsEnabled $true
      Set-CloudflareStatus ('OAuth succeeded, but the Cloudflare account name could not be loaded: ' + $_.Exception.Message) $true
      if (Test-Path -LiteralPath $whoamiLogFile -PathType Leaf) {
        Remove-Item -LiteralPath $whoamiLogFile -Force -ErrorAction SilentlyContinue
      }
      return
    }
  }
  $script:cloudflareOAuthProcess = $null
  $completedLogFile = $script:cloudflareOAuthLogFile
  $script:cloudflareOAuthLogFile = ''
  $script:cloudflareOAuthBrowserOpened = $false
  $completedMode = $script:cloudflareOAuthMode
  $script:cloudflareOAuthMode = ''
  Set-CloudflareControlsEnabled $true
  if ($completedMode -eq 'whoami' -and $exitCode -eq 0) {
    $accountMatch = [regex]::Match($log, '(?m)^\s*[\u2502|]\s*(?<name>[^\u2502|\r\n]+?)\s*[\u2502|]\s*[0-9a-fA-F]{32}\s*[\u2502|]\s*$')
    $identityMatch = [regex]::Match($log, '(?im)associated with the email\s+([^\s!]+)')
    if (-not $identityMatch.Success) {
      $identityMatch = [regex]::Match($log, '(?im)^\s*Email:\s*(\S+)\s*$')
    }
    if ($accountMatch.Success -or $identityMatch.Success) {
      $accountName = if ($accountMatch.Success) { $accountMatch.Groups['name'].Value.Trim() } else { $identityMatch.Groups[1].Value.Trim() }
      $cloudflareOAuthAccountLabel.Text = $accountName
      $accountTooltip = 'Cloudflare OAuth account: ' + $accountName
      if ($identityMatch.Success -and $accountMatch.Success) {
        $accountTooltip += ' (' + $identityMatch.Groups[1].Value.Trim() + ')'
      }
      $toolTip.SetToolTip($cloudflareOAuthAccountLabel, $accountTooltip)
      try {
        if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
          New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force -ErrorAction Stop | Out-Null
        }
        [IO.File]::WriteAllText($cloudflareAccountNameFile, $accountName, (New-Object System.Text.UTF8Encoding($false)))
      } catch {
        Set-CloudflareStatus ('OAuth succeeded, but could not save the Cloudflare account name: ' + $_.Exception.Message) $true
        return
      }
      Set-CloudflareStatus ('Cloudflare OAuth authorized as ' + $accountName + '.')
    } else {
      $details = @($log -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 8) -join "`r`n"
      Set-CloudflareStatus ('Wrangler is authorized, but could not read the account name.' + $(if ($details) { "`r`n" + $details } else { '' })) $true
    }
  } elseif ($completedMode -eq 'login' -and $exitCode -eq 0) {
    Set-CloudflareStatus 'Cloudflare OAuth completed. Wrangler is authorized.'
  } else {
    $details = @($log -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 8) -join "`r`n"
    if (-not $details) {
      $details = "Wrangler login failed (exit code $exitCode)."
    }
    Set-CloudflareStatus $details $true
  }
  if ($completedLogFile -and (Test-Path -LiteralPath $completedLogFile -PathType Leaf)) {
    Remove-Item -LiteralPath $completedLogFile -Force -ErrorAction SilentlyContinue
  }
})
$cloudflareOAuthButton.Add_Click({
  if (Test-CloudflareBusy) {
    Set-CloudflareStatus 'Wait for the current Cloudflare operation to finish before authorizing.' $true
    return
  }
  if ($script:cloudflareOAuthProcess) {
    Set-CloudflareStatus 'Cloudflare OAuth is already running. Complete authorization in Chrome.'
    return
  }
  if (-not (Get-ChromeExecutable)) {
    Set-CloudflareStatus 'Google Chrome was not found. Install Chrome before starting Cloudflare OAuth.' $true
    return
  }
  if (-not (Get-Command 'npx.cmd' -ErrorAction SilentlyContinue)) {
    Set-CloudflareStatus 'Node.js / npx was not found. Install Node.js before starting Cloudflare OAuth.' $true
    return
  }
  $logFile = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-cloudflare-oauth-' + [Guid]::NewGuid().ToString('N') + '.log')
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $env:ComSpec
  $startInfo.Arguments = '/d /c call npx.cmd --yes wrangler@latest login --browser=false > "' + $logFile + '" 2>&1'
  $startInfo.WorkingDirectory = $projectDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) {
      throw 'Could not start Wrangler login.'
    }
    $script:cloudflareOAuthProcess = $process
    $script:cloudflareOAuthLogFile = $logFile
    $script:cloudflareOAuthBrowserOpened = $false
    $script:cloudflareOAuthMode = 'login'
    Set-CloudflareControlsEnabled $false
    Set-CloudflareStatus 'Starting Wrangler Cloudflare OAuth...'
    $cloudflareOAuthTimer.Start()
  } catch {
    $process.Dispose()
    Set-CloudflareStatus ('Could not start Cloudflare OAuth: ' + $_.Exception.Message) $true
    if (Test-Path -LiteralPath $logFile -PathType Leaf) {
      Remove-Item -LiteralPath $logFile -Force -ErrorAction SilentlyContinue
    }
  }
})
function Set-CloudflareStatus {
  param([string]$Text, [bool]$IsError = $false)
  $cloudflareStatusLabel.Text = $Text
  $toolTip.SetToolTip($cloudflareStatusLabel, $Text)
  if ($IsError) {
    $cloudflareStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick
  } else {
    $cloudflareStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  }
}

$cloudflareSecretsFile = Join-Path $repositorySettingsDirectory 'cloudflare-secrets.json'
$script:cloudflareSecretsRestoring = $false

function ConvertTo-ComBoxCsvField {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) {
    $Value = ''
  }
  return '"' + $Value.Replace('"', '""') + '"'
}

function Unprotect-ComBoxDataSecret {
  param([string]$Value)
  if (-not $Value.StartsWith('dpapi:')) {
    return $Value
  }
  $secureValue = ConvertTo-SecureString -String $Value.Substring(6) -ErrorAction Stop
  $pointer = [IntPtr]::Zero
  try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  } finally {
    if ($pointer -ne [IntPtr]::Zero) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    $secureValue.Dispose()
  }
}

function Get-ComBoxDataRecord {
  $appName = $webpageUrlInputBox.Text.Trim()
  $link = $webpageUrlBox.Text.Trim()
  if (-not $link) {
    $link = Get-ComBoxLinkFromAppName $appName
  }
  return [pscustomobject][ordered]@{
    AppName = $appName
    Link = $link
    Repo = $deployRepoBox.Text.Trim()
    Local = $localDeployFolderBox.Text.Trim()
    Github = $githubTokenBox.Text
    Session = $sessionCodeBox.Text
  }
}

function Get-ComBoxLinkFromAppName {
  param([string]$AppName)
  $workerName = $AppName.Trim().ToLowerInvariant()
  if ($workerName -notmatch '^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$') {
    return ''
  }
  return "https://$workerName.jakirfile.workers.dev"
}

function Save-ComBoxActiveAppName {
  param([string]$AppName)
  if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force -ErrorAction Stop | Out-Null
  }
  [IO.File]::WriteAllText($comboxDataActiveAppFile, $AppName.Trim(), (New-Object System.Text.UTF8Encoding($false)))
}

function Read-ComBoxDataRows {
  if (-not (Test-Path -LiteralPath $comboxDataFile -PathType Leaf)) {
    return @()
  }
  $rows = @(Import-Csv -LiteralPath $comboxDataFile -ErrorAction Stop)
  foreach ($column in @('AppName', 'Link', 'Repo', 'Local', 'Github', 'Session')) {
    if ($rows.Count -gt 0 -and $rows[0].PSObject.Properties.Name -notcontains $column) {
      throw "The FormData file is missing the '$column' column: $comboxDataFile"
    }
  }
  return @($rows)
}

function Write-ComBoxDataRows {
  param([object[]]$Rows)
  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add('AppName,Link,Repo,Local,Github,Session')
  foreach ($record in $Rows) {
    $values = @(
      [string]$record.AppName
      [string]$record.Link
      [string]$record.Repo
      [string]$record.Local
      (Unprotect-ComBoxDataSecret ([string]$record.Github))
      (Unprotect-ComBoxDataSecret ([string]$record.Session))
    )
    $csvValues = @($values | ForEach-Object { ConvertTo-ComBoxCsvField $_ })
    $lines.Add($csvValues -join ',')
  }
  [IO.File]::WriteAllLines($comboxDataFile, $lines.ToArray(), (New-Object System.Text.UTF8Encoding($false)))
}

$script:comboxDataActiveRow = -1

function Assert-ComBoxAppUnique {
  param([string]$AppName)
  $normalizedName = $AppName.Trim()
  if (-not $normalizedName) {
    return
  }
  $rows = @(Read-ComBoxDataRows)
  for ($index = 0; $index -lt $rows.Count; $index++) {
    if ($index -eq $script:comboxDataActiveRow) {
      continue
    }
    if ([string]$rows[$index].AppName -ieq $normalizedName) {
      throw "App '$normalizedName' already exists in Data. Choose a different App name."
    }
  }
}

function Save-ComBoxData {
  param([switch]$RequireApp)
  if ($UploadWorker) {
    return $false
  }
  $appName = $webpageUrlInputBox.Text.Trim()
  if (-not $appName) {
    if ($RequireApp) {
      throw 'Enter an App name before saving.'
    }
    return $false
  }
  Assert-ComBoxAppUnique $appName
  $rows = [System.Collections.Generic.List[object]]::new()
  foreach ($row in (Read-ComBoxDataRows)) {
    $rows.Add($row)
  }
  $record = Get-ComBoxDataRecord
  if ($script:comboxDataActiveRow -ge 0 -and $script:comboxDataActiveRow -lt $rows.Count) {
    $rows[$script:comboxDataActiveRow] = $record
  } else {
    $rows.Add($record)
    $script:comboxDataActiveRow = $rows.Count - 1
  }
  Write-ComBoxDataRows $rows.ToArray()
  return $true
}

function Restore-ComBoxData {
  $rows = @(Read-ComBoxDataRows)
  if ($rows.Count -eq 0) {
    return
  }
  $savedAppName = ''
  if (Test-Path -LiteralPath $comboxDataActiveAppFile -PathType Leaf) {
    $savedAppName = [IO.File]::ReadAllText($comboxDataActiveAppFile).Trim()
  }
  $script:comboxDataActiveRow = $rows.Count - 1
  if ($savedAppName) {
    for ($index = 0; $index -lt $rows.Count; $index++) {
      if ([string]$rows[$index].AppName -ieq $savedAppName) {
        $script:comboxDataActiveRow = $index
        break
      }
    }
  }
  $record = $rows[$script:comboxDataActiveRow]
  $link = Get-ComBoxLinkFromAppName ([string]$record.AppName)
  if ([string]::IsNullOrWhiteSpace($link)) {
    $link = [string]$record.Link
  }
  $localDeployFolderBox.Text = [string]$record.Local
  $deployRepoBox.Text = [string]$record.Repo
  $githubTokenBox.Text = Unprotect-ComBoxDataSecret ([string]$record.Github)
  $sessionCodeBox.Text = Unprotect-ComBoxDataSecret ([string]$record.Session)
  $webpageUrlBox.Text = $link
  $webpageUrlInputBox.Text = [string]$record.AppName
}

function Select-ComBoxDataRow {
  $rows = @(Read-ComBoxDataRows)
  if ($rows.Count -eq 0) {
    return $null
  }

  $dialog = New-Object System.Windows.Forms.Form
  $dialog.Text = 'Select a saved app'
  $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
  $dialog.Size = New-Object System.Drawing.Size(1160, 480)
  $dialog.MinimumSize = New-Object System.Drawing.Size(900, 320)
  $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
  $dialog.MinimizeBox = $false
  $dialog.ShowInTaskbar = $false

  $list = New-Object System.Windows.Forms.DataGridView
  $list.Location = New-Object System.Drawing.Point(12, 12)
  $list.Size = New-Object System.Drawing.Size(1120, 385)
  $list.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
  $list.AllowUserToAddRows = $false
  $list.AllowUserToDeleteRows = $false
  $list.AllowUserToResizeRows = $false
  $list.ReadOnly = $true
  $list.MultiSelect = $false
  $list.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
  $list.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
  $list.RowHeadersVisible = $false
  $list.ShowCellToolTips = $true
  foreach ($column in @(
    @{ Name = 'AppName'; Width = 90 }
    @{ Name = 'Link'; Width = 150 }
    @{ Name = 'Repo'; Width = 150 }
    @{ Name = 'Local'; Width = 120 }
    @{ Name = 'Github'; Width = 100 }
    @{ Name = 'Session'; Width = 100 }
  )) {
    $gridColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $gridColumn.Name = $column.Name
    $gridColumn.HeaderText = $column.Name
    $gridColumn.FillWeight = $column.Width
    [void]$list.Columns.Add($gridColumn)
  }
  foreach ($row in $rows) {
    $rowIndex = $list.Rows.Add(
      [string]$row.AppName,
      [string]$row.Link,
      [string]$row.Repo,
      [string]$row.Local,
      (Unprotect-ComBoxDataSecret ([string]$row.Github)),
      (Unprotect-ComBoxDataSecret ([string]$row.Session))
    )
    foreach ($cell in $list.Rows[$rowIndex].Cells) {
      $cell.ToolTipText = [string]$cell.Value
    }
  }
  $dialog.Controls.Add($list)

  $loadButton = New-Object System.Windows.Forms.Button
  $loadButton.Text = 'Select and edit'
  $loadButton.Location = New-Object System.Drawing.Point(944, 405)
  $loadButton.Size = New-Object System.Drawing.Size(110, 30)
  $loadButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
  $loadButton.Enabled = $false
  $loadButton.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK })
  $dialog.Controls.Add($loadButton)

  $cancelButton = New-Object System.Windows.Forms.Button
  $cancelButton.Text = 'Cancel'
  $cancelButton.Location = New-Object System.Drawing.Point(1060, 405)
  $cancelButton.Size = New-Object System.Drawing.Size(72, 30)
  $cancelButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
  $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $dialog.Controls.Add($cancelButton)

  $list.Add_SelectionChanged({ $loadButton.Enabled = $list.SelectedRows.Count -gt 0 })
  $list.Add_DoubleClick({
    if ($list.SelectedRows.Count -gt 0) {
      $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
    }
  })
  $dialog.AcceptButton = $loadButton
  $dialog.CancelButton = $cancelButton

  Register-FormButtonSoundControl $dialog
  try {
    if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK -or $list.SelectedRows.Count -eq 0) {
      return $null
    }
    $selectedIndex = $list.SelectedRows[0].Index
    return [pscustomobject]@{
      Index = $selectedIndex
      Record = $rows[$selectedIndex]
    }
  } finally {
    $dialog.Dispose()
  }
}

function Save-CloudflareSecrets {
  if ([string]::IsNullOrEmpty($githubTokenBox.Text) -and [string]::IsNullOrEmpty($sessionCodeBox.Text)) {
    if (Test-Path -LiteralPath $cloudflareSecretsFile -PathType Leaf) {
      Remove-Item -LiteralPath $cloudflareSecretsFile -Force -ErrorAction Stop
    }
    return
  }

  if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force -ErrorAction Stop | Out-Null
  }
  $savedSecrets = [ordered]@{
    GITHUB_TOKEN = if ($githubTokenBox.Text) { ConvertFrom-SecureString -SecureString (ConvertTo-SecureString -String $githubTokenBox.Text -AsPlainText -Force) } else { '' }
    SESSION_CODE = if ($sessionCodeBox.Text) { ConvertFrom-SecureString -SecureString (ConvertTo-SecureString -String $sessionCodeBox.Text -AsPlainText -Force) } else { '' }
  }
  $json = ConvertTo-Json -InputObject $savedSecrets
  [IO.File]::WriteAllText($cloudflareSecretsFile, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Restore-CloudflareSecrets {
  if (-not (Test-Path -LiteralPath $cloudflareSecretsFile -PathType Leaf)) {
    return
  }
  $savedSecrets = [IO.File]::ReadAllText($cloudflareSecretsFile) | ConvertFrom-Json
  foreach ($entry in @(
    @{ Name = 'GITHUB_TOKEN'; Box = $githubTokenBox }
    @{ Name = 'SESSION_CODE'; Box = $sessionCodeBox }
  )) {
    $encrypted = [string]$savedSecrets.($entry.Name)
    if (-not $encrypted) { continue }
    $secureValue = ConvertTo-SecureString -String $encrypted -ErrorAction Stop
    $pointer = [IntPtr]::Zero
    try {
      $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
      $entry.Box.Text = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    } finally {
      if ($pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
      }
      $secureValue.Dispose()
    }
  }
}

if (-not $UploadWorker) {
  try {
    if (Test-Path -LiteralPath $localDeployFolderFile -PathType Leaf) {
      $localDeployFolderBox.Text = [IO.File]::ReadAllText($localDeployFolderFile).Trim()
    }
  } catch {
    Set-CloudflareStatus ('Could not restore the local deploy folder: ' + $_.Exception.Message) $true
  }
  try {
    $script:cloudflareSecretsRestoring = $true
    Restore-CloudflareSecrets
  } catch {
    Set-CloudflareStatus ('Could not restore saved Cloudflare secrets: ' + $_.Exception.Message) $true
  } finally {
    $script:cloudflareSecretsRestoring = $false
  }
  try {
    Restore-ComBoxData
  } catch {
    Set-CloudflareStatus ('Could not restore saved Data fields: ' + $_.Exception.Message) $true
  }
}

$localDeployFolderBox.Add_TextChanged({
  if ($script:cloudflareSecretsRestoring) { return }
  Set-ComBoxDataPendingChanges $true
  if ($script:cloudflareLocalFilesExpanded) {
    Update-LocalDeployFilesList
  }
})
$githubTokenBox.Add_TextChanged({
  if ($script:cloudflareSecretsRestoring) { return }
  Set-ComBoxDataPendingChanges $true
})
$sessionCodeBox.Add_TextChanged({
  if ($script:cloudflareSecretsRestoring) { return }
  Set-ComBoxDataPendingChanges $true
})
$deployRepoBox.Add_TextChanged({
  if ($script:cloudflareSecretsRestoring) { return }
  Set-ComBoxDataPendingChanges $true
})
$webpageUrlBox.Add_TextChanged({
  if ($script:cloudflareSecretsRestoring) { return }
  Set-ComBoxDataPendingChanges $true
})
$webpageUrlInputBox.Add_TextChanged({
  if ($script:cloudflareSecretsRestoring) { return }
  Set-ComBoxDataPendingChanges $true
  try {
    $script:cloudflareSecretsRestoring = $true
    try {
      $webpageUrlBox.Text = Get-ComBoxLinkFromAppName $webpageUrlInputBox.Text
    } finally {
      $script:cloudflareSecretsRestoring = $false
    }
    Update-SecretTargetTitle
  } catch {
    $script:cloudflareSecretsRestoring = $false
    Set-CloudflareStatus ('Could not update the AppName preview: ' + $_.Exception.Message) $true
  }
})

function Set-Status {
  param([string]$Text, [bool]$IsError = $false)
  Set-HomeStatus $Text $(if ($IsError) { 'error' } else { 'info' })
}

$script:activeOperationWorkers = @()

# Says how long a GitHub upload has been running; with -Ask, offers to stop it.
function Stop-GitHubOperation {
  param([switch]$Ask)
  $process = $null
  $what = ''
  if ($script:uploadProcess -and -not $script:uploadProcess.HasExited) {
    $process = $script:uploadProcess
    $what = 'GitHub upload'
  }
  if (-not $process) {
    Show-SectionMessage 'Wait for the current GitHub operation to finish.' $true
    return
  }
  $minutes = 0
  try { $minutes = [int][Math]::Floor(((Get-Date) - $process.StartTime).TotalMinutes) } catch { }
  $step = if ($script:lastUploadProgress -and $what -eq 'GitHub upload') { $script:lastUploadProgress } else { '' }
  $text = "A $what is still running ($minutes min)." + $(if ($step) { " Last step: $step" } else { '' })
  Show-SectionMessage $text $true
  if ($Ask) {
    $answer = [System.Windows.Forms.MessageBox]::Show($form, "$text`r`n`r`nIf it is stuck (for example waiting for a GitHub sign-in), stop it now?", $what, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
      return
    }
  }
  try {
    # Stop it and everything it started (git, credential helper).
    $null = & taskkill.exe /PID $process.Id /T /F 2>&1
  } catch {
  }
  Show-SectionMessage "$what stopped. You can start it again." $true
}

function Stop-RunLocalUpload {
  if ($script:uploadStatusTarget -ne 'runlocal' -or -not (Test-GitHubBusy)) {
    return
  }
  $script:uploadCancelled = $true
  Stop-GitHubOperation
  if (Test-GitHubBusy) {
    $script:uploadCancelled = $false
    Set-ColoredStatus $runLocalUploadStatusLabel 'Could not stop the upload process.' 'error'
  }
}

function Test-GitHubBusy {
  return [bool]($script:uploadProcess -and -not $script:uploadProcess.HasExited)
}

function Test-CloudflareBusy {
  return [bool]($script:cloudflareJob -or $script:deleteRepoJob -or $script:cloudflareOAuthProcess)
}

function Update-RestartButton {
  $restartButton.Enabled = -not ((Test-GitHubBusy) -or (Test-CloudflareBusy) -or [bool]$script:renameJob -or [bool]$script:deleteRepoJob)
}

function Set-GitHubControlsEnabled {
  param([bool]$Enabled)
  foreach ($control in @(
    $homeRepoBox, $homeUploadButton, $homeDownloadButton, $homeCleanButton,
    $homeCopyButton, $homeRepoSearchButton,
    $runLocalPrefixBox, $runLocalRepoSearchButton, $runLocalLeftArrowButton
  )) {
    if ($control) {
      $control.Enabled = $Enabled
    }
  }
  $canStopRunLocalUpload = (-not $Enabled) -and
    $script:uploadStatusTarget -eq 'runlocal' -and (Test-GitHubBusy)
  if ($canStopRunLocalUpload) {
    $runLocalLeftArrowButton.Text = [string][char]0xE71A
    $runLocalLeftArrowButton.AccessibleName = 'Stop GitHub upload'
    $runLocalLeftArrowButton.AccessibleDescription = 'Stop the current GitHub upload'
    $toolTip.SetToolTip($runLocalLeftArrowButton, 'Stop GitHub upload')
    $runLocalLeftArrowButton.Enabled = $true
  } else {
    $runLocalLeftArrowButton.Text = [string][char]0xE898
    $runLocalLeftArrowButton.AccessibleName = 'Upload checked Local items to GitHub'
    $runLocalLeftArrowButton.AccessibleDescription = 'Upload checked Local items to GitHub'
    $toolTip.SetToolTip($runLocalLeftArrowButton, 'Upload checked Local items to GitHub')
    $runLocalLeftArrowButton.Enabled = $Enabled
  }
  $localDeployUploadButton.Enabled = $Enabled
  $runLocalFilesEyeButton.Enabled = $Enabled
  $runLocalFilesList.Enabled = $Enabled
  if ($Enabled) {
    Update-RestartButton
  } else {
    $restartButton.Enabled = $false
  }
}

function Set-CloudflareControlsEnabled {
  param([bool]$Enabled)
  foreach ($control in @(
    $localDeployBrowseButton, $deployIconButton, $localDeployIconButton, $localDeployViewButton, $deployRepoDeleteButton, $deployRepoSearchButton,
    $githubTokenUploadButton, $sessionCodeUploadButton, $githubActionsSecretsButton, $cloudflareOAuthButton
  )) {
    $control.Enabled = $Enabled
  }
  $localDeployFolderBox.Enabled = $Enabled -and $script:cloudflareDeployFieldsEditable
  $localDeployFolderBox.ReadOnly = -not $script:cloudflareDeployFieldsEditable
  $deployRepoBox.Enabled = $Enabled -and $script:cloudflareDeployFieldsEditable
  $cloudflareDeployEditButton.Enabled = $Enabled
  $githubTokenBox.Enabled = $Enabled -and $script:cloudflareSecretsEditable
  $sessionCodeBox.Enabled = $Enabled -and $script:cloudflareSecretsEditable
  $cloudflareSecretsEditButton.Enabled = $Enabled
  if ($Enabled) {
    Update-RestartButton
  } else {
    $restartButton.Enabled = $false
  }
}

function Get-ErrorRecordDetails {
  param([System.Management.Automation.ErrorRecord]$ErrorRecord)

  if (-not $ErrorRecord) {
    return 'The operation failed without a PowerShell error record.'
  }

  $details = [System.Collections.Generic.List[string]]::new()
  $exception = $ErrorRecord.Exception
  while ($exception) {
    if (-not [string]::IsNullOrWhiteSpace($exception.Message) -and $exception.Message -notmatch "^Exception of type '.+' was thrown\.$") {
      if (-not $details.Contains($exception.Message)) {
        $details.Add($exception.Message)
      }
    }
    $exception = $exception.InnerException
  }

  if ($ErrorRecord.InvocationInfo -and $ErrorRecord.InvocationInfo.MyCommand) {
    $details.Add("Command: $($ErrorRecord.InvocationInfo.MyCommand)")
  }
  if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ScriptStackTrace)) {
    $details.Add("PowerShell stack: $($ErrorRecord.ScriptStackTrace)")
  }
  if ($details.Count -eq 0) {
    $details.Add($ErrorRecord.ToString())
  }
  return ($details -join [Environment]::NewLine)
}

function Save-UploadErrorLog {
  param([Parameter(Mandatory = $true)][string]$Details)
  if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force -ErrorAction Stop | Out-Null
  }
  Set-Content -LiteralPath $uploadErrorLogFile -Value $Details -Encoding UTF8 -ErrorAction Stop
}

if ($UploadWorker) {
  try {
    if (-not (Test-GitHubRepositoryUrl $RepositoryUrl)) {
      throw 'The upload worker received an invalid GitHub repository URL.'
    }
    if ([string]::IsNullOrWhiteSpace($GitHubUser)) {
      throw 'The upload worker did not receive a GitHub account name for authentication.'
    }
    $script:githubCredentialUser = $GitHubUser.Trim()
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GCM_INTERACTIVE = 'never'
    if ([string]::IsNullOrWhiteSpace($ProgressFile) -or [string]::IsNullOrWhiteSpace($ResultFile)) {
      throw 'The upload worker did not receive its progress and result file paths.'
    }

    $onlyPaths = @()
    if ($OnlyListFile -and (Test-Path -LiteralPath $OnlyListFile -PathType Leaf)) {
      $onlyPaths = @([System.IO.File]::ReadAllLines($OnlyListFile) | Where-Object { $_.Trim() })
    }
    $result = Invoke-UploadSnapshot -RepositoryUrl $RepositoryUrl -ProgressFile $ProgressFile -OnlyPaths $onlyPaths
    [System.IO.File]::WriteAllText($ResultFile, $result, [System.Text.Encoding]::UTF8)
    exit 0
  } catch {
    $errorDetails = Get-ErrorRecordDetails $_
    try {
      Save-UploadErrorLog -Details $errorDetails
    } catch {
      $errorDetails += "$([Environment]::NewLine)Could not write diagnostic log: $($_.Exception.ToString())"
    }
    try {
      [System.IO.File]::WriteAllText($ResultFile, $errorDetails, [System.Text.Encoding]::UTF8)
    } catch {
      $errorDetails += "$([Environment]::NewLine)Could not write worker result: $($_.Exception.ToString())"
    }
    exit 1
  }
}

function Update-DeployLink {
  param([switch]$Force)
  $updated = $true
  if ($Force -or [string]::IsNullOrWhiteSpace($webpageUrlBox.Text)) {
    try {
      $appLink = Get-ComBoxLinkFromAppName $webpageUrlInputBox.Text
      if ($appLink) {
        $webpageUrlBox.Text = $appLink
      } else {
        $webpageUrlBox.Text = Read-LatestDeployUrl
      }
    } catch {
      $webpageUrlBox.Clear()
      Set-CloudflareStatus $_.Exception.Message $true
      $updated = $false
    }
  }
  Update-SecretTargetTitle
  return $updated
}

# AppName is the source of truth for the worker receiving deploys and secrets.
function Get-CloudflareWorkerName {
  $worker = $webpageUrlInputBox.Text.Trim().ToLowerInvariant()
  if ($worker -notmatch '^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$') {
    throw 'Enter a valid AppName before deploying or uploading Cloudflare secrets.'
  }
  return $worker
}

function Get-WranglerWorkerNameUpdate {
  param(
    [string]$ConfigPath,
    [string]$WorkerName,
    [string]$RepositoryName
  )

  if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "wrangler.jsonc was not found in the Local folder: $ConfigPath"
  }

  $bytes = [IO.File]::ReadAllBytes($ConfigPath)
  $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
  $contentOffset = if ($hasUtf8Bom) { 3 } else { 0 }
  $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
  $content = $utf8.GetString($bytes, $contentOffset, $bytes.Length - $contentOffset)
  $depth = 0
  $inString = $false
  $escaped = $false
  $inLineComment = $false
  $inBlockComment = $false
  $namePropertyCount = 0
  $valueStart = -1
  $valueLength = 0
  $varsPending = $false
  $varsDepth = -1
  $repositoryPropertyCount = 0
  $repositoryValueStart = -1
  $repositoryValueLength = 0
  for ($index = 0; $index -lt $content.Length; $index++) {
    $character = $content[$index]
    $nextCharacter = if ($index + 1 -lt $content.Length) { $content[$index + 1] } else { [char]0 }
    if ($inLineComment) {
      if ($character -eq "`r" -or $character -eq "`n") {
        $inLineComment = $false
      }
      continue
    }
    if ($inBlockComment) {
      if ($character -eq '*' -and $nextCharacter -eq '/') {
        $inBlockComment = $false
        $index++
      }
      continue
    }
    if ($inString) {
      if ($escaped) {
        $escaped = $false
      } elseif ($character -eq '\') {
        $escaped = $true
      } elseif ($character -eq '"') {
        $inString = $false
      }
      continue
    }
    if ($character -eq '/' -and $nextCharacter -eq '/') {
      $inLineComment = $true
      $index++
      continue
    }
    if ($character -eq '/' -and $nextCharacter -eq '*') {
      $inBlockComment = $true
      $index++
      continue
    }
    if ($character -eq '"') {
      if ($depth -eq 1) {
        $propertyMatch = [regex]::Match(
          $content.Substring($index),
          '^"name"[ \t]*:[ \t]*("(?:[^"\\]|\\.)*")'
        )
        if ($propertyMatch.Success) {
          $namePropertyCount++
          $valueStart = $index + $propertyMatch.Groups[1].Index
          $valueLength = $propertyMatch.Groups[1].Length
        }
        if (-not [string]::IsNullOrWhiteSpace($RepositoryName) -and
            [regex]::IsMatch($content.Substring($index), '^"vars"[ \t\r\n]*:[ \t\r\n]*\{')) {
          $varsPending = $true
        }
      } elseif (-not [string]::IsNullOrWhiteSpace($RepositoryName) -and
          $varsDepth -gt 0 -and $depth -eq $varsDepth) {
        $repositoryMatch = [regex]::Match(
          $content.Substring($index),
          '^"GITHUB_REPO"[ \t]*:[ \t]*("(?:[^"\\]|\\.)*")'
        )
        if ($repositoryMatch.Success) {
          $repositoryPropertyCount++
          $repositoryValueStart = $index + $repositoryMatch.Groups[1].Index
          $repositoryValueLength = $repositoryMatch.Groups[1].Length
        }
      }
      $inString = $true
      continue
    }
    if ($character -eq '{') {
      $depth++
      if ($varsPending) {
        $varsDepth = $depth
        $varsPending = $false
      }
    } elseif ($character -eq '}') {
      $depth--
      if ($varsDepth -gt 0 -and $depth -lt $varsDepth) {
        $varsDepth = -1
      }
    }
  }
  if ($namePropertyCount -ne 1) {
    throw "Expected exactly one top-level name property in wrangler.jsonc: $ConfigPath"
  }
  if (-not [string]::IsNullOrWhiteSpace($RepositoryName) -and $repositoryPropertyCount -gt 1) {
    throw "Expected at most one vars.GITHUB_REPO property in wrangler.jsonc: $ConfigPath"
  }

  $updatedContent = $content.Substring(0, $valueStart) + '"' + $WorkerName + '"' +
    $content.Substring($valueStart + $valueLength)
  if (-not [string]::IsNullOrWhiteSpace($RepositoryName) -and $repositoryValueStart -ge 0) {
    if ($repositoryValueStart -gt $valueStart) {
      $repositoryValueStart += $WorkerName.Length - $valueLength + 2
    }
    $updatedContent = $updatedContent.Substring(0, $repositoryValueStart) + '"' + $RepositoryName + '"' +
      $updatedContent.Substring($repositoryValueStart + $repositoryValueLength)
  }
  return [pscustomobject]@{
    Path = $ConfigPath
    Content = $updatedContent
    Changed = $updatedContent -cne $content
    HasUtf8Bom = $hasUtf8Bom
    HasRepositoryProperty = $repositoryPropertyCount -eq 1
  }
}

function Get-WranglerAssetsUpdate {
  param(
    [string]$ConfigPath,
    [string]$Content
  )

  $nameMatch = [regex]::Match($Content, '(?m)^([ \t]*)"name"[ \t]*:')
  if (-not $nameMatch.Success) {
    throw "Cannot find the top-level name property in wrangler.jsonc: $ConfigPath"
  }
  $indent = [regex]::Escape($nameMatch.Groups[1].Value)
  $assetsPropertyPattern = '(?m)^' + $indent + '"assets"[ \t]*:'
  $assetsProperty = [regex]::Match($Content, $assetsPropertyPattern)
  if ($assetsProperty.Success) {
    $assetsObject = [regex]::Match(
      $Content.Substring($assetsProperty.Index),
      '"assets"[ \t]*:[ \t]*\{[^{}]*\}'
    )
    if (-not $assetsObject.Success) {
      throw "The existing assets configuration is not in the supported form: $ConfigPath"
    }
    if ($assetsObject.Value -notmatch '"directory"[ \t]*:[ \t]*"\./(?:public|out)"' -or
        $assetsObject.Value -notmatch '"binding"[ \t]*:[ \t]*"ASSETS"') {
      throw "The existing assets configuration must use directory './public' or './out' and binding 'ASSETS': $ConfigPath"
    }
    return [pscustomobject]@{
      Content = $Content
      Changed = $false
    }
  }

  $depth = 0
  $inString = $false
  $escaped = $false
  $inLineComment = $false
  $inBlockComment = $false
  $rootClose = -1
  for ($index = 0; $index -lt $Content.Length; $index++) {
    $character = $Content[$index]
    $nextCharacter = if ($index + 1 -lt $Content.Length) { $Content[$index + 1] } else { [char]0 }
    if ($inLineComment) {
      if ($character -eq "`r" -or $character -eq "`n") {
        $inLineComment = $false
      }
      continue
    }
    if ($inBlockComment) {
      if ($character -eq '*' -and $nextCharacter -eq '/') {
        $inBlockComment = $false
        $index++
      }
      continue
    }
    if ($inString) {
      if ($escaped) {
        $escaped = $false
      } elseif ($character -eq '\') {
        $escaped = $true
      } elseif ($character -eq '"') {
        $inString = $false
      }
      continue
    }
    if ($character -eq '/' -and $nextCharacter -eq '/') {
      $inLineComment = $true
      $index++
      continue
    }
    if ($character -eq '/' -and $nextCharacter -eq '*') {
      $inBlockComment = $true
      $index++
      continue
    }
    if ($character -eq '"') {
      $inString = $true
      continue
    }
    if ($character -eq '{') {
      $depth++
    } elseif ($character -eq '}') {
      $depth--
      if ($depth -eq 0) {
        $rootClose = $index
        break
      }
    }
  }
  if ($rootClose -lt 0) {
    throw "Could not find the end of the Wrangler config object: $ConfigPath"
  }

  $before = $Content.Substring(0, $rootClose).TrimEnd()
  $after = $Content.Substring($rootClose)
  $lineEnding = if ($Content.Contains("`r`n")) { "`r`n" } else { "`n" }
  $separator = if ($before.EndsWith('{') -or $before.EndsWith(',')) { '' } else { ',' }
  $assetsConfig = @(
    '  "assets": {'
    '    "directory": "./public",'
    '    "binding": "ASSETS",'
    '    "run_worker_first": true,'
    '    "not_found_handling": "none",'
    '    "html_handling": "none"'
    '  }'
  ) -join $lineEnding
  return [pscustomobject]@{
    Content = $before + $separator + $lineEnding + $assetsConfig + $lineEnding + $after
    Changed = $true
  }
}

function Get-AllWebWorkerTemplateContent {
  param([string]$Folder)

  $combinedScript = [string]$script:cloudflareDeploymentSource
  $startMarker = '/*__CLOUDFLARE_WORKER_TEMPLATE__*/'
  $endMarker = '/*__END_CLOUDFLARE_WORKER_TEMPLATE__*/'
  $start = $combinedScript.IndexOf($startMarker, [StringComparison]::Ordinal)
  $end = $combinedScript.IndexOf($endMarker, $start + $startMarker.Length, [StringComparison]::Ordinal)
  if ($start -lt 0 -or $end -lt 0) {
    throw 'The embedded All-Web Worker template was not found in Form.bat.'
  }
  $start += $startMarker.Length
  if ($combinedScript.Substring($start).StartsWith("`r`n")) {
    $start += 2
  } elseif ($combinedScript.Substring($start).StartsWith("`n")) {
    $start++
  }
  $templateContent = $combinedScript.Substring($start, $end - $start).TrimEnd("`r", "`n") + "`r`n"
  $sources = [System.Collections.Generic.List[object]]::new()
  $sources.Add([pscustomobject]@{
    Path = (Join-Path $Folder 'worker.js')
    Content = $templateContent
  })
  foreach ($apiFile in Get-ChildItem -LiteralPath (Join-Path $Folder 'api') -Recurse -Filter '*.js' -File -ErrorAction Stop) {
    $sources.Add([pscustomobject]@{
      Path = $apiFile.FullName
      Content = [IO.File]::ReadAllText($apiFile.FullName)
    })
  }

  foreach ($source in $sources) {
    foreach ($match in [regex]::Matches([string]$source.Content, 'require\(["''](\.{1,2}/[^"'']+)["'']\)')) {
      $target = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName([string]$source.Path)) $match.Groups[1].Value))
      $candidates = @($target, ($target + '.js'), ($target + '.json'), (Join-Path $target 'index.js'))
      if (-not ($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })) {
        throw "The All-Web mapping template has an unresolved module dependency in '$($source.Path)': $($match.Groups[1].Value)"
      }
    }
  }

  return $templateContent
}

function Get-LocalCloudflareStarterFiles {
  param(
    [string]$Folder,
    [string]$WorkerName
  )

  $files = [System.Collections.Generic.List[object]]::new()
  $configPath = Join-Path $Folder 'wrangler.jsonc'
  $publicDirectory = Join-Path $Folder 'public'
  $hasPublicAssets = Test-Path -LiteralPath $publicDirectory -PathType Container
  $apiDirectory = Join-Path $Folder 'api'
  $hasAllWebApi = (Test-Path -LiteralPath (Join-Path $apiDirectory 'auth.js') -PathType Leaf) -and
    (Test-Path -LiteralPath (Join-Path $apiDirectory '_lib\runtime-env.js') -PathType Leaf)
  $workerPath = Join-Path $Folder 'worker.js'
  if ((Test-Path -LiteralPath $workerPath) -and -not (Test-Path -LiteralPath $workerPath -PathType Leaf)) {
    throw "Cannot create worker.js because that path is not a file: $workerPath"
  }
  $existingWorker = if (Test-Path -LiteralPath $workerPath -PathType Leaf) {
    [IO.File]::ReadAllText($workerPath)
  } else {
    ''
  }
  $isPlaceholder = $existingWorker -match 'module\.exports\s*=\s*\{\s*async\s+fetch\s*\(\s*\)\s*\{\s*return\s+new\s+Response\(''Hello from [^'']+'''
  $workerTemplate = $null
  if ($hasPublicAssets -and $hasAllWebApi -and (-not $existingWorker -or $isPlaceholder)) {
    $workerTemplate = Get-AllWebWorkerTemplateContent -Folder $Folder
  }

  if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    $configUpdate = Get-WranglerWorkerNameUpdate -ConfigPath $configPath -WorkerName $WorkerName
    if ($hasPublicAssets) {
      $assetsUpdate = Get-WranglerAssetsUpdate -ConfigPath $configPath -Content $configUpdate.Content
      $configUpdate.Content = $assetsUpdate.Content
      $configUpdate.Changed = $configUpdate.Changed -or $assetsUpdate.Changed
      $configUpdate | Add-Member -NotePropertyName AddsPublicAssets -NotePropertyValue $assetsUpdate.Changed
    }
    $files.Add($configUpdate)
  } elseif (Test-Path -LiteralPath $configPath) {
    throw "Cannot create wrangler.jsonc because that path is not a file: $configPath"
  } else {
    $compatibilityDate = Get-Date -Format 'yyyy-MM-dd'
    $configContent = @"
{
  "`$schema": "node_modules/wrangler/config-schema.json",
  "name": "$WorkerName",
  "main": "worker.mjs",
  "workers_dev": true,
  "compatibility_date": "$compatibilityDate",
  "compatibility_flags": [
    "nodejs_compat"
  ]
}
"@
    if ($hasPublicAssets) {
      $assetsUpdate = Get-WranglerAssetsUpdate -ConfigPath $configPath -Content $configContent
      $configContent = $assetsUpdate.Content
    }
    $files.Add([pscustomobject]@{
      Path = $configPath
      Content = $configContent + "`r`n"
      Changed = $true
      HasUtf8Bom = $false
      IsNew = $true
      AddsPublicAssets = [bool]$hasPublicAssets
    })
  }

  $workerModulePath = Join-Path $Folder 'worker.mjs'
  if (Test-Path -LiteralPath $workerModulePath -PathType Leaf) {
    $files.Add([pscustomobject]@{
      Path = $workerModulePath
      Content = ''
      Changed = $false
      HasUtf8Bom = $false
      IsNew = $false
    })
  } elseif (Test-Path -LiteralPath $workerModulePath) {
    throw "Cannot create worker.mjs because that path is not a file: $workerModulePath"
  } else {
    $files.Add([pscustomobject]@{
      Path = $workerModulePath
      Content = "import worker from './worker.js';`r`n`r`nexport default worker;`r`n"
      Changed = $true
      HasUtf8Bom = $false
      IsNew = $true
    })
  }

  $workerContent = if ($workerTemplate) { $workerTemplate } else {
    @"
'use strict';

module.exports = {
  async fetch() {
    return new Response('Hello from $WorkerName', {
      headers: { 'content-type': 'text/plain; charset=utf-8' }
    });
  }
};
"@ + "`r`n"
  }
  $workerIsMapped = [bool]$workerTemplate
  if (Test-Path -LiteralPath $workerPath -PathType Leaf) {
    $canReplaceWorker = $workerTemplate -and ($isPlaceholder -or $existingWorker.Trim() -eq $workerTemplate.Trim())
    $files.Add([pscustomobject]@{
      Path = $workerPath
      Content = if ($canReplaceWorker -and $isPlaceholder) { $workerContent } else { '' }
      Changed = [bool]($canReplaceWorker -and $isPlaceholder)
      HasUtf8Bom = $false
      IsNew = $false
      IsWorkerMapping = [bool]($canReplaceWorker -or ($workerTemplate -and $existingWorker.Trim() -eq $workerTemplate.Trim()))
      HasCustomWorker = [bool]($workerTemplate -and -not $canReplaceWorker)
    })
  } elseif (Test-Path -LiteralPath $workerPath) {
    throw "Cannot create worker.js because that path is not a file: $workerPath"
  } else {
    $files.Add([pscustomobject]@{
      Path = $workerPath
      Content = $workerContent
      Changed = $true
      HasUtf8Bom = $false
      IsNew = $true
      IsWorkerMapping = $workerIsMapped
      HasCustomWorker = $false
    })
  }

  return @($files.ToArray())
}

function Save-LocalCloudflareStarterFiles {
  param([object[]]$Files)

  foreach ($file in $Files) {
    if ($file.IsNew) {
      if (Test-Path -LiteralPath $file.Path) {
        throw "Cannot create the starter file because the path already exists: $($file.Path)"
      }
      [IO.File]::WriteAllText([string]$file.Path, [string]$file.Content, (New-Object System.Text.UTF8Encoding($false)))
    } elseif ($file.Changed) {
      $encoding = New-Object System.Text.UTF8Encoding([bool]$file.HasUtf8Bom)
      [IO.File]::WriteAllText([string]$file.Path, [string]$file.Content, $encoding)
    }
  }
}

function Update-SecretTargetTitle {
  if (-not $secretPanel) {
    return
  }
  try {
    $worker = Get-CloudflareWorkerName
  } catch {
    $worker = 'unknown'
  }
  $secretPanel.Tag.Text = "Cloudflare secrets  (worker: $worker)"
  if ($deployPanel) {
    $deployPanel.Tag.Text = "Cloudflare deploy  (worker: $worker)"
  }
}

$script:gitInitDeclined = @{}
function Initialize-GitHubSourceRepository {
  $folder = $script:githubDirectory
  if (Test-Path -LiteralPath (Join-Path $folder '.git')) {
    return
  }
  if ([System.IO.Path]::GetPathRoot($folder).TrimEnd('\') -ieq $folder.TrimEnd('\')) {
    throw "The source folder is a whole drive ($folder). Choose a project folder with the folder button above."
  }
  if ($script:gitInitDeclined.ContainsKey($folder)) {
    throw "The source folder is not a Git repository: $folder"
  }
  $answer = [System.Windows.Forms.MessageBox]::Show(
    "The source folder is not a Git repository yet:`r`n$folder`r`n`r`nCreate a Git repository here now (git init, branch $mainBranch)?",
    'Create Git repository',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question)
  if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
    $script:gitInitDeclined[$folder] = $true
    throw "The source folder is not a Git repository: $folder"
  }
  $null = Invoke-Git -Arguments @('init')
  $null = Invoke-Git -Arguments @('symbolic-ref', 'HEAD', "refs/heads/$mainBranch")
}

$webpageUrlCopyButton.Add_Click({
  if ([string]::IsNullOrWhiteSpace($webpageUrlBox.Text)) {
    Set-CloudflareStatus 'There is no deployed webpage URL to copy.' $true
    return
  }
  try {
    [System.Windows.Forms.Clipboard]::SetText($webpageUrlBox.Text.Trim())
    Set-CloudflareStatus 'Deployed webpage URL copied.'
  } catch {
    Set-CloudflareStatus $_.Exception.Message $true
  }
})

$webpageUrlOpenButton.Add_Click({
  $url = $webpageUrlBox.Text.Trim()
  $parsedUrl = $null
  if (-not [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$parsedUrl) -or $parsedUrl.Scheme -notin @('http', 'https')) {
    Set-CloudflareStatus 'There is no valid deployed webpage URL to open.' $true
    return
  }
  try {
    Start-Process -FilePath $parsedUrl.AbsoluteUri -ErrorAction Stop | Out-Null
    Set-CloudflareStatus 'Opened the deployed webpage in your browser.'
  } catch {
    Set-CloudflareStatus $_.Exception.Message $true
  }
})

$webpageUrlRefreshButton.Add_Click({
  if (-not (Update-DeployLink -Force)) {
    return
  }
  if ([string]::IsNullOrWhiteSpace($webpageUrlBox.Text)) {
    Set-CloudflareStatus 'No deployed webpage URL has been saved yet.'
  } elseif ($webpageUrlBox.Text -match '^https?://') {
    Set-CloudflareStatus 'Deployed webpage URL refreshed.'
  }
})

$webpageUrlSearchButton.Add_Click({
  try {
    $selection = Select-ComBoxDataRow
    if ($null -eq $selection) {
      if (@(Read-ComBoxDataRows).Count -eq 0) {
        Set-CloudflareStatus 'No saved app records were found in Data.' $true
      }
      return
    }
    $record = $selection.Record
    $script:comboxDataActiveRow = $selection.Index
    Save-ComBoxActiveAppName ([string]$record.AppName)
    $link = Get-ComBoxLinkFromAppName ([string]$record.AppName)
    $script:cloudflareSecretsRestoring = $true
    try {
      $webpageUrlInputBox.Text = [string]$record.AppName
      $webpageUrlBox.Text = $link
      $localDeployFolderBox.Text = [string]$record.Local
      $deployRepoBox.Text = [string]$record.Repo
      $githubTokenBox.Text = Unprotect-ComBoxDataSecret ([string]$record.Github)
      $sessionCodeBox.Text = Unprotect-ComBoxDataSecret ([string]$record.Session)
    } finally {
      $script:cloudflareSecretsRestoring = $false
    }
    if ($script:cloudflareLocalFilesExpanded) {
      Update-LocalDeployFilesList
    }
    Update-SecretTargetTitle
    Set-ComBoxDataPendingChanges $false
    $selectedApp = [string]$record.AppName
    if (-not $selectedApp) { $selectedApp = '(Unnamed App)' }
    Set-CloudflareStatus "Loaded '$selectedApp'. Edit any field, then click Save to update this record."
  } catch {
    Set-CloudflareStatus ('Could not load the selected Data record: ' + $_.Exception.Message) $true
  }
})

function Start-ComBoxNewEntry {
  $script:comboxDataActiveRow = -1
  $script:cloudflareSecretsRestoring = $true
  try {
    $webpageUrlInputBox.Clear()
    $webpageUrlBox.Clear()
    $localDeployFolderBox.Clear()
    $deployRepoBox.Clear()
    $githubTokenBox.Clear()
    $sessionCodeBox.Clear()
  } finally {
    $script:cloudflareSecretsRestoring = $false
  }
  if ($script:cloudflareLocalFilesExpanded) {
    Update-LocalDeployFilesList
  }
  Set-ComBoxDataPendingChanges $true
  $webpageUrlInputBox.Focus()
  Set-CloudflareStatus 'New entry ready. Fill in the fields and click Save to add this app.'
}

$webpageUrlNewButton.Add_Click({
  try {
    Start-ComBoxNewEntry
  } catch {
    Set-CloudflareStatus ('Could not start a new entry: ' + $_.Exception.Message) $true
  }
})

$cloudflareDataSaveButton.Add_Click({
  try {
    $appName = $webpageUrlInputBox.Text.Trim()
    if (-not $appName) {
      throw 'Enter an App name before saving.'
    }
    Assert-ComBoxAppUnique $appName
    $url = $webpageUrlBox.Text.Trim()
    if ($url) {
      $parsedUrl = $null
      if (-not [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$parsedUrl) -or $parsedUrl.Scheme -notin @('http', 'https')) {
        throw 'Enter a valid webpage URL beginning with http:// or https://.'
      }
    }
    Update-SecretTargetTitle
    Save-ComBoxData -RequireApp
    Set-ComBoxDataPendingChanges $false
    Set-CloudflareStatus 'Cloudflare fields saved to Data.'
  } catch {
    Set-CloudflareStatus ('Could not save Cloudflare fields: ' + $_.Exception.Message) $true
  }
})

$uploadTimer = New-Object System.Windows.Forms.Timer
$uploadTimer.Interval = 400
$script:lastUploadProgress = ''

function Set-UploadOperationStatus {
  param([string]$Text, [bool]$IsError = $false)
  if ($script:uploadStatusTarget -eq 'cloudflare') {
    Set-CloudflareStatus $Text $IsError
  } elseif ($script:uploadStatusTarget -eq 'runlocal') {
    Set-ColoredStatus $runLocalUploadStatusLabel $Text $(if ($IsError) { 'error' } else { 'info' })
  } elseif ($script:uploadStatusTarget -eq 'home') {
    Set-HomeStatus $Text $(if ($IsError) { 'error' } else { 'info' })
  } else {
    Set-Status $Text $IsError
  }
}
$uploadTimer.Add_Tick({
  if (-not $script:uploadProcess) {
    $uploadTimer.Stop()
    return
  }

  # The worker replaces this file for every step, so it can be missing or locked
  # for a moment; that tick is simply skipped.
  $progress = ''
  try {
    if (Test-Path -LiteralPath $script:uploadProgressFile -PathType Leaf) {
      $progress = [System.IO.File]::ReadAllText($script:uploadProgressFile).Trim()
    }
  } catch {
    $progress = ''
  }
  if ($progress) {
    if ($progress -ne $script:lastUploadProgress) {
      $script:lastUploadProgress = $progress
      Set-UploadOperationStatus $progress
    }
  }

  if (-not $script:uploadProcess.HasExited) {
    return
  }

  $uploadTimer.Stop()
  $exitCode = $script:uploadProcess.ExitCode
  $result = ''
  try {
    if (Test-Path -LiteralPath $script:uploadResultFile -PathType Leaf) {
      $result = [System.IO.File]::ReadAllText($script:uploadResultFile).Trim()
    }
  } catch {
    $result = ''
  }
  $script:uploadProcess.Dispose()
  $script:uploadProcess = $null
  Set-GitHubControlsEnabled $true

  Remove-Item -LiteralPath $script:uploadProgressFile -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath ($script:uploadProgressFile + '.tmp') -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $script:uploadResultFile -Force -ErrorAction SilentlyContinue
  if ($script:uploadOnlyListFile) {
    Remove-Item -LiteralPath $script:uploadOnlyListFile -Force -ErrorAction SilentlyContinue
    $script:uploadOnlyListFile = ''
  }

  if ($script:uploadCancelled) {
    $script:uploadCancelled = $false
    Set-UploadOperationStatus 'Upload stopped by user. Check GitHub before retrying if the upload had reached the push step.'
    return
  }

  if ($exitCode -ne 0 -or -not $result) {
    if (-not $result -and (Test-Path -LiteralPath $uploadErrorLogFile -PathType Leaf)) {
      $result = Get-Content -LiteralPath $uploadErrorLogFile -Raw
    }
    if ([string]::IsNullOrWhiteSpace($result)) {
      $result = "The upload process exited with code $exitCode without returning details. Last reported step: $script:lastUploadProgress"
    }
    Set-UploadOperationStatus "Upload failed: $result" $true
    Show-ComBoxMessage ("$result`r`n`r`nDiagnostic log: $uploadErrorLogFile") 'GitHub upload failed' $true
    return
  }

  if ($script:uploadStatusTarget -eq 'cloudflare') {
    if ($result -like 'GitHub already matches*') {
      Set-CloudflareStatus 'The checked items already match the Repo.'
    } else {
      Set-CloudflareStatus "Checked items uploaded to $(Get-DisplayRepositoryUrl $script:uploadDestinationUrl)/tree/$mainBranch."
    }
  } elseif ($script:uploadStatusTarget -eq 'runlocal') {
    if ($result -like 'GitHub already matches*') {
      Set-ColoredStatus $runLocalUploadStatusLabel 'Checked Local items already match the Repo; no upload was needed.' 'success'
    } else {
      try {
        Save-RunLocalLastUploadTime
        Set-ColoredStatus $runLocalUploadStatusLabel "Upload completed to $(Get-DisplayRepositoryUrl $script:uploadDestinationUrl)/tree/$mainBranch." 'success'
      } catch {
        Set-ColoredStatus $runLocalUploadStatusLabel ("Upload completed, but could not save its time: " + $_.Exception.Message) 'error'
      }
    }
  } else {
    if ($result -like 'GitHub already matches*') {
      Set-HomeStatus 'GitHub upload finished; the repository was already up to date.' 'success'
    } else {
      Set-HomeStatus 'GitHub upload finished.' 'success'
    }
  }
})

# Shared upload worker used by Home, Cloudflare and Server.
function Start-GitHubUpload {
  param(
    [string[]]$OnlyPaths = @(),
    [string]$RepositoryUrl = '',
    [string]$SourceFolder = '',
    [switch]$Confirmed,
    [switch]$CloudflareStatus,
    [switch]$RunLocalStatus,
    [switch]$HomeStatus
  )
  if ($script:deleteRepoJob) {
    if ($CloudflareStatus) {
      Set-CloudflareStatus 'Wait for the repository delete to finish before uploading.' $true
    } elseif ($RunLocalStatus) {
      Set-ColoredStatus $runLocalUploadStatusLabel 'Wait for the repository delete to finish before uploading.' 'error'
    } elseif ($HomeStatus) {
      Set-HomeStatus 'Wait for the repository delete to finish before uploading.' 'error'
    } else {
      Set-Status 'Wait for the repository delete to finish before uploading.' $true
    }
    return
  }
  if (Test-GitHubBusy) {
    if ($CloudflareStatus) {
      Set-CloudflareStatus 'Wait for the current GitHub upload to finish.' $true
    } elseif ($RunLocalStatus) {
      Set-ColoredStatus $runLocalUploadStatusLabel 'Wait for the current GitHub upload to finish.' 'error'
    } elseif ($HomeStatus) {
      Set-HomeStatus 'Wait for the current GitHub upload to finish.' 'error'
    } else {
      Set-Status 'Wait for the current operation to finish.' $true
    }
    return
  }
  if (-not $Confirmed) {
    if ($HomeStatus) {
      Set-HomeStatus 'Confirm that existing repository files will be replaced before uploading.' 'error'
    } else {
      Set-Status 'Confirm that existing repository files will be replaced before uploading.' $true
    }
    return
  }
  $url = if ($RepositoryUrl) { $RepositoryUrl.Trim() } else { $homeRepoBox.Text.Trim() }
  if (-not (Test-GitHubRepositoryUrl $url)) {
    if ($CloudflareStatus) {
      Set-CloudflareStatus 'Enter a valid GitHub Repo URL first.' $true
    } elseif ($RunLocalStatus) {
      Set-ColoredStatus $runLocalUploadStatusLabel 'Enter a valid GitHub Repo URL first.' 'error'
    } elseif ($HomeStatus) {
      Set-HomeStatus 'Enter a valid GitHub repository URL.' 'error'
    } else {
      Set-Status 'Enter a valid GitHub repository URL.' $true
    }
    return
  }
  try {
    $credentialUser = Get-GitHubCredentialUser $url
  } catch {
    $message = $_.Exception.Message
    if ($CloudflareStatus) {
      Set-CloudflareStatus $message $true
    } elseif ($RunLocalStatus) {
      Set-ColoredStatus $runLocalUploadStatusLabel $message 'error'
    } elseif ($HomeStatus) {
      Set-HomeStatus $message 'error'
    } else {
      Set-Status $message $true
    }
    return
  }
  $uploadSourceFolder = if ($SourceFolder) { [IO.Path]::GetFullPath($SourceFolder) } else { $script:githubDirectory }
  if (-not (Test-Path -LiteralPath $uploadSourceFolder -PathType Container)) {
    $message = "Upload source folder was not found: $uploadSourceFolder"
    if ($CloudflareStatus) {
      Set-CloudflareStatus $message $true
    } elseif ($RunLocalStatus) {
      Set-ColoredStatus $runLocalUploadStatusLabel $message 'error'
    } elseif ($HomeStatus) {
      Set-HomeStatus $message 'error'
    } else {
      Set-Status $message $true
    }
    return
  }
  if ($SourceFolder -and $OnlyPaths.Count -eq 0 -and -not $HomeStatus) {
    if ($CloudflareStatus) {
      Set-CloudflareStatus 'Tick at least one file or folder to upload.' $true
    } elseif ($RunLocalStatus) {
      Set-ColoredStatus $runLocalUploadStatusLabel 'Tick at least one file or folder to upload.' 'error'
    } else {
      Set-Status 'Tick at least one file or folder to upload.' $true
    }
    return
  }

  Set-GitHubControlsEnabled $false
  $script:uploadCancelled = $false
  $script:uploadStatusTarget = if ($CloudflareStatus) { 'cloudflare' } elseif ($RunLocalStatus) { 'runlocal' } else { 'home' }
  $script:uploadDestinationUrl = $url
  $script:uploadProgressFile = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-upload-progress-' + [Guid]::NewGuid().ToString('N') + '.txt')
  $script:uploadResultFile = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-upload-result-' + [Guid]::NewGuid().ToString('N') + '.txt')
  $script:lastUploadProgress = 'Starting the isolated upload process...'
  try {
    Remove-Item -LiteralPath $uploadErrorLogFile -Force -ErrorAction SilentlyContinue
    $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $quote = { param([string]$Value) "'" + $Value.Replace("'", "''") + "'" }
    $workerCommand = '$env:COMBOX_FORM_SELF = ' + (& $quote $applicationScriptPath) +
      '; & ([scriptblock]::Create([IO.File]::ReadAllText($env:COMBOX_FORM_SELF)))' +
      ' -UploadWorker -RepositoryUrl ' + (& $quote $url) +
      ' -GitHubUser ' + (& $quote $credentialUser) +
      ' -ProgressFile ' + (& $quote $script:uploadProgressFile) +
      ' -ResultFile ' + (& $quote $script:uploadResultFile) +
      ' -SourceFolder ' + (& $quote $uploadSourceFolder)
    if ($OnlyPaths.Count -gt 0) {
      # Only the ticked items: their names go to the worker in a list file.
      $script:uploadOnlyListFile = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-upload-only-' + [Guid]::NewGuid().ToString('N') + '.txt')
      [System.IO.File]::WriteAllLines($script:uploadOnlyListFile, [string[]]$OnlyPaths, (New-Object System.Text.UTF8Encoding($false)))
      $workerCommand += ' -OnlyListFile ' + (& $quote $script:uploadOnlyListFile)
    }
    $arguments = '-NoProfile -ExecutionPolicy Bypass -STA -EncodedCommand ' +
      [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($workerCommand))
    $script:uploadProcess = Start-NoWindowProcess $powerShellPath $arguments $uploadSourceFolder -GitHubUser $credentialUser
    Set-GitHubControlsEnabled $false
    if ($CloudflareStatus) {
      Set-CloudflareStatus "Uploading selected items from $uploadSourceFolder to $(Get-DisplayRepositoryUrl $url)/tree/$mainBranch..."
    } elseif ($RunLocalStatus) {
      Set-ColoredStatus $runLocalUploadStatusLabel "Uploading checked Local items from $uploadSourceFolder to $(Get-DisplayRepositoryUrl $url)/tree/$mainBranch..." 'busy'
    } elseif ($HomeStatus) {
      Set-HomeStatus "Uploading this folder to $(Get-DisplayRepositoryUrl $url)/tree/$mainBranch..."
    } else {
      Set-Status "Uploading files to $(Get-DisplayRepositoryUrl $url)/tree/$mainBranch..."
    }
    $uploadTimer.Start()
  } catch {
    if ($script:uploadOnlyListFile) {
      Remove-Item -LiteralPath $script:uploadOnlyListFile -Force -ErrorAction SilentlyContinue
      $script:uploadOnlyListFile = ''
    }
    if ($script:uploadProcess) {
      $script:uploadProcess.Dispose()
      $script:uploadProcess = $null
    }
    Set-GitHubControlsEnabled $true
    if ($CloudflareStatus) {
      Set-CloudflareStatus $_.Exception.Message $true
    } elseif ($RunLocalStatus) {
      Set-ColoredStatus $runLocalUploadStatusLabel $_.Exception.Message 'error'
    } elseif ($HomeStatus) {
      Set-HomeStatus $_.Exception.Message 'error'
    } else {
      Set-Status $_.Exception.Message $true
    }
    Show-ComBoxMessage ($_.Exception.ToString()) 'Could not start GitHub upload' $true
  }
}

function Invoke-RunLocalRepoUpload {
  try {
    $folder = [IO.Path]::GetFullPath([string]$script:sectionFolders['runlocal'])
    $repo = $runLocalPrefixBox.Text.Trim()
    if (-not (Test-GitHubRepositoryUrl $repo)) {
      throw 'Choose or enter a valid GitHub Repo URL first.'
    }
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
      throw "Local folder not found: $folder"
    }
    if ($script:runLocalFilesLoadedFor -ine $folder) {
      Update-RunLocalFilesList
    }
    if ($script:runLocalFilesLoadedFor -ine $folder) {
      throw "Could not load the Local file list for upload: $folder"
    }
    if ($runLocalFilesList.IsCurrentCellDirty) {
      $runLocalFilesList.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
    }
    $runLocalFilesList.EndEdit()
    Save-RunLocalUploadSelection
    $selectedPaths = @(
      foreach ($row in $runLocalFilesList.Rows) {
        if (-not [bool]$row.Cells['Upload'].Value) { continue }
        $name = ([string]$row.Cells['Name'].Value) -replace '^\[Folder\] ', ''
        if (-not $name -or $name -in @('.git', '.', '..') -or $name.Contains('\') -or $name.Contains('/')) {
          continue
        }
        $itemPath = Join-Path $folder $name
        if ((Test-Path -LiteralPath $itemPath -PathType Leaf) -or (Test-Path -LiteralPath $itemPath -PathType Container)) {
          $name
        }
      }
    )
    if ($selectedPaths.Count -eq 0) {
      throw 'Tick at least one existing file or folder in the Upload column.'
    }
    $shown = @($selectedPaths | Select-Object -First 12) -join "`r`n   "
    if ($selectedPaths.Count -gt 12) {
      $shown += "`r`n   ... and $($selectedPaths.Count - 12) more"
    }
    $question = "Upload only the ticked Local items to this Repo?`r`n`r`nLocal folder:  $folder`r`nRepo:  $repo`r`n`r`n   $shown`r`n`r`nMatching paths on the main branch will be replaced; all other Repo contents will stay unchanged."
    $answer = [System.Windows.Forms.MessageBox]::Show(
      $form,
      $question,
      'Fresh upload checked Local items',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Warning,
      [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
      Set-ColoredStatus $runLocalUploadStatusLabel 'Repo upload cancelled.' 'info'
      return
    }
    Start-GitHubUpload -OnlyPaths $selectedPaths -RepositoryUrl $repo -SourceFolder $folder -Confirmed -RunLocalStatus
  } catch {
    Set-ColoredStatus $runLocalUploadStatusLabel ('Could not upload checked Local items: ' + $_.Exception.Message) 'error'
  }
}

# Cloudflare jobs run in a separate cmd process (output goes to a temp log file),
# so no PowerShell code runs on a background thread. Loading info is shown in the
# Cloudflare status line at the bottom of the Cloudflare border.
$script:cloudflareJob = $null
$script:cloudflareLoadingStart = $null
$script:cloudflareLoadingTitle = ''
$script:cloudflareLoadingStep = ''
$script:cloudflareHideLoadingTitle = $false
$script:cloudflareDotCount = 0
$cloudflareTimer = New-Object System.Windows.Forms.Timer
$cloudflareTimer.Interval = 400

function Get-CloudflareElapsedText {
  if (-not $script:cloudflareLoadingStart) {
    return '00:00'
  }
  $elapsed = (Get-Date) - $script:cloudflareLoadingStart
  return ('{0:00}:{1:00}' -f [int][Math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds)
}

function Update-CloudflareLoadingLine {
  if (-not $script:cloudflareLoadingStart) {
    return
  }
  $script:cloudflareDotCount = ($script:cloudflareDotCount % 3) + 1
  $text = if ($script:cloudflareHideLoadingTitle) {
    ''
  } else {
    $script:cloudflareLoadingTitle + ('.' * $script:cloudflareDotCount) + '   |   '
  }
  $text += 'Elapsed: ' + (Get-CloudflareElapsedText)
  if ($script:cloudflareLoadingStep) {
    $text += '   |   ' + $script:cloudflareLoadingStep
  }
  $cloudflareStatusLabel.Text = $text
  $cloudflareStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(38, 105, 176)
  $toolTip.SetToolTip($cloudflareStatusLabel, $script:cloudflareLoadingStep)
}

function Set-CloudflareResult {
  param([string]$Text, [bool]$IsError = $false)
  Set-CloudflareStatus ($Text + '   |   Total time: ' + (Get-CloudflareElapsedText)) $IsError
  if (-not $IsError) {
    $cloudflareStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 130, 60)
  }
}

function Read-CloudflareJobLog {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return ''
  }
  $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try {
    $reader = New-Object System.IO.StreamReader($stream)
    return $reader.ReadToEnd()
  } finally {
    $stream.Dispose()
  }
}

function Start-CloudflareJob {
  param(
    [string]$Kind,
    [string]$Command,
    [string]$Title,
    [string]$Name = '',
    [string]$InputText = '',
    [string]$ProjectDirectory = '',
    [string]$CleanupFile = '',
    [string]$GitHubUser = '',
    [switch]$HideStatusTitle
  )

  $jobProjectDirectory = if ($ProjectDirectory) { $ProjectDirectory } else { $script:cloudflareDirectory }
  if (-not (Test-Path -LiteralPath $jobProjectDirectory -PathType Container)) {
    throw "Cloudflare project folder not found: $jobProjectDirectory"
  }

  $logFile = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-cloudflare-' + [Guid]::NewGuid().ToString('N') + '.log')
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $env:ComSpec
  $startInfo.Arguments = '/d /s /c "' + $Command + ' > "' + $logFile + '" 2>&1"'
  $startInfo.WorkingDirectory = $jobProjectDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.EnvironmentVariables['RUBELAPP_PROJECT_DIR'] = $jobProjectDirectory
  if ($GitHubUser) {
    $startInfo.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $startInfo.EnvironmentVariables['GCM_INTERACTIVE'] = 'never'
    $startInfo.EnvironmentVariables['GIT_CONFIG_COUNT'] = '1'
    $startInfo.EnvironmentVariables['GIT_CONFIG_KEY_0'] = 'credential.https://github.com.username'
    $startInfo.EnvironmentVariables['GIT_CONFIG_VALUE_0'] = $GitHubUser
  }
  $startInfo.CreateNoWindow = $true
  $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
  $startInfo.RedirectStandardInput = $true

  $process = [System.Diagnostics.Process]::Start($startInfo)
  if (-not $process) {
    throw "Could not start: $Title"
  }
  if ($InputText) {
    $process.StandardInput.WriteLine($InputText)
  }
  $process.StandardInput.Close()

  $script:cloudflareJob = [pscustomobject]@{
    Kind    = $Kind
    Name    = $Name
    Process = $process
    LogFile = $logFile
    CleanupFile = $CleanupFile
  }
  $script:cloudflareLoadingStart = Get-Date
  $script:cloudflareLoadingTitle = $Title
  $script:cloudflareHideLoadingTitle = [bool]$HideStatusTitle
  $script:cloudflareLoadingStep = 'Starting...'
  $script:cloudflareDotCount = 0
  Update-CloudflareLoadingLine
  $cloudflareTimer.Start()
}

$cloudflareTimer.Add_Tick({
  $job = $script:cloudflareJob
  if (-not $job) {
    $cloudflareTimer.Stop()
    return
  }

  $log = ''
  try {
    $log = Read-CloudflareJobLog $job.LogFile
  } catch {
    $log = ''
  }
  $lastLine = @($log -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1)
  if ($lastLine.Count -gt 0) {
    $script:cloudflareLoadingStep = $lastLine[0].Trim()
  }

  if (-not $job.Process.HasExited) {
    Update-CloudflareLoadingLine
    return
  }

  $cloudflareTimer.Stop()
  $exitCode = $job.Process.ExitCode
  $job.Process.Dispose()
  $script:cloudflareJob = $null
  Remove-Item -LiteralPath $job.LogFile -Force -ErrorAction SilentlyContinue
  if ($job.CleanupFile) {
    try {
      Remove-Item -LiteralPath $job.CleanupFile -Force -ErrorAction Stop
    } catch {
      Show-ComBoxMessage ('Could not remove the temporary Cloudflare deployment script: ' + $_.Exception.Message) 'Cloudflare cleanup failed' $true
    }
  }
  if ($job.SecretFile) {
    Remove-Item -LiteralPath $job.SecretFile -Force -ErrorAction SilentlyContinue
  }
  $details = $log.Trim()
  Set-CloudflareControlsEnabled $true

  if ($job.Kind -eq 'deploy') {
    if ($exitCode -eq 0 -and $details -match '(?i)\b([1-9]\d*) secrets? failed') {
      $exitCode = 1
    }
    try {
      Update-DeployLink -Force
    } catch {
      Show-ComBoxMessage ($_.Exception.Message) 'Could not read deploy link' $true
    }
    if ($exitCode -ne 0) {
      if (-not $details) {
        $details = "Cloudflare deployment failed (exit code $exitCode)."
      }
      Set-CloudflareResult 'Deploy failed' $true
      $script:cloudflareLoadingStart = $null
      Show-ComBoxMessage ($details) 'Cloudflare deployment failed' $true
      return
    }
    Set-CloudflareResult 'Deploy complete'
    $script:cloudflareLoadingStart = $null
    if (-not $details) {
      $details = 'Cloudflare deployment complete.'
    }
    Show-ComBoxMessage ($details) 'Cloudflare deployment complete' $false
    return
  }

  if ($exitCode -eq 0 -and $details -match '(?i)\b([1-9]\d*) secrets? failed') {
    $exitCode = 1
  }
  if ($exitCode -ne 0) {
    if (-not $details) {
      $details = "Wrangler exited with code $exitCode while uploading $($job.Name)."
    }
    Set-CloudflareResult "$($job.Name) upload failed" $true
    $script:cloudflareLoadingStart = $null
    Show-ComBoxMessage ($details) 'Cloudflare secret upload failed' $true
    return
  }
  Set-CloudflareResult "$($job.Name) saved to $($job.Worker) (Production)"
  $script:cloudflareLoadingStart = $null
  $script:cloudflareLoadingStart = $null
})

function Start-CloudflareSecretUpload {
  if (Test-CloudflareBusy) {
    Set-CloudflareStatus 'Wait for the current operation to finish.' $true
    return
  }

  $secrets = [ordered]@{}
  if (-not [string]::IsNullOrWhiteSpace($githubTokenBox.Text)) {
    $secrets['GITHUB_TOKEN'] = $githubTokenBox.Text.Trim()
  }
  if (-not [string]::IsNullOrWhiteSpace($sessionCodeBox.Text)) {
    $secrets['SESSION_CODE'] = $sessionCodeBox.Text.Trim()
  }
  if ($secrets.Count -eq 0) {
    Set-CloudflareStatus 'Enter GITHUB_TOKEN, SESSION_CODE or both first.' $true
    return
  }

  try {
    $worker = Get-CloudflareWorkerName
  } catch {
    Set-CloudflareStatus $_.Exception.Message $true
    return
  }

  $names = @($secrets.Keys)
  $secretFile = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-secrets-' + [Guid]::NewGuid().ToString('N') + '.json')
  Set-CloudflareControlsEnabled $false
  try {
    $json = [pscustomobject]$secrets | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($secretFile, $json, (New-Object System.Text.UTF8Encoding($false)))
    $command = 'call npx.cmd --yes wrangler@latest secret bulk "' + $secretFile + '" --name ' + $worker
    Start-CloudflareJob -Kind 'secret' -Command $command -Title "Uploading $($names -join ' + ') to $worker" -Name ($names -join ', ')
    $script:cloudflareJob | Add-Member -NotePropertyName SecretFile -NotePropertyValue $secretFile
    $script:cloudflareJob | Add-Member -NotePropertyName SecretNames -NotePropertyValue $names
    $script:cloudflareJob | Add-Member -NotePropertyName Worker -NotePropertyValue $worker
  } catch {
    Remove-Item -LiteralPath $secretFile -Force -ErrorAction SilentlyContinue
    $script:cloudflareJob = $null
    Set-CloudflareControlsEnabled $true
    Set-CloudflareStatus $_.Exception.Message $true
    Show-ComBoxMessage ($_.Exception.Message) 'Cloudflare secret upload failed' $true
  }
}

function Set-GitHubActionsSecret {
  param(
    [string]$GitHubCli,
    [string]$Repository,
    [string]$Name,
    [string]$Value
  )

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $GitHubCli
  $startInfo.Arguments = 'secret set ' + $Name + ' --repo ' + $Repository
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) {
      throw "Could not start GitHub CLI while setting $Name."
    }
    $standardOutput = $process.StandardOutput.ReadToEndAsync()
    $standardError = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write($Value)
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(60000)) {
      if (-not $process.HasExited) {
        $process.Kill()
      }
      throw "Timed out while setting $Name in GitHub Actions secrets."
    }
    $output = $standardOutput.GetAwaiter().GetResult().Trim()
    $details = $standardError.GetAwaiter().GetResult().Trim()
    if ($process.ExitCode -ne 0) {
      if (-not $details) {
        $details = $output
      }
      throw "GitHub CLI could not set $Name. $details"
    }
  } finally {
    $process.Dispose()
  }
}

function Show-GitHubActionsSecretsDialog {
  if (Test-CloudflareBusy) {
    Set-CloudflareStatus 'Wait for the current operation to finish.' $true
    return
  }

  $repoPattern = '^(?:https?://)?(?:www\.)?github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+?)(?:\.git)?(?:/.*)?$'
  $repoMatch = [regex]::Match($deployRepoBox.Text.Trim(), $repoPattern)
  if (-not $repoMatch.Success) {
    Set-CloudflareStatus 'Choose a valid GitHub Repo before setting Actions secrets.' $true
    return
  }
  $githubCli = Get-Command gh -ErrorAction SilentlyContinue
  if (-not $githubCli) {
    Set-CloudflareStatus 'GitHub CLI is not installed. Install gh and sign in with gh auth login.' $true
    Show-ComBoxMessage 'Install GitHub CLI (gh), run gh auth login, then try again.' 'GitHub CLI required' $true
    return
  }

  $repository = $repoMatch.Groups[1].Value + '/' + $repoMatch.Groups[2].Value
  $dialog = New-Object System.Windows.Forms.Form
  $dialog.Text = 'GitHub Actions deploy secrets'
  $dialog.ClientSize = New-Object System.Drawing.Size(500, 254)
  $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
  $dialog.MaximizeBox = $false
  $dialog.MinimizeBox = $false
  $dialog.ShowInTaskbar = $false

  $repoLabel = New-Object System.Windows.Forms.Label
  $repoLabel.Text = "GitHub Repo: $repository"
  $repoLabel.Location = New-Object System.Drawing.Point(18, 14)
  $repoLabel.Size = New-Object System.Drawing.Size(460, 22)
  $repoLabel.AutoEllipsis = $true
  $dialog.Controls.Add($repoLabel)

  $tokenLabel = New-Object System.Windows.Forms.Label
  $tokenLabel.Text = 'CLOUDFLARE_API_TOKEN'
  $tokenLabel.Location = New-Object System.Drawing.Point(18, 47)
  $tokenLabel.Size = New-Object System.Drawing.Size(460, 20)
  $dialog.Controls.Add($tokenLabel)

  $tokenBox = New-Object System.Windows.Forms.TextBox
  $tokenBox.Location = New-Object System.Drawing.Point(18, 68)
  $tokenBox.Size = New-Object System.Drawing.Size(460, 25)
  $tokenBox.UseSystemPasswordChar = $true
  $dialog.Controls.Add($tokenBox)

  $accountLabel = New-Object System.Windows.Forms.Label
  $accountLabel.Text = 'CLOUDFLARE_ACCOUNT_ID'
  $accountLabel.Location = New-Object System.Drawing.Point(18, 101)
  $accountLabel.Size = New-Object System.Drawing.Size(460, 20)
  $dialog.Controls.Add($accountLabel)

  $accountBox = New-Object System.Windows.Forms.TextBox
  $accountBox.Location = New-Object System.Drawing.Point(18, 122)
  $accountBox.Size = New-Object System.Drawing.Size(460, 25)
  $accountBox.UseSystemPasswordChar = $true
  $dialog.Controls.Add($accountBox)

  $helpLabel = New-Object System.Windows.Forms.Label
  $helpLabel.Text = 'Values are sent to GitHub Actions secrets and are not saved by Form.bat.'
  $helpLabel.Location = New-Object System.Drawing.Point(18, 157)
  $helpLabel.Size = New-Object System.Drawing.Size(460, 32)
  $helpLabel.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $dialog.Controls.Add($helpLabel)

  $uploadButton = New-Object System.Windows.Forms.Button
  $uploadButton.Text = 'Upload'
  $uploadButton.Location = New-Object System.Drawing.Point(306, 204)
  $uploadButton.Size = New-Object System.Drawing.Size(82, 30)
  $uploadButton.Add_Click({
    $apiToken = $tokenBox.Text.Trim()
    $accountId = $accountBox.Text.Trim()
    if (-not $apiToken) {
      Show-ComBoxMessage 'Enter CLOUDFLARE_API_TOKEN.' 'Missing value' $true
      return
    }
    if ($accountId -notmatch '^[A-Fa-f0-9]{32}$') {
      Show-ComBoxMessage 'CLOUDFLARE_ACCOUNT_ID must contain 32 hexadecimal characters.' 'Invalid account ID' $true
      return
    }
    try {
      Set-CloudflareStatus "Uploading CLOUDFLARE_API_TOKEN to GitHub Actions secrets for $repository..."
      Set-GitHubActionsSecret -GitHubCli $githubCli.Source -Repository $repository -Name 'CLOUDFLARE_API_TOKEN' -Value $apiToken
      Set-CloudflareStatus "Uploading CLOUDFLARE_ACCOUNT_ID to GitHub Actions secrets for $repository..."
      Set-GitHubActionsSecret -GitHubCli $githubCli.Source -Repository $repository -Name 'CLOUDFLARE_ACCOUNT_ID' -Value $accountId
      $tokenBox.Clear()
      $accountBox.Clear()
      Set-CloudflareStatus "Cloudflare deploy secrets saved to GitHub Actions for $repository."
      $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
      $dialog.Close()
    } catch {
      Set-CloudflareStatus $_.Exception.Message $true
      Show-ComBoxMessage $_.Exception.Message 'GitHub Actions secret upload failed' $true
    }
  })
  $dialog.Controls.Add($uploadButton)

  $cancelButton = New-Object System.Windows.Forms.Button
  $cancelButton.Text = 'Cancel'
  $cancelButton.Location = New-Object System.Drawing.Point(396, 204)
  $cancelButton.Size = New-Object System.Drawing.Size(82, 30)
  $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $dialog.Controls.Add($cancelButton)
  $dialog.AcceptButton = $uploadButton
  $dialog.CancelButton = $cancelButton

  Register-FormButtonSoundControl $dialog
  try {
    [void]$dialog.ShowDialog($form)
  } finally {
    $tokenBox.Clear()
    $accountBox.Clear()
    $dialog.Dispose()
  }
}

$githubTokenUploadButton.Add_Click({ Start-CloudflareSecretUpload })
$sessionCodeUploadButton.Add_Click({ Start-CloudflareSecretUpload })

function Start-CloudflareDeploy {
  param(
    [bool]$LocalFolderOnly = $false,
    [bool]$RepositoryOnly = $false
  )

  if (Test-CloudflareBusy) {
    Set-CloudflareStatus 'Wait for the current operation to finish.' $true
    return
  }
  if ($LocalFolderOnly -and $RepositoryOnly) {
    Set-CloudflareStatus 'Choose either Local-folder deployment or Repo deployment, not both.' $true
    return
  }
  try {
    $worker = Get-CloudflareWorkerName
  } catch {
    Set-CloudflareStatus $_.Exception.Message $true
    return
  }

  $localProjectDirectory = ''
  if ($LocalFolderOnly) {
    $localProjectDirectory = $localDeployFolderBox.Text.Trim()
    if (-not $localProjectDirectory -or -not (Test-Path -LiteralPath $localProjectDirectory -PathType Container)) {
      Set-CloudflareStatus 'Choose an existing local project folder with the search button first.' $true
      return
    }
  }
  $repoText = ''
  if ($RepositoryOnly) {
    try {
      if (-not (Test-Path -LiteralPath $deployRepoFile -PathType Leaf)) {
        throw "The saved Repo link file was not found: $deployRepoFile"
      }
      $repoText = ([string](Get-Content -LiteralPath $deployRepoFile -Raw -ErrorAction Stop)).Trim()
      if (-not $repoText) {
        throw 'Enter and save a GitHub Repo link before deploying.'
      }
    } catch {
      Set-CloudflareStatus ('Could not read the saved Repo link: ' + $_.Exception.Message) $true
      return
    }
  } elseif (-not $LocalFolderOnly) {
    $repoText = $deployRepoBox.Text.Trim()
  }
  $projectDirectory = if ($LocalFolderOnly) {
    $localProjectDirectory
  } elseif ($RepositoryOnly) {
    [IO.Path]::GetTempPath()
  } else {
    $script:cloudflareDirectory
  }
  $title = if ($RepositoryOnly) {
    "Deploying from GitHub Repo to $worker"
  } else {
    "Deploying $projectDirectory to $worker"
  }
  $repoUrl = ''
  $cloneDir = ''
  if ($repoText) {
    $repoMatch = [regex]::Match($repoText, '^(?:https?://)?(?:www\.)?github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+?)(?:\.git)?(?:/.*)?$')
    if (-not $repoMatch.Success) {
      Set-CloudflareStatus 'Repo must be a GitHub link, like https://github.com/jakirfile/rubelapp' $true
      return
    }
    $repoUrl = 'https://github.com/' + $repoMatch.Groups[1].Value + '/' + $repoMatch.Groups[2].Value + '.git'
    $cloneDir = Join-Path ([IO.Path]::GetTempPath()) 'combox-cloudflare-deploy'
    $title = "Deploying from GitHub Repo $($repoMatch.Groups[1].Value)/$($repoMatch.Groups[2].Value) to $worker"
  }
  if ($RepositoryOnly -and -not $repoUrl) {
    Set-CloudflareStatus 'A valid saved GitHub Repo link is required; Local-folder deployment is disabled for this button.' $true
    return
  }

  $credentialUser = ''
  if ($repoUrl) {
    try {
      $credentialUser = Get-GitHubCredentialUser $repoUrl
    } catch {
      Set-CloudflareStatus $_.Exception.Message $true
      return
    }
  }

  Set-CloudflareControlsEnabled $false
  $deployScript = $null
  try {
    $deployScript = New-CloudflareDeploymentScript
    $command = 'call "' + $deployScript + '" /noninteractive ' + $worker
    if ($repoUrl) {
      $command = '(if exist "' + $cloneDir + '" rmdir /s /q "' + $cloneDir + '") & (git clone --depth 1 "' + $repoUrl + '" "' + $cloneDir + '" && set "RUBELAPP_PROJECT_DIR=' + $cloneDir + '" && cd /d "' + $cloneDir + '" && ' + $command + ')'
    }
    Start-CloudflareJob -Kind 'deploy' -Command $command -Title $title -ProjectDirectory $projectDirectory -CleanupFile $deployScript -GitHubUser $credentialUser -HideStatusTitle:$RepositoryOnly
    $script:cloudflareJob | Add-Member -NotePropertyName SecretFile -NotePropertyValue $secretFile
  } catch {
    $errorMessage = $_.Exception.Message
    if ($deployScript -and (Test-Path -LiteralPath $deployScript -PathType Leaf)) {
      try {
        Remove-Item -LiteralPath $deployScript -Force -ErrorAction Stop
      } catch {
        $errorMessage += "`r`nCould not remove the temporary deployment script: $($_.Exception.Message)"
      }
    }
    $script:cloudflareJob = $null
    Set-CloudflareControlsEnabled $true
    Set-CloudflareStatus $errorMessage $true
    Show-ComBoxMessage ($errorMessage) 'Cloudflare deployment failed' $true
  }
}

$deployAction = { Start-CloudflareDeploy -RepositoryOnly $true }
$deployIconButton.Add_Click($deployAction)
$localDeployAction = {
  $configPath = $null
  try {
    $localFolder = $localDeployFolderBox.Text.Trim()
    if (-not $localFolder) {
      throw 'Choose a Local folder before updating wrangler.jsonc.'
    }
    if (-not (Test-Path -LiteralPath $localFolder -PathType Container)) {
      throw "The Local folder does not exist: $localFolder"
    }
    $configPath = Join-Path ([IO.Path]::GetFullPath($localFolder)) 'wrangler.jsonc'

    $worker = Get-CloudflareWorkerName
    $workerLink = Get-ComBoxLinkFromAppName $webpageUrlInputBox.Text
    if (-not $workerLink) {
      throw 'Could not generate the Worker link from AppName.'
    }

    $repoPattern = '^(?:https?://)?(?:www\.)?github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+?)(?:\.git)?(?:/.*)?$'
    $repoText = $deployRepoBox.Text.Trim()
    if ($repoText) {
      $repoMatch = [regex]::Match($repoText, $repoPattern)
      if (-not $repoMatch.Success) {
        throw 'Repo must be a GitHub link, like https://github.com/jakirfile/rubelapp.'
      }
    } else {
      $repoMatch = [regex]::Match($script:defaultRepositoryUrl, $repoPattern)
      if (-not $repoMatch.Success) {
        throw 'Could not determine the GitHub account from the default repository URL.'
      }
    }
    $repoOwner = $repoMatch.Groups[1].Value
    $repoUrl = 'https://github.com/' + $repoOwner + '/' + $worker

    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
      throw "File not found: $configPath"
    }
    $repositoryName = $repoOwner + '/' + $worker
    $configUpdate = Get-WranglerWorkerNameUpdate -ConfigPath $configPath -WorkerName $worker -RepositoryName $repositoryName
    if ($configUpdate.Changed) {
      Save-LocalCloudflareStarterFiles @($configUpdate)
    }

    [IO.File]::WriteAllText($deployRepoFile, $repoUrl, (New-Object System.Text.UTF8Encoding($false)))
    $script:cloudflareSecretsRestoring = $true
    try {
      $webpageUrlBox.Text = $workerLink
      $deployRepoBox.Text = $repoUrl
    } finally {
      $script:cloudflareSecretsRestoring = $false
    }
    Update-SecretTargetTitle
    Set-ComBoxDataPendingChanges $true

    $content = [IO.File]::ReadAllText($configPath)
    $updateStatus = if ($configUpdate.Changed) {
      if ($configUpdate.HasRepositoryProperty) {
        "Updated only name and existing vars.GITHUB_REPO to $repositoryName; all other config was preserved."
      } else {
        "Updated only the top-level name from AppName: $worker; vars.GITHUB_REPO is absent, so all other config was preserved."
      }
    } else {
      if ($configUpdate.HasRepositoryProperty) {
        "name and vars.GITHUB_REPO are already up to date for $repositoryName"
      } else {
        "Top-level name is already up to date for AppName: $worker; no other config was changed."
      }
    }
    Show-ComBoxMessage ("Worker link: $workerLink`r`nGitHub repo: $repoUrl`r`n`r`n$updateStatus`r`n`r`nFile: $configPath`r`n`r`n$content`r`n`r`nClick Save Cloudflare fields to Data to save the current app record.") 'wrangler.jsonc' $false
  } catch {
    $script:cloudflareSecretsRestoring = $false
    $displayPath = if ($configPath) { $configPath } else { 'wrangler.jsonc in the selected Local folder' }
    $details = "File: $displayPath`r`nCould not update this file.`r`n`r`n" + $_.Exception.Message
    if ($configPath -and (Test-Path -LiteralPath $configPath -PathType Leaf)) {
      try {
        $details += "`r`n`r`nCurrent file content:`r`n" + [IO.File]::ReadAllText($configPath)
      } catch {
        $details += "`r`n`r`nCould not read the file content: $($_.Exception.Message)"
      }
    }
    Show-ComBoxMessage $details 'wrangler.jsonc update failed' $true
  }
}
$localDeployIconButton.Add_Click($localDeployAction)
$localDeployUploadButton.Add_Click({
  try {
    if (Test-GitHubBusy) {
      Set-CloudflareStatus 'Wait for the current GitHub upload to finish.' $true
      return
    }
    $folder = $localDeployFolderBox.Text.Trim()
    if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
      throw "Choose an existing Local folder first: $folder"
    }
    $repo = $deployRepoBox.Text.Trim()
    if (-not (Test-GitHubRepositoryUrl $repo)) {
      throw 'Enter a valid GitHub Repo URL before uploading.'
    }
    if ($localDeployFilesList.IsCurrentCellDirty) {
      $localDeployFilesList.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
    }
    $localDeployFilesList.EndEdit()
    if (-not $script:cloudflareLocalFilesExpanded) {
      Update-LocalDeployFilesList
    }
    $worker = Get-CloudflareWorkerName
    $starterFiles = @(Get-LocalCloudflareStarterFiles -Folder $folder -WorkerName $worker)
    $newStarterFiles = @($starterFiles | Where-Object { $_.IsNew })
    $selectedPaths = @(
      foreach ($row in $localDeployFilesList.Rows) {
        if (-not [bool]$row.Cells['Upload'].Value) {
          continue
        }
        $name = [string]$row.Cells['Name'].Value
        $name = $name -replace '^\[Folder\] ', ''
        if (-not $name -or $name -in @('.git', '.', '..') -or $name.Contains('\') -or $name.Contains('/')) {
          continue
        }
        $path = Join-Path $folder $name
        if ((Test-Path -LiteralPath $path -PathType Leaf) -or (Test-Path -LiteralPath $path -PathType Container)) {
          $name
        }
      }
    )
    if ($selectedPaths.Count -eq 0 -and $newStarterFiles.Count -eq 0) {
      Set-CloudflareStatus 'No Local items are checked. Tick the files or folders to upload in the list above, then click Upload again. GitHub authentication is only needed after an upload starts.'
      return
    }
    $wranglerConfigIncluded = $selectedPaths -contains 'wrangler.jsonc'
    if (-not $wranglerConfigIncluded) {
      $selectedPaths += 'wrangler.jsonc'
    }
    foreach ($starterFile in $newStarterFiles) {
      $starterName = [IO.Path]::GetFileName([string]$starterFile.Path)
      if ($selectedPaths -notcontains $starterName) {
        $selectedPaths += $starterName
      }
    }
    $shown = @($selectedPaths | Select-Object -First 12) -join "`r`n   "
    if ($selectedPaths.Count -gt 12) {
      $shown += "`r`n   ... and $($selectedPaths.Count - 12) more"
    }
    $starterNames = @($newStarterFiles | ForEach-Object { [IO.Path]::GetFileName([string]$_.Path) })
    $starterNote = if ($starterNames.Count -gt 0) {
      'Missing starter files will be created: ' + ($starterNames -join ', ') + '.'
    } else {
      'No starter files need to be created.'
    }
    $configSelectionNote = if ($wranglerConfigIncluded) {
      'wrangler.jsonc is checked and its name will be synchronized.'
    } else {
      'wrangler.jsonc is automatically included even though it is not checked.'
    }
    $question = "Upload these Local items to this GitHub Repo?`r`n`r`nLocal folder:  $folder`r`nRepo:  $repo`r`nAppName:  $worker`r`n`r`n   $shown`r`n`r`n$starterNote Before upload, wrangler.jsonc ""name"" will be set to ""$worker"". $configSelectionNote These items will replace matching files/folders on the main branch; all other Repo contents will stay unchanged."
    $answer = [System.Windows.Forms.MessageBox]::Show(
      $form,
      $question,
      'Upload selected items to Repo',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Warning,
      [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
      Set-CloudflareStatus 'Repo upload cancelled.'
      return
    }
    Save-LocalCloudflareStarterFiles $starterFiles
    Update-LocalDeployFilesList
    Set-CloudflareStatus "Prepared wrangler.jsonc and worker files for '$worker'; uploading the Local items to Repo..."
    Start-GitHubUpload -OnlyPaths $selectedPaths -RepositoryUrl $repo -SourceFolder $folder -Confirmed -CloudflareStatus
  } catch {
    Set-CloudflareStatus ('Could not upload checked items to Repo: ' + $_.Exception.Message) $true
  }
})

# Which tab is open and each tab's height: Form.bat ($FormLayout.Sections)

# Rename section: replaces exact-case text and file/folder names in a folder,
# using the embedded rename worker in this file.
$renamePanel = New-FormSectionPanel 'rename'

function New-RenameLabel {
  param([string]$Text, [int]$X, [int]$Y, [int]$Width)
  $label = New-Object System.Windows.Forms.Label
  $label.Text = $Text
  $label.Location = New-Object System.Drawing.Point($X, $Y)
  $label.Size = New-Object System.Drawing.Size($Width, 22)
  $label.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $renamePanel.Controls.Add($label)
  return $label
}

$null = New-RenameLabel 'Folder' 14 48 90
$renameFolderBox = New-Object System.Windows.Forms.TextBox
$renameFolderBox.Location = New-Object System.Drawing.Point(110, 45)
$renameFolderBox.Size = New-Object System.Drawing.Size(732, 26)
$renameFolderBox.Text = $projectDirectory
$renamePanel.Controls.Add($renameFolderBox)
$renameBrowseButton = New-ActionButton 'Choose folder' 0xE8B7 0 0
$form.Controls.Remove($renameBrowseButton)
$renameBrowseButton.Location = New-Object System.Drawing.Point(852, 43)
$renamePanel.Controls.Add($renameBrowseButton)

$null = New-RenameLabel 'Mappings' 14 92 90
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CueBannerNative {
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern IntPtr SendMessage(IntPtr handle, int message, IntPtr wParam, string lParam);
}
'@

function New-MappingBox {
  param([int]$X, [int]$Width, [string]$Cue)
  $box = New-Object System.Windows.Forms.TextBox
  $box.Location = New-Object System.Drawing.Point($X, 89)
  $box.Size = New-Object System.Drawing.Size($Width, 26)
  $box.Tag = $Cue
  $box.Add_HandleCreated({
    param($sender, $eventArgs)
    [void][CueBannerNative]::SendMessage($sender.Handle, 0x1501, [IntPtr]1, [string]$sender.Tag)
  })
  $toolTip.SetToolTip($box, $Cue)
  $renamePanel.Controls.Add($box)
  return $box
}

# Left: UPPER-case old -> new     Right: lower-case old -> new
$renameUpperOldBox = New-MappingBox 110 172 'UPPER old  (e.g. IJTC)'
$renameUpperNewBox = New-MappingBox 288 172 'UPPER new  (e.g. ShopApp)'
$renameLowerOldBox = New-MappingBox 492 172 'lower old  (e.g. ijtc)'
$renameLowerNewBox = New-MappingBox 670 172 'lower new  (e.g. shopapp)'
$renameMappingBoxes = @($renameUpperOldBox, $renameUpperNewBox, $renameLowerOldBox, $renameLowerNewBox)

$renameHintLabel = New-RenameLabel 'Left: UPPER-case  old -> new        Right: lower-case  old -> new' 110 128 560
$renameHintLabel.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 130)
$renameHintLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$renameConfirmCheckBox = New-Object System.Windows.Forms.CheckBox
$renameConfirmCheckBox.Text = 'Confirm changes'
$renameConfirmCheckBox.Location = New-Object System.Drawing.Point(690, 126)
$renameConfirmCheckBox.Size = New-Object System.Drawing.Size(150, 26)
$renameConfirmCheckBox.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
$renamePanel.Controls.Add($renameConfirmCheckBox)

$renameRunButton = New-ActionButton 'Rename text and file/folder names in the folder' 0xE8AC 0 0
$form.Controls.Remove($renameRunButton)
$renameRunButton.Location = New-Object System.Drawing.Point(852, 124)
$renameRunButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$renameRunButton.FlatAppearance.BorderSize = 0
$renameRunButton.BackColor = [System.Drawing.Color]::FromArgb(38, 105, 176)
$renameRunButton.ForeColor = [System.Drawing.Color]::White
$renamePanel.Controls.Add($renameRunButton)

$renameStatusLabel = New-Label 'Enter the folder and mappings, tick Confirm changes, then press the rename button.' 37 226 900 24
$renameStatusLabel.AutoEllipsis = $true

$script:renameJob = $null
$script:renameStart = $null
$script:renameDots = 0
$script:renameStep = ''
$renameTimer = New-Object System.Windows.Forms.Timer
$renameTimer.Interval = 400

function Get-RenameElapsedText {
  if (-not $script:renameStart) {
    return '00:00'
  }
  $elapsed = (Get-Date) - $script:renameStart
  return ('{0:00}:{1:00}' -f [int][Math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds)
}

function Set-RenameStatus {
  param([string]$Text, [string]$Kind = 'info')
  $renameStatusLabel.Text = $Text
  $toolTip.SetToolTip($renameStatusLabel, $Text)
  switch ($Kind) {
    'error'   { $renameStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick }
    'success' { $renameStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 130, 60) }
    'busy'    { $renameStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(38, 105, 176) }
    default   { $renameStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103) }
  }
}

function Set-RenameControlsEnabled {
  param([bool]$Enabled)
  foreach ($control in (@($renameFolderBox, $renameBrowseButton, $renameConfirmCheckBox, $renameRunButton) + $renameMappingBoxes)) {
    $control.Enabled = $Enabled
  }
  if ($Enabled) {
    Update-RestartButton
  } else {
    $restartButton.Enabled = $false
  }
}

$renameBrowseButton.Add_Click({
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  try {
    $dialog.Description = 'Choose the folder whose files and folders will be renamed'
    if (Test-Path -LiteralPath $renameFolderBox.Text.Trim() -PathType Container) {
      $dialog.SelectedPath = $renameFolderBox.Text.Trim()
    }
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
      $renameFolderBox.Text = $dialog.SelectedPath
    }
  } finally {
    $dialog.Dispose()
  }
})

$renameRunButton.Add_Click({
  if ($script:renameJob) {
    Set-RenameStatus 'Wait for the current rename to finish.' 'error'
    return
  }
  $folder = $renameFolderBox.Text.Trim()
  if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
    Set-RenameStatus 'Choose a folder that exists.' 'error'
    return
  }
  $values = @($renameMappingBoxes | ForEach-Object { $_.Text.Trim() })
  if (@($values | Where-Object { -not $_ }).Count -gt 0) {
    Set-RenameStatus 'Fill all four boxes: UPPER old, UPPER new (left) and lower old, lower new (right).' 'error'
    return
  }
  if (@($values | Where-Object { $_.Contains(',') -or $_.Contains('=') }).Count -gt 0) {
    Set-RenameStatus 'The rename boxes must not contain a comma (,) or an equals sign (=).' 'error'
    return
  }
  if ($values[0] -ceq $values[1] -or $values[2] -ceq $values[3]) {
    Set-RenameStatus 'Old and new values are identical. Enter a different new name.' 'error'
    return
  }
  $mapping = "$($values[0])=$($values[1]), $($values[2])=$($values[3])"
  if (-not $renameConfirmCheckBox.Checked) {
    Set-RenameStatus 'Tick Confirm changes first. Matching text and file/folder names will be changed.' 'error'
    return
  }
  $id = [Guid]::NewGuid().ToString('N')
  $mappingFile = Join-Path ([IO.Path]::GetTempPath()) ("ijtc-rename-map-$id.txt")
  $logFile = Join-Path ([IO.Path]::GetTempPath()) ("ijtc-rename-$id.log")
  $rootArgument = $folder
  if ($rootArgument.EndsWith('\')) {
    $rootArgument += '.'
  }
  $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $quote = { param([string]$Value) "'" + $Value.Replace("'", "''") + "'" }
  $formPath = if ($env:COMBOX_FORM_SELF) { $env:COMBOX_FORM_SELF } else { Join-Path $toolDirectory 'Form.bat' }
  $renameCommand = '& ([scriptblock]::Create([IO.File]::ReadAllText(' + (& $quote $formPath) + ')))' +
    ' -RenameWorker -RenameRoot ' + (& $quote $rootArgument) + ' -RenameMappingFile ' + (& $quote $mappingFile)
  # Never rename this tool's own files.
  $rootFull = [System.IO.Path]::GetFullPath($folder).TrimEnd('\')
  $toolFull = $toolDirectory.TrimEnd('\')
  $protectedNames = ''
  if ($toolFull -ieq $rootFull) {
    $protectedNames = (@(Get-ChildItem -LiteralPath $toolDirectory -File -Force | ForEach-Object { $_.Name })) -join ','
  } elseif ($toolFull.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    $protectedNames = $toolFull.Substring($rootFull.Length + 1)
  }
  if ($protectedNames) {
    $renameCommand += ' -RenameProtectedNames ' + (& $quote $protectedNames)
  }
  $command = '"' + $powerShellPath + '" -NoProfile -ExecutionPolicy Bypass -OutputFormat Text -EncodedCommand ' +
    [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($renameCommand))

  Set-RenameControlsEnabled $false
  try {
    [System.IO.File]::WriteAllText($mappingFile, $mapping, (New-Object System.Text.UTF8Encoding($false)))
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $env:ComSpec
    $startInfo.Arguments = '/d /s /c "' + $command + ' > "' + $logFile + '" 2>&1"'
    $startInfo.WorkingDirectory = $folder
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $process = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $process) {
      throw 'Could not start the rename process.'
    }
    $script:renameJob = [pscustomobject]@{
      Process     = $process
      LogFile     = $logFile
      MappingFile = $mappingFile
      Mapping     = $mapping
    }
    $script:renameStart = Get-Date
    $script:renameDots = 0
    $script:renameStep = 'Starting...'
    $restartButton.Enabled = $false
    $renameTimer.Start()
  } catch {
    Remove-Item -LiteralPath $mappingFile -Force -ErrorAction SilentlyContinue
    $script:renameJob = $null
    Set-RenameControlsEnabled $true
    Set-RenameStatus $_.Exception.Message 'error'
  }
})

$renameTimer.Add_Tick({
  $job = $script:renameJob
  if (-not $job) {
    $renameTimer.Stop()
    return
  }
  $log = ''
  try {
    $log = Read-CloudflareJobLog $job.LogFile
  } catch {
    $log = ''
  }
  $logLines = @($log -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($logLines.Count -gt 0) {
    $script:renameStep = $logLines[-1].Trim()
  }

  if (-not $job.Process.HasExited) {
    $script:renameDots = ($script:renameDots % 3) + 1
    Set-RenameStatus ('Renaming' + ('.' * $script:renameDots) + '   |   Elapsed: ' + (Get-RenameElapsedText) + '   |   ' + $script:renameStep) 'busy'
    return
  }

  $renameTimer.Stop()
  $exitCode = $job.Process.ExitCode
  $job.Process.Dispose()
  $script:renameJob = $null
  Remove-Item -LiteralPath $job.MappingFile -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $job.LogFile -Force -ErrorAction SilentlyContinue
  $elapsedText = Get-RenameElapsedText
  $script:renameStart = $null
  Set-RenameControlsEnabled $true
  $renameConfirmCheckBox.Checked = $false

  if ($exitCode -ne 0) {
    $details = $log.Trim()
    if (-not $details) {
      $details = "The rename process exited with code $exitCode."
    }
    Set-RenameStatus "Rename failed   |   Total time: $elapsedText" 'error'
    Show-ComBoxMessage ($details) 'Rename failed' $true
    return
  }

  $updated = ''
  $renamed = ''
  foreach ($line in $logLines) {
    if ($line -match '^Updated text files:\s*(\d+)') { $updated = $Matches[1] }
    if ($line -match '^Renamed files/folders:\s*(\d+)') { $renamed = $Matches[1] }
  }
  foreach ($box in $renameMappingBoxes) {
    $box.Clear()
  }
  Set-RenameStatus "Rename complete ($($job.Mapping))   |   Updated text files: $updated   |   Renamed files/folders: $renamed   |   Total time: $elapsedText" 'success'
})
# ---------------------------------------------------------------------------
# Server and repository-delete sections
# (built-in local server and shared repository-delete worker)
$localServerPort = 3000
$localServerUrl = "http://localhost:$localServerPort"

# The self-contained local server launcher, used when a project has no server script.
$runLocalServerBatchSource = @'
@echo off
rem Embedded local server launcher for IJTC-ComBox's Server tab.
rem The Node.js and PowerShell server parts are stored in Form.bat. A project
rem without public\ is proxied to the local Odoo server; api\ enables local APIs.
rem A project that has its own server (server.bat, or scripts\
rem server.bat / server.js / run-local.js) still uses that one.
rem   /background  start without a window (used by IJTC-ComBox)
rem   /address     only print this PC's network address
setlocal EnableExtensions
set "IJTC_SERVER_LAUNCHER=%~f0"
if /i "%~1"=="/address" goto builtinAddress
set "BACKGROUND="
if /i "%~1"=="/background" set "BACKGROUND=1"
if defined RUBELAPP_PROJECT_DIR (cd /d "%RUBELAPP_PROJECT_DIR%") else (cd /d "%~dp0..")
if errorlevel 1 (
    echo Could not open the project folder.
    if not defined BACKGROUND pause
    exit /b 1
)
set "PROJECT_DIR=%CD%"

where node >nul 2>nul
if errorlevel 1 (
    echo Node.js is not installed or not in PATH.
    echo Install Node.js: https://nodejs.org/
    if not defined BACKGROUND pause
    exit /b 1
)

rem The project's server: server.bat in the project folder (older projects:
rem scripts\server.bat, scripts\server.js, or scripts\run-local.js with
rem prepare-static-assets.js / get-local-address.ps1).
set "PROJECT_SERVER="
if exist "%PROJECT_DIR%\scripts\server.bat" set "PROJECT_SERVER=%PROJECT_DIR%\scripts\server.bat"
rem (Not this file itself, when the project folder is IJTC-ComBox.)
if exist "%PROJECT_DIR%\server.bat" if /I not "%PROJECT_DIR%\server.bat"=="%~f0" set "PROJECT_SERVER=%PROJECT_DIR%\server.bat"
rem No server file in the project: use the built-in one (copied to a temp file for Node.js).
set "BUILTIN_SERVER="
if not defined PROJECT_SERVER if not exist "%PROJECT_DIR%\scripts\server.js" if not exist "%PROJECT_DIR%\scripts\run-local.js" set "BUILTIN_SERVER=1"
if defined BUILTIN_SERVER (
    set "SERVER_ROOT=%PROJECT_DIR%"
    set "SERVER_JS=%TEMP%\ijtc-local-server.js"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = [IO.File]::ReadAllText($env:IJTC_SERVER_LAUNCHER); $i = $t.LastIndexOf('/*__NODE_SERVER__*/'); $j = $t.LastIndexOf('/*__END_NODE_SERVER__*/'); if ($i -lt 0 -or $j -le $i) { exit 1 }; [IO.File]::WriteAllText($env:TEMP + '\ijtc-local-server.js', $t.Substring($i, $j - $i))"
    if errorlevel 1 (
        echo Could not read the built-in server embedded in Form.bat.
        if not defined BACKGROUND pause
        exit /b 1
    )
)
echo Checking local server configuration...
if defined BUILTIN_SERVER (
    node "%TEMP%\ijtc-local-server.js" --check
) else if defined PROJECT_SERVER (
    call "%PROJECT_SERVER%" check
) else if exist "scripts\server.js" (
    node scripts\server.js --check
) else (
    node scripts\prepare-static-assets.js
)
if errorlevel 1 (
    echo Could not validate the local server configuration.
    if not defined BACKGROUND pause
    exit /b 1
)

netstat -ano | findstr /R /C:":3000 .*LISTENING" >nul
if not errorlevel 1 (
    echo Port 3000 is already in use.
    echo Close the existing RRE server window, then run this file again.
    if not defined BACKGROUND pause
    exit /b 1
)

set "SESSION_CODE=12345"
set "IJTC_STORAGE=local"

if defined PROJECT_SERVER (
    for /f "delims=" %%i in ('call "%PROJECT_SERVER%" address') do set "LOCAL_IP=%%i"
) else (
    set "ADDRESS_SCRIPT=%PROJECT_DIR%\scripts\server.ps1"
    if not exist "%PROJECT_DIR%\scripts\server.ps1" set "ADDRESS_SCRIPT=%PROJECT_DIR%\scripts\get-local-address.ps1"
)
if not defined LOCAL_IP if defined ADDRESS_SCRIPT if exist "%ADDRESS_SCRIPT%" for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%ADDRESS_SCRIPT%"') do set "LOCAL_IP=%%i"
if not defined LOCAL_IP for /f "delims=" %%i in ('call "%IJTC_SERVER_LAUNCHER%" /address') do set "LOCAL_IP=%%i"
if defined LOCAL_IP set "NETWORK_URL=http://%LOCAL_IP%:3000"

for /f "delims=" %%i in ('node -e "process.stdout.write(require('crypto').randomBytes(32).toString('hex'))"') do set "GITHUB_TOKEN=%%i"
if not defined GITHUB_TOKEN (
    echo Could not generate a local session secret.
    if not defined BACKGROUND pause
    exit /b 1
)

echo.
echo Starting RRE locally...
echo Local URL: http://localhost:3000
if defined NETWORK_URL (
    echo Network URL: %NETWORK_URL%
) else (
    echo Network URL unavailable. Connect this PC to Wi-Fi or Ethernet and restart.
)
echo Local session code: 12345
echo Local data folder: %PROJECT_DIR%\Data
echo.

set "SERVER_RUN=node scripts\run-local.js"
if exist "%PROJECT_DIR%\scripts\server.js" set "SERVER_RUN=node scripts\server.js"
if exist "%PROJECT_DIR%\scripts\server.bat" set "SERVER_RUN=call scripts\server.bat"
if exist "%PROJECT_DIR%\server.bat" if /I not "%PROJECT_DIR%\server.bat"=="%~f0" set "SERVER_RUN=call server.bat"
rem (Short 8.3 path: no spaces, so it fits inside the server command below.)
if defined BUILTIN_SERVER for %%I in ("%TEMP%\ijtc-local-server.js") do set "SERVER_RUN=node %%~sI"

rem Run the server in a hidden console so CMD never appears in the taskbar.
powershell -NoProfile -Command "$process = Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /c ' + $env:SERVER_RUN) -WindowStyle Hidden -PassThru; if (-not $process) { exit 1 }"
if errorlevel 1 (
    echo Could not start the local server in hidden mode.
    if not defined BACKGROUND pause
    exit /b 1
)

powershell -NoProfile -Command "$deadline=(Get-Date).AddSeconds(90); do { $client=New-Object Net.Sockets.TcpClient; try { $client.Connect('127.0.0.1',3000); $ready=$client.Connected } catch { $ready=$false } finally { $client.Dispose() }; if (-not $ready) { Start-Sleep -Seconds 1 } } until ($ready -or (Get-Date) -ge $deadline); if (-not $ready) { exit 1 }"
if errorlevel 1 (
    echo The local server did not start within 90 seconds.
    echo Check the local server log in IJTC-ComBox for errors.
    if not defined BACKGROUND pause
    exit /b 1
)

if defined BACKGROUND (
    echo Server is ready.
) else (
    echo Server is ready. Opening browser...
    start "" "http://localhost:3000"
)
if not defined BACKGROUND echo Use the Stop button in IJTC-ComBox to stop the server.
exit /b 0

:builtinAddress
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = [IO.File]::ReadAllText($env:IJTC_SERVER_LAUNCHER); $i = $t.LastIndexOf('#__ADDRESS__'); $j = $t.LastIndexOf('#__END_ADDRESS__'); if ($i -ge 0 -and $j -gt $i) { & ([scriptblock]::Create($t.Substring($i, $j - $i))) }"
exit /b 0

rem ===========================================================================
rem Built-in server parts (batch never runs past the lines above).
rem ===========================================================================
/*__NODE_SERVER__*/
'use strict';

// Built-in local server of IJTC-ComBox (Node.js part embedded in Form.bat).
//   - serves out\ for a Next.js static export, or public\ when public\index.html exists
//   - otherwise proxies requests to the local Odoo server (default port 8069)
//   - runs API handlers in api\ when present
//   - /api/login, /api/logout, /api/session and /api/complete-login go to api\auth.js
// Settings come from the environment (the launcher sets them):
//   PORT (3000), SESSION_CODE (5-digit login code, 12345), IJTC_STORAGE (local = Data\ folder),
//   GITHUB_TOKEN (with local storage only used as the session secret; random if missing).

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

// SERVER_ROOT: the project folder (set by the launcher; this code runs from a temp copy).
const ROOT = path.resolve(process.env.SERVER_ROOT || path.join(__dirname, '..'));
const PUBLIC_DIR = path.join(ROOT, 'public');
const NEXT_EXPORT_DIR = path.join(ROOT, 'out');
const NEXT_EXPORT_INDEX = path.join(NEXT_EXPORT_DIR, 'index.html');
const HAS_NEXT_EXPORT = fs.existsSync(NEXT_EXPORT_INDEX) && fs.statSync(NEXT_EXPORT_INDEX).isFile();
const STATIC_DIR = HAS_NEXT_EXPORT ? NEXT_EXPORT_DIR : PUBLIC_DIR;
const STATIC_INDEX = path.join(STATIC_DIR, 'index.html');
const HAS_STATIC_FRONTEND = fs.existsSync(STATIC_INDEX) && fs.statSync(STATIC_INDEX).isFile();
const ODOO_PROXY_MODE = !HAS_STATIC_FRONTEND;
const ODOO_URL = ODOO_PROXY_MODE
  ? new URL(process.env.ODOO_URL || 'http://127.0.0.1:8069')
  : null;
if (ODOO_URL && !['http:', 'https:'].includes(ODOO_URL.protocol)) {
  throw new Error('ODOO_URL must use http:// or https://.');
}
const ODOO_TRANSPORT = ODOO_URL
  ? (ODOO_URL.protocol === 'https:' ? require('node:https') : http)
  : null;
const API_DIR = path.join(ROOT, 'api');
const API_ENABLED = fs.existsSync(API_DIR) && fs.statSync(API_DIR).isDirectory();
const PORT = Number(process.env.PORT) || 3000;
const MAX_BODY_BYTES = 25 * 1024 * 1024;

// The API reads and writes Data\ and File\ relative to the working folder.
process.chdir(ROOT);

// Check that the website files are in place (this was prepare-static-assets.js).
// "--check" only runs this check, without starting the server.
function checkProjectFiles() {
  const required = HAS_STATIC_FRONTEND ? [STATIC_INDEX] : [];
  const missing = required.filter((item) => !fs.existsSync(item));
  if (missing.length > 0) {
    console.error('Missing:');
    for (const item of missing) console.error('  ' + item);
    process.exit(1);
  }
}
checkProjectFiles();
if (process.argv.includes('--check')) {
  console.log([
    HAS_STATIC_FRONTEND ? `Static frontend found in ${STATIC_DIR}.` : `No static frontend; proxying to Odoo at ${ODOO_URL.origin}.`,
    API_ENABLED ? 'API enabled.' : 'API disabled.',
  ].join(' '));
  process.exit(0);
}
if (!process.env.SESSION_CODE) process.env.SESSION_CODE = '12345';
if (!process.env.IJTC_STORAGE) process.env.IJTC_STORAGE = 'local';
if (!process.env.GITHUB_TOKEN) process.env.GITHUB_TOKEN = crypto.randomBytes(32).toString('hex');

const AUTH_ROUTES = new Set(['login', 'logout', 'session', 'complete-login']);

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.htm': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.csv': 'text/csv; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.mp4': 'video/mp4',
  '.pdf': 'application/pdf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.webmanifest': 'application/manifest+json',
};

function sendJson(res, status, data) {
  if (res.headersSent) {
    res.end();
    return;
  }
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(data));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new RangeError('Request body is too large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function handleApi(req, res, url) {
  if (!API_ENABLED) return sendJson(res, 404, { error: 'API is unavailable in static-only mode.' });

  let name = url.pathname.slice('/api/'.length).replace(/\/+$/, '');
  if (name === 'logics') name = 'fields';
  if (AUTH_ROUTES.has(name)) name = 'auth';
  if (!/^[a-z0-9-]+$/.test(name)) return sendJson(res, 404, { error: 'API not found.' });

  const file = path.join(API_DIR, `${name}.js`);
  if (!fs.existsSync(file)) return sendJson(res, 404, { error: 'API not found.' });

  const handler = require(file);
  if (typeof handler !== 'function') return sendJson(res, 500, { error: 'API handler is not a function.' });

  req.originalUrl = req.url;
  req.query = Object.fromEntries(url.searchParams);

  const parseBody = !(handler.config && handler.config.api && handler.config.api.bodyParser === false);
  if (parseBody && req.method !== 'GET' && req.method !== 'HEAD') {
    const raw = (await readBody(req)).toString('utf8');
    const type = String(req.headers['content-type'] || '').toLowerCase();
    if (type.includes('application/json')) {
      try {
        req.body = raw ? JSON.parse(raw) : {};
      } catch {
        req.body = raw;
      }
    } else if (type.includes('application/x-www-form-urlencoded')) {
      req.body = Object.fromEntries(new URLSearchParams(raw));
    } else {
      req.body = raw;
    }
  }

  await handler(req, res);
}

function getOdooProxyHeaders(req) {
  const headers = { ...req.headers };
  const forwardedHost = req.headers.host || `localhost:${PORT}`;
  headers.host = forwardedHost;
  headers['x-forwarded-host'] = forwardedHost;
  headers['x-forwarded-proto'] = req.socket.encrypted ? 'https' : 'http';
  if (req.socket.remoteAddress) {
    const previous = req.headers['x-forwarded-for'];
    headers['x-forwarded-for'] = previous
      ? `${previous}, ${req.socket.remoteAddress}`
      : req.socket.remoteAddress;
  }
  return headers;
}

function proxyToOdoo(req, res) {
  const proxyRequest = ODOO_TRANSPORT.request({
    hostname: ODOO_URL.hostname,
    port: ODOO_URL.port || undefined,
    method: req.method,
    path: req.url,
    headers: getOdooProxyHeaders(req),
  }, (upstreamResponse) => {
    const headers = { ...upstreamResponse.headers };
    if (typeof headers.location === 'string') {
      try {
        const location = new URL(headers.location, ODOO_URL);
        if (location.origin === ODOO_URL.origin) {
          const proxyOrigin = `${req.socket.encrypted ? 'https' : 'http'}://${req.headers.host || `localhost:${PORT}`}`;
          headers.location = proxyOrigin + location.pathname + location.search + location.hash;
        }
      } catch {
        // Keep malformed upstream Location headers unchanged.
      }
    }
    res.writeHead(upstreamResponse.statusCode || 502, headers);
    upstreamResponse.pipe(res);
  });
  proxyRequest.on('error', (error) => {
    console.error(`Odoo proxy request ${req.method} ${req.url} failed:`, error);
    if (res.headersSent) {
      res.destroy(error);
      return;
    }
    res.statusCode = 502;
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.end(`Could not connect to Odoo at ${ODOO_URL.origin}. Start Odoo or set ODOO_URL.`);
  });
  req.pipe(proxyRequest);
}

function writeUpgradeResponse(socket, response) {
  socket.write(`HTTP/1.1 ${response.statusCode || 502} ${response.statusMessage || ''}\r\n`);
  for (let index = 0; index < response.rawHeaders.length; index += 2) {
    socket.write(`${response.rawHeaders[index]}: ${response.rawHeaders[index + 1]}\r\n`);
  }
  socket.write('\r\n');
}

function proxyWebSocket(req, socket, head) {
  const proxyRequest = ODOO_TRANSPORT.request({
    hostname: ODOO_URL.hostname,
    port: ODOO_URL.port || undefined,
    method: 'GET',
    path: req.url,
    headers: getOdooProxyHeaders(req),
  });
  proxyRequest.on('upgrade', (response, upstreamSocket, upstreamHead) => {
    writeUpgradeResponse(socket, response);
    if (upstreamHead.length) socket.write(upstreamHead);
    if (head.length) upstreamSocket.write(head);
    socket.on('error', (error) => upstreamSocket.destroy(error));
    upstreamSocket.on('error', (error) => socket.destroy(error));
    upstreamSocket.pipe(socket);
    socket.pipe(upstreamSocket);
  });
  proxyRequest.on('response', (response) => {
    writeUpgradeResponse(socket, response);
    response.on('error', (error) => socket.destroy(error));
    response.pipe(socket);
  });
  proxyRequest.on('error', (error) => {
    console.error(`Odoo WebSocket proxy failed for ${req.url}:`, error);
    if (!socket.destroyed) {
      socket.end('HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n');
    }
  });
  proxyRequest.end();
}

function serveStatic(req, res, url) {
  let pathname;
  try {
    pathname = decodeURIComponent(url.pathname);
  } catch {
    res.statusCode = 400;
    res.end('Bad request');
    return;
  }
  const target = path.normalize(path.join(STATIC_DIR, pathname));
  if (target !== STATIC_DIR && !target.startsWith(STATIC_DIR + path.sep)) {
    res.statusCode = 403;
    res.end('Forbidden');
    return;
  }
  // Clean page addresses: /Session (not /Session/ or /Session/index.html).
  // The old forms still work: the browser is sent to the clean address.
  const redirect = (location) => {
    res.statusCode = 301;
    res.setHeader('Location', location + url.search);
    res.end();
  };
  if (/\/index\.html$/i.test(pathname)) {
    redirect(pathname.replace(/\/index\.html$/i, '') || '/');
    return;
  }
  if (pathname.length > 1 && pathname.endsWith('/')) {
    redirect(pathname.replace(/\/+$/, '') || '/');
    return;
  }

  let file = target;
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) {
    file = path.join(file, 'index.html');
  } else if (!fs.existsSync(file) && !path.extname(file) && fs.existsSync(file + '.html')) {
    file += '.html';
  }

  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
    res.statusCode = 404;
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.end('Not found: ' + pathname);
    return;
  }

  res.statusCode = 200;
  res.setHeader('Content-Type', MIME_TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream');
  res.setHeader('Cache-Control', 'no-cache');
  if (req.method === 'HEAD') {
    res.end();
    return;
  }
  fs.createReadStream(file).pipe(res);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', 'http://localhost');
  try {
    const isApiRequest = url.pathname === '/api' || url.pathname.startsWith('/api/');
    if (isApiRequest && API_ENABLED) {
      await handleApi(req, res, url);
    } else if (ODOO_PROXY_MODE) {
      proxyToOdoo(req, res);
    } else if (isApiRequest) {
      await handleApi(req, res, url);
    } else if (req.method === 'GET' || req.method === 'HEAD') {
      serveStatic(req, res, url);
    } else {
      res.statusCode = 405;
      res.setHeader('Allow', 'GET, HEAD');
      res.end('Method not allowed');
    }
  } catch (error) {
    console.error(`${req.method} ${req.url} failed:`, error);
    sendJson(res, error instanceof RangeError ? 413 : 500, { error: 'Server error: ' + error.message });
  }
});

server.on('upgrade', (req, socket, head) => {
  if (ODOO_PROXY_MODE) {
    proxyWebSocket(req, socket, head);
  } else {
    socket.end('HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n');
  }
});

server.on('error', (error) => {
  console.error(error.code === 'EADDRINUSE' ? `Port ${PORT} is already in use.` : error);
  process.exit(1);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Local server: http://localhost:${PORT}`);
  console.log(`Project folder: ${ROOT}`);
  if (ODOO_PROXY_MODE) console.log(`Odoo proxy: ${ODOO_URL.origin}`);
  console.log(API_ENABLED
    ? `Data storage: ${process.env.IJTC_STORAGE === 'local' ? path.join(ROOT, 'Data') : 'GitHub'}`
    : 'Local API: disabled');
});
/*__END_NODE_SERVER__*/

#__ADDRESS__
# Prints this PC's IPv4 address on the local network (Wi-Fi or Ethernet), or nothing.
# Built-in part of IJTC-ComBox's embedded launcher ("/address"); also used by
# the ComBox Server tab for the Network URL (http://<address>:3000).
$ErrorActionPreference = 'SilentlyContinue'
$address = Get-NetIPConfiguration |
  Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
  ForEach-Object { $_.IPv4Address.IPAddress } |
  Where-Object { $_ -and $_ -notlike '169.254.*' } |
  Select-Object -First 1
if (-not $address) {
  $address = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
    Where-Object { $_.AddressFamily -eq 'InterNetwork' -and $_.ToString() -notlike '127.*' -and $_.ToString() -notlike '169.254.*' } |
    ForEach-Object { $_.ToString() } |
    Select-Object -First 1
}
if ($address) { Write-Output $address }
#__END_ADDRESS__
'@

function Add-PanelLabel {
  param($Panel, [string]$Text, [int]$X, [int]$Y, [int]$Width)
  $label = New-Object System.Windows.Forms.Label
  $label.Text = $Text
  $label.Location = New-Object System.Drawing.Point($X, $Y)
  $label.Size = New-Object System.Drawing.Size($Width, 22)
  $label.AutoEllipsis = $true
  $label.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $Panel.Controls.Add($label)
  return $label
}

function Add-PanelTextBox {
  param($Panel, [int]$X, [int]$Y, [int]$Width, [bool]$ReadOnly = $false)
  $box = New-Object System.Windows.Forms.TextBox
  $box.Location = New-Object System.Drawing.Point($X, $Y)
  $box.Size = New-Object System.Drawing.Size($Width, 26)
  $box.ReadOnly = $ReadOnly
  if ($ReadOnly) {
    $box.BackColor = [System.Drawing.Color]::White
  }
  $Panel.Controls.Add($box)
  return $box
}

function Add-PanelIconButton {
  param($Panel, [string]$AccessibleName, [int]$GlyphCode, [int]$X, [int]$Y, [string]$Fill = '')
  $button = New-ActionButton $AccessibleName $GlyphCode 0 0
  $form.Controls.Remove($button)
  $button.Location = New-Object System.Drawing.Point($X, $Y)
  if ($Fill) {
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    if ($Fill -eq 'red') {
      $button.BackColor = [System.Drawing.Color]::Firebrick
    } else {
      $button.BackColor = [System.Drawing.Color]::FromArgb(38, 105, 176)
    }
    $button.ForeColor = [System.Drawing.Color]::White
  }
  $Panel.Controls.Add($button)
  return $button
}

function Set-ColoredStatus {
  param($Label, [string]$Text, [string]$Kind = 'info')
  if ($null -ne $runLocalUploadStatusLabel -and $Label -eq $runLocalUploadStatusLabel -and
    (Get-Command Get-RunLocalLastUploadTimeText -ErrorAction SilentlyContinue)) {
    $Text = 'Last upload: ' + (Get-RunLocalLastUploadTimeText) + '   |   ' + $Text
  }
  $Label.Text = $Text
  $toolTip.SetToolTip($Label, $Text)
  switch ($Kind) {
    'error'   { $Label.ForeColor = [System.Drawing.Color]::Firebrick }
    'success' { $Label.ForeColor = [System.Drawing.Color]::FromArgb(30, 130, 60) }
    'busy'    { $Label.ForeColor = [System.Drawing.Color]::FromArgb(38, 105, 176) }
    default   { $Label.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103) }
  }
}

function Get-ElapsedText {
  param($Start)
  if (-not $Start) {
    return '00:00'
  }
  $elapsed = (Get-Date) - $Start
  return ('{0:00}:{1:00}' -f [int][Math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds)
}

# ----- Server section -----
$runLocalPanel = New-FormSectionPanel 'runlocal'
$runLocalGearButton = Add-PanelIconButton $runLocalPanel 'From AppName, update Worker/GitHub links and only name + existing vars.GITHUB_REPO in wrangler.jsonc; preserve all other settings' 0xE713 836 4
$runLocalDeployButton = Add-PanelIconButton $runLocalPanel 'Deploy from the GitHub Repo link saved in the Repo field' 0xE753 874 4
$runLocalGearButton.Text = [string][char]0x2699
$runLocalDeployButton.Text = [string][char]0x2601
foreach ($button in @($runLocalGearButton, $runLocalDeployButton)) {
  $button.Size = New-Object System.Drawing.Size(34, 30)
  $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $button.UseVisualStyleBackColor = $false
  $button.FlatAppearance.BorderSize = 1
  $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(120, 150, 185)
  $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(213, 230, 248)
  $button.BackColor = [System.Drawing.Color]::FromArgb(232, 242, 252)
  $button.ForeColor = [System.Drawing.Color]::FromArgb(36, 91, 150)
  $button.Font = New-Object System.Drawing.Font('Segoe UI Symbol', 14)
  $button.BringToFront()
}
$runLocalGearButton.Add_Click($localDeployAction)
$runLocalDeployButton.Add_Click($deployAction)

$null = Add-PanelLabel $runLocalPanel 'Local URL' 14 48 100
$runLocalUrlBox = Add-PanelTextBox $runLocalPanel 120 45 520 $true
$runLocalUrlBox.Text = $localServerUrl
$runLocalCopyUrlButton = Add-PanelIconButton $runLocalPanel 'Copy local URL' 0xE8C8 650 43
$runLocalOpenUrlButton = Add-PanelIconButton $runLocalPanel 'Open local URL in the browser' 0xE774 688 43

$null = Add-PanelLabel $runLocalPanel 'Network URL' 14 92 100
$runLocalNetworkBox = Add-PanelTextBox $runLocalPanel 120 89 520 $true
$runLocalCopyNetworkButton = Add-PanelIconButton $runLocalPanel 'Copy network URL' 0xE8C8 650 87
$runLocalOpenNetworkButton = Add-PanelIconButton $runLocalPanel 'Open network URL in the browser' 0xE774 688 87

$runLocalStartButton = Add-PanelIconButton $runLocalPanel 'Start local server' 0xE768 776 43
$runLocalStopButton = Add-PanelIconButton $runLocalPanel 'Stop local server' 0xE71A 814 43
$runLocalRefreshButton = Add-PanelIconButton $runLocalPanel 'Restart local server (stop and start again)' 0xE72C 852 43
$runLocalDataButton = Add-PanelIconButton $runLocalPanel 'Open the folder the server runs from' 0xE8A7 776 87
$runLocalLogButton = Add-PanelIconButton $runLocalPanel 'Open the local server log' 0xE8A5 814 87
$runLocalCodeLabel = Add-PanelLabel $runLocalPanel '12345' 856 92 50
$toolTip.SetToolTip($runLocalCodeLabel, 'Local session code used by the Server')
$runLocalUploadStatusLabel = Add-PanelLabel $runLocalPanel 'Choose a GitHub Repo, review Local Upload ticks, then click the Upload button.' 14 124 870
$runLocalUploadStatusLabel.AutoEllipsis = $true

$runLocalStatusLabel = New-Label 'Checking...' 37 211 900 24
$runLocalStatusLabel.AutoEllipsis = $true

# QR code of the Network URL: scan it with a phone on the same Wi-Fi/LAN to
# open the local server running from the project folder above.
$qrEncoderSource = @'
using System;
using System.Collections.Generic;
using System.Text;

public static class IjtcQr {
  // Byte-mode QR encoder (versions 1-10, error correction level L), based on the
  // standard algorithm (ISO/IEC 18004). Returns modules[y, x], true = dark.
  static readonly int[] EccPerBlock = { -1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18 };
  static readonly int[] NumBlocks   = { -1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4 };

  public static bool[,] Encode(string text) {
    byte[] data = Encoding.UTF8.GetBytes(text);
    int version = 0;
    for (int v = 1; v <= 10; v++) {
      int capacityBits = NumDataCodewords(v) * 8;
      int needed = 4 + (v < 10 ? 8 : 16) + data.Length * 8;
      if (needed <= capacityBits) { version = v; break; }
    }
    if (version == 0) throw new ArgumentException("Text is too long for the QR code.");

    var bits = new List<bool>();
    AppendBits(bits, 4, 4);
    AppendBits(bits, data.Length, version < 10 ? 8 : 16);
    foreach (byte b in data) AppendBits(bits, b, 8);
    int capacity = NumDataCodewords(version) * 8;
    AppendBits(bits, 0, Math.Min(4, capacity - bits.Count));
    AppendBits(bits, 0, (8 - bits.Count % 8) % 8);
    for (int pad = 0xEC; bits.Count < capacity; pad ^= 0xEC ^ 0x11) AppendBits(bits, pad, 8);

    byte[] dataCodewords = new byte[bits.Count / 8];
    for (int i = 0; i < bits.Count; i++) if (bits[i]) dataCodewords[i >> 3] |= (byte)(1 << (7 - (i & 7)));

    byte[] allCodewords = AddEccAndInterleave(dataCodewords, version);
    int size = version * 4 + 17;
    var modules = new bool[size, size];
    var isFunction = new bool[size, size];
    DrawFunctionPatterns(modules, isFunction, version, size);
    DrawCodewords(modules, isFunction, allCodewords, size);

    int bestMask = 0;
    long minPenalty = long.MaxValue;
    for (int mask = 0; mask < 8; mask++) {
      ApplyMask(modules, isFunction, mask, size);
      DrawFormatBits(modules, isFunction, mask, size);
      long penalty = Penalty(modules, size);
      if (penalty < minPenalty) { minPenalty = penalty; bestMask = mask; }
      ApplyMask(modules, isFunction, mask, size);
    }
    ApplyMask(modules, isFunction, bestMask, size);
    DrawFormatBits(modules, isFunction, bestMask, size);
    return modules;
  }

  static void AppendBits(List<bool> bits, int value, int length) {
    for (int i = length - 1; i >= 0; i--) bits.Add(((value >> i) & 1) != 0);
  }

  static int NumRawDataModules(int ver) {
    int result = (16 * ver + 128) * ver + 64;
    if (ver >= 2) {
      int numAlign = ver / 7 + 2;
      result -= (25 * numAlign - 10) * numAlign - 55;
      if (ver >= 7) result -= 36;
    }
    return result;
  }

  static int NumDataCodewords(int ver) {
    return NumRawDataModules(ver) / 8 - EccPerBlock[ver] * NumBlocks[ver];
  }

  static byte[] AddEccAndInterleave(byte[] data, int ver) {
    int numBlocks = NumBlocks[ver];
    int blockEccLen = EccPerBlock[ver];
    int rawCodewords = NumRawDataModules(ver) / 8;
    int numShortBlocks = numBlocks - rawCodewords % numBlocks;
    int shortBlockLen = rawCodewords / numBlocks;
    byte[] divisor = ReedSolomonDivisor(blockEccLen);
    var blocks = new List<byte[]>();
    for (int i = 0, k = 0; i < numBlocks; i++) {
      int datLen = shortBlockLen - blockEccLen + (i < numShortBlocks ? 0 : 1);
      byte[] dat = new byte[datLen];
      Array.Copy(data, k, dat, 0, datLen);
      k += datLen;
      byte[] ecc = ReedSolomonRemainder(dat, divisor);
      byte[] block = new byte[shortBlockLen + 1];
      Array.Copy(dat, 0, block, 0, datLen);
      Array.Copy(ecc, 0, block, block.Length - blockEccLen, blockEccLen);
      blocks.Add(block);
    }
    var result = new List<byte>();
    for (int i = 0; i < blocks[0].Length; i++) {
      for (int j = 0; j < blocks.Count; j++) {
        if (i != shortBlockLen - blockEccLen || j >= numShortBlocks) result.Add(blocks[j][i]);
      }
    }
    return result.ToArray();
  }

  static byte[] ReedSolomonDivisor(int degree) {
    byte[] result = new byte[degree];
    result[degree - 1] = 1;
    int root = 1;
    for (int i = 0; i < degree; i++) {
      for (int j = 0; j < result.Length; j++) {
        result[j] = (byte)GfMultiply(result[j], root);
        if (j + 1 < result.Length) result[j] ^= result[j + 1];
      }
      root = GfMultiply(root, 0x02);
    }
    return result;
  }

  static byte[] ReedSolomonRemainder(byte[] data, byte[] divisor) {
    byte[] result = new byte[divisor.Length];
    foreach (byte b in data) {
      int factor = b ^ result[0];
      Array.Copy(result, 1, result, 0, result.Length - 1);
      result[result.Length - 1] = 0;
      for (int i = 0; i < result.Length; i++) result[i] ^= (byte)GfMultiply(divisor[i], factor);
    }
    return result;
  }

  static int GfMultiply(int x, int y) {
    int z = 0;
    for (int i = 7; i >= 0; i--) {
      z = (z << 1) ^ ((z >> 7) * 0x11D);
      z ^= ((y >> i) & 1) * x;
    }
    return z & 0xFF;
  }

  static void SetFunction(bool[,] m, bool[,] f, int x, int y, bool dark) {
    m[y, x] = dark;
    f[y, x] = true;
  }

  static void DrawFunctionPatterns(bool[,] m, bool[,] f, int ver, int size) {
    for (int i = 0; i < size; i++) {
      SetFunction(m, f, 6, i, i % 2 == 0);
      SetFunction(m, f, i, 6, i % 2 == 0);
    }
    DrawFinder(m, f, 3, 3, size);
    DrawFinder(m, f, size - 4, 3, size);
    DrawFinder(m, f, 3, size - 4, size);
    int[] align = AlignmentPositions(ver, size);
    int n = align.Length;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if ((i == 0 && j == 0) || (i == 0 && j == n - 1) || (i == n - 1 && j == 0)) continue;
        for (int dy = -2; dy <= 2; dy++)
          for (int dx = -2; dx <= 2; dx++)
            SetFunction(m, f, align[i] + dx, align[j] + dy, Math.Max(Math.Abs(dx), Math.Abs(dy)) != 1);
      }
    }
    DrawFormatBits(m, f, 0, size);
    if (ver >= 7) {
      int rem = ver;
      for (int i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
      int bits = ver << 12 | rem;
      for (int i = 0; i < 18; i++) {
        bool bit = ((bits >> i) & 1) != 0;
        int a = size - 11 + i % 3, b = i / 3;
        SetFunction(m, f, a, b, bit);
        SetFunction(m, f, b, a, bit);
      }
    }
  }

  static void DrawFinder(bool[,] m, bool[,] f, int x, int y, int size) {
    for (int dy = -4; dy <= 4; dy++) {
      for (int dx = -4; dx <= 4; dx++) {
        int dist = Math.Max(Math.Abs(dx), Math.Abs(dy));
        int xx = x + dx, yy = y + dy;
        if (0 <= xx && xx < size && 0 <= yy && yy < size) SetFunction(m, f, xx, yy, dist != 2 && dist != 4);
      }
    }
  }

  static int[] AlignmentPositions(int ver, int size) {
    if (ver == 1) return new int[0];
    int numAlign = ver / 7 + 2;
    int step = (ver * 4 + numAlign * 2 + 1) / (numAlign * 2 - 2) * 2;
    int[] result = new int[numAlign];
    result[0] = 6;
    for (int i = numAlign - 1, pos = size - 7; i >= 1; i--, pos -= step) result[i] = pos;
    return result;
  }

  static void DrawFormatBits(bool[,] m, bool[,] f, int mask, int size) {
    int data = 1 << 3 | mask; // level L = 01
    int rem = data;
    for (int i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    int bits = (data << 10 | rem) ^ 0x5412;
    for (int i = 0; i <= 5; i++) SetFunction(m, f, 8, i, Bit(bits, i));
    SetFunction(m, f, 8, 7, Bit(bits, 6));
    SetFunction(m, f, 8, 8, Bit(bits, 7));
    SetFunction(m, f, 7, 8, Bit(bits, 8));
    for (int i = 9; i < 15; i++) SetFunction(m, f, 14 - i, 8, Bit(bits, i));
    for (int i = 0; i < 8; i++) SetFunction(m, f, size - 1 - i, 8, Bit(bits, i));
    for (int i = 8; i < 15; i++) SetFunction(m, f, 8, size - 15 + i, Bit(bits, i));
    SetFunction(m, f, 8, size - 8, true);
  }

  static bool Bit(int x, int i) { return ((x >> i) & 1) != 0; }

  static void DrawCodewords(bool[,] m, bool[,] f, byte[] data, int size) {
    int i = 0;
    for (int right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (int vert = 0; vert < size; vert++) {
        for (int j = 0; j < 2; j++) {
          int x = right - j;
          bool upward = ((right + 1) & 2) == 0;
          int y = upward ? size - 1 - vert : vert;
          if (!f[y, x] && i < data.Length * 8) {
            m[y, x] = Bit(data[i >> 3], 7 - (i & 7));
            i++;
          }
        }
      }
    }
  }

  static void ApplyMask(bool[,] m, bool[,] f, int mask, int size) {
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        bool invert;
        switch (mask) {
          case 0: invert = (x + y) % 2 == 0; break;
          case 1: invert = y % 2 == 0; break;
          case 2: invert = x % 3 == 0; break;
          case 3: invert = (x + y) % 3 == 0; break;
          case 4: invert = (x / 3 + y / 2) % 2 == 0; break;
          case 5: invert = x * y % 2 + x * y % 3 == 0; break;
          case 6: invert = (x * y % 2 + x * y % 3) % 2 == 0; break;
          default: invert = ((x + y) % 2 + x * y % 3) % 2 == 0; break;
        }
        if (!f[y, x] && invert) m[y, x] = !m[y, x];
      }
    }
  }

  static long Penalty(bool[,] m, int size) {
    long result = 0;
    int dark = 0;
    for (int y = 0; y < size; y++) {
      for (int pass = 0; pass < 2; pass++) {
        int run = 0;
        bool color = false;
        for (int x = 0; x < size; x++) {
          bool c = pass == 0 ? m[y, x] : m[x, y];
          if (x > 0 && c == color) {
            run++;
            if (run == 5) result += 3;
            else if (run > 5) result++;
          } else {
            color = c;
            run = 1;
          }
        }
      }
      for (int x = 0; x < size; x++) {
        if (m[y, x]) dark++;
        if (y + 1 < size && x + 1 < size) {
          bool c = m[y, x];
          if (c == m[y, x + 1] && c == m[y + 1, x] && c == m[y + 1, x + 1]) result += 3;
        }
      }
    }
    int total = size * size;
    int k = (Math.Abs(dark * 20 - total * 10) + total - 1) / total - 1;
    result += Math.Max(0, k) * 10;
    return result;
  }
}
'@

function Get-QrModules {
  param([string]$Text)
  if (-not ('IjtcQr' -as [type])) {
    Add-Type -TypeDefinition $qrEncoderSource -Language CSharp
  }
  return ,([IjtcQr]::Encode($Text))
}

function New-QrBitmap {
  param([string]$Text, [int]$Pixels, [int]$QuietModules = 0)
  $bitmap = New-Object System.Drawing.Bitmap($Pixels, $Pixels)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.Clear([System.Drawing.Color]::White)
    if ($Text) {
      $modules = Get-QrModules $Text
      if ($modules.Rank -ne 2) {
        throw 'QR encoder returned an unexpected result.'
      }
      $count = $modules.GetLength(0)
      $moduleSize = [int][Math]::Floor($Pixels / ($count + 2 * $QuietModules))
      if ($moduleSize -lt 1) {
        $moduleSize = 1
      }
      $offset = [int][Math]::Floor(($Pixels - $count * $moduleSize) / 2)
      $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Black)
      try {
        for ($y = 0; $y -lt $count; $y++) {
          for ($x = 0; $x -lt $count; $x++) {
            if ($modules[$y, $x]) {
              $graphics.FillRectangle($brush, $offset + $x * $moduleSize, $offset + $y * $moduleSize, $moduleSize, $moduleSize)
            }
          }
        }
      } finally {
        $brush.Dispose()
      }
    } else {
      $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 200, 200))
      try {
        $graphics.DrawRectangle($pen, 0, 0, $Pixels - 1, $Pixels - 1)
        $graphics.DrawLine($pen, 0, 0, $Pixels - 1, $Pixels - 1)
        $graphics.DrawLine($pen, 0, $Pixels - 1, $Pixels - 1, 0)
      } finally {
        $pen.Dispose()
      }
    }
  } finally {
    $graphics.Dispose()
  }
  return $bitmap
}

$runLocalQrBox = New-Object System.Windows.Forms.PictureBox
$runLocalQrBox.Location = New-Object System.Drawing.Point(723, 55)
$runLocalQrBox.Size = New-Object System.Drawing.Size(50, 50)
$runLocalQrBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Normal
$runLocalQrBox.BackColor = [System.Drawing.Color]::White
$runLocalQrBox.Cursor = [System.Windows.Forms.Cursors]::Hand
$runLocalPanel.Controls.Add($runLocalQrBox)
$script:runLocalQrUrl = ''

function Update-RunLocalQr {
  $url = ''
  if ($runLocalNetworkBox.Text -like 'http*') {
    $url = $runLocalNetworkBox.Text.Trim()
  }
  if ($url -eq $script:runLocalQrUrl -and $runLocalQrBox.Image) {
    return
  }
  $script:runLocalQrUrl = $url
  $old = $runLocalQrBox.Image
  try {
    $runLocalQrBox.Image = New-QrBitmap $url 50
  } catch {
    $runLocalQrBox.Image = New-QrBitmap '' 50
    $url = ''
  }
  if ($old) {
    $old.Dispose()
  }
  if ($url) {
    $toolTip.SetToolTip($runLocalQrBox, "Scan to open $url on a phone or another device on the same Wi-Fi/LAN (start the server first). Click to enlarge.")
  } else {
    $toolTip.SetToolTip($runLocalQrBox, 'Network URL unavailable - connect this PC to Wi-Fi or Ethernet, then press Refresh.')
  }
}

$runLocalNetworkBox.Add_TextChanged({ Update-RunLocalQr })

$runLocalQrBox.Add_Click({
  $url = $script:runLocalQrUrl
  if (-not $url) {
    Set-ColoredStatus $runLocalStatusLabel 'Network URL unavailable - connect this PC to Wi-Fi or Ethernet, then press Refresh.' 'error'
    return
  }
  $qrDialog = New-Object System.Windows.Forms.Form
  $qrDialog.Text = 'Scan to open the local server'
  $qrDialog.StartPosition = 'CenterParent'
  $qrDialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $qrDialog.MaximizeBox = $false
  $qrDialog.MinimizeBox = $false
  $qrDialog.ShowInTaskbar = $false
  $qrDialog.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
  $qrDialog.ClientSize = New-Object System.Drawing.Size(340, 420)
  $qrDialog.BackColor = [System.Drawing.Color]::White
  $qrDialog.Font = New-Object System.Drawing.Font('Segoe UI', 10)
  $bigQr = New-Object System.Windows.Forms.PictureBox
  $bigQr.Location = New-Object System.Drawing.Point(20, 16)
  $bigQr.Size = New-Object System.Drawing.Size(300, 300)
  $bigQr.Image = New-QrBitmap $url 300 2
  $qrDialog.Controls.Add($bigQr)
  $qrUrlLabel = New-Object System.Windows.Forms.Label
  $qrUrlLabel.Text = $url
  $qrUrlLabel.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
  $qrUrlLabel.ForeColor = [System.Drawing.Color]::FromArgb(38, 105, 176)
  $qrUrlLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
  $qrUrlLabel.Location = New-Object System.Drawing.Point(10, 322)
  $qrUrlLabel.Size = New-Object System.Drawing.Size(320, 24)
  $qrDialog.Controls.Add($qrUrlLabel)
  $qrHintLabel = New-Object System.Windows.Forms.Label
  if (Test-LocalServerRunning) {
    $qrHintLabel.Text = "Server is running. Session code: 12345`r`nFolder: $($script:runLocalDirectory)"
  } else {
    $qrHintLabel.Text = "Server is stopped - press the play button first.`r`nFolder: $($script:runLocalDirectory)"
  }
  $qrHintLabel.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $qrHintLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
  $qrHintLabel.AutoEllipsis = $true
  $qrHintLabel.Location = New-Object System.Drawing.Point(10, 348)
  $qrHintLabel.Size = New-Object System.Drawing.Size(320, 40)
  $qrDialog.Controls.Add($qrHintLabel)
  $qrCloseButton = New-Object System.Windows.Forms.Button
  $qrCloseButton.Text = 'Close'
  $qrCloseButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $qrCloseButton.Location = New-Object System.Drawing.Point(250, 390)
  $qrCloseButton.Size = New-Object System.Drawing.Size(80, 26)
  $qrDialog.Controls.Add($qrCloseButton)
  $qrDialog.CancelButton = $qrCloseButton
  Register-FormButtonSoundControl $qrDialog
  try {
    [void]$qrDialog.ShowDialog($form)
  } finally {
    $bigQr.Image.Dispose()
    $qrDialog.Dispose()
  }
})

$script:runLocalNetworkLoaded = $false
$script:runLocalStarting = $false
$script:runLocalStartTime = $null
$script:runLocalServerStartedAt = $null
$script:runLocalLastState = ''
$script:runLocalLauncher = $null
$script:runLocalBatchFile = $null
$script:runLocalLogFile = $null
$script:runLocalStartedByForm = $env:COMBOX_PRESERVE_LOCAL_SERVER -eq '1'
$env:COMBOX_PRESERVE_LOCAL_SERVER = ''

function Remove-RunLocalBatchFile {
  if (-not $script:runLocalBatchFile) {
    return
  }
  if (Test-Path -LiteralPath $script:runLocalBatchFile -PathType Leaf) {
    Remove-Item -LiteralPath $script:runLocalBatchFile -Force -ErrorAction Stop
  }
  $script:runLocalBatchFile = $null
}

function Get-RunLocalLog {
  if (-not $script:runLocalLogFile) {
    return ''
  }
  try {
    return Read-CloudflareJobLog $script:runLocalLogFile
  } catch {
    return ''
  }
}

function Get-RunLocalLastLogLine {
  $lines = @((Get-RunLocalLog) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($lines.Count -gt 0) {
    return $lines[-1].Trim()
  }
  return ''
}

function Test-LocalServerRunning {
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $async = $client.BeginConnect('127.0.0.1', $localServerPort, $null, $null)
    if (-not $async.AsyncWaitHandle.WaitOne(300)) {
      return $false
    }
    $client.EndConnect($async)
    return [bool]$client.Connected
  } catch {
    return $false
  } finally {
    $client.Close()
  }
}

function Get-LocalServerProcessIds {
  $ids = @()
  try {
    $ids = @(Get-NetTCPConnection -LocalPort $localServerPort -State Listen -ErrorAction Stop |
      Select-Object -ExpandProperty OwningProcess)
  } catch {
    foreach ($line in @(netstat -ano -p tcp)) {
      if ($line -match ('^\s*TCP\s+\S+:' + $localServerPort + '\s+\S+\s+LISTENING\s+(\d+)')) {
        $ids += [int]$Matches[1]
      }
    }
  }
  return @($ids | Where-Object { $_ -gt 0 } | Sort-Object -Unique)
}

function Get-RunLocalServerProcessStartTime {
  $startTimes = @(
    foreach ($id in @(Get-LocalServerProcessIds)) {
      try {
        (Get-Process -Id $id -ErrorAction Stop).StartTime
      } catch {
      }
    }
  )
  if ($startTimes.Count -gt 0) {
    return ($startTimes | Sort-Object | Select-Object -First 1)
  }
  return $null
}

function Get-RunLocalUptimeText {
  param([DateTime]$StartedAt)
  $elapsed = [DateTime]::Now - $StartedAt
  $hours = [int][Math]::Floor($elapsed.TotalHours)
  return ('{0:00}:{1:00}:{2:00}' -f $hours, $elapsed.Minutes, $elapsed.Seconds)
}

function Stop-LocalServer {
  param([int[]]$ProcessIds)
  foreach ($id in $ProcessIds) {
    $parentId = $null
    $childStart = $null
    try {
      $info = Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction Stop
      $parentId = [int]$info.ParentProcessId
      $childStart = $info.CreationDate
    } catch {
      $parentId = $null
    }
    Stop-Process -Id $id -Force -ErrorAction Stop
    # Also stop the launcher process that owns the server process.
    if ($parentId) {
      try {
        $parent = Get-Process -Id $parentId -ErrorAction Stop
        if ($parent.ProcessName -ieq 'cmd' -and (-not $childStart -or $parent.StartTime -le $childStart)) {
          Stop-Process -Id $parentId -Force -ErrorAction SilentlyContinue
        }
      } catch {
      }
    }
  }
}

function Get-RunLocalIPv4Address {
  $addresses = [System.Collections.Generic.List[object]]::new()
  foreach ($adapter in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
    if ($adapter.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up -or
        $adapter.NetworkInterfaceType -in @(
          [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback,
          [System.Net.NetworkInformation.NetworkInterfaceType]::Tunnel
        )) {
      continue
    }

    $properties = $adapter.GetIPProperties()
    $hasGateway = @($properties.GatewayAddresses | Where-Object {
      $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and
      $_.Address.IPAddressToString -ne '0.0.0.0'
    }).Count -gt 0
    foreach ($entry in $properties.UnicastAddresses) {
      $address = $entry.Address
      if ($address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        continue
      }
      $ip = $address.IPAddressToString
      if ($ip -eq '127.0.0.1' -or $ip.StartsWith('169.254.')) {
        continue
      }
      $priority = if ($hasGateway) { 0 } else { 1 }
      $addresses.Add([pscustomobject]@{ Priority = $priority; Address = $ip })
    }
  }
  $selected = $addresses | Sort-Object Priority, Address | Select-Object -First 1
  if ($selected) {
    return [string]$selected.Address
  }
  return ''
}

function Update-RunLocalNetworkUrl {
  $script:runLocalNetworkLoaded = $true
  $ip = Get-RunLocalIPv4Address
  if ($ip.Trim()) {
    $runLocalNetworkBox.Text = "http://$($ip.Trim()):$localServerPort"
  } else {
    $runLocalNetworkBox.Text = 'Unavailable - connect this PC to Wi-Fi or Ethernet'
  }
}

function Update-RunLocalState {
  if (-not $script:runLocalNetworkLoaded) {
    Update-RunLocalNetworkUrl
  }
  $running = Test-LocalServerRunning
  if ($script:runLocalBatchFile -and $script:runLocalLauncher -and $script:runLocalLauncher.HasExited) {
    try {
      Remove-RunLocalBatchFile
    } catch {
      Set-ColoredStatus $runLocalStatusLabel ('Could not remove the temporary server launcher: ' + $_.Exception.Message) 'error'
      return
    }
  }
  $hasNetworkUrl = $runLocalNetworkBox.Text -like 'http*'
  $runLocalStopButton.Enabled = $running
  $runLocalOpenUrlButton.Enabled = $running
  $runLocalOpenNetworkButton.Enabled = $running -and $hasNetworkUrl
  $runLocalCopyNetworkButton.Enabled = $hasNetworkUrl

  if ($script:runLocalStarting) {
    if ($running) {
      $script:runLocalStarting = $false
    } else {
      $launcherExited = (-not $script:runLocalLauncher) -or $script:runLocalLauncher.HasExited
      $timedOut = ((Get-Date) - $script:runLocalStartTime).TotalSeconds -ge 95
      if (-not $launcherExited -and -not $timedOut) {
        $runLocalStartButton.Enabled = $false
        $step = Get-RunLocalLastLogLine
        Set-ColoredStatus $runLocalStatusLabel ('Starting the local server...   |   Elapsed: ' + (Get-ElapsedText $script:runLocalStartTime) + '   |   ' + $step) 'busy'
        $script:runLocalLastState = 'starting'
        return
      }
      $script:runLocalStarting = $false
      $script:runLocalStartedByForm = $false
      $runLocalStartButton.Enabled = $true
      Set-ColoredStatus $runLocalStatusLabel 'The local server did not start. Press the log button for details.' 'error'
      $script:runLocalLastState = 'failed'
      $details = (Get-RunLocalLog).Trim()
      if (-not $details) {
        $details = 'Local server launcher stopped without output.'
      }
      Show-ComBoxMessage ($details) 'Server failed' $true
      return
    }
  }

  $runLocalStartButton.Enabled = -not $running
  $state = if ($running) { 'running' } else { 'stopped' }
  if (-not $running -and $state -eq $script:runLocalLastState) {
    return
  }
  $script:runLocalLastState = $state
  if ($running) {
    if (-not $script:runLocalServerStartedAt) {
      $script:runLocalServerStartedAt = Get-RunLocalServerProcessStartTime
      if (-not $script:runLocalServerStartedAt) {
        $script:runLocalServerStartedAt = if ($script:runLocalStartTime) { $script:runLocalStartTime } else { Get-Date }
      }
    }
    $startedText = $script:runLocalServerStartedAt.ToString('yyyy-MM-dd HH:mm:ss')
    $uptimeText = Get-RunLocalUptimeText $script:runLocalServerStartedAt
    Set-ColoredStatus $runLocalStatusLabel "Started: $startedText   |   Running: $uptimeText   |   Session code: 12345   |   Folder: $($script:runLocalDirectory)" 'success'
  } else {
    $script:runLocalServerStartedAt = $null
    Set-ColoredStatus $runLocalStatusLabel 'Local server is stopped. Press the play button to start the Server.' 'info'
  }
}

$runLocalTimer = New-Object System.Windows.Forms.Timer
$runLocalTimer.Interval = 2000
$runLocalTimer.Add_Tick({ Update-RunLocalState })

$runLocalStartButton.Add_Click({
  try {
    if (Test-LocalServerRunning) {
      Update-RunLocalState
      return
    }
    $script:runLocalBatchFile = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-local-server-' + [Guid]::NewGuid().ToString('N') + '.bat')
    [IO.File]::WriteAllText($script:runLocalBatchFile, $runLocalServerBatchSource, (New-Object System.Text.UTF8Encoding($false)))
    # Run hidden in the background: no console window and no taskbar entry.
    $script:runLocalLogFile = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-run-local-' + [Guid]::NewGuid().ToString('N') + '.log')
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $env:ComSpec
    $startInfo.Arguments = '/d /s /c ""' + $script:runLocalBatchFile + '" /background > "' + $script:runLocalLogFile + '" 2>&1"'
    $startInfo.WorkingDirectory = $script:runLocalDirectory
    $startInfo.EnvironmentVariables['RUBELAPP_PROJECT_DIR'] = $script:runLocalDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $script:runLocalLauncher = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $script:runLocalLauncher) {
      throw 'Could not start the local server launcher.'
    }
    $script:runLocalStartedByForm = $true
    $script:runLocalStarting = $true
    $script:runLocalStartTime = Get-Date
    $script:runLocalLastState = ''
    Update-RunLocalState
  } catch {
    $errorMessage = $_.Exception.Message
    if ($script:runLocalBatchFile -and (-not $script:runLocalLauncher -or $script:runLocalLauncher.HasExited)) {
      try {
        Remove-RunLocalBatchFile
      } catch {
        $errorMessage += "`r`nCould not remove the temporary server launcher: $($_.Exception.Message)"
      }
    }
    Set-ColoredStatus $runLocalStatusLabel $errorMessage 'error'
  }
})

$runLocalStopButton.Add_Click({
  try {
    $ids = @(Get-LocalServerProcessIds)
    if ($ids.Count -eq 0) {
      $script:runLocalLastState = ''
      Update-RunLocalState
      return
    }
    Stop-LocalServer $ids
    Start-Sleep -Milliseconds 300
    $script:runLocalStartedByForm = $false
    $script:runLocalStarting = $false
    $script:runLocalLastState = ''
    Update-RunLocalState
    if (-not (Test-LocalServerRunning)) {
      Set-ColoredStatus $runLocalStatusLabel 'Local server stopped.' 'success'
    }
  } catch {
    Set-ColoredStatus $runLocalStatusLabel ("Could not stop the local server: " + $_.Exception.Message) 'error'
  }
})

$runLocalLogButton.Add_Click({
  if (-not $script:runLocalLogFile -or -not (Test-Path -LiteralPath $script:runLocalLogFile -PathType Leaf)) {
    Set-ColoredStatus $runLocalStatusLabel 'No server log yet. Start the local server from this form first.' 'info'
    return
  }
  try {
    Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $script:runLocalLogFile + '"') -ErrorAction Stop | Out-Null
  } catch {
    Set-ColoredStatus $runLocalStatusLabel $_.Exception.Message 'error'
  }
})

# Stop the background server when the form closes (only if this form started it).
$form.Add_FormClosing({
  if ($script:cloudflareOAuthProcess -and -not $script:cloudflareOAuthProcess.HasExited) {
    try {
      Stop-Process -Id $script:cloudflareOAuthProcess.Id -Force -ErrorAction Stop
    } catch {
    }
    $script:cloudflareOAuthProcess.Dispose()
    $script:cloudflareOAuthProcess = $null
    $cloudflareOAuthTimer.Stop()
    if ($script:cloudflareOAuthLogFile -and (Test-Path -LiteralPath $script:cloudflareOAuthLogFile -PathType Leaf)) {
      Remove-Item -LiteralPath $script:cloudflareOAuthLogFile -Force -ErrorAction SilentlyContinue
    }
    $script:cloudflareOAuthLogFile = ''
  }
  if ($script:runLocalStartedByForm) {
    try {
      Stop-LocalServer @(Get-LocalServerProcessIds)
    } catch {
    }
  }
})

$runLocalRefreshButton.Add_Click({
  $runLocalRefreshButton.Enabled = $false
  try {
    Set-ColoredStatus $runLocalStatusLabel 'Restarting the local server...' 'busy'
    Update-RunLocalNetworkUrl
    $wasRunning = Test-LocalServerRunning
    $ids = @(Get-LocalServerProcessIds)
    if ($wasRunning -and $ids.Count -eq 0) {
      throw 'Could not identify the process using the local server port.'
    }
    if ($wasRunning) {
      Stop-LocalServer $ids
      $stopDeadline = (Get-Date).AddSeconds(10)
      while ((Test-LocalServerRunning) -and (Get-Date) -lt $stopDeadline) {
        Start-Sleep -Milliseconds 200
      }
      if (Test-LocalServerRunning) {
        throw 'The local server did not stop; it could not be restarted.'
      }
    }
    $script:runLocalStartedByForm = $false
    $script:runLocalStarting = $false
    $script:runLocalLastState = ''
    Update-RunLocalState
    $runLocalStartButton.PerformClick()
  } catch {
    Set-ColoredStatus $runLocalStatusLabel ("Could not restart the local server: " + $_.Exception.Message) 'error'
  } finally {
    $runLocalRefreshButton.Enabled = $true
  }
})

$runLocalCopyUrlButton.Add_Click({
  [System.Windows.Forms.Clipboard]::SetText($runLocalUrlBox.Text)
  Set-ColoredStatus $runLocalStatusLabel 'Local URL copied.' 'info'
})
$runLocalCopyNetworkButton.Add_Click({
  if ($runLocalNetworkBox.Text -like 'http*') {
    [System.Windows.Forms.Clipboard]::SetText($runLocalNetworkBox.Text)
    Set-ColoredStatus $runLocalStatusLabel 'Network URL copied.' 'info'
  }
})
$runLocalOpenUrlButton.Add_Click({
  try { Start-Process $runLocalUrlBox.Text | Out-Null } catch { Set-ColoredStatus $runLocalStatusLabel $_.Exception.Message 'error' }
})
$runLocalOpenNetworkButton.Add_Click({
  try { Start-Process $runLocalNetworkBox.Text | Out-Null } catch { Set-ColoredStatus $runLocalStatusLabel $_.Exception.Message 'error' }
})
$runLocalDataButton.Add_Click({
  $dataFolder = $script:runLocalDirectory
  try {
    if (-not (Test-Path -LiteralPath $dataFolder -PathType Container)) {
      throw "Project folder was not found: $dataFolder"
    }
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $dataFolder + '"') -ErrorAction Stop | Out-Null
  } catch {
    Set-ColoredStatus $runLocalStatusLabel $_.Exception.Message 'error'
  }
})

$script:deleteRepoJob = $null
$script:deleteRepoStart = $null
$script:deleteRepoDots = 0
$script:deleteRepoStep = ''
$deleteRepoTimer = New-Object System.Windows.Forms.Timer
$deleteRepoTimer.Interval = 400

function Set-DeleteRepoControlsEnabled {
  param([bool]$Enabled)
  foreach ($control in @($deployRepoDeleteButton)) {
    if ($control) {
      $control.Enabled = $Enabled
    }
  }
  if ($Enabled) {
    Update-RestartButton
  } else {
    $restartButton.Enabled = $false
  }
}



function Set-DeleteRepoOperationStatus {
  param(
    [string]$Text,
    [string]$Kind = 'info',
    [bool]$CloudflareStatus = $false
  )
  if ($CloudflareStatus) {
    Set-CloudflareStatus $Text ($Kind -eq 'error')
    if ($Kind -eq 'success') {
      $cloudflareStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 130, 60)
    } elseif ($Kind -eq 'busy') {
      $cloudflareStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(38, 105, 176)
    }
  } else {
    Set-HomeStatus $Text $Kind
  }
}

# Shared repository-delete operation used by Home and Cloudflare.
function Start-DeleteRepo {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryUrl,
    [switch]$CloudflareStatus
  )

  $isCloudflareStatus = [bool]$CloudflareStatus
  if ($script:deleteRepoJob) {
    Set-DeleteRepoOperationStatus 'Wait for the current delete to finish.' 'error' $isCloudflareStatus
    return
  }
  if (Test-GitHubBusy) {
    Set-DeleteRepoOperationStatus 'Wait for the current GitHub upload to finish.' 'error' $isCloudflareStatus
    return
  }
  if (Test-CloudflareBusy) {
    Set-DeleteRepoOperationStatus 'Wait for the current Cloudflare or repository-delete operation to finish.' 'error' $isCloudflareStatus
    return
  }
  $url = $RepositoryUrl.Trim()
  if (-not (Test-GitHubRepositoryUrl $url)) {
    Set-DeleteRepoOperationStatus 'Enter a valid HTTPS GitHub repository URL.' 'error' $isCloudflareStatus
    return
  }
  $credentialUser = [string]$script:githubAccount
  if (-not $credentialUser) {
    $repositoryOwner = ''
    if ($url -match '^https://github\.com/([A-Za-z0-9_.-]+)/') {
      $repositoryOwner = $Matches[1]
    }
    try {
      $signedInAccounts = @(Get-GitHubSignedInAccounts)
    } catch {
      Set-DeleteRepoOperationStatus ("Could not check signed-in GitHub accounts: " + $_.Exception.Message) 'error' $isCloudflareStatus
      return
    }
    if ($repositoryOwner -and $signedInAccounts -contains $repositoryOwner) {
      $credentialUser = $repositoryOwner
    } elseif ($signedInAccounts.Count -eq 1) {
      $credentialUser = [string]$signedInAccounts[0]
    } elseif ($signedInAccounts.Count -gt 1) {
      Set-DeleteRepoOperationStatus 'Select the GitHub account with access to this repository, then try again.' 'error' $isCloudflareStatus
      return
    } else {
      Set-DeleteRepoOperationStatus 'Sign in to GitHub with an account that can access this repository, then try again.' 'error' $isCloudflareStatus
      return
    }
  }
  $answer = [System.Windows.Forms.MessageBox]::Show(
    "Delete every tracked file from the default branch of:`r`n$(Get-DisplayRepositoryUrl $url)`r`n`r`nThis makes the branch empty; the repository, its history and other branches remain. Continue?",
    'Delete-Repo',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Warning,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
  if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
    Set-DeleteRepoOperationStatus 'Delete cancelled. No changes were made.' 'info' $isCloudflareStatus
    return
  }

  $id = [Guid]::NewGuid().ToString('N')
  $logFile = Join-Path ([IO.Path]::GetTempPath()) ("ijtc-delete-repo-$id.log")
  Set-DeleteRepoControlsEnabled $false
  try {
    $formPath = if ($env:COMBOX_FORM_SELF) { $env:COMBOX_FORM_SELF } else { Join-Path $toolDirectory 'Form.bat' }
    $quote = { param([string]$Value) "'" + $Value.Replace("'", "''") + "'" }
    $workerCommand = '& ([scriptblock]::Create([IO.File]::ReadAllText(' + (& $quote $formPath) + ')))' +
      ' -DeleteRepoWorker -DeleteRepoUrl ' + (& $quote $url) +
      ' *> ' + (& $quote $logFile)
    $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $powerShellPath
    $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -EncodedCommand ' +
      [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($workerCommand))
    $startInfo.WorkingDirectory = [IO.Path]::GetTempPath()
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $startInfo.EnvironmentVariables['GCM_INTERACTIVE'] = 'never'
    $startInfo.EnvironmentVariables['GIT_CONFIG_COUNT'] = '1'
    $startInfo.EnvironmentVariables['GIT_CONFIG_KEY_0'] = 'credential.https://github.com.username'
    $startInfo.EnvironmentVariables['GIT_CONFIG_VALUE_0'] = $credentialUser
    $process = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $process) {
      throw 'Could not start the embedded repository-delete worker.'
    }
    $script:deleteRepoJob = [pscustomobject]@{
      Process         = $process
      LogFile         = $logFile
      Url             = $url
      CloudflareStatus = $isCloudflareStatus
    }
    $script:deleteRepoStart = Get-Date
    $script:deleteRepoDots = 0
    $script:deleteRepoStep = 'Starting...'
    $restartButton.Enabled = $false
    Set-DeleteRepoOperationStatus 'Preparing to empty the repository...' 'busy' $isCloudflareStatus
    $deleteRepoTimer.Start()
  } catch {
    $script:deleteRepoJob = $null
    Set-DeleteRepoControlsEnabled $true
    Set-DeleteRepoOperationStatus $_.Exception.Message 'error' $isCloudflareStatus
  }
}

$deployRepoDeleteButton.Add_Click({
  Start-DeleteRepo -RepositoryUrl $deployRepoBox.Text.Trim() -CloudflareStatus
})

$deleteRepoTimer.Add_Tick({
  $job = $script:deleteRepoJob
  if (-not $job) {
    $deleteRepoTimer.Stop()
    return
  }
  $log = ''
  try {
    $log = Read-CloudflareJobLog $job.LogFile
  } catch {
    $log = ''
  }
  $logLines = @($log -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($logLines.Count -gt 0) {
    $script:deleteRepoStep = $logLines[-1].Trim()
  }

  if (-not $job.Process.HasExited) {
    $script:deleteRepoDots = ($script:deleteRepoDots % 3) + 1
    Set-DeleteRepoOperationStatus ('Deleting' + ('.' * $script:deleteRepoDots) + '   |   Elapsed: ' + (Get-ElapsedText $script:deleteRepoStart) + '   |   ' + $script:deleteRepoStep) 'busy' $job.CloudflareStatus
    return
  }

  $deleteRepoTimer.Stop()
  $job.Process.Dispose()
  $script:deleteRepoJob = $null
  Remove-Item -LiteralPath $job.LogFile -Force -ErrorAction SilentlyContinue
  $elapsedText = Get-ElapsedText $script:deleteRepoStart
  $script:deleteRepoStart = $null
  Set-DeleteRepoControlsEnabled $true
  if ($log -match 'All tracked files have been deleted') {
    Set-DeleteRepoOperationStatus "All files deleted from $(Get-DisplayRepositoryUrl $job.Url)   |   Total time: $elapsedText" 'success' $job.CloudflareStatus
    return
  }
  $details = $log.Trim()
  if (-not $details) {
    $details = 'The embedded repository-delete worker finished without output.'
  }
  Set-DeleteRepoOperationStatus "Delete failed   |   Total time: $elapsedText   |   $script:deleteRepoStep" 'error' $job.CloudflareStatus
  Show-ComBoxMessage ($details) 'Delete-Repo failed' $true
})

# ----- ADB section -----
# The ADB implementation is embedded in Form.bat.
$adbScriptSource = @'
param(
  $HostPanel,
  [string]$ProjectRoot = 'D:\AllApp-Android-Source'
)

$ErrorActionPreference = 'Stop'
if ($ExecutionContext.SessionState.Module) {
  # Loaded by IJTC-ComBox: keep this file's functions private.
  Export-ModuleMember -Function 'AdbNothingExported'
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Builds the ADB tools inside $Panel (the ADB tab, or this file's own window).
# $ProjectRoot is the Android project folder chosen in the tab's folder bar.
$adbLastConnectFile = Join-Path $env:LOCALAPPDATA 'IJTC\adb-last-connect.json'

# adb.exe from PATH or the Android SDK platform-tools folder.
function Get-AdbPath {
  $command = Get-Command 'adb.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($command) {
    return $command.Source
  }
  foreach ($sdk in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $env:LOCALAPPDATA 'Android\Sdk'))) {
    if ($sdk) {
      $candidate = Join-Path $sdk 'platform-tools\adb.exe'
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return $candidate
      }
    }
  }
  return ''
}

function Start-AdbProcess {
  param([string]$Arguments)
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $script:adbPath
  $startInfo.Arguments = $Arguments
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $process = [System.Diagnostics.Process]::Start($startInfo)
  return [pscustomobject]@{ Process = $process; Output = $process.StandardOutput.ReadToEndAsync(); Errors = $process.StandardError.ReadToEndAsync() }
}

function Invoke-AdbQuick {
  param([string]$Arguments, [int]$TimeoutMs = 3000)
  $job = Start-AdbProcess $Arguments
  try {
    if (-not $job.Process.WaitForExit($TimeoutMs)) {
      try { $job.Process.Kill() } catch { }
      return ''
    }
    return ([string]$job.Output.Result).Trim()
  } finally {
    $job.Process.Dispose()
  }
}

function Read-AdbLastConnect {
  try {
    if (Test-Path -LiteralPath $adbLastConnectFile -PathType Leaf) {
      return (Get-Content -LiteralPath $adbLastConnectFile -Raw | ConvertFrom-Json)
    }
  } catch {
  }
  return $null
}

function Save-AdbLastConnect {
  param($Info)
  try {
    $folder = Split-Path -Parent $adbLastConnectFile
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
      New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($adbLastConnectFile, ($Info | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
  } catch {
  }
}

function Format-AdbLastConnect {
  param($Info)
  if (-not $Info) {
    return 'No device has been connected yet.'
  }
  $parts = @("$($Info.Model)")
  if ($Info.Android) { $parts += "Android $($Info.Android)" }
  $parts += "Serial: $($Info.Serial)"
  $parts += "$($Info.Connection)"
  $parts += "Time: $($Info.Time)"
  return ($parts -join '   |   ')
}

function Update-AdbDisplay {
  param([string]$State, [string]$Kind = 'info')
  $script:adbLastLabel.Text = Format-AdbLastConnect (Read-AdbLastConnect)
  $script:adbStateLabel.Text = $State
  switch ($Kind) {
    'success' { $script:adbStateLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 130, 60) }
    'error'   { $script:adbStateLabel.ForeColor = [System.Drawing.Color]::Firebrick }
    default   { $script:adbStateLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 110) }
  }
}

$adbLastWirelessFile = Join-Path $env:LOCALAPPDATA 'IJTC\adb-last-wireless.txt'

# Handles one finished "adb devices -l": updates both rows.
function Complete-AdbCheck {
  param([string]$Output)
  $script:adbLastOutput = $Output
  Complete-AdbCheckCore $Output
  Update-AdbConnectionRow
}

function Test-AdbWirelessSerial {
  param([string]$Serial)
  return ($Serial -match ':\d+$' -or $Serial -match '\._tcp')
}

function Get-AdbLastWireless {
  try {
    if (Test-Path -LiteralPath $adbLastWirelessFile -PathType Leaf) {
      return ([System.IO.File]::ReadAllText($adbLastWirelessFile)).Trim()
    }
  } catch {
  }
  return ''
}

function Set-AdbRowLabel {
  param($Label, [string]$Text, [bool]$On)
  $Label.Text = $Text
  if ($On) {
    $Label.ForeColor = [System.Drawing.Color]::FromArgb(30, 130, 60)
  } else {
    $Label.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 130)
  }
}

# USB / Wireless row: which connection is active now.
function Update-AdbConnectionRow {
  $usb = ''
  $wireless = ''
  foreach ($line in ([string]$script:adbLastOutput -split "`r?`n")) {
    if ($line -match '^(\S+)\s+device\b') {
      $serial = $Matches[1]
      if (Test-AdbWirelessSerial $serial) {
        if (-not $wireless) { $wireless = $serial }
      } elseif (-not $usb) {
        $usb = $serial
      }
    }
  }
  $script:adbUsbSerial = $usb
  $script:adbWirelessSerial = $wireless
  if ($usb) {
    Set-AdbRowLabel $script:adbUsbLabel "Connected ($usb)" $true
  } else {
    Set-AdbRowLabel $script:adbUsbLabel 'Not connected' $false
  }
  $script:adbToWirelessButton.Enabled = [bool]$usb -and -not $script:adbBusy
  if ($wireless) {
    Set-AdbRowLabel $script:adbWirelessLabel "Connected ($wireless)" $true
    $script:adbWirelessButton.Text = [string][char]0xE711
    $script:adbTip.SetToolTip($script:adbWirelessButton, "Disconnect wireless ($wireless)")
  } else {
    $last = Get-AdbLastWireless
    $text = if ($last) { "Not connected (last: $last)" } else { 'Not connected' }
    Set-AdbRowLabel $script:adbWirelessLabel $text $false
    $script:adbWirelessButton.Text = [string][char]0xE71B
    $script:adbTip.SetToolTip($script:adbWirelessButton, $(if ($last) { "Reconnect wireless ($last)" } else { 'Connect wireless (switch from USB first)' }))
  }
  $script:adbWirelessButton.Enabled = -not $script:adbBusy
}

function Wait-AdbUi {
  param([int]$Milliseconds)
  $until = (Get-Date).AddMilliseconds($Milliseconds)
  while ((Get-Date) -lt $until) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 100
  }
}

function Set-AdbBusy {
  param([bool]$Busy, [string]$Text = '')
  $script:adbBusy = $Busy
  if ($Text) {
    Update-AdbDisplay $Text $(if ($Busy) { 'info' } else { 'success' })
  }
  $script:adbToWirelessButton.Enabled = -not $Busy -and [bool]$script:adbUsbSerial
  $script:adbWirelessButton.Enabled = -not $Busy
  [System.Windows.Forms.Application]::DoEvents()
}

# USB -> Wireless: adb tcpip 5555 on the USB phone, then adb connect <phone IP>:5555.
function Switch-AdbToWireless {
  $serial = $script:adbUsbSerial
  if (-not $serial) {
    Update-AdbDisplay 'Connect the phone with USB first.' 'error'
    return
  }
  Set-AdbBusy $true 'Finding the phone''s Wi-Fi address...'
  try {
    $ip = ''
    $address = Invoke-AdbQuick ('-s ' + $serial + ' shell ip -f inet addr show wlan0')
    if ($address -match 'inet (\d+\.\d+\.\d+\.\d+)') {
      $ip = $Matches[1]
    } else {
      $route = Invoke-AdbQuick ('-s ' + $serial + ' shell ip route')
      if ($route -match 'wlan\d+.*?src (\d+\.\d+\.\d+\.\d+)') {
        $ip = $Matches[1]
      }
    }
    if (-not $ip) {
      throw 'The phone is not on Wi-Fi. Connect the phone and this PC to the same Wi-Fi, then try again.'
    }
    Set-AdbBusy $true "Turning on wireless debugging (${ip}:5555)..."
    $null = Invoke-AdbQuick ('-s ' + $serial + ' tcpip 5555') 8000
    Wait-AdbUi 2500
    Set-AdbBusy $true "Connecting to ${ip}:5555..."
    $result = Invoke-AdbQuick ('connect ' + $ip + ':5555') 10000
    if ($result -notmatch 'connected to') {
      throw ("Could not connect to ${ip}:5555. " + $result)
    }
    [System.IO.File]::WriteAllText($adbLastWirelessFile, "${ip}:5555")
    Set-AdbBusy $false "Wireless connected: ${ip}:5555. You can unplug the USB cable now."
  } catch {
    Set-AdbBusy $false
    Update-AdbDisplay $_.Exception.Message 'error'
  }
  $script:adbConnectedSerial = ''
}

function Switch-AdbWireless {
  if ($script:adbWirelessSerial) {
    Set-AdbBusy $true "Disconnecting $($script:adbWirelessSerial)..."
    $null = Invoke-AdbQuick ('disconnect ' + $script:adbWirelessSerial) 5000
    Set-AdbBusy $false 'Wireless disconnected.'
    return
  }
  $last = Get-AdbLastWireless
  if (-not $last) {
    Update-AdbDisplay 'No wireless address yet: connect the phone with USB and press the USB to Wireless button.' 'error'
    return
  }
  Set-AdbBusy $true "Connecting to $last..."
  $result = Invoke-AdbQuick ('connect ' + $last) 10000
  if ($result -match 'connected to') {
    Set-AdbBusy $false "Wireless connected: $last"
  } else {
    Set-AdbBusy $false
    Update-AdbDisplay ("Could not connect to $last. Connect with USB and press USB to Wireless again. " + $result) 'error'
  }
}

# Package name (applicationId) of an APK: from output-metadata.json next to it,
# or from the Android SDK's aapt/aapt2.
function Get-ApkPackageName {
  param([string]$Apk)
  try {
    $metadata = Join-Path (Split-Path -Parent $Apk) 'output-metadata.json'
    if (Test-Path -LiteralPath $metadata -PathType Leaf) {
      $json = Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json
      $listed = @($json.elements | Where-Object { $_.outputFile -and ((Split-Path -Leaf $Apk) -ieq $_.outputFile) })
      if ($json.applicationId -and ($listed.Count -gt 0 -or @($json.elements).Count -eq 1)) {
        return [string]$json.applicationId
      }
    }
  } catch {
  }
  $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $env:LOCALAPPDATA 'Android\Sdk')) | Where-Object { $_ }
  if ($script:adbPath) {
    $sdkRoots += Split-Path -Parent (Split-Path -Parent $script:adbPath)
  }
  foreach ($sdk in $sdkRoots) {
    $tools = Join-Path $sdk 'build-tools'
    if (-not (Test-Path -LiteralPath $tools -PathType Container)) {
      continue
    }
    foreach ($folder in @(Get-ChildItem -LiteralPath $tools -Directory | Sort-Object Name -Descending)) {
      $aapt2 = Join-Path $folder.FullName 'aapt2.exe'
      $aapt = Join-Path $folder.FullName 'aapt.exe'
      try {
        if (Test-Path -LiteralPath $aapt2 -PathType Leaf) {
          $name = (& $aapt2 dump packagename $Apk 2>$null | Select-Object -First 1)
          if ($name -and $name.Trim() -match '^[A-Za-z][\w.]*$') {
            return $name.Trim()
          }
        }
        if (Test-Path -LiteralPath $aapt -PathType Leaf) {
          $badging = (& $aapt dump badging $Apk 2>$null | Select-Object -First 1)
          if ($badging -match "package: name='([^']+)'") {
            return $Matches[1]
          }
        }
      } catch {
      }
    }
  }
  return ''
}

# Plain-language hint for common adb install failure codes.
function Get-AdbInstallHint {
  param([string]$Text)
  $hints = [ordered]@{
    'INSTALL_FAILED_USER_RESTRICTED'           = 'Blocked on the phone: turn on "Install via USB" in Developer options (Xiaomi needs a Mi account), or accept the prompt on the phone.'
    'INSTALL_FAILED_UPDATE_INCOMPATIBLE'       = 'The installed app has a different signature. Uninstall it from the phone, then install again.'
    'INSTALL_FAILED_VERSION_DOWNGRADE'         = 'The phone has a newer version (higher versionCode) and the APK could not replace it. Uninstall the app from the phone, or raise versionCode and build again.'
    'INSTALL_FAILED_INSUFFICIENT_STORAGE'      = 'Not enough free storage on the phone.'
    'INSTALL_FAILED_OLDER_SDK'                 = 'The app needs a newer Android version than this phone has (minSdk too high).'
    'INSTALL_FAILED_TEST_ONLY'                 = 'This is a test-only APK (android:testOnly). Build a normal APK, or install with adb install -t.'
    'INSTALL_FAILED_NO_MATCHING_ABIS'          = 'The APK has no native libraries for this phone''s CPU (ABI).'
    'INSTALL_FAILED_ALREADY_EXISTS'            = 'The app already exists and could not be replaced. Uninstall it first.'
    'INSTALL_FAILED_DUPLICATE_PERMISSION'      = 'Another installed app already defines the same permission.'
    'INSTALL_FAILED_CONFLICTING_PROVIDER'      = 'Another installed app already uses the same content provider authority.'
    'INSTALL_PARSE_FAILED_NO_CERTIFICATES'     = 'The APK is not signed (or signed incorrectly).'
    'INSTALL_PARSE_FAILED_NOT_APK'             = 'The file is not a valid APK.'
    'INSTALL_FAILED_INVALID_APK'               = 'The APK is damaged or invalid. Build it again.'
    'INSTALL_FAILED_ABORTED'                   = 'The install was cancelled on the phone.'
    'INSTALL_CANCELED_BY_USER'                 = 'The install was cancelled on the phone.'
    'INSTALL_FAILED_VERIFICATION_FAILURE'      = 'Play Protect / package verification rejected the APK.'
    'device offline'                           = 'The phone went offline. Reconnect it and try again.'
    'device unauthorized'                      = 'Allow USB debugging on the phone (accept the RSA prompt).'
    "' not found"                              = 'The phone is not connected any more. Reconnect it and try again.'
  }
  foreach ($key in $hints.Keys) {
    if ($Text -match [regex]::Escape($key)) {
      return $hints[$key]
    }
  }
  return ''
}

# Shows (or clears) the install failure reason under the APK box.
function Set-AdbInstallError {
  param([string]$Reason, [string]$Details = '')
  if (-not $script:adbInstallErrorLabel) {
    return
  }
  if (-not $Reason) {
    $script:adbInstallErrorFull = ''
    $script:adbInstallErrorLabel.Text = ''
    $script:adbInstallErrorLabel.Visible = $false
    $script:adbInstallErrorCopy.Visible = $false
    $script:adbTip.SetToolTip($script:adbInstallErrorLabel, '')
    return
  }
  $hint = Get-AdbInstallHint ($Reason + ' ' + $Details)
  $shown = if ($hint) { "$Reason - $hint" } else { $Reason }
  $full = $shown
  if ($Details -and $Details.Trim() -and $Details.Trim() -ne $Reason.Trim()) {
    $full += "`r`n`r`nadb output:`r`n" + $Details.Trim()
  }
  $script:adbInstallErrorFull = $full
  $script:adbInstallErrorLabel.Text = $shown
  $script:adbInstallErrorLabel.Visible = $true
  $script:adbInstallErrorCopy.Visible = $true
  $script:adbTip.SetToolTip($script:adbInstallErrorLabel, $full)
}

# Runs one "adb install ..." with a progress line; returns adb's combined output.
function Invoke-AdbInstallRun {
  param([string]$Serial, [string]$Arguments, [string]$Label)
  $job = Start-AdbProcess ('-s ' + $Serial + ' ' + $Arguments)
  $start = Get-Date
  try {
    while (-not $job.Process.HasExited) {
      Update-AdbDisplay ("$Label on $Serial...   |   Elapsed: " + [int]((Get-Date) - $start).TotalSeconds + ' s   |   Confirm on the phone if it asks.')
      Wait-AdbUi 300
      if (((Get-Date) - $start).TotalMinutes -gt 5) {
        try { $job.Process.Kill() } catch { }
        throw 'Install timed out after 5 minutes.'
      }
    }
    return (([string]$job.Output.Result) + ' ' + ([string]$job.Errors.Result)).Trim()
  } finally {
    $job.Process.Dispose()
  }
}

# Installs an APK from a link (https://...) or a file path on the connected phone.
function Install-AdbApk {
  $source = $script:adbApkBox.Text.Trim().Trim('"')
  Set-AdbInstallError ''
  $script:adbInstallOutput = ''
  if (-not $source) {
    Update-AdbDisplay 'Enter an APK link (https://...) or file path first.' 'error'
    Set-AdbInstallError 'Enter an APK link (https://...) or file path first.'
    return
  }
  $serial = if ($script:adbWirelessSerial) { $script:adbWirelessSerial } else { $script:adbUsbSerial }
  if (-not $serial) {
    Update-AdbDisplay 'No phone is connected. Connect with USB or Wireless first.' 'error'
    Set-AdbInstallError 'No phone is connected. Connect with USB or Wireless first.'
    return
  }
  $temporary = ''
  Set-AdbBusy $true 'Preparing the APK...'
  $script:adbApkButton.Enabled = $false
  try {
    if ($source -match '^https?://') {
      $temporary = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-install-' + [Guid]::NewGuid().ToString('N') + '.apk')
      [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
      $client = New-Object System.Net.WebClient
      try {
        $task = $client.DownloadFileTaskAsync($source, $temporary)
        $start = Get-Date
        while (-not $task.IsCompleted) {
          $size = if (Test-Path -LiteralPath $temporary) { (Get-Item -LiteralPath $temporary).Length } else { 0 }
          Update-AdbDisplay ('Downloading the APK... ' + [Math]::Round($size / 1MB, 1) + ' MB   |   Elapsed: ' + [int]((Get-Date) - $start).TotalSeconds + ' s')
          Wait-AdbUi 300
        }
        if ($task.IsFaulted) {
          throw ('Download failed: ' + $task.Exception.GetBaseException().Message)
        }
      } finally {
        $client.Dispose()
      }
      $apk = $temporary
    } elseif (Test-Path -LiteralPath $source -PathType Container) {
      # A folder: use the newest .apk inside it (for a project, its build output).
      $found = Get-ChildItem -LiteralPath $source -Filter '*.apk' -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if (-not $found) {
        throw "No .apk file was found in $source. Use the search button to choose one."
      }
      $apk = $found.FullName
      $script:adbApkBox.Text = $apk
    } else {
      if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "APK file not found: $source"
      }
      $apk = (Resolve-Path -LiteralPath $source).Path
    }
    $bytes = New-Object byte[] 2
    $stream = [IO.File]::OpenRead($apk)
    try { [void]$stream.Read($bytes, 0, 2) } finally { $stream.Dispose() }
    if ($bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4B) {
      throw 'The link or file is not an APK (it is not a valid Android package).'
    }

    $output = Invoke-AdbInstallRun $serial ('install -r "' + $apk + '"') 'Installing'
    if ($output -notmatch 'Success' -and $output -match 'INSTALL_FAILED_VERSION_DOWNGRADE') {
      # The phone has a newer versionCode: a debug APK may be installed over it with -d (keeps app data).
      $output = Invoke-AdbInstallRun $serial ('install -r -d "' + $apk + '"') 'Phone has a newer version. Installing the older build over it (-d)'
    }
    if ($output -notmatch 'Success' -and $output -match 'INSTALL_FAILED_VERSION_DOWNGRADE|INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
      # Still blocked (release APK, or a different signature): offer uninstall + install.
      $package = Get-ApkPackageName $apk
      if ($package) {
        $why = if ($output -match 'UPDATE_INCOMPATIBLE') { 'The app on the phone is signed with a different key.' } else { 'The phone has a newer version of the app.' }
        $answer = [System.Windows.Forms.MessageBox]::Show("$why`r`n`r`nUninstall $package from the phone and install this APK?`r`nThe app's data on the phone (login, settings, files) will be erased.", 'Install failed', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
        if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
          Update-AdbDisplay "Uninstalling $package from $serial..."
          $removed = Invoke-AdbQuick ('-s ' + $serial + ' uninstall ' + $package) 60000
          if ($removed -notmatch 'Success') {
            $script:adbInstallOutput = "$output`r`n`r`nadb uninstall $package`r`n$removed"
            throw "Could not uninstall $package from the phone: $removed"
          }
          $output = Invoke-AdbInstallRun $serial ('install -r "' + $apk + '"') 'Installing after uninstall'
        }
      }
    }
    $script:adbInstallOutput = $output
    if ($output -match 'Success') {
      # Start the app right after installing it.
      Update-AdbDisplay "Installed on $serial. Starting the app..."
      $package = Get-ApkPackageName $apk
      $script:adbApkBox.Clear()
      if (-not $package) {
        Set-AdbBusy $false "Installed on $serial (could not read the package name to start it)."
      } else {
        $null = Invoke-AdbQuick ('-s ' + $serial + ' logcat -b crash -c') 5000
        Set-AdbWatchPackage $package
        $launch = Invoke-AdbQuick ('-s ' + $serial + ' shell monkey -p ' + $package + ' -c android.intent.category.LAUNCHER 1') 15000
        if ($launch -match 'Events injected: 1') {
          Set-AdbBusy $false "Installed and started $package on $serial."
        } else {
          Set-AdbBusy $false
          Update-AdbDisplay "Installed $package on $serial, but it could not be started automatically." 'error'
        }
      }
    } else {
      $reason = if ($output -match '(INSTALL_[A-Z_]+[^\]]*)') { $Matches[1] } elseif ($output) { $output } else { 'adb returned no output.' }
      throw "Install failed: $reason"
    }
  } catch {
    Set-AdbBusy $false
    Update-AdbDisplay $_.Exception.Message 'error'
    Set-AdbInstallError $_.Exception.Message $script:adbInstallOutput
  } finally {
    if ($temporary) {
      Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
    $script:adbApkButton.Enabled = $true
  }
}

# Finds .apk files inside the Android project folder (skipping tool/cache folders).
function Find-ProjectApks {
  $skip = @('.git', '.gradle', '.idea', '.kotlin', '.vscode', 'node_modules', 'intermediates', 'tmp')
  $results = New-Object System.Collections.Generic.List[object]
  $pending = New-Object System.Collections.Generic.Stack[string]
  if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    return @()
  }
  $pending.Push($ProjectRoot)
  while ($pending.Count -gt 0) {
    $folder = $pending.Pop()
    foreach ($item in @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue)) {
      if ($item.PSIsContainer) {
        if ($skip -notcontains $item.Name) {
          $pending.Push($item.FullName)
        }
      } elseif ($item.Extension -ieq '.apk') {
        $results.Add($item)
      }
    }
  }
  return @($results | Sort-Object LastWriteTime -Descending)
}

# Search button: one APK is installed directly; several are listed to choose from.
function Select-ProjectApk {
  Update-AdbDisplay "Searching for .apk files in $ProjectRoot..."
  [System.Windows.Forms.Application]::DoEvents()
  $apks = @(Find-ProjectApks)
  if ($apks.Count -eq 0) {
    Update-AdbDisplay "No .apk file was found in $ProjectRoot. Save the settings, then click Build in the Apk update tab." 'error'
    return
  }
  if ($apks.Count -eq 1) {
    $script:adbApkBox.Text = $apks[0].FullName
    Install-AdbApk
    return
  }
  Update-AdbDisplay "$($apks.Count) APK files found. Choose one to install."

  $dialog = New-Object System.Windows.Forms.Form
  $dialog.Text = 'Choose the APK to install'
  $dialog.StartPosition = 'CenterParent'
  $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $dialog.MaximizeBox = $false
  $dialog.MinimizeBox = $false
  $dialog.ShowInTaskbar = $false
  $dialog.ClientSize = New-Object System.Drawing.Size(760, 320)
  $dialog.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $dialog.BackColor = [System.Drawing.Color]::White

  $list = New-Object System.Windows.Forms.ListView
  $list.View = [System.Windows.Forms.View]::Details
  $list.FullRowSelect = $true
  $list.MultiSelect = $false
  $list.HideSelection = $false
  $list.Location = New-Object System.Drawing.Point(12, 12)
  $list.Size = New-Object System.Drawing.Size(736, 256)
  [void]$list.Columns.Add('APK file (inside the project folder)', 470)
  [void]$list.Columns.Add('Size', 80)
  [void]$list.Columns.Add('Modified', 160)
  foreach ($apk in $apks) {
    $relative = $apk.FullName.Substring($ProjectRoot.TrimEnd('\').Length).TrimStart('\')
    $row = New-Object System.Windows.Forms.ListViewItem($relative)
    [void]$row.SubItems.Add(('{0:N1} MB' -f ($apk.Length / 1MB)))
    [void]$row.SubItems.Add($apk.LastWriteTime.ToString('dd-MMM-yyyy hh:mm tt'))
    $row.Tag = $apk.FullName
    [void]$list.Items.Add($row)
  }
  $list.Items[0].Selected = $true
  $dialog.Controls.Add($list)

  $install = New-Object System.Windows.Forms.Button
  $install.Text = 'Install'
  $install.Location = New-Object System.Drawing.Point(568, 280)
  $install.Size = New-Object System.Drawing.Size(88, 30)
  $install.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $dialog.Controls.Add($install)
  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = 'Cancel'
  $cancel.Location = New-Object System.Drawing.Point(660, 280)
  $cancel.Size = New-Object System.Drawing.Size(88, 30)
  $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $dialog.Controls.Add($cancel)
  $dialog.AcceptButton = $install
  $dialog.CancelButton = $cancel
  $list.Add_DoubleClick({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK })

  try {
    $result = $dialog.ShowDialog()
    $chosen = if ($list.SelectedItems.Count -gt 0) { [string]$list.SelectedItems[0].Tag } else { '' }
  } finally {
    $dialog.Dispose()
  }
  if ($result -ne [System.Windows.Forms.DialogResult]::OK -or -not $chosen) {
    Update-AdbDisplay 'Install cancelled.'
    return
  }
  $script:adbApkBox.Text = $chosen
  Install-AdbApk
}

# ----- App errors: crashes of the watched app from the phone's crash log -----
function Get-AdbTargetSerial {
  if ($script:adbWirelessSerial) { return $script:adbWirelessSerial }
  return $script:adbUsbSerial
}

# Last crash of $Package in "adb logcat -b crash -d" output, or $null.
function Get-AdbLastCrash {
  param([string]$Output, [string]$Package)
  $blocks = New-Object System.Collections.Generic.List[object]
  $current = $null
  foreach ($line in ($Output -split "`r?`n")) {
    if ($line -notmatch 'AndroidRuntime\s*:\s?(.*)$') {
      continue
    }
    $text = $Matches[1]
    if ($text -match '^FATAL EXCEPTION') {
      $time = if ($line -match '^\d\d-\d\d\s+(\d\d:\d\d:\d\d)') { $Matches[1] } else { '' }
      $current = [pscustomobject]@{ Time = $time; Lines = (New-Object System.Collections.Generic.List[string]) }
      $blocks.Add($current)
    }
    if ($current) {
      $current.Lines.Add($text)
    }
  }
  for ($index = $blocks.Count - 1; $index -ge 0; $index--) {
    $block = $blocks[$index]
    if (@($block.Lines | Where-Object { $_ -match ('^Process: ' + [regex]::Escape($Package) + ',') }).Count -gt 0) {
      $summary = @($block.Lines | Where-Object { $_ -notmatch '^(FATAL EXCEPTION|Process: )' } | Select-Object -First 1)
      return [pscustomobject]@{
        Time    = $block.Time
        Summary = $(if ($summary.Count -gt 0) { $summary[0].Trim() } else { 'The app crashed.' })
        Full    = ($block.Lines -join "`r`n")
      }
    }
  }
  return $null
}

function Show-AdbAppError {
  param($Crash)
  $script:adbErrorIsInfo = $false
  if ($Crash) {
    $script:adbErrorFull = "$($script:adbWatchPackage) crashed at $($Crash.Time)`r`n$($Crash.Full)"
    $script:adbErrorBox.Text = "$($Crash.Time)  $($Crash.Summary)"
    $script:adbErrorBox.ForeColor = [System.Drawing.Color]::Firebrick
    $script:adbTip.SetToolTip($script:adbErrorBox, ((@($Crash.Full -split "`r`n") | Select-Object -First 12) -join "`r`n"))
    $script:adbErrorCopy.Enabled = $true
    $script:adbErrorView.Enabled = $true
  } else {
    $script:adbErrorFull = ''
    $script:adbErrorBox.Text = $(if ($script:adbWatchPackage) { "No app errors ($($script:adbWatchPackage))" } else { 'No app errors' })
    $script:adbErrorBox.ForeColor = [System.Drawing.Color]::FromArgb(130, 130, 130)
    $script:adbTip.SetToolTip($script:adbErrorBox, 'Crashes of the app appear here while the phone is connected.')
    $script:adbErrorCopy.Enabled = $false
    if ($script:adbErrorView) { $script:adbErrorView.Enabled = $false }
  }
}

# Refresh button next to the error box: finds the app in front on the phone,
# shows its details there (copy / view buttons work on them) and watches it for crashes.
function Show-AdbRunningApp {
  $serial = if ($script:adbWirelessSerial) { $script:adbWirelessSerial } else { $script:adbUsbSerial }
  if (-not $serial) {
    Update-AdbDisplay 'No phone is connected. Connect with USB or Wireless first.' 'error'
    return
  }
  $script:adbAppInfoButton.Enabled = $false
  try {
    Update-AdbDisplay "Reading the running app on $serial..."
    [System.Windows.Forms.Application]::DoEvents()
    $package = ''
    $activity = ''
    $activities = Invoke-AdbQuick ('-s ' + $serial + ' shell dumpsys activity activities') 15000
    if ($activities -match '(?:mResumedActivity|topResumedActivity|ResumedActivity)[:=]\s*ActivityRecord\{\S+ u\d+ ([\w.]+)/([\w.$]+)') {
      $package = $Matches[1]
      $activity = $Matches[2]
    } else {
      $windows = Invoke-AdbQuick ('-s ' + $serial + ' shell dumpsys window') 15000
      if ($windows -match 'mCurrentFocus=Window\{\S+ u\d+ ([\w.]+)/([\w.$]+)') {
        $package = $Matches[1]
        $activity = $Matches[2]
      }
    }
    if (-not $package) {
      Update-AdbDisplay 'No app is open on the phone right now (or the phone is locked).' 'error'
      return
    }
    if ($activity.StartsWith('.')) {
      $activity = $package + $activity
    }
    $details = Invoke-AdbQuick ('-s ' + $serial + ' shell dumpsys package ' + $package) 15000
    $value = {
      param([string]$Pattern)
      if ($details -match $Pattern) { return $Matches[1].Trim() } else { return '' }
    }
    $versionName = & $value 'versionName=(\S+)'
    $versionCode = & $value 'versionCode=(\d+)'
    $minSdk = & $value 'minSdk=(\d+)'
    $targetSdk = & $value 'targetSdk=(\d+)'
    $installed = & $value 'firstInstallTime=([^\r\n]+)'
    $updated = & $value 'lastUpdateTime=([^\r\n]+)'
    $installer = & $value 'installerPackageName=(\S+)'
    $path = & $value 'codePath=(\S+)'
    $debuggable = if ($details -match 'pkgFlags=\[[^\]]*DEBUGGABLE') { 'yes' } else { 'no' }
    $processId = (Invoke-AdbQuick ('-s ' + $serial + ' shell pidof ' + $package) 5000).Trim()
    $memory = ''
    if ($processId) {
      $meminfo = Invoke-AdbQuick ('-s ' + $serial + ' shell dumpsys meminfo ' + $package) 15000
      if ($meminfo -match 'TOTAL(?: PSS)?[:\s]+(\d+)') {
        $memory = ([Math]::Round([int64]$Matches[1] / 1024, 1)).ToString() + ' MB'
      }
    }

    Set-AdbWatchPackage $package
    $short = "Running: $package"
    if ($versionName) { $short += "  v$versionName" }
    if ($versionCode) { $short += " ($versionCode)" }
    if ($processId) { $short += "  PID $processId" }
    $lines = @(
      "Running app on $serial  ($((Get-Date).ToString('dd-MMM-yyyy hh:mm:ss tt')))",
      '',
      "Package:        $package",
      "Activity:       $activity",
      "Version name:   $versionName",
      "Version code:   $versionCode",
      "PID:            $(if ($processId) { $processId } else { '-' })",
      "Memory (PSS):   $(if ($memory) { $memory } else { '-' })",
      "Debuggable:     $debuggable",
      "minSdk/target:  $minSdk / $targetSdk",
      "Installed:      $installed",
      "Last update:    $updated",
      "Installer:      $(if ($installer -and $installer -ne 'null') { $installer } else { '-' })",
      "APK path:       $path"
    )
    $full = $lines -join "`r`n"
    $script:adbErrorIsInfo = $true
    $script:adbErrorFull = $full
    $script:adbErrorBox.Text = $short
    $script:adbErrorBox.ForeColor = [System.Drawing.Color]::FromArgb(30, 110, 60)
    $script:adbTip.SetToolTip($script:adbErrorBox, $full)
    $script:adbErrorCopy.Enabled = $true
    if ($script:adbErrorView) { $script:adbErrorView.Enabled = $true }
    Update-AdbDisplay "Running app: $package. Its crashes will appear in this box." 'success'
  } catch {
    Update-AdbDisplay ('Could not read the running app: ' + $_.Exception.Message) 'error'
  } finally {
    $script:adbAppInfoButton.Enabled = $true
  }
}

# ----- Device screen: mirrors the phone's screen with jpi (scrcpy) -----
# The screen viewer (scrcpy, also used by D:\jpi as jpi.exe) is kept in its own
# folder so the screen always works, even without D:\jpi:
#   1. %LOCALAPPDATA%\IJTC\screen  (filled automatically the first time)
#   2. copied from D:\jpi when that folder exists
#   3. otherwise the official scrcpy for Windows is downloaded from GitHub once.
$screenFolder = Join-Path $env:LOCALAPPDATA 'IJTC\screen'

function Find-ScreenViewer {
  param([string]$Folder)
  foreach ($name in @('scrcpy.exe', 'jpi.exe')) {
    $path = Join-Path $Folder $name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      return $path
    }
  }
  return ''
}

function Get-ScreenMirrorPath {
  $viewer = Find-ScreenViewer $screenFolder
  if ($viewer) {
    return $viewer
  }
  if (Test-Path -LiteralPath 'D:\jpi\jpi.exe' -PathType Leaf) {
    try {
      New-Item -ItemType Directory -Path $screenFolder -Force | Out-Null
      Get-ChildItem -LiteralPath 'D:\jpi' -File | Where-Object { $_.Extension -in @('.exe', '.dll') -or $_.Name -eq 'jpi-server' } |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $screenFolder -Force }
      $viewer = Find-ScreenViewer $screenFolder
      if ($viewer) {
        return $viewer
      }
    } catch {
      return 'D:\jpi\jpi.exe'
    }
  }
  $command = Get-Command 'scrcpy.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($command) {
    return $command.Source
  }
  return ''
}

# Downloads the latest official scrcpy for Windows (64-bit) into the screen folder.
function Install-ScreenViewer {
  $zip = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-scrcpy-' + [Guid]::NewGuid().ToString('N') + '.zip')
  $extract = Join-Path ([IO.Path]::GetTempPath()) ('ijtc-scrcpy-' + [Guid]::NewGuid().ToString('N'))
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Update-AdbDisplay 'Finding the screen viewer (scrcpy) download...'
    [System.Windows.Forms.Application]::DoEvents()
    $release = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/Genymobile/scrcpy/releases/latest' -Headers @{ 'User-Agent' = 'IJTC-ComBox' }
    $asset = @($release.assets | Where-Object { $_.name -like 'scrcpy-win64-*.zip' } | Select-Object -First 1)
    if ($asset.Count -eq 0) {
      throw 'The scrcpy download for Windows was not found.'
    }
    $client = New-Object System.Net.WebClient
    $client.Headers.Add('User-Agent', 'IJTC-ComBox')
    try {
      $task = $client.DownloadFileTaskAsync($asset[0].browser_download_url, $zip)
      while (-not $task.IsCompleted) {
        $size = if (Test-Path -LiteralPath $zip) { (Get-Item -LiteralPath $zip).Length } else { 0 }
        Update-AdbDisplay ("Downloading the screen viewer $($release.tag_name) (first time only)... " + [Math]::Round($size / 1MB, 1) + ' MB')
        Wait-AdbUi 300
      }
      if ($task.IsFaulted) {
        throw ('Download failed: ' + $task.Exception.GetBaseException().Message)
      }
    } finally {
      $client.Dispose()
    }
    Update-AdbDisplay 'Installing the screen viewer...'
    [System.Windows.Forms.Application]::DoEvents()
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $extract)
    $exe = Get-ChildItem -LiteralPath $extract -Filter 'scrcpy.exe' -File -Recurse | Select-Object -First 1
    if (-not $exe) {
      throw 'scrcpy.exe was not found in the download.'
    }
    New-Item -ItemType Directory -Path $screenFolder -Force | Out-Null
    Get-ChildItem -LiteralPath $exe.DirectoryName -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $screenFolder -Force }
    return (Find-ScreenViewer $screenFolder)
  } finally {
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Start-AdbScreen {
  $serial = Get-AdbTargetSerial
  if (-not $serial) {
    Update-AdbDisplay 'No phone is connected. Connect with USB or Wireless first.' 'error'
    return
  }
  $mirror = Get-ScreenMirrorPath
  if (-not $mirror) {
    try {
      $script:adbBusy = $true
      $mirror = Install-ScreenViewer
    } catch {
      Update-AdbDisplay ('Could not get the screen viewer: ' + $_.Exception.Message) 'error'
      return
    } finally {
      $script:adbBusy = $false
    }
    if (-not $mirror) {
      Update-AdbDisplay 'The screen viewer could not be installed.' 'error'
      return
    }
  }
  $folder = Split-Path -Parent $mirror
  $title = (Format-AdbLastConnect (Read-AdbLastConnect)).Split('|')[0].Trim()
  if (-not $title -or $title -like 'No device*') { $title = $serial }
  try {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $mirror
    $startInfo.Arguments = '--serial ' + $serial + ' --stay-awake --window-title="' + $title.Replace('"', '') + '"'
    $startInfo.WorkingDirectory = $folder
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $server = Join-Path $folder 'jpi-server'
    if (Test-Path -LiteralPath $server -PathType Leaf) {
      $startInfo.EnvironmentVariables['SCRCPY_SERVER_PATH'] = $server
    }
    # Use the same adb as this tab so the two never restart each other's adb server.
    if ($script:adbPath) {
      $startInfo.EnvironmentVariables['ADB'] = $script:adbPath
    }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $script:adbScreen = [pscustomobject]@{
      Process = $process
      Output  = $process.StandardOutput.ReadToEndAsync()
      Errors  = $process.StandardError.ReadToEndAsync()
      Start   = Get-Date
    }
    Update-AdbDisplay "Opening the screen of $title..." 'success'
    $script:adbScreenTimer.Start()
  } catch {
    Update-AdbDisplay ('Could not open the device screen: ' + $_.Exception.Message) 'error'
  }
}

# Window with the full error text: scrollable, selectable and copyable.
function Show-AdbErrorWindow {
  if (-not $script:adbErrorFull) {
    Update-AdbDisplay 'There is no app error to show.'
    return
  }
  $window = New-Object System.Windows.Forms.Form
  $window.Text = $(if ($script:adbErrorIsInfo) { "App info - $($script:adbWatchPackage)" } else { "App error - $($script:adbWatchPackage)" })
  $window.StartPosition = 'CenterParent'
  $window.ShowInTaskbar = $false
  $window.MinimizeBox = $false
  $window.ClientSize = New-Object System.Drawing.Size(860, 460)
  $window.MinimumSize = New-Object System.Drawing.Size(500, 300)
  $window.BackColor = [System.Drawing.Color]::White
  $window.Font = New-Object System.Drawing.Font('Segoe UI', 9)

  $text = New-Object System.Windows.Forms.TextBox
  $text.Multiline = $true
  $text.ReadOnly = $true
  $text.WordWrap = $false
  $text.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
  $text.BackColor = [System.Drawing.Color]::White
  $text.ForeColor = $(if ($script:adbErrorIsInfo) { [System.Drawing.Color]::FromArgb(35, 35, 35) } else { [System.Drawing.Color]::FromArgb(150, 30, 30) })
  $text.Font = New-Object System.Drawing.Font('Consolas', 9.5)
  $text.Text = $script:adbErrorFull
  $text.Location = New-Object System.Drawing.Point(12, 12)
  $text.Size = New-Object System.Drawing.Size(836, 394)
  $text.Anchor = 'Top, Bottom, Left, Right'
  $window.Controls.Add($text)

  $copy = New-Object System.Windows.Forms.Button
  $copy.Text = 'Copy all'
  $copy.Location = New-Object System.Drawing.Point(668, 418)
  $copy.Size = New-Object System.Drawing.Size(88, 30)
  $copy.Anchor = 'Bottom, Right'
  $window.Controls.Add($copy)
  $close = New-Object System.Windows.Forms.Button
  $close.Text = 'Close'
  $close.Location = New-Object System.Drawing.Point(760, 418)
  $close.Size = New-Object System.Drawing.Size(88, 30)
  $close.Anchor = 'Bottom, Right'
  $close.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $window.Controls.Add($close)
  $window.CancelButton = $close
  $copy.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText($text.Text)
    $copy.Text = 'Copied'
  })
  $window.Add_Shown({ $text.SelectionStart = 0; $text.SelectionLength = 0 })
  try {
    [void]$window.ShowDialog()
  } finally {
    $window.Dispose()
  }
}

# Watches the app installed/started from this tab (or the project's app).
function Set-AdbWatchPackage {
  param([string]$Package)
  $script:adbWatchPackage = $Package
  $script:adbLastCrashText = ''
  Show-AdbAppError $null
}

function Complete-AdbCheckCore {
  param([string]$Output)
  $devices = @()
  foreach ($line in ($Output -split "`r?`n")) {
    if ($line -match '^(\S+)\s+device\b(.*)$') {
      $serial = $Matches[1]
      $details = $Matches[2]
      $model = if ($details -match 'model:(\S+)') { $Matches[1] -replace '_', ' ' } else { 'Android device' }
      $devices += [pscustomobject]@{ Serial = $serial; Model = $model }
    } elseif ($line -match '^(\S+)\s+unauthorized') {
      Update-AdbDisplay 'A device is connected but not authorized: allow USB debugging on the phone.' 'error'
      $script:adbConnectedSerial = ''
      return
    }
  }
  if ($devices.Count -eq 0) {
    $script:adbConnectedSerial = ''
    Update-AdbDisplay 'No device connected now.'
    return
  }
  $device = $devices[0]
  if ($device.Serial -ne $script:adbConnectedSerial) {
    $script:adbConnectedSerial = $device.Serial
    $brand = Invoke-AdbQuick ('-s ' + $device.Serial + ' shell getprop ro.product.manufacturer')
    $android = Invoke-AdbQuick ('-s ' + $device.Serial + ' shell getprop ro.build.version.release')
    $model = $device.Model
    if ($brand -and $model -notmatch [regex]::Escape($brand)) {
      $model = (Get-Culture).TextInfo.ToTitleCase($brand.ToLower()) + ' ' + $model
    }
    Save-AdbLastConnect ([pscustomobject]@{
      Model      = $model
      Android    = $android
      Serial     = $device.Serial
      Connection = $(if ($device.Serial -match ':\d+$') { 'Wi-Fi' } else { 'USB' })
      Time       = (Get-Date).ToString('dd-MMM-yyyy hh:mm tt')
    })
  }
  $more = if ($devices.Count -gt 1) { " (+$($devices.Count - 1) more)" } else { '' }
  Update-AdbDisplay ("Connected now: $($device.Model)$more") 'success'
}

function Initialize-AdbPanel {
  param($Panel)
  $script:adbPanel = $Panel
  $script:adbPath = Get-AdbPath
  $script:adbConnectedSerial = ''
  $script:adbCheck = $null

  $title = New-Object System.Windows.Forms.Label
  $title.Text = 'Last connect'
  $title.Location = New-Object System.Drawing.Point(24, 10)
  $title.Size = New-Object System.Drawing.Size(110, 22)
  $title.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
  $title.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $Panel.Controls.Add($title)

  $script:adbLastLabel = New-Object System.Windows.Forms.Label
  $script:adbLastLabel.Location = New-Object System.Drawing.Point(136, 10)
  $script:adbLastLabel.Size = New-Object System.Drawing.Size(700, 22)
  $script:adbLastLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10)
  $script:adbLastLabel.ForeColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
  $script:adbLastLabel.AutoEllipsis = $true
  $Panel.Controls.Add($script:adbLastLabel)

  $script:adbStateLabel = New-Object System.Windows.Forms.Label
  $script:adbStateLabel.Location = New-Object System.Drawing.Point(136, 36)
  $script:adbStateLabel.Size = New-Object System.Drawing.Size(700, 22)
  $script:adbStateLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $script:adbStateLabel.AutoEllipsis = $true
  $Panel.Controls.Add($script:adbStateLabel)

  $refresh = New-Object System.Windows.Forms.Button
  $refresh.Text = [string][char]0xE72C
  $refresh.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $refresh.Location = New-Object System.Drawing.Point(856, 10)
  $refresh.Size = New-Object System.Drawing.Size(32, 30)
  $refresh.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $refresh.Cursor = [System.Windows.Forms.Cursors]::Hand
  $tip = New-Object System.Windows.Forms.ToolTip
  $tip.SetToolTip($refresh, 'Check connected devices now')
  $Panel.Controls.Add($refresh)

  $script:adbTip = $tip
  $script:adbBusy = $false
  $bold = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

  $usbTitle = New-Object System.Windows.Forms.Label
  $usbTitle.Text = 'USB'
  $usbTitle.Location = New-Object System.Drawing.Point(24, 74)
  $usbTitle.Size = New-Object System.Drawing.Size(50, 22)
  $usbTitle.Font = $bold
  $usbTitle.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $Panel.Controls.Add($usbTitle)
  $script:adbUsbLabel = New-Object System.Windows.Forms.Label
  $script:adbUsbLabel.Location = New-Object System.Drawing.Point(76, 74)
  $script:adbUsbLabel.Size = New-Object System.Drawing.Size(250, 22)
  $script:adbUsbLabel.AutoEllipsis = $true
  $Panel.Controls.Add($script:adbUsbLabel)
  $script:adbToWirelessButton = New-Object System.Windows.Forms.Button
  $script:adbToWirelessButton.Text = [string][char]0xE701
  $script:adbToWirelessButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $script:adbToWirelessButton.Location = New-Object System.Drawing.Point(330, 69)
  $script:adbToWirelessButton.Size = New-Object System.Drawing.Size(32, 30)
  $script:adbToWirelessButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:adbToWirelessButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $tip.SetToolTip($script:adbToWirelessButton, 'USB to Wireless: switch the USB phone to wireless debugging (same Wi-Fi needed)')
  $Panel.Controls.Add($script:adbToWirelessButton)

  $wirelessTitle = New-Object System.Windows.Forms.Label
  $wirelessTitle.Text = 'Wireless'
  $wirelessTitle.Location = New-Object System.Drawing.Point(420, 74)
  $wirelessTitle.Size = New-Object System.Drawing.Size(76, 22)
  $wirelessTitle.Font = $bold
  $wirelessTitle.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $Panel.Controls.Add($wirelessTitle)
  $script:adbWirelessLabel = New-Object System.Windows.Forms.Label
  $script:adbWirelessLabel.Location = New-Object System.Drawing.Point(498, 74)
  $script:adbWirelessLabel.Size = New-Object System.Drawing.Size(300, 22)
  $script:adbWirelessLabel.AutoEllipsis = $true
  $Panel.Controls.Add($script:adbWirelessLabel)
  $script:adbWirelessButton = New-Object System.Windows.Forms.Button
  $script:adbWirelessButton.Text = [string][char]0xE71B
  $script:adbWirelessButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $script:adbWirelessButton.Location = New-Object System.Drawing.Point(804, 69)
  $script:adbWirelessButton.Size = New-Object System.Drawing.Size(32, 30)
  $script:adbWirelessButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:adbWirelessButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $Panel.Controls.Add($script:adbWirelessButton)

  $apkTitle = New-Object System.Windows.Forms.Label
  $apkTitle.Text = 'APK'
  $apkTitle.Location = New-Object System.Drawing.Point(24, 114)
  $apkTitle.Size = New-Object System.Drawing.Size(50, 22)
  $apkTitle.Font = $bold
  $apkTitle.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  $Panel.Controls.Add($apkTitle)
  $script:adbApkBox = New-Object System.Windows.Forms.TextBox
  $script:adbApkBox.Location = New-Object System.Drawing.Point(76, 111)
  $script:adbApkBox.Size = New-Object System.Drawing.Size(246, 26)
  $script:adbApkBox.AllowDrop = $true
  $tip.SetToolTip($script:adbApkBox, 'APK link (https://...) or file path - you can also drop an .apk file here')
  $Panel.Controls.Add($script:adbApkBox)
  $script:adbApkButton = New-Object System.Windows.Forms.Button
  $script:adbApkButton.Text = [string][char]0xE896
  $script:adbApkButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $script:adbApkButton.Location = New-Object System.Drawing.Point(368, 109)
  $script:adbApkButton.Size = New-Object System.Drawing.Size(32, 30)
  $script:adbApkButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:adbApkButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $tip.SetToolTip($script:adbApkButton, 'Install this APK on the connected phone (adb install)')
  $Panel.Controls.Add($script:adbApkButton)
  $script:adbApkButton.Add_Click({ Install-AdbApk })
  $browse = New-Object System.Windows.Forms.Button
  $browse.Text = [string][char]0xE8E5
  $browse.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $browse.Location = New-Object System.Drawing.Point(330, 109)
  $browse.Size = New-Object System.Drawing.Size(32, 30)
  $browse.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $browse.Cursor = [System.Windows.Forms.Cursors]::Hand
  $tip.SetToolTip($browse, 'Find an APK file on this PC')
  $Panel.Controls.Add($browse)
  $findApk = New-Object System.Windows.Forms.Button
  $findApk.Text = [string][char]0xE721
  $findApk.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $findApk.Location = New-Object System.Drawing.Point(406, 109)
  $findApk.Size = New-Object System.Drawing.Size(32, 30)
  $findApk.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $findApk.Cursor = [System.Windows.Forms.Cursors]::Hand
  $tip.SetToolTip($findApk, 'Find .apk files in the Android project folder above and install one')
  $Panel.Controls.Add($findApk)
  $findApk.Add_Click({ Select-ProjectApk })
  $browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    try {
      $dialog.Title = 'Choose the APK to install'
      $dialog.Filter = 'Android app (*.apk)|*.apk|All files (*.*)|*.*'
      $current = $script:adbApkBox.Text.Trim().Trim('"')
      $start = ''
      if ($current -and (Test-Path -LiteralPath $current -PathType Container)) {
        $start = $current
      } elseif ($current -and (Test-Path -LiteralPath $current -PathType Leaf)) {
        $start = Split-Path -Parent $current
      } else {
        foreach ($candidate in @((Join-Path $ProjectRoot 'app\build\outputs\apk\debug'), $ProjectRoot)) {
          if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) {
            $start = $candidate
            break
          }
        }
      }
      if ($start) {
        $dialog.InitialDirectory = $start
      }
      if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:adbApkBox.Text = $dialog.FileName
      }
    } finally {
      $dialog.Dispose()
    }
  })
  $script:adbApkBox.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
      $eventArgs.SuppressKeyPress = $true
      Install-AdbApk
    }
  })
  $script:adbApkBox.Add_DragEnter({
    param($sender, $eventArgs)
    if ($eventArgs.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
      $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    }
  })
  $script:adbApkBox.Add_DragDrop({
    param($sender, $eventArgs)
    $files = $eventArgs.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    if ($files -and $files.Count -gt 0) {
      $script:adbApkBox.Text = [string]$files[0]
    }
  })

  # Install failure reason (under the APK box) with a copy button on its right.
  $script:adbInstallErrorLabel = New-Object System.Windows.Forms.Label
  $script:adbInstallErrorLabel.Location = New-Object System.Drawing.Point(76, 147)
  $script:adbInstallErrorLabel.Size = New-Object System.Drawing.Size(324, 22)
  $script:adbInstallErrorLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $script:adbInstallErrorLabel.ForeColor = [System.Drawing.Color]::Firebrick
  $script:adbInstallErrorLabel.AutoEllipsis = $true
  $script:adbInstallErrorLabel.Visible = $false
  $Panel.Controls.Add($script:adbInstallErrorLabel)
  $script:adbInstallErrorCopy = New-Object System.Windows.Forms.Button
  $script:adbInstallErrorCopy.Text = [string][char]0xE8C8
  $script:adbInstallErrorCopy.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $script:adbInstallErrorCopy.Location = New-Object System.Drawing.Point(406, 143)
  $script:adbInstallErrorCopy.Size = New-Object System.Drawing.Size(32, 30)
  $script:adbInstallErrorCopy.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:adbInstallErrorCopy.Cursor = [System.Windows.Forms.Cursors]::Hand
  $script:adbInstallErrorCopy.Visible = $false
  $tip.SetToolTip($script:adbInstallErrorCopy, 'Copy the install error')
  $Panel.Controls.Add($script:adbInstallErrorCopy)
  $script:adbInstallErrorCopy.Add_Click({
    if ($script:adbInstallErrorFull) {
      [System.Windows.Forms.Clipboard]::SetText($script:adbInstallErrorFull)
      Update-AdbDisplay 'Install error copied to the clipboard.' 'success'
    }
  })
  $script:adbInstallErrorFull = ''
  $script:adbInstallOutput = ''

  $script:adbErrorBox = New-Object System.Windows.Forms.TextBox
  $script:adbErrorBox.Location = New-Object System.Drawing.Point(450, 111)
  $script:adbErrorBox.Size = New-Object System.Drawing.Size(316, 26)
  $script:adbErrorBox.ReadOnly = $true
  $script:adbErrorBox.BackColor = [System.Drawing.Color]::White
  $Panel.Controls.Add($script:adbErrorBox)
  $script:adbAppInfoButton = New-Object System.Windows.Forms.Button
  $script:adbAppInfoButton.Text = [string][char]0xE72C
  $script:adbAppInfoButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $script:adbAppInfoButton.Location = New-Object System.Drawing.Point(772, 109)
  $script:adbAppInfoButton.Size = New-Object System.Drawing.Size(32, 30)
  $script:adbAppInfoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:adbAppInfoButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $tip.SetToolTip($script:adbAppInfoButton, 'Show the app running on the phone now (and watch it for errors)')
  $Panel.Controls.Add($script:adbAppInfoButton)
  $script:adbAppInfoButton.Add_Click({ Show-AdbRunningApp })
  $script:adbErrorCopy = New-Object System.Windows.Forms.Button
  $script:adbErrorCopy.Text = [string][char]0xE8C8
  $script:adbErrorCopy.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $script:adbErrorCopy.Location = New-Object System.Drawing.Point(810, 109)
  $script:adbErrorCopy.Size = New-Object System.Drawing.Size(32, 30)
  $script:adbErrorCopy.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:adbErrorCopy.Cursor = [System.Windows.Forms.Cursors]::Hand
  $tip.SetToolTip($script:adbErrorCopy, 'Copy the full error (stack trace)')
  $Panel.Controls.Add($script:adbErrorCopy)
  $script:adbErrorCopy.Add_Click({
    if ($script:adbErrorFull) {
      [System.Windows.Forms.Clipboard]::SetText($script:adbErrorFull)
      Update-AdbDisplay $(if ($script:adbErrorIsInfo) { 'App info copied to the clipboard.' } else { 'App error copied to the clipboard.' }) 'success'
    }
  })
  $script:adbErrorView = New-Object System.Windows.Forms.Button
  $script:adbErrorView.Text = [string][char]0xE8A7
  $script:adbErrorView.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $script:adbErrorView.Location = New-Object System.Drawing.Point(848, 109)
  $script:adbErrorView.Size = New-Object System.Drawing.Size(32, 30)
  $script:adbErrorView.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:adbErrorView.Cursor = [System.Windows.Forms.Cursors]::Hand
  $tip.SetToolTip($script:adbErrorView, 'Show the full error')
  $Panel.Controls.Add($script:adbErrorView)
  $script:adbErrorView.Add_Click({ Show-AdbErrorWindow })
  $script:adbErrorFull = ''
  $projectApkPackage = Get-ApkPackageName (Join-Path $ProjectRoot 'app\build\outputs\apk\debug\app-debug.apk')
  Set-AdbWatchPackage $projectApkPackage

  # Reads the phone's crash log every 4 seconds while the tab is visible.
  $script:adbCrashCheck = $null
  $script:adbCrashTimer = New-Object System.Windows.Forms.Timer
  $script:adbCrashTimer.Interval = 4000
  $script:adbCrashTimer.Add_Tick({
    if ($script:adbPanel.IsDisposed) {
      $script:adbCrashTimer.Stop()
      $script:adbCrashTimer.Dispose()
      return
    }
    if ($script:adbCrashCheck) {
      if (-not $script:adbCrashCheck.Process.HasExited) {
        return
      }
      $output = [string]$script:adbCrashCheck.Output.Result
      $script:adbCrashCheck.Process.Dispose()
      $script:adbCrashCheck = $null
      if ($script:adbWatchPackage) {
        $crash = Get-AdbLastCrash $output $script:adbWatchPackage
        if ($crash -and $crash.Full -ne $script:adbLastCrashText) {
          $script:adbLastCrashText = $crash.Full
          Show-AdbAppError $crash
        }
      }
      return
    }
    $serial = Get-AdbTargetSerial
    if ($script:adbPanel.Visible -and -not $script:adbBusy -and $serial -and $script:adbWatchPackage) {
      try {
        $script:adbCrashCheck = Start-AdbProcess ('-s ' + $serial + ' logcat -b crash -d')
      } catch {
      }
    }
  })
  if ($script:adbPath) {
    $script:adbCrashTimer.Start()
  }

  $script:adbScreenButton = New-Object System.Windows.Forms.Button
  $script:adbScreenButton.Text = [string][char]0xE8EA
  $script:adbScreenButton.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 11)
  $script:adbScreenButton.Location = New-Object System.Drawing.Point(848, 69)
  $script:adbScreenButton.Size = New-Object System.Drawing.Size(32, 30)
  $script:adbScreenButton.FlatStyle = [System.Windows.Forms.FlatStyle]::System
  $script:adbScreenButton.Cursor = [System.Windows.Forms.Cursors]::Hand
  $tip.SetToolTip($script:adbScreenButton, 'Show the connected phone''s screen (control it with mouse and keyboard)')
  $Panel.Controls.Add($script:adbScreenButton)
  $script:adbScreenButton.Add_Click({ Start-AdbScreen })
  $script:adbScreen = $null
  # Reports a screen viewer that closed by itself within a few seconds (an error).
  $script:adbScreenTimer = New-Object System.Windows.Forms.Timer
  $script:adbScreenTimer.Interval = 1000
  $script:adbScreenTimer.Add_Tick({
    $screen = $script:adbScreen
    if (-not $screen) {
      $script:adbScreenTimer.Stop()
      return
    }
    if (-not $screen.Process.HasExited) {
      if (((Get-Date) - $screen.Start).TotalSeconds -gt 8) {
        $script:adbScreenTimer.Stop()
        $script:adbScreen = $null
      }
      return
    }
    $script:adbScreenTimer.Stop()
    $script:adbScreen = $null
    if ($screen.Process.ExitCode -ne 0 -and ((Get-Date) - $screen.Start).TotalSeconds -le 8) {
      $text = (([string]$screen.Output.Result) + "`n" + ([string]$screen.Errors.Result))
      $last = @($text -split "`r?`n" | Where-Object { $_ -match 'ERROR' -or $_.Trim() } | Select-Object -Last 1)
      Update-AdbDisplay ('Device screen closed: ' + $(if ($last.Count) { $last[0].Trim() } else { "exit code $($screen.Process.ExitCode)" })) 'error'
    }
  })

  $script:adbToWirelessButton.Add_Click({ Switch-AdbToWireless })
  $script:adbWirelessButton.Add_Click({ Switch-AdbWireless })
  $script:adbLastOutput = ''
  Update-AdbConnectionRow

  if (-not $script:adbPath) {
    Update-AdbDisplay 'adb.exe was not found. Install Android SDK platform-tools (Android Studio).' 'error'
    $script:adbToWirelessButton.Enabled = $false
    $script:adbWirelessButton.Enabled = $false
    return
  }
  Update-AdbDisplay 'Checking connected devices...'

  # Checks "adb devices -l" every 3 seconds while the tab is visible, without freezing the window.
  $script:adbTimer = New-Object System.Windows.Forms.Timer
  $script:adbTimer.Interval = 3000
  $script:adbTimer.Add_Tick({
    if ($script:adbPanel.IsDisposed) {
      $script:adbTimer.Stop()
      $script:adbTimer.Dispose()
      return
    }
    if ($script:adbBusy) {
      return
    }
    if ($script:adbCheck) {
      if (-not $script:adbCheck.Process.HasExited) {
        return
      }
      $output = [string]$script:adbCheck.Output.Result
      $script:adbCheck.Process.Dispose()
      $script:adbCheck = $null
      $script:adbTimer.Interval = 3000
      Complete-AdbCheck $output
      return
    }
    if ($script:adbPanel.Visible) {
      try {
        $script:adbCheck = Start-AdbProcess 'devices -l'
        $script:adbTimer.Interval = 500
      } catch {
        Update-AdbDisplay ('Could not run adb: ' + $_.Exception.Message) 'error'
      }
    }
    if (-not $script:adbCheck) {
      $script:adbTimer.Interval = 3000
    }
  })
  $refresh.Add_Click({
    if (-not $script:adbCheck) {
      $script:adbConnectedSerial = ''
      $script:adbCheck = Start-AdbProcess 'devices -l'
      $script:adbTimer.Interval = 500
    }
  })
  $script:adbCheck = Start-AdbProcess 'devices -l'
  $script:adbTimer.Interval = 500
  $script:adbTimer.Start()
}

if ($HostPanel) {
  Initialize-AdbPanel $HostPanel
  return
}
'@
$script:adbDirectory = $projectDirectory
$script:adbLoaded = $false
$adbPanel = New-FormSectionPanel 'adb'
$adbHost = New-Object System.Windows.Forms.Panel
$adbHost.Location = New-Object System.Drawing.Point(1, 34)
$adbHost.Size = New-Object System.Drawing.Size(($adbPanel.Width - 2), ($adbPanel.Height - 35))
$adbHost.BackColor = [System.Drawing.Color]::White
$adbPanel.Controls.Add($adbHost)

function Import-AdbTab {
  $script:adbLoaded = $true
  foreach ($control in @($adbHost.Controls)) {
    $adbHost.Controls.Remove($control)
    $control.Dispose()
  }
  try {
    $scriptBlock = [scriptblock]::Create($adbScriptSource)
    $null = New-Module -Name ('IjtcAdb' + [Guid]::NewGuid().ToString('N')) -ScriptBlock $scriptBlock -ArgumentList $adbHost, $script:adbDirectory
  } catch {
    $errorLabel = New-Object System.Windows.Forms.Label
    $errorLabel.Text = "Could not load the ADB tab: $($_.Exception.Message)"
    $errorLabel.Location = New-Object System.Drawing.Point(13, 10)
    $errorLabel.Size = New-Object System.Drawing.Size(880, 60)
    $errorLabel.ForeColor = [System.Drawing.Color]::Firebrick
    $adbHost.Controls.Add($errorLabel)
  }
}

# ---------------------------------------------------------------------------
# Folder bar: every section shows the folder it works in, with buttons to
# change it, open it in File Explorer, or go back to the default folder.
# Moves all tabs below the tab bar and folder bar (Form.bat).
. $FormParts.Bars

# The Rename section's own folder row is replaced by the folder bar.
foreach ($control in @($renamePanel.Controls)) {
  if ($control -eq $renameFolderBox -or $control -eq $renameBrowseButton -or ($control -is [System.Windows.Forms.Label] -and $control.Text -eq 'Folder')) {
    $control.Visible = $false
  } elseif ($control.Top -ge 80) {
    $control.Top -= 44
  }
}
$renamePanel.Height -= 44
$renameStatusLabel.Top -= 44
$renameSectionHeight -= 44

# ----- Rename tab: search the folder (file names and text inside files) -----
# A row under the folder bar: type, press Enter or the search button; results show
# in a list under the box. Click a result to open the file (VS Code at the line, else Notepad).
$renameSearchRowTop = $renamePanel.Top
$renamePanel.Top += 40
$renameStatusLabel.Top += 40
$renameSectionHeight += 40
$renameSearchLabel = New-Label 'Search' 37 ($renameSearchRowTop + 3) 140 22
$renameSearchLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$renameSearchLabel.ForeColor = Get-FormColor $FormLayout.AccentColor
$renameSearchBox = New-Object System.Windows.Forms.TextBox
$renameSearchBox.Location = New-Object System.Drawing.Point(180, $renameSearchRowTop)
$renameSearchBox.Size = New-Object System.Drawing.Size(($FormLayout.Width - 370 - 42), 26)
$renameSearchBox.Tag = 'noUndo'
$form.Controls.Add($renameSearchBox)
$toolTip.SetToolTip($renameSearchBox, 'Text to find in the folder above: file and folder names, and text inside files. Enter = search, Esc = close the list.')
$renameSearchButton = New-ActionButton 'Search the folder for this text' 0xE721 (180 + $FormLayout.Width - 370 - 32) ($renameSearchRowTop - 2)
$renameSearchRefreshButton = New-ActionButton 'Search again (refresh the results)' 0xE72C (180 + $FormLayout.Width - 370 + 6) ($renameSearchRowTop - 2)

$renameSearchDropDown = New-Object System.Windows.Forms.Panel
$renameSearchDropDown.Location = New-Object System.Drawing.Point(180, ($renameSearchRowTop + 30))
$renameSearchDropDown.Size = New-Object System.Drawing.Size(($FormLayout.Width - 218), 300)
$renameSearchDropDown.BackColor = [System.Drawing.Color]::White
$renameSearchDropDown.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$renameSearchDropDown.Visible = $false
$form.Controls.Add($renameSearchDropDown)
$renameSearchClose = New-Object System.Windows.Forms.Button
$renameSearchClose.Text = [string][char]0xE711
$renameSearchClose.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 9)
$renameSearchClose.Size = New-Object System.Drawing.Size(30, 24)
$renameSearchClose.Location = New-Object System.Drawing.Point(($renameSearchDropDown.Width - 38), 3)
$renameSearchClose.FlatStyle = [System.Windows.Forms.FlatStyle]::System
$renameSearchDropDown.Controls.Add($renameSearchClose)
$toolTip.SetToolTip($renameSearchClose, 'Close the list')
$renameSearchListRefresh = New-Object System.Windows.Forms.Button
$renameSearchListRefresh.Text = [string][char]0xE72C
$renameSearchListRefresh.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 9)
$renameSearchListRefresh.Size = New-Object System.Drawing.Size(30, 24)
$renameSearchListRefresh.Location = New-Object System.Drawing.Point(($renameSearchDropDown.Width - 74), 3)
$renameSearchListRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::System
$renameSearchDropDown.Controls.Add($renameSearchListRefresh)
$toolTip.SetToolTip($renameSearchListRefresh, 'Search again (refresh the results)')
$renameSearchInfo = New-Object System.Windows.Forms.Label
$renameSearchInfo.Location = New-Object System.Drawing.Point(8, 6)
$renameSearchInfo.Size = New-Object System.Drawing.Size(($renameSearchDropDown.Width - 88), 20)
$renameSearchInfo.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
$renameSearchInfo.AutoEllipsis = $true
$renameSearchDropDown.Controls.Add($renameSearchInfo)
$renameSearchList = New-Object System.Windows.Forms.ListView
$renameSearchList.Location = New-Object System.Drawing.Point(6, 30)
$renameSearchList.Size = New-Object System.Drawing.Size(($renameSearchDropDown.Width - 14), ($renameSearchDropDown.Height - 38))
$renameSearchList.View = [System.Windows.Forms.View]::Details
$renameSearchList.FullRowSelect = $true
$renameSearchList.MultiSelect = $false
$renameSearchList.HideSelection = $false
$renameSearchList.ShowItemToolTips = $true
$renameSearchList.Font = New-Object System.Drawing.Font('Segoe UI', 9)
[void]$renameSearchList.Columns.Add('File', 300)
[void]$renameSearchList.Columns.Add('Line', 50)
[void]$renameSearchList.Columns.Add('Text', 560)
$renameSearchDropDown.Controls.Add($renameSearchList)

# Fits the result list between the search box and the bottom of the window.
function Show-RenameSearchList {
  $height = [Math]::Max(140, $form.ClientSize.Height - $renameSearchDropDown.Top - 8)
  $renameSearchDropDown.Height = $height
  $renameSearchList.Height = $height - 38
  $renameSearchDropDown.Visible = $true
  $renameSearchDropDown.BringToFront()
}

function Hide-RenameSearch {
  $renameSearchDropDown.Visible = $false
}

# Folders skipped while searching (tools, builds, downloaded packages).
$renameSearchSkipDirs = @('.git', 'node_modules', '.wrangler', '.gradle', '.idea', '.vs', 'bin', 'obj', 'build', 'dist', '.next', '.cache')
$renameSearchSkipExt = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.bmp', '.pdf', '.zip', '.7z', '.rar', '.apk', '.aab', '.jar', '.exe', '.dll', '.so', '.class', '.keystore', '.jks', '.mp3', '.mp4', '.wav', '.ttf', '.otf', '.woff', '.woff2', '.db', '.sqlite')

function Invoke-RenameSearch {
  $text = $renameSearchBox.Text
  $folder = [string]$script:sectionFolders['rename']
  if ([string]::IsNullOrWhiteSpace($text)) {
    Set-RenameStatus 'Type the text to search for.' 'error'
    return
  }
  if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
    Set-RenameStatus "Folder not found: $folder" 'error'
    return
  }
  $folder = $folder.TrimEnd('\')
  $limit = 1000
  $renameSearchButton.Enabled = $false
  $renameSearchRefreshButton.Enabled = $false
  $renameSearchList.BeginUpdate()
  $renameSearchList.Items.Clear()
  $count = 0
  $files = 0
  try {
    Set-RenameStatus "Searching $folder for '$text'..." 'busy'
    $renameSearchInfo.Text = 'Searching...'
    Show-RenameSearchList
    [System.Windows.Forms.Application]::DoEvents()
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($folder)
    while ($stack.Count -gt 0 -and $count -lt $limit) {
      $dir = $stack.Pop()
      $entries = @()
      try { $entries = @([System.IO.Directory]::GetFileSystemEntries($dir)) } catch { continue }
      [array]::Sort($entries)
      $subDirs = New-Object System.Collections.Generic.List[string]
      foreach ($entry in $entries) {
        if ($count -ge $limit) { break }
        $name = [System.IO.Path]::GetFileName($entry)
        $relative = $entry.Substring($folder.Length).TrimStart('\')
        $isDir = [System.IO.Directory]::Exists($entry)
        if ($name.IndexOf($text, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
          $item = New-Object System.Windows.Forms.ListViewItem $relative
          [void]$item.SubItems.Add('')
          [void]$item.SubItems.Add($(if ($isDir) { '(folder name)' } else { '(file name)' }))
          $item.Tag = @{ Path = $entry; Line = 0 }
          $item.ToolTipText = $entry
          [void]$renameSearchList.Items.Add($item)
          $count++
        }
        if ($isDir) {
          if ($renameSearchSkipDirs -notcontains $name.ToLowerInvariant()) { $subDirs.Add($entry) }
          continue
        }
        if ($renameSearchSkipExt -contains [System.IO.Path]::GetExtension($name).ToLowerInvariant()) { continue }
        try { if ((New-Object System.IO.FileInfo $entry).Length -gt 5MB) { continue } } catch { continue }
        $files++
        if ($files % 40 -eq 0) {
          $renameSearchInfo.Text = "Searching... $files files, $count found"
          [System.Windows.Forms.Application]::DoEvents()
        }
        $lines = $null
        try { $lines = [System.IO.File]::ReadAllLines($entry) } catch { continue }
        if ($lines.Count -gt 0 -and $lines[0].IndexOf([char]0) -ge 0) { continue }
        for ($i = 0; $i -lt $lines.Count -and $count -lt $limit; $i++) {
          if ($lines[$i].IndexOf($text, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $line = $lines[$i].Trim()
            if ($line.Length -gt 300) {
              $at = [Math]::Max(0, $line.IndexOf($text, [StringComparison]::OrdinalIgnoreCase) - 80)
              $line = '...' + $line.Substring($at, [Math]::Min(300, $line.Length - $at))
            }
            $item = New-Object System.Windows.Forms.ListViewItem $relative
            [void]$item.SubItems.Add([string]($i + 1))
            [void]$item.SubItems.Add($line)
            $item.Tag = @{ Path = $entry; Line = $i + 1 }
            $item.ToolTipText = $lines[$i].Trim()
            [void]$renameSearchList.Items.Add($item)
            $count++
          }
        }
      }
      for ($j = $subDirs.Count - 1; $j -ge 0; $j--) { $stack.Push($subDirs[$j]) }
    }
  } finally {
    $renameSearchList.EndUpdate()
    $renameSearchButton.Enabled = $true
    $renameSearchRefreshButton.Enabled = $true
  }
  $more = if ($count -ge $limit) { " (first $limit shown)" } else { '' }
  $summary = "$count found for '$text' in $files files$more. Click one to open it."
  $renameSearchInfo.Text = $summary
  Set-RenameStatus $summary $(if ($count -gt 0) { 'success' } else { 'info' })
  Show-RenameSearchList
}

function Open-RenameSearchResult {
  if ($renameSearchList.SelectedItems.Count -eq 0) { return }
  $info = $renameSearchList.SelectedItems[0].Tag
  try {
    if ([System.IO.Directory]::Exists($info.Path)) {
      Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $info.Path + '"')
      return
    }
    $code = Get-Command code.cmd -ErrorAction SilentlyContinue
    if ($code) {
      $target = if ($info.Line -gt 0) { $info.Path + ':' + $info.Line } else { $info.Path }
      Start-NoWindowProcess $code.Source ('-g "' + $target + '"') | Out-Null
    } else {
      Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $info.Path + '"')
    }
  } catch {
    Set-RenameStatus $_.Exception.Message 'error'
  }
}

$renameSearchButton.Add_Click({
  if ($renameSearchDropDown.Visible -and -not $renameSearchBox.Focused) { Hide-RenameSearch } else { Invoke-RenameSearch }
})
$renameSearchBox.Add_KeyDown({
  param($sender, $eventArgs)
  if ($eventArgs.KeyCode -eq 'Enter') { $eventArgs.SuppressKeyPress = $true; Invoke-RenameSearch }
  elseif ($eventArgs.KeyCode -eq 'Escape') { $eventArgs.SuppressKeyPress = $true; Hide-RenameSearch }
  elseif ($eventArgs.KeyCode -eq 'Down' -and $renameSearchDropDown.Visible -and $renameSearchList.Items.Count -gt 0) {
    $eventArgs.SuppressKeyPress = $true
    $renameSearchList.Focus()
    if ($renameSearchList.SelectedItems.Count -eq 0) { $renameSearchList.Items[0].Selected = $true }
  }
})
$renameSearchList.Add_MouseClick({ Open-RenameSearchResult })
$renameSearchList.Add_KeyDown({
  param($sender, $eventArgs)
  if ($eventArgs.KeyCode -eq 'Enter') { $eventArgs.SuppressKeyPress = $true; Open-RenameSearchResult }
  elseif ($eventArgs.KeyCode -eq 'Escape') { $eventArgs.SuppressKeyPress = $true; Hide-RenameSearch }
})
$renameSearchClose.Add_Click({ Hide-RenameSearch })
$renameSearchRefreshButton.Add_Click({ Invoke-RenameSearch })
$renameSearchListRefresh.Add_Click({ Invoke-RenameSearch })

$sectionFolderFile = Join-Path $repositorySettingsDirectory 'section-folders.txt'
# Folder bar labels, tooltips and default folders: Form.bat ($FormLayout.Folders)
$sectionFolderInfo = Get-FormFolderInfo

function Read-SectionFolders {
  $folders = @{}
  foreach ($key in $sectionFolderInfo.Keys) {
    $folders[$key] = $sectionFolderInfo[$key].Default
  }
  try {
    if (Test-Path -LiteralPath $sectionFolderFile -PathType Leaf) {
      foreach ($line in [System.IO.File]::ReadAllLines($sectionFolderFile)) {
        $separator = $line.IndexOf('=')
        if ($separator -le 0) {
          continue
        }
        $key = $line.Substring(0, $separator).Trim()
        $path = $line.Substring($separator + 1).Trim()
        if ($folders.ContainsKey($key) -and $path -and (Test-Path -LiteralPath $path -PathType Container)) {
          $folders[$key] = $path
        }
      }
    }
  } catch {
  }
  return $folders
}

function Save-SectionFolders {
  if (-not (Test-Path -LiteralPath $repositorySettingsDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $repositorySettingsDirectory -Force | Out-Null
  }
  $lines = foreach ($key in $sectionFolderInfo.Keys) {
    "$key=$($script:sectionFolders[$key])"
  }
  [System.IO.File]::WriteAllLines($sectionFolderFile, [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))
}

function Apply-SectionFolders {
  $script:githubDirectory = $script:sectionFolders['home']
  if ($relationFolderBox) {
    $relationFolderBox.Text = [string]$script:sectionFolders['relation']
  }
  # The Cloudflare tab has no folder bar: it deploys Home's folder.
  $script:cloudflareDirectory = $script:sectionFolders['cloudflare']
  if ($script:sectionFolders['home'] -and (Test-Path -LiteralPath (Join-Path $script:sectionFolders['home'] 'wrangler.jsonc') -PathType Leaf)) {
    $script:cloudflareDirectory = $script:sectionFolders['home']
  }
  $renameFolderBox.Text = $script:sectionFolders['rename']
  $script:runLocalDirectory = $script:sectionFolders['runlocal']
  $script:adbDirectory = $script:sectionFolders['adb']
}

$script:sectionFolders = Read-SectionFolders
Apply-SectionFolders

# Folder bar controls and Update-FolderBar: Form.bat
. $FormParts.FolderBar

# Show-SectionMessage: Form.bat

function Test-SectionBusy {
  param([string]$Key)
  if ($Key -eq 'cloudflare') { return (Test-CloudflareBusy) }
  if ($Key -eq 'rename') { return [bool]$script:renameJob }
  if ($Key -eq 'runlocal') { return [bool]$script:runLocalStarting }
  return $false
}

function Set-SectionFolder {
  param([string]$Key, [string]$Path)
  if (Test-SectionBusy $Key) {
    Show-SectionMessage 'Wait for the current operation to finish before changing the folder.' $true
    return
  }
  $previousFolder = [string]$script:sectionFolders[$Key]
  try {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
      throw "Folder not found: $fullPath"
    }
    $script:sectionFolders[$Key] = $fullPath
    Save-SectionFolders
  } catch {
    Show-SectionMessage $_.Exception.Message $true
    return
  }
  Apply-SectionFolders
  Update-FolderBar
  if ($Key -eq 'runlocal' -and $script:runLocalFilesExpanded) {
    Update-RunLocalFilesList
  }
  if ($previousFolder -and $previousFolder -ne $fullPath -and (Get-Command Add-UndoAction -ErrorAction SilentlyContinue)) {
    Add-UndoAction 'folder' $sectionFolderInfo[$Key].Label.TrimEnd(' ', ':') @{ Key = $Key; Old = $previousFolder; New = $fullPath }
  }

  $warning = ''
  switch ($Key) {
    'github' {
      if (-not (Test-Path -LiteralPath (Join-Path $fullPath '.git') -PathType Container)) {
        $warning = ' Warning: this folder is not a Git repository.'
      }
    }
    'cloudflare' {
      if (-not (Test-Path -LiteralPath (Join-Path $fullPath 'wrangler.jsonc') -PathType Leaf)) {
        $warning = ' Warning: wrangler.jsonc was not found in this folder.'
      }
    }
    'runlocal' {
      $hasNextExport = Test-Path -LiteralPath (Join-Path $fullPath 'out\index.html') -PathType Leaf
      $hasPublicFrontend = Test-Path -LiteralPath (Join-Path $fullPath 'public\index.html') -PathType Leaf
      if (-not $hasNextExport -and -not $hasPublicFrontend) {
        $warning = ' out\index.html and public\index.html not found; run npm run build for a Next.js project. Otherwise requests will be forwarded to local Odoo at http://127.0.0.1:8069.'
      } elseif (-not $hasNextExport -and -not (Test-Path -LiteralPath (Join-Path $fullPath 'api') -PathType Container)) {
        $warning = ' API folder not found; local API routes are disabled.'
      }
    }
  }
  if ($Key -eq 'adb') {
    Import-AdbTab
  }
  if ($Key -eq 'runlocal') {
    $script:runLocalNetworkLoaded = $false
    $script:runLocalLastState = ''
    Update-RunLocalState
  }
  Show-SectionMessage ("$($sectionFolderInfo[$Key].Label) changed: $fullPath." + $warning) ([bool]$warning)
}

$folderChangeButton.Add_Click({
  $key = $script:currentSection
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  try {
    $dialog.Description = "Choose the $($sectionFolderInfo[$key].Label.ToLower()) ($($sectionFolderInfo[$key].Hint))"
    $dialog.ShowNewFolderButton = $true
    if (Test-Path -LiteralPath $script:sectionFolders[$key] -PathType Container) {
      $dialog.SelectedPath = $script:sectionFolders[$key]
    }
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
      Set-SectionFolder $key $dialog.SelectedPath
    }
  } finally {
    $dialog.Dispose()
  }
})

$folderOpenButton.Add_Click({
  $folder = $script:sectionFolders[$script:currentSection]
  try {
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
      throw "Folder not found: $folder"
    }
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $folder + '"') -ErrorAction Stop | Out-Null
  } catch {
    Show-SectionMessage $_.Exception.Message $true
  }
})

$cloudflareSectionItems = @(
  @($deployPanel, $secretPanel, $webpagePanel, $cloudflareStatusLabel) | ForEach-Object {
    [pscustomobject]@{ Control = $_; Top = $_.Top }
  }
)

# Tab bar (order, icons, names, logos): Form.bat ($FormLayout.Tabs)
. $FormParts.Tabs

function Get-RelationGraphData {
  param([string]$Root)
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Project folder not found: $Root"
  }
  $rootPath = [IO.Path]::GetFullPath($Root)
  $pathRoot = [IO.Path]::GetPathRoot($rootPath)
  if ($rootPath.Length -gt $pathRoot.Length) {
    $rootPath = $rootPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  }
  $rootPrefix = $rootPath
  if (-not $rootPrefix.EndsWith([string][IO.Path]::DirectorySeparatorChar)) {
    $rootPrefix += [IO.Path]::DirectorySeparatorChar
  }
  $workerPath = Join-Path $rootPath 'worker.js'
  if (-not (Test-Path -LiteralPath $workerPath -PathType Leaf)) {
    throw "worker.js was not found in: $rootPath"
  }

  $nodes = @{}
  $edges = New-Object 'System.Collections.Generic.List[object]'
  $queue = New-Object 'System.Collections.Generic.Queue[object]'
  $workerRelative = 'worker.js'
  $nodes[$workerRelative] = [pscustomobject]@{
    Key = $workerRelative; Path = $workerPath; Name = 'worker.js'; Kind = 'worker'
    Depth = 0; X = 0; Y = 0
  }
  $queue.Enqueue([pscustomobject]@{ Key = $workerRelative; Depth = 0 })
  $maxDepth = 0
  while ($queue.Count -gt 0) {
    $item = $queue.Dequeue()
    $sourceNode = $nodes[$item.Key]
    if ($sourceNode.Kind -eq 'missing') { continue }
    $sourceText = [IO.File]::ReadAllText($sourceNode.Path)
    $pattern = '(?:\brequire\s*\(\s*|\bimport\s*\(\s*|\bfrom\s*)(["''])(?<path>\.{1,2}/[^"'']+)\1'
    foreach ($match in [regex]::Matches($sourceText, $pattern)) {
      $spec = $match.Groups['path'].Value
      $basePath = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $sourceNode.Path) $spec))
      if (-not $basePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        continue
      }

      $candidates = New-Object 'System.Collections.Generic.List[string]'
      if ([IO.Path]::HasExtension($basePath)) {
        $candidates.Add($basePath)
      } else {
        $candidates.Add($basePath + '.js')
        $candidates.Add($basePath + '.mjs')
        $candidates.Add($basePath + '.cjs')
        $candidates.Add($basePath + '.json')
        $candidates.Add((Join-Path $basePath 'index.js'))
      }
      $resolved = $null
      foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
          $resolved = [IO.Path]::GetFullPath($candidate)
          break
        }
      }

      $lineNumber = ([regex]::Matches($sourceText.Substring(0, $match.Index), "`n")).Count + 1
      if ($resolved) {
        $targetKey = $resolved.Substring($rootPrefix.Length).Replace([IO.Path]::DirectorySeparatorChar, '/')
        if (-not $nodes.ContainsKey($targetKey)) {
          $nodes[$targetKey] = [pscustomobject]@{
            Key = $targetKey; Path = $resolved; Name = [IO.Path]::GetFileName($resolved)
            Kind = 'file'; Depth = $item.Depth + 1; X = 0; Y = 0
          }
          $queue.Enqueue([pscustomobject]@{ Key = $targetKey; Depth = $item.Depth + 1 })
          $maxDepth = [Math]::Max($maxDepth, $item.Depth + 1)
        } elseif ($nodes[$targetKey].Depth -gt ($item.Depth + 1)) {
          $nodes[$targetKey].Depth = $item.Depth + 1
        }
        $target = $targetKey
        $kind = 'import'
      } else {
        $target = 'missing:' + $item.Key + ':' + $spec
        if (-not $nodes.ContainsKey($target)) {
          $nodes[$target] = [pscustomobject]@{
            Key = $target; Path = ''; Name = $spec; Kind = 'missing'
            Depth = $item.Depth + 1; X = 0; Y = 0
          }
          $maxDepth = [Math]::Max($maxDepth, $item.Depth + 1)
        }
        $kind = 'missing'
      }
      $exists = $false
      foreach ($edge in $edges) {
        if ($edge.Source -eq $item.Key -and $edge.Target -eq $target) {
          $exists = $true
          break
        }
      }
      if (-not $exists) {
        $edges.Add([pscustomobject]@{
          Source = $item.Key; Target = $target; Kind = $kind
          Line = $lineNumber; Label = "L$lineNumber"
        })
      }
    }
  }

  $workerText = [IO.File]::ReadAllText($workerPath)
  $bindings = @{}
  foreach ($binding in [regex]::Matches($workerText, '(?m)^\s*const\s+(?<var>\w+)\s*=\s*require\(\s*[''"](?<path>\.{1,2}/[^''"]+)[''"]')) {
    $bindings[$binding.Groups['var'].Value] = $binding.Groups['path'].Value
  }
  $routeLabels = @{}
  foreach ($route in [regex]::Matches($workerText, '[''"](?<route>/api/[^''"]+)[''"]\s*,\s*(?<var>\w+)')) {
    $spec = $bindings[$route.Groups['var'].Value]
    if (-not $spec) { continue }
    foreach ($edge in $edges) {
      if ($edge.Source -eq $workerRelative -and
          [IO.Path]::GetFileNameWithoutExtension($edge.Target) -eq [IO.Path]::GetFileNameWithoutExtension([IO.Path]::GetFileName($spec))) {
        if (-not $routeLabels.ContainsKey($edge.Target)) {
          $routeLabels[$edge.Target] = New-Object 'System.Collections.Generic.List[string]'
        }
        $routeLabels[$edge.Target].Add($route.Groups['route'].Value)
      }
    }
  }
  foreach ($edge in $edges) {
    if ($edge.Source -eq $workerRelative -and $routeLabels.ContainsKey($edge.Target)) {
      $routes = $routeLabels[$edge.Target]
      $edge.Label = $routes[0]
      if ($routes.Count -gt 1) { $edge.Label += " (+$($routes.Count - 1) routes)" }
    }
  }

  $apiDirectory = Join-Path $rootPath 'api'
  if (Test-Path -LiteralPath $apiDirectory -PathType Container) {
    $unlinkedDepth = $maxDepth + 1
    foreach ($apiFile in Get-ChildItem -LiteralPath $apiDirectory -Filter '*.js' -File -Recurse) {
      $relative = $apiFile.FullName.Substring($rootPrefix.Length).Replace([IO.Path]::DirectorySeparatorChar, '/')
      if (-not $nodes.ContainsKey($relative)) {
        $nodes[$relative] = [pscustomobject]@{
          Key = $relative; Path = $apiFile.FullName; Name = $apiFile.Name
          Kind = 'unlinked'; Depth = $unlinkedDepth; X = 0; Y = 0
        }
      }
    }
  }

  $files = @{}
  $directories = New-Object 'System.Collections.Generic.Stack[string]'
  $directories.Push($rootPath)
  while ($directories.Count -gt 0) {
    $directory = $directories.Pop()
    foreach ($entry in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
      if ($entry.PSIsContainer) {
        if ($entry.Name -notin @('.git', 'node_modules')) { $directories.Push($entry.FullName) }
        continue
      }
      if ($entry.Extension -notin @('.js', '.mjs', '.cjs', '.json')) { continue }
      $relative = $entry.FullName.Substring($rootPrefix.Length).Replace([IO.Path]::DirectorySeparatorChar, '/')
      $files[$relative] = $entry.FullName
    }
  }

  $columns = @{}
  foreach ($node in $nodes.Values) {
    if (-not $columns.ContainsKey($node.Depth)) { $columns[$node.Depth] = New-Object 'System.Collections.Generic.List[object]' }
    $columns[$node.Depth].Add($node)
  }
  $maxColumnCount = 1
  foreach ($depth in @($columns.Keys | Sort-Object)) {
    $columnNodes = @($columns[$depth] | Sort-Object Key)
    $maxColumnCount = [Math]::Max($maxColumnCount, $columnNodes.Count)
    for ($index = 0; $index -lt $columnNodes.Count; $index++) {
      $columnNodes[$index].X = 28 + ([int]$depth * 250)
      $columnNodes[$index].Y = 24 + ($index * 92)
    }
  }
  return @{
    Nodes = $nodes
    Edges = $edges.ToArray()
    Width = [Math]::Max(560, (($maxDepth + 1) * 250) + 240)
    Height = [Math]::Max(240, ($maxColumnCount * 92) + 48)
    Files = $files
    Source = $rootPath
  }
}

function Get-RelationGitHubFileText {
  param(
    [string]$Owner,
    [string]$Repository,
    [string]$Branch,
    [string]$Path,
    [hashtable]$Headers
  )
  $encodedPath = (($Path -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
  $encodedBranch = [Uri]::EscapeDataString($Branch)
  $uri = "https://api.github.com/repos/$Owner/$Repository/contents/$encodedPath`?ref=$encodedBranch"
  try {
    $file = Invoke-RestMethod -Uri $uri -Headers $Headers -ErrorAction Stop
    if (-not $file.content) {
      throw "GitHub returned no file content for '$Path'."
    }
    $bytes = [Convert]::FromBase64String(([string]$file.content -replace '\s', ''))
    return [Text.Encoding]::UTF8.GetString($bytes)
  } catch {
    throw "Could not read GitHub file '$Path': $($_.Exception.Message)"
  }
}

function Get-RelationGitHubGraphData {
  param([string]$RepositoryUrl)
  if ($RepositoryUrl -notmatch '^https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?$') {
    throw 'Choose a GitHub repository with the search icon first.'
  }
  $owner = $Matches[1]
  $repository = $Matches[2]
  $account = Get-HomeRepoAccount $RepositoryUrl
  $token = Get-HomeGitHubToken $account
  $headers = @{ 'User-Agent' = 'IJTC-ComBox'; 'Accept' = 'application/vnd.github+json' }
  if ($token) { $headers['Authorization'] = 'Bearer ' + $token }

  try {
    $repoInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repository" -Headers $headers -ErrorAction Stop
  } catch {
    throw "Could not access GitHub repository '$owner/$repository': $($_.Exception.Message)"
  }
  $branch = [string]$repoInfo.default_branch
  if (-not $branch) { throw "GitHub did not report a default branch for '$owner/$repository'." }
  $encodedBranch = [Uri]::EscapeDataString($branch)
  try {
    $branchInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repository/branches/$encodedBranch" -Headers $headers -ErrorAction Stop
  } catch {
    throw "Could not read the default branch '$branch' in '$owner/$repository': $($_.Exception.Message)"
  }
  $treeSha = [string]$branchInfo.commit.sha
  if (-not $treeSha) { throw "GitHub did not report a commit for '$owner/$repository@$branch'." }
  try {
    $tree = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repository/git/trees/$treeSha`?recursive=1" -Headers $headers -ErrorAction Stop
  } catch {
    throw "Could not list files in '$owner/$repository': $($_.Exception.Message)"
  }
  if ($tree.truncated) {
    throw "GitHub's file list for '$owner/$repository' was truncated; relation scan was stopped to avoid missing files."
  }

  $files = @{}
  foreach ($entry in $tree.tree) {
    if ($entry.type -eq 'blob') { $files[[string]$entry.path] = $entry }
  }
  if (-not $files.ContainsKey('worker.js')) {
    throw "worker.js was not found at the repository root of '$owner/$repository'."
  }

  $nodes = @{}
  $edges = New-Object 'System.Collections.Generic.List[object]'
  $queue = New-Object 'System.Collections.Generic.Queue[string]'
  $nodes['worker.js'] = [pscustomobject]@{
    Key = 'worker.js'; Path = 'worker.js'; Name = 'worker.js'; Kind = 'worker'
    Depth = 0; X = 0; Y = 0
  }
  $queue.Enqueue('worker.js')
  $depths = @{ 'worker.js' = 0 }
  $sourceCache = @{}
  $maxDepth = 0
  while ($queue.Count -gt 0) {
    $sourcePath = $queue.Dequeue()
    $sourceDepth = [int]$depths[$sourcePath]
    if (-not $sourceCache.ContainsKey($sourcePath)) {
      $sourceCache[$sourcePath] = Get-RelationGitHubFileText $owner $repository $branch $sourcePath $headers
    }
    $sourceText = [string]$sourceCache[$sourcePath]
    $pattern = '(?:\brequire\s*\(\s*|\bimport\s*\(\s*|\bfrom\s*)(["''])(?<path>\.{1,2}/[^"'']+)\1'
    foreach ($match in [regex]::Matches($sourceText, $pattern)) {
      $spec = $match.Groups['path'].Value
      $parts = New-Object 'System.Collections.Generic.List[string]'
      $sourceDirectory = ''
      if ($sourcePath.Contains('/')) {
        $sourceDirectory = $sourcePath.Substring(0, $sourcePath.LastIndexOf('/'))
      }
      if ($sourceDirectory) {
        foreach ($part in ($sourceDirectory -split '/')) {
          if ($part) { $parts.Add($part) }
        }
      }
      $outsideRepository = $false
      foreach ($part in ($spec -split '/')) {
        if ($part -eq '.' -or -not $part) { continue }
        if ($part -eq '..') {
          if ($parts.Count -eq 0) {
            $outsideRepository = $true
            break
          }
          $parts.RemoveAt($parts.Count - 1)
        } else {
          $parts.Add($part)
        }
      }
      if ($outsideRepository) { continue }
      $basePath = $parts -join '/'
      $candidates = New-Object 'System.Collections.Generic.List[string]'
      if ([IO.Path]::HasExtension($basePath)) {
        $candidates.Add($basePath)
      } else {
        $candidates.Add($basePath + '.js')
        $candidates.Add($basePath + '.mjs')
        $candidates.Add($basePath + '.cjs')
        $candidates.Add($basePath + '.json')
        $candidates.Add($basePath.TrimEnd('/') + '/index.js')
      }
      $resolved = $null
      foreach ($candidate in $candidates) {
        if ($files.ContainsKey($candidate)) {
          $resolved = $candidate
          break
        }
      }
      $lineNumber = ([regex]::Matches($sourceText.Substring(0, $match.Index), "`n")).Count + 1
      if ($resolved) {
        $target = $resolved
        $kind = 'import'
        $nextDepth = $sourceDepth + 1
        if (-not $nodes.ContainsKey($target)) {
          $nodes[$target] = [pscustomobject]@{
            Key = $target; Path = $target; Name = [IO.Path]::GetFileName($target)
            Kind = 'file'; Depth = $nextDepth; X = 0; Y = 0
          }
        }
        if (-not $depths.ContainsKey($target) -or $depths[$target] -gt $nextDepth) {
          $depths[$target] = $nextDepth
          $nodes[$target].Depth = $nextDepth
          $queue.Enqueue($target)
          $maxDepth = [Math]::Max($maxDepth, $nextDepth)
        }
      } else {
        $target = 'missing:' + $sourcePath + ':' + $spec
        $kind = 'missing'
        if (-not $nodes.ContainsKey($target)) {
          $nodes[$target] = [pscustomobject]@{
            Key = $target; Path = ''; Name = $spec; Kind = 'missing'
            Depth = $sourceDepth + 1; X = 0; Y = 0
          }
          $maxDepth = [Math]::Max($maxDepth, $sourceDepth + 1)
        }
      }
      $exists = $false
      foreach ($edge in $edges) {
        if ($edge.Source -eq $sourcePath -and $edge.Target -eq $target) {
          $exists = $true
          break
        }
      }
      if (-not $exists) {
        $edges.Add([pscustomobject]@{
          Source = $sourcePath; Target = $target; Kind = $kind
          Line = $lineNumber; Label = "L$lineNumber"
        })
      }
    }
  }

  $workerText = [string]$sourceCache['worker.js']
  $bindings = @{}
  foreach ($binding in [regex]::Matches($workerText, '(?m)^\s*const\s+(?<var>\w+)\s*=\s*require\(\s*[''"](?<path>\.{1,2}/[^''"]+)[''"]')) {
    $bindings[$binding.Groups['var'].Value] = $binding.Groups['path'].Value
  }
  $routeLabels = @{}
  foreach ($route in [regex]::Matches($workerText, '[''"](?<route>/api/[^''"]+)[''"]\s*,\s*(?<var>\w+)')) {
    $spec = $bindings[$route.Groups['var'].Value]
    if (-not $spec) { continue }
    foreach ($edge in $edges) {
      if ($edge.Source -eq 'worker.js' -and
          [IO.Path]::GetFileNameWithoutExtension($edge.Target) -eq [IO.Path]::GetFileNameWithoutExtension([IO.Path]::GetFileName($spec))) {
        if (-not $routeLabels.ContainsKey($edge.Target)) {
          $routeLabels[$edge.Target] = New-Object 'System.Collections.Generic.List[string]'
        }
        $routeLabels[$edge.Target].Add($route.Groups['route'].Value)
      }
    }
  }
  foreach ($edge in $edges) {
    if ($edge.Source -eq 'worker.js' -and $routeLabels.ContainsKey($edge.Target)) {
      $routes = $routeLabels[$edge.Target]
      $edge.Label = $routes[0]
      if ($routes.Count -gt 1) { $edge.Label += " (+$($routes.Count - 1) routes)" }
    }
  }
  $unlinkedDepth = $maxDepth + 1
  foreach ($path in @($files.Keys | Where-Object { $_ -match '^api/.+\.js$' })) {
    if (-not $nodes.ContainsKey($path)) {
      $nodes[$path] = [pscustomobject]@{
        Key = $path; Path = $path; Name = [IO.Path]::GetFileName($path)
        Kind = 'unlinked'; Depth = $unlinkedDepth; X = 0; Y = 0
      }
    }
  }

  $columns = @{}
  foreach ($node in $nodes.Values) {
    if (-not $columns.ContainsKey($node.Depth)) { $columns[$node.Depth] = New-Object 'System.Collections.Generic.List[object]' }
    $columns[$node.Depth].Add($node)
  }
  $maxColumnCount = 1
  foreach ($depth in @($columns.Keys | Sort-Object)) {
    $columnNodes = @($columns[$depth] | Sort-Object Key)
    $maxColumnCount = [Math]::Max($maxColumnCount, $columnNodes.Count)
    for ($index = 0; $index -lt $columnNodes.Count; $index++) {
      $columnNodes[$index].X = 28 + ([int]$depth * 250)
      $columnNodes[$index].Y = 24 + ($index * 92)
    }
  }
  return @{
    Nodes = $nodes; Edges = $edges.ToArray()
    Width = [Math]::Max(560, (($maxDepth + 1) * 250) + 240)
    Height = [Math]::Max(240, ($maxColumnCount * 92) + 48)
    Source = "$owner/$repository@$branch"
    Owner = $owner
    Repository = $repository
    Branch = $branch
    Files = $files
  }
}

function Set-RelationGraphStatus {
  param([string]$Text, [string]$Kind = 'info')
  $relationStatusLabel.Text = $Text
  $toolTip.SetToolTip($relationStatusLabel, $Text)
  if ($Kind -eq 'error') {
    $relationStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick
  } else {
    $relationStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(65, 83, 103)
  }
}

function Reset-RelationGraph {
  $script:relationLocalGraph = $null
  $script:relationRepoGraph = $null
  $script:relationGraphData = $null
  $script:relationGraphErrors = @{}
  $relationGraphCanvas.Size = $relationGraphViewport.ClientSize
  $relationGraphViewport.AutoScrollMinSize = [System.Drawing.Size]::Empty
  Set-RelationGraphStatus 'Source selection changed. Click Refresh to check Local and Repo relations.'
  $relationGraphCanvas.Invalidate()
}

function Get-RelationGraphStats {
  param($Graph)
  $files = @($Graph.Nodes.Values | Where-Object { $_.Kind -in @('worker', 'file') }).Count
  $missing = @($Graph.Nodes.Values | Where-Object { $_.Kind -eq 'missing' }).Count
  $unlinked = @($Graph.Nodes.Values | Where-Object { $_.Kind -eq 'unlinked' }).Count
  return [pscustomobject]@{
    Files = $files
    Links = $Graph.Edges.Count
    Missing = $missing
    Unlinked = $unlinked
  }
}

function Get-RelationMissingCandidates {
  param([string]$SourcePath, [string]$ImportPath)
  $parts = New-Object 'System.Collections.Generic.List[string]'
  $separator = $SourcePath.LastIndexOf('/')
  if ($separator -ge 0) {
    foreach ($part in ($SourcePath.Substring(0, $separator) -split '/')) {
      if ($part) { $parts.Add($part) }
    }
  }
  foreach ($part in ($ImportPath -split '/')) {
    if (-not $part -or $part -eq '.') { continue }
    if ($part -eq '..') {
      if ($parts.Count -eq 0) { return @() }
      $parts.RemoveAt($parts.Count - 1)
    } else {
      $parts.Add($part)
    }
  }
  $basePath = $parts -join '/'
  if ([IO.Path]::HasExtension($basePath)) {
    return @($basePath)
  }
  return @(
    ($basePath + '.js'),
    ($basePath + '.mjs'),
    ($basePath + '.cjs'),
    ($basePath + '.json'),
    ($basePath.TrimEnd('/') + '/index.js')
  )
}

function Get-RelationCounterpartPath {
  param($Graph, [string[]]$Candidates)
  foreach ($candidate in $Candidates) {
    if ($Graph.Files.ContainsKey($candidate)) {
      return $candidate
    }
  }

  foreach ($candidate in $Candidates) {
    $moduleName = [IO.Path]::GetFileNameWithoutExtension($candidate)
    if ($moduleName -eq 'index' -and $candidate -match '(?:^|/)index\.js$') { continue }
    $extension = [IO.Path]::GetExtension($candidate)
    $candidateParts = @([string]$candidate -split '/')
    $candidateDirectories = @()
    if ($candidateParts.Length -gt 1) {
      $candidateDirectories = @($candidateParts[0..($candidateParts.Length - 2)])
    }
    $matches = New-Object 'System.Collections.Generic.List[object]'
    foreach ($path in $Graph.Files.Keys) {
      $path = [string]$path
      if (-not [string]::Equals(
          [IO.Path]::GetFileNameWithoutExtension($path),
          $moduleName,
          [StringComparison]::OrdinalIgnoreCase
        ) -or [IO.Path]::GetExtension($path) -ne $extension) {
        continue
      }
      $pathParts = @($path -split '/')
      $pathDirectories = @()
      if ($pathParts.Length -gt 1) {
        $pathDirectories = @($pathParts[0..($pathParts.Length - 2)])
      }
      $sharedDirectories = 0
      while ($sharedDirectories -lt $candidateDirectories.Count -and
          $sharedDirectories -lt $pathDirectories.Count -and
          [string]::Equals(
            [string]$candidateDirectories[$sharedDirectories],
            [string]$pathDirectories[$sharedDirectories],
            [StringComparison]::OrdinalIgnoreCase
          )) {
        $sharedDirectories++
      }
      $matches.Add([pscustomobject]@{ Path = $path; Score = $sharedDirectories })
    }
    if ($matches.Count -eq 1) {
      return [string]$matches[0].Path
    }
    if ($matches.Count -gt 1) {
      $bestScore = [int](($matches | Measure-Object -Property Score -Maximum).Maximum)
      $bestMatches = @($matches | Where-Object Score -eq $bestScore)
      if ($bestMatches.Count -eq 1) {
        return [string]$bestMatches[0].Path
      }
    }
  }
  return $null
}

function Get-RelationMissingTargetPath {
  param([string[]]$Candidates, [string]$SourcePath)
  foreach ($candidate in $Candidates) {
    if ($candidate -eq $SourcePath) { return $candidate }
  }
  $sourceExtension = [IO.Path]::GetExtension($SourcePath)
  if ($sourceExtension) {
    $matchingExtension = $Candidates | Where-Object {
      [IO.Path]::GetExtension($_) -eq $sourceExtension
    } | Select-Object -First 1
    if ($matchingExtension) { return [string]$matchingExtension }
  }
  if ($Candidates.Count -gt 0) { return [string]$Candidates[0] }
  return $null
}

function Get-RelationMissingImportReport {
  param([string]$Name, $Graph, $OtherGraph)
  $lines = New-Object 'System.Collections.Generic.List[string]'
  $missingEdges = @($Graph.Edges | Where-Object { $_.Kind -eq 'missing' })
  if ($missingEdges.Count -eq 0) {
    $lines.Add("$Name missing imports: none")
    return $lines.ToArray()
  }
  $lines.Add("$Name missing imports ($($missingEdges.Count)):")
  foreach ($edge in ($missingEdges | Sort-Object Source, Line)) {
    $node = $Graph.Nodes[$edge.Target]
    $sourceNode = $Graph.Nodes[$edge.Source]
    $importPath = [string]$node.Name
    $counterpart = ''
    if ($OtherGraph) {
      $candidates = @(Get-RelationMissingCandidates $edge.Source $importPath)
      $sourcePath = Get-RelationCounterpartPath $OtherGraph $candidates
      if ($sourcePath) {
        $targetPath = Get-RelationMissingTargetPath $candidates $sourcePath
        if ($sourcePath -eq $targetPath) {
          $counterpart = " [available in other source: $sourcePath]"
        } else {
          $counterpart = " [copy from other source: $sourcePath -> $targetPath]"
        }
      }
    }
    $lines.Add(("  {0}:{1} -> {2}{3}" -f $edge.Source,$edge.Line,$importPath,$counterpart))
  }
  return $lines.ToArray()
}

function Get-RelationDifferenceReport {
  if (-not $script:relationLocalGraph -and -not $script:relationRepoGraph) {
    throw 'Click Refresh to check Local and Repo before copying the comparison.'
  }
  $lines = New-Object 'System.Collections.Generic.List[string]'
  $lines.Add('Local and GitHub Repo relation comparison')
  if ($script:relationLocalGraph) {
    $localStats = Get-RelationGraphStats $script:relationLocalGraph
    $lines.Add(("Local: {0}; {1} files, {2} links, {3} missing imports, {4} unlinked API files" -f $script:relationLocalGraph.Source,$localStats.Files,$localStats.Links,$localStats.Missing,$localStats.Unlinked))
  } elseif ($script:relationGraphErrors.Local) {
    $lines.Add("Local scan error: $($script:relationGraphErrors.Local)")
  } else {
    $lines.Add('Local: not selected')
  }
  if ($script:relationRepoGraph) {
    $repoStats = Get-RelationGraphStats $script:relationRepoGraph
    $lines.Add(("Repo: {0}; {1} files, {2} links, {3} missing imports, {4} unlinked API files" -f $script:relationRepoGraph.Source,$repoStats.Files,$repoStats.Links,$repoStats.Missing,$repoStats.Unlinked))
  } elseif ($script:relationGraphErrors.Repo) {
    $lines.Add("Repo scan error: $($script:relationGraphErrors.Repo)")
  } else {
    $lines.Add('Repo: not selected')
  }

  if ($script:relationLocalGraph -and $script:relationRepoGraph) {
    $localPaths = @($script:relationLocalGraph.Nodes.Values | Where-Object { $_.Kind -in @('worker', 'file', 'unlinked') } | ForEach-Object Key)
    $repoPaths = @($script:relationRepoGraph.Nodes.Values | Where-Object { $_.Kind -in @('worker', 'file', 'unlinked') } | ForEach-Object Key)
    $onlyLocal = @($localPaths | Where-Object { $_ -notin $repoPaths } | Sort-Object -Unique)
    $onlyRepo = @($repoPaths | Where-Object { $_ -notin $localPaths } | Sort-Object -Unique)
    $lines.Add("Relation module paths only in Local ($($onlyLocal.Count)):")
    if ($onlyLocal.Count) { foreach ($path in $onlyLocal) { $lines.Add("  + $path") } } else { $lines.Add('  none') }
    $lines.Add("Relation module paths only in Repo ($($onlyRepo.Count)):")
    if ($onlyRepo.Count) { foreach ($path in $onlyRepo) { $lines.Add("  + $path") } } else { $lines.Add('  none') }
    foreach ($line in (Get-RelationMissingImportReport 'Local' $script:relationLocalGraph $script:relationRepoGraph)) { $lines.Add($line) }
    foreach ($line in (Get-RelationMissingImportReport 'Repo' $script:relationRepoGraph $script:relationLocalGraph)) { $lines.Add($line) }
  } elseif ($script:relationLocalGraph) {
    foreach ($line in (Get-RelationMissingImportReport 'Local' $script:relationLocalGraph $null)) { $lines.Add($line) }
  } elseif ($script:relationRepoGraph) {
    foreach ($line in (Get-RelationMissingImportReport 'Repo' $script:relationRepoGraph $null)) { $lines.Add($line) }
  }
  return $lines -join [Environment]::NewLine
}

function Update-RelationGraph {
  param([switch]$Silent)
  $script:relationLocalGraph = $null
  $script:relationRepoGraph = $null
  $script:relationGraphErrors = @{}
  $root = $relationFolderBox.Text.Trim()
  $repositoryUrl = $relationRepoBox.Text.Trim()
  if ($root) {
    try {
      $script:relationLocalGraph = Get-RelationGraphData $root
    } catch {
      $script:relationGraphErrors.Local = $_.Exception.Message
    }
  }
  if ($repositoryUrl) {
    try {
      $script:relationRepoGraph = Get-RelationGitHubGraphData $repositoryUrl
    } catch {
      $script:relationGraphErrors.Repo = $_.Exception.Message
    }
  }
  if (-not $root -and -not $repositoryUrl) {
    Reset-RelationGraph
    Set-RelationGraphStatus 'Choose Local or Repo and click Refresh to check relations.' 'error'
    return
  }
  $data = if ($script:relationRepoGraph) { $script:relationRepoGraph } else { $script:relationLocalGraph }
  $script:relationGraphData = $data
  if ($data) {
    $relationGraphCanvas.Size = New-Object System.Drawing.Size($data.Width, $data.Height)
    $relationGraphViewport.AutoScrollMinSize = New-Object System.Drawing.Size($data.Width, $data.Height)
  } else {
    $relationGraphCanvas.Size = $relationGraphViewport.ClientSize
    $relationGraphViewport.AutoScrollMinSize = [System.Drawing.Size]::Empty
  }
  $statusParts = New-Object 'System.Collections.Generic.List[string]'
  foreach ($entry in @(
      @{ Name = 'Local'; Graph = $script:relationLocalGraph },
      @{ Name = 'Repo'; Graph = $script:relationRepoGraph }
    )) {
    if ($entry.Graph) {
      $stats = Get-RelationGraphStats $entry.Graph
      $statusParts.Add(("{0}: {1} files, {2} missing, {3} unlinked" -f $entry.Name,$stats.Files,$stats.Missing,$stats.Unlinked))
    } elseif ($script:relationGraphErrors[$entry.Name]) {
      $statusParts.Add(("{0} error: {1}" -f $entry.Name,$script:relationGraphErrors[$entry.Name]))
    }
  }
  if ($script:relationLocalGraph -and $script:relationRepoGraph) {
    $localPaths = @($script:relationLocalGraph.Nodes.Values | Where-Object { $_.Kind -in @('worker', 'file', 'unlinked') } | ForEach-Object Key)
    $repoPaths = @($script:relationRepoGraph.Nodes.Values | Where-Object { $_.Kind -in @('worker', 'file', 'unlinked') } | ForEach-Object Key)
    $onlyLocalCount = @($localPaths | Where-Object { $_ -notin $repoPaths } | Sort-Object -Unique).Count
    $onlyRepoCount = @($repoPaths | Where-Object { $_ -notin $localPaths } | Sort-Object -Unique).Count
    $statusParts.Add(("only Local/Repo: {0}/{1}" -f $onlyLocalCount,$onlyRepoCount))
  }
  $statusParts.Add('Static imports only')
  $kind = if ($script:relationGraphErrors.Count -gt 0) { 'error' } else { 'info' }
  if (-not $Silent) {
    try {
      Play-NotificationSound
    } catch {
      $statusParts.Add("Scan complete, but notification sound failed: $($_.Exception.Message)")
      $kind = 'error'
    }
  }
  Set-RelationGraphStatus ($statusParts -join ' | ') $kind
  $relationGraphCanvas.Invalidate()
}

function Get-RelationFixPlan {
  $plan = New-Object 'System.Collections.Generic.List[object]'
  if (-not $script:relationLocalGraph -or -not $script:relationRepoGraph) {
    return $plan.ToArray()
  }
  $seen = @{}
  foreach ($entry in @(
      @{ Name = 'Local'; Graph = $script:relationLocalGraph; Other = $script:relationRepoGraph; Destination = 'Local' },
      @{ Name = 'Repo'; Graph = $script:relationRepoGraph; Other = $script:relationLocalGraph; Destination = 'Repo' }
    )) {
    foreach ($edge in @($entry.Graph.Edges | Where-Object { $_.Kind -eq 'missing' })) {
      $missingNode = $entry.Graph.Nodes[$edge.Target]
      $candidates = @(Get-RelationMissingCandidates $edge.Source ([string]$missingNode.Name))
      $sourcePath = Get-RelationCounterpartPath $entry.Other $candidates
      if (-not $sourcePath) { continue }
      $targetPath = Get-RelationMissingTargetPath $candidates $sourcePath
      if ($entry.Graph.Files.ContainsKey($targetPath)) { continue }
      $key = $entry.Destination + ':' + $targetPath
      if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        $plan.Add([pscustomobject]@{
          Destination = $entry.Destination
          Path = $targetPath
          Source = $entry.Other
          SourcePath = $sourcePath
          Importer = $edge.Source
          Line = $edge.Line
        })
      }
    }
  }
  return $plan.ToArray()
}

function Write-RelationLocalFile {
  param([string]$Root, [string]$RelativePath, [byte[]]$Bytes)
  $rootPath = [IO.Path]::GetFullPath($Root)
  $destination = [IO.Path]::GetFullPath((Join-Path $rootPath ($RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))))
  $prefix = $rootPath
  if (-not $prefix.EndsWith([string][IO.Path]::DirectorySeparatorChar)) {
    $prefix += [IO.Path]::DirectorySeparatorChar
  }
  if (-not $destination.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to write outside Local folder: $RelativePath"
  }
  $directory = Split-Path -Parent $destination
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
    New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
  }
  $stream = New-Object System.IO.FileStream(
    $destination,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None
  )
  try {
    $stream.Write($Bytes, 0, $Bytes.Length)
  } finally {
    $stream.Dispose()
  }
}

function Add-RelationGitHubFile {
  param($Graph, [string]$RelativePath, [byte[]]$Bytes, [string]$Token)
  $encodedPath = (($RelativePath -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
  $encodedBranch = [Uri]::EscapeDataString([string]$Graph.Branch)
  $uri = "https://api.github.com/repos/$($Graph.Owner)/$($Graph.Repository)/contents/$encodedPath"
  $headers = @{ 'User-Agent' = 'IJTC-ComBox'; 'Accept' = 'application/vnd.github+json' }
  if ($Token) { $headers['Authorization'] = 'Bearer ' + $Token }
  $body = @{
    message = "Add missing relation dependency $RelativePath"
    content = [Convert]::ToBase64String($Bytes)
    branch = [string]$Graph.Branch
  } | ConvertTo-Json -Depth 3
  try {
    Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -ContentType 'application/json' -Body $body -ErrorAction Stop | Out-Null
  } catch {
    throw "Could not create '$RelativePath' in $($Graph.Owner)/$($Graph.Repository): $($_.Exception.Message)"
  }
}

function Copy-RelationDifferenceReport {
  try {
    $report = Get-RelationDifferenceReport
    [System.Windows.Forms.Clipboard]::SetText($report)
    Set-RelationGraphStatus 'Local/Repo relation differences copied. Paste into AI to review and fix.'
  } catch {
    Set-RelationGraphStatus $_.Exception.Message 'error'
  }
}

function Fix-RelationMissingFiles {
  if (-not $script:relationLocalGraph -or -not $script:relationRepoGraph) {
    Set-RelationGraphStatus 'Click Refresh with both Local and Repo selected before auto-fixing.'
    return
  }
  $plan = @(Get-RelationFixPlan)
  if ($plan.Count -eq 0) {
    $details = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in @(
        @{ Name = 'Local'; Graph = $script:relationLocalGraph; Other = $script:relationRepoGraph },
        @{ Name = 'Repo'; Graph = $script:relationRepoGraph; Other = $script:relationLocalGraph }
      )) {
      if (-not $entry.Graph) { continue }
      foreach ($edge in @($entry.Graph.Edges | Where-Object { $_.Kind -eq 'missing' } | Select-Object -First 3)) {
        $missingNode = $entry.Graph.Nodes[$edge.Target]
        $candidates = @(Get-RelationMissingCandidates $edge.Source ([string]$missingNode.Name))
        if (-not (Get-RelationCounterpartPath $entry.Other $candidates)) {
          $details.Add(("{0}: {1} -> {2}" -f $entry.Name,$edge.Source,$missingNode.Name))
        }
      }
    }
    if ($details.Count -eq 0) {
      $missingCount = 0
      $unlinkedPaths = New-Object 'System.Collections.Generic.List[string]'
      foreach ($graph in @($script:relationLocalGraph, $script:relationRepoGraph)) {
        if (-not $graph) { continue }
        $missingCount += @($graph.Edges | Where-Object { $_.Kind -eq 'missing' }).Count
        foreach ($node in @($graph.Nodes.Values | Where-Object { $_.Kind -eq 'unlinked' })) {
          if ($node.Key -notin $unlinkedPaths) { $unlinkedPaths.Add([string]$node.Key) }
        }
      }
      if ($missingCount -eq 0 -and $unlinkedPaths.Count -gt 0) {
        $shown = @($unlinkedPaths | Select-Object -First 5) -join ', '
        if ($unlinkedPaths.Count -gt 5) { $shown += ", and $($unlinkedPaths.Count - 5) more" }
        Set-RelationGraphStatus ("No missing imports. Yellow files have no worker.js import path; they are not missing files and cannot be safely wired automatically: $shown")
      } elseif ($missingCount -eq 0) {
        Set-RelationGraphStatus 'No missing imports were found in the current Local and Repo scans.'
      } else {
        Set-RelationGraphStatus 'No missing imports are available to fix in the current scan. Check the Local and Repo scan errors, then Refresh.'
      }
    } else {
      Set-RelationGraphStatus ("No matching source file found for: " + ($details -join ' | ')) 'error'
    }
    return
  }

  $localPlan = @($plan | Where-Object Destination -eq 'Local')
  $repoPlan = @($plan | Where-Object Destination -eq 'Repo')
  $githubToken = ''
  if ($repoPlan.Count -gt 0 -or $localPlan.Count -gt 0) {
    $githubToken = Get-HomeGitHubToken (Get-HomeRepoAccount $relationRepoBox.Text)
    if ($repoPlan.Count -gt 0 -and -not $githubToken) {
      Set-RelationGraphStatus 'Cannot fix Repo files: sign in to GitHub with write access, then refresh and try again.' 'error'
      return
    }
  }
  if ($repoPlan.Count -gt 0) {
    $shown = @($repoPlan | Select-Object -First 10 | ForEach-Object { "  $($_.Path)" }) -join "`r`n"
    if ($repoPlan.Count -gt 10) { $shown += "`r`n  ... and $($repoPlan.Count - 10) more" }
    $answer = [System.Windows.Forms.MessageBox]::Show(
      $form,
      "Create $($repoPlan.Count) missing file(s) in $($script:relationRepoGraph.Owner)/$($script:relationRepoGraph.Repository) on branch '$($script:relationRepoGraph.Branch)'?`r`n`r`n$shown`r`n`r`nThis creates new files only; existing files will not be overwritten. GitHub will record commits for these additions.",
      'Confirm GitHub relation fixes',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Warning,
      [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
      Set-RelationGraphStatus 'Auto-fix cancelled; no files were changed.'
      return
    }
  }

  $localRoot = [string]$relationFolderBox.Text
  $githubHeaders = @{ 'User-Agent' = 'IJTC-ComBox'; 'Accept' = 'application/vnd.github+json' }
  if ($githubToken) { $githubHeaders['Authorization'] = 'Bearer ' + $githubToken }

  $fixed = 0
  $problems = New-Object 'System.Collections.Generic.List[string]'
  foreach ($item in $localPlan) {
    try {
      if ($item.Source.Files[$item.SourcePath] -is [string]) {
        $sourcePath = [string]$item.Source.Files[$item.SourcePath]
        $bytes = [IO.File]::ReadAllBytes($sourcePath)
      } else {
        $text = Get-RelationGitHubFileText $item.Source.Owner $item.Source.Repository $item.Source.Branch $item.SourcePath $githubHeaders
        $bytes = [Text.Encoding]::UTF8.GetBytes($text)
      }
      Write-RelationLocalFile $localRoot $item.Path $bytes
      $fixed++
    } catch {
      $problems.Add("Local $($item.Path): $($_.Exception.Message)")
    }
  }
  foreach ($item in $repoPlan) {
    try {
      $sourcePath = [string]$item.Source.Files[$item.SourcePath]
      $bytes = [IO.File]::ReadAllBytes($sourcePath)
      Add-RelationGitHubFile $script:relationRepoGraph $item.Path $bytes $githubToken
      $fixed++
    } catch {
      $problems.Add("Repo $($item.Path): $($_.Exception.Message)")
    }
  }
  Update-RelationGraph -Silent
  $completionMessage = ''
  $completionKind = 'info'
  if ($problems.Count -gt 0) {
    $completionMessage = "Fixed $fixed file(s); some fixes failed: $($problems -join ' | ')"
    $completionKind = 'error'
  } else {
    $completionMessage = "Auto-fix complete: created $fixed missing file(s). Existing files were not overwritten."
  }
  if ($fixed -gt 0) {
    try {
      Play-NotificationSound
    } catch {
      $completionMessage += " Completion sound failed: $($_.Exception.Message)"
      $completionKind = 'error'
    }
  }
  Set-RelationGraphStatus $completionMessage $completionKind
}

function Draw-RelationGraph {
  param([System.Drawing.Graphics]$Graphics)
  $Graphics.Clear([System.Drawing.Color]::White)
  if (-not $script:relationGraphData) {
    $hintFont = New-Object System.Drawing.Font('Segoe UI', 9)
    try {
      [System.Windows.Forms.TextRenderer]::DrawText(
        $Graphics, 'Choose a PC folder or GitHub repository, then refresh to scan its worker.js relations.',
        $hintFont, (New-Object System.Drawing.Rectangle(18, 18, 620, 24)),
        [System.Drawing.Color]::FromArgb(85, 95, 110)
      )
    } finally {
      $hintFont.Dispose()
    }
    return
  }
  $data = $script:relationGraphData
  $font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
  $smallFont = New-Object System.Drawing.Font('Segoe UI', 8)
  $edgePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(145, 159, 178), 1.5)
  $missingPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Firebrick, 1.5)
  $arrow = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(4, 5, $true)
  $edgePen.CustomEndCap = $arrow
  $missingPen.CustomEndCap = $arrow
  try {
    foreach ($edge in $data.Edges) {
      $source = $data.Nodes[$edge.Source]
      $target = $data.Nodes[$edge.Target]
      $pen = $edgePen
      if ($edge.Kind -eq 'missing') { $pen = $missingPen }
      $start = New-Object System.Drawing.Point(($source.X + 200), ($source.Y + 29))
      $end = New-Object System.Drawing.Point($target.X, ($target.Y + 29))
      $Graphics.DrawLine($pen, $start, $end)
      $labelX = [int](($start.X + $end.X) / 2)
      $labelY = [int](($start.Y + $end.Y) / 2) - 13
      [System.Windows.Forms.TextRenderer]::DrawText(
        $Graphics, [string]$edge.Label, $smallFont,
        (New-Object System.Drawing.Rectangle(($labelX - 36), $labelY, 100, 18)),
        $(if ($edge.Kind -eq 'missing') { [System.Drawing.Color]::Firebrick } else { [System.Drawing.Color]::FromArgb(85, 95, 110) }),
        [System.Windows.Forms.TextFormatFlags]::EndEllipsis
      )
    }
    foreach ($node in $data.Nodes.Values) {
      $rect = New-Object System.Drawing.Rectangle($node.X, $node.Y, 200, 58)
      $fill = [System.Drawing.Color]::FromArgb(235, 243, 252)
      $border = [System.Drawing.Color]::FromArgb(91, 137, 190)
      if ($node.Kind -eq 'worker') {
        $fill = [System.Drawing.Color]::FromArgb(38, 105, 176)
        $border = [System.Drawing.Color]::FromArgb(25, 77, 132)
      } elseif ($node.Kind -eq 'missing') {
        $fill = [System.Drawing.Color]::FromArgb(255, 238, 238)
        $border = [System.Drawing.Color]::Firebrick
      } elseif ($node.Kind -eq 'unlinked') {
        $fill = [System.Drawing.Color]::FromArgb(255, 247, 225)
        $border = [System.Drawing.Color]::FromArgb(190, 132, 35)
      }
      $brush = New-Object System.Drawing.SolidBrush($fill)
      $nodePen = New-Object System.Drawing.Pen($border, 1.5)
      try {
        $Graphics.FillRectangle($brush, $rect)
        $Graphics.DrawRectangle($nodePen, $rect)
      } finally {
        $brush.Dispose()
        $nodePen.Dispose()
      }
      $titleColor = [System.Drawing.Color]::FromArgb(35, 48, 65)
      if ($node.Kind -eq 'worker') { $titleColor = [System.Drawing.Color]::White }
      [System.Windows.Forms.TextRenderer]::DrawText(
        $Graphics, [string]$node.Name, $font,
        (New-Object System.Drawing.Rectangle(($node.X + 8), ($node.Y + 5), 184, 22)),
        $titleColor, [System.Windows.Forms.TextFormatFlags]::EndEllipsis
      )
      $detail = [string]$node.Key
      if ($node.Kind -eq 'missing') { $detail = 'MISSING import target' }
      elseif ($node.Kind -eq 'unlinked') { $detail = 'No worker import path found' }
      [System.Windows.Forms.TextRenderer]::DrawText(
        $Graphics, $detail, $smallFont,
        (New-Object System.Drawing.Rectangle(($node.X + 8), ($node.Y + 31), 184, 20)),
        $(if ($node.Kind -eq 'worker') { [System.Drawing.Color]::White } elseif ($node.Kind -eq 'missing') { [System.Drawing.Color]::Firebrick } else { [System.Drawing.Color]::FromArgb(85, 95, 110) }),
        [System.Windows.Forms.TextFormatFlags]::EndEllipsis
      )
    }
  } finally {
    $font.Dispose()
    $smallFont.Dispose()
    $edgePen.Dispose()
    $missingPen.Dispose()
    $arrow.Dispose()
  }
}

$relationBrowseButton.Add_Click({
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  try {
    $dialog.Description = 'Choose a PC folder containing worker.js'
    $dialog.ShowNewFolderButton = $false
    if (-not [string]::IsNullOrWhiteSpace($relationFolderBox.Text) -and
        (Test-Path -LiteralPath $relationFolderBox.Text -PathType Container)) {
      $dialog.SelectedPath = $relationFolderBox.Text
    }
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
      Set-SectionFolder 'relation' $dialog.SelectedPath
      $relationRepoBox.Clear()
      Reset-RelationGraph
    }
  } finally {
    $dialog.Dispose()
  }
})

$relationRepoSearchButton.Add_Click({
  Show-RepoPicker -Box $relationRepoBox -Button $relationRepoSearchButton -Status {
    param($Text, $Kind)
    if ($Kind -eq 'success') {
      Request-FormStateSave
      Reset-RelationGraph
    } else {
      Set-RelationGraphStatus $Text $Kind
    }
  }
})

$relationRefreshButton.Add_Click({ Update-RelationGraph })
$relationCopyButton.Add_Click({ Copy-RelationDifferenceReport })
$relationFixButton.Add_Click({
  try {
    Fix-RelationMissingFiles
  } catch {
    Set-RelationGraphStatus ("Fix failed: " + $_.Exception.Message) 'error'
  }
})

# Work a tab needs when it is opened (Show-Section in Form.bat calls these).
function Invoke-SectionShowing {
  param([string]$Name)
  Hide-RenameSearch
  if ($Name -eq 'runlocal') {
    Update-RunLocalState
    $runLocalTimer.Start()
  } else {
    $runLocalTimer.Stop()
  }
}

function Invoke-SectionShown {
  param([string]$Name)
  if ($Name -eq 'relation') {
    $relationFolderLabel.BringToFront()
    $relationFolderBox.BringToFront()
    $relationBrowseButton.BringToFront()
    $relationRepoLabel.BringToFront()
    $relationRepoBox.BringToFront()
    $relationRepoSearchButton.BringToFront()
    $relationRefreshButton.BringToFront()
    $relationCopyButton.BringToFront()
    $relationFixButton.BringToFront()
    $relationStatusLabel.BringToFront()
    $relationGraphViewport.BringToFront()
  }
  if ($Name -eq 'runlocal') {
    Update-RunLocalFilesList
    Set-RunLocalUploadInfo
  }
  if ($Name -eq 'adb' -and -not $script:adbLoaded) {
    Import-AdbTab
  }
}

# Undo / Redo buttons in the title bar: Form.bat
. $FormParts.UndoRedo

# GitHub / Cloudflare work once the window is up (Form.bat's Start part calls this).
function Invoke-FormShown {
  try {
    Update-DeployLink
  } catch {
    Set-CloudflareStatus $_.Exception.Message $true
    Show-ComBoxMessage ($_.Exception.Message) 'Could not read deploy link' $true
  }
  if ($startupRepositoryError) {
    Set-Status $startupRepositoryError $true
    Show-ComBoxMessage ($startupRepositoryError) 'Could not load saved repository URL' $true
  }
}

# First tab, window and message loop: Form.bat
. $FormParts.Start
