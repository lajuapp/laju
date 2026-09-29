import React, { useState, useEffect, useRef } from 'react';
import {
  Play,
  Pause,
  Upload,
  Layers,
  Film,
  Grid3X3,
  Trash2,
  ArrowLeft,
  ArrowRight,
  CheckCircle,
  AlertCircle,
  Sparkles,
  Sliders,
  Clock,
  RotateCcw,
  Copy,
  SkipBack,
  SkipForward,
  Maximize2,
  ZoomIn,
  Repeat,
  Scissors,
  Eye,
} from 'lucide-react';
import { Modal } from '../ui/Modal';
import { Button } from '../ui/Button';
import { Badge } from '../ui/Badge';
import { compileFramesToApng, sliceSpriteSheet } from '../../utils/apngCompiler';
import { useMediaUpload } from '../../hooks/useMediaUpload';
import { useAddStickerItem } from '../../hooks/useStickers';

interface ApngFrameStudioModalProps {
  isOpen: boolean;
  onClose: () => void;
  packId: string;
  packName: string;
}

interface FrameItem {
  id: string;
  canvas: HTMLCanvasElement;
  previewUrl: string;
}

export function ApngFrameStudioModal({
  isOpen,
  onClose,
  packId,
  packName,
}: ApngFrameStudioModalProps) {
  const mediaUpload = useMediaUpload();
  const addSticker = useAddStickerItem();

  const [activeTab, setActiveTab] = useState<'SEQUENCE' | 'SPRITESHEET'>('SEQUENCE');
  const [stickerName, setStickerName] = useState('');
  const [stickerTag, setStickerTag] = useState('');
  const [fps, setFps] = useState(12);
  const [loopCount, setLoopCount] = useState(0); // 0 = infinite
  const [canvasSize, setCanvasSize] = useState(512);

  // Viewport Settings
  const [stageBg, setStageBg] = useState<'checker' | 'dark' | 'light' | 'green'>('checker');
  const [zoomLevel, setZoomLevel] = useState<number>(1); // 1 = 1x, 1.5, 2

  // Sprite sheet settings
  const [spriteCols, setSpriteCols] = useState(4);
  const [spriteRows, setSpriteRows] = useState(4);

  // Frames state
  const [frames, setFrames] = useState<FrameItem[]>([]);
  const [currentFrameIdx, setCurrentFrameIdx] = useState(0);
  const [isPlaying, setIsPlaying] = useState(true);

  // Compiled APNG
  const [compiledBlob, setCompiledBlob] = useState<Blob | null>(null);
  const [compiledUrl, setCompiledUrl] = useState<string | null>(null);
  const [isCompiling, setIsCompiling] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Canvas Player Ref
  const playerCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const animIntervalRef = useRef<number | null>(null);

  // Reset when modal opens
  useEffect(() => {
    if (isOpen) {
      setFrames([]);
      setCompiledBlob(null);
      setCompiledUrl(null);
      setStickerName('');
      setStickerTag('');
      setErrorMessage(null);
      setIsPlaying(true);
      setCurrentFrameIdx(0);
      setFps(12);
      setLoopCount(0);
      setZoomLevel(1);
    }
  }, [isOpen]);

  // Live animation player loop
  useEffect(() => {
    if (frames.length === 0) return;

    if (isPlaying) {
      const intervalMs = Math.round(1000 / fps);
      animIntervalRef.current = window.setInterval(() => {
        setCurrentFrameIdx((prev) => (prev + 1) % frames.length);
      }, intervalMs);
    }

    return () => {
      if (animIntervalRef.current) {
        clearInterval(animIntervalRef.current);
      }
    };
  }, [isPlaying, fps, frames.length]);

  // Render current frame to the preview canvas
  useEffect(() => {
    if (!playerCanvasRef.current || frames.length === 0) return;
    const canvas = playerCanvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const activeFrame = frames[currentFrameIdx];
    if (activeFrame) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(activeFrame.canvas, 0, 0, canvas.width, canvas.height);
    }
  }, [currentFrameIdx, frames]);

  // Handle uploading sequence of image files
  const handleUploadSequence = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || e.target.files.length === 0) return;

    const files = Array.from(e.target.files);
    // Sort files naturally by filename (e.g. frame_1, frame_2, ...)
    files.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }));

    const newFrames: FrameItem[] = [];
    let loadedCount = 0;

    files.forEach((file) => {
      const img = new Image();
      const objectUrl = URL.createObjectURL(file);
      img.src = objectUrl;

      img.onload = () => {
        const c = document.createElement('canvas');
        c.width = canvasSize;
        c.height = canvasSize;
        const ctx = c.getContext('2d');
        if (ctx) {
          ctx.imageSmoothingEnabled = true;
          ctx.drawImage(img, 0, 0, canvasSize, canvasSize);
          newFrames.push({
            id: Math.random().toString(36).substring(2, 9),
            canvas: c,
            previewUrl: c.toDataURL('image/png'),
          });
        }
        loadedCount++;

        if (loadedCount === files.length) {
          setFrames((prev) => [...prev, ...newFrames]);
          setCompiledBlob(null);
          setCompiledUrl(null);
          if (!stickerName && files.length > 0) {
            const baseName = files[0].name.replace(/\.[^/.]+$/, '').replace(/[\d_-]+$/, '');
            if (baseName) setStickerName(baseName);
          }
        }
      };
    });
  };

  // Handle uploading and slicing a sprite sheet
  const handleUploadSpriteSheet = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0]) return;
    const file = e.target.files[0];
    const img = new Image();
    img.src = URL.createObjectURL(file);

    img.onload = async () => {
      try {
        const slicedCanvases = await sliceSpriteSheet(
          img,
          spriteCols,
          spriteRows,
          canvasSize,
          canvasSize
        );
        const slicedFrames: FrameItem[] = slicedCanvases.map((c) => ({
          id: Math.random().toString(36).substring(2, 9),
          canvas: c,
          previewUrl: c.toDataURL('image/png'),
        }));
        setFrames(slicedFrames);
        setCompiledBlob(null);
        setCompiledUrl(null);
        if (!stickerName) {
          const baseName = file.name.replace(/\.[^/.]+$/, '');
          setStickerName(baseName);
        }
      } catch (err: any) {
        setErrorMessage('Gagal memotong sprite sheet: ' + err.message);
      }
    };
  };

  // Move frame in sequence
  const moveFrame = (index: number, direction: 'left' | 'right') => {
    const targetIdx = direction === 'left' ? index - 1 : index + 1;
    if (targetIdx < 0 || targetIdx >= frames.length) return;

    setFrames((prev) => {
      const copy = [...prev];
      const temp = copy[index];
      copy[index] = copy[targetIdx];
      copy[targetIdx] = temp;
      return copy;
    });
    setCompiledBlob(null);
    setCompiledUrl(null);
  };

  // Duplicate specific frame
  const duplicateFrame = (index: number) => {
    setFrames((prev) => {
      const copy = [...prev];
      const original = copy[index];
      const clonedCanvas = document.createElement('canvas');
      clonedCanvas.width = canvasSize;
      clonedCanvas.height = canvasSize;
      const ctx = clonedCanvas.getContext('2d');
      if (ctx) ctx.drawImage(original.canvas, 0, 0);

      copy.splice(index + 1, 0, {
        id: Math.random().toString(36).substring(2, 9),
        canvas: clonedCanvas,
        previewUrl: clonedCanvas.toDataURL('image/png'),
      });
      return copy;
    });
    setCompiledBlob(null);
    setCompiledUrl(null);
  };

  // Delete individual frame
  const deleteFrame = (index: number) => {
    setFrames((prev) => prev.filter((_, idx) => idx !== index));
    if (currentFrameIdx >= frames.length - 1) {
      setCurrentFrameIdx(Math.max(0, frames.length - 2));
    }
    setCompiledBlob(null);
    setCompiledUrl(null);
  };

  // Timeline Tools: Reverse Sequence
  const reverseFrames = () => {
    setFrames((prev) => [...prev].reverse());
    setCompiledBlob(null);
    setCompiledUrl(null);
  };

  // Timeline Tools: Boomerang / Ping-Pong (Forward then Backward)
  const boomerangFrames = () => {
    if (frames.length < 2) return;
    const middleReversed = frames.slice(1, -1).reverse();
    const clonedReversed = middleReversed.map((f) => {
      const c = document.createElement('canvas');
      c.width = canvasSize;
      c.height = canvasSize;
      const ctx = c.getContext('2d');
      if (ctx) ctx.drawImage(f.canvas, 0, 0);
      return {
        id: Math.random().toString(36).substring(2, 9),
        canvas: c,
        previewUrl: c.toDataURL('image/png'),
      };
    });
    setFrames((prev) => [...prev, ...clonedReversed]);
    setCompiledBlob(null);
    setCompiledUrl(null);
  };

  // Compile frames to APNG
  const handleCompileApng = async () => {
    if (frames.length === 0) {
      setErrorMessage('Unggah frame animasi terlebih dahulu');
      return;
    }

    setIsCompiling(true);
    setErrorMessage(null);

    try {
      const canvases = frames.map((f) => f.canvas);
      const blob = await compileFramesToApng(canvases, {
        fps,
        loopCount,
        width: canvasSize,
        height: canvasSize,
      });

      const url = URL.createObjectURL(blob);
      setCompiledBlob(blob);
      setCompiledUrl(url);
    } catch (err: any) {
      setErrorMessage('Kompilasi APNG gagal: ' + err.message);
    } finally {
      setIsCompiling(false);
    }
  };

  // Save compiled APNG sticker to package
  const handleSaveSticker = async () => {
    if (!compiledBlob) {
      setErrorMessage('Harap kompilasi animasi terlebih dahulu sebelum menyimpan');
      return;
    }
    if (!stickerName.trim()) {
      setErrorMessage('Nama stiker wajib diisi');
      return;
    }

    setIsSaving(true);
    setErrorMessage(null);

    try {
      // Create File from APNG Blob with .apng extension
      const file = new File([compiledBlob], `${stickerName.replace(/\s+/g, '_').toLowerCase()}.apng`, {
        type: 'image/apng',
      });

      const uploadRes = await mediaUpload.mutateAsync(file);

      await addSticker.mutateAsync({
        packId,
        name: stickerName.trim(),
        imageUrl: uploadRes.url,
        emoji: stickerTag.trim() || undefined,
      });

      onClose();
    } catch (err: any) {
      setErrorMessage(err.response?.data?.message || 'Gagal menyimpan stiker animasi');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Studio Animasi APNG & Frame Sheet"
      description={`Buat dan kompilasi stiker animasi untuk paket "${packName}"`}
      maxWidth="7xl"
    >
      <div className="space-y-5 max-h-[85vh] overflow-y-auto pr-1">
        {errorMessage && (
          <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        {/* Studio Workspace Layout: 2 Columns */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-start">
          {/* Left Column (5 cols): Interactive Live Viewport & Player Stage */}
          <div className="lg:col-span-5 space-y-3.5 bg-neutral-50/70 p-4 rounded-2xl border border-neutral-200/80">
            {/* Viewport Toolbar */}
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-neutral-800 flex items-center gap-1.5">
                <Film className="w-3.5 h-3.5 text-indigo-600" />
                Live Animation Viewport
              </span>

              {/* Background Theme Switcher */}
              <div className="flex items-center gap-1 bg-white p-1 rounded-xl border border-neutral-200/80 text-[10px]">
                <button
                  type="button"
                  onClick={() => setStageBg('checker')}
                  className={`px-2 py-0.5 rounded-md font-semibold transition-all ${
                    stageBg === 'checker' ? 'bg-neutral-900 text-white shadow-2xs' : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Catur
                </button>
                <button
                  type="button"
                  onClick={() => setStageBg('light')}
                  className={`px-2 py-0.5 rounded-md font-semibold transition-all ${
                    stageBg === 'light' ? 'bg-neutral-900 text-white shadow-2xs' : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Putih
                </button>
                <button
                  type="button"
                  onClick={() => setStageBg('dark')}
                  className={`px-2 py-0.5 rounded-md font-semibold transition-all ${
                    stageBg === 'dark' ? 'bg-neutral-900 text-white shadow-2xs' : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Gelap
                </button>
                <button
                  type="button"
                  onClick={() => setStageBg('green')}
                  className={`px-2 py-0.5 rounded-md font-semibold transition-all ${
                    stageBg === 'green' ? 'bg-emerald-600 text-white shadow-2xs' : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Hijau
                </button>
              </div>
            </div>

            {/* Live Canvas Viewport Box */}
            <div
              className="w-full h-64 rounded-2xl border border-neutral-200/90 flex items-center justify-center p-4 relative overflow-hidden transition-colors"
              style={{
                backgroundColor:
                  stageBg === 'dark' ? '#0F172A' : stageBg === 'green' ? '#059669' : '#ffffff',
                backgroundImage:
                  stageBg === 'checker'
                    ? 'linear-gradient(45deg, #f1f5f9 25%, transparent 25%), linear-gradient(-45deg, #f1f5f9 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f1f5f9 75%), linear-gradient(-45deg, transparent 75%, #f1f5f9 75%)'
                    : undefined,
                backgroundSize: '16px 16px',
                backgroundPosition: '0 0, 0 8px, 8px -8px, -8px 0px',
              }}
            >
              {frames.length > 0 ? (
                <canvas
                  ref={playerCanvasRef}
                  width={canvasSize}
                  height={canvasSize}
                  className="max-h-full max-w-full object-contain filter drop-shadow-md transition-transform duration-150"
                  style={{ transform: `scale(${zoomLevel})` }}
                />
              ) : (
                <div className="text-center text-neutral-400 space-y-1">
                  <Film className="w-10 h-10 mx-auto text-neutral-300" />
                  <p className="text-xs font-semibold">Belum ada frame animasi</p>
                  <p className="text-[11px] text-neutral-400">Unggah frame atau sprite sheet di sebelah kanan</p>
                </div>
              )}
            </div>

            {/* Full Transport Scrub Bar */}
            <div className="bg-white p-3 rounded-xl border border-neutral-200/80 space-y-2.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5">
                  <button
                    type="button"
                    onClick={() => {
                      setIsPlaying(false);
                      setCurrentFrameIdx(0);
                    }}
                    disabled={frames.length === 0}
                    className="p-1.5 rounded-lg text-neutral-600 hover:bg-neutral-100 disabled:opacity-40"
                    title="Ke Frame Pertama"
                  >
                    <SkipBack className="w-4 h-4" />
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setIsPlaying(false);
                      setCurrentFrameIdx((prev) => (prev > 0 ? prev - 1 : frames.length - 1));
                    }}
                    disabled={frames.length === 0}
                    className="p-1.5 rounded-lg text-neutral-600 hover:bg-neutral-100 disabled:opacity-40"
                    title="Frame Sebelumnya"
                  >
                    <ArrowLeft className="w-4 h-4" />
                  </button>

                  <button
                    type="button"
                    onClick={() => setIsPlaying(!isPlaying)}
                    disabled={frames.length === 0}
                    className="p-2 rounded-xl bg-indigo-600 text-white hover:bg-indigo-700 disabled:opacity-40 shadow-xs"
                    title={isPlaying ? 'Jeda Animasi' : 'Putar Animasi'}
                  >
                    {isPlaying ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setIsPlaying(false);
                      setCurrentFrameIdx((prev) => (prev + 1) % frames.length);
                    }}
                    disabled={frames.length === 0}
                    className="p-1.5 rounded-lg text-neutral-600 hover:bg-neutral-100 disabled:opacity-40"
                    title="Frame Berikutnya"
                  >
                    <ArrowRight className="w-4 h-4" />
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setIsPlaying(false);
                      setCurrentFrameIdx(Math.max(0, frames.length - 1));
                    }}
                    disabled={frames.length === 0}
                    className="p-1.5 rounded-lg text-neutral-600 hover:bg-neutral-100 disabled:opacity-40"
                    title="Ke Frame Terakhir"
                  >
                    <SkipForward className="w-4 h-4" />
                  </button>
                </div>

                <div className="flex items-center gap-2">
                  <span className="text-xs font-mono font-bold text-neutral-700 bg-neutral-100 px-2 py-0.5 rounded-md">
                    Frame {frames.length > 0 ? currentFrameIdx + 1 : 0} / {frames.length}
                  </span>

                  {/* Zoom Selector */}
                  <div className="flex items-center bg-neutral-100 rounded-lg p-0.5 text-[10px]">
                    <button
                      type="button"
                      onClick={() => setZoomLevel(1)}
                      className={`px-1.5 py-0.5 rounded font-semibold ${zoomLevel === 1 ? 'bg-white shadow-2xs' : 'text-neutral-500'}`}
                    >
                      1x
                    </button>
                    <button
                      type="button"
                      onClick={() => setZoomLevel(1.5)}
                      className={`px-1.5 py-0.5 rounded font-semibold ${zoomLevel === 1.5 ? 'bg-white shadow-2xs' : 'text-neutral-500'}`}
                    >
                      1.5x
                    </button>
                  </div>
                </div>
              </div>

              {/* Scrubber Range */}
              {frames.length > 0 && (
                <input
                  type="range"
                  min="0"
                  max={Math.max(0, frames.length - 1)}
                  value={currentFrameIdx}
                  onChange={(e) => {
                    setIsPlaying(false);
                    setCurrentFrameIdx(parseInt(e.target.value) || 0);
                  }}
                  className="w-full accent-indigo-600 h-1.5 bg-neutral-200 rounded-lg cursor-pointer"
                />
              )}
            </div>

            {/* Compiled Result Stage */}
            {compiledUrl && (
              <div className="p-3.5 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div
                    className="w-14 h-14 rounded-lg flex items-center justify-center p-1 border border-emerald-300 overflow-hidden shrink-0"
                    style={{
                      backgroundColor: '#ffffff',
                      backgroundImage:
                        'linear-gradient(45deg, #f1f5f9 25%, transparent 25%), linear-gradient(-45deg, #f1f5f9 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f1f5f9 75%), linear-gradient(-45deg, transparent 75%, #f1f5f9 75%)',
                      backgroundSize: '8px 8px',
                      backgroundPosition: '0 0, 0 4px, 4px -4px, -4px 0px',
                    }}
                  >
                    <img
                      src={compiledUrl}
                      alt="Hasil APNG"
                      className="max-w-full max-h-full object-contain filter drop-shadow-xs"
                    />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-bold text-emerald-900">APNG Siap Diterbitkan</span>
                      <span className="text-[10px] font-bold bg-emerald-200 text-emerald-800 px-1.5 py-0.5 rounded">
                        {Math.round((compiledBlob?.size || 0) / 1024)} KB
                      </span>
                    </div>
                    <p className="text-[11px] text-emerald-700 mt-0.5">
                      Berjalan pada {fps} FPS • Animasi mulus tanpa background.
                    </p>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Right Column (7 cols): Studio Controls & Mode Tabs */}
          <div className="lg:col-span-7 space-y-4">
            {/* Input Name & Tag */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 bg-neutral-50/70 p-3.5 rounded-xl border border-neutral-200/80">
              <div className="space-y-1">
                <label className="text-xs font-bold text-neutral-800">Nama Stiker Animasi</label>
                <input
                  type="text"
                  placeholder="Misal: Frog_Dance / Katak_Tertawa"
                  value={stickerName}
                  onChange={(e) => setStickerName(e.target.value)}
                  className="w-full px-3 py-1.5 text-xs rounded-lg border border-neutral-200 bg-white font-medium"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-neutral-800">Tag / Reaksi Emoji</label>
                <input
                  type="text"
                  placeholder="Misal: frog / dance / laugh"
                  value={stickerTag}
                  onChange={(e) => setStickerTag(e.target.value)}
                  className="w-full px-3 py-1.5 text-xs rounded-lg border border-neutral-200 bg-white"
                />
              </div>
            </div>

            {/* Source Mode Selector */}
            <div className="flex items-center justify-between border-b border-neutral-200 pb-2">
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setActiveTab('SEQUENCE')}
                  className={`text-xs font-bold pb-2 px-3 border-b-2 transition-all flex items-center gap-1.5 ${
                    activeTab === 'SEQUENCE'
                      ? 'border-indigo-600 text-indigo-700'
                      : 'border-transparent text-neutral-500 hover:text-neutral-800'
                  }`}
                >
                  <Layers className="w-3.5 h-3.5" />
                  Urutan Gambar Frame
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab('SPRITESHEET')}
                  className={`text-xs font-bold pb-2 px-3 border-b-2 transition-all flex items-center gap-1.5 ${
                    activeTab === 'SPRITESHEET'
                      ? 'border-indigo-600 text-indigo-700'
                      : 'border-transparent text-neutral-500 hover:text-neutral-800'
                  }`}
                >
                  <Grid3X3 className="w-3.5 h-3.5" />
                  Pemotong Sprite Sheet Animasi
                </button>
              </div>

              <Badge variant="neutral">{frames.length} Frame Aktif</Badge>
            </div>

            {/* Upload Area depending on Active Tab */}
            {activeTab === 'SEQUENCE' ? (
              <div className="border-2 border-dashed border-neutral-300 rounded-2xl p-5 text-center hover:border-indigo-500 transition-colors cursor-pointer relative bg-neutral-50/50">
                <input
                  type="file"
                  multiple
                  accept="image/png,image/webp,image/apng,image/gif"
                  onChange={handleUploadSequence}
                  className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                />
                <div className="space-y-1.5 text-neutral-600">
                  <Upload className="w-7 h-7 mx-auto text-indigo-600" />
                  <p className="text-xs font-bold text-neutral-800">
                    Pilih atau Seret Beberapa File Frame Sekaligus (PNG / WEBP Transparan)
                  </p>
                  <p className="text-[11px] text-neutral-400">
                    Otomatis diurutkan berdasarkan penomoran nama file (misal: frog_1.png, frog_2.png)
                  </p>
                </div>
              </div>
            ) : (
              <div className="space-y-3 bg-neutral-50/70 p-4 rounded-2xl border border-neutral-200">
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <label className="text-[11px] font-semibold text-neutral-700">Kolom (Columns)</label>
                    <input
                      type="number"
                      min="1"
                      max="16"
                      value={spriteCols}
                      onChange={(e) => setSpriteCols(Math.max(1, parseInt(e.target.value) || 1))}
                      className="w-full px-3 py-1.5 text-xs rounded-lg border border-neutral-200 bg-white"
                    />
                  </div>
                  <div className="space-y-1">
                    <label className="text-[11px] font-semibold text-neutral-700">Baris (Rows)</label>
                    <input
                      type="number"
                      min="1"
                      max="16"
                      value={spriteRows}
                      onChange={(e) => setSpriteRows(Math.max(1, parseInt(e.target.value) || 1))}
                      className="w-full px-3 py-1.5 text-xs rounded-lg border border-neutral-200 bg-white"
                    />
                  </div>
                </div>

                <div className="border-2 border-dashed border-neutral-300 rounded-xl p-3.5 text-center hover:border-indigo-500 transition-colors cursor-pointer relative bg-white">
                  <input
                    type="file"
                    accept="image/png,image/webp,image/jpeg"
                    onChange={handleUploadSpriteSheet}
                    className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                  />
                  <div className="space-y-1 text-neutral-600">
                    <Scissors className="w-5 h-5 mx-auto text-indigo-600" />
                    <p className="text-xs font-bold text-neutral-800">
                      Unggah Sprite Sheet Animasi ({spriteCols}x{spriteRows} = {spriteCols * spriteRows} frame)
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Animation Speed & Compilation Settings */}
            <div className="bg-neutral-50/70 p-4 rounded-2xl border border-neutral-200 space-y-3.5">
              <div>
                <div className="flex items-center justify-between text-xs font-bold text-neutral-800 mb-1.5">
                  <span className="flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5 text-neutral-600" />
                    Kecepatan Animasi: {fps} FPS ({Math.round(1000 / fps)} ms/frame)
                  </span>
                  <div className="flex gap-1">
                    {[8, 12, 16, 24, 30].map((rate) => (
                      <button
                        key={rate}
                        type="button"
                        onClick={() => setFps(rate)}
                        className={`text-[10px] font-semibold px-2 py-0.5 rounded border transition-all ${
                          fps === rate
                            ? 'bg-indigo-600 text-white border-indigo-600'
                            : 'bg-white text-neutral-600 border-neutral-200 hover:border-neutral-400'
                        }`}
                      >
                        {rate}
                      </button>
                    ))}
                  </div>
                </div>

                <input
                  type="range"
                  min="4"
                  max="60"
                  step="1"
                  value={fps}
                  onChange={(e) => setFps(parseInt(e.target.value) || 12)}
                  className="w-full accent-indigo-600 h-1.5 bg-neutral-200 rounded-lg cursor-pointer"
                />
              </div>

              <div className="grid grid-cols-2 gap-3 pt-1">
                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-neutral-700">Dimensi Target</label>
                  <select
                    value={canvasSize}
                    onChange={(e) => setCanvasSize(parseInt(e.target.value))}
                    className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-neutral-200 bg-white"
                  >
                    <option value="512">512 x 512 px (Standar Optimal)</option>
                    <option value="256">256 x 256 px (Kecil)</option>
                    <option value="128">128 x 128 px (Mini)</option>
                  </select>
                </div>

                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-neutral-700">Perulangan (Loop)</label>
                  <select
                    value={loopCount}
                    onChange={(e) => setLoopCount(parseInt(e.target.value))}
                    className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-neutral-200 bg-white"
                  >
                    <option value="0">Tak Terbatas (Infinite Loop)</option>
                    <option value="1">1 Kali Putar</option>
                    <option value="3">3 Kali Putar</option>
                  </select>
                </div>
              </div>

              {/* Timeline Sequence Helper Buttons */}
              <div className="flex flex-wrap gap-2 pt-2 border-t border-neutral-200">
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  disabled={frames.length < 2}
                  onClick={boomerangFrames}
                  icon={<Repeat className="w-3.5 h-3.5 text-indigo-600" />}
                >
                  Boomerang / Ping-Pong
                </Button>

                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  disabled={frames.length < 2}
                  onClick={reverseFrames}
                  icon={<RotateCcw className="w-3.5 h-3.5 text-neutral-600" />}
                >
                  Balikkan Urutan
                </Button>

                {frames.length > 0 && (
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    className="text-rose-600 hover:bg-rose-50 ml-auto"
                    onClick={() => {
                      setFrames([]);
                      setCompiledBlob(null);
                      setCompiledUrl(null);
                    }}
                  >
                    Kosongkan Semua Frame
                  </Button>
                )}
              </div>

              {/* Compile Button */}
              <Button
                type="button"
                variant="primary"
                className="w-full py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-bold"
                isLoading={isCompiling}
                disabled={frames.length === 0}
                onClick={handleCompileApng}
                icon={<Sparkles className="w-4 h-4" />}
              >
                {compiledBlob ? 'Kompilasi Ulang APNG' : 'Kompilasi ke Stiker APNG'}
              </Button>
            </div>
          </div>
        </div>

        {/* Bottom Horizontal Timeline Sequencer Strip */}
        {frames.length > 0 && (
          <div className="space-y-2 pt-3 border-t border-neutral-200">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-neutral-800">
                Timeline Urutan Frame ({frames.length} Frame)
              </span>
              <span className="text-[11px] text-neutral-400">
                Klik frame untuk melompat • Gunakan tombol untuk geser, duplikasi, atau hapus
              </span>
            </div>

            <div className="flex items-center gap-2.5 overflow-x-auto pb-3 pt-1">
              {frames.map((frame, idx) => (
                <div
                  key={frame.id}
                  onClick={() => {
                    setIsPlaying(false);
                    setCurrentFrameIdx(idx);
                  }}
                  className={`flex-shrink-0 w-24 p-2 rounded-2xl border bg-white cursor-pointer transition-all ${
                    currentFrameIdx === idx
                      ? 'border-indigo-600 ring-2 ring-indigo-200 shadow-sm'
                      : 'border-neutral-200 hover:border-neutral-300'
                  }`}
                >
                  <div
                    className="h-18 rounded-xl flex items-center justify-center overflow-hidden border border-neutral-100"
                    style={{
                      backgroundColor: '#ffffff',
                      backgroundImage:
                        'linear-gradient(45deg, #f1f5f9 25%, transparent 25%), linear-gradient(-45deg, #f1f5f9 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f1f5f9 75%), linear-gradient(-45deg, transparent 75%, #f1f5f9 75%)',
                      backgroundSize: '8px 8px',
                      backgroundPosition: '0 0, 0 4px, 4px -4px, -4px 0px',
                    }}
                  >
                    <img
                      src={frame.previewUrl}
                      alt={`Frame ${idx + 1}`}
                      className="max-h-full max-w-full object-contain filter drop-shadow-2xs"
                    />
                  </div>

                  <div className="flex items-center justify-between mt-2 text-[10px] text-neutral-500 font-mono">
                    <span className="font-bold">#{idx + 1}</span>
                    <div className="flex items-center gap-1">
                      {idx > 0 && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            moveFrame(idx, 'left');
                          }}
                          className="p-0.5 rounded hover:bg-neutral-100 text-neutral-600"
                          title="Geser Kiri"
                        >
                          <ArrowLeft className="w-3 h-3" />
                        </button>
                      )}
                      {idx < frames.length - 1 && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            moveFrame(idx, 'right');
                          }}
                          className="p-0.5 rounded hover:bg-neutral-100 text-neutral-600"
                          title="Geser Kanan"
                        >
                          <ArrowRight className="w-3 h-3" />
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          duplicateFrame(idx);
                        }}
                        className="p-0.5 rounded hover:bg-neutral-100 text-indigo-600"
                        title="Duplikasi Frame"
                      >
                        <Copy className="w-3 h-3" />
                      </button>
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          deleteFrame(idx);
                        }}
                        className="p-0.5 rounded hover:bg-rose-50 text-rose-600"
                        title="Hapus Frame"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Modal Footer */}
        <div className="flex items-center justify-between pt-4 border-t border-neutral-100">
          <Button type="button" variant="outline" onClick={onClose} disabled={isSaving}>
            Tutup
          </Button>

          <Button
            type="button"
            variant="primary"
            className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold"
            disabled={!compiledBlob || !stickerName.trim() || isSaving}
            isLoading={isSaving}
            onClick={handleSaveSticker}
            icon={<CheckCircle className="w-4 h-4" />}
          >
            Simpan Stiker Animasi ke Paket "{packName}"
          </Button>
        </div>
      </div>
    </Modal>
  );
}
