# miarch-installer version
VERSION='0.1 Beta'

# path to miarch-installer
Config_PATH='/usr/share/miarch-installer/files'

# true / false
TRUE=0
FALSE=1

# return codes
SUCCESS=0
FAILURE=1

# default verbose mode
VERBOSE='/dev/null'

# columns
COLUMNS="$(tput cols)"

# colors
WHITE="$(
  tput bold
  tput setaf 7
)"
NC="$(tput sgr0)"
CYAN="$(tput setaf 6)"
RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
PURPLE="$(tput setaf 5)"

# chosen locale
LOCALE=''

# chosen keymap
KEYMAP=''

# hostname
HOST_NAME=''

# time zone
TIMEZONE=''

# dualboot
DUALBOOT=''

# grub
GRUB=''

# avalable disks
Disks=''

# chosen disk device
Disk=''

# Partitions
PARTITIONS=''

# partition label: gpt or mbr
PART_LABEL=''

# boot partition
BOOT_PART=''

# root partition
ROOT_PART=''

# swap partition
SWAP_PART=''

# boot filesystem type - default: ext4
BOOT_FS_TYPE=''

# root filesystem type - default: ext4
ROOT_FS_TYPE=''

# chroot directory
CHROOT='/mnt'

# Normal system user
NORMAL_USER=''

# check boot mode
BOOT_MODE=''

# Copy files
COPY=''

ctrl_c() {
  sleep_clear 0
  error "ADIOS!"
  exit $FAILURE
}

trap ctrl_c 2

sleep_clear() {
  sleep "$1"
  clear
}

confirm() {
  header="$1"
  ask="$2"

  while true; do
    title "$header"
    wprintf "$ask"
    read -r input
    case $input in
    y | Y | yes | YES | Yes | yas | "") return $TRUE ;;
    n | N | no | NO | No |nO | nah) return $FALSE ;;
    *)
      clear
      continue
      ;;
    esac
  done
}

check_uid() {
  if [ "$(id -u)" != '0' ]; then
    error 'You must be root to run the MiArch installer!'
    exit $FAILURE
  fi
}

check_env() {
  if [ -f "/var/lib/pacman/db.lck" ]; then
    rm -f "/var/lib/pacman/db.lck"
  fi
}

check_inet_conn() {
  if ! curl -s http://archlinux.org/ >$VERBOSE; then
    error 'No Internet connection!'
    exit $FAILURE
  fi
}

check_boot_mode() {
  if [ -r "/sys/firmware/efi/efivars" ]; then
    BOOT_MODE="uefi"
  fi
}

mirrors_update() {
  title 'Environment > Mirrors'

  pacman -Fyy

  warn 'This can take a while, please wait...'
  reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
}

ask_output_mode() {
  local output_opt

  while true; do
    title 'Environment > Output Mode'

    wprintf '[+] Available output modes:'
    printf "\n
  1. Quiet (default)
  2. Verbose (output system commands: mkfs, mount, etc.)\n\n"
    wprintf "[?] Make a choice: "
    read -r output_opt
    case $output_opt in
    1)
      break
      ;;
    2)
      VERBOSE='/dev/stdout'
      break
      ;;
    *)
      clear
      ;;
    esac
  done
}

ask_locale() {
  local locale_opt

  while true; do
    title 'Environment > Locale Setup'
    wprintf '[+] Available locale options:'
    printf "\n
  1. Set a locale
  2. List available locales\n\n"
    wprintf "[?] Make a choice: "
    read -r locale_opt

    case $locale_opt in
    1)
      clear
      title 'Environment > Locale Setup'
      wprintf '[?] Set locale [en_US.UTF-8]: '
      read -r LOCALE

      if [ -z "$LOCALE" ]; then
        warn 'Setting default locale: en_US.UTF-8'
        LOCALE='en_US.UTF-8'
        sleep 1
      fi
      break
      ;;
    2)
      less /etc/locale.gen
      clear
      ;;
    *)
      clear
      ;;
    esac
  done
}

ask_keymap() {
  local keymap_opt

  while true; do
    title 'Environment > Keymap Setup'
    wprintf '[+] Available keymap options:'
    printf "\n
  1. Set a keymap
  2. List available keymaps\n\n"
    wprintf '[?] Make a choice: '
    read -r keymap_opt

    case $keymap_opt in
    1)
      clear
      title 'Environment > Keymap Setup'
      wprintf '[?] Set keymap [us]: '
      read -r KEYMAP

      if [ -z "$KEYMAP" ]; then
        echo
        warn 'Setting default keymap: us'
        sleep 1
        KEYMAP='us'
      fi
      break
      ;;
    2)
      localectl list-keymaps
      sleep_clear 0
      ;;
    *)
      clear
      continue
      ;;
    esac
  done
}

ask_hostname() {
  while [ -z "$HOST_NAME" ]; do
    clear
    title 'Environment > Hostname'
    wprintf '[?] Set your hostname: '
    read -r HOST_NAME
  done
}

ask_time() {
  if confirm 'Environment > Timezone' '[?] Default: UTC. Choose other timezone [y/n]: '; then
    timedatectl list-timezones | less
    wprintf "[?] What is your (Zone/SubZone): "
    read -r TIMEZONE
  else
    warn "Default time and timezone"
    sleep 1
  fi
}

ask_restart() {
  if confirm 'Completed' '[?] Reboot [y/n]: '; then
    reboot
  fi
}

first_check() {
  if [ ! -d "/usr/share/miarch-installer/" ] || [ "$(basename "$0")" != "miarchinstall" ]; then
    rm -rf "/usr/share/miarch-installer/" >$VERBOSE 2>&1 || true
    mkdir -p "/usr/share/miarch-installer/" >$VERBOSE 2>&1
    cp -rf ../* "/usr/share/miarch-installer/" >$VERBOSE 2>&1
    ln -sf "/usr/share/miarch-installer/scripts/start.sh" "/usr/bin/miarchinstall" >$VERBOSE 2>&1
    printf "$YELLOW[!] Now you can run 'miarchinstall'\n"
    exit
  fi
}

necessary_install() {
  pacman -S --noconfirm --needed less sed curl arch-install-scripts reflector >$VERBOSE 2>&1
}

reinitialize_keyring() {
  pacman -Syu --noconfirm archlinux-keyring
}