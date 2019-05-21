#version 150 core

in vec3 Color;
in vec2 Texcoord;
out vec4 outColor;

uniform sampler2D texEarth;
uniform sampler2D texMoon;
uniform float uniTime;

void main()
{
    // requires passing in a glUniform1f through a GLint
    float factor = (sin(uniTime * 3.0) + 1.0) / 2.0;
    outColor = mix(texture(texEarth, Texcoord), texture(texMoon, Texcoord), factor);
}
