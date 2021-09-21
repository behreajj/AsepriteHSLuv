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

hsluv = {}

hsluv.m = {
    { 3.240969941904521, -1.537383177570093, -0.498610760293 },
    { -0.96924363628087, 1.87596750150772, 0.041555057407175 },
    { 0.055630079696993, -0.20397695888897, 1.056971514242878 }
}
hsluv.minv = {
    { 0.41239079926595, 0.35758433938387, 0.18048078840183 },
    { 0.21263900587151, 0.71516867876775, 0.072192315360733 },
    { 0.019330818715591, 0.11919477979462, 0.95053215224966 }
}
hsluv.refY = 1.0
hsluv.refU = 0.19783000664283
hsluv.refV = 0.46831999493879
hsluv.kappa = 903.2962962
hsluv.epsilon = 0.0088564516

local distance_line_from_origin = function(line)
    return math.abs(line.intercept) / math.sqrt((line.slope * line.slope) + 1)
end

local length_of_ray_until_intersect = function(theta, line)
    return line.intercept / (math.sin(theta) - line.slope * math.cos(theta))
end

hsluv.get_bounds = function(l)
    local result = {}
    local sub2
    local sub1 = ((l + 16) ^ 3) / 1560896
    if sub1 > hsluv.epsilon then
        sub2 = sub1
    else
        sub2 = l / hsluv.kappa
    end

    for i = 1, 3 do
        local mi = hsluv.m[i]
        local m1 = mi[1]
        local m2 = mi[2]
        local m3 = mi[3]

        for t = 0, 1 do
            local top1 = (284517 * m1 - 94839 * m3) * sub2
            local top2 = (838422 * m3 + 769860 * m2 + 731718 * m1) * l * sub2 - 769860 * t * l
            local bottom = (632260 * m3 - 126452 * m2) * sub2 + 126452 * t
            table.insert(result, {
                slope = top1 / bottom,
                intercept = top2 / bottom
            })
        end
    end
    return result
end

hsluv.max_safe_chroma_for_l = function(l)
    local bounds = hsluv.get_bounds(l)
    local min = 1.7976931348623157e+308

    for i = 1, 6 do
        local length = distance_line_from_origin(bounds[i])
        if length >= 0 then
            min = math.min(min, length)
        end
    end
    return min
end

hsluv.max_safe_chroma_for_lh = function(l, h)
    local hrad = math.rad(h)
    local bounds = hsluv.get_bounds(l)
    local min = 1.7976931348623157e+308

    for i = 1, 6 do
        local bound = bounds[i]
        local length = length_of_ray_until_intersect(hrad, bound)
        if length >= 0 then
            min = math.min(min, length)
        end
    end
    return min
end

hsluv.dot_product = function(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

hsluv.from_linear = function(c)
    if c <= 0.0031308 then
        return 12.92 * c
    else
        return 1.055 * (c ^ 0.4166666666666667) - 0.055
    end
end

hsluv.to_linear = function(c)
    -- 1 / 12.92 = 0.07739938080495357
    -- 1 / 1.055 = 0.9478672985781991
    if c > 0.04045 then
        return ((c + 0.055) * 0.9478672985781991) ^ 2.4
    else
        return c * 0.07739938080495357
    end
end

hsluv.xyz_to_rgb = function(tuple)
    return {
        hsluv.from_linear(hsluv.dot_product(hsluv.m[1], tuple)),
        hsluv.from_linear(hsluv.dot_product(hsluv.m[2], tuple)),
        hsluv.from_linear(hsluv.dot_product(hsluv.m[3], tuple)) }
end

hsluv.rgb_to_xyz = function(tuple)
    local rgbl = {
        hsluv.to_linear(tuple[1]),
        hsluv.to_linear(tuple[2]),
        hsluv.to_linear(tuple[3]) }
    return {
        hsluv.dot_product(hsluv.minv[1], rgbl),
        hsluv.dot_product(hsluv.minv[2], rgbl),
        hsluv.dot_product(hsluv.minv[3], rgbl) }
end

hsluv.y_to_l = function(Y)
    if Y <= hsluv.epsilon then
        return Y / hsluv.refY * hsluv.kappa
    else
        return 116 * ((Y / hsluv.refY) ^ 0.3333333333333333) - 16
    end
end

hsluv.l_to_y = function(L)
    -- 1 / 116 = 0.008620689655172414
    if L <= 8 then
        return hsluv.refY * L / hsluv.kappa
    else
        return hsluv.refY * (((L + 16) * 0.008620689655172414) ^ 3)
    end
end

hsluv.xyz_to_luv = function(tuple)
    local X = tuple[1]
    local Y = tuple[2]
    local divider = X + 15 * Y + 3 * tuple[3]
    local varU = 0
    local varV = 0
    if divider ~= 0 then
        varU = (4 * X) / divider
        varV = (9 * Y) / divider
    end
    local L = hsluv.y_to_l(Y)
    if L == 0 then
        return { 0, 0, 0 }
    end
    return { L, 13 * L * (varU - hsluv.refU), 13 * L * (varV - hsluv.refV) }
end

hsluv.luv_to_xyz = function(tuple)
    local L = tuple[1]
    local U = tuple[2]
    local V = tuple[3]
    if L == 0 then
        return { 0, 0, 0 }
    end
    local varU = U / (13 * L) + hsluv.refU
    local varV = V / (13 * L) + hsluv.refV
    local Y = hsluv.l_to_y(L)
    local X = 0 - (9 * Y * varU) / ((((varU - 4) * varV) - varU * varV))
    return { X, Y, (9 * Y - 15 * varV * Y - varV * X) / (3 * varV) }
end

hsluv.luv_to_lch = function(tuple)
    local L = tuple[1]
    local U = tuple[2]
    local V = tuple[3]
    local chromasq = U * U + V * V
    local H = 0
    local C = 0
    if chromasq > 0.00000001 then
        C = math.sqrt(chromasq)
        H = math.deg(math.atan(V, U))
        if H < 0 then H = 360 + H end
    end
    return { L, C, H }
end

hsluv.lch_to_luv = function(tuple)
    local L = tuple[1]
    local C = tuple[2]
    local Hrad = math.rad(tuple[3])
    return { L, math.cos(Hrad) * C, math.sin(Hrad) * C }
end

hsluv.hsluv_to_lch = function(tuple)
    local H = tuple[1]
    local S = tuple[2]
    local L = tuple[3]
    if L > 99.9999999 then
        return { 100, 0, H }
    end
    if L < 0.00000001 then
        return { 0, 0, H }
    end
    return { L, hsluv.max_safe_chroma_for_lh(L, H) / 100 * S, H }
end

hsluv.lch_to_hsluv = function(tuple)
    local L = tuple[1]
    local C = tuple[2]
    local H = tuple[3]
    local max_chroma = hsluv.max_safe_chroma_for_lh(L, H)
    if L > 99.9999999 then
        return { H, 0, 100 }
    end
    if L < 0.00000001 then
        return { H, 0, 0 }
    end

    return { H, C / max_chroma * 100, L }
end

hsluv.hpluv_to_lch = function(tuple)
    local H = tuple[1]
    local S = tuple[2]
    local L = tuple[3]
    if L > 99.9999999 then
        return { 100, 0, H }
    end
    if L < 0.00000001 then
        return { 0, 0, H }
    end
    return { L, hsluv.max_safe_chroma_for_l(L) / 100 * S, H }
end

hsluv.lch_to_hpluv = function(tuple)
    local L = tuple[1]
    local C = tuple[2]
    local H = tuple[3]
    if L > 99.9999999 then
        return { H, 0, 100 }
    end
    if L < 0.00000001 then
        return { H, 0, 0 }
    end
    return { H, C / hsluv.max_safe_chroma_for_l(L) * 100, L }
end

hsluv.lch_to_rgb = function(tuple)
    return hsluv.xyz_to_rgb(hsluv.luv_to_xyz(hsluv.lch_to_luv(tuple)))
end

hsluv.rgb_to_lch = function(tuple)
    return hsluv.luv_to_lch(hsluv.xyz_to_luv(hsluv.rgb_to_xyz(tuple)))
end

hsluv.hsluv_to_rgb = function(tuple)
    return hsluv.lch_to_rgb(hsluv.hsluv_to_lch(tuple))
end

hsluv.rgb_to_hsluv = function(tuple)
    return hsluv.lch_to_hsluv(hsluv.rgb_to_lch(tuple))
end

hsluv.hpluv_to_rgb = function(tuple)
    return hsluv.lch_to_rgb(hsluv.hpluv_to_lch(tuple))
end

hsluv.rgb_to_hpluv = function(tuple)
    return hsluv.lch_to_hpluv(hsluv.rgb_to_lch(tuple))
end

return hsluv