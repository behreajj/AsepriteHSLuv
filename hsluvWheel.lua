--[[
Lua implementation of HSLuv and HPLuv color spaces
Homepage: http://www.hsluv.org/

Copyright (C) 2019 Alexei Boronine

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

dofile("./hsluv.lua")

local harmonies = {
    "ANALOGOUS",
    "COMPLEMENT",
    "SPLIT",
    "SQUARE",
    "TRIADIC"
}

local shadingCount = 7
local dayHue = 76
local shadowHue = 274
local shadowLight = 10
local dayLight = 90
local minGreenOff = 0.5
local maxGreenOff = 0.7

local palColors = {
    Color(234,   0, 100, 255),
    Color(188,  92,   0, 255),
    Color(149, 114,   0, 255),
    Color(119, 124,   0, 255),
    Color( 63, 135,   0, 255),
    Color(  0, 136,  93, 255),
    Color(  0, 134, 124, 255),
    Color(  0, 131, 147, 255),
    Color(  0, 126, 183, 255),
    Color(121,  89, 255, 255),
    Color(205,   0, 226, 255),
    Color(222,   0, 170, 255) }

local defaults = {
    preview = Color(234, 0, 100, 255),
    hexCode = "ea0064",
    hue = 0,
    saturation = 100,
    lightness = 50,
    alpha = 255,

    showShading = false,

    showWheelSettings = false,
    size = 256,
    minLight = 5,
    maxLight = 95,
    sectorCount = 0,
    ringCount = 0,
    frames = 32,
    fps = 24,

    showHarmonies = false,
    harmonyType = "TRIADIC",
    analogies = {
        Color(222,   0, 170, 255),
        Color(188,  93,   0, 255) },
    complement = { Color(0, 134, 124, 255) },
    splits = {
        Color(  0, 136,  94, 255),
        Color(  0, 131, 147, 255) },
    squares = {
        Color(118, 124,   0, 255),
        Color(  0, 134, 124, 255),
        Color(121,  89, 255, 255) },
    triads = {
        Color(  0, 126, 183, 255),
        Color( 62, 135,   0, 255) },
}

local primary = Color(234, 0, 100, 255)

local dlg = Dialog { title = "HSLuv Color Picker" }

local function copyColorByValue(aseColor)
    return Color(
        aseColor.red,
        aseColor.green,
        aseColor.blue,
        aseColor.alpha)
end

local function assignColor(aseColor)
    if aseColor.alpha > 0 then
        return copyColorByValue(aseColor)
    else
        return Color(0, 0, 0, 0)
    end
end

local function colorToHexWeb(aseColor)
    return string.format("%06x",
        aseColor.red << 0x10
        | aseColor.green << 0x08
        | aseColor.blue)
end

local function createNewFrames(sprite, count, duration)
    if not sprite then
        app.alert("Sprite could not be found.")
        return {}
    end

    if count < 1 then return {} end
    if count > 256 then
        local response = app.alert {
            title = "Warning",
            text = {
                string.format(
                    "This script will create %d frames,",
                    count),
                string.format(
                    "%d beyond the limit of %d.",
                    count - 256,
                    256),
                "Do you wish to proceed?"
            },
            buttons = { "&YES", "&NO" }
        }

        if response == 2 then
            return {}
        end
    end

    local valDur = duration or 1
    local valCount = count or 1
    if valCount < 1 then valCount = 1 end

    local frames = {}
    app.transaction(function()
        for i = 1, valCount, 1 do
            local frame = sprite:newEmptyFrame()
            frame.duration = valDur
            frames[i] = frame
        end
    end)
    return frames
end

local function lerpAngleNear(origin, dest, t, range)
    local valRange = range or 360.0
    local halfRange = valRange * 0.5

    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o < d and diff > halfRange then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff < -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

local function lerpAngleCcw(origin, dest, t, range)
    local valRange = range or 360.0
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o > d then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

local function lerpAngleCw(origin, dest, t, range)
    local valRange = range or 360.0
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return d
    elseif o < d then
        return (u * (o + valRange) + t * d) % valRange
    else
        return u * o + t * d
    end
end

local function pingPong(t)
    return 0.5 + 0.5 * math.cos((t - 0.5) * 6.283185307179586)
end

local function rgbTupToAseColor(rgb, a)
    local aVal = a or 255
    return Color(
        math.tointeger(0.5 + 255.0 * rgb[1]),
        math.tointeger(0.5 + 255.0 * rgb[2]),
        math.tointeger(0.5 + 255.0 * rgb[3]),
        aVal)
end

local function quantizeSigned(a, levels)
    if levels ~= 0 then
        return math.floor(0.5 + a * levels) / levels
    else
        return a
    end
end

local function quantizeUnsigned(a, levels)
    if levels > 1 then
        return math.max(0.0,
            (math.ceil(a * levels) - 1.0)
            / (levels - 1.0))
    else
        return math.max(0.0, a)
    end
end

local function updateHarmonies(dialog, h, s, l, a)
    local ana0 = hsluv.hsluv_to_rgb({ h - 30, s, l })
    local ana1 = hsluv.hsluv_to_rgb({ h + 30, s, l })

    local tri0 = hsluv.hsluv_to_rgb({ h - 120, s, l })
    local tri1 = hsluv.hsluv_to_rgb({ h + 120, s, l })

    local split0 = hsluv.hsluv_to_rgb({ h + 150, s, l })
    local split1 = hsluv.hsluv_to_rgb({ h + 210, s, l })

    local square0 = hsluv.hsluv_to_rgb({ h + 90, s, l })
    local square1 = hsluv.hsluv_to_rgb({ h + 180, s, l })
    local square2 = hsluv.hsluv_to_rgb({ h + 270, s, l })

    local tris = {
        rgbTupToAseColor(tri0),
        rgbTupToAseColor(tri1)
    }

    local analogues = {
        rgbTupToAseColor(ana0),
        rgbTupToAseColor(ana1)
    }

    local splits = {
        rgbTupToAseColor(split0),
        rgbTupToAseColor(split1)
    }

    local squares = {
        rgbTupToAseColor(square0),
        rgbTupToAseColor(square1),
        rgbTupToAseColor(square2)
    }

    dialog:modify { id = "complement", colors = { squares[2] } }
    dialog:modify { id = "triadic", colors = tris }
    dialog:modify { id = "analogous", colors = analogues }
    dialog:modify { id = "split", colors = splits }
    dialog:modify { id = "square", colors = squares }
end

local function updateShading(dialog, h, s, l, a)

    -- Decide whether to go clockwise or counter-clockwise
    -- based on the color's "warmth" or "coolness".
    -- 86 is the HSLuv hue for yellow (#ffff00).
    local lerpFunc = nil
    if h <= 86 or h >= 266 then
        lerpFunc = lerpAngleCcw
    else
        lerpFunc = lerpAngleCw
    end

    -- Decide on a weight betweeen absolute lightness
    -- and relative lightness based on the source.
    local lFac = l * 0.01
    local srcLightWeight = 0.333
    local cmpLightWeight = 1.0 - srcLightWeight

    local shades = {}
    local toFac = 1.0 / (shadingCount - 1.0)

    -- The "warm" and "cool" dichotomy doesn't make much
    -- sense for green. So the closer the hue is to the green
    -- range (130), the more it needs to shift its offset.
    local offFac = math.abs(math.fmod(h, 180) - 130) / 180.0
    offFac = 1.0 - math.max(0.0, math.min(1.0, offFac))
    local off = (1.0 - offFac) * minGreenOff + offFac * maxGreenOff
    -- print(offFac)
    -- print(off)

    for i = 0, shadingCount - 1, 1 do
        local t = srcLightWeight * lFac
                + cmpLightWeight * (i * toFac)
        local u = 1.0 - t

        local lShade = u * shadowLight + t * dayLight
        local hNeutral = lerpFunc(shadowHue, dayHue, t, 360.0)

        local tOsc = pingPong(t)
        local f = tOsc * off

        local hShade = lerpAngleNear(h, hNeutral, f, 360.0)
        local hsluvtup = { hShade, s, lShade }
        local shadetup = hsluv.hsluv_to_rgb(hsluvtup)
        local aseShade = rgbTupToAseColor(shadetup, a)
        shades[i + 1] = aseShade
    end

    dialog:modify {
        id = "shading",
        colors = shades
    }
end

local function updateColor(dialog)
    local data = dialog.data

    local h = data.hue
    local s = data.saturation
    local l = data.lightness
    local a = data.alpha

    local rgb = hsluv.hsluv_to_rgb({ h, s, l })
    primary = rgbTupToAseColor(rgb, a)

    dialog:modify {
        id = "preview",
        colors = { primary }
    }

    dialog:modify {
        id = "hexCode",
        text = colorToHexWeb(primary)
    }

    updateHarmonies(dialog, h, s, l, a)
    updateShading(dialog, h, s, l, a)
end

local function setFromAse(dialog, aseColor)
    primary = copyColorByValue(aseColor)
    local alpha = primary.alpha
    local hexstr = colorToHexWeb(primary)

    local hsl = hsluv.rgb_to_hsluv({
        primary.red * 0.00392156862745098,
        primary.green * 0.00392156862745098,
        primary.blue * 0.00392156862745098 })

    local hdbl = hsl[1]
    local sdbl = hsl[2]
    local ldbl = hsl[3]

    local hint = math.tointeger(0.5 + hdbl)
    local sint = math.tointeger(0.5 + sdbl)
    local lint = math.tointeger(0.5 + ldbl)

    dialog:modify { id = "alpha", value = alpha }
    dialog:modify { id = "lightness", value = lint }
    dialog:modify { id = "saturation", value = sint }
    dialog:modify { id = "preview", colors = { primary } }
    dialog:modify { id = "hexCode", text = hexstr }

    if sint > 0 then
        dialog:modify { id = "hue", value = hint }
    end

    updateHarmonies(dialog, hdbl, sdbl, ldbl, alpha)
    updateShading(dialog, hdbl, sdbl, ldbl, alpha)
end

dlg:button {
    id = "fgGet",
    label = "Get:",
    text = "&FORE",
    focus = false,
    onclick = function()
       setFromAse(dlg, app.fgColor)
    end
}

dlg:button {
    id = "bgGet",
    text = "&BACK",
    focus = false,
    onclick = function()
       app.command.SwitchColors()
       setFromAse(dlg, app.fgColor)
       app.command.SwitchColors()
    end
}

dlg:shades {
    id = "preview",
    label = "Preview:",
    mode = "pick",
    colors = { defaults.preview },
    visible = not defaults.showShading,
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            app.fgColor = assignColor(ev.color)
        elseif button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = assignColor(ev.color)
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "shading",
    label = "Shading:",
    mode = "pick",
    colors = {
        Color(114,   0,  58, 255),
        Color(150,   0,  86, 255),
        Color(190,   0, 106, 255),
        Color(233,   0, 109, 255),
        Color(255,  72, 106, 255),
        Color(255, 125, 134, 255),
        Color(255, 164, 174, 255) },
    visible = defaults.showShading,
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            app.fgColor = assignColor(ev.color)
        elseif button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = assignColor(ev.color)
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "hexCode",
    label = "Hex: #",
    text = "ea0064",
    focus = false,
    visible = not defaults.showShading
}

dlg:newrow { always = false }

dlg:slider {
    id = "hue",
    label = "Hue:",
    min = 0,
    max = 360,
    value = defaults.hue,
    onchange = function()
        updateColor(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "saturation",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = defaults.saturation,
    onchange = function()
        updateColor(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "lightness",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = defaults.lightness,
    onchange = function()
        updateColor(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "alpha",
    label = "Alpha:",
    min = 0,
    max = 255,
    value = defaults.alpha,
    onchange = function()
        updateColor(dlg)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "size",
    label = "Size:",
    min = 64,
    max = 512,
    value = defaults.size,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "minLight",
    label = "Light:",
    min = 1,
    max = 98,
    value = defaults.minLight,
    visible = defaults.showWheelSettings
}

dlg:slider {
    id = "maxLight",
    min = 2,
    max = 99,
    value = defaults.maxLight,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "frames",
    label = "Frames:",
    min = 1,
    max = 96,
    value = defaults.frames,
    visible = defaults.showWheelSettings
}

-- dlg:newrow { always = false }

-- dlg:slider {
--     id = "fps",
--     label = "FPS:",
--     min = 1,
--     max = 90,
--     value = defaults.fps,
--     visible = defaults.showWheelSettings
-- }

dlg:newrow { always = false }

dlg:slider {
    id = "sectorCount",
    label = "Sectors:",
    min = 0,
    max = 32,
    value = defaults.sectorCount,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "ringCount",
    label = "Rings:",
    min = 0,
    max = 32,
    value = defaults.ringCount,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:combobox {
    id = "harmonyType",
    label = "Harmony:",
    option = defaults.harmonyType,
    options = harmonies,
    visible = defaults.showHarmonies,
    onchange = function()
        local md = dlg.data.harmonyType
        dlg:modify { id = "complement", visible = md == "COMPLEMENT" }
        dlg:modify { id = "triadic", visible = md == "TRIADIC" }
        dlg:modify { id = "analogous", visible = md == "ANALOGOUS" }
        dlg:modify { id = "split", visible = md == "SPLIT" }
        dlg:modify { id = "square", visible = md == "SQUARE" }
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "analogous",
    label = "Analogous:",
    mode = "pick",
    colors = defaults.analogies,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "ANALOGOUS",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif button == MouseButton.RIGHT then
            app.fgColor = assignColor(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "complement",
    label = "Complement:",
    mode = "pick",
    colors = defaults.complement,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "COMPLEMENT",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif button == MouseButton.RIGHT then
            app.fgColor = assignColor(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "split",
    label = "Split:",
    mode = "pick",
    colors = defaults.splits,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "SPLIT",
    onclick = function(ev)
        local button = ev.button
        if ev.button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif button == MouseButton.RIGHT then
            app.fgColor = assignColor(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "square",
    label = "Square:",
    mode = "pick",
    colors = defaults.squares,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "SQUARE",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif button == MouseButton.RIGHT then
            app.fgColor = assignColor(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "triadic",
    label = "Triadic:",
    mode = "pick",
    colors = defaults.triads,
    visible = defaults.showHarmonies
        and defaults.harmonyType == "TRIADIC",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            setFromAse(dlg, ev.color)
        elseif button == MouseButton.RIGHT then
            app.fgColor = assignColor(ev.color)
        end
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "showShading",
    label = "Show:",
    text = "Shading",
    selected = defaults.showShading,
    onclick = function()
        local state = dlg.data.showShading
        dlg:modify { id = "shading", visible = state }
        dlg:modify { id = "preview", visible = not state }
        dlg:modify { id = "hexCode", visible = not state }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "showWheelSettings",
    text = "Wheel Settings",
    selected = defaults.showWheelSettings,
    onclick = function()
        local state = dlg.data.showWheelSettings
        dlg:modify { id = "size", visible = state }
        dlg:modify { id = "minLight", visible = state }
        dlg:modify { id = "maxLight", visible = state }
        dlg:modify { id = "frames", visible = state }
        -- dlg:modify { id = "fps", visible = state }
        dlg:modify { id = "sectorCount", visible = state }
        dlg:modify { id = "ringCount", visible = state }
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "showHarmonies",
    text = "Harmonies",
    selected = defaults.showHarmonies,
    onclick = function()
        local args = dlg.data
        local state = args.showHarmonies
        dlg:modify { id = "harmonyType", visible = state }
        if state then
            local md = args.harmonyType
            dlg:modify { id = "complement", visible = md == "COMPLEMENT" }
            dlg:modify { id = "triadic", visible = md == "TRIADIC" }
            dlg:modify { id = "analogous", visible = md == "ANALOGOUS" }
            dlg:modify { id = "split", visible = md == "SPLIT" }
            dlg:modify { id = "square", visible = md == "SQUARE" }
        else
            dlg:modify { id = "complement", visible = false }
            dlg:modify { id = "triadic", visible = false }
            dlg:modify { id = "analogous", visible = false }
            dlg:modify { id = "split", visible = false }
            dlg:modify { id = "square", visible = false }
        end
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "wheel",
    text = "&WHEEL",
    focus = defaults.pullFocus,
    onclick = function()
        local args = dlg.data

        -- Cache methods.
        -- atan is atan2 in newer Lua; older atan2 is deprecated.
        local atan2 = math.atan
        local sqrt = math.sqrt
        local trunc = math.tointeger

        -- Unpack arguments.
        local size = args.size or defaults.size
        local szInv = 1.0 / (size - 1.0)
        local iToStep = 1.0
        local reqFrames = args.frames or defaults.frames
        if reqFrames > 1 then iToStep = 1.0 / (reqFrames - 1.0) end
        local minLight = args.minLight or defaults.minLight
        local maxLight = args.maxLight or defaults.maxLight
        local ringCount = args.ringCount or defaults.ringCount
        local sectorCount = args.sectorCount or defaults.sectorCount

        -- Offset by 30 degrees to match Aseprite's color wheel.
        local angleOffset = math.rad(30.0)

        local wheelImgs = {}
        for i = 1, reqFrames, 1 do
            local wheelImg = Image(size, size)

            -- Calculate light from frame count.
            local t = (i - 1.0) * iToStep
            local light = (1.0 - t) * minLight + t * maxLight

            -- Iterate over image pixels.
            local pxItr = wheelImg:pixels()
            for elm in pxItr do

                -- Find rise.
                local y = elm.y
                local yNrm = y * szInv
                local ySgn = 1.0 - (yNrm + yNrm)

                -- Find run.
                local x = elm.x
                local xNrm = x * szInv
                local xSgn = xNrm + xNrm - 1.0

                -- Find square magnitude.
                -- Magnitude correlates with saturation.
                local sqSat = xSgn * xSgn + ySgn * ySgn
                if sqSat <= 1.0 then
                    local rgbtuple = { 0.0, 0.0, 0.0 }

                    if sqSat > 0.0 then

                        -- Convert square magnitude to magnitude.
                        local sat = sqrt(sqSat)
                        local hue = atan2(ySgn, xSgn) + angleOffset

                        -- Convert from [-PI, PI] to [0.0, 1.0].
                        -- 1 / TAU approximately equals 0.159.
                        -- % operator is floor modulo.
                        hue = hue * 0.15915494309189535
                        hue = hue % 1.0

                        hue = quantizeSigned(hue, sectorCount)
                        sat = quantizeUnsigned(sat, ringCount)

                        hue = hue * 360
                        sat = sat * 100

                        rgbtuple = hsluv.hsluv_to_rgb({ hue, sat, light })
                    else
                        rgbtuple = hsluv.hsluv_to_rgb({ 0.0, 0.0, light })
                    end

                    -- Round [0.0, 1.0] up to [0, 255] unsigned byte.
                    local r255 = trunc(0.5 + rgbtuple[1] * 255.0)
                    local g255 = trunc(0.5 + rgbtuple[2] * 255.0)
                    local b255 = trunc(0.5 + rgbtuple[3] * 255.0)

                    -- Composite into a 32-bit integer.
                    local hex = 0xff000000
                        | b255 << 0x10
                        | g255 << 0x08
                        | r255

                    -- Assign to iterator.
                    elm(hex)
                else
                    elm(0)
                end
            end
            wheelImgs[i] = wheelImg
        end

        -- Create frames.
        local sprite = Sprite(size, size)
        local oldFrameLen = #sprite.frames
        local needed = math.max(0, reqFrames - oldFrameLen)
        local fps = args.fps or defaults.fps
        local duration = 1.0 / math.max(1, fps)
        sprite.frames[1].duration = duration
        local newFrames = createNewFrames(sprite, needed, duration)

        -- Set first layer to gamut.
        local gamutLayer = sprite.layers[1]
        gamutLayer.name = "Color Wheel"

        -- Create gamut layer cels.
        app.transaction(function()
            for i = 1, reqFrames, 1 do
                sprite:newCel(
                    gamutLayer,
                    sprite.frames[i],
                    wheelImgs[i])
            end
        end)

        -- Assign a palette.
        local pal = Palette(#palColors)
        for i = 1, #palColors, 1 do
            pal:setColor(i - 1, palColors[i])
        end
        sprite:setPalette(pal)

        -- Because light correlates to frames, the middle
        -- frame should be the default.
        app.activeFrame = sprite.frames[
            math.ceil(#sprite.frames / 2)]
        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }