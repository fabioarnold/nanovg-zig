let webgl2Supported = (typeof WebGL2RenderingContext !== 'undefined');
let webgl_fallback = false;
let gl;

let webglOptions = {
  alpha: true, //Boolean that indicates if the canvas contains an alpha buffer.
  antialias: true,  //Boolean that indicates whether or not to perform anti-aliasing.
  depth: 32,  //Boolean that indicates that the drawing buffer has a depth buffer of at least 16 bits.
  failIfMajorPerformanceCaveat: false,  //Boolean that indicates if a context will be created if the system performance is low.
  powerPreference: "default", //A hint to the user agent indicating what configuration of GPU is suitable for the WebGL context. Possible values are:
  premultipliedAlpha: true,  //Boolean that indicates that the page compositor will assume the drawing buffer contains colors with pre-multiplied alpha.
  preserveDrawingBuffer: true,  //If the value is true the buffers will not be cleared and will preserve their values until cleared or overwritten by the author.
  stencil: true, //Boolean that indicates that the drawing buffer has a stencil buffer of at least 8 bits.
}

if (webgl2Supported) {
  gl = $canvasgl.getContext('webgl2', webglOptions);
  if (!gl) {
    throw new Error('The browser supports WebGL2, but initialization failed.');
  }
}
if (!gl) {
  webgl_fallback = true;
  gl = $canvasgl.getContext('webgl', webglOptions);

  if (!gl) {
    throw new Error('The browser does not support WebGL');
  }

  let vaoExt = gl.getExtension("OES_vertex_array_object");
  if (!vaoExt) {
    throw new Error('The browser supports WebGL, but not the OES_vertex_array_object extension');
  }
  gl.createVertexArray = vaoExt.createVertexArrayOES,
    gl.deleteVertexArray = vaoExt.deleteVertexArrayOES,
    gl.isVertexArray = vaoExt.isVertexArrayOES,
    gl.bindVertexArray = vaoExt.bindVertexArrayOES,
    gl.createVertexArray = vaoExt.createVertexArrayOES;
}
if (!gl) {
  throw new Error('The browser supports WebGL, but initialization failed.');
}

const glShaders = [];
const glPrograms = [];
const glVertexArrays = [];
const glBuffers = [];
const glTextures = [];
const glUniformLocations = [];

const glInitShader = (sourcePtr, sourceLen, type) => {
  const source = readCharStr(sourcePtr, sourceLen);
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw "Error compiling shader:" + gl.getShaderInfoLog(shader);
  }
  glShaders.push(shader);
  return glShaders.length - 1;
}
const glLinkShaderProgram = (vertexShaderId, fragmentShaderId) => {
  const program = gl.createProgram();
  gl.attachShader(program, glShaders[vertexShaderId]);
  gl.attachShader(program, glShaders[fragmentShaderId]);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw ("Error linking program:" + gl.getProgramInfoLog(program));
  }
  glPrograms.push(program);
  return glPrograms.length - 1;
}

const glViewport = (x, y, width, height) => gl.viewport(x, y, width, height);
const glClearColor = (r, g, b, a) => gl.clearColor(r, g, b, a);
const glClear = (x) => gl.clear(x);
const glColorMask = (r, g, b, a) => gl.colorMask(r, g, b, a);
const glStencilMask = (mask) => gl.stencilMask(mask);
const glCullFace = (mode) => gl.cullFace(mode);
const glFrontFace = (mode) => gl.frontFace(mode);
const glEnable = (cap) => gl.enable(cap);
const glDisable = (cap) => gl.disable(cap);
const glDepthFunc = (x) => gl.depthFunc(x);
const glBlendFunc = (x, y) => gl.blendFunc(x, y);
const glBlendFuncSeparate = (srcRGB, dstRGB, srcAlpha, dstAlpha) => gl.blendFuncSeparate(srcRGB, dstRGB, srcAlpha, dstAlpha);
const glStencilFunc = (func, ref, mask) => gl.stencilFunc(func, ref, mask);
const glStencilOp = (fail, zfail, zpass) => gl.stencilOp(fail, zfail, zpass);
const glStencilOpSeparate = (face, fail, zfail, zpass) => gl.stencilOpSeparate(face, fail, zfail, zpass);
const glCreateProgram = () => {
  glPrograms.push(gl.createProgram());
  return glPrograms.length - 1;
};
const glCreateShader = (type) => {
  glShaders.push(gl.createShader(type));
  return glShaders.length - 1;
};
const glShaderSource = (shader, count, string, length) => {
  const strs = new Uint32Array(memory.buffer, string, count);
  const lens = new Uint32Array(memory.buffer, length, count);
  let source = '';
  for (let i = 0; i < count; i++) {
    source += readCharStr(strs[i], lens[i]);
  }
  gl.shaderSource(glShaders[shader], source);
};
const glCompileShader = (shader) => gl.compileShader(glShaders[shader]);
const glAttachShader = (program, shader) => gl.attachShader(glPrograms[program], glShaders[shader]);
const glGetShaderiv = (shader, pname, params) => {
  const buffer = new Uint32Array(memory.buffer, params, 1);
  buffer[0] = gl.getShaderParameter(glShaders[shader], pname);
};
const glGetShaderInfoLog = (shader, bufSize, length, infoLog) => {
  console.log(gl.getShaderInfoLog(glShaders[shader]));
};
const jsBindAttribLocation = (programId, index, namePtr, nameLen) => gl.bindAttribLocation(glPrograms[programId], index, readCharStr(namePtr, nameLen));
const glLinkProgram = (program) => gl.linkProgram(glPrograms[program]);
const glGetProgramiv = (program, pname, params) => {
  const buffer = new Uint32Array(memory.buffer, params, 1);
  buffer[0] = gl.getProgramParameter(glPrograms[program], pname);
};
const glGetProgramInfoLog = (program, bufSize, length, infoLog) => {
  console.log(gl.getProgramInfoLog(glPrograms[program]));
};
const glGetAttribLocation = (programId, namePtr, nameLen) => gl.getAttribLocation(glPrograms[programId], readCharStr(namePtr, nameLen));
const jsGetUniformLocation = (programId, namePtr, nameLen) => {
  glUniformLocations.push(gl.getUniformLocation(glPrograms[programId], readCharStr(namePtr, nameLen)));
  return glUniformLocations.length - 1;
};
const glUniform4f = (locationId, x, y, z, w) => gl.uniform4fv(glUniformLocations[locationId], [x, y, z, w]);
const glUniform4fv = (locationId, count, value) => {
  let arr = new Float32Array(memory.buffer, value, count * 4);
  gl.uniform4fv(glUniformLocations[locationId], arr);
}
const glUniformMatrix4fv = (locationId, dataLen, transpose, dataPtr) => {
  const floats = new Float32Array(memory.buffer, dataPtr, dataLen * 16);
  gl.uniformMatrix4fv(glUniformLocations[locationId], transpose, floats);
};
const glUniform1i = (locationId, x) => gl.uniform1i(glUniformLocations[locationId], x);
const glUniform1f = (locationId, x) => gl.uniform1f(glUniformLocations[locationId], x);
const glUniform2fv = (locationId, count, value) => {
  let arr = new Float32Array(memory.buffer, value, count * 2);
  gl.uniform2fv(glUniformLocations[locationId], arr);
}
const glCreateBuffer = () => {
  glBuffers.push(gl.createBuffer());
  return glBuffers.length - 1;
};
const glGenBuffers = (num, dataPtr) => {
  const buffers = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    const b = glCreateBuffer();
    buffers[n] = b;
  }
};
const glDetachShader = (program, shader) => {
  gl.detachShader(glPrograms[program], glShaders[shader]);
};
const glDeleteProgram = (id) => {
  gl.deleteProgram(glPrograms[id]);
  glPrograms[id] = undefined;
};
const glDeleteBuffer = (id) => {
  gl.deleteBuffer(glPrograms[id]);
  glPrograms[id] = undefined;
};
const glDeleteBuffers = (num, dataPtr) => {
  const buffers = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    gl.deleteBuffer(buffers[n]);
    glBuffers[buffers[n]] = undefined;
  }
};
const glDeleteShader = (id) => {
  gl.deleteShader(glShaders[id]);
  glShaders[id] = undefined;
};
const glBindBuffer = (type, bufferId) => gl.bindBuffer(type, glBuffers[bufferId]);
const glBufferData = (type, count, dataPtr, drawType) => {
  const floats = new Uint8Array(memory.buffer, dataPtr, count);
  gl.bufferData(type, floats, drawType);
}
const glUseProgram = (programId) => gl.useProgram(glPrograms[programId]);
const glEnableVertexAttribArray = (x) => gl.enableVertexAttribArray(x);
const glDisableVertexAttribArray = (x) => gl.disableVertexAttribArray(x);
const glVertexAttribPointer = (attribLocation, size, type, normalize, stride, offset) => {
  gl.vertexAttribPointer(attribLocation, size, type, normalize, stride, offset);
}
const glDrawArrays = (type, offset, count) => gl.drawArrays(type, offset, count);
const glDrawElements = (mode, count, type, offset) => gl.drawElements(mode, count, type, offset);

const glCreateTexture = () => {
  glTextures.push(gl.createTexture());
  return glTextures.length - 1;
};
const glLoadTexture = (urlPtr, urlLen) => {
  const url = readCharStr(urlPtr, urlLen);
  return loadImageTexture(gl, url);
}
function createGLTexture(image, texture) {
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
  glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
  glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
  glTexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  gl.generateMipmap(gl.TEXTURE_2D)
  glBindTexture(gl.TEXTURE_2D, null);
}
function loadImageTexture(gl, url) {
  var id = glCreateTexture();
  var texture = glTextures[id];
  texture.image = new Image();
  texture.image.crossOrigin = '';
  texture.image.onload = function () {
    createGLTexture(texture.image, texture)
  }
  texture.image.src = url;
  return id;
}
const glGenTextures = (num, dataPtr) => {
  const textures = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    const b = glCreateTexture();
    textures[n] = b;
  }
}
const glDeleteTextures = (num, dataPtr) => {
  const textures = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    gl.deleteTexture(glTextures[textures[n]]);
    glTextures[textures[n]] = undefined;
  }
};
const glBindTexture = (target, textureId) => gl.bindTexture(target, glTextures[textureId]);
const glTexImage2D = (target, level, internalFormat, width, height, border, format, type, dataPtr, dataLen) => {
  const data = new Uint8Array(memory.buffer, dataPtr, dataLen);
  gl.texImage2D(target, level, internalFormat, width, height, border, format, type, data);
};
const glTexSubImage2D = (target, level, xoffset, yoffset, width, height, format, type, dataPtr, dataLen) => {
  const data = new Uint8Array(memory.buffer, dataPtr, dataLen);
  gl.texSubImage2D(target, level, xoffset, yoffset, width, height, format, type, data);
}
const glTexParameteri = (target, pname, param) => gl.texParameteri(target, pname, param);
const glGenerateMipmap = (target) => gl.generateMipmap(target);
const glActiveTexture = (target) => gl.activeTexture(target);
const glCreateVertexArray = () => {
  glVertexArrays.push(gl.createVertexArray());
  return glVertexArrays.length - 1;
};
const glGenVertexArrays = (num, dataPtr) => {
  const vaos = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    const b = glCreateVertexArray();
    vaos[n] = b;
  }
}
const glDeleteVertexArrays = (num, dataPtr) => {
  const vaos = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    gl.glCreateTexture(vaos[n]);
    glVertexArrays[vaos[n]] = undefined;
  }
};
const glBindVertexArray = (id) => gl.bindVertexArray(glVertexArrays[id]);
const glPixelStorei = (pname, param) => gl.pixelStorei(pname, param);
const glReadPixels = (x, y, w, h, format, type, pixels) => {
  const data = new Uint8Array(memory.buffer, pixels);
  gl.readPixels(x, y, w, h, format, type, data);
}
const glGetError = () => gl.getError();

var webgl = {
  glInitShader,
  glLinkShaderProgram,
  glLoadTexture,
  glDeleteProgram,
  glDetachShader,
  glDeleteShader,
  glViewport,
  glClearColor,
  glCullFace,
  glFrontFace,
  glEnable,
  glDisable,
  glDepthFunc,
  glBlendFunc,
  glBlendFuncSeparate,
  glStencilFunc,
  glStencilOp,
  glStencilOpSeparate,
  glClear,
  glColorMask,
  glStencilMask,
  glCreateProgram,
  glCreateShader,
  glShaderSource,
  glCompileShader,
  glAttachShader,
  glGetShaderiv,
  glGetShaderInfoLog,
  jsBindAttribLocation,
  glLinkProgram,
  glGetProgramiv,
  glGetProgramInfoLog,
  glGetAttribLocation,
  jsGetUniformLocation,
  glUniform4f,
  glUniform4fv,
  glUniformMatrix4fv,
  glUniform1i,
  glUniform1f,
  glUniform2fv,
  glCreateBuffer,
  glGenBuffers,
  glDeleteBuffer,
  glDeleteBuffers,
  glBindBuffer,
  glBufferData,
  glUseProgram,
  glEnableVertexAttribArray,
  glDisableVertexAttribArray,
  glVertexAttribPointer,
  glDrawArrays,
  glDrawElements,
  glCreateTexture,
  glGenTextures,
  glDeleteTextures,
  glBindTexture,
  glTexImage2D,
  glTexSubImage2D,
  glTexParameteri,
  glGenerateMipmap,
  glActiveTexture,
  glCreateVertexArray,
  glGenVertexArrays,
  glDeleteVertexArrays,
  glBindVertexArray,
  glPixelStorei,
  glReadPixels,
  glGetError,
};