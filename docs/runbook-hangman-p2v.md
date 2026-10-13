# Runbook: Windows 10 P2V image + Tower backup (hangman prep)

Order matters: image first, verify, then copy to Tower. Do everything
booted into Aurora with Windows NOT running.

## 0. Prereqs (on Aurora)

```bash
# qemu-img comes with the virt stack; check first
qemu-img --version || sudo rpm-ostree install qemu-img
```

Check free space on sdc (need roughly the *used* size of sdb, since qcow2
is sparse — check with `sudo fdisk -l /dev/sdb` usage or just ensure
~150G free):

```bash
df -h /path/to/sdc/mountpoint
```

## 1. Convert sdb to qcow2

```bash
sudo qemu-img convert -p -O qcow2 /dev/sdb /path/to/sdc/win10.qcow2
sudo chown bryan: /path/to/sdc/win10.qcow2
```

- `-p` = progress bar. Takes 30–90 min depending on disk speed.
- No `-c` (compression): qcow2 is already sparse; compression slows VM I/O.
- The image is BOTH the backup and the future VM disk.

## 2. Verify

```bash
qemu-img check /path/to/sdc/win10.qcow2
qemu-img info /path/to/sdc/win10.qcow2
```

`check` must report no errors. `info` should show `virtual size: 232 GiB`
and a much smaller `disk size` (actual used). The definitive verification
is booting it as a VM after hangman is installed (needs OVMF/UEFI firmware
— the install is GPT) — do that before wiping anything or relying on it.

## 3. Back up to Tower (over Tailscale)

Single-shot rsync with checksum (size+time is meaningless for a fresh file,
and we want the copy proven):

```bash
rsync -av --checksum --progress \
  /path/to/sdc/win10.qcow2 \
  bryan@tower:/mnt/user/backups/hangman-p2v/
```

- Adjust the Tower destination path to wherever bulk backups live there.
- `--checksum` forces a full read of both sides at the end — slow but it
  proves the copy. Run it once; later refreshes can drop it.
- If the tailnet name differs, use `tailscale status` to find Tower's name.

Verify on Tower:

```bash
ssh bryan@tower 'sha256sum /mnt/user/backups/hangman-p2v/win10.qcow2'
sha256sum /path/to/sdc/win10.qcow2
```

Hashes must match.

## 4. After hangman is installed

1. Boot win10.qcow2 in virt-manager: new VM, "Import existing disk",
   select the qcow2, firmware **UEFI/OVMF**, chipset Q35.
2. Expect Windows first-boot driver churn (virtio disk + passed-through
   1650) and possibly a license reactivation prompt — known P2V cost.
3. Only after the VM has run well for a couple of weeks: consider wiping
   sdb for storage. Until then it stays as the cold original.
