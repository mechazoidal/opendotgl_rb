#version 150 core

/* uniform vec3 triangleColor; */
/* in vec3 Color; */
in float Color;

out vec4 outColor;

void main()
{
  /* outColor = vec4(triangleColor, 1.0); */
  /* outColor = vec4(Color, 1.0); */
  /* outColor = vec4((-Color), 1.0); */
  /* outColor = vec4(1.0 - Color.r, 1.0 - Color.g, 1.0 - Color.b, 1.0); */
  outColor = vec4(Color, Color, Color, 1.0);
}
