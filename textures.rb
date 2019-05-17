require 'chunky_png'

require_relative './lib/window'
require_relative './lib/utils'

class Textures
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
    @vert_shader = "vert_shader.glsl"
    @vert_source = File.join("shaders", @name, @vert_shader)
    @frag_source = File.join("shaders", @name, frag_shader)

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

    vertexShader = Utils::Shader.new(GL_VERTEX_SHADER)
    @running = false unless vertexShader.load(File.open(@vert_source, "r") {|f| f.read})

    fragShader = Utils::Shader.new(GL_FRAGMENT_SHADER)
    @running = false unless fragShader.load(File.open(@frag_source, "r") {|f| f.read})

    @shaderProgram = glCreateProgram()
    glAttachShader(@shaderProgram, vertexShader.id)
    glAttachShader(@shaderProgram, fragShader.id)
    #We have multiple buffers if we include textures!
    glBindFragDataLocation(@shaderProgram, 0, "outColor")

    glLinkProgram(@shaderProgram)
    glUseProgram(@shaderProgram)

    #vertex data and attributes
    posAttrib = glGetAttribLocation(@shaderProgram, "position")
    glEnableVertexAttribArray(posAttrib)
    glVertexAttribPointer(posAttrib,                # location
                          2,                        # size
                          GL_FLOAT,                 # type
                          GL_FALSE,                 # normalized?
                          Fiddle::SIZEOF_FLOAT * Vertices[0].length, # stride: 5 items in each vertex(x,y,r,g,b)
                          0        # no offset required
                         )

    colAttrib = glGetAttribLocation(@shaderProgram, "color")
    glEnableVertexAttribArray(colAttrib)
    glVertexAttribPointer(colAttrib,
                          3,
                          GL_FLOAT,
                          GL_FALSE,
                          Fiddle::SIZEOF_FLOAT * Vertices[0].length,
                          (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 2) # "Offset" pointer: space for 2 floats, cast to void*
                         )

    texAttrib = glGetAttribLocation(@shaderProgram, "texcoord")
    glEnableVertexAttribArray(texAttrib)
    glVertexAttribPointer(texAttrib,
                          2,
                          GL_FLOAT,
                          GL_FALSE,
                          Fiddle::SIZEOF_FLOAT * Vertices[0].length,
                          (Fiddle::Pointer[0] + Fiddle::SIZEOF_FLOAT * 5) # "Offset" pointer: space for 2 floats, cast to void*
                         )
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

    # FIXME there's a difference between SOIL and ChunkyPNG loading:
    # loading with C_P makes it look like the scanlines are out of wack, so 
    # there's some difference between what opengl expects and what chunkyPNG is giving
    image = File.open('sample.png', 'rb') {|io| ChunkyPNG::Canvas.from_io(io)}
    image_ptr = Fiddle::Pointer[image.pixels.pack("L*")]
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, image.width, image.height, 0, GL_RGB, GL_UNSIGNED_BYTE, image_ptr)
    # unsure how/if to free image itself after pixels are sent to opengl

    #x,y,z = s,t,r in textures
    #set clamping for s and t coordinates

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    #Specify interpolation for scaling up/down*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

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

  #def load_texture(filename, name, slot, texBuffer, shader)
  def load_texture(filename, name, slot, texBuffer)
    # FIXME there's a difference between SOIL and ChunkyPNG loading:
    # loading with C_P makes it look like the scanlines are out of wack, so 
    # there's some difference between what opengl expects and what chunkyPNG is giving
    slots = [GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2]

    glActiveTexture(slots[slot])
    glBindTexture(GL_TEXTURE_2D, texBuffer)

    image = File.open(filename, 'rb') {|io| ChunkyPNG::Canvas.from_io(io)}
    image_ptr = Fiddle::Pointer[image.pixels.pack("L*")]
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, image.width, image.height, 0, GL_RGB, GL_UNSIGNED_BYTE, image_ptr)
    # unsure how/if to free image itself after pixels are sent to opengl
    #uni_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)

    uni_buf = glGetUniformLocation(@shaderProgram, name)
    #puts uni_buf.inspect
    glUniform1i(uni_buf, slot)

    #x,y,z = s,t,r in textures
    #set clamping for s and t coordinates

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    #Specify interpolation for scaling up/down*/
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  end

  def draw_anim_blend_texture
    start_time = SDL2::get_ticks / 1000.0
    current_time = 0.0
    tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT * 2)
    glGenTextures(2, tex_buf)
    #puts tex_buf.inspect
    #tex = tex_buf[0, Fiddle::SIZEOF_INT*2].unpack('L') #[0]
    #tex = tex_buf[0, Fiddle::SIZEOF_INT * 2].unpack('L') #[0]
    tex = [tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0], tex_buf[Fiddle::SIZEOF_INT, Fiddle::SIZEOF_INT*2].unpack('L')[0]]
    #puts tex.inspect
    #glBindTexture(GL_TEXTURE_2D, tex)

    # FIXME there's a difference between SOIL and ChunkyPNG loading:
    # loading with C_P makes it look like the scanlines are out of wack, so 
    # there's some difference between what opengl expects and what chunkyPNG is giving
    load_texture('sample.png', 'texKitten', 0, tex[0])
    load_texture('sample2.png', 'texPuppy', 1, tex[1])

    # unsure how/if to free image itself after pixels are sent to opengl

    uni_time = glGetUniformLocation(@shaderProgram, "time")
    puts uni_time.inspect
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

      currentTime = SDL2::get_ticks / 1000.0
      glUniform1f(uni_time, (current_time - start_time))
      glDrawElements(GL_TRIANGLES, Elements.length, GL_UNSIGNED_INT, 0)

      @window.window.gl_swap
    end
  end
end

window = Window.new(800, 600, "textures", true)
#Textures.new(window, "no_tex_frag.glsl").draw_checkerboard
#Textures.new(window, "one_texture_frag.glsl").draw_texture
Textures.new(window, "anim_tex_frag_shader.glsl").draw_anim_blend_texture
