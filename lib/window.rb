require 'opengl'
#require 'logger'

require_relative 'utils'

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

  def initialize(width, height, name = "opendotgl_rb", debug = false)
    @debug = debug
    @logger = Logger.new(STDOUT)
    debug ? @logger.level = Logger::DEBUG : @logger.level = Logger::INFO
    original_formatter = Logger::Formatter.new
    @logger.formatter = proc {|severity, datetime, progname, msg| "#{severity} -- #{msg}\n"}

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

    if @debug
      # request debug context
      @logger.info "OpenGL debug context requested"
      SDL2::GL.set_attribute(SDL2::GL::CONTEXT_FLAGS, SDL2::GL::CONTEXT_DEBUG_FLAG)
    end

    @window = SDL2::Window.create(name, 0, 0, width, height, SDL2::Window::Flags::OPENGL)
    @context = SDL2::GL::Context.create(@window)
    #print("SDL2 OpenGL version %d.%d\n",
            #SDL2::GL.get_attribute(SDL2::GL::CONTEXT_MAJOR_VERSION),
            #SDL2::GL.get_attribute(SDL2::GL::CONTEXT_MINOR_VERSION))
    @logger.info {"SDL2 OpenGL version #{SDL2::GL.get_attribute(SDL2::GL::CONTEXT_MAJOR_VERSION)}.#{SDL2::GL.get_attribute(SDL2::GL::CONTEXT_MINOR_VERSION)}"}
    # GLEW/GLEE isn't needed since opengl-bindings gem automatically enumerates all available dynamic functions&constants

    if @debug
      # check if we did get a debug context
      # FIXME need to AND the flags to make sure it's right
      if SDL2::GL.get_attribute(SDL2::GL::CONTEXT_FLAGS) == 1
        @logger.info "OpenGL debug context activated"
        Utils::gl_enable_debug_output
      end
    end

    # force vsync
    SDL2::GL::swap_interval = 1
  end

end
