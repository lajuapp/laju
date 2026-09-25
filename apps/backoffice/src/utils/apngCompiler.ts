/**
 * Pure TypeScript APNG (Animated Portable Network Graphics) Compiler
 * Assembles HTMLCanvasElement or ImageData frame sequence into a standard APNG binary Blob
 * Compliant with W3C APNG specification.
 */

// CRC32 Lookup Table
const crcTable: number[] = new Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) {
    if (c & 1) {
      c = 0xedb88320 ^ (c >>> 1);
    } else {
      c = c >>> 1;
    }
  }
  crcTable[n] = c;
}

function crc32(buf: Uint8Array, offset: number, length: number): number {
  let c = 0xffffffff;
  for (let i = 0; i < length; i++) {
    c = crcTable[(c ^ buf[offset + i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function writeUint32(buf: Uint8Array, offset: number, value: number) {
  buf[offset] = (value >>> 24) & 0xff;
  buf[offset + 1] = (value >>> 16) & 0xff;
  buf[offset + 2] = (value >>> 8) & 0xff;
  buf[offset + 3] = value & 0xff;
}

function writeUint16(buf: Uint8Array, offset: number, value: number) {
  buf[offset] = (value >>> 8) & 0xff;
  buf[offset + 1] = value & 0xff;
}

function createChunk(type: string, data: Uint8Array): Uint8Array {
  const len = data.length;
  const chunk = new Uint8Array(12 + len);
  writeUint32(chunk, 0, len);
  chunk[4] = type.charCodeAt(0);
  chunk[5] = type.charCodeAt(1);
  chunk[6] = type.charCodeAt(2);
  chunk[7] = type.charCodeAt(3);
  chunk.set(data, 8);
  const crc = crc32(chunk, 4, 4 + len);
  writeUint32(chunk, 8 + len, crc);
  return chunk;
}

interface ParsedChunk {
  type: string;
  data: Uint8Array;
}

function parsePngChunks(pngBytes: Uint8Array): ParsedChunk[] {
  const chunks: ParsedChunk[] = [];
  let pos = 8; // skip 8-byte PNG signature

  while (pos < pngBytes.length) {
    const len =
      (pngBytes[pos] << 24) |
      (pngBytes[pos + 1] << 16) |
      (pngBytes[pos + 2] << 8) |
      pngBytes[pos + 3];
    const type = String.fromCharCode(
      pngBytes[pos + 4],
      pngBytes[pos + 5],
      pngBytes[pos + 6],
      pngBytes[pos + 7]
    );
    const data = pngBytes.slice(pos + 8, pos + 8 + len);
    chunks.push({ type, data });
    pos += 12 + len; // 4 len + 4 type + data + 4 crc
  }
  return chunks;
}

export interface ApngCompileOptions {
  fps: number; // e.g. 10, 15, 24
  loopCount?: number; // 0 = infinite loop
  width: number;
  height: number;
}

/**
 * Compiles a list of HTMLCanvasElements into an APNG Blob
 */
export async function compileFramesToApng(
  canvasFrames: HTMLCanvasElement[],
  options: ApngCompileOptions
): Promise<Blob> {
  if (canvasFrames.length === 0) {
    throw new Error('Dibutuhkan minimal 1 frame untuk kompilasi');
  }

  const { fps, loopCount = 0, width, height } = options;
  const delayNum = 1;
  const delayDen = Math.max(1, Math.round(fps));

  // Convert all canvases to PNG buffers in parallel
  const frameBuffers: Uint8Array[] = await Promise.all(
    canvasFrames.map(
      (canvas) =>
        new Promise<Uint8Array>((resolve, reject) => {
          canvas.toBlob(async (blob) => {
            if (!blob) return reject(new Error('Gagal mengekstrak canvas blob'));
            const arrayBuffer = await blob.arrayBuffer();
            resolve(new Uint8Array(arrayBuffer));
          }, 'image/png');
        })
    )
  );

  const pngSignature = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const chunksList: Uint8Array[] = [pngSignature];

  const firstParsed = parsePngChunks(frameBuffers[0]);
  const ihdrChunk = firstParsed.find((c) => c.type === 'IHDR');
  if (!ihdrChunk) throw new Error('Invalid PNG header');

  // 1. IHDR Chunk
  chunksList.push(createChunk('IHDR', ihdrChunk.data));

  // 2. acTL Chunk (Animation Control)
  const actlData = new Uint8Array(8);
  writeUint32(actlData, 0, canvasFrames.length); // num_frames
  writeUint32(actlData, 4, loopCount); // num_plays (0 = infinite)
  chunksList.push(createChunk('acTL', actlData));

  let sequenceNumber = 0;

  // 3. Process each frame
  for (let i = 0; i < frameBuffers.length; i++) {
    const parsed = i === 0 ? firstParsed : parsePngChunks(frameBuffers[i]);

    // Create fcTL Chunk (Frame Control)
    const fctlData = new Uint8Array(26);
    writeUint32(fctlData, 0, sequenceNumber++);
    writeUint32(fctlData, 4, width);
    writeUint32(fctlData, 8, height);
    writeUint32(fctlData, 12, 0); // x_offset
    writeUint32(fctlData, 16, 0); // y_offset
    writeUint16(fctlData, 20, delayNum);
    writeUint16(fctlData, 22, delayDen);
    fctlData[24] = 1; // dispose_op = APNG_DISPOSE_OP_BACKGROUND (clean frame redraw)
    fctlData[25] = 0; // blend_op = APNG_BLEND_OP_SOURCE
    chunksList.push(createChunk('fcTL', fctlData));

    // IDAT or fdAT
    const idatChunks = parsed.filter((c) => c.type === 'IDAT');
    for (const idat of idatChunks) {
      if (i === 0) {
        // First frame uses standard IDAT
        chunksList.push(createChunk('IDAT', idat.data));
      } else {
        // Subsequent frames use fdAT with sequence number prefix
        const fdatData = new Uint8Array(4 + idat.data.length);
        writeUint32(fdatData, 0, sequenceNumber++);
        fdatData.set(idat.data, 4);
        chunksList.push(createChunk('fdAT', fdatData));
      }
    }
  }

  // 4. IEND Chunk
  chunksList.push(createChunk('IEND', new Uint8Array(0)));

  // Combine all Uint8Arrays into single binary Blob
  return new Blob(chunksList as any, { type: 'image/apng' });
}

/**
 * Slices a Sprite Sheet image into individual frame canvases
 */
export async function sliceSpriteSheet(
  image: HTMLImageElement,
  cols: number,
  rows: number,
  targetWidth = 512,
  targetHeight = 512
): Promise<HTMLCanvasElement[]> {
  const frameWidth = Math.floor(image.naturalWidth / cols);
  const frameHeight = Math.floor(image.naturalHeight / rows);
  const frames: HTMLCanvasElement[] = [];

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const canvas = document.createElement('canvas');
      canvas.width = targetWidth;
      canvas.height = targetHeight;
      const ctx = canvas.getContext('2d');
      if (ctx) {
        ctx.imageSmoothingEnabled = true;
        ctx.drawImage(
          image,
          c * frameWidth,
          r * frameHeight,
          frameWidth,
          frameHeight,
          0,
          0,
          targetWidth,
          targetHeight
        );
        frames.push(canvas);
      }
    }
  }

  return frames;
}
