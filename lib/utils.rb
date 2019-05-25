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



  module RadianHelper
    refine Float do
      def to_rad
        self / 180.0 * Math::PI
      end
    end
  end

  class Shader
    include Logging

    #AttribTypes = {float: {gl: GL_FLOAT, pointer: Fiddle::SIZEOF_FLOAT}
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

  class ShaderProgram
    include Logging
    attr_reader :id, :linked, :in_use
    def initialize
      @id = glCreateProgram()
      @attached = []
      @frag_locations = []
      @linked = false
      @in_use = false
    end

    def attach(shader)
      glAttachShader(@id, shader.id)
      @attached << shader.id
      shader.id
    end

    def link_and_use
      glLinkProgram(@id)
      @linked = true
      glUseProgram(@id)
      @in_use = true
      #true
    end

    def bind(name)
      slot = @frag_locations.length
      glBindFragDataLocation(@id, slot, name)
      @frag_locations << name
      slot
    end

    # TODO should probably take hash args
    def enable_vertex_attrib(name, size, type, stride, offset=0)
      enableAttrib = glGetAttribLocation(@id, name)
      if enableAttrib != -1
        glEnableVertexAttribArray(enableAttrib)
        logger.debug "enabling vertex attrib array for #{name}(#{enableAttrib}): size: #{size}, type: #{type.to_s}, stride: #{stride}, offset: #{offset}" 
        glVertexAttribPointer(enableAttrib, # location
                              size,
                              gl_type(type),
                              GL_FALSE,     # normalized?
                              fiddle_type(type) * stride,
                              # Yes, the offset is weird(an offset void* pointer)
                              # Blame the OpenGL ARB
                              Utils::NullPtr + fiddle_type(type) * offset # A void* ptr
                             )
        enableAttrib
      else
        logger.debug("shader vertex attribute '#{name}' was requested but not found(probably stripped/unused")
        nil
      end
    end

    def uniform_location(name)
      glGetUniformLocation(@id, name)

    end
    def gl_type(type_name)
      begin
        Object.const_get("GL_#{type_name.to_s.upcase}")
      rescue NameError
        logger.info("gl_type: '#{type_name}' does not match a GL_ constant")
        return nil
      end
    end

    def fiddle_type(type_name)
      begin
        Object.const_get("Fiddle::SIZEOF_#{type_name.to_s.upcase}")
      rescue NameError
        logger.info("fiddle_type: '#{type_name}' does not match a Fiddle::SIZEOF_ constant")
        return nil
      end
    end
  end

  class Textures
    # Holds texture buffer pointers
    # @slots: count is GL_TEXTURE<n>, value is requested name
    include Logging
    attr_reader :slots
    # FIXME this is just from _my_ system, not sure if there's a set limit of GL_TEXTURE<n> units
    # this _should_ be 48 by the Opengl 3 standard, but it is driver-specific(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS - 1)
    MAX_UNITS = 31
    def initialize
      @slots = []
      # TODO maybe hold an array of hashes:
      # array count is texture unit (0-based)
      # hash is: name, opengl buffer handle
      # [{name: texMoon, buffer: 1}, {name: texEarth, buffer: 2}]
    end

    def load(filename, name)
      if @slots.length == MAX_UNITS
        logger.error "can't load any more textures(#{slots.length})"
        return
      end
      slot = @slots.length

      tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGenTextures(1, tex_buf)
      tex_slot = tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
      # TODO not really sure if I need this call to activeTexture?
      glActiveTexture(Object.const_get("GL_TEXTURE#{slot}"))
      logger.debug {"load_texture: loading #{filename} to name #{name} to buffer #{tex_slot}, unit GL_TEXTURE#{slot}"}
      glBindTexture(GL_TEXTURE_2D, tex_slot)

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
      glTexImage2D(GL_TEXTURE_2D, 0, mode, image.w, image.h, 0, GL_RGB, GL_UNSIGNED_BYTE, image_ptr)
      image.destroy
      # TODO do I need to reset glActiveTexture back to 0 ?
      slots << name
    end

    def slot_for(name)
      # Returns the texture unit(GL_TEXTURE<n>) handle as an int
      @slots.index(name)
    end
  end
end
