---
title: "Using rsync for backup"
description: "Simple command to (safely) backup the home directory of a user"
category: "utility"
tags: ["linux", "utility", "backup", "rsync"]
created: 2026-01-29
---

## Home Dir full backup

```bash
sudo rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" \
    /home/ /mnt/usbdrive-name/
```

# General incremental file transfer

## Local to Local:

```bash
rsync [OPTION]... [SRC]... DEST
```

## Local to Remote:

```bash
rsync [OPTION]... [SRC]... [USER@]HOST:DEST
```

## Remote to Local:

```bash
rsync [OPTION]... [USER@]HOST:SRC... [DEST]
```
