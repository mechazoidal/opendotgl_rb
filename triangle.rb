require_relative './lib/shader'
#require_relative './lib/utils'
require_relative './lib/window'

class Triangle
  def draw(window)

    @running = true

    # setup vao
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenVertexArrays(1, buf)
    vao = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindVertexArray(vao)

    vertices = [
          [ 0.0,  0.5],
          [ 0.5, -0.5],
          [-0.5, -0.5]]

    # Odd note: we reused buf, but that's OK because it's just a destination for the integer that comes back from Opengl
    vbo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, buf)
    vbo = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    vertices_data_ptr = Fiddle::Pointer[vertices.flatten.pack("F*")]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * vertices.flatten.length
    glBufferData(GL_ARRAY_BUFFER, vertices_data_size, vertices_data_ptr, GL_STATIC_DRAW)
    
    # vertexShader

    # TODO should really just do these manually for now, to reduce errors
    shader = Shader.new
    shader.load( vertex_code: File.open("shaders/triangle/solid_vert.glsl", "r") {|f| f.read},
                 fragment_code: File.open("shaders/triangle/solid_frag.glsl", "r") {|f| f.read})
    shader.use

    # Specify the layout of the vertex data
    posAttrib = glGetAttribLocation(shader.program_id, "position")
    glEnableVertexAttribArray(posAttrib)
    glVertexAttribPointer(posAttrib,                # location
                          2,                        # size
                          GL_FLOAT,                 # type
                          GL_FALSE,                 # normalized?
                          #Fiddle::SIZEOF_FLOAT * 3, # stride
                          0,
                          NullPtr                   # array buffer offset
                         )

    #GLint colAttrib = glGetAttribLocation(shaderProgram, "color");
    #glEnableVertexAttribArray(colAttrib);
    #glVertexAttribPointer(colAttrib, 1, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));

    #colAttrib = glGetAttribLocation(shader.program_id, "color")
    #glEnableVertexAttribArray(colAttrib)
    # BUG HERE
    # GL_INVALID_OPERATION in glVertexAttribPointer(non-VBO array)
    #glVertexAttribPointer(colAttrib, 1, GL_FLOAT, GL_FALSE, Fiddle::SIZEOF_FLOAT * 3, Fiddle::SIZEOF_FLOAT * 2)
    #glVertexAttribPointer(colAttrib, 1, GL_FLOAT, GL_FALSE, Fiddle::SIZEOF_FLOAT * 5, Fiddle::SIZEOF_FLOAT * 2)
    # No GL error, but nothing appears
    #glVertexAttribPointer(colAttrib, 1, GL_FLOAT, GL_FALSE, Fiddle::SIZEOF_FLOAT * 3, 2)

    #glVertexAttribPointer(colAttrib, Attribute::COLOR, GL_FLOAT, GL_FALSE, Fiddle::SIZEOF_FLOAT * 3, Fiddle::SIZEOF_FLOAT * 2)

    #in opengl-bindings, the last argument is a Fiddle::TYPE_VOIDP
    #vap = Fiddle::Pointer.malloc(Fiddle::SIZEOF_FLOAT * 2)
    #glVertexAttribPointer(colAttrib, 1, GL_FLOAT, GL_FALSE, Fiddle::SIZEOF_FLOAT * 3, vap)

    #glVertexAttribPointer(colAttrib, 1, GL_FLOAT, GL_FALSE, Fiddle::SIZEOF_FLOAT * 3, 2)

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
      glClearColor(0.0, 0.0, 0.0, 1.0);
      glClear(GL_COLOR_BUFFER_BIT)

      glDrawArrays(GL_TRIANGLES, 0, vertices.length)

      window.window.gl_swap
    end
  end
end

window = Window.new(800, 600)
Triangle.new.draw(window)
