require_relative './lib/window'
require_relative './lib/utils'
require_relative './data'

require "rmath3d/rmath3d"

class Framebuffer
  include Logging
  using Utils::RadianHelper

  def initialize(window)
    @window = window
    @name = "framebuffer"

    scene_vertex_source = File.join("shaders", @name, "sceneVertex.glsl")
    scene_frag_source = File.join("shaders", @name, "sceneFragment.glsl")

    screen_vertex_source = File.join("shaders", @name, "screenVertex.glsl")
    screen_frag_source = File.join("shaders", @name, "screenFragment.glsl")

    @textures = Utils::Textures.new

    @running = true

    glEnable(GL_DEPTH_TEST)

    # Create VAOs
    @vaoCube = Utils::VertexArray.new
    @vaoQuad = Utils::VertexArray.new

    # Setup VBO
    @vboCube = Utils::VertexBuffer.new
    @vboQuad = Utils::VertexBuffer.new

    @vboCube.bind
    @vboCube.load_buffer(GeometryData::Vertices, :float)

    @vboQuad.bind
    @vboQuad.load_buffer(GeometryData::QuadVertices, :float)


    # No element buffers required for this lesson, as we use glDrawArrays

    # setup shaders
    @sceneShaderProgram = Utils::ShaderProgram.new
    @sceneShaderProgram.load_from({vertex: File.open(scene_vertex_source, "r") {|f| f.read}, 
                                     fragment: File.open(scene_frag_source, "r") {|f| f.read}})


    @screenShaderProgram = Utils::ShaderProgram.new
    @screenShaderProgram.load_from({vertex: File.open(screen_vertex_source, "r") {|f| f.read}, 
                                    fragment: File.open(screen_frag_source, "r") {|f| f.read}})
    # end shader setup

    # Setup scene vertex attributes
    @vaoCube.bind
    @vboCube.bind
    @sceneShaderProgram.enable_vertex_attrib("position", 3, :float, 8)
    @sceneShaderProgram.enable_vertex_attrib("color",    3, :float, 8, 3)
    @sceneShaderProgram.enable_vertex_attrib("texcoord", 2, :float, 8, 6)
    @sceneShaderProgram.bind_frag("outColor")

    # Setup screen vertex attributes
    @vaoQuad.bind
    @vboQuad.bind
    @screenShaderProgram.enable_vertex_attrib("position", 2, :float, 4)
    @screenShaderProgram.enable_vertex_attrib("texcoord", 2, :float, 4, 2)


    @textures.load("sample_moon.png", "texMoon")
    @textures.load("sample_earth.png", "texEarth")

    @sceneShaderProgram.use
    glUniform1i(@sceneShaderProgram.uniform_location("texEarth"), @textures.slot_for("texEarth"))
    glUniform1i(@sceneShaderProgram.uniform_location("texMoon"), @textures.slot_for("texMoon"))

    @screenShaderProgram.use
    # FIXME not sure what '0' refers to
    glUniform1i(@screenShaderProgram.uniform_location("texFramebuffer"), 0)


    @frameBuffer = Utils::FrameBuffer.new
    @frameBuffer.bind

    @texColorBuffer = Utils::Texture.new(GL_TEXTURE_2D)
    @texColorBuffer.bind
    @texColorBuffer.create(@window.width, @window.height)
    @texColorBuffer.texParameter(GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    @texColorBuffer.texParameter(GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    @frameBuffer.texture2D(@texColorBuffer.id)

    # Create a Renderbuffer object to hold depth/stencil buffers
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenRenderbuffers(1, buf)
    rboDepthStencil = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindRenderbuffer(GL_RENDERBUFFER, rboDepthStencil);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, @window.width, @window.height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rboDepthStencil)


    # with RenderBuffer this collapses into:
    #@rboDepthStencil = Utils::RenderBuffer.new
    #@rboDepthStencil.bind
    #@rboDepthStencil.set_storage(GL_DEPTH24_STENCIL8, @window.width, @window.height)
    #@rboDepthStencil.set_framebuffer(GL_DEPTH_STENCIL_ATTACHMENT)

    @running = false unless @frameBuffer.complete?
  end

  def draw
    uniModel = @sceneShaderProgram.uniform_location("model")

    # Set view matrix(original used glm::lookAt)
    view = RMath3D::RMtx4.new.lookAtRH(
      RMath3D::RVec3.new(2.5, 2.5, 2.0), # eye
      RMath3D::RVec3.new(0.0, 0.0, 0.0), # at
      RMath3D::RVec3.new(0.0, 0.0, 1.0)  # up
    )

    @sceneShaderProgram.use

    uniView = @sceneShaderProgram.uniform_location("view");
    uniProj = @sceneShaderProgram.uniform_location("proj");
    # set projection matrix(original used glm:perspective)
    proj = RMath3D::RMtx4.new.perspectiveFovRH(45.0.to_rad, # FOV
                                              (@window.height.to_f / @window.width.to_f), # aspect
                                              1.0, # znear
                                              10.0) # zfar
    # Send view and proj matrix variables to shader (which will not change per-frame)
    glUniformMatrix4fv(uniView, 1, GL_FALSE,  Fiddle::Pointer[view.to_a.pack('F*')])
    glUniformMatrix4fv(uniProj, 1, GL_FALSE, Fiddle::Pointer[proj.to_a.pack('F*')])

    uniColor = @sceneShaderProgram.uniform_location("overrideColor")
    start_time = SDL2::get_ticks / 1000.0
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
      @frameBuffer.bind
      @vaoCube.bind
      glEnable(GL_DEPTH_TEST)
      @sceneShaderProgram.use

      glActiveTexture(GL_TEXTURE0)
      @textures.bind("texEarth")
      glActiveTexture(GL_TEXTURE1)
      @textures.bind("texMoon")
      
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

      # Bind default framebuffer and draw contents of our framebuffer
      glBindFramebuffer(GL_FRAMEBUFFER, 0)
      @vaoQuad.bind
      glDisable(GL_DEPTH_TEST)
      @screenShaderProgram.use

      glActiveTexture(GL_TEXTURE0)
      @texColorBuffer.bind

      glDrawArrays(GL_TRIANGLES, 0, 6)

      @window.window.gl_swap
    end
  end
end

window = Window.new(800, 600, "framebuffer", true)
Framebuffer.new(window).draw
