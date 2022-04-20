const std = @import("std");

//
// Datatypes
//

pub const GLenum = c_uint;
pub const GLboolean = u8;
pub const GLbitfield = c_uint;
pub const GLvoid = anyopaque;
pub const GLbyte = i8; // 1-byte signed
pub const GLshort = c_short; // 2-byte signed
pub const GLint = c_int; // 4-byte signed
pub const GLubyte = u8; // 1-byte unsigned
pub const GLushort = c_ushort; // 2-byte unsigned
pub const GLuint = c_uint; // 4-byte unsigned
pub const GLsizei = c_int; // 4-byte signed
pub const GLfloat = f32; // single precision float
pub const GLclampf = f32; // single precision float in [0,1]
pub const GLdouble = f64; // double precision float
pub const GLclampd = f64; // double precision float in [0,1]
pub const GLchar = u8;
pub const GLsizeiptr = c_long;
pub const GLintptr = c_long;

//
// Constants
//

// Boolean values
pub const GL_FALSE = 0;
pub const GL_TRUE = 1;

// Data types
pub const GL_UNSIGNED_BYTE = 0x1401;
pub const GL_FLOAT = 0x1406;

// Primitives
pub const GL_TRIANGLES = 0x0004;
pub const GL_TRIANGLE_STRIP = 0x0005;
pub const GL_TRIANGLE_FAN = 0x0006;

// Polygons
pub const GL_CW = 0x0900;
pub const GL_CCW = 0x0901;
pub const GL_FRONT = 0x0404;
pub const GL_BACK = 0x0405;
pub const GL_CULL_FACE = 0x0B44;

// Depth buffer
pub const GL_EQUAL = 0x0202;
pub const GL_NOTEQUAL = 0x0205;
pub const GL_ALWAYS = 0x0207;
pub const GL_DEPTH_TEST = 0x0B71;

// Blending
pub const GL_BLEND = 0x0BE2;
pub const GL_BLEND_SRC = 0x0BE1;
pub const GL_BLEND_DST = 0x0BE0;
pub const GL_ZERO = 0;
pub const GL_ONE = 1;
pub const GL_SRC_COLOR = 0x0300;
pub const GL_ONE_MINUS_SRC_COLOR = 0x0301;
pub const GL_SRC_ALPHA = 0x0302;
pub const GL_ONE_MINUS_SRC_ALPHA = 0x0303;
pub const GL_DST_ALPHA = 0x0304;
pub const GL_ONE_MINUS_DST_ALPHA = 0x0305;
pub const GL_DST_COLOR = 0x0306;
pub const GL_ONE_MINUS_DST_COLOR = 0x0307;
pub const GL_SRC_ALPHA_SATURATE = 0x0308;

// Texture mapping
pub const GL_TEXTURE_2D = 0x0DE1;
pub const GL_TEXTURE_WRAP_S = 0x2802;
pub const GL_TEXTURE_WRAP_T = 0x2803;
pub const GL_TEXTURE_MAG_FILTER = 0x2800;
pub const GL_TEXTURE_MIN_FILTER = 0x2801;

// Errors
pub const GL_NO_ERROR = 0;
pub const GL_INVALID_ENUM = 0x0500;
pub const GL_INVALID_VALUE = 0x0501;
pub const GL_INVALID_OPERATION = 0x0502;
pub const GL_STACK_OVERFLOW = 0x0503;
pub const GL_STACK_UNDERFLOW = 0x0504;
pub const GL_OUT_OF_MEMORY = 0x0505;

// glPush/PopAttrib bits
pub const GL_DEPTH_BUFFER_BIT = 0x00000100;
pub const GL_STENCIL_BUFFER_BIT = 0x00000400;
pub const GL_COLOR_BUFFER_BIT = 0x00004000;

// Stencil
pub const GL_STENCIL_TEST = 0x0B90;
pub const GL_KEEP = 0x1E00;
pub const GL_REPLACE = 0x1E01;
pub const GL_INCR = 0x1E02;
pub const GL_DECR = 0x1E03;

// Buffers, Pixel Drawing/Reading
pub const GL_LUMINANCE = 0x1909;
pub const GL_RGBA = 0x1908;

// Scissor box
pub const GL_SCISSOR_TEST = 0x0C11;

// Texture mapping
pub const GL_NEAREST_MIPMAP_NEAREST = 0x2700;
pub const GL_NEAREST_MIPMAP_LINEAR = 0x2702;
pub const GL_LINEAR_MIPMAP_NEAREST = 0x2701;
pub const GL_LINEAR_MIPMAP_LINEAR = 0x2703;
pub const GL_NEAREST = 0x2600;
pub const GL_LINEAR = 0x2601;
pub const GL_REPEAT = 0x2901;

// OpenGL 1.2
pub const GL_CLAMP_TO_EDGE = 0x812F;

// OpenGL 1.3
pub const GL_TEXTURE0 = 0x84C0;

// OpenGL 1.4
pub const GL_ARRAY_BUFFER = 0x8892;
pub const GL_STREAM_DRAW = 0x88E0;
pub const GL_INCR_WRAP = 0x8507;
pub const GL_DECR_WRAP = 0x8508;

// OpenGL 2.0
pub const GL_FRAGMENT_SHADER = 0x8B30;
pub const GL_VERTEX_SHADER = 0x8B31;
pub const GL_COMPILE_STATUS = 0x8B81;
pub const GL_LINK_STATUS = 0x8B82;

//
// Miscellaneous
//

pub extern fn glClearColor(red: GLclampf, green: GLclampf, blue: GLclampf, alpha: GLclampf) void;
pub extern fn glClear(mask: GLbitfield) void;
pub extern fn glColorMask(red: GLboolean, green: GLboolean, blue: GLboolean, alpha: GLboolean) void;
pub extern fn glCullFace(mode: GLenum) void;
pub extern fn glFrontFace(mode: GLenum) void;
pub extern fn glEnable(cap: GLenum) void;
pub extern fn glDisable(cap: GLenum) void;
pub extern fn glGetError() GLenum;
pub extern fn glReadPixels(x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, type: GLenum, data: ?*anyopaque) void;

//
// Transformation
//

pub extern fn glViewport(x: GLint, y: GLint, width: GLsizei, height: GLsizei) void;

//
// Stenciling
//

pub extern fn glStencilFunc(func: GLenum, ref: GLint, mask: GLuint) void;
pub extern fn glStencilMask(mask: GLuint) void;
pub extern fn glStencilOp(fail: GLenum, zfail: GLenum, zpass: GLenum) void;

//
// Extensions
//

pub extern fn glDrawArrays(mode: GLenum, first: GLint, count: GLsizei) void;

pub extern fn glTexImage2D(target: GLenum, level: GLint, internalFormat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, @"type": GLenum, pixels: ?*const GLvoid) void;
pub extern fn glTexSubImage2D(target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, @"type": GLenum, pixels: ?*const GLvoid) void;
pub extern fn glGenTextures(n: GLsizei, textures: [*c]GLuint) void;
pub extern fn glDeleteTextures(n: GLsizei, textures: [*c]const GLuint) void;
pub extern fn glBindTexture(target: GLenum, texture: GLuint) void;
pub extern fn glTexParameteri(target: GLenum, pname: GLenum, param: GLint) void;
pub extern fn glGenerateMipmap(target: GLenum) void;

pub extern fn glActiveTexture(texture: GLenum) void;

pub extern fn glStencilOpSeparate(face: GLenum, sfail: GLenum, dpfail: GLenum, dppass: GLenum) void;
pub extern fn glBlendFuncSeparate(sfactorRGB: GLenum, dfactorRGB: GLenum, sfactorAlpha: GLenum, dfactorAlpha: GLenum) void;

pub extern fn glBindBuffer(target: GLenum, buffer: GLuint) void;
pub extern fn glDeleteBuffers(n: GLsizei, buffers: [*c]const GLuint) void;
pub extern fn glGenBuffers(n: GLsizei, buffers: [*c]GLuint) void;
pub extern fn glBufferData(target: GLenum, size: GLsizeiptr, data: ?*const anyopaque, usage: GLenum) void;
pub extern fn glBufferSubData(target: GLenum, offset: GLintptr, size: GLsizeiptr, data: ?*const anyopaque) void;

pub extern fn glAttachShader(program: GLuint, shader: GLuint) void;
extern fn jsBindAttribLocation(program: GLuint, index: GLuint, name: [*c]const GLchar, nameLen: usize) void;
pub fn glBindAttribLocation(program: GLuint, index: GLuint, name: [*c]const GLchar) void {
    jsBindAttribLocation(program, index, name, std.mem.sliceTo(name, 0).len);
}
pub extern fn glCompileShader(shader: GLuint) void;
pub extern fn glCreateProgram() GLuint;
pub extern fn glCreateShader(@"type": GLenum) GLuint;
pub extern fn glDeleteProgram(program: GLuint) void;
pub extern fn glDeleteShader(shader: GLuint) void;
pub extern fn glDisableVertexAttribArray(index: GLuint) void;
pub extern fn glEnableVertexAttribArray(index: GLuint) void;
pub extern fn glGetProgramiv(program: GLuint, pname: GLenum, params: [*c]GLint) void;
pub extern fn glGetProgramInfoLog(program: GLuint, bufSize: GLsizei, length: [*c]GLsizei, infoLog: [*c]GLchar) void;
pub extern fn glGetShaderiv(shader: GLuint, pname: GLenum, params: [*c]GLint) void;
pub extern fn glGetShaderInfoLog(shader: GLuint, bufSize: GLsizei, length: [*c]GLsizei, infoLog: [*c]GLchar) void;
pub extern fn glLinkProgram(program: GLuint) void;
pub extern fn glShaderSource(shader: GLuint, count: GLsizei, [*c]const [*c]const GLchar, length: [*c]const GLint) void;
extern fn jsGetUniformLocation(program: GLuint, name: [*c]const GLchar, nameLen: usize) GLint;
pub fn glGetUniformLocation(program: GLuint, name: [*c]const GLchar) GLint {
    return jsGetUniformLocation(program, name, std.mem.sliceTo(name, 0).len);
}
pub extern fn glUseProgram(program: GLuint) void;
pub extern fn glUniform1i(location: GLint, v0: GLint) void;
pub extern fn glUniform2fv(location: GLint, count: GLsizei, value: [*c]const GLfloat) void;
pub extern fn glUniform4fv(location: GLint, count: GLsizei, value: [*c]const GLfloat) void;
pub extern fn glVertexAttribPointer(index: GLuint, size: GLint, @"type": GLenum, normalized: GLboolean, stride: GLsizei, pointer: ?*const anyopaque) void;
