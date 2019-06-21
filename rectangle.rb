require_relative './lib/application'
require_relative 'data'
require_relative './lib/utils'
require 'optimist'

class Rectangle
  VERTICES = GeometryData::Rectangle::VERTICES
  ELEMENTS = GeometryData::ELEMENTS
  # vertices_gray = vertices.map {|n| n[0..1]}
  def initialize(window)
    @window = window
    @name = 'rectangle'
  end

  def draw
    @running = true

    # Create VAO
    vao_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenVertexArrays(1, vao_buf)
    vao = vao_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindVertexArray(vao)

    vbo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, vbo_buf)
    vbo = vbo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindBuffer(GL_ARRAY_BUFFER, vbo)

    # setup vertex element buffers
    ebo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, ebo_buf)
    ebo = ebo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    element_data_ptr = Fiddle::Pointer[ELEMENTS.pack('i*')]
    element_data_size = Fiddle::SIZEOF_INT * ELEMENTS.length
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)

    glBufferData(GL_ELEMENT_ARRAY_BUFFER, element_data_size, element_data_ptr, GL_STATIC_DRAW)

    # Upload vertices once, draw them many
    vertices_data_ptr = Fiddle::Pointer[VERTICES.flatten.pack('F*')]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * VERTICES.flatten.length
    glBufferData(GL_ARRAY_BUFFER, vertices_data_size, vertices_data_ptr, GL_STATIC_DRAW)

    vertex_shader = Utils::Shader.new(:vertex)
    @running = false unless vertex_shader.load(File.open('shaders/rectangle/rectangle_vert_shader.glsl', 'r', &:read))

    frag_shader = Utils::Shader.new(:fragment)
    @running = false unless frag_shader.load(File.open('shaders/rectangle/rectangle_frag_shader.glsl', 'r', &:read))

    shader_program = glCreateProgram()
    glAttachShader(shader_program, vertex_shader.id)
    glAttachShader(shader_program, frag_shader.id)

    glLinkProgram(shader_program)
    glUseProgram(shader_program)

    position_attribute = glGetAttribLocation(shader_program, 'position')
    glEnableVertexAttribArray(position_attribute)
    glVertexAttribPointer(position_attribute,
                          # size: 2 (x, y)
                          2,
                          # type
                          GL_FLOAT,
                          # normalized?
                          GL_FALSE,
                          # stride: 5 items in each vertex(x, y, r, g, b)
                          Fiddle::SIZEOF_FLOAT * VERTICES[0].length,
                          # no offset required
                          0)

    color_attribute = glGetAttribLocation(shader_program, 'color')
    glEnableVertexAttribArray(color_attribute)

    glVertexAttribPointer(color_attribute,
                          3,
                          GL_FLOAT,
                          GL_FALSE,
                          Fiddle::SIZEOF_FLOAT * VERTICES[0].length,
                          # Offset: space for 2 floats, cast to void*
                          (Utils::NullPtr + Fiddle::SIZEOF_FLOAT * 2))

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
      glDrawElements(GL_TRIANGLES, ELEMENTS.length, GL_UNSIGNED_INT, 0)

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
                         'rectangle',
                         opts[:verbose])
Rectangle.new(window).draw
