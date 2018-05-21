# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH

# start a screen session
if [ -n "$SSH_CLIENT" -a "$TERM" != "screen" -a -n "$SSH_TTY" ]; then
        screen -xRR && exit
fi
