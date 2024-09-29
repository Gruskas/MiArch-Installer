# colors
red="$(tput bold ; tput setaf 1)"
yellow="$(tput bold ; tput setaf 3)"
cyan="$(tput bold; tput setaf 6)"
purple="$(tput bold; tput setaf 5)"
nc="$(tput sgr0)"

# export
export PS1="\[$red\][\[$cyan\]\u \[$yellow\]\H \[$purple\]\w\[$red\]]\\$ \[$nc\]"

# alias
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias vi="vim"
