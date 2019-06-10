require 'logger'
require 'fiddle'
require 'opengl'
require 'sdl2'

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
  extend Logging
  NullPtr = Fiddle::Pointer[0]

  # For use with glDebugMessageCallback
  DEBUG_LOG_SEVERITY = {OpenGL::GL_DEBUG_SEVERITY_HIGH => :high,
              OpenGL::GL_DEBUG_SEVERITY_MEDIUM => :medium,
              OpenGL::GL_DEBUG_SEVERITY_LOW => :low,
              OpenGL::GL_DEBUG_SEVERITY_NOTIFICATION  => :notification}

  DEBUG_LOG_TYPE = {OpenGL::GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR => :deprecated_behavior,
          OpenGL::GL_DEBUG_TYPE_POP_GROUP => :pop_group,
          OpenGL::GL_DEBUG_TYPE_ERROR => :error,
          OpenGL::GL_DEBUG_TYPE_PORTABILITY => :portability,
          OpenGL::GL_DEBUG_TYPE_MARKER => :marker,
          OpenGL::GL_DEBUG_TYPE_PUSH_GROUP => :push_group,
          OpenGL::GL_DEBUG_TYPE_OTHER => :other,
          OpenGL::GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR => :undefined_behavior,
          OpenGL::GL_DEBUG_TYPE_PERFORMANCE => :performance}

  # For use with glGetError
  GL_ERROR_TYPE = {
    OpenGL::GL_NO_ERROR                      => :no_error,
    OpenGL::GL_INVALID_ENUM                  => :invalid_enum,
    OpenGL::GL_INVALID_VALUE                 => :invalid_value,
    OpenGL::GL_INVALID_OPERATION             => :invalid_operation,
    OpenGL::GL_INVALID_FRAMEBUFFER_OPERATION => :invalid_framebuffer_operation,
    OpenGL::GL_OUT_OF_MEMORY                 => :out_of_memory,
    OpenGL::GL_STACK_UNDERFLOW               => :stack_underflow,
    OpenGL::GL_STACK_OVERFLOW                => :stack_overflow,
    OpenGL::GL_CONTEXT_LOST                  => :context_lost }

  # Provided as a fallback in case the platform is too old to use glDebugMessage
  def self.gl_get_one_error
    e = glGetError()
    if e != GL_NO_ERROR
      "glGetError: #{GL_ERROR_TYPE[e.to_i]}, from: #{caller[0]}"
    else
      nil
    end
  end

  def self.gl_get_errors
    e = glGetError()
    while e != GL_NO_ERROR
      logger.error "glGetError: #{GL_ERROR_TYPE[e.to_i]}, from: #{caller.join("\n")}"
    end
  end

  def self.gl_enable_debug_output
    closure = Class.new(Fiddle::Closure) {

      include Logging
      def call(source, type, id, severity, length, message)
        msg = "GL::#{DEBUG_LOG_SEVERITY[severity].to_s}::#{DEBUG_LOG_TYPE[type].to_s} -- #{message}"
        if type == GL_DEBUG_TYPE_ERROR
          logger.error(msg)
        else
          logger.debug(msg)
        end
      end
    }.new(Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_CHAR, Fiddle::TYPE_VOIDP])
    
    glDebugMessageCallback(closure.to_i, NullPtr)
  # TODO this should really rescue Fiddle::DLError, but I don't know if you can!
  rescue RuntimeError # => exception
    logger.warn("glDebugMessageCallback not available on this platform")
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

    Types = {:vertex => OpenGL::GL_VERTEX_SHADER,
             :fragment => OpenGL::GL_FRAGMENT_SHADER,
             :geometry => OpenGL::GL_GEOMETRY_SHADER}

    attr_reader :id
    def initialize(type = :vertex)
      @id = glCreateShader(Types[type])
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

  # TODO should have a overall Shader object keeping track of which ShaderProgram is in use
  class ShaderProgram
    include Logging
    attr_reader :id, :linked #, :in_use
    def initialize
      @id = glCreateProgram()
      @attached = []
      @frag_locations = []
      @linked = false
    end

    def attach(shader)
      glAttachShader(@id, shader.id)
      @attached << shader.id
      shader.id
    end

    def link
      glLinkProgram(@id)
      @linked = true
    end

    def use
      glUseProgram(@id)
    end

    def link_and_use
      link
      use
    end

    def create_from_vert_frag(vertex_shader_source, frag_shader_source)
      vertexShader = Utils::Shader.new(:vertex)
      vertexShader.load(vertex_shader_source)
      fragShader = Utils::Shader.new(:fragment)
      fragShader.load(frag_shader_source)
      attach(vertexShader)
      attach(fragShader)
      link
    end

    # ex: {vertex: <source>, fragment: <source>}
    def load_from(shader_sources)
      shader_sources.each_pair {|k,v| load_and_attach(k, v)}
    end

    def load_and_attach(type, shader_source)
      shader = Utils::Shader.new(type)
      shader.load(shader_source)
      attach(shader)
    end

    def bind_frag(name)
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
        logger.debug "enabling vertex attrib array for '#{name}'(#{enableAttrib}): size: #{size}, type: #{type.to_s}, stride: #{stride}, offset: #{offset}"
        glVertexAttribPointer(enableAttrib, # location
                              size,
                              gl_type(type),
                              GL_FALSE,     # normalized?
                              fiddle_type(type) * stride,
                              # Yes, the offset is weird(an offset void* pointer)
                              # Blame the OpenGL ARB!
                              Utils::NullPtr + fiddle_type(type) * offset # A void* ptr
                             )
        enableAttrib
      else
        logger.info("shader vertex attribute '#{name}' was requested but not found(probably stripped/unused by driver)")
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
        logger.error("fiddle_type: '#{type_name}' does not match a Fiddle::SIZEOF_ constant")
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
      glTexImage2D(GL_TEXTURE_2D, 0, mode, image.w, image.h, 0, mode, GL_UNSIGNED_BYTE, image_ptr)
      image.destroy
      # TODO do I need to reset glActiveTexture back to 0 ?
      @slots << name
      slot_for(name)
    end

    def create(name, width, height)
      if @slots.length == MAX_UNITS
        logger.error "can't load any more textures(#{slots.length})"
        return
      end
      slot = @slots.length
      tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGenTextures(1, tex_buf)
      tex_slot = tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
      logger.debug {"creating #{name} (#{width}x#{height}) texture in buffer #{tex_slot}, unit GL_TEXTURE#{slot}"}
      glBindTexture(GL_TEXTURE_2D, tex_slot)

      # TODO generify
      glTexImage2D(GL_TEXTURE_2D,
                   0,
                   GL_RGB,
                   800, 600,
                   0,
                   GL_RGB,
                   GL_UNSIGNED_BYTE,
                   NullPtr)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
      @slots << name
      slot_for(name)
    end

    def slot_for(name)
      # Returns the texture unit(GL_TEXTURE<n>) handle as an int
      @slots.index(name)
    end

    def bind(name, type=GL_TEXTURE_2D)
      glBindTexture(type, slot_for(name))
    end

    def activate(name)
      glActiveTexture(Object.const_get("GL_TEXTURE#{slot_for(name)}"))
    end

    def activate_and_bind(name)
      activate(name)
      bind(name)
    end
  end

  class Texture
    attr_reader :id
    Types = [OpenGL::GL_TEXTURE_1D, OpenGL::GL_TEXTURE_2D]
    def initialize(type)
      tex_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGenTextures(1, tex_buf)
      @id = tex_buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
      if Types.include?(type)
        @type = type
      else
        raise ArgumentError "#{type} is not valid"
      end
    end

    def bind
      glBindTexture(@type, @id)
    end
    def create(width, height)
      glTexImage2D(GL_TEXTURE_2D,
                   0,
                   GL_RGB,
                   width,
                   height,
                   0,
                   GL_RGB,
                   GL_UNSIGNED_BYTE,
                   Utils::NullPtr)
    end

    # FIXME better names
    def texParameter(set, value)
      glTexParameteri(@type, set, value)
    end
  end

  class VertexArray
    include Logging
    attr_reader :id

    def initialize
      buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGenVertexArrays(1, buf)
      @id = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    end

    def bind
      glBindVertexArray(@id)
    end

  end

  class VertexBuffer
    include Logging
    attr_reader :id, :loaded

    def initialize
      buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGenBuffers(1, buf)
      @id = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    end

    # FIXME it'd be nice to have this as a module-method, but Logging doesn't then work
    def fiddle_type(type_name)
      Object.const_get("Fiddle::SIZEOF_#{type_name.to_s.upcase}")
    end

    def bind
      glBindBuffer(GL_ARRAY_BUFFER, @id)
    end

    # type is a symbol: :float, :int, etc.
    def load_buffer(data, type, mode=GL_STATIC_DRAW)
      # FIXME pack command should vary by type
      data_ptr = Fiddle::Pointer[data.flatten.pack("F*")]
      data_size = fiddle_type(type) * data.flatten.length
      glBufferData(GL_ARRAY_BUFFER, data_size, data_ptr, mode)
      @loaded = true
    end

    # For transform buffers
    def set_read_buffer(type, size)
      data_size = fiddle_type(type) * size
      glBufferData(GL_ARRAY_BUFFER, data_size, Utils::NullPtr, GL_STATIC_READ)
    end
  end

  class FrameBuffer
    include Logging
    attr_reader :id
    StatusValues = {OpenGL::GL_FRAMEBUFFER_COMPLETE => :complete,
              OpenGL::GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT => :incomplete_attachment,
              OpenGL::GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT => :incomplete_missing_attachment,
              OpenGL::GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER => :incomplete_draw_buffer,
              OpenGL::GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER => :incomplete_read_buffer,
              OpenGL::GL_FRAMEBUFFER_UNSUPPORTED => :unsupported}

    def initialize
      buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGenFramebuffers(1, buf)
      @id = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
      logger.debug status
    end

    def bind
      glBindFramebuffer(GL_FRAMEBUFFER, @id)
    end

    def status
      StatusValues[glCheckFramebufferStatus(GL_FRAMEBUFFER)]
    end

    def complete?
      status == :complete ? true : false
    end

    def texture2D(texBuffer)
      # TODO need a slot list at some point
      glFramebufferTexture2D(
          GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texBuffer, 0
      )

    end
  end

  class RenderBuffer
    include Logging
    attr_reader :id, :bound

    def initialize
      buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      glGenRenderbuffers(1, buf)
      @id = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]
    end

    def bind
      glBindRenderbuffer(GL_RENDERBUFFER, @id)
    end

    def set_storage(type, width, height)
      glRenderbufferStorage(GL_RENDERBUFFER, type, width, height);
    end

    def set_framebuffer(type)
      glFramebufferRenderbuffer(GL_FRAMEBUFFER, type, GL_RENDERBUFFER, @id)
    end
  end
end
