local mainMod = "SUPER"



-- =========================
-- APPLICATIONS
-- =========================

-- Kitty
hl.bind(
    mainMod .. " + T",
    hl.dsp.exec_cmd("kitty")
)

-- Walker
hl.bind(
    mainMod .. " + D",
    hl.dsp.exec_cmd("walker -m desktopapplications")
)

-- Nautilus
hl.bind(
    mainMod .. " + E",
    hl.dsp.exec_cmd("nautilus")
)

-- Mission Center
hl.bind(
    mainMod .. " + SHIFT + escape",
    hl.dsp.exec_cmd("missioncenter")
)

-- Close window
hl.bind(
    mainMod .. " + Q",
    hl.dsp.window.close()
)

-- Force kill (убить приложение целиком: окно + все дочерние процессы)
hl.bind(
    mainMod .. " + SHIFT + Q",
    hl.dsp.exec_cmd("~/.local/bin/app-kill")
)

-- Exit Hyprland
hl.bind(
    mainMod .. " + M",
    hl.dsp.exit()
)

-- Fullscreen
hl.bind(
    mainMod .. " + F",
    hl.dsp.window.fullscreen()
)

-- Floating
hl.bind(
    mainMod .. " + V",
    hl.dsp.window.float({
        action = "toggle",
    })
)


-- =========================
-- CLIPBOARD HISTORY
-- =========================

hl.bind(
    mainMod .. " + SHIFT + V",
    hl.dsp.exec_cmd("walker -m clipboard")
)

-- =========================
-- SCREENSHOTS
-- =========================

hl.bind(
    mainMod .. " + SHIFT + S",
    hl.dsp.exec_cmd("~/.local/bin/freeze-screenshot")
)

hl.bind(
    mainMod .. " + S",
    hl.dsp.exec_cmd("grim - | wl-copy")
)


-- =========================
-- WONDER MENU
-- =========================

hl.bind(
    mainMod .. " + SHIFT + R",
    hl.dsp.exec_cmd("walker -m menus:main")
)
-- =========================
-- MICROPHONE
-- =========================

hl.bind(
    mainMod .. " + F1",
    hl.dsp.exec_cmd("~/.local/bin/mic-osd")
)

-- =========================
-- THEME SWITCH (линза-анимация)
-- =========================

hl.bind(
    mainMod .. " + F2",
    hl.dsp.exec_cmd("~/.local/bin/rice-theme-toggle")
)

-- =========================
-- CONTROL CENTER
-- =========================

hl.bind(
    mainMod .. " + SHIFT + SPACE",
    hl.dsp.exec_cmd("qs -p ~/.config/quickshell/mybar/shell.qml ipc call controlcenter toggle")
)


-- =========================
-- HYPRLOCK
-- =========================

hl.bind(
    mainMod .. " + L",
    hl.dsp.exec_cmd("hyprlock --config ~/.config/hyprlock/hyprlock.conf")
)

-- =========================
-- FOCUS
-- =========================

hl.bind(
    mainMod .. " + left",
    hl.dsp.focus({
        direction = "left",
    })
)

hl.bind(
    mainMod .. " + right",
    hl.dsp.focus({
        direction = "right",
    })
)

hl.bind(
    mainMod .. " + up",
    hl.dsp.focus({
        direction = "up",
    })
)

hl.bind(
    mainMod .. " + down",
    hl.dsp.focus({
        direction = "down",
    })
)


-- =========================
-- MOVE WINDOWS
-- =========================

hl.bind(
    mainMod .. " + SHIFT + left",
    hl.dsp.window.move({
        direction = "left",
    })
)

hl.bind(
    mainMod .. " + SHIFT + right",
    hl.dsp.window.move({
        direction = "right",
    })
)

hl.bind(
    mainMod .. " + SHIFT + up",
    hl.dsp.window.move({
        direction = "up",
    })
)

hl.bind(
    mainMod .. " + SHIFT + down",
    hl.dsp.window.move({
        direction = "down",
    })
)


-- =========================
-- RESIZE
-- =========================

hl.bind(
    mainMod .. " + CTRL + left",
    hl.dsp.window.resize({
        x = -50,
        y = 0,
        relative = true,
    })
)

hl.bind(
    mainMod .. " + CTRL + right",
    hl.dsp.window.resize({
        x = 50,
        y = 0,
        relative = true,
    })
)

hl.bind(
    mainMod .. " + CTRL + up",
    hl.dsp.window.resize({
        x = 0,
        y = -50,
        relative = true,
    })
)

hl.bind(
    mainMod .. " + CTRL + down",
    hl.dsp.window.resize({
        x = 0,
        y = 50,
        relative = true,
    })
)


-- =========================
-- ALT TAB
-- =========================

hl.bind(
    "ALT + Tab",
    hl.dsp.window.cycle_next()
)

-- =========================
-- MOUSE WINDOW CONTROLS
-- =========================

hl.bind(
    mainMod .. " + mouse:272",
    hl.dsp.window.drag(),
    {
        mouse = true,
    }
)

hl.bind(
    mainMod .. " + mouse:273",
    hl.dsp.window.resize(),
    {
        mouse = true,
    }
)



-- =========================
-- AUTOCLICKER
-- =========================

hl.bind(
    "F6",
    hl.dsp.exec_cmd("omniclicker --toggle")
)
