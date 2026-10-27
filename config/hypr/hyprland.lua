-- Hyprland 0.56.2

local mainMod = "SUPER"

hl.env("HYPRCURSOR_THEME", "Rage-Gothic")
hl.env("HYPRCURSOR_SIZE", "36")
hl.env("XCURSOR_THEME", "Rage-Gothic-Cursor")
hl.env("XCURSOR_SIZE", "24")

hl.monitor({
    output = "",
    mode = "1920x1080@180",
    position = "auto",
    scale = 1,
})

require("modules.programs")
require("modules.appearance")
require("modules.input")
require("modules.autostart")
require("modules.audio")
require("modules.binds")
require("modules.workspaces")
require("modules.cursor")


hl.window_rule({
    name = "btop-floating",
    match = {
        class = "^btop-terminal$",
    },
    float = true,
    center = true,
    size = {900, 600},
})

-- Игры Steam: отключённый VSync (tearing), как в fullscreen на Windows.
-- Работает, только если в самой игре выключена вертикальная синхронизация.
hl.window_rule({
    name = "steam-games-tearing",
    match = {
        class = "^steam_app_",
    },
    immediate = true,
})


hl.window_rule({
    name = "switchcalc-floating",
    match = {
        class = "^com\\.switchcalc\\.app$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "obsidian-floating",
    match = {
        class = "^md\\.obsidian\\.Obsidian$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "ghostwriter-floating",
    match = {
        class = "^(org\\.kde\\.ghostwriter|ghostwriter)$",
    },
    float = true,
    center = true,
    size = {1000, 720},
})
