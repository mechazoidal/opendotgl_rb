#version 150 core
in vec3 fColor;
out vec4 outColor;

void main()
{
    /*outColor = vec4(1.0, 0.0, 0.0, 1.0);*/
    outColor = vec4(fColor, 1.0);
}
