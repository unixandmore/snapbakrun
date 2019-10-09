# snapbakrun
AIX Kornshell backup script with snapshots

Configure cron to backup different directories


# Requirements

- The script requires GNU Sed.
- Requires ksh93

# Installation

## Create the directory structure

```
mkdir -p /usr/local/adm/bin
mkdir /snapshot
```

- Copy the snapbakrun.ksh script to /usr/local/adm/bin

## Mount NFS resource

```
mknfsmnt -f /mnt/backup -d 'remote filesystem' -h 'hostname'
```

# Configuration

## Modify the following variables for the target system

- **LOG**: Defaults to /tmp/snapbakrun_`DATE`.out
- **SNAPDIR**: Defaults to /snapshot
- **BACKUP_DIR**: Defaults to /backup
- **DIRLIST**: Defaults to "met page data home"
- **MAILTO**: Default is empty

- Add an entry to cron to run the script
