hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,

        border_size = 2,

        col = {
            active_border = {
                colors = {
                    "rgba(7f8ff5ff)",
                    "rgba(a5b4fcff)",
                },
                angle = 45,
            },

            inactive_border = "rgba(2d3042aa)",
        },

        resize_on_border = true,
        allow_tearing = true,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        rounding_power = 2,

        active_opacity = 1.0,
        inactive_opacity = 0.94,

        shadow = {
            enabled = true,
            range = 8,
            render_power = 3,
            color = 0xaa000000,
        },

        blur = {
            enabled = true,
            size = 5,
            passes = 2,
            vibrancy = 0.15,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },
})
