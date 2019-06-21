require_relative './lib/application'
require_relative './lib/utils'
require_relative './data'
require 'optimist'
require 'rmath3d/rmath3d'

class Feedback
  include Logging
  def initialize(window)
    @window = window
    @name = 'feedback'
  end
end

class Calculate < Feedback
  # this is named 'draw' for consistency,
  # even though it doesn't actually draw anything!
  def draw
    vertex_source = File.join('shaders', @name, 'vertexShader.glsl')
    geometry_source = File.join('shaders', @name, 'geoShader.glsl')
    @shader_program = Utils::ShaderProgram.new
    @shader_program.load_and_attach(:vertex, File.open(vertex_source, 'r', &:read))
    @shader_program.load_and_attach(:geometry, File.open(geometry_source, 'r', &:read))

    varying_ptr = ['outValue'].pack('p')
    glTransformFeedbackVaryings(@shader_program.id, 1, varying_ptr, GL_INTERLEAVED_ATTRIBS)
    @shader_program.link
    @shader_program.use

    @vao = Utils::VertexArray.new
    @vao.bind

    data = [1.0, 2.0, 3.0, 4.0, 5.0]

    @vbo = Utils::VertexBuffer.new
    @vbo.bind
    @vbo.load_buffer(data, :float)
    @shader_program.enable_vertex_attrib('inValue', 1, :float, 0)

    # Create transform buffer
    @tbo = Utils::VertexBuffer.new
    @tbo.bind
    @data_size = @tbo.fiddle_type(:float) * data.length * 3
    glBufferData(GL_ARRAY_BUFFER, @data_size, Utils::NullPtr, GL_STATIC_READ)

    # Throw away the rasterizer, we don't need visual output
    glEnable(GL_RASTERIZER_DISCARD)

    # Create our query buffer
    glBindBufferBase(GL_TRANSFORM_FEEDBACK_BUFFER, 0, @tbo.id)
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenQueries(1, buf)
    query = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]

    # must be done BEFORE transform feedback
    # Other useful queries: GL_PRIMITIVES_GENERATED, GL_TIME_ELAPSED, etc.
    glBeginQuery(GL_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN, query)

    # unique to feedback shaders
    glBeginTransformFeedback(GL_TRIANGLES)

    glDrawArrays(GL_POINTS, 0, 5)

    glEndTransformFeedback()
    # Must stop the query AFTER transform feedback
    glEndQuery(GL_TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN)

    glFlush()
    # get results back
    feedback = Fiddle::Pointer.malloc(Fiddle::SIZEOF_FLOAT * 15)
    glGetBufferSubData(GL_TRANSFORM_FEEDBACK_BUFFER,
                       Utils::NullPtr,
                       (15 * Fiddle::SIZEOF_FLOAT),
                       feedback)
    response = feedback[0, @data_size].unpack('F*')
    response.each { |n| puts n }

    # get query results
    prim_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGetQueryObjectuiv(query, GL_QUERY_RESULT, prim_buf)
    primitives = prim_buf[0, Fiddle::SIZEOF_INT].unpack('L*')[0]
    puts "#{primitives} primitives written!"
  end
end

class Gravity < Feedback
  def initialize(window)
    super(window)
    @previous_frame_time = 0
    @frame_time = 0
  end

  def draw
    @running = true

    vertex_source = File.join('shaders', @name, 'vertexShader_gravity.glsl')
    frag_source = File.join('shaders', @name, 'fragmentShader.glsl')
    @shader_program = Utils::ShaderProgram.new
    @shader_program.load_from(vertex: File.open(vertex_source, 'r', &:read),
                              fragment: File.open(frag_source, 'r', &:read))
    varying_ptr = %w[outPosition outVelocity].pack('p*')

    glTransformFeedbackVaryings(@shader_program.id, 2, varying_ptr, GL_INTERLEAVED_ATTRIBS)
    @shader_program.link
    @shader_program.use

    uniform_time = @shader_program.uniform_location('time')
    uniform_mouse_pos = @shader_program.uniform_location('mousePos')

    @vao = Utils::VertexArray.new
    @vao.bind

    # Vertex format: 6 floats per vertex:
    # pos.x  pox.y  vel.x  vel.y  origPos.x  origPos.y
    @data = Array.new(600) { 0.0 }
    10.times do |y|
      # OPTIMIZE: should probably use .each_cons(4) or .each_slice(4)
      10.times do |x|
        @data[60 * y + 6 * x] = 0.2 * x - 0.9
        @data[60 * y + 6 * x + 1] = 0.2 * y - 0.9
        @data[60 * y + 6 * x + 4] = 0.2 * x - 0.9
        @data[60 * y + 6 * x + 5] = 0.2 * y - 0.9
      end
    end

    @data_size = Fiddle::SIZEOF_FLOAT * @data.length
    @data_ptr = Fiddle::Pointer[@data.pack('F*')]

    @vbo = Utils::VertexBuffer.new
    @vbo.bind
    @vbo.load_buffer(@data, :float, GL_STREAM_DRAW)

    @shader_program.enable_vertex_attrib('position',    2, :float, 6)
    @shader_program.enable_vertex_attrib('velocity',    2, :float, 6, 2)
    @shader_program.enable_vertex_attrib('originalPos', 2, :float, 6, 4)

    # Create transform feedback buffer
    @tbo = Utils::VertexBuffer.new
    @tbo.bind
    glBufferData(GL_ARRAY_BUFFER, Fiddle::SIZEOF_FLOAT * 400, Utils::NullPtr, GL_STATIC_READ)

    # Set the transform feedback buffer as our base
    glBindBufferBase(GL_TRANSFORM_FEEDBACK_BUFFER, 0, @tbo.id)

    # We will receive 400 items back from the feedback (4 items per row * 100 rows)
    @feedback_length = 400
    @feedback_size = Fiddle::SIZEOF_FLOAT * @feedback_length
    @feedback = Fiddle::Pointer.malloc(@feedback_size)
    @vbo.bind

    glPointSize(5.0)

    previous_time = Time.now

    # Set up our variables for tracking the mouse pointer.
    # We also warp the mouse into the window to prevent
    # any initial behavior with nonsense coordinates
    mouse_x = @window.width / 2
    mouse_y = @window.height / 2
    SDL2::Mouse::Cursor.warp(@window.window, mouse_x, mouse_y)

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
      # Render
      glClearColor(0.0, 0.0, 0.0, 1.0)
      glClear(GL_COLOR_BUFFER_BIT)

      now = Time.now
      time = (now - previous_time)
      previous_time = now

      glUniform1f(uniform_time, time)

      # Send updated mouse position to shader
      glUniform2f(uniform_mouse_pos, mouse_x / 400.0 - 1, -mouse_y / 400.0 + 1)

      # Setup a query for rendering details.
      buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGenQueries(1, buf)
      query = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
      glBeginQuery(GL_TIME_ELAPSED, query)

      # Unique to feedback shaders
      glBeginTransformFeedback(GL_POINTS)

      # Draw our gravity-influenced points
      glDrawArrays(GL_POINTS, 0, 100)

      glEndTransformFeedback()
      glEndQuery(GL_TIME_ELAPSED)
      @window.window.gl_swap

      # Get our updated coordinates from the feedback buffer
      glGetBufferSubData(GL_TRANSFORM_FEEDBACK_BUFFER, 0, @feedback_size, @feedback)
      response = @feedback[0, @feedback_size].unpack('F*')

      # each "row" is 4: 100.times {4} = 400
      # OPTIMIZE: should probably use .each_cons(4) or .each_slice(4)
      100.times do |i|
        @data[6 * i] = response[4 * i]
        @data[6 * i + 1] = response[4 * i + 1]
        @data[6 * i + 2] = response[4 * i + 2]
        @data[6 * i + 3] = response[4 * i + 3]
      end

      # glBufferData reallocates the whole vertex data buffer,
      # so we use this call to just update the existing buffer
      glBufferSubData(GL_ARRAY_BUFFER, 0, @data_size, Fiddle::Pointer[@data.pack('F*')])

      # get time elapsed from query
      time_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGetQueryObjectuiv(query, GL_QUERY_RESULT, time_buf)
      time_elapsed = time_buf[0, Fiddle::SIZEOF_INT].unpack('L*')[0]
      frame_average = (time_elapsed + @previous_frame_time) / 2
      @previous_frame_time = @frame_time
      @frame_time = frame_average
    end
    puts "Average per-frame time: #{@frame_time} ns"
  end
end

examples = %w[calculate gravity]

opts = Optimist.options do
  opt :size, 'width X height string', default: '800x600'
  opt :example, "example to run: #{examples.join(', ')}", default: 'calculate'
  opt :verbose, 'say a lot', default: false
end

window_size = Utils.parse_window_size(opts[:size])
Optimist.die('Valid size string is required') unless window_size
Optimist.die('Valid width is required') unless window_size[:width] > 0
Optimist.die('Valid height is required') unless window_size[:height] > 0
Optimist.die("Example must be one of: #{examples}") unless examples.include?(opts[:example])

window = Application.new(window_size[:width],
                         window_size[:height],
                         'feedback',
                         opts[:verbose])

case opts[:example]
when 'calculate'
  Calculate.new(window).draw
when 'gravity'
  Gravity.new(window).draw
end
