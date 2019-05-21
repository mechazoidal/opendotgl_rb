#version 150 core

in vec3 Color;
in vec2 Texcoord;
out vec4 outColor;

// uniform sampler2D tex;
uniform sampler2D texEarth;
uniform sampler2D texMoon;

void main()
{
    // outColor = texture(tex, Texcoord) * vec4(Color, 1.0);
    vec4 colEarth = texture(texEarth, Texcoord);
    vec4 colMoon = texture(texMoon, Texcoord);
    /*outColor = mix(colKitten, colPuppy, 0.5) * vec4(Color, 1.0);*/
    outColor = mix(colEarth, colMoon, 0.5);
}
