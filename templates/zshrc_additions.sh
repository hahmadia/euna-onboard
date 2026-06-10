# Kubernetes aliases
alias k='kubectl'
alias kdev='kubectl --context=dev'
alias kuat='kubectl --context=uat'
alias kprod='kubectl --context=prod'
alias kpods='kubectl get pods'
alias klogs='kubectl logs -f'

# GPG TTY for commit signing
export GPG_TTY=$(tty)

# asdf version manager
. "$(brew --prefix asdf)/libexec/asdf.sh"

# GemFury (uncomment and add your token after receiving it from IT)
# export BUNDLE_GEM__FURY__IO=<your-gemfury-token>
# export GEMFURY_TOKEN=<your-gemfury-token>
