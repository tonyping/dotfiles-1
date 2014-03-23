# Enable color support of ls/*grep and make it the default
if [ -x /usr/bin/dircolors ]; then
	test -r "$HOME/.dircolors" && eval "$(dircolors -b "$HOME/.dircolors")" || eval "$(dircolors -b)"
	alias ls='ls --color=auto'
	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
fi

# Some useful ls aliases
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'

# vim: syntax=sh ts=4 sw=4 sts=4 sr noet

