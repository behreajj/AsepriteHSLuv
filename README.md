- [AsepriteHSLuv](#asepritehsluv)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Credits](#credits)
  - [Changes](#changes)
  - [License](#license)

# AsepriteHSLuv

This is an [Aseprite](https://www.aseprite.org/) dialog that wraps [HSLuv](https://www.hsluv.org) to provide a color picker and a color wheel generator.

From the website linked above, HSLuv is

> a human-friendly alternative to HSL. \[...\] HSLuv extends CIELUV with a new saturation component that allows you to span all the available chroma as a neat percentage.

Aseprite is an "animated sprite editor & pixel art tool."

## Installation

To use this script, open Aseprite, go to `File > Scripts > Open Scripts Folder`. Copy and paste the two Lua scripts from this repository into that folder. Return to Aseprite; go to `File > Scripts > Rescan Scripts Folder` (the default hotkey is `F5`). The two scripts should now be listed under `File > Scripts`. Select `hsluvWheel` to launch the dialog.

To assign a hotkey to the dialog script go to `Edit > Keyboard Shortcuts`.

## Usage

![screen cap](screenCap.png)

Left click on the color preview window to assign the color to the foreground. Right click to assign to the background. If the alpha channel slider is zero, the color assigned will be transparent black (`0x0` or `Color(0, 0, 0, 0)`).

The hexadecimal field is visible when `Shading` is off. It is read-only; you cannot change the color by typing a new hexadecimal code into the field. It is there to make copying and pasting the hex easier.

Hues in HSLuv are not the same as in LCh, HSL or HSV. For example, red (`#ff0000`) is at approximately (12, 100, 53) in HSLuv. Do not assume the same primaries, or the same spatial relationships between colors.

When the `Wheel` button is clicked, a new sprite is created. In this sprite, lightness varies with the frame index. Use the arrow keys to navigate through each frame and thus change the lightness. The sprite defaults to the middle frame, so moving left would decrease the lightness; moving right would increase the lightness.

The color wheel's hue is shifted by 30 degrees to match the Aseprite convention.

Click on the `Shading` toggle to switch from a single color to a set of seven swatches. Algorithmic hue shifting as light changes will not provide ideal results in all contexts.

Click on the `Wheel Settings` and `Harmonies` toggles to show more parameters. For example, the `Sectors` and `Rings` parameters can be used to make the color wheel discrete in a fashion similar to Aseprite's built-in color wheels.

Supported harmonies are: analogous, complementary, split, square and triadic. Left click on a harmony to make it the picker's primary color. Right click on a harmony to assign it to the foreground.

The underlined letters on each button indicate that they work with keyboard shortcuts: `Alt+F` gets the foreground color, `Alt+B` gets the background color, `Alt+C` closes the dialog, `Alt+W` creates a wheel.

This tool -- its harmony and shading features in particular -- is an imperfect aide to artistic judgment, not a replacement for it. See Pixel Parmesan's "[Color Theory for Pixel Artists: It's All Relative](https://pixelparmesan.com/color-theory-for-pixel-artists-its-all-relative/)" on the subject.

_This script was tested in Aseprite version 1.3-beta-6._ It assumes that it will be used in RGB color mode, not indexed or gray mode. Furthermore, it assumes that [sRGB](https://www.wikiwand.com/en/SRGB) (standard RGB) is the working color space.

To modify this script, see Aseprite's [API Reference](https://github.com/aseprite/api).

## Credits

HSLuv is by [Alexei Boronine](https://github.com/boronine). The Lua implementation is sourced from [this repository](https://github.com/hsluv/hsluv-lua). The README from that repository credits [Mark Wonnacott](https://github.com/Ragzouken) for the implementation. For more credits, see this [section](https://www.hsluv.org/credits/) on the HSLuv website. 

## Changes

Changes have been made to the Lua code. First, to remove hexadecimal `string` conversions. Second to update function conventions, i.e., `math.atan` (not `math.atan2`) and `math.rad`. Third, to avoid unecessary square root calculations for desaturated colors. Fourth, to simplify the dot product implementation.

## License

This repository uses the MIT License from the [reference implementation](https://github.com/hsluv/hsluv/blob/master/LICENSE). The Lua implementation repository does not have a formal license, but issues the following in its README and in the code file.

> Copyright (C) 2019 Alexei Boronine
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.