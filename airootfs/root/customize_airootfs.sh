#!/bin/bash

set -e -u -x

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

usermod -s /usr/bin/zsh root
cp -aT /etc/skel/ /root/ || true
chmod 700 /root

sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

systemctl enable pacman-init.service choose-mirror.service xkcd.service
# systemctl set-default multi-user.target
systemctl set-default graphical.target

# echo "KEYMAP=fr-latin1" > /etc/vconsole.conf

# ln -sf /usr/share/zoneinfo/UTC /etc/localtime
test -e /etc/localtime && unlink /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

# ln -s /usr/lib/systemd/system/gdm.service /etc/systemd/system/display-manager.service
# systemctl enable gdm.service

# systemctl enable NetworkManager.service

sed -i 's/#\(Color\)/\1/' /etc/pacman.conf


unlink /etc/fonts/conf.d/10-autohint.conf || true
unlink /etc/fonts/conf.d/10-hinting-none.conf || true
unlink /etc/fonts/conf.d/10-hinting-slight.conf || true
unlink /etc/fonts/conf.d/10-hinting-medium.conf || true
unlink /etc/fonts/conf.d/10-hinting-full.conf || true
ln -sv /etc/fonts/conf.{avail,d}/10-hinting-none.conf

unlink /etc/fonts/conf.d/10-no-sub-pixel.conf || true
unlink /etc/fonts/conf.d/10-sub-pixel-bgr.conf || true
unlink /etc/fonts/conf.d/10-sub-pixel-rgb.conf || true
unlink /etc/fonts/conf.d/10-sub-pixel-vbgr.conf || true
unlink /etc/fonts/conf.d/10-sub-pixel-vrgb.conf || true
ln -sv /etc/fonts/conf.{avail,d}/10-sub-pixel-rgb.conf

unlink /etc/fonts/conf.d/11-lcdfilter-default.conf || true
unlink /etc/fonts/conf.d/11-lcdfilter-light.conf || true
unlink /etc/fonts/conf.d/11-lcdfilter-legacy.conf || true
ln -sv /etc/fonts/conf.{avail,d}/11-lcdfilter-light.conf

NEW_USER=mc
if [ ! "$(id $NEW_USER)" ]; then
    cd /usr/share/fonts/100dpi/ && mkfontdir && cd -
    cd /usr/share/fonts/75dpi/ && mkfontdir && cd -

    useradd -m -g users -G wheel -s /bin/zsh $NEW_USER
    echo "$NEW_USER:$NEW_USER" | chpasswd
    echo "root:$NEW_USER" | chpasswd

    rm -f /{home/$NEW_USER,root}/.bashrc

    /root/config-files/install.sh --no-private
    su $NEW_USER -c "/home/$NEW_USER/config-files/install.sh --no-private"

	rm -rf /root/config-files
	ln -sv /home/$NEW_USER/config-files /root/config-files

	emacs -nw --kill || true
	chown -R $NEW_USER:users /home/$NEW_USER/config-files

    rm -rf /{etc/skel,root}/.mozilla
fi

sed -i 's/^\(%wheel ALL=(ALL) ALL\)/# \1/' /etc/sudoers
sed -i 's/# \(%wheel ALL=(ALL) NOPASSWD: ALL\)/\1/' /etc/sudoers

pacman-key --init
pacman-key --populate archlinux
yaourt -Sy --devel --aur
# gpg --recv-keys --keyserver hkp://pgp.mit.edu 1EB2638FF56C0C53 #cower

AUR_PKG="aic94xx-firmware
colormake
i3blocks
idutils
global
neofetch
playerctl
multimarkdown
peda
rxvt-unicode-fontspacing-noinc-vteclear-secondarywheel
sloccount
ttf-monaco
urxvt-resize-font-git
urxvt-tabbedex-git
wd719x-firmware
zsh-autosuggestions"
# roswell

for p in $AUR_PKG; do
    su $NEW_USER -c "yaourt --noconfirm -S $p" #yolo
done
su $NEW_USER -c "gem install oauth2"
# su $NEW_USER -c "ros install"
# su $NEW_USER -c "ros install caveman2"
# su $NEW_USER -c "ros install clack"
# su $NEW_USER -c "ros install hunchentoot"
# su $NEW_USER -c "ros install woo"
# su $NEW_USER -c "ros install slime"

sed -i 's/# \(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers
sed -i 's/^\(%wheel ALL=(ALL) NOPASSWD: ALL\)/# \1/' /etc/sudoers

updatedb

# zsh
