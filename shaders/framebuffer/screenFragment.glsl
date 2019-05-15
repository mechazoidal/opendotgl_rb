#version 150 core
in vec2 Texcoord;
out vec4 outColor;
uniform sampler2D texFramebuffer;
void main()
{
  /*original*/
  /*outColor = texture(texFramebuffer, Texcoord);*/

  /*Color inversion*/
  /*outColor = vec4(1.0, 1.0, 1.0, 1.0) - texture(texFramebuffer, Texcoord);*/

  /*Grayscale*/
  outColor = texture(texFramebuffer, Texcoord);
  /*naive version*/
  /*float avg = (outColor.r + outColor.g + outColor.b) / 3.0;*/
  /*corrected version*/
  float avg = 0.2126 * outColor.r + 0.7152 * outColor.g + 0.0722 * outColor.b;
  outColor = vec4(avg, avg, avg, 1.0);
}
