require_relative './lib/application'
require_relative './lib/utils'
require_relative './data'

require 'rmath3d/rmath3d'

class Framebuffer
  include Logging
  using Utils::RadianHelper

  def initialize(window)
    @window = window
    @name = 'framebuffer'

    scene_vertex_source = File.join('shaders', @name, 'sceneVertex.glsl')
    scene_frag_source = File.join('shaders', @name, 'sceneFragment.glsl')

    screen_vertex_source = File.join('shaders', @name, 'screenVertex.glsl')
    screen_frag_source = File.join('shaders', @name, 'screenFragment.glsl')

    @textures = Utils::Textures.new

    @running = true

    glEnable(GL_DEPTH_TEST)

    # Create VAOs
    @vao_cube = Utils::VertexArray.new
    @vao_quad = Utils::VertexArray.new

    # Setup VBO
    @vbo_cube = Utils::VertexBuffer.new
    @vbo_quad = Utils::VertexBuffer.new

    @vbo_cube.bind
    @vbo_cube.load_buffer(GeometryData::VERTICES, :float)

    @vbo_quad.bind
    @vbo_quad.load_buffer(GeometryData::QUAD_VERTICES, :float)


    # No element buffers required for this lesson, as we use glDrawArrays

    # setup shaders
    @scene_shader_program = Utils::ShaderProgram.new
    @scene_shader_program.load_from({vertex: File.open(scene_vertex_source, 'r', &:read),
                                     fragment: File.open(scene_frag_source, 'r', &:read)})
    @scene_shader_program.bind_frag('outColor')
    @scene_shader_program.link

    @screen_shader_program = Utils::ShaderProgram.new
    @screen_shader_program.load_from({vertex: File.open(screen_vertex_source, 'r', &:read),
                                    fragment: File.open(screen_frag_source, 'r', &:read)})
    @screen_shader_program.link
    # end shader setup

    # Setup scene vertex attributes
    @vao_cube.bind
    @vbo_cube.bind
    @scene_shader_program.enable_vertex_attrib('position', 3, :float, 8)
    @scene_shader_program.enable_vertex_attrib('color',    3, :float, 8, 3)
    @scene_shader_program.enable_vertex_attrib('texcoord', 2, :float, 8, 6)

    # Setup screen vertex attributes
    @vao_quad.bind
    @vbo_quad.bind
    @screen_shader_program.enable_vertex_attrib('position', 2, :float, 4)
    @screen_shader_program.enable_vertex_attrib('texcoord', 2, :float, 4, 2)


    @textures.load('sample_moon.png', 'texMoon')
    @textures.load('sample_earth.png', 'texEarth')

    @scene_shader_program.use
    glUniform1i(@scene_shader_program.uniform_location('texEarth'), @textures.slot_for('texEarth'))
    glUniform1i(@scene_shader_program.uniform_location('texMoon'), @textures.slot_for('texMoon'))

    @screen_shader_program.use
    # FIXME not sure what '0' refers to
    glUniform1i(@screen_shader_program.uniform_location('texFramebuffer'), 0)


    @frame_buffer = Utils::FrameBuffer.new
    @frame_buffer.bind

    @tex_color_buffer = Utils::Texture.new(GL_TEXTURE_2D)
    @tex_color_buffer.bind
    @tex_color_buffer.create(@window.width, @window.height)
    @tex_color_buffer.texParameter(GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    @tex_color_buffer.texParameter(GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    @frame_buffer.texture2D(@tex_color_buffer.id)

    # Create a Renderbuffer object to hold depth/stencil buffers
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenRenderbuffers(1, buf)
    rbo_depth_stencil = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindRenderbuffer(GL_RENDERBUFFER, rbo_depth_stencil);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, @window.width, @window.height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo_depth_stencil)


    # with RenderBuffer this collapses into:
    # rbo_depth_stencil = Utils::RenderBuffer.new
    # rbo_depth_stencil.bind
    # rbo_depth_stencil.set_storage(GL_DEPTH24_STENCIL8, @window.width, @window.height)
    # rbo_depth_stencil.set_framebuffer(GL_DEPTH_STENCIL_ATTACHMENT)

    @running = false unless @frame_buffer.complete?
  end

  def draw
    uniModel = @scene_shader_program.uniform_location('model')

    # Set view matrix(original used glm::lookAt)
    view = RMath3D::RMtx4.new.lookAtRH(
      RMath3D::RVec3.new(2.5, 2.5, 2.0), # eye
      RMath3D::RVec3.new(0.0, 0.0, 0.0), # at
      RMath3D::RVec3.new(0.0, 0.0, 1.0)  # up
    )

    @scene_shader_program.use

    uniView = @scene_shader_program.uniform_location('view');
    uniProj = @scene_shader_program.uniform_location('proj');
    # set projection matrix(original used glm:perspective)
    proj = RMath3D::RMtx4.new.perspectiveFovRH(45.0.to_rad, # FOV
                                              # aspect
                                              (@window.height.to_f / @window.width.to_f),
                                              # znear
                                              1.0,
                                              # zfar
                                              10.0)
    # Send view and proj matrix variables to shader (which will not change per-frame)
    glUniformMatrix4fv(uniView, 1, GL_FALSE,  Fiddle::Pointer[view.to_a.pack('F*')])
    glUniformMatrix4fv(uniProj, 1, GL_FALSE, Fiddle::Pointer[proj.to_a.pack('F*')])

    uniColor = @scene_shader_program.uniform_location('overrideColor')
    start_time = Time.now
    # Create initial model matrix
    model = RMath3D::RMtx4.new.setIdentity
    scaling = RMath3D::RMtx4.new.scaling(1.0, 1.0, -1.0)
    translation = RMath3D::RMtx4.new.translation(0.0, 0.0, -1.0)

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
      @frame_buffer.bind
      @vao_cube.bind
      glEnable(GL_DEPTH_TEST)
      @scene_shader_program.use

      glActiveTexture(GL_TEXTURE0)
      @textures.bind('texEarth')
      glActiveTexture(GL_TEXTURE1)
      @textures.bind('texMoon')

      glClearColor(1.0, 1.0, 1.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

      now = Time.now
      time = (now - start_time)

      # Calculate new rotation
      model = model.rotationAxis(RMath3D::RVec3.new(0.0, 0.0, 1.0),
                                                   (time * 180.0.to_rad))

      # Update shader with new rotation
      glUniformMatrix4fv(uniModel, 1, GL_FALSE, Fiddle::Pointer[model.to_a.pack('F*')])

      # Draw cube
      glDrawArrays(GL_TRIANGLES, 0, 36)

      # Setup stencil mask
      glEnable(GL_STENCIL_TEST)
      # Draw floor:
      # set any stencil to 1
      glStencilFunc(GL_ALWAYS, 1, 0xFF) 
      glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
      # write to stencil buffer
      glStencilMask(0xFF) 
      # don't write to depth buffer
      glDepthMask(GL_FALSE) 
      # clear stencil buffer
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
      glUniformMatrix4fv(uniModel, 1, GL_FALSE, Fiddle::Pointer[model.to_a.pack('F*')])
      glUniform3f(uniColor, 0.3, 0.3, 0.3)
      glDrawArrays(GL_TRIANGLES, 0, 36)
      glUniform3f(uniColor, 1.0, 1.0, 1.0)

      glDisable(GL_STENCIL_TEST)

      # Bind default framebuffer and draw contents of our framebuffer
      glBindFramebuffer(GL_FRAMEBUFFER, 0)
      @vao_quad.bind
      glDisable(GL_DEPTH_TEST)
      @screen_shader_program.use

      glActiveTexture(GL_TEXTURE0)
      @tex_color_buffer.bind

      glDrawArrays(GL_TRIANGLES, 0, 6)

      @window.window.gl_swap
    end
  end
end

window = Application.new(800, 600, 'framebuffer') #, true)
Framebuffer.new(window).draw
