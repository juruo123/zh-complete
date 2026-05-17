# Source this file from ~/.zshrc after installing the pinyin-path binary:
#
#   source /path/to/zh-complete/shell/pcd.zsh
#
# Then use:
#
#   pcd gong
#   pcd gzbg

pcd() {
  if (( $# != 1 )); then
    print -u2 "usage: pcd <pinyin-query>"
    return 2
  fi

  local target
  target=$(pinyin-path --dirs "$1") || return $?
  cd -- "$target"
}
