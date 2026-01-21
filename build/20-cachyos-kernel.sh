#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# CachyOS Kernel Installation
###############################################################################
# This script installs the CachyOS optimized kernel with advanced schedulers
# and performance enhancements. Based on the pattern from:
# https://github.com/sihawken/cachyos-kernel-aurora-dx
###############################################################################

echo "::group:: Install CachyOS Kernel"

# DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

# Create shims to bypass kernel install triggering dracut/rpm-ostree
# This allows the build to progress without errors
cd /usr/lib/kernel/install.d || exit 1
mv 05-rpmostree.install 05-rpmostree.install.bak
mv 50-dracut.install 50-dracut.install.bak
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x 05-rpmostree.install 50-dracut.install

# Install CachyOS kernel from COPR
dnf5 -y copr enable bieszczaders/kernel-cachyos
dnf5 -y remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra 
rm -rf /lib/modules/* # Remove old kernel files

# Install CachyOS kernel and development headers
dnf5 -y install kernel-cachyos kernel-cachyos-devel-matched --allowerasing

# Enable CachyOS addons repository
dnf5 -y copr enable bieszczaders/kernel-cachyos-addons

# Required to install CachyOS settings (removes conflicting file)
rm -rf /usr/lib/systemd/coredump.conf

# Install KSMD dependencies and CachyOS settings
dnf5 -y install libcap-ng libcap-ng-devel procps-ng procps-ng-devel
dnf5 -y install cachyos-settings cachyos-ksm-settings --allowerasing

# Enable Kernel Samepage Merging Daemon (KSMD) for memory optimization
tee "/usr/lib/systemd/system/ksmd.service" > /dev/null <<'EOF'
[Unit]
Description=Activates Kernel Samepage Merging
ConditionPathExists=/sys/kernel/mm/ksm

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/ksmctl -e
ExecStop=/usr/bin/ksmctl -d

[Install]
WantedBy=multi-user.target
EOF

# Enable KSMD service
ln -s /usr/lib/systemd/system/ksmd.service /etc/systemd/system/multi-user.target.wants/ksmd.service

# Restore kernel install scripts
mv -f 05-rpmostree.install.bak 05-rpmostree.install
mv -f 50-dracut.install.bak 50-dracut.install
cd - || exit 1

# Regenerate initramfs for the new kernel
releasever=$(/usr/bin/rpm -E %fedora)
basearch=$(/usr/bin/arch)
KERNEL_VERSION=$(dnf list kernel-cachyos -q | awk '/kernel-cachyos/ {print $2}' | head -n 1 | cut -d'-' -f1)-cachyos1.fc${releasever}.${basearch}

# Ensure initramfs is generated properly
depmod -a "${KERNEL_VERSION}"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"

# Disable COPR repositories after installation
dnf5 -y copr disable bieszczaders/kernel-cachyos
dnf5 -y copr disable bieszczaders/kernel-cachyos-addons

echo "::endgroup::"

echo "CachyOS kernel installation complete!"
