# =========================================================
# Audiobookshelf Podcast Cleaner
# ---------------------------------------------------------
# - Generates a list of completed podcast episodes from
#   Audiobookshelf SQLite database
# - Matches podcast folders and episode files flexibly
# - Asks for confirmation before deleting files
# - Writes a timestamped log file
#
# Tested on:
# - Windows 10/11
# - PowerShell 5.1+
# - Audiobookshelf SQLite database
# =========================================================

# =========================
# USER CONFIGURATION
# =========================

# Path to sqlite3 executable
$sqliteExe = "C:\sqlite\sqlite3.exe"

# Path to Audiobookshelf SQLite database
$dbPath = "C:\path\to\absdatabase.sqlite"

# Network or local path where podcast audio files are stored
$libraryPath = "\\NAS_IP\path\to\audiobooks"

# Working directory (script + output files)
$workDir = "C:\path\to\working_directory"

# =========================
# INTERNAL PATHS
# =========================

$outFile = Join-Path $workDir "completed_episodes.txt"
$tmpSql  = Join-Path $workDir "_generate_completed.sql"

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile   = Join-Path $workDir "cleanup_log_$timestamp.txt"

# =========================
# HELPER FUNCTIONS
# =========================

function Log($message) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $message
    Add-Content -Encoding UTF8 -Path $logFile -Value $line
    Write-Host $message
}

function Normalize-Text($text) {
    $t = $text.ToLowerInvariant()
    $t = $t.Normalize([Text.NormalizationForm]::FormD)
    $t = ($t -replace '\p{Mn}', '')
    $t = $t -replace '[:–—\-]', ' '
    $t = $t -replace '[^a-z0-9 ]', ''
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function Get-Words($text) {
    return (Normalize-Text $text).Split(' ') | Where-Object { $_.Length -gt 1 }
}

function Word-MatchScore($wordsA, $wordsB) {
    if ($wordsA.Count -eq 0) { return 0 }
    $common = $wordsA | Where-Object { $wordsB -contains $_ }
    return $common.Count / $wordsA.Count
}

# =========================
# START
# =========================

Log "Starting Audiobookshelf podcast cleanup"

# =========================
# STEP 1: Generate completed episodes list
# =========================

@"
.mode list
.separator | 
.output $outFile

SELECT
  TRIM(p.title) AS podcast,
  TRIM(
    REPLACE(
      REPLACE(e.title, CHAR(10), ' '),
      CHAR(13), ' '
    )
  ) AS episode
FROM mediaProgresses mp
JOIN podcastEpisodes e ON mp.mediaItemId = e.id
JOIN podcasts p ON e.podcastId = p.id
WHERE mp.isFinished = 1
ORDER BY podcast COLLATE NOCASE,
         episode COLLATE NOCASE;

.output stdout
.quit
"@ | Set-Content -Encoding UTF8 $tmpSql

Get-Content $tmpSql | & $sqliteExe $dbPath
Remove-Item $tmpSql -Force

if (-not (Test-Path $outFile)) {
    Log "ERROR: completed_episodes.txt was not generated"
    exit 1
}

Log "Completed episodes list generated"

# =========================
# STEP 2: Identify files to delete
# =========================

$podcastFolders = Get-ChildItem -LiteralPath $libraryPath -Directory
$filesToDelete = @()

Get-Content -Path $outFile -Encoding UTF8 | ForEach-Object {

    $line = $_.Trim()
    if (-not ($line -match '\|')) { return }

    $parts = $line -split '\|', 2
    $podcastName  = $parts[0].Trim()
    $episodeTitle = $parts[1].Trim()

    $podcastWords = Get-Words $podcastName
    $episodeWords = Get-Words $episodeTitle

    # Match podcast folder
    $bestFolder = $null
    $bestScore  = 0

    foreach ($folder in $podcastFolders) {
        $score = Word-MatchScore $podcastWords (Get-Words $folder.Name)
        if ($score -gt $bestScore) {
            $bestScore = $score
            $bestFolder = $folder
        }
    }

    if (-not $bestFolder -or $bestScore -lt 0.6) {
        Log "Podcast folder not identified: $podcastName"
        return
    }

    # Match episode file
    $files = Get-ChildItem -LiteralPath $bestFolder.FullName -File
    $bestFile = $null
    $bestFileScore = 0

    foreach ($file in $files) {
        $score = Word-MatchScore $episodeWords (Get-Words $file.BaseName)
        if ($score -gt $bestFileScore) {
            $bestFileScore = $score
            $bestFile = $file
        }
    }

    if ($bestFile -and $bestFileScore -ge 0.6) {
        $filesToDelete += $bestFile
        Log "CANDIDATE: $($bestFile.FullName)"
    }
    else {
        Log "Episode not identified: $podcastName | $episodeTitle"
    }
}

# =========================
# STEP 3: Confirmation
# =========================

Log "Total files selected for deletion: $($filesToDelete.Count)"
$choice = Read-Host "Proceed with deletion? (Y/N)"

if ($choice.ToUpper() -ne "Y") {
    Log "Operation cancelled by user"
    exit 0
}

# =========================
# STEP 4: Deletion
# =========================

foreach ($file in $filesToDelete) {
    if (Test-Path -LiteralPath $file.FullName) {
        try {
            Remove-Item -LiteralPath $file.FullName -Force
            Log "DELETED: $($file.FullName)"
        }
        catch {
            Log "ERROR deleting $($file.FullName): $($_.Exception.Message)"
        }
    }
    else {
        Log "File not found at deletion time: $($file.FullName)"
    }
}

Log "Cleanup finished. Files deleted: $($filesToDelete.Count)"
