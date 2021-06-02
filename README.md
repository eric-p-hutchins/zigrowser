Zigrowser
=========

The web browser written in Zig!

![The start page](/screenshot01.png)

Ok... so I'm just playing around and learning to use Zig for this project. This probably won't really go
anywhere. But it's inspiring other things that might be interesting to build for Zig:

 * A BDF (Glyph Bitmap Distribution Format) package
   * I wanted a little font to use for testing and ran into this format. It's a neat little spec
 * A TrueType font parsing/rendering library
   * Ok, so I'm using FreeType... which would be a massive project to replicate, so this is probably good
     enough. Zig is highly compatible with C for a reason, after all.
 * An HTML parsing library

These are certainly not the only things that would be cool to have in Zig, but just a few obvious ones that
might be fun to start playing with.

To get the PressStart2P font as a BDF I used the following command:

```sh
otf2bdf -r 96 -p 12 src/PressStart2P-Regular.ttf > src/PressStart2P-16.bdf
```

I then manually changed the font bounding box's height to 16 like this:

```diff
--- a/src/PressStart2P-16.bdf
+++ b/src/PressStart2P-16.bdf
@@ -4,7 +4,7 @@ COMMENT Converted from OpenType font "PressStart2P-Regular.ttf" by "otf2bdf 3.0"
 COMMENT
 FONT -FreeType-Press Start 2P-Medium-R-Normal--16-120-96-96-P-134-ISO10646-1
 SIZE 12 96 96
-FONTBOUNDINGBOX 28 22 -12 -6
+FONTBOUNDINGBOX 28 16 -12 -6
 STARTPROPERTIES 19
 FOUNDRY "FreeType"
 FAMILY_NAME "Press Start 2P"
```

## TODO ##

* Parse attributes and store the style information somewhere
* Parse the `<style>` block in the header of the welcome page:
  * `background-color: #131315;`
  * `color: white;`
  * `font-family`, `font-size`, and the `@font-face` loading of the font I currently get for free because I
    use the given values as browser defaults, which I will leave alone for now
* Use style info from `<body>` for `margin`
* Use style info from `<div>` for `padding`, `margin`, `background-color`, `border`, and `text-align`
* Use style info from `<img>` for `width` and `margin-bottom`
* Make welcome page officially have URL of `zigrowser://welcome`, make `zigrowser://zigrowser.png` resolve to
  the image, and make the `src=...` attribute of the `<img>` in the welcome page point to `/zigrowser.png`
* Add an address bar for browsing
* Implement `file:///` protocol for local browsing
* Implement `http://` protocol and test with `http://zig.show` so that I can continue to pretend that
  "PressStart2P" is a reasonable choice for a default font ;-P
* ~Fix memory leaks~
