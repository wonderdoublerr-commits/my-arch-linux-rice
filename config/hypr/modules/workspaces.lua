local mainMod = "SUPER"

for i = 1, 6 do

    hl.bind(
        mainMod .. " + " .. i,
        hl.dsp.focus({
            workspace = i,
        })
    )

    hl.bind(
        mainMod .. " + SHIFT + " .. i,
        hl.dsp.window.move({
            workspace = i,
        })
    )

end
