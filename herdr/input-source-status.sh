#!/bin/sh

# macOS stores the currently selected input source in HIToolbox preferences.
# Keep the label deliberately short: it lives in Herdr's tab-bar status area.
sources=$(/usr/bin/defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null) || exit 0

case "$sources" in
  *"Input Mode"*"Pinyin"* | *"Input Mode"*"Chinese"* | *"Input Mode"*"SCIM"* | *"Input Mode"*"Sogou"* | *"Input Mode"*"Rime"* | *"Input Mode"*"WeChat"*)
    printf '中\n'
    ;;
  *"Input Mode"*)
    printf 'IME\n'
    ;;
  *'"KeyboardLayout Name" = ABC;'* | *'"KeyboardLayout Name" = "U.S.";'*)
    printf 'EN\n'
    ;;
  *)
    printf 'IME\n'
    ;;
esac
