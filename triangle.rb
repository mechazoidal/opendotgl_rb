require_relative './lib/utils'
require_relative './lib/application'

class Triangle
  include Logging
  def initialize(window)
    @window = window
    @name = 'triangle'
    @vert_source = File.join('shaders', @name, 'triangle_vert_shader.glsl')
    @frag_source = File.join('shaders', @name, 'triangle_frag_shader.glsl')
  end

  def draw
    @running = true

    # setup vao
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenVertexArrays(1, buf)
    vao = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindVertexArray(vao)

    vertices = [
      [0.0,  0.5, 0.0],
      [0.5, -0.5, 0.5],
      [-0.5, -0.5, 1.0]
    ]
    # vertices_gray = vertices.map {|n| n[0..1]} # for just the xy coords

    vbo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, vbo_buf)
    vbo = vbo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    vertices_data_ptr = Fiddle::Pointer[vertices.flatten.pack('F*')]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * vertices.flatten.length
    glBufferData(GL_ARRAY_BUFFER,
                 vertices_data_size,
                 vertices_data_ptr,
                 GL_STATIC_DRAW)

    vertex_shader = Utils::Shader.new(:vertex)
    @running = false unless vertex_shader.load(File.open(@vert_source, 'r', &:read))

    frag_shader = Utils::Shader.new(:fragment)
    @running = false unless frag_shader.load(File.open(@frag_source, 'r', &:read))

    shader_program = glCreateProgram()
    glAttachShader(shader_program, vertex_shader.id)
    glAttachShader(shader_program, frag_shader.id)

    glLinkProgram(shader_program)
    glUseProgram(shader_program)

    # Specify the layout of the vertex data
    position_attribute = glGetAttribLocation(shader_program, 'position')
    glEnableVertexAttribArray(position_attribute)
    glVertexAttribPointer(position_attribute,       # location
                          2,                        # size
                          GL_FLOAT,                 # type
                          GL_FALSE,                 # normalized?
                          Fiddle::SIZEOF_FLOAT * vertices[0].length, # stride
                          Utils::NullPtr)           # array buffer offset

    color_attribute = glGetAttribLocation(shader_program, 'color')
    glEnableVertexAttribArray(color_attribute)
    glVertexAttribPointer(color_attribute,
                          3,
                          GL_FLOAT,
                          GL_FALSE,
                          Fiddle::SIZEOF_FLOAT * vertices[0].length,
                          (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 2)) # "Offset" pointer: space for 2 floats, cast to void*

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
      # render
      glClearColor(0.0, 0.0, 0.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT)

      glDrawArrays(GL_TRIANGLES, 0, vertices.length)

      @window.window.gl_swap
    end
  end
end

window = Application.new(800, 600, 'triangle')
Triangle.new(window).draw
