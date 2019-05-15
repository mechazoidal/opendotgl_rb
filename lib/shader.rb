require_relative 'utils'
require 'opengl'
include OpenGL

class Shader

  attr_reader :program_id

  def initialize
    @program_id = glCreateProgram()
  end

  def compile( type, code )
    shader_id = glCreateShader( type )
    srcs = [code].pack('p')
    lens = [code.length].pack('I')
    glShaderSource( shader_id, 1, srcs, lens )
    glCompileShader( shader_id )

    result_buf = '    '
    glGetShaderiv( shader_id, GL_COMPILE_STATUS, result_buf )
    result = result_buf.unpack('L')[0] # GLint

    if result == GL_FALSE
      log_length_buf = '    '
      glGetShaderiv( shader_id, GL_INFO_LOG_LENGTH, log_length_buf )
      log_length = log_length_buf.unpack('L')[0]
      log = ' ' * log_length
      glGetShaderInfoLog( shader_id, log_length, nil, log )
      puts log
      return -1
    end

    return shader_id
  end
  private :compile

  def load( vertex_code: nil, fragment_code: nil )
    shader_ids = []

    # Compile each shader
    if vertex_code != nil
      id = compile( GL_VERTEX_SHADER, vertex_code )
      shader_ids << id
    end
    if fragment_code != nil
      id = compile( GL_FRAGMENT_SHADER, fragment_code )
      shader_ids << id
    end

    # Link shaders into one program
    shader_ids.each do |shader_id|
      glAttachShader( @program_id, shader_id )
    end

    # added
    glBindFragDataLocation(@program_id, 0, "outColor")

    glLinkProgram( @program_id )

    result_buf = '    '
    glGetProgramiv( @program_id, GL_LINK_STATUS, result_buf )
    result = result_buf.unpack('L')[0] # GLint

    if result == GL_FALSE
      log_length_buf = '    '
      glGetProgramiv( @program_id, GL_INFO_LOG_LENGTH, log_length_buf )
      log_length = log_length_buf.unpack('L')[0]
      log = ' ' * log_length
      glGetProgramInfoLog( @program_id, log_length, nil, log )
      puts log
      return -1
    end

    shader_ids.each do |shader_id|
      glDeleteShader( shader_id )
    end
    return @program_id
  end

  def delete
    glDeleteProgram( @program_id )
  end

  def use
    glUseProgram( @program_id )
  end

  def unuse
    glUseProgram( 0 )
  end

  def location( name )
    return glGetUniformLocation( @program_id, name )
  end

  def set_uniform( name, *args )
    loc = location(name)
    if loc < 0 # optimized out or misspell. Ref.: http://www.opengl.org/wiki/GLSL_:_common_mistakes
      print "Shader#set_uniform : Location for \"#{name}\" not found. Arg0 Class:#{args[0].class}, Length:#{args.length}\n"
      # return
    end
    case args[0]
    when Fixnum
      case args.length
      when 1; glUniform1i(loc, args[0])
      when 2; glUniform2i(loc, args[0], args[1])
      when 3; glUniform3i(loc, args[0], args[1], args[2])
      when 4; glUniform4i(loc, args[0], args[1], args[2], args[3])
      end
    when Float
      case args.length
      when 1; glUniform1f(loc, args[0])
      when 2; glUniform2f(loc, args[0], args[1])
      when 3; glUniform3f(loc, args[0], args[1], args[2])
      when 4; glUniform4f(loc, args[0], args[1], args[2], args[3])
      end
    when RVec3; glUniform3f(loc, args[0].x, args[0].y, args[0].z)
    when RVec4; glUniform4f(loc, args[0].x, args[0].y, args[0].z, args[0].w)
    when RMtx3; glUniformMatrix3fv(loc, 1, GL_FALSE, args[0].to_a.pack('F*'))
    when RMtx4; glUniformMatrix4fv(loc, 1, GL_FALSE, args[0].to_a.pack('F*'))
    end
  end

  def get_attribute_location(name)
    glGetAttribLocation(program_id, name)
  end
  def enable_attribute(location)
    glEnableVertexAttribArray(location)
  end
  def vertex_pointer(name, size, stride, offset)
    offset > 0 ? ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_FLOAT * offset) : ptr = Fiddle::Pointer[0]
    attr = get_attribute_location(name)
    enable_attribute(attr)
    puts "#{name} location: #{attr}"

    glVertexAttribPointer(attr, size, GL_FLOAT, GL_FALSE, Fiddle::SIZEOF_FLOAT * stride, ptr)
    ptr
  end
end
