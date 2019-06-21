require_relative './lib/application'
require_relative './lib/data'
require_relative './lib/utils'

require 'optimist'
require 'rmath3d/rmath3d'

class Stencils
  include Logging
  using Utils::RadianHelper

  VERTICES = GeometryData::Stencils::VERTICES
  ELEMENTS = GeometryData::ELEMENTS

  def initialize(window)
    @window = window
    @name = 'stencils'
    @vert_source = File.join('shaders', @name, 'vert_shader.glsl')
    @frag_source = File.join('shaders', @name, 'frag_shader.glsl')

    @textures = Utils::Textures.new

    @running = true
    glEnable(GL_DEPTH_TEST)

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

    # No element buffers required for this lesson since we use glDrawArrays

    # setup shaders
    vertex_shader = Utils::Shader.new(:vertex)
    @running = false unless vertex_shader.load(File.open(@vert_source, 'r', &:read))

    frag_shader = Utils::Shader.new(:fragment)
    @running = false unless frag_shader.load(File.open(@frag_source, 'r', &:read))

    @shader_program = Utils::ShaderProgram.new
    @shader_program.attach(vertex_shader)
    @shader_program.attach(frag_shader)
    @shader_program.bind_frag('outColor')

    @shader_program.link_and_use

    @shader_program.enable_vertex_attrib('position', 3, :float, VERTICES[0].length)
    @shader_program.enable_vertex_attrib('color',    3, :float, VERTICES[0].length, 3)
    @shader_program.enable_vertex_attrib('texcoord', 2, :float, VERTICES[0].length, 6)

    @textures.load('sample_earth.png', 'texEarth')
    @textures.load('sample_moon.png', 'texMoon')

    # TODO
    glUniform1i(@shader_program.uniform_location('texEarth'),
                @textures.slot_for('texEarth'))
    glUniform1i(@shader_program.uniform_location('texMoon'),
                @textures.slot_for('texMoon'))
  end

  def draw
    start_time = Time.now

    uniform_model = @shader_program.uniform_location('model')

    # Set view matrix (original used glm::lookAt)
    view = RMath3D::RMtx4.new.lookAtRH(
      # "eye" vector
      RMath3D::RVec3.new(1.5, 1.5, 1.5),
      # "look-at" vector
      RMath3D::RVec3.new(0.0, 0.0, 0.0),
      # "up" vector
      RMath3D::RVec3.new(0.0, 0.0, 1.0)
    )

    proj = RMath3D::RMtx4.new.perspectiveFovRH(45.0.to_rad, # FOV
                                               # aspect ratio
                                               (@window.height.to_f / @window.width.to_f),
                                               # z-clipping near-plane
                                               1.0,
                                               # z-clipping far-plane
                                               10.0)

    uniform_view = @shader_program.uniform_location('view')
    uniform_proj = @shader_program.uniform_location('proj')

    # Send view and proj matrix variables to shader.
    # We only do this once since they will not change per-frame.
    glUniformMatrix4fv(uniform_view, 1, GL_FALSE, Fiddle::Pointer[view.to_a.pack('F*')])
    glUniformMatrix4fv(uniform_proj, 1, GL_FALSE, Fiddle::Pointer[proj.to_a.pack('F*')])

    # used for darkening the reflection color
    uniform_color = @shader_program.uniform_location('overrideColor')

    # Create initial model matrix
    # ( original used glm::mat4(1.0f) )
    model = RMath3D::RMtx4.new.setIdentity

    scaling = RMath3D::RMtx4.new.scaling(1.0, 1.0, -1.0)
    translation = RMath3D::RMtx4.new.translation(0.0, 0.0, -1.0)

    # event loop
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

      glClearColor(1.0, 1.0, 1.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

      current_time = Time.now
      time = (current_time - start_time)

      # Calculate new rotation
      model = model.rotationAxis(RMath3D::RVec3.new(0.0, 0.0, 1.0),
                                 (time * 180.0.to_rad))

      # Update shader with new rotation
      glUniformMatrix4fv(uniform_model,
                         1,
                         GL_FALSE,
                         Fiddle::Pointer[model.to_a.pack('F*')])

      # Draw cube
      glDrawArrays(GL_TRIANGLES, 0, 36)

      # Setup stencil mask
      glEnable(GL_STENCIL_TEST)

      # Draw floor:
      glStencilFunc(GL_ALWAYS, 1, 0xFF)
      # set any stencil to 1
      glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
      # write to stencil buffer
      glStencilMask(0xFF)
      # don't write to depth buffer
      glDepthMask(GL_FALSE)
      # clear the stencil buffer
      glClear(GL_STENCIL_BUFFER_BIT)

      glDrawArrays(GL_TRIANGLES, 36, 6)

      # draw reflection:
      # set any stencil to 1
      glStencilFunc(GL_EQUAL, 1, 0xFF)
      # don't write to stencil buffer
      glStencilMask(0x00)
      # write to depth buffer
      glDepthMask(GL_TRUE)

      # translate and scale the model matrix
      # ( original used a nested call: glm::scale(glm::translate(0,0,-1), (1,1,-1)) )
      model = model * translation * scaling

      # Update shader with new scaling
      glUniformMatrix4fv(uniform_model,
                         1,
                         GL_FALSE,
                         Fiddle::Pointer[model.to_a.pack('F*')])
      glUniform3f(uniform_color, 0.3, 0.3, 0.3)
      glDrawArrays(GL_TRIANGLES, 0, 36)
      glUniform3f(uniform_color, 1.0, 1.0, 1.0)

      glDisable(GL_STENCIL_TEST)

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
                         'stencils',
                         opts[:verbose])
Stencils.new(window).draw
