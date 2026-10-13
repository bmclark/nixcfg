#!/usr/bin/env bash
# iommu-check.sh — post-reboot IOMMU group inspection for hangman (ADR-015).
# Run AFTER rebooting Aurora with `intel_iommu=on` on the kernel cmdline:
#   sudo rpm-ostree kargs --append=intel_iommu=on && sudo systemctl reboot
#   bash iommu-check.sh | tee iommu.txt
set -uo pipefail

section() { printf '\n===== %s =====\n' "$1"; }

section "0. Kernel cmdline (confirm intel_iommu=on present)"
cat /proc/cmdline

section "1. IOMMU enabled in dmesg"
dmesg 2>/dev/null | grep -iE 'iommu|dmar' | head -15 \
  || sudo dmesg | grep -iE 'iommu|dmar' | head -15

section "2. IOMMU groups"
if [ -d /sys/kernel/iommu_groups ] && [ -n "$(ls /sys/kernel/iommu_groups 2>/dev/null)" ]; then
  for g in /sys/kernel/iommu_groups/*; do
    echo "Group $(basename "$g"):"
    for d in "$g"/devices/*; do
      lspci -nns "${d##*/}" 2>/dev/null | sed 's/^/  /'
    done
  done
else
  echo "FATAL: no IOMMU groups — intel_iommu=on not active. Check section 0."
  exit 1
fi

section "3. Verdict for 01:00.0 / 01:00.1 (GTX 1650 + audio)"
GPU_GROUP=$(basename "$(readlink -f /sys/bus/pci/devices/0000:01:00.0/iommu_group)")
AUD_GROUP=$(basename "$(readlink -f /sys/bus/pci/devices/0000:01:00.1/iommu_group)")
# Non-bridge devices in the GPU's group (bridges may share the group safely).
REAL_DEVS=$(for d in /sys/kernel/iommu_groups/"$GPU_GROUP"/devices/*; do
  lspci -nns "${d##*/}" 2>/dev/null | grep -vE '\[0604\]' ; done | wc -l)
echo "GPU group: $GPU_GROUP ($REAL_DEVS non-bridge device(s))"
echo "Audio group: $AUD_GROUP"
if [ "$GPU_GROUP" != "$AUD_GROUP" ]; then
  echo "VERDICT: WARNING — GPU and audio are in DIFFERENT groups. Workable but check both groups' members."
elif [ "$REAL_DEVS" -eq 2 ]; then
  echo "VERDICT: CLEAN — only the 1650 + its audio (plus bridges) in the group. Passthrough is a go."
else
  echo "VERDICT: DIRTY — group $GPU_GROUP has $REAL_DEVS real devices. See section 2."
  echo "Options: ACS override (pcie_acs_override=pcie_acs_multifunction) or different slot."
fi

echo
echo "Done. Send iommu.txt back to Bob."
