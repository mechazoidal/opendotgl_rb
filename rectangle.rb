require_relative './lib/window'
require_relative './lib/utils'
require_relative './lib/buffer_object'
require_relative './lib/shader'

class Rectangle
  def draw(window)
    @running = true
    #vertices = [
      #-0.5,  0.5, 1.0, 0.0, 0.0, # Top-left
       #0.5,  0.5, 0.0, 1.0, 0.0, # Top-right
       #0.5, -0.5, 0.0, 0.0, 1.0, # Bottom-right
      #-0.5, -0.5, 1.0, 1.0, 1.0, # Bottom-left
    #]
    #vertices1 = [
      #[-0.5,  0.5], # Top-left
      #[ 0.5,  0.5], # Top-right
      #[ 0.5, -0.5], # Bottom-right

      #[ 0.5, -0.5], # Bottom-right
      #[-0.5, -0.5], # Bottom-left
      #[-0.5,  0.5], # Top-left
    #]

    vertices = [
      [-0.5,  0.5], # Top-left
      [ 0.5,  0.5], # Top-right
      [ 0.5, -0.5], # Bottom-right
      [-0.5, -0.5], # Bottom-left
    ]

    # Create VAO
    vao_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenVertexArrays(1, vao_buf)
    vao = vao_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindVertexArray(vao)

    #vbo = BufferObject.new(GL_ARRAY_BUFFER)
    vbo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, vbo_buf)
    vbo = vbo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    vertices_data_ptr = Fiddle::Pointer[vertices.flatten.pack("F*")]
    vertices_data_size = Fiddle::SIZEOF_FLOAT * vertices.flatten.length
    glBufferData(GL_ARRAY_BUFFER, vertices_data_size, vertices_data_ptr, GL_STATIC_DRAW)
    #glBufferData(GL_ARRAY_BUFFER, Fiddle::SIZEOF_FLOAT * vertices1.flatten.length, vertices1.flatten.pack("F*"), GL_STATIC_DRAW)

    ebo_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, ebo_buf)

    elements = [
      0, 1, 2, 
      2, 3, 0
    ]

    #ebo = BufferObject.new(GL_ELEMENT_ARRAY_BUFFER)
    #ebo.set_data(Fiddle::Pointer[elements.pack('E*')[0]], elements.length, GL_STATIC_DRAW)

    ebo = ebo_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo)
    element_data_ptr = Fiddle::Pointer[elements.pack("C*")]
    element_data_size = Fiddle::SIZEOF_INT * elements.length
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, element_data_size, element_data_ptr, GL_STATIC_DRAW)

    #glBufferData(GL_ARRAY_BUFFER, Fiddle::SIZEOF_FLOAT * vertices.flatten.length, vertices.flatten.pack("F*"), GL_STATIC_DRAW)

    # TODO should really just do these manually for now, to reduce errors
    shader = Shader.new
    shader.load( vertex_code: File.open("shaders/rectangle/solid_vert.glsl", "r") {|f| f.read},
                 fragment_code: File.open("shaders/rectangle/solid_frag.glsl", "r") {|f| f.read})
    shader.use

    posAttrib = glGetAttribLocation(shader.program_id, "position")
    glEnableVertexAttribArray(posAttrib)
    glVertexAttribPointer(posAttrib,                # location
                          2,                        # size
                          GL_FLOAT,                 # type
                          GL_FALSE,                 # normalized?
                          0,
                          #Fiddle::SIZEOF_FLOAT * 5, # stride: 5 items in each vertex(x,y,r,g,b)
                          Fiddle::Pointer[0]        # 
                         )

    #shader.vertex_pointer("position", 2, 5, 0)

    #puts shader.location("position")
    #puts shader.location("color")

    #colAttrib = glGetAttribLocation(shader.program_id, "color")
    #glEnableVertexAttribArray(colAttrib)
    #shader.vertex_pointer("color", 3, 5, 0)
    #glVertexAttribPointer(colAttrib, 3 ,GL_FLOAT, GL_FALSE, Fiddle::SIZEOF_FLOAT * 5, Fiddle::Pointer[0])

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
      #render
      glClearColor(0.0, 0.0, 0.0, 1.0);
      glClear(GL_COLOR_BUFFER_BIT)
      glDrawElements(GL_TRIANGLES, elements.length, GL_UNSIGNED_INT, 0)
      #glDrawElements(GL_TRIANGLES, 9, GL_UNSIGNED_INT, 0)

      #glDrawArrays(GL_TRIANGLES, 0, 6)
      #glDrawArrays(GL_TRIANGLES, 0, elements.flatten.length)
      #glDrawArrays(GL_TRIANGLES, 0, vertices.flatten.length)

      window.window.gl_swap
    end
  end
end

window = Window.new(800, 600)
Rectangle.new.draw(window)
