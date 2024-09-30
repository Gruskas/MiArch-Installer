ask_disk() {
  while true; do
    Disks="$(lsblk | grep disk | awk '{print $1}')"
    title 'Disk Setup'
    wprintf '[+] Available Disks for installation:'
    printf "\n\n"

    for i in $Disks; do
      echo "  > $i"
    done

    printf "\n"
    wprintf '[?] Please choose a device: '
    read -r Disk

    if echo "$Disks" | grep "\<$Disk\>" >$VERBOSE; then
      Disk="/dev/$Disk"
      clear
      break
    fi

    clear
  done
}

ask_dualboot() {
  if confirm 'Disk Setup > DualBoot' '[?] Install MiArch with Windows/Other OS [y/n]: '; then
    GRUB=$TRUE
    DUALBOOT=$TRUE
  else
    DUALBOOT=$FALSE
    if [ "$BOOT_MODE" = 'uefi' ]; then
      clear
      ask_grub
    else
      GRUB=$TRUE
    fi
  fi

  sleep_clear 0
  ask_luks
}

ask_grub() {
  if confirm 'Disk Setup > Grub' '[?] Do you want grub [y/n]: '; then
    GRUB=$TRUE
  else
    GRUB=$FALSE
  fi
}

ask_luks() {
  if confirm 'Disk Setup > LUKS' '[?] Do you want encrypt [y/n]: '; then
    LUKS=$TRUE
  else
    LUKS=$FALSE
  fi
}

ask_cfdisk() {
  if confirm 'Disk Setup > Partitions' '[?] Create partitions with cfdisk (root and boot, optional swap) [y/n]: '; then
    clear
    zero_part
  else
    echo
    warn 'No partitions chosed? Make sure you have them already configured.'
    get_partitions
  fi
}

zero_part() {
  local clear_part=0

  if confirm 'Disk Setup' '[?] Start with a blank partition table in memory, where all data will be zeroed out. [y/n]: '; then
    clear_part=1
    cfdisk -z "$Disk"
  else
    cfdisk "$Disk"
  fi
  sync

  get_partitions
  if [ ${#PARTITIONS[@]} -eq 0 ] && [ $clear_part -eq 1 ]; then
    clear
    error 'You have not created partitions on your disk, make sure to write your changes before quiting cfdisk. Trying again...'
    zero_part
  fi
  if [ "$BOOT_MODE" = 'uefi' ] && ! fdisk -l "$Disk" -o type | grep -i 'EFI'; then
    clear
    error 'You are booting in UEFI mode but not EFI partition was created, make sure you select the "EFI System" type for your EFI partition.'
    zero_part
  fi
}

get_partitions() {
  PARTITIONS=$(fdisk -l "$Disk" -o device,size,type | grep "$Disk[[:alnum:]]" | awk '{print $1;}')
}

ask_partitions() {
  # get_partition_label
  PART_LABEL="$(fdisk -l "$Disk" | grep "Disklabel" | awk '{print $3;}')"

  while [ "$BOOT_PART" = '' ] ||
    [ "$ROOT_PART" = '' ] ||
    [ "$BOOT_FS_TYPE" = '' ] ||
    [ "$ROOT_FS_TYPE" = '' ]; do
    title 'Disk Setup > Partitions'
    wprintf '[+] Created partitions:'
    printf "\n\n"

    fdisk -l "$Disk" -o device,size,type | grep "$Disk[[:alnum:]]" | sed 's#/dev/# >  #'

    echo

    if [ "$BOOT_MODE" = 'uefi' ] && [ "$PART_LABEL" = 'gpt' ]; then
      while [ -z "$BOOT_PART" ]; do
        wprintf "[?] EFI System partition ($(basename "$Disk")X): "
        read -r BOOT_PART
        BOOT_PART="/dev/$BOOT_PART"
        until [[ "$PARTITIONS" =~ $BOOT_PART ]]; do
          wprintf "[?] Your partition $BOOT_PART is not in the partitions list.\n"
          wprintf "[?] EFI System partition ($(basename "$Disk")X): "
          read -r BOOT_PART
          BOOT_PART="/dev/$BOOT_PART"
        done
      done
      BOOT_FS_TYPE="fat32"
    else
      while [ -z "$BOOT_PART" ]; do
        wprintf "[?] Boot partition ($(basename "$Disk")X): "
        read -r BOOT_PART
        BOOT_PART="/dev/$BOOT_PART"
        until [[ "$PARTITIONS" =~ $BOOT_PART ]]; do
          wprintf "[?] Your partition $BOOT_PART is not in the partitions list.\n"
          wprintf "[?] Boot partition ($(basename "$Disk")X): "
          read -r BOOT_PART
          BOOT_PART="/dev/$BOOT_PART"
        done
      done
      wprintf '[?] Choose a filesystem to use in your boot partition (ext2, ext3, ext4)? (default: ext4): '
      read -r BOOT_FS_TYPE
      if [ -z "$BOOT_FS_TYPE" ]; then
        BOOT_FS_TYPE="ext4"
      fi
    fi

    while [ -z "$ROOT_PART" ]; do
      wprintf "[?] Root partition ($(basename "$Disk")X): "
      read -r ROOT_PART
      ROOT_PART="/dev/$ROOT_PART"
      until [[ "$PARTITIONS" =~ $ROOT_PART ]]; do
        wprintf "[?] Your partition $ROOT_PART is not in the partitions list.\n"
        wprintf "[?] Root partition ($(basename "$Disk")X): "
        read -r ROOT_PART
        ROOT_PART="/dev/$ROOT_PART"
      done
    done
    wprintf '[?] Choose a filesystem to use in your root partition (btrfs, ext4)? (default: ext4): '
    read -r ROOT_FS_TYPE
    if [ -z "$ROOT_FS_TYPE" ]; then
      ROOT_FS_TYPE="ext4"
    fi

    wprintf "[?] Swap partition ($(basename "$Disk")X - empty for none): "
    read -r SWAP_PART
    if [ -n "$SWAP_PART" ]; then
      until [[ "$PARTITIONS" =~ $SWAP_PART ]]; do
        wprintf "[?] Your partition $SWAP_PART is not in the partitions list.\n"
        wprintf "[?] Swap partition ($(basename "$Disk")X): "
        read -r SWAP_PART
      done
    fi
    if [ "$SWAP_PART" = '' ]; then
      SWAP_PART='none'
    else
      SWAP_PART="/dev/$SWAP_PART"
    fi
    clear
  done
}

print_partitions() {
  local partitions_opt

  while true; do
    title 'Disk Setup > Partitions'
    wprintf '[+] Current Partition table'

    if [ "$BOOT_MODE" = 'uefi' ]; then
      printf "\n
      > /boot/efi   : %s (%s)
      > /           : %s (%s)
      > swap        : %s (swap)
      \n" "$BOOT_PART" "$BOOT_FS_TYPE" \
        "$ROOT_PART" "$ROOT_FS_TYPE" \
        "$SWAP_PART"
    else
      printf "\n
      > /boot   : %s (%s)
      > /       : %s (%s)
      > swap    : %s (swap)
      \n" "$BOOT_PART" "$BOOT_FS_TYPE" \
        "$ROOT_PART" "$ROOT_FS_TYPE" \
        "$SWAP_PART"
    fi

    wprintf "[?] Partition table correct [y/n]: "
    read -r partitions_opt

    if [ "$partitions_opt" = 'y' ] || [ "$partitions_opt" = 'Y' ]; then
      clear
      break
    else
      BOOT_PART=""
      ROOT_PART=""
      BOOT_FS_TYPE=""
      ROOT_FS_TYPE=""
      SWAP_PART=""
      sleep_clear 1
      ask_partitions
    fi
    clear
  done
}

ask_formatting() {
  if confirm 'Disk Setup > Partition Formatting' "[?] Ready to format? No turning back without backups! Confirm? [y/n]: "; then
    text="Formatting in progress..."
    for ((i = 0; i < ${#text}; i++)); do
      echo -n "${text:$i:1}"
      sleep 0.05
    done
    sleep_clear 1
  else
    echo
    error 'Seriously?'
    sleep_clear 10
    shutdown now
  fi
}

mount_filesystems() {
  title 'Disk Setup > Mount'

  wprintf '[+] Mounting filesystems'
  printf "\n\n"

  # ROOT
  if [ "$LUKS" = "$TRUE" ]; then
    if ! mount "$ROOT_PART_ENCRYPT" "$CHROOT"; then
      error "Error mounting encrypted root filesystem, leaving."
      exit $FAILURE
    fi
  else
    if ! mount "$ROOT_PART" "$CHROOT"; then
      error "Error mounting root filesystem, leaving."
      exit $FAILURE
    fi
  fi

  # BOOT
  mkdir -p "$CHROOT/boot" >$VERBOSE 2>&1
  if [ "$GRUB" = "$TRUE" ]; then
    if [ "$BOOT_MODE" = 'uefi' ] && [ "$PART_LABEL" = 'gpt' ] && [ "$LUKS" = "$FALSE" ]; then
      mkdir -p "$CHROOT/boot/efi" >$VERBOSE 2>&1

      if ! mount "$BOOT_PART" "$CHROOT/boot/efi"; then
        error "Error mounting EFI partition, exiting."
        exit $FAILURE
      fi
    else
      if ! mount "$BOOT_PART" "$CHROOT/boot"; then
        error "Error mounting boot partition, exiting."
        exit $FAILURE
      fi
    fi
  else
    if ! mount "$BOOT_PART" "$CHROOT/boot"; then
      error "Error mounting boot partition, exiting."
      exit $FAILURE
    fi
  fi

  # SWAP
  if [ "$SWAP_PART" != 'none' ]; then
    swapon $SWAP_PART >$VERBOSE 2>&1
  fi
}

umount_filesystems() {
  if [ "$1" = 'WindowsMyBeloved' ]; then
    title 'Disk Setup > Unmount'

    wprintf '[+] Unmounting filesystems'
    printf "\n\n"

    umount -Rf /mnt >$VERBOSE 2>&1
    umount -Rfa "$Disk" >$VERBOSE 2>&1
  else
    title 'Completed'

    wprintf '[+] Unmounting filesystems'
    printf "\n\n"

    umount -Rf $CHROOT >$VERBOSE 2>&1
    swapoff $SWAP_PART >$VERBOSE 2>&1
  fi
}

sync_disk() {
  title 'Ending'
  wprintf '[+] Syncing disk'
  printf "\n\n"
  sync
}
