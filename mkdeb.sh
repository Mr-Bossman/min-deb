#!/bin/bash
sudo apt-get update
sudo apt-get -y install gawk wget git diffstat unzip texinfo \
     build-essential chrpath socat ncurses-dev lzop \
     gcc debootstrap  bc rsync bison flex libelf-dev

git submodule update --init
cp defconfig linux/arch/x86/configs/x86_64_defconfig
cd linux

test -e .config || make x86_64_defconfig
make deb-pkg -j10

cd ..



sudo rm -rf output/rootfs/
sudo rm output/sdcard.img
mkdir -p output 
mkdir -p output/rootfs
dd if=/dev/zero of=output/sdcard.img bs=1M count=2000
cat <<EOT | sudo  fdisk -u output/sdcard.img
g
n


+500M
t
uefi
n



w
EOT
_loop=$(sudo losetup -f)
sudo losetup -P $_loop output/sdcard.img
sudo mkfs.vfat ${_loop}p1
sudo mkfs.ext4 ${_loop}p2
sudo sync
sudo mount ${_loop}p2 output/rootfs

sudo debootstrap --variant=minbase --components=main,non-free --include=systemd-sysv,console-setup buster output/rootfs http://deb.debian.org/debian/
sudo cp *.deb output/rootfs/
sudo mount ${_loop}p1 output/rootfs/boot
sudo mkdir output/rootfs/boot/EFI
sudo mkdir output/rootfs/boot/EFI/boot

sudo chroot output/rootfs/ /bin/bash <<EOT
mount -t devtmpfs dev /dev
mount -t devpts dev/pts /dev/pts
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t tmpfs tmpfs /tmp
apt install -y dialog makedev nano tasksel htop neofetch
echo "0.0 0 0.0 0 LOCAL" > /etc/adjtime export LANGUAGE=en_US.UTF-8 export LANG=en_US.UTF-8 export LC_ALL=en_US.UTF-8 echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen locale-gen en_US.UTF-8
apt install -y locales
apt install -y iputils-ping iproute2
#tasksel install standard # this is extra
dpkg -i /*.deb
echo -e "password\npassword" | passwd
umount /sys
umount /proc
umount /dev/pts
umount /dev
umount /tmp
EOT
sudo cp linux/arch/x86_64/boot/bzImage output/rootfs/boot/EFI/boot/bootx64.efi
sudo cp linux/arch/x86_64/boot/bzImage output/rootfs/boot/EFI/boot/mmx64.efi
rm -rf linux-* linux.orig linux/debian

echo "test" | sudo tee output/rootfs/etc/hostname


cat <<EOT | sudo tee output/rootfs/etc/fstab
/dev/sda2 /               ext4    errors=remount-ro 0 1
#/dev/sda1 /boot           vfat    defaults 0 2
proc           /proc           proc        defaults         0     0
sysfs          /sys            sysfs       defaults         0     0
tmpfs          /tmp            tmpfs       defaults         0     0
devtmpfs       /dev            devtmpfs    mode=0755,nosuid 0     0
devpts         /dev/pts        devpts      gid=5,mode=620   0     0
EOT

sudo umount output/rootfs/boot
sudo umount -l output/rootfs
sudo losetup -d $_loop

