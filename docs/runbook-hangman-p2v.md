# Runbook: hangman prep — Windows 10 LTSC P2V image, Tower backups

Complete pre-install checklist for the Optiplex (hangman) conversion.
Everything here happens BEFORE NixOS touches sda. Order matters.

Safety layers when done:
1. `win10.qcow2` on sdc — machine image (backup + future VM disk)
2. `win10.qcow2` on Tower — off-box copy of the same
3. File History on Tower — versioned user files (file-level recovery)

All Aurora-side steps run with Windows NOT running (booted into Aurora).

---

## Phase 1 — qcow2 image (Aurora)

### 1.0 Use the helper

```bash
export SDC_MNT=/run/media/bryan/7748b39d-220e-4e8f-966f-740e8ec18c98
export TOWER=bryan@tower
export TOWER_PATH=/mnt/user/Bryan/win-10-backup   # SMB share Bryan/win-10-backup

bash p2v.sh convert   # phase 1
bash p2v.sh check     # phase 1 verify
bash p2v.sh tower      # phase 2, hashes both sides and fails on mismatch
bash p2v.sh all        # everything in order
```

Helper lives at `hosts/hangman/p2v.sh` in this repo. Manual equivalents
below.

### 1.1 Prereqs

```bash
qemu-img --version || sudo rpm-ostree install qemu-img
df -h /path/to/sdc/mountpoint    # want ~150G free (qcow2 is sparse)
```

### 1.2 Convert sdb → qcow2 (30–90 min, unattended)

```bash
sudo qemu-img convert -p -O qcow2 /dev/sdb /path/to/sdc/win10.qcow2
sudo chown bryan: /path/to/sdc/win10.qcow2
```

No `-c` compression: qcow2 is already sparse; compression slows VM I/O.

### 1.3 Verify

```bash
qemu-img check /path/to/sdc/win10.qcow2   # must report no errors
qemu-img info /path/to/sdc/win10.qcow2    # virtual ~232G, disk size = used
```

Definitive verification = booting it as a VM after hangman is installed
(UEFI/OVMF firmware — the install is GPT; chipset Q35).

---

## Phase 2 — Tower copy of the image (Aurora)

### 2.1 rsync with checksum proof

```bash
rsync -av --checksum --progress \
  /path/to/sdc/win10.qcow2 \
  bryan@tower:/mnt/user/backups/hangman-p2v/
```

Adjust the Tower path to the real bulk-backup share. `--checksum` proves
the copy byte-for-byte; drop it on later refreshes.

### 2.2 Hash both sides

```bash
ssh bryan@tower 'sha256sum /mnt/user/backups/hangman-p2v/win10.qcow2'
sha256sum /path/to/sdc/win10.qcow2
```

Must match. Tower share needs ~150G free and should not be a
snapraid/parity array member that churns on a one-off huge file.

---

## Phase 3 — File History, Windows → Tower (from Windows)

Built-in, versioned, file-level backup of the user profile. Complements
the qcow2 (which protects the whole machine, but only as of today).

### 3.1 Tower side — SMB share

Unraid: create share (e.g. `win10-filehistory`), enable SMB export,
user `bryan` with write access. Verify from Windows:
`\\tower\win10-filehistory` reachable over the tailnet.

### 3.2 Windows side — enable File History

Control Panel → System and Security → **File History**:
1. Select drive → **Add a network location** → `\\tower\win10-filehistory`
2. Turn on.
3. Exclude folders: `AppData\Local`, `AppData\LocalLow` if coverage gets
   noisy — caches are regenerable. `AppData\Roaming` stays (real app state).
4. Advanced settings: save copies hourly (default), keep versions
   "until space is needed" or a set retention (e.g. 6 months).

First run duration depends on profile size; it runs in the background.

### 3.3 Notes

- File History covers libraries/profile folders (Documents, Desktop,
  Pictures, AppData\Roaming). Anything outside `C:\Users\bryan`
  (e.g. game saves under `ProgramData`) must be added manually or
  accepted as uncovered.
- Works identically once Windows is a VM on hangman (bridged network
  reaches Tower the same way).
- Deprecated-ish but present and functional in Win10 LTSC.

---

## Phase 4 — after hangman is installed (later, separate session)

1. Boot win10.qcow2 in virt-manager: Import existing disk, firmware
   **UEFI/OVMF**, chipset Q35.
2. Expect first-boot driver churn (virtio + passed-through 1650) and
   possibly a license reactivation prompt — known P2V cost.
3. Re-point File History at the same Tower share from inside the VM.
4. Only after the VM has run well for a couple of weeks: consider
   wiping sdb for storage. Until then it stays as the cold original.

## LTSC note

Windows 10 LTSC: no feature-update churn, long support window. The qcow2
is a stable artifact worth keeping; File History covers the user data
that changes. wbadmin system image is intentionally skipped — redundant
with the qcow2.
