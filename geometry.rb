require_relative './lib/window'
require_relative './lib/utils'
require_relative './data'
require 'rmath3d/rmath3d'

class Geometry
  include Logging
  def initialize(window)
    @window = window
    @name = 'geometry'
    vertex_source = File.join('shaders', @name, 'vertexShader.glsl')
    frag_source = File.join('shaders', @name, 'fragShader.glsl')
    geometry_source = File.join('shaders', @name, 'geometryShader.glsl')

    @shaderProgram = Utils::ShaderProgram.new
    @shaderProgram.load_and_attach(:vertex, File.open(vertex_source, 'r', &:read))
    @shaderProgram.load_and_attach(:fragment, File.open(frag_source, 'r', &:read))
    @shaderProgram.load_and_attach(:geometry, File.open(geometry_source, 'r', &:read))
    @shaderProgram.link
    @shaderProgram.use

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
    @shaderProgram.enable_vertex_attrib('pos', 2, :float, 6)
    # Color is the next three items
    @shaderProgram.enable_vertex_attrib('color', 3, :float, 6, 2)
    # Sides-per-object is the last item
    @shaderProgram.enable_vertex_attrib('sides', 1, :float, 6, 5)
  end

  def draw
    @running = true
    @shaderProgram.use
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
      glClearColor(0.0, 0.0, 0.0, 1.0);
      glClear(GL_COLOR_BUFFER_BIT);
      glDrawArrays(GL_POINTS, 0, 4);
      @window.window.gl_swap
    end
  end
end

window = Window.new(800, 600, 'geometry') #, true)
Geometry.new(window).draw
