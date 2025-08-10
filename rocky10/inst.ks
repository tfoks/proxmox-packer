# Partition clearing information
clearpart --all --initlabel
# Use graphical install
# graphical
# Use CDROM installation media
cdrom
text
# Keyboard layouts
keyboard de
# System language
lang en_US

# Root password
rootpw Packer
# Run the Setup Agent on first boot
firstboot --disable
# Do not configure the X Window System
skipx
# System services
services --disabled="kdump" --enabled="sshd,rsyslog,chronyd"
# System timezone
timezone Europe/Berlin --utc
# Disk partitioning information
part /boot/efi --fstype vfat --size 600 --ondisk=sda
part / --fstype xfs --size 2048 --grow --ondisk=sda
reboot

%packages
@^minimal-environment
# Exclude unnecessary firmwares
-iwl*firmware
# add packages
kexec-tools
krb5-workstation
bind-utils
cloud-init
cloud-utils-growpart
qemu-guest-agent
git
tmux
zsh
# allow for ansible
python3.12
python3.12-pip

# unnecessary firmware
-aic94xx-firmware
-atmel-firmware
-b43-openfwwf
-bfa-firmware
-ipw2100-firmware
-ipw2200-firmware
-ivtv-firmware
-iwl100-firmware
-iwl1000-firmware
-iwl3945-firmware
-iwl4965-firmware
-iwl5000-firmware
-iwl5150-firmware
-iwl6000-firmware
-iwl6000g2a-firmware
-iwl6050-firmware
-libertas-usb8388-firmware
-ql2100-firmware
-ql2200-firmware
-ql23xx-firmware
-ql2400-firmware
-ql2500-firmware
-rt61pci-firmware
-rt73usb-firmware
-xorg-x11-drv-ati-firmware
-zd1211-firmware
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%post

# this is installed by default but we don't need it in virt
echo "Removing linux-firmware package."
dnf -C -y remove linux-firmware

# Remove firewalld; it is required to be present for install/image building.
echo "Removing firewalld."
dnf -C -y remove firewalld --setopt="clean_requirements_on_remove=1"

# remove avahi and networkmanager
echo "Removing avahi/zeroconf and NetworkManager"
dnf -C -y remove avahi\* 

echo -n "Getty fixes"
# although we want console output going to the serial console, we don't
# actually have the opportunity to login there. FIX.
# we don't really need to auto-spawn _any_ gettys.
sed -i '/^#NAutoVTs=.*/ a\
NAutoVTs=0' /etc/systemd/logind.conf

# set virtual-guest as default profile for tuned
echo "virtual-guest" > /etc/tuned/active_profile

# Because memory is scarce resource in most cloud/virt environments,
# and because this impedes forensics, we are differing from the Fedora
# default of having /tmp on tmpfs.
echo "Disabling tmpfs for /tmp."
systemctl mask tmp.mount

cat <<EOL > /etc/sysconfig/kernel
# UPDATEDEFAULT specifies if new-kernel-pkg should make
# new kernels the default
UPDATEDEFAULT=yes

# DEFAULTKERNEL specifies the default kernel package type
DEFAULTKERNEL=kernel
EOL

# make sure firstboot doesn't start
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

echo "Fixing SELinux contexts."
touch /var/log/cron
touch /var/log/boot.log
mkdir -p /var/cache/dnf
/usr/sbin/fixfiles -R -a restore

# reorder console entries
sed -i 's/console=tty0/console=tty0 console=ttyS0,115200n8/' /boot/grub2/grub.cfg

dnf update -y

# add a datasource to cloud-init configuration
# datasoure: nocloud
# datasource_list: ['NoCloud', 'ConfigDrive', 'None']
# sed -i "s/^# datasource:/datasource_list: \[\'NoCloud\', \'ConfigDrive\', \'None\'\]\\ndatasource: nocloud\\nunverified_modules: ['ssh-import-id','ca-certs']/" /etc/cloud/cloud.cfg
echo "datasource_list: [ NoCloud, ConfigDrive ]" > /etc/cloud/cloud.cfg.d/99_pve.cfg
# remove config_scripts_per_instance semaphore to allow a new run when template clone starts
find /var/lib/cloud/instances -name "config_scripts_per_instance" -exec rm -f {} \;

sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/allow-root-ssh.conf

dnf clean all
%end
