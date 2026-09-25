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
} from 'lucide-react';
import { Modal } from '../ui/Modal';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
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

  // Delete individual frame
  const deleteFrame = (index: number) => {
    setFrames((prev) => prev.filter((_, idx) => idx !== index));
    if (currentFrameIdx >= frames.length - 1) {
      setCurrentFrameIdx(Math.max(0, frames.length - 2));
    }
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
      // Create File from APNG Blob
      const file = new File([compiledBlob], `${stickerName.replace(/\s+/g, '_').toLowerCase()}.png`, {
        type: 'image/png',
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
      maxWidth="xl"
    >
      <div className="space-y-5">
        {errorMessage && (
          <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        {/* Input Name & Tag */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <Input
            label="Nama Stiker Animasi"
            placeholder="Misal: Goyang Jempol / Tepuk Tangan"
            value={stickerName}
            onChange={(e) => setStickerName(e.target.value)}
          />

          <Input
            label="Tag / Kata Kunci Reaksi (Opsional)"
            placeholder="Misal: thumbs_up / clap"
            value={stickerTag}
            onChange={(e) => setStickerTag(e.target.value)}
          />
        </div>

        {/* Mode Tabs: Frame Sequence vs Sprite Sheet */}
        <div className="flex items-center gap-1 bg-neutral-100 p-1 rounded-xl">
          <button
            type="button"
            onClick={() => setActiveTab('SEQUENCE')}
            className={`flex-1 flex items-center justify-center gap-2 py-1.5 text-xs font-semibold rounded-lg transition-all ${
              activeTab === 'SEQUENCE'
                ? 'bg-white text-neutral-900 shadow-xs'
                : 'text-neutral-500 hover:text-neutral-900'
            }`}
          >
            <Film className="w-3.5 h-3.5" />
            Urutan Frame (Multiple Images)
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('SPRITESHEET')}
            className={`flex-1 flex items-center justify-center gap-2 py-1.5 text-xs font-semibold rounded-lg transition-all ${
              activeTab === 'SPRITESHEET'
                ? 'bg-white text-neutral-900 shadow-xs'
                : 'text-neutral-500 hover:text-neutral-900'
            }`}
          >
            <Grid3X3 className="w-3.5 h-3.5" />
            Potong Frame Sheet (Sprite Sheet)
          </button>
        </div>

        {/* Upload Zone based on Tab */}
        {activeTab === 'SEQUENCE' ? (
          <div className="border-2 border-dashed border-neutral-200 rounded-xl p-4 text-center hover:border-neutral-400 transition-colors cursor-pointer relative bg-neutral-50/50">
            <input
              type="file"
              multiple
              accept="image/png,image/webp,image/apng,image/gif"
              onChange={handleUploadSequence}
              className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
            />
            <div className="space-y-1 text-neutral-500">
              <Upload className="w-5 h-5 mx-auto text-neutral-400" />
              <p className="text-xs font-semibold text-neutral-800">
                Pilih atau Geser Beberapa File Frame (PNG / WEBP)
              </p>
              <p className="text-[11px] text-neutral-400">
                Otomatis diurutkan berdasarkan penomoran nama file
              </p>
            </div>
          </div>
        ) : (
          <div className="space-y-3 bg-neutral-50 p-4 rounded-xl border border-neutral-200">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <label className="text-[11px] font-semibold text-neutral-700">Jumlah Kolom (Columns)</label>
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
                <label className="text-[11px] font-semibold text-neutral-700">Jumlah Baris (Rows)</label>
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

            <div className="border-2 border-dashed border-neutral-200 rounded-xl p-3 text-center hover:border-neutral-400 transition-colors cursor-pointer relative bg-white">
              <input
                type="file"
                accept="image/png,image/webp,image/jpeg"
                onChange={handleUploadSpriteSheet}
                className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
              />
              <div className="space-y-1 text-neutral-500">
                <Grid3X3 className="w-4 h-4 mx-auto text-neutral-400" />
                <p className="text-xs font-semibold text-neutral-800">
                  Unggah Gambar Sprite Sheet ({spriteCols}x{spriteRows} = {spriteCols * spriteRows} frame)
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Live Player & Controls Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 items-center bg-white rounded-xl border border-neutral-200/90 p-4 shadow-xs">
          {/* Canvas Player Box */}
          <div className="flex flex-col items-center justify-center p-3 rounded-xl bg-neutral-50 border border-neutral-100 min-h-[200px]">
            <canvas
              ref={playerCanvasRef}
              width={canvasSize}
              height={canvasSize}
              className="w-40 h-40 object-contain rounded-lg shadow-xs bg-white border border-neutral-200/70"
            />

            {frames.length > 0 && (
              <div className="flex items-center gap-2 mt-3">
                <button
                  type="button"
                  onClick={() => setIsPlaying(!isPlaying)}
                  className="p-1.5 rounded-lg bg-neutral-900 text-white hover:bg-neutral-800 transition-colors"
                  title={isPlaying ? 'Jeda' : 'Putar'}
                >
                  {isPlaying ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5" />}
                </button>
                <span className="text-[11px] font-mono text-neutral-500">
                  Frame {currentFrameIdx + 1} / {frames.length}
                </span>
              </div>
            )}
          </div>

          {/* Animation Settings Controls */}
          <div className="space-y-3.5">
            <div>
              <div className="flex items-center justify-between text-xs font-semibold text-neutral-700 mb-1.5">
                <span>Kecepatan Animasi: {fps} FPS</span>
                <span className="text-[11px] text-neutral-400 font-mono">
                  {Math.round(1000 / fps)}ms / frame
                </span>
              </div>
              <input
                type="range"
                min="4"
                max="30"
                step="1"
                value={fps}
                onChange={(e) => setFps(parseInt(e.target.value))}
                className="w-full h-1.5 bg-neutral-200 rounded-lg appearance-none cursor-pointer accent-neutral-900"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <label className="text-[11px] font-semibold text-neutral-700">Dimensi Ekspor</label>
                <select
                  value={canvasSize}
                  onChange={(e) => setCanvasSize(parseInt(e.target.value))}
                  className="w-full px-2.5 py-1.5 text-xs rounded-lg border border-neutral-200 bg-white"
                >
                  <option value="512">512 x 512 px (Standar)</option>
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
                  <option value="0">Tak Terbatas (Infinite)</option>
                  <option value="1">1 Kali Putar</option>
                  <option value="3">3 Kali Putar</option>
                </select>
              </div>
            </div>

            <div className="pt-2">
              <Button
                type="button"
                variant="outline"
                className="w-full"
                isLoading={isCompiling}
                disabled={frames.length === 0}
                onClick={handleCompileApng}
                icon={<Sparkles className="w-3.5 h-3.5 text-emerald-600" />}
              >
                {compiledBlob ? 'Kompilasi Ulang APNG' : 'Kompilasi ke APNG'}
              </Button>
            </div>
          </div>
        </div>

        {/* Frames Timeline Strip */}
        {frames.length > 0 && (
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-neutral-700">
                Urutan Frame ({frames.length} frame)
              </span>
              <span className="text-[10px] text-neutral-400">
                Gunakan panah untuk mengubah urutan frame
              </span>
            </div>

            <div className="flex items-center gap-2 overflow-x-auto pb-2 pt-1">
              {frames.map((frame, idx) => (
                <div
                  key={frame.id}
                  onClick={() => {
                    setIsPlaying(false);
                    setCurrentFrameIdx(idx);
                  }}
                  className={`flex-shrink-0 w-20 p-1.5 rounded-xl border bg-white cursor-pointer transition-all ${
                    currentFrameIdx === idx
                      ? 'border-neutral-900 ring-2 ring-neutral-200 shadow-xs'
                      : 'border-neutral-200 hover:border-neutral-300'
                  }`}
                >
                  <div className="h-16 rounded-lg bg-neutral-50 flex items-center justify-center overflow-hidden border border-neutral-100">
                    <img
                      src={frame.previewUrl}
                      alt={`Frame ${idx + 1}`}
                      className="max-h-full max-w-full object-contain"
                    />
                  </div>

                  <div className="flex items-center justify-between mt-1 text-[10px] text-neutral-500 font-mono">
                    <span>#{idx + 1}</span>
                    <div className="flex items-center gap-0.5">
                      {idx > 0 && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            moveFrame(idx, 'left');
                          }}
                          className="hover:text-neutral-900"
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
                          className="hover:text-neutral-900"
                        >
                          <ArrowRight className="w-3 h-3" />
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          deleteFrame(idx);
                        }}
                        className="hover:text-rose-600 ml-1"
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

        {/* Compiled APNG Status & Final Action */}
        <div className="flex items-center justify-between pt-4 border-t border-neutral-100">
          <div>
            {compiledBlob && (
              <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-full border border-emerald-200">
                <CheckCircle className="w-3.5 h-3.5" />
                APNG Terkompilasi ({Math.round(compiledBlob.size / 1024)} KB)
              </span>
            )}
          </div>

          <div className="flex items-center gap-2">
            <Button type="button" variant="outline" onClick={onClose}>
              Tutup
            </Button>
            <Button
              type="button"
              variant="primary"
              disabled={!compiledBlob || !stickerName.trim()}
              isLoading={isSaving}
              onClick={handleSaveSticker}
            >
              Simpan ke Paket Stiker
            </Button>
          </div>
        </div>
      </div>
    </Modal>
  );
}
