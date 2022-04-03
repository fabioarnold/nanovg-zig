const consoleLog = (ptr, len) => {
    console.log(readCharStr(ptr, len));
}

const performanceNow = () => {
    return performance.now();
}

const readCharStr = (ptr, len) => {
    const array = new Uint8Array(memory.buffer, ptr, len)
    const decoder = new TextDecoder()
    return decoder.decode(array)
}

const memcpy = (dest, src, n) => {
    const destArray = new Uint8Array(memory.buffer, dest, n);
    const srcArray = new Uint8Array(memory.buffer, src, n);
    for (let i = 0; i < n; i++) {
        destArray[i] = srcArray[i];
    }
}

const memset = (s, c, n) => {
    const arr = new Uint8Array(memory.buffer, s, n);
    for (let i = 0; i < n; i++) {
        arr[i] = c;
    }
}

var wasm = {
    consoleLog,
    performanceNow,
    readCharStr,
    memcpy,
    memset,
    fmodf: (x, y) => x % y,
    sinf: Math.sin,
    cosf: Math.cos,
    roundf: Math.round,
    fabs: Math.abs,
    abs: Math.abs,
    sqrt: Math.sqrt,
    expf: Math.exp,
    pow: Math.pow,
    ldexp: (x, exp) => x * Math.pow(2, exp)
}