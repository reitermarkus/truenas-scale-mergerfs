# Install MergerFS on TrueNAS Scale

1. Add an init script to disable RootFS protection:

   | Command / Script | Description | When | Enabled | Timeout |
   |------------------|-------------|------|---------|---------|
   | `/usr/local/libexec/disable-rootfs-protection` | Disable RootFS protection | PREINIT | Yes | 10 |

2. Download `install-mergerfs.sh` to any dataset.

3. Add an init script to install MergerFS:

   | Command / Script | Description | When | Enabled | Timeout |
   |------------------|-------------|------|---------|---------|
   | `env MOUNTPOINT=<mountpoint> SUB_MOUNTPOINTS=<sub_mountpoints> /mnt/<pool>/<dataset>/install-mergerfs.sh` | Install MergerFS | PREINIT | Yes | 600 |

   ## Example

   With a dataset called `scripts` on a pool called `data`:         

   ```bash
   env MOUNTPOINT=/mnt/media SUB_MOUNTPOINTS=/mnt/media-1/media-1:/mnt/media-2/media-2:/mnt/media-3/media-3 /mnt/data/scripts/install-mergerfs.sh
   ```

   Additionally specify `NFS_USER` to create an NFS export for the `MOUNTPOINT`:

   ```bash
   env MOUNTPOINT=/mnt/media SUB_MOUNTPOINTS=/mnt/media-1/media-1:/mnt/media-2/media-2:/mnt/media-3/media-3 NFS_USER=plex /mnt/data/scripts/install-mergerfs.sh
   ```
