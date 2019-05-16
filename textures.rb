require_relative './lib/window'
require_relative './lib/utils'

class Textures
  attr_reader :name
  def initialize
    @name = "textures"
    @vert_shader = "rectangle_tex_vert_shader.glsl"
    @frag_shader = "rectangle_tex_frag_shader.glsl"
    @vert_source = File.join("shaders", @name, @vert_shader)
    @frag_source = File.join("shaders", @name, @frag_shader)
  end

  def draw_checkerboard(window)
    @running = true

    # Create VAO
    vao_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenVertexArrays(1, vao_buf)
    vao = vao_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindVertexArray(vao)

    # Create VBO
    vbo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, vbo_buf)
    vbo = vbo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindBuffer(GL_ARRAY_BUFFER, vbo)

    vertices = [    #  Position      Color             Texcoords
                    [ -0.5,  0.5, 1.0, 0.0, 0.0, 0.0, 0.0 ], # Top-left
                    [  0.5,  0.5, 0.0, 1.0, 0.0, 1.0, 0.0 ], # Top-right
                    [  0.5, -0.5, 0.0, 0.0, 1.0, 1.0, 1.0 ], # Bottom-right
                    [ -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0 ]  # Bottom-left
    ]

    # Upload vertices once, draw them many
    vertices_data_ptr = Fiddle::Pointer[vertices.flatten.pack("F*")]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * vertices.flatten.length
    glBufferData(GL_ARRAY_BUFFER, vertices_data_size, vertices_data_ptr, GL_STATIC_DRAW)

    # setup vertex element buffers
    elements = [
      0, 1, 2,
      2, 3, 0
    ]

    ebo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, ebo_buf)
    ebo = ebo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    element_data_ptr = Fiddle::Pointer[elements.pack("i*")]
    element_data_size = Fiddle::SIZEOF_INT * elements.length
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, element_data_size, element_data_ptr, GL_STATIC_DRAW)

    vertexShader = Utils::Shader.new(GL_VERTEX_SHADER)
    @running = false unless vertexShader.load(File.open(@vert_source, "r") {|f| f.read})

    fragShader = Utils::Shader.new(GL_FRAGMENT_SHADER)
    @running = false unless fragShader.load(File.open(@frag_source, "r") {|f| f.read})

    shaderProgram = glCreateProgram()
    glAttachShader(shaderProgram, vertexShader.id)
    glAttachShader(shaderProgram, fragShader.id)
    #We have multiple buffers if we include textures!
    glBindFragDataLocation(shaderProgram, 0, "outColor")

    glLinkProgram(shaderProgram)
    glUseProgram(shaderProgram)

    #vertex data and attributes
    posAttrib = glGetAttribLocation(shaderProgram, "position")
    glEnableVertexAttribArray(posAttrib)
    glVertexAttribPointer(posAttrib,                # location
                          2,                        # size
                          GL_FLOAT,                 # type
                          GL_FALSE,                 # normalized?
                          Fiddle::SIZEOF_FLOAT * vertices[0].length, # stride: 5 items in each vertex(x,y,r,g,b)
                          0        # no offset required
                         )

    colAttrib = glGetAttribLocation(shaderProgram, "color")
    glEnableVertexAttribArray(colAttrib)
    glVertexAttribPointer(colAttrib,
                          3,
                          GL_FLOAT,
                          GL_FALSE,
                          Fiddle::SIZEOF_FLOAT * vertices[0].length,
                          (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 2) # "Offset" pointer: space for 2 floats, cast to void*
                         )

    texAttrib = glGetAttribLocation(shaderProgram, "texcoord")
    glEnableVertexAttribArray(texAttrib)
    glVertexAttribPointer(texAttrib,
                          2,
                          GL_FLOAT,
                          GL_FALSE,
                          Fiddle::SIZEOF_FLOAT * vertices[0].length,
                          (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 5) # "Offset" pointer: space for 2 floats, cast to void*
                         )

    # textures
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenTextures(1, tex_buf)
    tex = tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindTexture(GL_TEXTURE_2D, tex)

    #x,y,z = s,t,r in textures
    #set clamping for s and t coordinates

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    #Specify interpolation for scaling up/down*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

    # BW checkerboard
    pixels = [
      0.0, 0.0, 0.0,  1.0, 1.0, 1.0,
      1.0, 1.0, 1.0,  0.0, 0.0, 0.0
    ]
    # for checkerboard*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)

    # change border color to red
    # FIXME not working?
    color = [1.0, 0.0, 0.0, 1.0]
    color_ptr = Fiddle::Pointer[color.pack("F*")]
    glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, color_ptr);

    # params:
    # texture target
    # LOD (0=base image)
    # internal pixel format
    # width
    # height
    # always 0, per spec
    # format of pixels in image
    # type of pixels in image
    # array to use
    # FIXME it's a bit fuzzy, am I missing something here?
    pixels_ptr = Fiddle::Pointer[pixels.pack("F*")]
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 2, 2, 0, GL_RGB, GL_FLOAT, pixels_ptr);
    glGenerateMipmap(GL_TEXTURE_2D);

    while @running
      event = SDL2::Event.poll
      case event
      when SDL2::Event::Quit
        @running = false
      when SDL2::Event::KeyUp
        case event.sym
        when SDL2::Key::ESCAPE, SDL2::Key::Q
          @running = false
        end
      end

      glClearColor(0.0, 0.0, 0.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT)
      glDrawElements(GL_TRIANGLES, elements.length, GL_UNSIGNED_INT, 0)

      window.window.gl_swap
    end
  end
end

window = Window.new(800, 600, "textures", true)
Textures.new.draw_checkerboard(window)
