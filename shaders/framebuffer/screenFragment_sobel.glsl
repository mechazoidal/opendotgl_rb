#version 150 core
in vec2 Texcoord;
out vec4 outColor;
uniform sampler2D texFramebuffer;
void main()
{
  vec4 top           = texture(texFramebuffer, vec2(Texcoord.x, Texcoord.y + 1.0 / 200.0));
  vec4 bottom        = texture(texFramebuffer, vec2(Texcoord.x, Texcoord.y - 1.0 / 200.0));
  vec4 left          = texture(texFramebuffer, vec2(Texcoord.x - 1.0 / 300.0, Texcoord.y));
  vec4 right         = texture(texFramebuffer, vec2(Texcoord.x + 1.0 / 300.0, Texcoord.y));
  vec4 topLeft       = texture(texFramebuffer, vec2(Texcoord.x - 1.0 / 300.0, Texcoord.y + 1.0 / 200.0));
  vec4 topRight      = texture(texFramebuffer, vec2(Texcoord.x + 1.0 / 300.0, Texcoord.y + 1.0 / 200.0));
  vec4 bottomLeft    = texture(texFramebuffer, vec2(Texcoord.x - 1.0 / 300.0, Texcoord.y - 1.0 / 200.0));
  vec4 bottomRight   = texture(texFramebuffer, vec2(Texcoord.x + 1.0 / 300.0, Texcoord.y - 1.0 / 200.0));

  vec4 sx = -topLeft - 2 * left - bottomLeft + topRight   + 2 * right  + bottomRight;
  vec4 sy = -topLeft - 2 * top  - topRight   + bottomLeft + 2 * bottom + bottomRight;
  vec4 sobel = sqrt(sx * sx + sy * sy);
  outColor = sobel;
}
