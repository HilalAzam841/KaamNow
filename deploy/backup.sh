#!/bin/sh
# Daily backup: database dump plus uploaded files. Runs inside the `backup` container,
# or by hand: docker compose exec backup sh /usr/local/bin/kaamnow-backup
# Files land in deploy/backups/ on the server. Copy them off the server too (see deploy/README.md).
set -eu
umask 077
stamp=$(date +%Y%m%d-%H%M%S)
cd /backups

pg_dump --format=custom --file="db-$stamp.dump.part"
mv "db-$stamp.dump.part" "db-$stamp.dump"
# CNIC documents: private, kept with owner-only permissions (umask 077).
tar -czf "private-media-$stamp.tar.gz.part" -C /private_media .
mv "private-media-$stamp.tar.gz.part" "private-media-$stamp.tar.gz"
tar -czf "media-$stamp.tar.gz.part" -C /media .
mv "media-$stamp.tar.gz.part" "media-$stamp.tar.gz"

# Keep the last BACKUP_KEEP_DAYS days.
find /backups -maxdepth 1 -type f \( -name 'db-*.dump' -o -name '*media-*.tar.gz' \) \
  -mtime +"${BACKUP_KEEP_DAYS:-14}" -delete
echo "backup $stamp done: $(ls -1 /backups | wc -l) files kept"
