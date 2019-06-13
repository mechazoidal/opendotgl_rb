require_relative './lib/window'
require_relative './lib/utils'
require_relative './data'

require "rmath3d/rmath3d"

class Feedback
  include Logging
  FeedbackVaryings = "outValue"
  def initialize(window)
    @window = window
    @name = "feedback"
  end

  def calculate
    vertex_source = File.join("shaders", @name, "vertexShader.glsl")
    geometry_source = File.join("shaders", @name, "geoShader.glsl")
    @shaderProgram = Utils::ShaderProgram.new
    @shaderProgram.load_and_attach(:vertex, File.open(vertex_source, "r") {|f| f.read})
    @shaderProgram.load_and_attach(:geometry, File.open(geometry_source, "r") {|f| f.read})

    varying_ptr = ["outValue"].pack('p')
    glTransformFeedbackVaryings(@shaderProgram.id, 1, varying_ptr, GL_INTERLEAVED_ATTRIBS)
    @shaderProgram.link
    @shaderProgram.use

    @vao = Utils::VertexArray.new
    @vao.bind

    data = [1.0, 2.0, 3.0, 4.0, 5.0]

    @vbo = Utils::VertexBuffer.new
    @vbo.bind
    @vbo.load_buffer(data, :float)
    @shaderProgram.enable_vertex_attrib("inValue", 1, :float, 0)

    # Create transform buffer
    @tbo = Utils::VertexBuffer.new
    @tbo.bind
    @data_size = @tbo.fiddle_type(:float) * data.length * 3
    glBufferData(GL_ARRAY_BUFFER, @data_size, Utils::NullPtr, GL_STATIC_READ)
    # Throw away the rasterizer, we don't need visual output
    glEnable(GL_RASTERIZER_DISCARD)

    glBindBufferBase(GL_TRANSFORM_FEEDBACK_BUFFER, 0, @tbo.id)
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenQueries(1, buf)
    query = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]

    # must be done BEFORE glBeginTransformFeedback
    # Other useful queries: GL_PRIMITIVES_GENERATED, GL_TIME_ELAPSED, etc.
    glBeginQuery(GL_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN, query)
    # unique to feedback shaders
    glBeginTransformFeedback(GL_TRIANGLES)

    glDrawArrays(GL_POINTS, 0, 5)

    glEndTransformFeedback()
    glEndQuery(GL_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN)

    glFlush()
    # get results back
    feedback = Fiddle::Pointer.malloc(Fiddle::SIZEOF_FLOAT * 15)
    glGetBufferSubData(GL_TRANSFORM_FEEDBACK_BUFFER, Utils::NullPtr, (15 * Fiddle::SIZEOF_FLOAT), feedback)
    response = feedback[0, @data_size].unpack('F*')
    response.each {|n| puts n}

    # get query results
    prim_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGetQueryObjectuiv(query, GL_QUERY_RESULT, prim_buf)
    primitives = prim_buf[0, Fiddle::SIZEOF_INT].unpack('L*')[0]
    puts "#{primitives} primitives written!"
  end
end

class FeedbackGravity
  include Logging
  FeedbackVaryings = ["outPosition", "outVelocity"]

  def initialize(window)
    @window = window
    @name = "feedback"
  end

  def draw
    @running = true

    vertex_source = File.join("shaders", @name, "vertexShader_gravity.glsl")
    frag_source = File.join("shaders", @name, "fragmentShader.glsl")
    @shader_program = Utils::ShaderProgram.new
    @shader_program.load_from({vertex: File.open(vertex_source, "r") {|f| f.read},
                              fragment: File.open(frag_source, "r") {|f| f.read}})
    varying_ptr = ["outPosition", "outVelocity"].pack('p*')
    
    glTransformFeedbackVaryings(@shader_program.id, 2, varying_ptr, GL_INTERLEAVED_ATTRIBS)
    @shader_program.link
    @shader_program.use

    uniTime = @shader_program.uniform_location("time")
    uniMousePos = @shader_program.uniform_location("mousePos")

    @vao = Utils::VertexArray.new
    @vao.bind

    # FIXME optimize
    # Vertex format: 6 floats per vertex:
    # pos.x  pox.y  vel.x  vel.y  origPos.x  origPos.y
    @data = Array.new(600) {0.0}
    10.times do |y|
      10.times do |x|
        @data[60 * y + 6 * x] = 0.2 * x - 0.9
        @data[60 * y + 6 * x + 1] = 0.2 * y - 0.9
        @data[60 * y + 6 * x + 4] = 0.2 * x - 0.9
        @data[60 * y + 6 * x + 5] = 0.2 * y - 0.9
      end
    end

    @data_size = Fiddle::SIZEOF_FLOAT * @data.length
    @data_ptr = Fiddle::Pointer[@data.pack("F*")]


    @vbo = Utils::VertexBuffer.new
    @vbo.bind
    @vbo.load_buffer(@data, :float, GL_STREAM_DRAW)

    @shader_program.enable_vertex_attrib("position",    2, :float, 6)
    @shader_program.enable_vertex_attrib("velocity",    2, :float, 6, 2)
    @shader_program.enable_vertex_attrib("originalPos", 2, :float, 6, 4)

    # Create transform feedback buffer
    @tbo = Utils::VertexBuffer.new
    @tbo.bind
    #tbo.set_read_buffer(:float, 400)
    # feedback_size
    glBufferData(GL_ARRAY_BUFFER, Fiddle::SIZEOF_FLOAT * 400, Utils::NullPtr, GL_STATIC_READ)

    # Declare our feedback buffer
    glBindBufferBase(GL_TRANSFORM_FEEDBACK_BUFFER, 0, @tbo.id)
    # approach 1
    #@feedback = Array.new(400) {0.0}
    #@feedback_size = Fiddle::SIZEOF_FLOAT * @feedback.length
    #@feedback_ptr = Fiddle::Pointer[@feedback.pack("F*")]
    # end approach 1

    # approach 2
    @feedback_length = 400
    @feedback_size = Fiddle::SIZEOF_FLOAT * @feedback_length

    @feedback = Fiddle::Pointer.malloc(@feedback_size, Utils::FreeFunction)
    # end approach 2
    @vbo.bind

    glPointSize(5.0)

    previous_time = Time.now


    mouse_x = 400
    mouse_y = 300

    SDL2::Mouse::Cursor::warp(@window.window, 400, 300)
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
      when SDL2::Event::MouseMotion
        mouse_x = event.x
        mouse_y = event.y
      end
      # draw here
      glClearColor(0.0, 0.0, 0.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT)

      now = Time.now
      time = (now - previous_time)
      previous_time = now

      glUniform1f(uniTime, time)

      # update mouse position
      glUniform2f(uniMousePos, mouse_x / 400.0 - 1, -mouse_y / 400.0 + 1)


      # Query feedback
      buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGenQueries(1, buf)
      query = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
      glBeginQuery(GL_TIME_ELAPSED, query)
      # unique to feedback shaders
      glBeginTransformFeedback(GL_POINTS)


      # draw our gravity-influenced points
      glDrawArrays(GL_POINTS, 0, 100)

      glEndTransformFeedback()
      glEndQuery(GL_TIME_ELAPSED)
      @window.window.gl_swap


      # Get our updated coordinates from the feedback buffer
      # approach 1
      glGetBufferSubData(GL_TRANSFORM_FEEDBACK_BUFFER, 0, @feedback_size, @feedback)
      response = @feedback[0, @feedback_size].unpack('F*')
      # FIXME optimize array manipulation?
      # each "row" is 4: 100.times {4} = 400
      100.times do |i|
        @data[6 * i] = response[4 * i]
        @data[6 * i + 1] = response[4 * i + 1]
        @data[6 * i + 2] = response[4 * i + 2]
        @data[6 * i + 3] = response[4 * i + 3]
      end
      # end approach 1


      #approach 2
      #glGetBufferSubData(GL_TRANSFORM_FEEDBACK_BUFFER, Utils::NullPtr, @feedback_size, @feedback_ptr)

      #@feedback = @feedback_ptr[0, @feedback_size].unpack("F*")
      #100.times do |i|
        #@data[6 * i] = @feedback[4 * i]
        #@data[6 * i + 1] = @feedback[4 * i + 1]
        #@data[6 * i + 2] = @feedback[4 * i + 2]
        #@data[6 * i + 3] = @feedback[4 * i + 3]
      #end
      #puts feedback.inspect
      # end approach 2


      # glBufferData reallocates the whole vertex data buffer,
      # so we use this to just update the existing buffer


      # TODO is there a better way to do this than repeatedly packing?
      # approach 1
      glBufferSubData(GL_ARRAY_BUFFER, 0, @data_size, Fiddle::Pointer[@data.pack("F*")])

      # approach 2
      #glBufferSubData(GL_ARRAY_BUFFER, 0, @data_size, @data_ptr)

      # get time elapsed from query
      time_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGetQueryObjectuiv(query, GL_QUERY_RESULT, time_buf)
      time_elapsed = time_buf[0, Fiddle::SIZEOF_INT].unpack('L*')[0]
      #logger.info time_elapsed.inspect
    end
  end
end

#window = Window.new(800, 600, "feedback", true)
window = Window.new(800, 600, "feedback")
#Feedback.new(window).calculate
FeedbackGravity.new(window).draw
