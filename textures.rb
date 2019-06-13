require_relative './lib/window'
require_relative './lib/utils'

# sample_earth: https://nasa3d.arc.nasa.gov/detail/as10-34-5013
# sample_moon: https://nasa3d.arc.nasa.gov/detail/as11-44-6665
class Textures
  include Logging
  attr_reader :name
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
  def initialize(window, frag_shader)
    @window = window
    @name = "textures"
    @vert_source = File.join("shaders", @name, "vert_shader.glsl")
    @frag_source = File.join("shaders", @name, frag_shader)

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
    #We have multiple buffers if we include textures!
    glBindFragDataLocation(@shaderProgram, 0, "outColor")

    glLinkProgram(@shaderProgram)
    glUseProgram(@shaderProgram)

    #vertex data and attributes
    # Note that if your fragment shader does not use an attribute at some point, the GLSL compiler is free to strip it!
    # Thus we can't blindly enable the vertex attrib array unless we get a real location back.
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
  end

  def draw_checkerboard

    # textures
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenTextures(1, tex_buf)
    tex = tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindTexture(GL_TEXTURE_2D, tex)

    #x,y,z = s,t,r in textures
    #set clamping for s and t coordinates

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    #Specify interpolation for scaling up/down*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

    # BW checkerboard
    pixels = [
      0.0, 0.0, 0.0,  1.0, 1.0, 1.0,
      1.0, 1.0, 1.0,  0.0, 0.0, 0.0
    ]
    # for checkerboard*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)

    # change border color to red
    # FIXME not working?
    color = [1.0, 0.0, 0.0, 1.0]
    color_ptr = Fiddle::Pointer[color.pack("F*")]
    glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, color_ptr);

    # params:
    # texture target
    # LOD (0=base image)
    # internal pixel format
    # width
    # height
    # always 0, per spec
    # format of pixels in image
    # type of pixels in image
    # array to use
    # FIXME it's a bit fuzzy, am I missing something here?
    pixels_ptr = Fiddle::Pointer[pixels.pack("F*")]
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 2, 2, 0, GL_RGB, GL_FLOAT, pixels_ptr);
    glGenerateMipmap(GL_TEXTURE_2D);

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
      glDrawElements(GL_TRIANGLES, Elements.length, GL_UNSIGNED_INT, 0)

      @window.window.gl_swap
    end

  end

  def draw_texture
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenTextures(1, tex_buf)
    tex = tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindTexture(GL_TEXTURE_2D, tex)

    image = SDL2::Surface.load('sample_earth.png')
    image_ptr = Fiddle::Pointer[image.pixels]
    mode = image.bytes_per_pixel == 4 ? GL_RGBA : GL_RGB
    #logger.debug image.bytes_per_pixel
    glTexImage2D(GL_TEXTURE_2D, 0, mode, image.w, image.h, 0, mode, GL_UNSIGNED_BYTE, image_ptr)
    image.destroy
    Utils.gl_get_errors

    #x,y,z = s,t,r in textures
    #set clamping for s and t coordinates

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    #Specify interpolation for scaling up/down*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    Utils.gl_get_errors

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
      glDrawElements(GL_TRIANGLES, Elements.length, GL_UNSIGNED_INT, 0)

      @window.window.gl_swap
    end

  end

  def load_texture(filename, name, slot, texBuffer)
    logger.debug {"load_texture: loading #{filename} to name #{name} at slot #{slot}(#{@textures[slot]}) to buffer #{texBuffer}"}
    glActiveTexture(@textures[slot])
    glBindTexture(GL_TEXTURE_2D, texBuffer)

    #x,y,z = s,t,r in textures
    #set clamping for s and t coordinates

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    #Specify interpolation for scaling up/down*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

    image = SDL2::Surface.load(filename)
    image_ptr = Fiddle::Pointer[image.pixels]
    mode = image.bytes_per_pixel == 4 ? GL_RGBA : GL_RGB
    glTexImage2D(GL_TEXTURE_2D, 0, mode, image.w, image.h, 0, mode, GL_UNSIGNED_BYTE, image_ptr)
    image.destroy

    uni_buf = glGetUniformLocation(@shaderProgram, name)
    logger.debug {"attribute #{name} location: #{uni_buf.inspect}"}
    glUniform1i(uni_buf, slot)
    Utils.gl_get_errors
    nil
  end

  def draw_blend_texture
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT * 2)
    glGenTextures(2, tex_buf)
    tex = [tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0], tex_buf[Fiddle::SIZEOF_INT, Fiddle::SIZEOF_INT*2].unpack('L')[0]]

    load_texture('sample_earth.png', 'texEarth', 0, tex[0])
    load_texture('sample_moon.png', 'texMoon', 1, tex[1])
    Utils.gl_get_errors

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

      glDrawElements(GL_TRIANGLES, Elements.length, GL_UNSIGNED_INT, 0)
    Utils.gl_get_errors

      @window.window.gl_swap
    end
  end

  def draw_anim_blend_texture
    start_time = Time.now
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT * 2)
    glGenTextures(2, tex_buf)
    tex = [tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0], tex_buf[Fiddle::SIZEOF_INT, Fiddle::SIZEOF_INT*2].unpack('L')[0]]

    load_texture('sample_earth.png', 'texEarth', 0, tex[0])
    load_texture('sample_moon.png', 'texMoon', 1, tex[1])

    uni_time = glGetUniformLocation(@shaderProgram, "uniTime")
    logger.debug {"texUniform: #{glGetUniformLocation(@shaderProgram, "texEarth")}"}
    logger.debug {"texUniform: #{glGetUniformLocation(@shaderProgram, "texMoon")}"}
    logger.debug {"uni_time location: #{uni_time.inspect}"}
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

      current_time = Time.now
      time = (current_time - start_time)
      glUniform1f(uni_time, time)
      glDrawElements(GL_TRIANGLES, Elements.length, GL_UNSIGNED_INT, 0)

      @window.window.gl_swap
    end
  end
end

window = Window.new(800, 600, "textures")
#Textures.new(window, "no_tex_frag.glsl").draw_checkerboard
#Textures.new(window, "one_texture_frag.glsl").draw_texture
#Textures.new(window, "two_textures_frag.glsl").draw_blend_texture
Textures.new(window, "anim_tex_frag_shader.glsl").draw_anim_blend_texture
