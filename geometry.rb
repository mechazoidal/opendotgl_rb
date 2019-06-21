require_relative './lib/application'
require_relative './lib/utils'
require_relative './data'
require 'optimist'
require 'rmath3d/rmath3d'

class Geometry
  include Logging
  def initialize(window)
    @window = window
    @name = 'geometry'
    vertex_source = File.join('shaders', @name, 'vertexShader.glsl')
    frag_source = File.join('shaders', @name, 'fragShader.glsl')
    geometry_source = File.join('shaders', @name, 'geometryShader.glsl')

    @shader_program = Utils::ShaderProgram.new
    @shader_program.load_and_attach(:vertex, File.open(vertex_source, 'r', &:read))
    @shader_program.load_and_attach(:fragment, File.open(frag_source, 'r', &:read))
    @shader_program.load_and_attach(:geometry, File.open(geometry_source, 'r', &:read))
    @shader_program.link
    @shader_program.use

    @vbo = Utils::VertexBuffer.new
    points = [
      # Red point
      [-0.45,  0.45, 1.0, 0.0, 0.0, 4.0],
      # Green point
      [ 0.45,  0.45, 0.0, 1.0, 0.0, 8.0],
      # Blue point
      [ 0.45, -0.45, 0.0, 0.0, 1.0, 16.0],
      # Yellow point
      [-0.45, -0.45, 1.0, 1.0, 0.0, 32.0]
    ]

    @vbo.bind
    @vbo.load_buffer(points, :float)

    @vao = Utils::VertexArray.new
    @vao.bind
    # specify layout of point data:
    # The position is the first two items
    @shader_program.enable_vertex_attrib('pos', 2, :float, 6)
    # Color is the next three items
    @shader_program.enable_vertex_attrib('color', 3, :float, 6, 2)
    # Sides-per-object is the last item
    @shader_program.enable_vertex_attrib('sides', 1, :float, 6, 5)
  end

  def draw
    @running = true
    @shader_program.use
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
      glDrawArrays(GL_POINTS, 0, 4)
      @window.window.gl_swap
    end
  end
end

opts = Optimist.options do
  opt :size, 'width X height string', default: '800x600'
  opt :verbose, 'say a lot', default: false
end
window_size = Utils.parse_window_size(opts[:size])
Optimist.die('Valid size string is required') unless window_size
Optimist.die('Valid width is required') unless window_size[:width] > 0
Optimist.die('Valid height is required') unless window_size[:height] > 0

window = Application.new(window_size[:width],
                         window_size[:height],
                         'geometry',
                         opts[:verbose])
Geometry.new(window).draw
