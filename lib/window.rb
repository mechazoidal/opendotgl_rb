require 'opengl'
require 'logger'

require_relative 'utils'

NullPtr = Fiddle::Pointer[0]
include OpenGL
case OpenGL.get_platform
when :OPENGL_PLATFORM_WINDOWS
  OpenGL.load_lib('opengl32.dll', 'C:/Windows/System32')
when :OPENGL_PLATFORM_MACOSX
  OpenGL.load_lib('libGL.dylib', '/System/Library/Frameworks/OpenGL.framework/Libraries')
when :OPENGL_PLATFORM_LINUX
  OpenGL.load_lib()
else
  raise RuntimeError, "Unsupported platform."
end

require 'sdl2'

class Window
  include Logging
  attr_reader :window
  def initialize(width, height)
    @running = false
    SDL2.init(SDL2::INIT_VIDEO)
    SDL2::GL.set_attribute(SDL2::GL::RED_SIZE, 8)
    SDL2::GL.set_attribute(SDL2::GL::GREEN_SIZE, 8)
    SDL2::GL.set_attribute(SDL2::GL::BLUE_SIZE, 8)
    SDL2::GL.set_attribute(SDL2::GL::ALPHA_SIZE, 8)
    SDL2::GL.set_attribute(SDL2::GL::DOUBLEBUFFER, 1)


    # forward-compatible OpenGL 3.2 context
    SDL2::GL.set_attribute(SDL2::GL::CONTEXT_PROFILE_MASK, SDL2::GL::CONTEXT_PROFILE_CORE)
    SDL2::GL.set_attribute(SDL2::GL::CONTEXT_MAJOR_VERSION, 3)
    SDL2::GL.set_attribute(SDL2::GL::CONTEXT_MINOR_VERSION, 2)
    SDL2::GL.set_attribute(SDL2::GL::STENCIL_SIZE, 8)
    # debug context
    SDL2::GL.set_attribute(SDL2::GL::CONTEXT_FLAGS, SDL2::GL::CONTEXT_DEBUG_FLAG)
    @window = SDL2::Window.create("modeler", 0, 0, width, height, SDL2::Window::Flags::OPENGL)
    @context = SDL2::GL::Context.create(@window)
    printf("OpenGL version %d.%d\n",
            SDL2::GL.get_attribute(SDL2::GL::CONTEXT_MAJOR_VERSION),
            SDL2::GL.get_attribute(SDL2::GL::CONTEXT_MINOR_VERSION))
    # GLEW/GLEE isn't needed since opengl-bindings gem automatically enumerates all dynamic functions/constants
    
    # check if we did get a debug context
    # FIXME need to AND the flags to make sure it's right
    puts SDL2::GL.get_attribute(SDL2::GL::CONTEXT_FLAGS)

    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG

    glEnable(GL_DEBUG_OUTPUT)
    closure = Class.new(Fiddle::Closure) { 
      def call(source, type, id, severity, length, message)
        # TODO it'd be nice to send this straight to a logger
        #type == GL_DEBUG_TYPE_ERROR ? @logger.error(message) : @logger.debug(message)
        puts "GL CALLBACK: #{type == GL_DEBUG_TYPE_ERROR ? "** GL ERROR **" : ""} type = #{type}, severity = #{severity}, message = #{message}"
      end
    }.new(Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_CHAR, Fiddle::TYPE_VOIDP])

    glDebugMessageCallback(closure.to_i, NullPtr)

    # force vsync
    SDL2::GL::swap_interval = 1
  end

end
