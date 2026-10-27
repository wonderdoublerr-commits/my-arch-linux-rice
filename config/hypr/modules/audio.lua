hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("swayosd-client --output-volume raise"),
    {
        locked = true,
        repeating = true,
    }
)

hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("swayosd-client --output-volume lower"),
    {
        locked = true,
        repeating = true,
    }
)

hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"),
    {
        locked = true,
        repeating = true,
    }
)

