#!/usr/bin/env bash
# optiplex-preflight.sh — hardware recon for the NixOS optiplex host (ADR-015).
# Read-only: collects PCI IDs, IOMMU/VT-d status, disk layout, CPU virt flags.
# Run on the Optiplex under Aurora:  bash optiplex-preflight.sh | tee preflight.txt
set -uo pipefail

section() { printf '\n===== %s =====\n' "$1"; }

section "1. GPU / audio PCI IDs (for vfio-pci.ids)"
lspci -nn | grep -iE 'vga|3d|display|audio' || true

section "2. Current kernel cmdline"
cat /proc/cmdline

section "3. VT-d / IOMMU status (dmesg)"
dmesg 2>/dev/null | grep -iE 'iommu|dmar' | head -20 \
  || sudo dmesg | grep -iE 'iommu|dmar' | head -20 \
  || echo "dmesg needs sudo: run 'sudo dmesg | grep -iE \"iommu|dmar\"'"

section "4. IOMMU groups (if IOMMU is active)"
if [ -d /sys/kernel/iommu_groups ] && [ -n "$(ls /sys/kernel/iommu_groups 2>/dev/null)" ]; then
  for g in /sys/kernel/iommu_groups/*; do
    echo "Group $(basename "$g"):"
    for d in "$g"/devices/*; do
      lspci -nns "${d##*/}" 2>/dev/null | sed 's/^/  /'
    done
  done
else
  echo "No IOMMU groups visible — needs the intel_iommu=on reboot (see ADR-015 step 1)."
fi

section "5. Disk layout"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS,MODEL
echo
sudo fdisk -l 2>/dev/null | grep -E '^Disk /dev/' || echo "fdisk needs sudo"

section "6. Nvidia device slot"
lspci | grep -i nvidia || echo "no nvidia in lspci?"

section "7. CPU virtualization flags"
grep -cE '(^| )(vmx|ept)' /proc/cpuinfo | xargs echo "vmx/ept flag count:"
lscpu | grep -iE 'model name|virtualization'

section "8. Memory"
free -h

echo
echo "Done. Send the full output (preflight.txt) back to Bob."
