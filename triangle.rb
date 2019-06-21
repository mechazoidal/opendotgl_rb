require_relative './lib/utils'
require_relative './lib/data'
require_relative './lib/application'
require 'optimist'

class Triangle
  include Logging
  VERTICES = GeometryData::Triangle::VERTICES
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

    vbo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, vbo_buf)
    vbo = vbo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    vertices_data_ptr = Fiddle::Pointer[VERTICES.flatten.pack('F*')]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * VERTICES.flatten.length
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
    glVertexAttribPointer(position_attribute,
                          # size
                          2,
                          # type
                          GL_FLOAT,
                          # normalized?
                          GL_FALSE,
                          # stride
                          Fiddle::SIZEOF_FLOAT * VERTICES[0].length,
                          # array buffer offset (none)
                          Utils::NullPtr)

    color_attribute = glGetAttribLocation(shader_program, 'color')
    glEnableVertexAttribArray(color_attribute)
    glVertexAttribPointer(color_attribute,
                          3,
                          GL_FLOAT,
                          GL_FALSE,
                          Fiddle::SIZEOF_FLOAT * VERTICES[0].length,
                          # "Offset" pointer: space for 2 floats, cast to void*
                          (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 2))

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

      glDrawArrays(GL_TRIANGLES, 0, VERTICES.length)

      @window.window.gl_swap
    end
  end
end

opts = Optimist.options do
  opt :size, 'width X height string', default: '800x600'
  opt :verbose, 'say a lot', default: false
end
window_size = Utils.parse_window_size(opts[:size])
Optimist.die('Valid size string is required') unless window_size
Optimist.die('Valid width is required') unless window_size[:width] > 0
Optimist.die('Valid height is required') unless window_size[:height] > 0

window = Application.new(window_size[:width],
                         window_size[:height],
                         'triangle',
                         opts[:verbose])
Triangle.new(window).draw
