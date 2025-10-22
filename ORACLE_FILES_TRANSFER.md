# Oracle Tools Tarball Transfer Instructions

This guide explains how to archive the `oracle-*` directories from `/tools/ver` on the source Red Hat Linux server, transfer the archive to a new server, and restore the files in the correct location.

## 1. Create the compressed tar archive on the source server
Run the following command on the source server to create a gzip-compressed tarball that contains every directory that matches `oracle-*` under `/tools/ver`:

```bash
sudo tar -czf /tmp/oracle-tools.tar.gz -C /tools/ver oracle-*
```

- `sudo` ensures you have sufficient privileges to read the directories.
- `tar -czf` creates a compressed archive (`-c`), uses gzip compression (`-z`), and writes to the specified file (`-f /tmp/oracle-tools.tar.gz`).
- `-C /tools/ver` changes to the `/tools/ver` directory before adding files, so only the `oracle-*` directories are included in the archive.

## 2. Copy the archive to the target server
Use `scp` (secure copy) from the source server to transfer the tarball to `/tmp` on the target server. Replace `target_user` and `target_server` with the appropriate SSH username and hostname (or IP address):

```bash
scp /tmp/oracle-tools.tar.gz target_user@target_server:/tmp/
```

If you are initiating the copy from the target server, reverse the arguments:

```bash
scp source_user@source_server:/tmp/oracle-tools.tar.gz /tmp/
```

## 3. Extract the archive on the target server
On the target server, recreate the directory structure and extract the archive back into `/tools/ver`:

```bash
sudo mkdir -p /tools/ver
sudo tar -xzf /tmp/oracle-tools.tar.gz -C /tools/ver
```

- `sudo mkdir -p /tools/ver` ensures the destination directory exists.
- `tar -xzf` extracts (`-x`) the gzip-compressed archive (`-z`) specified by `-f /tmp/oracle-tools.tar.gz`.
- `-C /tools/ver` extracts the contents into the `/tools/ver` directory, restoring the `oracle-*` directories to their original location.

## 4. (Optional) Verify the restored files
After extraction, verify that the expected directories exist on the target server:

```bash
ls -d /tools/ver/oracle-*
```

This command lists all directories that match `oracle-*` to confirm they were restored successfully.

## 5. (Optional) Remove the temporary archive
Once you have confirmed the files are in place on both servers, you can safely delete the temporary archive from `/tmp` on each server:

```bash
sudo rm -f /tmp/oracle-tools.tar.gz
```

This prevents stale archives from accumulating on the systems.
