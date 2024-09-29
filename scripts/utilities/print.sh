wprintf() {
  format="$1"
  string="$2"

  printf "$WHITE%s$string" "$format"
}

warn() {
  printf "\n$YELLOW[!] WARNING: $@%s\n" "$NC"
}

error() {
  printf "$RED[-] ERROR: $@\n"
}

banner() {
  printf "\n"

  line="__--==[ MiArch-installer v$VERSION ]==--__"
  printf "$YELLOW%*s$NC\n" $(((${#line} + COLUMNS) / 2)) "$line"

  printf "\n\n"
}

title() {
  banner
  printf "$PURPLE>> $@%s\n\n\n" "$NC"
}
