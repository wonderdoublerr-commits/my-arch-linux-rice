hl.on("hyprland.start", function()

    -- Передаём окружение Hyprland в systemd user
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS")

    -- Даём окружению примениться
    hl.exec_cmd("sleep 1")

    -- Clipboard history
    hl.exec_cmd("~/.local/bin/cliphist-start")

    -- Перезапускаем Elephant уже с окружением Hyprland
    hl.exec_cmd("systemctl --user restart elephant")

    -- Walker
    hl.exec_cmd("sleep 1 && systemctl --user restart walker")

    -- Quickshell
    hl.exec_cmd("quickshell -p ~/.config/quickshell/mybar/shell.qml")

    -- Rage-Gothic cursor
    hl.exec_cmd("hyprctl setcursor Rage-Gothic 36")

    -- SwayOSD
    hl.exec_cmd("sleep 2 && swayosd-server")

    -- Awww wallpaper daemon
    hl.exec_cmd("awww-daemon")

    -- Hypridle
    hl.exec_cmd("hypridle")
    
   --Wathcer
   hl.exec_cmd("~/.local/bin/layout-watch &")

   -- Sticky Telegram video bubbles
   hl.exec_cmd("~/.local/bin/telegram-bubble-pin &")

end)
