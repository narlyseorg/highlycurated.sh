# highlycurated.sh

A file organization utility for macOS that automatically categorizes files in the Downloads directory based on their extensions.

---

## Abstract

Modern computing workflows often result in accumulated files within the system's default download location. This utility provides an automated solution that monitors the `~/Downloads` directory and relocates files into predefined categorical subdirectories based on file extension analysis.

The implementation prioritizes:
- POSIX-compliant shell scripting (Bash 3.2+)
- Atomic locking mechanisms to prevent concurrent execution conflicts
- Case-insensitive extension matching
- Conflict resolution through sequential suffix enumeration

---

## System Requirements

- macOS 10.14 (Mojave) or later
- Automator.app (included with macOS)
- No additional dependencies

---

## File Categories

The utility classifies files into the following categories:

| Category | Extensions |
|----------|------------|
| Documents | doc, docx, odt, pdf, xls, xlsx, ods, csv, ppt, pptx, odp, pages, numbers, txt, rtf, md, tex, log, epub, mobi, wps, msg, wpd |
| Scripts | py, ipynb, js, jsx, ts, tsx, html, css, scss, java, class, jar, c, cpp, h, cs, php, swift, go, rb, pl, rs, sh, bash, zsh, bat, ps1, lua, r, sql, sqlite, db, json, xml, yaml, yml, toml, ini, cfg, config, env, htaccess, gitignore, pkl, kt, dart |
| Images | jpg, jpeg, png, gif, webp, tiff, tif, bmp, heic, svg, ico, psd, ai, eps, indd, raw, cr2, nef, orf, arw, dng, xcf |
| Compressed | zip, rar, 7z, tar, gz, tgz, bz2, tbz, xz, zst |
| Programs | app, pkg, exe, msi, apk, xapk, ipa, apkm, deb, rpm, appx, bin, dmg |
| Certificates | pem, crt, cer, der, p12, pfx, pki, pub, key, gpg, ovpn, asc |
| Videos | mp4, mkv, mov, avi, wmv, flv, webm, m4v, mpg, mpeg, 3gp, ts, vob, srt, ass |
| Music | mp3, wav, aac, flac, ogg, m4a, wma, alac, mid, midi |
| Disks | iso, ova, vdi, vbox, vmdk, qcow2, img |
| Fonts | ttf, otf, woff, woff2 |
| Torrents | torrent |
| Others | Unrecognized extensions |

Additionally, files matching common extensionless naming conventions (e.g., `Dockerfile`, `Makefile`, `LICENSE`, `README`) are classified under Scripts.

---

## Installation

### Step 1: Deploy the Script

Copy the shell script to the user Scripts directory:

```bash
mkdir -p ~/Library/Scripts
cp highlycurated.sh ~/Library/Scripts/
chmod +x ~/Library/Scripts/highlycurated.sh
```

Verify the script executes without errors:

```bash
/bin/bash ~/Library/Scripts/highlycurated.sh
```

### Step 2: Create Automator Folder Action

1. Open **Automator.app** (located in `/Applications/Automator.app`)

2. Select **New Document** when prompted

3. Choose **Folder Action** as the document type

4. At the top of the workflow, locate the dropdown labeled:
   ```
   Folder Action receives files and folders added to
   ```
   Click the dropdown and select **Other...**, then navigate to and select:
   ```
   ~/Downloads
   ```

5. From the Actions library (left sidebar), search for **Run Shell Script**

6. Drag the **Run Shell Script** action into the workflow area

7. Configure the action as follows:
   - **Shell**: `/bin/bash`
   - **Pass input**: `as arguments`
   - **Script content**:
     ```bash
     /bin/bash ~/Library/Scripts/highlycurated.sh
     ```

8. Save the workflow:
   - Press `Cmd + S`
   - Name it `HighlyCurated` (or any preferred identifier)
   - The file will be automatically saved to `~/Library/Workflows/Applications/Folder Actions/`

### Step 3: Verification

1. Download any file using Safari or another browser

2. Observe that the file is automatically moved to the appropriate category folder within `~/Downloads/`

3. Review the log file for execution details:
   ```bash
   tail -f ~/Library/Logs/highlycurated.log
   ```

---

## Configuration

The following variables may be modified at the top of `highlycurated.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOWNLOADS_DIR` | `$HOME/Downloads` | Source directory to monitor |
| `LOG_FILE` | `$HOME/Library/Logs/highlycurated.log` | Log file location |
| `LOCK_FILE` | `/tmp/highlycurated.lock` | Lock file for concurrency control |
| `MAX_LOG_SIZE` | `1048576` | Maximum log size in bytes before rotation (1 MB) |

---

## Technical Notes

### Concurrency Control

The script implements an atomic locking mechanism using shell `noclobber` mode to prevent race conditions when multiple triggers occur simultaneously. Stale locks (from terminated processes) are automatically detected and cleared.

### Skipped Files

The following are intentionally ignored:
- Hidden files (prefixed with `.`)
- Incomplete downloads: `.crdownload`, `.download`, `.part`, `.tmp`, `.opdownload`
- System files: `.DS_Store`, `.localized`
- Subdirectories and their contents

### Conflict Resolution

When a file with the same name exists in the destination directory, a numerical suffix is appended:
```
example.pdf → example (2).pdf → example (3).pdf
```

---

## Troubleshooting

**Permission denied errors**

Ensure the script has execute permissions:
```bash
chmod +x ~/Library/Scripts/highlycurated.sh
```

**Log file not created**

Manually create the log directory:
```bash
mkdir -p ~/Library/Logs
```

---

## License

MIT License. See LICENSE file for details.

---

## References

- Apple Developer Documentation: Folder Actions Reference
- POSIX.1-2017 Shell Command Language Specification
- GNU Bash Reference Manual, Version 3.2
