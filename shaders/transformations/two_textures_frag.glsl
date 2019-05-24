#version 150 core

in vec3 Color;
in vec2 Texcoord;
out vec4 outColor;

uniform sampler2D texEarth;
uniform sampler2D texMoon;

void main()
{
    vec4 colEarth = texture(texEarth, Texcoord);
    vec4 colMoon = texture(texMoon, Texcoord);
    outColor = mix(colEarth, colMoon, 0.5);
}
