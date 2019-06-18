
sample_earth: https://nasa3d.arc.nasa.gov/detail/as10-34-5013
sample_moon: https://nasa3d.arc.nasa.gov/detail/as11-44-6665
`convert as10-34-5013.jpg -resize 512x512\! sample_earth.png`
`convert as11-44-6665.jpg -resize 512x512\! sample_moon.png`
= Opinions
  - SDL2: able to use SDL_image, very consistent across platforms.
  - opengl-bindings: the lowest-level bindings you can get, with the tradeoff that a lot of [[Fiddle]] usage is required.
  - rmath3d: also from [ogl bindings author], this is a matrix class that is better suited to 3D and linear algebra than Ruby's standard library.

= TODO

= Known bugs
Examples do not check for required OpenGL extensions: on most current machines/GPUs(<5 years old) this will not be an issue, but missing any required extensions may cause a hard crash or garbage visual output.
