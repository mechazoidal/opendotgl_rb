#version 150 core
in vec2 pos;
in vec3 color;
in float sides;

out vec3 vColor; // output to geometry or fragment shader
out float vSides; // output to geometry shader
void main()
{
    gl_Position = vec4(pos, 0.0, 1.0);
    vColor = color;
    vSides = sides;
}
