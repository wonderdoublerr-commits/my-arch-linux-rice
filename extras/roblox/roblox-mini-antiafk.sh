#!/usr/bin/env bash
set -euo pipefail

INTERVAL_SECONDS="${INTERVAL_SECONDS:-600}"
TAP_SECONDS="${TAP_SECONDS:-0.08}"
REQUIRE_ROBLOX_FOCUS="${REQUIRE_ROBLOX_FOCUS:-1}"
WINDOW_PATTERN="${WINDOW_PATTERN:-roblox|sober|vinegar|waydroid}"
ACTION="${ACTION:-move}"
YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/.ydotool_socket}"
export YDOTOOL_SOCKET

log() {
  printf '[roblox-mini-antiafk] %s\n' "$*"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

active_window_name() {
  if have xdotool; then
    xdotool getactivewindow getwindowname 2>/dev/null || true
    return
  fi

  if have swaymsg && have jq; then
    swaymsg -t get_tree 2>/dev/null \
      | jq -r '.. | select(.focused? == true) | .name // empty' 2>/dev/null \
      || true
    return
  fi
}

roblox_is_focused() {
  local name
  name="$(active_window_name)"

  if [[ -z "$name" ]]; then
    [[ "$REQUIRE_ROBLOX_FOCUS" == "0" ]]
    return
  fi

  [[ "$name" =~ $WINDOW_PATTERN ]]
}

tap_pair_xdotool() {
  if [[ "$ACTION" == "jump" ]]; then
    xdotool keydown space
    sleep "$TAP_SECONDS"
    xdotool keyup space
    return
  fi

  xdotool keydown w
  sleep "$TAP_SECONDS"
  xdotool keyup w
  sleep 0.15
  xdotool keydown s
  sleep "$TAP_SECONDS"
  xdotool keyup s
}

tap_pair_ydotool() {
  ensure_ydotoold

  if [[ "$ACTION" == "jump" ]]; then
    # Linux input keycode: Space=57.
    ydotool key 57:1
    sleep "$TAP_SECONDS"
    ydotool key 57:0
    return
  fi

  # Linux input keycodes: W=17, S=31.
  ydotool key 17:1
  sleep "$TAP_SECONDS"
  ydotool key 17:0
  sleep 0.15
  ydotool key 31:1
  sleep "$TAP_SECONDS"
  ydotool key 31:0
}

ensure_ydotoold() {
  if ydotool debug >/dev/null 2>&1; then
    return
  fi

  if [[ -S "$YDOTOOL_SOCKET" ]]; then
    log "Нашел мертвый сокет ydotool, удаляю: $YDOTOOL_SOCKET"
    rm -f "$YDOTOOL_SOCKET"
  fi

  if ! have ydotoold; then
    log "ydotool найден, но ydotoold нет. Переустанови пакет: sudo pacman -S ydotool"
    exit 1
  fi

  log "ydotoold не запущен. Пробую поднять его от текущего пользователя."

  ydotoold \
    --socket-path="$YDOTOOL_SOCKET" \
    --socket-own="$(id -u):$(id -g)" \
    >/tmp/roblox-mini-antiafk-ydotoold.log 2>&1 &

  sleep 1

  if ydotool debug >/dev/null 2>&1; then
    return
  fi

  log "Обычный запуск не сработал. Пробую через sudo."
  log "Если sudo снова пишет 'incorrect password', нажми Ctrl+C и проверь пароль командой: sudo -v"

  sudo -v

  sudo -n ydotoold \
    --socket-path="$YDOTOOL_SOCKET" \
    --socket-own="$(id -u):$(id -g)" \
    >/tmp/roblox-mini-antiafk-ydotoold.log 2>&1 &

  sleep 1

  if ! ydotool debug >/dev/null 2>&1; then
    log "Не получилось запустить ydotoold автоматически."
    if [[ -s /tmp/roblox-mini-antiafk-ydotoold.log ]]; then
      log "Вывод ydotoold:"
      sed 's/^/[ydotoold] /' /tmp/roblox-mini-antiafk-ydotoold.log >&2
    fi
    log "Попробуй отдельно:"
    log "sudo ydotoold --socket-path=\"$YDOTOOL_SOCKET\" --socket-own=\"$(id -u):$(id -g)\""
    log "Лог: /tmp/roblox-mini-antiafk-ydotoold.log"
    exit 1
  fi
}

tap_pair_wtype() {
  if [[ "$ACTION" == "jump" ]]; then
    wtype -k space
    return
  fi

  wtype -k w
  sleep 0.15
  wtype -k s
}

send_tiny_move() {
  if have xdotool && [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]]; then
    tap_pair_xdotool
    return
  fi

  if have ydotool; then
    tap_pair_ydotool
    return
  fi

  if have wtype; then
    tap_pair_wtype
    return
  fi

  log "Не найден инструмент для нажатий клавиш."
  log "Wayland: sudo apt install ydotool && sudo systemctl enable --now ydotool"
  log "X11: sudo apt install xdotool"
  exit 1
}

usage() {
  cat <<EOF
Использование:
  $0             запуск цикла раз в 12 минут
  $0 --test      сделать одно действие и выйти

Переменные:
  REQUIRE_ROBLOX_FOCUS=0   не проверять активное окно
  INTERVAL_SECONDS=720     интервал между движениями
  TAP_SECONDS=0.08         длительность нажатия
  ACTION=move              W/S микродвижение
  ACTION=jump              прыжок Space
EOF
}

case "${1:-}" in
  --test)
    log "Тест: делаю одно короткое действие: $ACTION."
    send_tiny_move
    log "Тест закончен."
    exit 0
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage
    exit 2
    ;;
esac

log "Старт. Действие: ${ACTION}, интервал: ${INTERVAL_SECONDS}s, длительность нажатия: ${TAP_SECONDS}s."
log "Остановить: Ctrl+C."

if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && ! have ydotool && ! have wtype; then
  log "У тебя Wayland, а ydotool/wtype не найден."
  log "Для Arch попробуй: sudo pacman -S ydotool"
fi

while true; do
  if roblox_is_focused; then
    log "Делаю короткое действие: $ACTION."
    send_tiny_move
  else
    log "Roblox не в фокусе, пропускаю. REQUIRE_ROBLOX_FOCUS=0 отключит проверку."
  fi

  sleep "$INTERVAL_SECONDS"
done

