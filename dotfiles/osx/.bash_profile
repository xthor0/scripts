if [ -f $(brew --prefix)/etc/bash_completion ]; then
	. $(brew --prefix)/etc/bash_completion
fi

case "$TERM" in
  screen*) PROMPT_COMMAND='printf %bk%s%b%b \\033 "${HOSTNAME%%.*}" \\033 \\0134';;
  xterm*) PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"';;
esac

if [ -f ${HOME}/.bashrc ]; then
	. ${HOME}/.bashrc
fi
export PATH="/usr/local/opt/coreutils/libexec/gnubin:/usr/local/sbin:$PATH"
