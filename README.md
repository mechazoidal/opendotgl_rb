# open.gl.rb
This is a port of the [open.gl](https://open.gl) modern OpenGL examples to Ruby 2.2+. 

It started out as trying to get acquainted with the `opengl-bindings` gem and quickly expanded out of hand into a crash-course in OpenGL along with demonstrating use of the Fiddle FFI library.

## Tested Platforms
  - OpenBSD 6.5, Intel(R) HD Graphics 5300
  - OSX 10.11 w/ Macports, NVidia GeForce 9400M

## Requirements:
### Base
  - Ruby 2.2+
  - SDL2, SDL_image
  - OpenGL hardware + driver that supports at least 3.2.

## Use
Run `bundle install`

## Opinions
The open.gl author leaves it up to the student to select a OpenGL context library(SDL, GLFW, SFML) and other helper libraries(like SOIL and GLM). These examples already have helper libraries:
  - [SDL2](https://rubygems.org/gems/ruby-sdl2): consistent OpenGL access across platforms and, unless you _really_ want to dig into PNG parsing, SDL_image will save you many headaches.
  - [opengl-bindings](https://rubygems.org/gems/opengl-bindings): the lowest-level OpenGL bindings available, with the tradeoff that a lot of Fiddle usage is required.
  - [rmath3d](https://github.com/vaiorabbit/rmath3d): also from vaiorabbit, this is a matrix class that is better suited to 3D and linear algebra than Ruby's standard library.

Additionally, the original sample texture PNG images were not completely compliant with the PNG standard and caused visual errors. I've replaced them with public-domain images taken from NASA:
  - sample_earth: https://nasa3d.arc.nasa.gov/detail/as10-34-5013
  - sample_moon: https://nasa3d.arc.nasa.gov/detail/as11-44-6665

They were converted from the JPEG originals through ImageMagick like so:
  - `convert as10-34-5013.jpg -resize 512x512\! sample_earth.png`
  - `convert as11-44-6665.jpg -resize 512x512\! sample_moon.png`

## Known bugs
  - stencils.rb, transformations.rb, and framebuffer.rb have perspective distortions compared to the originals: this could be from changes in floating-point rounding.
  - Examples do not check for required OpenGL extensions: on most current machines/GPUs(<5 years old) this will not be an issue, but missing any required extensions may cause a hard crash or garbage visual output.

## Licensing
Specific Ruby code in this repository is covered under the terms of the MIT License detailed in the LICENSE file. The shader files are derived from [open.gl](https://open.gl).

The sample texture images are derived from NASA original images and are provided for educational purposes as stated in the [NASA Media Usage Guidelines](https://www.nasa.gov/multimedia/guidelines/index.html)

## Credits
  - [Scott Francis](https://www.kurokoproject.com)
  - [Alexander Overvoorde](https://open.gl) for the original open.gl tutorials. If you like this port, the original lessons are well worth checking out!
  - [vaiorabbit](https://github.com/vaiorabbit) for the excellent opengl-bindings and rmath3d gems along with the [perfume_dance](https://github.com/vaiorabbit/perfume_dance) repository, which served as a crash-course for using OpenGL through Fiddle.

