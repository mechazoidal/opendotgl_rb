require_relative './lib/window'
require_relative './lib/utils'
require 'optimist'

class Textures
  include Logging
  attr_reader :name
  VERTICES = [  # Position | Color   |  Texcoords   |
                # Top-left
                [-0.5,  0.5, 1.0, 0.0, 0.0, 0.0, 0.0],
                # Top-right
                [ 0.5,  0.5, 0.0, 1.0, 0.0, 1.0, 0.0],
                # Bottom-right
                [ 0.5, -0.5, 0.0, 0.0, 1.0, 1.0, 1.0],
                # Bottom-left
                [-0.5, -0.5, 1.0, 1.0, 1.0, 0.0, 1.0]
  ].freeze
  ELEMENTS = [
    0, 1, 2,
    2, 3, 0
  ].freeze

  def initialize(window, frag_shader, vert_shader='vert_shader.glsl')
    @window = window
    @name = 'textures'
    @vert_source = File.join('shaders', @name, vert_shader)
    @frag_source = File.join('shaders', @name, frag_shader)

    @textures = [GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2]

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
    glBufferData(GL_ARRAY_BUFFER,
                 vertices_data_size,
                 vertices_data_ptr,
                 GL_STATIC_DRAW)

    # setup vertex element buffers
    ebo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, ebo_buf)
    ebo = ebo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    element_data_ptr = Fiddle::Pointer[ELEMENTS.pack('i*')]
    element_data_size = Fiddle::SIZEOF_INT * ELEMENTS.length
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER,
                 element_data_size,
                 element_data_ptr,
                 GL_STATIC_DRAW)

  end

  def create_shader_program
    vertex_shader = Utils::Shader.new(:vertex)
    @running = false unless vertex_shader.load(File.open(@vert_source, 'r', &:read))

    frag_shader = Utils::Shader.new(:fragment)
    @running = false unless frag_shader.load(File.open(@frag_source, 'r', &:read))

    @shader_program = glCreateProgram()
    glAttachShader(@shader_program, vertex_shader.id)
    glAttachShader(@shader_program, frag_shader.id)
    # We have multiple buffers if we include textures!
    glBindFragDataLocation(@shader_program, 0, 'outColor')

    glLinkProgram(@shader_program)
  end

  def setup_position_vertex_attribute
    # Setup our vertex attributes
    # Note that if the fragment shader does not USE the attribute, the GLSL compiler is free to strip it!
    # Thus we can't blindly enable the vertex attrib array unless we get a real location back.
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
  end

  def setup_color_vertex_attribute
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
  end

  def setup_texcoord_vertex_attribute
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
  end

  def load_texture(filename, name, slot, tex_buffer)
    logger.debug("load_texture: loading #{filename} "\
                 "to name '#{name}' "\
                 "at slot '#{slot}' (#{@textures[slot]}) "\
                 "to buffer #{tex_buffer}")
    glActiveTexture(@textures[slot])
    glBindTexture(GL_TEXTURE_2D, tex_buffer)

    # x,y,z = s,t,r in textures

    # set clamping for s and t coordinates
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    # Specify interpolation for scaling up/down*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

    image = SDL2::Surface.load(filename)
    image_ptr = Fiddle::Pointer[image.pixels]
    mode = image.bytes_per_pixel == 4 ? GL_RGBA : GL_RGB
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 mode,
                 image.w,
                 image.h,
                 0,
                 mode,
                 GL_UNSIGNED_BYTE,
                 image_ptr)
    image.destroy

    uni_buf = glGetUniformLocation(@shader_program, name)
    logger.debug { "attribute #{name} location: #{uni_buf.inspect}" }
    glUniform1i(uni_buf, slot)
    Utils.gl_get_errors
    nil
  end
end

# FIXME: not working yet
class Checkerboard < Textures
  def initialize(window)
    super(window, 'no_tex_frag.glsl', 'no_tex_vert.glsl')
    create_shader_program
    glUseProgram(@shader_program)
    setup_position_vertex_attribute
    setup_color_vertex_attribute
  end

  def draw
    # Get our texture memory.
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenTextures(1, tex_buf)
    tex = tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindTexture(GL_TEXTURE_2D, tex)
    #glActiveTexture(@textures[slot])

    # x,y,z = s,t,r in textures

    # set clamping for s and t coordinates
    #glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    #glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    # Specify interpolation for scaling up/down
    #glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    #glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

    # BW checkerboard
    pixels = [
      0.0, 0.0, 0.0,  1.0, 1.0, 1.0,
      1.0, 1.0, 1.0,  0.0, 0.0, 0.0
    ]

    # for checkerboard
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)

    # change border color to red
    # FIXME not working?
    #color = [1.0, 0.0, 0.0, 1.0]
    #color_ptr = Fiddle::Pointer[color.pack('F*')]
    #glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, color_ptr)

    pixels_ptr = Fiddle::Pointer[pixels.pack('F*')]

    glTexImage2D(GL_TEXTURE_2D,
                 # LOD (0=base image)
                 0,
                 # internal pixel format
                 GL_RGB,
                 # width
                 2,
                 # height
                 2,
                 # always 0, per spec
                 0,
                 # format of pixels in image
                 GL_RGB,
                 # type of pixels in image
                 GL_FLOAT,
                 # array to use
                 pixels_ptr)

    glGenerateMipmap(GL_TEXTURE_2D)

    # Start event loop
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

      # Draw to screen
      glClearColor(0.0, 0.0, 0.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT)
      glDrawElements(GL_TRIANGLES, ELEMENTS.length, GL_UNSIGNED_INT, 0)

      @window.window.gl_swap
    end
  end
end

class Basic < Textures
  def initialize(window)
    super(window, 'one_texture_frag.glsl')
    create_shader_program
    glUseProgram(@shader_program)
    setup_position_vertex_attribute
    setup_color_vertex_attribute
    setup_texcoord_vertex_attribute
  end

  def draw
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenTextures(1, tex_buf)
    tex = tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindTexture(GL_TEXTURE_2D, tex)

    image = SDL2::Surface.load('sample_earth.png')
    image_ptr = Fiddle::Pointer[image.pixels]
    mode = image.bytes_per_pixel == 4 ? GL_RGBA : GL_RGB
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 mode,
                 image.w,
                 image.h,
                 0,
                 mode,
                 GL_UNSIGNED_BYTE,
                 image_ptr)
    image.destroy
    Utils.gl_get_errors

    # x,y,z = s,t,r in textures

    # set clamping for s and t coordinates
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    # Specify interpolation for scaling up/down*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

    # Start render loop
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

      # Draw to screen
      glClearColor(0.0, 0.0, 0.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT)
      glDrawElements(GL_TRIANGLES, ELEMENTS.length, GL_UNSIGNED_INT, 0)

      @window.window.gl_swap
    end
  end
end

class Blend < Textures
  def initialize(window)
    super(window, 'two_textures_frag.glsl')
    create_shader_program
    glUseProgram(@shader_program)
    setup_position_vertex_attribute
    setup_color_vertex_attribute
    setup_texcoord_vertex_attribute
  end

  def draw
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT * 2)
    glGenTextures(2, tex_buf)
    tex = [tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0],
           tex_buf[Fiddle::SIZEOF_INT, Fiddle::SIZEOF_INT * 2].unpack('L')[0]]

    load_texture('sample_earth.png', 'texEarth', 0, tex[0])
    load_texture('sample_moon.png', 'texMoon', 1, tex[1])
    Utils.gl_get_errors

    # Start render loop
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

      # Draw to screen
      glClearColor(0.0, 0.0, 0.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT)

      glDrawElements(GL_TRIANGLES, ELEMENTS.length, GL_UNSIGNED_INT, 0)

      Utils.gl_get_errors

      @window.window.gl_swap
    end
  end
end

class BlendAnimated < Textures
  def initialize(window)
    super(window, 'anim_tex_frag_shader.glsl')
    create_shader_program
    glUseProgram(@shader_program)
    setup_position_vertex_attribute
    setup_color_vertex_attribute
    setup_texcoord_vertex_attribute
  end

  def draw
    start_time = Time.now
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT * 2)
    glGenTextures(2, tex_buf)
    tex = [tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0],
           tex_buf[Fiddle::SIZEOF_INT,
                   Fiddle::SIZEOF_INT * 2].unpack('L')[0]]

    load_texture('sample_earth.png', 'texEarth', 0, tex[0])
    load_texture('sample_moon.png', 'texMoon', 1, tex[1])

    uni_time = glGetUniformLocation(@shader_program, 'uniTime')
    logger.debug { "texUniform: #{glGetUniformLocation(@shader_program, 'texEarth')}" }
    logger.debug { "texUniform: #{glGetUniformLocation(@shader_program, 'texMoon')}" }
    logger.debug "uni_time location: #{uni_time.inspect}"

    # Start render loop
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

      # Draw to screen
      glClearColor(0.0, 0.0, 0.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT)

      current_time = Time.now
      time = (current_time - start_time)
      glUniform1f(uni_time, time)
      glDrawElements(GL_TRIANGLES, ELEMENTS.length, GL_UNSIGNED_INT, 0)

      @window.window.gl_swap
    end
  end
end

examples = %w[checkerboard basic blend blend_animated]

opts = Optimist.options do
  opt :size, 'width X height string', default: '800x600'
  opt :example, "example to run: #{examples.join(', ')}", default: 'blend'
  opt :verbose, 'say a lot', default: false
end

window_size = Utils.parse_window_size(opts[:size])
Optimist.die('Valid size string is required') unless window_size
Optimist.die('Valid width is required') unless window_size[:width] > 0
Optimist.die('Valid height is required') unless window_size[:height] > 0

Optimist.die("Example must be one of: #{examples}") unless examples.include?(opts[:example])

window = Window.new(window_size[:width],
                    window_size[:height],
                    'textures',
                    opts[:verbose])

case opts[:example]
when 'checkerboard'
  Checkerboard.new(window).draw
when 'basic'
  Basic.new(window).draw
when 'blend'
  Blend.new(window).draw
when 'blend_animated'
  BlendAnimated.new(window).draw
end
