# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
# window title
function window_title() {
	#echo -ne "\033]0;\u@\h: \W\007"
	#echo -n -e "\033]0;${PWD##*/}\007"
	echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"
}


# prompt
if [ -n "$SSH_CLIENT" ]; then
	export PROMPT_COMMAND="window_title"
	PS1='\[\033[00m\]::\[\033[01;31m\]SSH\[\033[00m\]:: \[\033[01;33m\]\u\[\033[00m\]@\[\033[01;34m\]\h\[\033[00m\] [\[\033[01;36m\]\W\[\033[00m\]]\$ '
else
	if [ "$TERM" == "xterm-256color" ]; then
		export PROMPT_COMMAND="window_title"
		PS1='\[\033[01;33m\]\u\[\033[00m\]@\[\033[01;34m\]\h\[\033[00m\] [\[\033[01;36m\]\W\[\033[00m\]]\$ '
	else
		PS1="[\u@\h \W]\\$ "
	fi
fi

# bash completion
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# path
export PATH=$PATH:$HOME/bin

# ls colors
export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx

# linuxbrew
test -f /home/linuxbrew/.linuxbrew/bin/brew && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# awless
which awless >& /dev/null
if [ $? -eq 0 ]; then
  source <(awless completion bash)
fi

# terraform bash completion
which terraform >& /dev/null
if [ $? -eq 0 ]; then
  complete -C $(which terraform) terraform
fi

# aliases
alias ls="ls --color"
alias npw="pwgen 8 1"
alias sshnosave="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
alias aws-regions="aws --profile personal ec2 describe-regions --output table"

