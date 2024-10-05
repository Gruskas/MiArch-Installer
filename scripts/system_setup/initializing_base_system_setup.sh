setup_base_system() {

  # Copy mirror list
  pass_mirror_conf
  sleep_clear 1

  # Set up the resolv.conf
  setup_resolvconf
  sleep_clear 1

  # Install base packages
  install_base_packages
  sleep_clear 1

  # Set up the fstab
  setup_fstab
  sleep_clear 1

  # Set up /proc, /sys, and /dev
  setup_proc_sys_dev
  sleep_clear 1

  # Set up the system locale
  setup_locale
  sleep_clear 1

  # Set up the system hostname
  setup_hostname
  sleep_clear 1

  # Copy Files to root and user account
  copy_config
  sleep_clear 1

  # Set up the root user account
  setup_user "root"
  sleep_clear 1

  # Ask for additional user accounts
  ask_user_account
  sleep_clear 1

  # Set up the normal user account
  setup_user "$NORMAL_USER"
  sleep_clear 1

  # Set up the time
  setup_time
  sleep_clear 1
  
  # Update distribution information
  update_distribution_info
  sleep_clear 1

  # Set up the initial ramdisk filesystem
  setup_initramfs
  sleep_clear 1
  
  # Set up boot lodaer
  setup_bootloader
}