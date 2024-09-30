make_boot_partition() {
  title 'Disk Setup > Partition Creation (boot)'
  wprintf '[+] Creating BOOT partition'
  printf "\n\n"

  if [ "$BOOT_FS_TYPE" = "fat32" ]; then
    if ! mkfs.fat -F32 "$BOOT_PART" >$VERBOSE 2>&1; then
      error 'Could not create filesystem'
      exit $FAILURE
    fi
  else
    if ! mkfs.$BOOT_FS_TYPE -F "$BOOT_PART" >$VERBOSE 2>&1; then
      error 'Could not create filesystem'
      exit $FAILURE
    fi
  fi
}

make_root_partition() {
  title 'Disk Setup > Partition Creation (root)'
  wprintf '[+] Creating ROOT partition'
  printf "\n\n"

    if [ "$LUKS" = "$TRUE" ]; then
    wprintf '[+] Encrypting ROOT partition with LUKS'
    printf "\n\n"
    
    if ! cryptsetup luksFormat "$ROOT_PART" >$VERBOSE 2>&1; then
      error 'Could not encrypt the root partition'
      exit $FAILURE
    fi

    if ! cryptsetup open "$ROOT_PART" cryptroot >$VERBOSE 2>&1; then
      error 'Could not open encrypted root partition'
      exit $FAILURE
    fi

    ROOT_PART_ENCRYPT='/dev/mapper/cryptroot'
  fi

  if [ "$ROOT_FS_TYPE" = 'btrfs' ]; then
    mkfs_opts='-f'
  else
    mkfs_opts='-F'
  fi

if [ "$LUKS" = "$TRUE" ]; then
    if ! mkfs.$ROOT_FS_TYPE "$mkfs_opts" "$ROOT_PART_ENCRYPT" >$VERBOSE 2>&1; then
      error 'Could not create filesystem on encrypted partition'
      exit $FAILURE
    fi
  else
    if ! mkfs.$ROOT_FS_TYPE "$mkfs_opts" "$ROOT_PART" >$VERBOSE 2>&1; then
      error 'Could not create filesystem on root partition'
      exit $FAILURE
    fi
  fi
}

make_swap_partition() {
  title 'Disk Setup > Partition Creation (swap)'
  wprintf '[+] Creating SWAP partition'
  printf "\n\n"

  if ! mkswap "$SWAP_PART" >$VERBOSE 2>&1; then
    error 'Could not create swap partition'
    exit $FAILURE
  fi
}

make_partitions() {
  make_boot_partition
  sleep_clear 1

  make_root_partition
  sleep_clear 1

  if [ "$SWAP_PART" != 'none' ]; then
    make_swap_partition
    sleep_clear 1
  fi
}