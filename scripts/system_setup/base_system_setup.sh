pass_mirror_conf() {
  mkdir -p "$CHROOT/etc/pacman.d/" >$VERBOSE 2>&1
  cp -f /etc/pacman.d/mirrorlist "$CHROOT/etc/pacman.d/" >$VERBOSE 2>&1
}

setup_resolvconf() {
  title 'Base System Setup > Etc'

  wprintf '[+] Setting up /etc/resolv.conf'
  printf "\n\n"

  mkdir -p "$CHROOT/etc/" >$VERBOSE 2>&1
  printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" >"$CHROOT/etc/resolv.conf"
}

install_base_packages() {
  title 'Base System Setup > ArchLinux Packages'

  wprintf '[+] Installing ArchLinux base packages'
  printf "\n\n"
  warn 'Please wait...'
  printf "\n"

  pacstrap $CHROOT base base-devel btrfs-progs linux linux-firmware archlinux-keyring vim dhcpcd >$VERBOSE 2>&1
}

setup_fstab() {
  title 'Base System Setup > Etc'

  wprintf '[+] Setting up /etc/fstab'
  printf "\n\n"

  if [ "$PART_LABEL" = "gpt" ]; then
    genfstab -U $CHROOT >>"$CHROOT/etc/fstab"
  else
    genfstab -L $CHROOT >>"$CHROOT/etc/fstab"
  fi

  sed 's/relatime/noatime/g' -i "$CHROOT/etc/fstab"
}

setup_proc_sys_dev() {
  title 'Base System Setup > Proc Sys Dev'

  wprintf '[+] Setting up /proc, /sys and /dev'
  printf "\n\n"

  mkdir -p "$CHROOT/"{proc,sys,dev} >$VERBOSE 2>&1

  mount -t proc proc "$CHROOT/proc" >$VERBOSE 2>&1
  mount --rbind /sys "$CHROOT/sys" >$VERBOSE 2>&1
  mount --make-rslave "$CHROOT/sys" >$VERBOSE 2>&1
  mount --rbind /dev "$CHROOT/dev" >$VERBOSE 2>&1
  mount --make-rslave "$CHROOT/dev" >$VERBOSE 2>&1
}

setup_locale() {
  title 'Base System Setup > Locale'

  wprintf "[+] Setting up $LOCALE locale"
  printf "\n\n"

  if ! grep -q "#$LOCALE" "$CHROOT/etc/locale.gen"; then
    wprintf "[!] Locale $LOCALE not found, defaulting to en_US.UTF-8\n"
    LOCALE="en_US.UTF-8"
    sleep 3
  fi

  sed -i "s/^#$LOCALE/$LOCALE/" "$CHROOT/etc/locale.gen"
  chroot $CHROOT locale-gen >$VERBOSE 2>&1
  printf "LANG=$LOCALE" >"$CHROOT/etc/locale.conf"
  printf "KEYMAP=$KEYMAP" >"$CHROOT/etc/vconsole.conf"
}

setup_hostname() {
  title 'Base System Setup > Hostname'

  wprintf '[+] Setting up hostname'
  printf "\n\n"

  printf "$HOST_NAME" >"$CHROOT/etc/hostname"
}

setup_user() {
  title 'Base System Setup > User'

  user="$(echo "$1" | tr -dc '[:alnum:]_' | tr '[:upper:]' '[:lower:]' |
    cut -c 1-32)"

  wprintf "[+] Setting up $user account"
  printf "\n\n"

  if [ "$user" = 'root' ]; then
    if [ $COPY = $TRUE ]; then
      cp -r "$Config_PATH/root/." "$CHROOT/root/" >$VERBOSE 2>&1
    fi
  else
    chroot $CHROOT groupadd "$user" >$VERBOSE 2>&1
    chroot $CHROOT useradd -g "$user" -d "/home/$user" -s "/bin/bash" \
      -G "$user,wheel" -m "$user" >$VERBOSE 2>&1
    cat >>"$CHROOT/etc/sudoers" <<EOF
$user ALL=(ALL) ALL 
EOF
    wprintf "[+] Added user: $user"
    printf "\n\n"
    if [ $COPY = $TRUE ]; then
      cp -r "$Config_PATH/user/." "$CHROOT/home/$user/" >$VERBOSE 2>&1
    fi
    chroot $CHROOT chown -R "$user":"$user" "/home/$user" >$VERBOSE 2>&1
  fi

  local Passwd_Result=1410
  wprintf "[?] Set password for $user: "
  printf "\n\n"
  while [ $Passwd_Result -ne 0 ]; do
    if [ "$user" = "root" ]; then
      chroot $CHROOT passwd
    else
      chroot $CHROOT passwd "$user"
    fi
    Passwd_Result=$?
  done
}

ask_user_account() {
  title 'Base System Setup > User'

  wprintf '[?] User name: '
  read -r NORMAL_USER
}

setup_time() {
  title 'Base System Setup > Time zone'

  if [ -z "$TIMEZONE" ]; then
    default_time
  elif timedatectl list-timezones | grep -q "^$TIMEZONE$"; then
    chroot "$CHROOT" ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime >$VERBOSE 2>&1
    printf "\n"
    wprintf "[+] Time zone setup correctly"
    printf "\n"
  else
    error "Invalid time zone: $TIMEZONE"
    printf "\n"
    wprintf "[+] Setting up default time and timezone"
    printf "\n"
    sleep 5
    default_time
  fi
}

default_time() {
  printf "\n"
  warn 'Setting up default time and timezone: UTC'
  printf "\n\n"
  chroot $CHROOT ln -sf /usr/share/zoneinfo/UTC /etc/localtime >$VERBOSE 2>&1
}

setup_bootloader() {
  title 'Base System Setup > Boot Loader'

  if [ $GRUB = $TRUE ]; then
    wprintf '[+] Setting up GRUB boot loader'
    printf "\n\n"

    packages="grub"

    if [ "$DUALBOOT" = "$TRUE" ]; then
      packages+=" os-prober"
    fi
    if [ "$BOOT_MODE" = 'uefi' ]; then
      packages+=" efibootmgr"
    fi

    pacstrap $CHROOT $packages >$VERBOSE 2>&1

    sed -i 's/Arch/MiArch/g' "$CHROOT/etc/default/grub"

    chroot $CHROOT grub-install "$Disk" >$VERBOSE 2>&1
    chroot $CHROOT grub-mkconfig -o /boot/grub/grub.cfg >$VERBOSE 2>&1
  else
    wprintf '[+] Setting up boot loader'
    printf "\n\n"

    chroot $CHROOT bootctl install >$VERBOSE 2>&1
    uuid="$(blkid "$ROOT_PART" | cut -d ' ' -f 2 | cut -d '"' -f 2)"

    cat >>"$CHROOT/boot/loader/entries/arch.conf" <<EOF
title   MiArch Linux
linux   /vmlinuz-linux
initrd    /initramfs-linux.img
options   root=UUID=$uuid rw
EOF
  fi
}

setup_initramfs() {
  title 'Base System Setup > InitramFS'

  wprintf '[+] Setting up InitramFS'
  printf "\n\n"

  cp -f "$Config_PATH/etc/mkinitcpio.conf" "$CHROOT/etc/mkinitcpio.conf"
  cp -fr "$Config_PATH/etc/mkinitcpio.d" "$CHROOT/etc/"

  warn 'This can take a while, please wait...'
  printf "\n"
  chroot $CHROOT mkinitcpio -P linux >$VERBOSE 2>&1
}

copy_config() {
  if confirm 'Base System Setup > User files' '[?] Do you want copy default files to your directory? [y/n]: '; then
    COPY=$TRUE
  else
    COPY=$FALSE
  fi
}

enable_pacman_multilib() {
  title 'Pacman Setup > Multilib'

  if [ "$(uname -m)" = "x86_64" ]; then
    wprintf '[+] Enabling multilib support'
    printf "\n\n"
    grep -q "#\[multilib\]" "$CHROOT/etc/pacman.conf" &&
      sed -i '/\[multilib\]/{ s/^#//; n; s/^#//; }' "$CHROOT/etc/pacman.conf" ||
      grep -q "\[multilib\]" "$CHROOT/etc/pacman.conf" ||
      echo "[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" >>"$CHROOT/etc/pacman.conf"
  fi
}
