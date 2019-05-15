#version 150 core

layout(points) in;

/*original version*/
/*layout(points, max_vertices = 1) out;*/

/*void main()*/
/*{*/
    /*gl_Position = gl_in[0].gl_Position;*/
    /*EmitVertex();*/
    /*EndPrimitive();*/
/*}*/

/*Simple line version*/
/*layout(line_strip, max_vertices = 2) out;*/

/*void main()*/
/*{*/
    /*gl_Position = gl_in[0].gl_Position + vec4(-0.1, 0.0, 0.0, 0.0);*/
    /*EmitVertex();*/

    /*gl_Position = gl_in[0].gl_Position + vec4(0.1, 0.0, 0.0, 0.0);*/
    /*EmitVertex();*/

    /*EndPrimitive();*/
/*}*/

/*include color*/
/*layout(line_strip, max_vertices = 2) out;*/
/*in vec3 vColor[]; // output from vertex shader for each vertex*/
/*out vec3 fColor; // output to fragment shader*/
/*void main()*/
/*{*/
    /*fColor = vColor[0]; // point has only one vertex*/
    /*gl_Position = gl_in[0].gl_Position + vec4(-0.1, 0.1, 0.0, 0.0);*/
    /*EmitVertex();*/

    /*gl_Position = gl_in[0].gl_Position + vec4(0.1, 0.1, 0.0, 0.0);*/
    /*EmitVertex();*/

    /*EndPrimitive();*/
/*}*/

/*generate geometry*/
/*layout(line_strip, max_vertices = 11) out;*/
layout(line_strip, max_vertices = 64) out;
in vec3 vColor[]; // output from vertex shader for each vertex
out vec3 fColor; // output to fragment shader

in float vSides[];

const float PI = 3.1415926;
void main()
{
    fColor = vColor[0]; // point has only one vertex
    /*for (int i = 0; i <= 10; i++) {*/
    // Safe, floats can represent small integers exactly
    for (int i = 0; i <= vSides[0]; i++) {
      // angle between each side in radians
      /*float ang = PI * 2.0 / 10.0 * i;*/
      float ang = PI * 2.0 / vSides[0] * i;

      // offset from center of point(0.3 to accomodate for aspect ratio)
      vec4 offset = vec4(cos(ang) * 0.3, -sin(ang) * 0.4, 0.0, 0.0);
      gl_Position = gl_in[0].gl_Position + offset;

      EmitVertex();
    }

    EndPrimitive();
}
