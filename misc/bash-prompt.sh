if [ "$PS1" ]; then
  case `dnsdomainname | awk -F'.' '{print $2}'` in
    test)     domain=".test"; color="\[\033[38;5;191m\]" ;;
    uat)      domain=".uat" ; color="\[\033[38;5;226m\]" ;;
    *)        domain=""     ; color="\[\033[38;5;196m\]" ;;
  esac

  export PS1="\[\033[38;5;202m\]\u\[$(tput sgr0)\]\[\033[38;5;214m\]@\[$(tput sgr0)\]${color}\h${domain}\[$(tput sgr0)\]\[\033[38;5;214m\]\\$\[$(tput sgr0)\] "
fi
