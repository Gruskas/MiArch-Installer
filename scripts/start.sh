#!/bin/bash

BASE_DIR="/usr/share/miarch-installer/scripts"

if [ -d "$(dirname "$0")" ] && [ -d "$(dirname "$0")/utilities" ]; then
  BASE_DIR="$(dirname "$0")"
fi

source $BASE_DIR"/utilities/general.sh"
source $BASE_DIR"/utilities/print.sh"
source $BASE_DIR"/disk_management/create_disk.sh"
source $BASE_DIR"/disk_management/make_partition.sh"
source $BASE_DIR"/system_setup/base_system_setup.sh"
source $BASE_DIR"/system_setup/initializing_base_system_setup.sh"

main() {
  # Do some checks
  sleep_clear 0
  check_uid
  first_check
  check_env
  check_inet_conn
  sleep_clear 0
  check_boot_mode

  # Mirrors
  necessary_install
  mirrors_update
  sleep_clear 0

  # Update keyrings
  reinitialize_keyring
  sleep_clear 0

  # Output mode
  ask_output_mode
  sleep_clear 0

  # Locale
  ask_locale
  sleep_clear 0

  # Keymap
  ask_keymap
  sleep_clear 0

  # Hostname
  ask_hostname
  sleep_clear 0

  # Time zone
  ask_time
  sleep_clear 0

  # Disk
  ask_dualboot
  sleep_clear 0
  ask_luks
  sleep_clear 0
  umount_filesystems 'WindowsMyBeloved'
  sleep_clear 0
  ask_disk
  sleep_clear 0
  ask_cfdisk
  sleep_clear 1
  ask_partitions
  print_partitions
  ask_formatting
  sleep_clear 1
  make_partitions
  sleep_clear 1
  mount_filesystems
  sleep_clear 1

  # Arch linux
  setup_base_system
  sleep_clear 1

  # Enable multilib support in Pacman (only for x86_64 architecture)
  enable_pacman_multilib
  sleep_clear 1

  # Finishing
  umount_filesystems
  sleep_clear 1
  sync_disk

  sleep_clear 0
  ask_restart
}

#start
main
