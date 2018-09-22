#!/bin/bash

set -e -u -x

NEW_USER=mc

AUR_PKG="aic94xx-firmware
colormake
ggtags
global
grc
idutils
ledger
multimarkdown
neofetch
peda
playerctl
rxvt-unicode-better-wheel-scrolling
sloccount
tor-browser
ttf-monaco
urxvt-resize-font-git
urxvt-tabbedex-mina86-git
urxvt-perls
wd719x-firmware
zsh-autosuggestions"
# roswell

init_customization() {
    # TODO: pacman wasn't bitching about space before
    sed -i 's/^\(CheckSpace\)/#\1/' /etc/pacman.conf

    # allow sudo without password
    sed -i 's/^\(%wheel ALL=(ALL) ALL\)/# \1/' /etc/sudoers
    sed -i 's/# \(%wheel ALL=(ALL) NOPASSWD: ALL\)/\1/' /etc/sudoers

    pacman-key --init
    pacman-key --populate archlinux
}

misc_config() {
    sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
    locale-gen

    usermod -s /usr/bin/zsh root
    cp -aT /etc/skel/ /root/ || true
    chmod 700 /root

    sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
    # sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
    sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

    sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
    sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
    sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

    # systemctl enable pacman-init.service choose-mirror.service xkcd.service
    # TODO: enable these after install

    systemctl set-default graphical.target

    sed -i 's/#\(Color\)/\1/' /etc/pacman.conf

    sed -i -E 's|Exec=(.*)|Exec=/usr/bin/gksudo \1|' /usr/share/applications/gparted.desktop
}

time_config() {
    # ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    test -e /etc/localtime && unlink /etc/localtime
    ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
    hwclock --systohc
}

font_config() {
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
}

create_new_user() {
    if [ ! "$(id $NEW_USER)" ]; then
        cd /usr/share/fonts/100dpi/ && mkfontdir && cd -
        cd /usr/share/fonts/75dpi/ && mkfontdir && cd -

        useradd -m -g users -G wheel -s /bin/zsh $NEW_USER
        echo "$NEW_USER:$NEW_USER" | chpasswd
        echo "root:$NEW_USER" | chpasswd

        rm -f /{home/$NEW_USER,root}/.bashrc

        /root/config-files/install.sh --no-private
        su $NEW_USER -c "/home/$NEW_USER/config-files/install.sh --no-private"

        if ! [ -d /home/$NEW_USER/config-files/.git ]; then
            rm /home/$NEW_USER/config-files/.git
            tmp=/tmp/config-files
            git clone https://github.com/jeanmax/config-files $tmp
            mv $tmp/.git /home/$NEW_USER/config-files/.git
            rm -rf $tmp
        fi

        emacs --daemon

        # don't start too many stuffs at boot
        sed -E -i 's|(.*workspace 1:firefox.*)|# \1|' /home/$NEW_USER/config-files/.config/i3/config
        sed -E -i 's|(.*workspace 2:emacs.*)|# \1|' /home/$NEW_USER/config-files/.config/i3/config
        sed -E -i 's|(.*compton.*)|# \1|' /home/$NEW_USER/config-files/.xinitrc
        sed -E -i 's|(.*numlockx.*)|# \1|' /home/$NEW_USER/config-files/.xinitrc
    fi
    chown -R $NEW_USER:users /home/$NEW_USER/config-files

    # mkarchiso overwrite .bashrc each time :o
    (cd /home/mc/config-files/ && git checkout .bashrc)
    unlink /root/config-files || true
    rm -rf /{etc/skel,root}/{config-files,.mozilla}
    ln -sv /home/$NEW_USER/config-files /root/config-files
}

install_yaourt() {
    if ! $(hash yaourt 2>/dev/null); then
	    package_url=https://aur.archlinux.org/cgit/aur.git/snapshot
	    for package in package-query yaourt; do
		    cd /tmp
		    test -e /tmp/$package.tar.gz \
			    || wget $package_url/$package.tar.gz -O /tmp/$package.tar.gz
		    tar -xvzf /tmp/$package.tar.gz
		    chown -R $NEW_USER:users /tmp/$package
		    cd /tmp/$package
		    su $NEW_USER -c "makepkg -si --noconfirm"
		    cd -
		    rm -rf /tmp/$package
	    done
	    unset package_url
    fi
}

install_aur_packages() {
    while ! su $NEW_USER -c "gpg --keyserver hkp://pgp.mit.edu:11371 --recv-keys D1483FA6C3C07136"; do sleep 3; done  # tor-browser

    if test "$(uname -m)" == "i686"; then
        yes | pacman -Syy --needed archlinux32-keyring-transition
        yes | pacman -S --needed archlinux32-keyring
    fi

    su $NEW_USER -c "yaourt -Syuu --devel --aur --noconfirm"

    if test "$(uname -m)" == "x86_64"; then
        # fontconfig-ubuntu and fontconfig are in conflict
        # if ! pacman -Qk fontconfig 2>/dev/null; then
        su $NEW_USER -c "yaourt -Rn --noconfirm --assume-installed=fontconfig fontconfig || true"
        su $NEW_USER -c "yaourt --noconfirm --needed -S fontconfig-ubuntu" #yolo
    fi

    for p in $AUR_PKG; do
        su $NEW_USER -c "yaourt --noconfirm --needed -S $p" #yolo
    done

    su $NEW_USER -c "gem install oauth2"
    # su $NEW_USER -c "ros install"
    # su $NEW_USER -c "ros install caveman2"
    # su $NEW_USER -c "ros install clack"
    # su $NEW_USER -c "ros install hunchentoot"
    # su $NEW_USER -c "ros install woo"
    # su $NEW_USER -c "ros install slime"
}

clean_customization() {
    yes | pacman -Rns $(pacman -Qdtq) || true
    yes | pacman -Scc
    rm -vf /var/cache/pacman/pkg/*
    pacman-optimize
    updatedb

    # revert sudo/pacman conf
    sed -i 's/# \(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers
    sed -i 's/^\(%wheel ALL=(ALL) NOPASSWD: ALL\)/# \1/' /etc/sudoers
    sed -i 's/^#\(CheckSpace\)/\1/' /etc/pacman.conf
}


init_customization
misc_config
time_config
font_config
create_new_user
install_yaourt
install_aur_packages
clean_customization
