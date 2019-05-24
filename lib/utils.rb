require 'logger'
require 'fiddle'
require 'opengl'

# https://stackoverflow.com/questions/917566/ruby-share-logger-instance-among-module-classes
module Logging
  # This is the magical bit that gets mixed into your classes
  def logger
    Logging.logger
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
end

module Utils
  NullPtr = Fiddle::Pointer[0]
  SEVERITY = {OpenGL::GL_DEBUG_SEVERITY_HIGH => :high,
              OpenGL::GL_DEBUG_SEVERITY_MEDIUM => :medium,
              OpenGL::GL_DEBUG_SEVERITY_LOW => :low,
              OpenGL::GL_DEBUG_SEVERITY_NOTIFICATION  => :notification}

  TYPE = {OpenGL::GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR => :deprecated_behavior,
          OpenGL::GL_DEBUG_TYPE_POP_GROUP => :pop_group,
          OpenGL::GL_DEBUG_TYPE_ERROR => :error,
          OpenGL::GL_DEBUG_TYPE_PORTABILITY => :portability,
          OpenGL::GL_DEBUG_TYPE_MARKER => :marker,
          OpenGL::GL_DEBUG_TYPE_PUSH_GROUP => :push_group,
          OpenGL::GL_DEBUG_TYPE_OTHER => :other,
          OpenGL::GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR => :undefined_behavior,
          OpenGL::GL_DEBUG_TYPE_PERFORMANCE => :performance}

  def self.check_errors( desc )
    include Logging
    e = glGetError()
    if e != GL_NO_ERROR
      logger.error sprintf "glGetError: \"#{desc}\", code=0x%08x\n", e.to_i
      exit
    end
  end

  def self.gl_enable_debug_output

    closure = Class.new(Fiddle::Closure) {

      include Logging
      def call(source, type, id, severity, length, message)
        msg = "GL::#{SEVERITY[severity].to_s}::#{TYPE[type].to_s} -- #{message}"
        if type == GL_DEBUG_TYPE_ERROR
          logger.error(msg)
        else
          logger.debug(msg)
        end
      end
    }.new(Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_CHAR, Fiddle::TYPE_VOIDP])

    glDebugMessageCallback(closure.to_i, NullPtr)
  end

  class Shader
    include Logging

    attr_reader :id
    def initialize(type = "GL_VERTEX_SHADER")
      @id = glCreateShader(type)
    end

    def load(source)
      status = GL_FALSE
      src = [source].pack('p')
      length = [source.length].pack('I')
      glShaderSource(@id, 1, src, length)
      glCompileShader(@id)
      # make sure it compiled
      result_buf = ' ' * 4
      glGetShaderiv(@id, GL_COMPILE_STATUS, result_buf);
      status = result_buf.unpack('L')[0] # GLint
      if status == GL_FALSE
        logger.error "Failed to compile shader"
        log_buffer = ' ' * 4
        glGetShaderiv(@id, GL_COMPILE_STATUS, log_buffer);
        log_length = log_buffer.unpack('L')[0]
        log = ' ' * log_length
        glGetShaderInfoLog(@id, log_length, Fiddle::Pointer[0], log)
        # TODO if we're in a debug context, we may not get output here and it may have gone straight to debug console
        logger.error log
      end
      status == GL_TRUE ? true : false
    end
  end
end
