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

# Synchronize history between bash sessions
#
# Make history from other terminals available to the current one. However,
# don't mix all histories together - make sure that *all* commands from the
# current session are on top of its history, so that pressing up arrow will
# give you most recent command from this session, not from any session.
#
# Since history is saved on each prompt, this additionally protects it from
# terminal crashes.
# stolen shamelessly: https://gist.github.com/jan-warchol/89f5a748f7e8a2c9e91c9bc1b358d3ec

# keep unlimited shell history because it's very useful
export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTFILESIZE=-1
export HISTSIZE=-1
shopt -s histappend   # don't overwrite history file after each session


# on every prompt, save new history to dedicated file and recreate full history
# by reading all files, always keeping history from current session on top.
update_history () {
  history -a ${HISTFILE}.$$
  history -c
  history -r  # load common history file
  # load histories of other sessions
  for f in `ls ${HISTFILE}.[0-9]* 2>/dev/null | grep -v "${HISTFILE}.$$\$"`; do
    history -r $f
  done
  history -r "${HISTFILE}.$$"  # load current session history
}
if [[ "$PROMPT_COMMAND" != *update_history* ]]; then
  export PROMPT_COMMAND="update_history; $PROMPT_COMMAND"
fi

# merge session history into main history file on bash exit
merge_session_history () {
  if [ -e ${HISTFILE}.$$ ]; then
    cat ${HISTFILE}.$$ >> $HISTFILE
    \rm ${HISTFILE}.$$
  fi
}
trap merge_session_history EXIT


# detect leftover files from crashed sessions and merge them back
active_shells=$(pgrep `ps -p $$ -o comm= | cut -b 2-`)
grep_pattern=`for pid in $active_shells; do echo -n "-e \.${pid}\$ "; done`
orphaned_files=`ls $HISTFILE.[0-9]* 2>/dev/null | grep -v $grep_pattern`

if [ -n "$orphaned_files" ]; then
  echo Merging orphaned history files:
  for f in $orphaned_files; do
    echo "  `basename $f`"
    cat $f >> $HISTFILE
    \rm $f
  done
  echo "done."
fi

# standard prompts
COLOR_PROMPT='\[\033[01;33m\]\u\[\033[00m\]@\[\033[01;34m\]\h\[\033[00m\] [\[\033[01;36m\]\W\[\033[00m\]]\$ '
STANDARD_PROMPT="[\u@\h \W]\\$ "

# wrap it
function set_bash_prompt() {
  PS1="${COLOR_PROMPT}"
}

# set it
if [ "$TERM" == "xterm-256color" ]; then
  if [[ "$PROMPT_COMMAND" != set_bash_prompt* ]]; then
    export PROMPT_COMMAND="set_bash_prompt; $PROMPT_COMMAND"
  fi
else
  PS1="${STANDARD_PROMPT}"
fi

# path
export PATH=$PATH:$HOME/bin:$HOME/.local/bin

# ls colors
export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx

# aliases
alias ls="ls --color"
alias npw="pwgen 8 1"
alias sshnosave="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
alias aws-regions="aws --region us-west-2 ec2 describe-regions --output table"
alias cp='gcp'

