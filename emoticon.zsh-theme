# vim:ft=zsh ts=2 sw=2 sts=2

CURRENT_BG='NONE'
PRIMARY_FG=black

# Characters
LEFT_SEGMENT_SEPARATOR="\ue0b0"
RIGHT_SEGMENT_SEPARATOR="\ue0b2"
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"
DETACHED="\u27a6"
CROSS="\u2718"
LIGHTNING="\u26a1\ufe0e"
GEAR="\u2699\ufe0e"

LINE_UP='%{'$'\e[1A''%}'
LINE_DOWN='%{'$'\e[1B''%}'

# Begin a left segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
left_prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    print -n "%{$bg%F{$CURRENT_BG}%}$LEFT_SEGMENT_SEPARATOR%{$fg%}"
  else
    print -n "%{$bg%}%{$fg%}"
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

# End the prompt, closing any open segments
left_prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    print -n "%{%k%F{$CURRENT_BG}%}$LEFT_SEGMENT_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  CURRENT_BG=''
}

# Begin a right segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
right_prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $1 != $CURRENT_BG ]]; then
    print -n "%{%F{$1}%}$RIGHT_SEGMENT_SEPARATOR"
  fi

  CURRENT_BG=$1
  [[ -n $3 ]] && print -n "%{$bg%}%{$fg%}$3"
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local user=`whoami`

  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CONNECTION" ]]; then
    left_prompt_segment $PRIMARY_FG default " %(!.%{%F{yellow}%}.)$user@%m "
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  local color ref
  is_dirty() {
    test -n "$(git status --porcelain --ignore-submodules)"
  }
  ref="$vcs_info_msg_0_"
  if [[ -n "$ref" ]]; then
    if is_dirty; then
      color=yellow
      ref="${ref} $PLUSMINUS"
    else
      color=green
      ref="${ref} "
    fi
    if [[ "${ref/.../}" == "$ref" ]]; then
      ref="$BRANCH $ref"
    else
      ref="$DETACHED ${ref/.../}"
    fi
    left_prompt_segment $color $PRIMARY_FG
    print -Pn " $ref"
  fi
}

# Dir: current working directory
prompt_dir() {
  left_prompt_segment blue $PRIMARY_FG ' %~ '
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}$CROSS"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}$LIGHTNING"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}$GEAR"

  [[ -n "$symbols" ]] && left_prompt_segment $PRIMARY_FG default " $symbols"
}

# Display current virtual environment
prompt_virtualenv() {
  if [[ -n $VIRTUAL_ENV ]]; then
    color=cyan
    left_prompt_segment $color $PRIMARY_FG
    print -Pn " $(basename $VIRTUAL_ENV) "
  fi
}

prompt_emoticon() {
  if [[ $RETVAL -ne 0 ]]; then
    EMOTICON=" (╯°Д°)╯ ┴─┴ "
  else
    if [[ $PRERETVAL -ne 0 ]]; then
      EMOTICON=" ┬─┬ ノ('-'ノ) "
    else
      EMOTICON=" _(┐「ε:)_ "
    fi
  fi

  left_prompt_segment $PRIMARY_FG default $EMOTICON
}

prompt_grayscale() {
  left_prompt_segment "10" default ""
  left_prompt_segment "12" default ""
}

prompt_time() {
  local time_format=" %D{%H:%M:%S} "
  right_prompt_segment white black $time_format
}

function zle-keymap-select zle-line-init zle-line-finish {
  # The terminal must be in application mode when ZLE is active for $terminfo
  # values to be valid.
  # if (( ${+terminfo[smkx]} )); then
    # printf '%s' ${terminfo[smkx]}
  # fi
  # if (( ${+terminfo[rmkx]} )); then
    # printf '%s' ${terminfo[rmkx]}
  # fi

  if [[ ${KEYMAP} == "vicmd" ]]; then
    RPROMPT=${RPROMPT/$VI_INSERT_SEGMENT/$VI_NORMAL_SEGMENT}
  elif [[ ${KEYMAP} == "main" || ${KEYMAP} == "viins" ]]; then
    RPROMPT=${RPROMPT/$VI_NORMAL_SEGMENT/$VI_INSERT_SEGMENT}
  fi

  zle reset-prompt
  zle -R
}
zle -N zle-line-init
zle -N zle-line-finish
zle -N zle-keymap-select

VI_INSERT_SEGMENT=$(right_prompt_segment "240" white " INSERT ")
VI_NORMAL_SEGMENT=$(right_prompt_segment yellow white " NORMAL ")
prompt_vi_mode() {
  print -n $VI_INSERT_SEGMENT
}

## Main prompt
build_left_prompt_first_line() {
  CURRENT_BG='NONE'
  prompt_status
  prompt_context
  prompt_virtualenv
  prompt_dir
  prompt_git
  left_prompt_end
}

build_left_prompt_second_line() {
  prompt_emoticon
  prompt_grayscale
  left_prompt_end
}

build_right_prompt() {
  prompt_vi_mode
  prompt_time
}

prompt_agnoster_precmd() {
  RETVAL=$?
  PRERETVAL=$TMPRETVAL
  TMPRETVAL=$RETVAL

  vcs_info
  PROMPT='%{%f%b%k%}$(build_left_prompt_first_line)
$(build_left_prompt_second_line) '
  RPROMPT="$LINE_UP%f%b%k$(build_right_prompt)$LINE_DOWN"
  # add a new line before prompt
  print ""
}

prompt_agnoster_setup() {
  setopt prompt_subst

  autoload -Uz add-zsh-hook
  autoload -Uz vcs_info

  prompt_opts=(cr subst percent)

  add-zsh-hook precmd prompt_agnoster_precmd

  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:*' check-for-changes false
  zstyle ':vcs_info:git*' formats '%b'
  zstyle ':vcs_info:git*' actionformats '%b (%a)'
}

prompt_agnoster_setup "$@"
