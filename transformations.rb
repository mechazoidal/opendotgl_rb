require_relative './lib/window'
require_relative './lib/utils'

require "rmath3d/rmath3d"

class Transformations
  include Logging
  using Utils::RadianHelper

  Vertices = [    #  Position      Color             Texcoords
                  [ -0.5,  0.5, 1.0, 0.0, 0.0, 0.0, 0.0 ], # Top-left
                  [  0.5,  0.5, 0.0, 1.0, 0.0, 1.0, 0.0 ], # Top-right
                  [  0.5, -0.5, 0.0, 0.0, 1.0, 1.0, 1.0 ], # Bottom-right
                  [ -0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0 ]  # Bottom-left
  ]
  Elements = [
    0, 1, 2,
    2, 3, 0
  ]
  def initialize(window)
    @window = window
    @name = "transformations"
    @vert_source = File.join("shaders", @name, "vert_shader.glsl")
    @frag_source = File.join("shaders", @name, "two_textures_frag.glsl")

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
    vertices_data_ptr = Fiddle::Pointer[Vertices.flatten.pack("F*")]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * Vertices.flatten.length
    glBufferData(GL_ARRAY_BUFFER, vertices_data_size, vertices_data_ptr, GL_STATIC_DRAW)


    # setup vertex element buffers
    ebo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, ebo_buf)
    ebo = ebo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    element_data_ptr = Fiddle::Pointer[Elements.pack("i*")]
    element_data_size = Fiddle::SIZEOF_INT * Elements.length
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, element_data_size, element_data_ptr, GL_STATIC_DRAW)
    vertexShader = Utils::Shader.new(:vertex)
    @running = false unless vertexShader.load(File.open(@vert_source, "r") {|f| f.read})

    fragShader = Utils::Shader.new(:fragment)
    @running = false unless fragShader.load(File.open(@frag_source, "r") {|f| f.read})

    @shaderProgram = glCreateProgram()
    glAttachShader(@shaderProgram, vertexShader.id)
    glAttachShader(@shaderProgram, fragShader.id)
    glBindFragDataLocation(@shaderProgram, 0, "outColor")

    glLinkProgram(@shaderProgram)
    glUseProgram(@shaderProgram)

    posAttrib = glGetAttribLocation(@shaderProgram, "position")
    if posAttrib != -1
      glEnableVertexAttribArray(posAttrib)
      glVertexAttribPointer(posAttrib,                # location
                            2,                        # size
                            GL_FLOAT,                 # type
                            GL_FALSE,                 # normalized?
                            Fiddle::SIZEOF_FLOAT * Vertices[0].length, # stride: 5 items in each vertex(x,y,r,g,b)
                            0        # no offset required
                           )
    end

    colAttrib = glGetAttribLocation(@shaderProgram, "color")
    if colAttrib != -1
      glEnableVertexAttribArray(colAttrib)
      glVertexAttribPointer(colAttrib,
                            3,
                            GL_FLOAT,
                            GL_FALSE,
                            Fiddle::SIZEOF_FLOAT * Vertices[0].length,
                            (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 2) # "Offset" pointer: space for 2 floats, cast to void*
                           )
    end

    texAttrib = glGetAttribLocation(@shaderProgram, "texcoord")
    if texAttrib != -1
      glEnableVertexAttribArray(texAttrib)
      glVertexAttribPointer(texAttrib,
                            2,
                            GL_FLOAT,
                            GL_FALSE,
                            Fiddle::SIZEOF_FLOAT * Vertices[0].length,
                            (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 5) # "Offset" pointer: space for 2 floats, cast to void*
                           )
    end
    @textures.load('sample_earth.png', 'texEarth')
    @textures.load('sample_moon.png', 'texMoon')

    glUniform1i(glGetUniformLocation(@shaderProgram, "texEarth"), @textures.slot_for("texEarth"));
    glUniform1i(glGetUniformLocation(@shaderProgram, "texMoon"), @textures.slot_for("texMoon"));

  end

  def draw

    uniModel = glGetUniformLocation(@shaderProgram, "model")

    # Set view matrix(original used glm::lookAt)
    view = RMath3D::RMtx4.new.lookAtRH(
      RMath3D::RVec3.new(1.2, 1.2, 1.2), # eye
      RMath3D::RVec3.new(0.0, 0.0, 0.0), # at
      RMath3D::RVec3.new(0.0, 0.0, 1.0)  # up
    )

    uniView = glGetUniformLocation(@shaderProgram, "view");
    uniProj = glGetUniformLocation(@shaderProgram, "proj");
    # set projection matrix(original used glm:perspective)
    proj = RMath3D::RMtx4.new.perspectiveFovRH(45.0.to_rad, # FOV
                                              (@window.height.to_f / @window.width.to_f), # aspect
                                              1.0, # znear
                                              10.0) # zfar


    start_time = SDL2::get_ticks / 1000.0

    # Send view and proj matrix variables to shader (which will not change per-frame)
    glUniformMatrix4fv(uniView, 1, GL_FALSE,  Fiddle::Pointer[view.to_a.pack('F*')])
    glUniformMatrix4fv(uniProj, 1, GL_FALSE, Fiddle::Pointer[proj.to_a.pack('F*')])

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

      current_time = SDL2::get_ticks / 1000.0
      time = (current_time - start_time)

      # Calculate new rotation
      model = model.rotationAxis(RMath3D::RVec3.new(0.0, 0.0, 1.0),
                                                   (time * 180.0.to_rad))

      # Update shader with new rotation
      glUniformMatrix4fv(uniModel, 1, GL_FALSE, Fiddle::Pointer[model.to_a.pack('F*')])

      glDrawElements(GL_TRIANGLES, Elements.length, GL_UNSIGNED_INT, 0)

      @window.window.gl_swap
    end
  end
end

window = Window.new(800, 600, "transformations")
Transformations.new(window).draw
