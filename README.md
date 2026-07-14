# Modin's Image viewer

**Image Viewer, and Image Loading Library in Zig.**

## Why

Wanted to have my own image library, since some libraries does not have support for some formats.
It gets anoying trying to find and add some new libraries when this arises.
Now I can atleast blame myself if it does not work :D

To test the library (that is not yet really a library, but part of this repo as of now),
I created a small image viewer using sdl.
The bindings for Zig are handwritten and are just added as quickly as possible (therefore not exactly beautiful. Might clean up as I go along).

## Future

This will probably become 2, possibly 3, repositories eventually.
This Repository for the Image Viewer, One new for the Image library and one additional for the SDL bindings (maybe).

The Image Viewer needs to become less cumbersome for viewing:
* Better default at startup.
* Better zooming.
* Loading images from within the application.
* Open a directory for "Scrolling" between images in a directory.

The Image Library:
* Major refactor, the code is really ugly at the moment (ongoing).
* Saving of images.
* More support for formats
* More metadata loading and handling.
* PNG: Support for BitDepth of 1, 2, 4 and 16
* PNG: Support for Interlacing
* JPEG: Support for Progressive loading.

SDL Bindings:
* Just alot of cleanup
* Better concepts for Zig bindings, right now, just calling to C.
