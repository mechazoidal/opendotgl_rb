#version 150 core

in vec3 Color;
in vec2 Texcoord;
out vec4 outColor;

// uniform sampler2D tex;
uniform sampler2D texKitten;
uniform sampler2D texPuppy;

void main()
{
    // outColor = texture(tex, Texcoord) * vec4(Color, 1.0);
    vec4 colKitten = texture(texKitten, Texcoord);
    vec4 colPuppy = texture(texPuppy, Texcoord);
    outColor = mix(colKitten, colPuppy, 0.5);

}
