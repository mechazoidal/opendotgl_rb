#version 150 core

in vec2 position;
/* in vec3 color; */
/* out vec3 Color; */
in float color;
out float Color;


void main()
{
  Color = color;
  gl_Position = vec4(position, 0.0, 1.0);
  /* gl_Position = vec4(position.x, -position.y, 0.0, 1.0); */
}
