require_relative './lib/window'
require_relative './lib/utils'


class Rectangle
  def draw(window)
    @running = true
    vertices = [
      [ -0.5,  0.5, 1.0, 0.0, 0.0 ], # Top-left
      [  0.5,  0.5, 0.0, 1.0, 0.0 ], # Top-right
      [  0.5, -0.5, 0.0, 0.0, 1.0 ], # Bottom-right
      [ -0.5, -0.5, 1.0, 1.0, 1.0 ], # Bottom-left
    ]
    #vertices_gray = vertices.map {|n| n[0..1]}

    # Create VAO
    vao_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenVertexArrays(1, vao_buf)
    vao = vao_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindVertexArray(vao)

    vbo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, vbo_buf)
    vbo = vbo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindBuffer(GL_ARRAY_BUFFER, vbo)

    elements = [
      0, 1, 2,
      2, 3, 0
    ]
    # setup vertex element buffers

    ebo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, ebo_buf)
    ebo = ebo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    element_data_ptr = Fiddle::Pointer[elements.pack("i*")]
    element_data_size = Fiddle::SIZEOF_INT * elements.length
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)

    glBufferData(GL_ELEMENT_ARRAY_BUFFER, element_data_size, element_data_ptr, GL_STATIC_DRAW)

    # Upload vertices once, draw them many
    vertices_data_ptr = Fiddle::Pointer[vertices.flatten.pack("F*")]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * vertices.flatten.length
    glBufferData(GL_ARRAY_BUFFER, vertices_data_size, vertices_data_ptr, GL_STATIC_DRAW)

    vertexShader = Utils::Shader.new(:vertex)
    @running = false unless vertexShader.load(File.open("shaders/rectangle/rectangle_vert_shader.glsl", "r") {|f| f.read})

    fragShader = Utils::Shader.new(:fragment)
    @running = false unless fragShader.load(File.open("shaders/rectangle/rectangle_frag_shader.glsl", "r") {|f| f.read})

    shaderProgram = glCreateProgram()
    glAttachShader(shaderProgram, vertexShader.id)
    glAttachShader(shaderProgram, fragShader.id)

    glLinkProgram(shaderProgram)
    glUseProgram(shaderProgram)

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
    # TODO proper cleanup
    #shader.delete
    glDeleteProgram(shaderProgram)
    #glDeleteBuffers(1, vbo.pack('L'))
    #glDeleteVertexArrays(1, Fiddle::Pointer[vao])
  end
end

window = Window.new(800, 600, "rectangle")
Rectangle.new.draw(window)
