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
