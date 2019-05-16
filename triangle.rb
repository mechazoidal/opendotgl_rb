require_relative './lib/utils'
require_relative './lib/window'

class Triangle
  NAME = "triangle"
  #VERT_SHADER = "solid_vert.glsl"
  #FRAG_SHADER = "solid_frag.glsl"
  VERT_SHADER = "triangle_vert_shader.glsl"
  FRAG_SHADER = "triangle_frag_shader.glsl"
  VERT_SOURCE = File.join("shaders", NAME, VERT_SHADER)
  FRAG_SOURCE = File.join("shaders", NAME, FRAG_SHADER)

  def draw(window)

    @running = true

    # setup vao
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenVertexArrays(1, buf)
    vao = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindVertexArray(vao)

    vertices = [
      [ 0.0,  0.5, 0.0 ],
      [ 0.5, -0.5, 0.5 ],
      [-0.5, -0.5, 1.0 ]]
    #vertices_gray = vertices.map {|n| n[0..1]} # for just the xy coords

    vbo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, buf)
    vbo = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    vertices_data_ptr = Fiddle::Pointer[vertices.flatten.pack("F*")]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * vertices.flatten.length
    glBufferData(GL_ARRAY_BUFFER, vertices_data_size, vertices_data_ptr, GL_STATIC_DRAW)

    vertexShader = Utils::Shader.new(GL_VERTEX_SHADER)
    @running = false unless vertexShader.load(File.open(VERT_SOURCE, "r") {|f| f.read})

    fragShader = Utils::Shader.new(GL_FRAGMENT_SHADER)
    @running = false unless fragShader.load(File.open(FRAG_SOURCE, "r") {|f| f.read})

    shaderProgram = glCreateProgram()
    glAttachShader(shaderProgram, vertexShader.id)
    glAttachShader(shaderProgram, fragShader.id)

    glLinkProgram(shaderProgram)
    glUseProgram(shaderProgram)


    # Specify the layout of the vertex data
    posAttrib = glGetAttribLocation(shaderProgram, "position")
    glEnableVertexAttribArray(posAttrib)
    glVertexAttribPointer(posAttrib,                # location
                          2,                        # size
                          GL_FLOAT,                 # type
                          GL_FALSE,                 # normalized?
                          Fiddle::SIZEOF_FLOAT * vertices[0].length, #stride
                          #0,                       # stride
                          Utils::NullPtr            # array buffer offset
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
      #render
      glClearColor(0.0, 0.0, 0.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT)

      glDrawArrays(GL_TRIANGLES, 0, vertices.length)

      window.window.gl_swap
    end
  end
end

window = Window.new(800, 600, "triangle", true)
Triangle.new.draw(window)
