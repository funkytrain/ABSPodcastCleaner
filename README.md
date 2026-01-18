# Audiobookshelf Podcast Cleaner

A PowerShell script that automatically removes **fully listened podcast episodes**
from an Audiobookshelf library, based on playback progress stored in the
Audiobookshelf SQLite database.

It is designed for users running Audiobookshelf on a NAS or server
and accessing the media files from Windows.

---

## ✨ Features

- Reads completed episodes directly from Audiobookshelf SQLite database
- Flexible matching for:
  - podcast folder names
  - episode file names
- Handles accents, punctuation, and renaming differences
- Interactive confirmation before deleting files
- Timestamped log file for full traceability
- Safe by design: never modifies the database

---

## ⚠️ Important Notes

- **Files are deleted from disk**, not from the database
- Audiobookshelf will automatically clean up references after a library rescan
- Always test on a backup or small subset first

---

## 🛠 Requirements

- Windows 10 / 11
- PowerShell 5.1 or newer
- `sqlite3.exe` (official SQLite tools)
- Audiobookshelf with SQLite database (`absdatabase.sqlite`)
- Network or local access to podcast audio files

---

## 📦 Installation

1. Clone this repository or download the script:
   ```bash
   git clone https://github.com/yourusername/audiobookshelf-podcast-cleaner.git
   ```

2. Download SQLite tools for Windows  
   https://www.sqlite.org/download.html

3. Extract `sqlite3.exe` to a known location, e.g.:
   ```
   C:\sqlite\sqlite3.exe
   ```

---

## ⚙️ Configuration

Edit the following variables at the top of the script:

```powershell
$sqliteExe   = "C:\sqlite\sqlite3.exe"
$dbPath      = "C:\path\to\absdatabase.sqlite"
$libraryPath = "\\NAS_IP\path\to\audiobooks"
$workDir     = "C:\path\to\working_directory"
```

- **dbPath**: path to Audiobookshelf SQLite database
- **libraryPath**: root folder containing podcast folders
- **workDir**: folder where logs and temporary files will be created

---

## ▶️ Usage

1. Open PowerShell
2. Navigate to the script directory
3. Allow script execution (once):
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
4. Run:
   ```powershell
   .\cleanup_audiobookshelf_podcasts.ps1
   ```

5. Review detected files
6. Confirm deletion by typing **Y**

---

## 📝 Logs

Each run generates a log file:

```
cleanup_log_YYYY-MM-DD_HH-MM-SS.txt
```

The log includes:
- detected episodes
- matched files
- deleted files
- errors or skipped items

---

## 🔐 Safety

- The script **never modifies the database**
- Deletion requires explicit user confirmation
- Files are verified before deletion
- Unmatched episodes are logged but not touched

---

## 📄 License

MIT License – use, modify and share freely.

---

## 🤝 Contributing

Issues and pull requests are welcome!
Please include logs (with private paths removed) when reporting problems.
