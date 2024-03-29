require_relative './lib/application'
require_relative './lib/data'
require_relative './lib/utils'

require 'optimist'
require 'rmath3d/rmath3d'

class Transformations
  include Logging
  using Utils::RadianHelper

  VERTICES = GeometryData::Transformations::VERTICES
  ELEMENTS = GeometryData::ELEMENTS

  def initialize(window)
    @window = window
    @name = 'transformations'
    @vert_source = File.join('shaders', @name, 'vert_shader.glsl')
    @frag_source = File.join('shaders', @name, 'two_textures_frag.glsl')

    @textures = Utils::Textures.new

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

    # Upload vertices once, draw them many
    vertices_data_ptr = Fiddle::Pointer[VERTICES.flatten.pack('F*')]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * VERTICES.flatten.length
    glBufferData(GL_ARRAY_BUFFER, vertices_data_size, vertices_data_ptr, GL_STATIC_DRAW)

    # setup vertex element buffers
    ebo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, ebo_buf)
    ebo = ebo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    element_data_ptr = Fiddle::Pointer[ELEMENTS.pack('i*')]
    element_data_size = Fiddle::SIZEOF_INT * ELEMENTS.length
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, element_data_size, element_data_ptr, GL_STATIC_DRAW)
    vertex_shader = Utils::Shader.new(:vertex)
    @running = false unless vertex_shader.load(File.open(@vert_source, 'r', &:read))

    frag_shader = Utils::Shader.new(:fragment)
    @running = false unless frag_shader.load(File.open(@frag_source, 'r', &:read))

    @shader_program = glCreateProgram()
    glAttachShader(@shader_program, vertex_shader.id)
    glAttachShader(@shader_program, frag_shader.id)
    glBindFragDataLocation(@shader_program, 0, 'outColor')

    glLinkProgram(@shader_program)
    glUseProgram(@shader_program)

    position_attribute = glGetAttribLocation(@shader_program, 'position')
    if position_attribute != -1
      glEnableVertexAttribArray(position_attribute)
      glVertexAttribPointer(position_attribute,
                            # size
                            2,
                            # type
                            GL_FLOAT,
                            # normalized?
                            GL_FALSE,
                            # stride: 5 items in each vertex(x,y,r,g,b)
                            Fiddle::SIZEOF_FLOAT * VERTICES[0].length,
                            # no offset required
                            0)
    end

    color_attribute = glGetAttribLocation(@shader_program, 'color')
    if color_attribute != -1
      glEnableVertexAttribArray(color_attribute)
      glVertexAttribPointer(color_attribute,
                            3,
                            GL_FLOAT,
                            GL_FALSE,
                            Fiddle::SIZEOF_FLOAT * VERTICES[0].length,
                            # Offset pointer: space for 2 floats, cast to void*
                            (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 2))
    end

    texcoord_attribute = glGetAttribLocation(@shader_program, 'texcoord')
    if texcoord_attribute != -1
      glEnableVertexAttribArray(texcoord_attribute)
      glVertexAttribPointer(texcoord_attribute,
                            2,
                            GL_FLOAT,
                            GL_FALSE,
                            Fiddle::SIZEOF_FLOAT * VERTICES[0].length,
                            # Offset pointer: space for 2 floats, cast to void*
                            (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 5))
    end
    @textures.load('sample_earth.png', 'texEarth')
    @textures.load('sample_moon.png', 'texMoon')

    glUniform1i(glGetUniformLocation(@shader_program, 'texEarth'),
                @textures.slot_for('texEarth'))
    glUniform1i(glGetUniformLocation(@shader_program, 'texMoon'),
                @textures.slot_for('texMoon'))
  end

  def draw
    uniform_model = glGetUniformLocation(@shader_program, 'model')

    # Set view matrix(original used glm::lookAt)
    view = RMath3D::RMtx4.new.lookAtRH(
      RMath3D::RVec3.new(1.2, 1.2, 1.2), # eye
      RMath3D::RVec3.new(0.0, 0.0, 0.0), # at
      RMath3D::RVec3.new(0.0, 0.0, 1.0)  # up
    )

    uniform_view = glGetUniformLocation(@shader_program, 'view')
    uniform_proj = glGetUniformLocation(@shader_program, 'proj')
    # set projection matrix(original used glm:perspective)
    proj = RMath3D::RMtx4.new.perspectiveFovRH(45.0.to_rad, # FOV
                                               (@window.height.to_f / @window.width.to_f), # aspect
                                               1.0, # znear
                                               10.0) # zfar

    start_time = Time.now

    # Send view and proj matrix variables to shader (which will not change per-frame)
    glUniformMatrix4fv(uniform_view, 1, GL_FALSE, Fiddle::Pointer[view.to_a.pack('F*')])
    glUniformMatrix4fv(uniform_proj, 1, GL_FALSE, Fiddle::Pointer[proj.to_a.pack('F*')])

    # Create initial model matrix
    model = RMath3D::RMtx4.new.setIdentity

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

      now = Time.now
      time = (now - start_time)

      # Calculate new rotation
      model = model.rotationAxis(RMath3D::RVec3.new(0.0, 0.0, 1.0),
                                 (time * 180.0.to_rad))

      # Update shader with new rotation
      glUniformMatrix4fv(uniform_model, 1, GL_FALSE, Fiddle::Pointer[model.to_a.pack('F*')])

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
                         'transformations',
                         opts[:verbose])
Transformations.new(window).draw
