#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"
export JAVA_HOME="/home/wonder/Downloads/OpenJDK25U-jdk_x64_linux_hotspot_25.0.4.1_1/jdk-25.0.4.1+1"
export PATH="$JAVA_HOME/bin:$PATH"
fastfetch
alias btop='kitty --class btop-terminal --title btop btop'
