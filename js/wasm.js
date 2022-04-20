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

const download = (filenamePtr, filenameLen, mimetypePtr, mimetypeLen, dataPtr, dataLen) => {
    const a = document.createElement('a');
    a.style = 'display:none';
    document.body.appendChild(a);
    const view = new Uint8Array(memory.buffer, dataPtr, dataLen);
    const mimetype = readCharStr(mimetypePtr, mimetypeLen);
    const blob = new Blob([view], {
        type: mimetype
    });
    const url = window.URL.createObjectURL(blob);
    a.href = url;
    const filename = readCharStr(filenamePtr, filenameLen);
    a.download = filename;
    a.click();
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
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
    download,
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