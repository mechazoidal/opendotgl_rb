require_relative './lib/window'
require_relative './lib/utils'

require "rmath3d/rmath3d"

class Stencils
  include Logging
  using Utils::RadianHelper

  Vertices = [
    [-0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 0.0],
    [ 0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 1.0, 0.0],
    [ 0.5,  0.5, -0.5, 1.0, 1.0, 1.0, 1.0, 1.0],
    [ 0.5,  0.5, -0.5, 1.0, 1.0, 1.0, 1.0, 1.0],
    [-0.5,  0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0],
    [-0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 0.0],

    [-0.5, -0.5,  0.5, 1.0, 1.0, 1.0, 0.0, 0.0],
    [ 0.5, -0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 0.0],
    [ 0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 1.0],
    [ 0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 1.0],
    [-0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 0.0, 1.0],
    [-0.5, -0.5,  0.5, 1.0, 1.0, 1.0, 0.0, 0.0],

    [-0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 0.0],
    [-0.5,  0.5, -0.5, 1.0, 1.0, 1.0, 1.0, 1.0],
    [-0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0],
    [-0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0],
    [-0.5, -0.5,  0.5, 1.0, 1.0, 1.0, 0.0, 0.0],
    [-0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 0.0],

    [ 0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 0.0],
    [ 0.5,  0.5, -0.5, 1.0, 1.0, 1.0, 1.0, 1.0],
    [ 0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0],
    [ 0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0],
    [ 0.5, -0.5,  0.5, 1.0, 1.0, 1.0, 0.0, 0.0],
    [ 0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 0.0],

    [-0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0],
    [ 0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 1.0, 1.0],
    [ 0.5, -0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 0.0],
    [ 0.5, -0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 0.0],
    [-0.5, -0.5,  0.5, 1.0, 1.0, 1.0, 0.0, 0.0],
    [-0.5, -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0],

    [-0.5,  0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0],
    [ 0.5,  0.5, -0.5, 1.0, 1.0, 1.0, 1.0, 1.0],
    [ 0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 0.0],
    [ 0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 1.0, 0.0],
    [-0.5,  0.5,  0.5, 1.0, 1.0, 1.0, 0.0, 0.0],
    [-0.5,  0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0],

# floor
    [-1.0, -1.0, -0.5, 0.0, 0.0, 0.0, 0.0, 0.0],
    [ 1.0, -1.0, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0],
    [ 1.0,  1.0, -0.5, 0.0, 0.0, 0.0, 1.0, 1.0],
    [ 1.0,  1.0, -0.5, 0.0, 0.0, 0.0, 1.0, 1.0],
    [-1.0,  1.0, -0.5, 0.0, 0.0, 0.0, 0.0, 1.0],
    [-1.0, -1.0, -0.5, 0.0, 0.0, 0.0, 0.0, 0.0]
  ]

  def initialize(window)
    @window = window
    @name = "stencils"
    @vert_source = File.join("shaders", @name, "vert_shader.glsl")
    @frag_source = File.join("shaders", @name, "frag_shader.glsl")

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
    vertices_data_ptr = Fiddle::Pointer[Vertices.flatten.pack("F*")]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * Vertices.flatten.length
    glBufferData(GL_ARRAY_BUFFER, vertices_data_size, vertices_data_ptr, GL_STATIC_DRAW)

    # No element buffers required for this lesson, as we use glDrawArrays

    # setup shaders
    vertexShader = Utils::Shader.new(GL_VERTEX_SHADER)
    @running = false unless vertexShader.load(File.open(@vert_source, "r") {|f| f.read})

    fragShader = Utils::Shader.new(GL_FRAGMENT_SHADER)
    @running = false unless fragShader.load(File.open(@frag_source, "r") {|f| f.read})

    @shaderProgram = Utils::ShaderProgram.new
    @shaderProgram.attach(vertexShader)
    @shaderProgram.attach(fragShader)
    @shaderProgram.bind_frag("outColor")

    @shaderProgram.link_and_use

    @shaderProgram.enable_vertex_attrib("position", 3, :float, Vertices[0].length)
    @shaderProgram.enable_vertex_attrib("color",    3, :float, Vertices[0].length, 3)
    @shaderProgram.enable_vertex_attrib("texcoord", 2, :float, Vertices[0].length, 6)

    @textures.load('sample_earth.png', 'texEarth')
    @textures.load('sample_moon.png', 'texMoon')

    # TODO
    glUniform1i(@shaderProgram.uniform_location("texEarth"), @textures.slot_for("texEarth"))
    glUniform1i(@shaderProgram.uniform_location("texMoon"), @textures.slot_for("texMoon"))

  end

  def draw
    start_time = SDL2::get_ticks / 1000.0

    uniModel = @shaderProgram.uniform_location("model")

    # Set view matrix(original used glm::lookAt)
    view = RMath3D::RMtx4.new.lookAtRH(
      RMath3D::RVec3.new(1.5, 1.5, 1.5), # eye
      RMath3D::RVec3.new(0.0, 0.0, 0.0), # at
      RMath3D::RVec3.new(0.0, 0.0, 1.0)  # up
    )


    proj = RMath3D::RMtx4.new.perspectiveFovRH(45.0.to_rad, # FOV
                                              (@window.height.to_f / @window.width.to_f), # aspect
                                              1.0, # znear
                                              10.0) # zfar

    uniView = @shaderProgram.uniform_location("view")
    uniProj = @shaderProgram.uniform_location("proj")


    # Send view and proj matrix variables to shader (which will not change per-frame)
    glUniformMatrix4fv(uniView, 1, GL_FALSE,  Fiddle::Pointer[view.to_a.pack('F*')])
    glUniformMatrix4fv(uniProj, 1, GL_FALSE, Fiddle::Pointer[proj.to_a.pack('F*')])

    # used for darkening the reflection color
    uniColor = @shaderProgram.uniform_location("overrideColor")

    # Create initial model matrix
    # ( original used glm::mat4(1.0f) )
    model = RMath3D::RMtx4.new.setIdentity

    scaling = RMath3D::RMtx4.new.scaling(1.0, 1.0, -1.0)
    translation = RMath3D::RMtx4.new.translation(0.0, 0.0, -1.0)

    # handle events
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

      current_time = SDL2::get_ticks / 1000.0
      time = (current_time - start_time)

      # Calculate new rotation
      model = model.rotationAxis(RMath3D::RVec3.new(0.0, 0.0, 1.0),
                                                   (time * 180.0.to_rad))

      # Update shader with new rotation
      glUniformMatrix4fv(uniModel, 1, GL_FALSE, Fiddle::Pointer[model.to_a.pack('F*')])


      # Draw cube
      glDrawArrays(GL_TRIANGLES, 0, 36)

      # Setup stencil mask
      glEnable(GL_STENCIL_TEST)
      # Draw floor
      glStencilFunc(GL_ALWAYS, 1, 0xFF) # set any stencil to 1
      glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
      glStencilMask(0xFF) # write to stencil buffer
      glDepthMask(GL_FALSE) # don't write to depth buffer
      glClear(GL_STENCIL_BUFFER_BIT) # clear stencil buffer

      glDrawArrays(GL_TRIANGLES, 36, 6)

      # draw reflection
      glStencilFunc(GL_EQUAL, 1, 0xFF) # set any stencil to 1
      glStencilMask(0x00) # don't write to stencil buffer
      glDepthMask(GL_TRUE) # write to depth buffer

      # translate and scale the model matrix
      # ( original used a nested call: glm::scale(glm::translate(0,0,-1), (1,1,-1)) )
      model = model * translation * scaling

      # Update shader with new scaling
      glUniformMatrix4fv(uniModel, 1, GL_FALSE, Fiddle::Pointer[model.to_a.pack('F*')])
      glUniform3f(uniColor, 0.3, 0.3, 0.3)
      glDrawArrays(GL_TRIANGLES, 0, 36)
      glUniform3f(uniColor, 1.0, 1.0, 1.0)

      glDisable(GL_STENCIL_TEST)

      @window.window.gl_swap
    end
  end
end

window = Window.new(800, 600, "stencils")
Stencils.new(window).draw
