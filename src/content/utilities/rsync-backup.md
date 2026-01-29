---
title: "Using rsync for backup"
description: "Simple command to (safely) backup the home directory of a user"
category: "utility"
tags: ["linux", "utility", "backup", "rsync"]
created: 2026-01-29
---

Simply use:

```bash
sudo rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" /home/ /mnt/usbdrive-name/
```