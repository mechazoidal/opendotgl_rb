#version 150 core

in vec3 Color;
in vec2 Texcoord;
out vec4 outColor;

uniform sampler2D texKitten;
uniform sampler2D texPuppy;
uniform float time;

void main()
{
    // requires passing in a glUniform1f through a GLint
    float factor = (sin(time * 3.0) + 1.0) / 2.0;
    outColor = mix(texture(texPuppy, Texcoord), texture(texPuppy, Texcoord), factor);
}
