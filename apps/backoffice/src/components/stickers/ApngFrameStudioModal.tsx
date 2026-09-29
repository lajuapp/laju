import React, { useState, useEffect, useRef, useCallback } from 'react';
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
  Repeat,
  Scissors,
  Eye,
  Wand2,
  Anchor,
  Move,
  RefreshCw,
  Crosshair,
  ArrowUp,
  ArrowDown,
  X,
} from 'lucide-react';
import { Modal } from '../ui/Modal';
import { Button } from '../ui/Button';
import { Badge } from '../ui/Badge';
import { compileFramesToApng } from '../../utils/apngCompiler';
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
  sourceCanvas: HTMLCanvasElement; // Original un-shifted frame
  canvas: HTMLCanvasElement;       // Active rendered frame with offset
  previewUrl: string;
  offsetX: number;
  offsetY: number;
}

type AnchorMode = 'BOTTOM_CENTER' | 'CENTER';

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
  const [zoomLevel, setZoomLevel] = useState<number>(1);
  const [onionSkinEnabled, setOnionSkinEnabled] = useState(false);

  // Sprite Sheet Slicer State
  const [spriteImage, setSpriteImage] = useState<HTMLImageElement | null>(null);
  const [spriteDims, setSpriteDims] = useState<{ width: number; height: number }>({ width: 0, height: 0 });
  const [spriteCols, setSpriteCols] = useState(4);
  const [spriteRows, setSpriteRows] = useState(4);
  const [spriteMarginX, setSpriteMarginX] = useState(0);
  const [spriteMarginY, setSpriteMarginY] = useState(0);
  const [spriteSpacingX, setSpriteSpacingX] = useState(0);
  const [spriteSpacingY, setSpriteSpacingY] = useState(0);

  // Frames state
  const [frames, setFrames] = useState<FrameItem[]>([]);
  const [currentFrameIdx, setCurrentFrameIdx] = useState(0);
  const [isPlaying, setIsPlaying] = useState(true);

  // Auto-Stabilizer State
  const [anchorMode, setAnchorMode] = useState<AnchorMode>('BOTTOM_CENTER');
  const [isStabilizing, setIsStabilizing] = useState(false);

  // Compiled APNG
  const [compiledBlob, setCompiledBlob] = useState<Blob | null>(null);
  const [compiledUrl, setCompiledUrl] = useState<string | null>(null);
  const [isCompiling, setIsCompiling] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Canvas Refs
  const playerCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const animIntervalRef = useRef<number | null>(null);
  const spritePreviewCanvasRef = useRef<HTMLCanvasElement | null>(null);

  // Drag Nudge on Player Canvas Ref
  const isDraggingPlayerRef = useRef(false);
  const dragStartRef = useRef<{ x: number; y: number }>({ x: 0, y: 0 });

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
      setOnionSkinEnabled(false);
      setSpriteImage(null);
      setSpriteDims({ width: 0, height: 0 });
      setSpriteMarginX(0);
      setSpriteMarginY(0);
      setSpriteSpacingX(0);
      setSpriteSpacingY(0);
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

  // Render current frame (and optional Onion Skin) to player canvas
  useEffect(() => {
    if (!playerCanvasRef.current || frames.length === 0) return;
    const canvas = playerCanvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // 1. Draw Onion Skin (previous frame in translucent tint)
    if (onionSkinEnabled && frames.length > 1) {
      const prevIdx = (currentFrameIdx - 1 + frames.length) % frames.length;
      const prevFrame = frames[prevIdx];
      if (prevFrame) {
        ctx.save();
        ctx.globalAlpha = 0.35;
        ctx.drawImage(prevFrame.canvas, 0, 0, canvas.width, canvas.height);
        ctx.restore();
      }
    }

    // 2. Draw Active Frame
    const activeFrame = frames[currentFrameIdx];
    if (activeFrame) {
      ctx.drawImage(activeFrame.canvas, 0, 0, canvas.width, canvas.height);
    }
  }, [currentFrameIdx, frames, onionSkinEnabled]);

  // Re-render an individual frame canvas with its current offset
  const reRenderFrameCanvas = useCallback((source: HTMLCanvasElement, target: HTMLCanvasElement, ox: number, oy: number) => {
    const ctx = target.getContext('2d');
    if (!ctx) return;
    ctx.clearRect(0, 0, target.width, target.height);
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(source, ox, oy);
  }, []);

  // Update offset for the active frame
  const updateActiveFrameOffset = useCallback((deltaX: number, deltaY: number) => {
    if (frames.length === 0) return;
    setFrames((prev) => {
      const copy = [...prev];
      const frame = copy[currentFrameIdx];
      if (!frame) return prev;

      const newOx = frame.offsetX + deltaX;
      const newOy = frame.offsetY + deltaY;

      reRenderFrameCanvas(frame.sourceCanvas, frame.canvas, newOx, newOy);

      copy[currentFrameIdx] = {
        ...frame,
        offsetX: newOx,
        offsetY: newOy,
        previewUrl: frame.canvas.toDataURL('image/png'),
      };
      return copy;
    });
    setCompiledBlob(null);
    setCompiledUrl(null);
  }, [currentFrameIdx, frames.length, reRenderFrameCanvas]);

  // Set absolute offset for the active frame
  const setActiveFrameOffsetDirect = (ox: number, oy: number) => {
    if (frames.length === 0) return;
    setFrames((prev) => {
      const copy = [...prev];
      const frame = copy[currentFrameIdx];
      if (!frame) return prev;

      reRenderFrameCanvas(frame.sourceCanvas, frame.canvas, ox, oy);

      copy[currentFrameIdx] = {
        ...frame,
        offsetX: ox,
        offsetY: oy,
        previewUrl: frame.canvas.toDataURL('image/png'),
      };
      return copy;
    });
    setCompiledBlob(null);
    setCompiledUrl(null);
  };

  // Keyboard Arrow Keys listener for nudging active frame
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (document.activeElement?.tagName === 'INPUT' || document.activeElement?.tagName === 'SELECT') return;
      if (frames.length === 0) return;

      const step = e.shiftKey ? 5 : 1;
      let handled = false;

      if (e.key === 'ArrowLeft') {
        updateActiveFrameOffset(-step, 0);
        handled = true;
      } else if (e.key === 'ArrowRight') {
        updateActiveFrameOffset(step, 0);
        handled = true;
      } else if (e.key === 'ArrowUp') {
        updateActiveFrameOffset(0, -step);
        handled = true;
      } else if (e.key === 'ArrowDown') {
        updateActiveFrameOffset(0, step);
        handled = true;
      }

      if (handled) {
        e.preventDefault();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [frames.length, updateActiveFrameOffset]);

  // Direct Mouse Drag on Player Canvas to Nudge Frame
  const handlePlayerMouseDown = (e: React.MouseEvent) => {
    if (frames.length === 0) return;
    isDraggingPlayerRef.current = true;
    dragStartRef.current = { x: e.clientX, y: e.clientY };
  };

  const handlePlayerMouseMove = (e: React.MouseEvent) => {
    if (!isDraggingPlayerRef.current || frames.length === 0) return;
    const dx = Math.round((e.clientX - dragStartRef.current.x) / zoomLevel);
    const dy = Math.round((e.clientY - dragStartRef.current.y) / zoomLevel);

    if (dx !== 0 || dy !== 0) {
      updateActiveFrameOffset(dx, dy);
      dragStartRef.current = { x: e.clientX, y: e.clientY };
    }
  };

  const handlePlayerMouseUp = () => {
    isDraggingPlayerRef.current = false;
  };

  // Auto-Stabilizer Engine: Align characters across all frames
  const handleAutoStabilizeAll = () => {
    if (frames.length === 0) return;
    setIsStabilizing(true);
    setErrorMessage(null);

    setTimeout(() => {
      try {
        const boundsList: Array<{ minX: number; maxX: number; minY: number; maxY: number; hasContent: boolean }> = [];
        let globalMaxY = 0; // lowest bottom point

        // 1. Scan bounding boxes of each frame's content
        frames.forEach((f) => {
          const ctx = f.sourceCanvas.getContext('2d', { willReadFrequently: true });
          if (!ctx) {
            boundsList.push({ minX: 0, maxX: canvasSize, minY: 0, maxY: canvasSize, hasContent: false });
            return;
          }

          const imgData = ctx.getImageData(0, 0, canvasSize, canvasSize);
          const data = imgData.data;
          let minX = canvasSize, minY = canvasSize, maxX = 0, maxY = 0;
          let hasContent = false;

          for (let py = 0; py < canvasSize; py++) {
            for (let px = 0; px < canvasSize; px++) {
              const alpha = data[(py * canvasSize + px) * 4 + 3];
              if (alpha > 15) {
                hasContent = true;
                if (px < minX) minX = px;
                if (px > maxX) maxX = px;
                if (py < minY) minY = py;
                if (py > maxY) maxY = py;
              }
            }
          }

          if (hasContent && maxY > globalMaxY) {
            globalMaxY = maxY;
          }

          boundsList.push({ minX, maxX, minY, maxY, hasContent });
        });

        const targetCenterX = Math.round(canvasSize / 2);
        // Anchor baseline at 90% of canvas height so character sits grounded
        const targetBaselineY = Math.min(canvasSize - 24, Math.max(globalMaxY, Math.round(canvasSize * 0.9)));

        // 2. Compute shifts and re-render each frame
        const updatedFrames = frames.map((frame, idx) => {
          const b = boundsList[idx];
          if (!b || !b.hasContent) return frame;

          let targetXShift = 0;
          let targetYShift = 0;

          if (anchorMode === 'BOTTOM_CENTER') {
            // Center horizontally, anchor feet to same baseline
            const currentCenterX = Math.round((b.minX + b.maxX) / 2);
            targetXShift = targetCenterX - currentCenterX;
            targetYShift = targetBaselineY - b.maxY;
          } else {
            // Anchor Center: center of mass to canvas center
            const currentCenterX = Math.round((b.minX + b.maxX) / 2);
            const currentCenterY = Math.round((b.minY + b.maxY) / 2);
            targetXShift = targetCenterX - currentCenterX;
            targetYShift = Math.round(canvasSize / 2) - currentCenterY;
          }

          // Re-render
          reRenderFrameCanvas(frame.sourceCanvas, frame.canvas, targetXShift, targetYShift);

          return {
            ...frame,
            offsetX: targetXShift,
            offsetY: targetYShift,
            previewUrl: frame.canvas.toDataURL('image/png'),
          };
        });

        setFrames(updatedFrames);
        setCompiledBlob(null);
        setCompiledUrl(null);
      } catch (err: any) {
        setErrorMessage('Gagal menstabilkan posisi frame: ' + err.message);
      } finally {
        setIsStabilizing(false);
      }
    }, 50);
  };

  // Reset all frame offsets to 0
  const handleResetAllOffsets = () => {
    setFrames((prev) =>
      prev.map((f) => {
        reRenderFrameCanvas(f.sourceCanvas, f.canvas, 0, 0);
        return {
          ...f,
          offsetX: 0,
          offsetY: 0,
          previewUrl: f.canvas.toDataURL('image/png'),
        };
      })
    );
    setCompiledBlob(null);
    setCompiledUrl(null);
  };

  // Upload sequence of image files
  const handleUploadSequence = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || e.target.files.length === 0) return;

    const files = Array.from(e.target.files);
    files.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }));

    const newFrames: FrameItem[] = [];
    let loadedCount = 0;

    files.forEach((file) => {
      const img = new Image();
      const objectUrl = URL.createObjectURL(file);
      img.src = objectUrl;

      img.onload = () => {
        const srcCanvas = document.createElement('canvas');
        srcCanvas.width = canvasSize;
        srcCanvas.height = canvasSize;
        const srcCtx = srcCanvas.getContext('2d');
        if (srcCtx) {
          srcCtx.imageSmoothingEnabled = true;
          // Scale to fit canvas preserving aspect ratio
          const scale = Math.min((canvasSize * 0.9) / img.naturalWidth, (canvasSize * 0.9) / img.naturalHeight);
          const dw = img.naturalWidth * scale;
          const dh = img.naturalHeight * scale;
          const dx = (canvasSize - dw) / 2;
          const dy = (canvasSize - dh) / 2;
          srcCtx.drawImage(img, dx, dy, dw, dh);
        }

        const renderCanvas = document.createElement('canvas');
        renderCanvas.width = canvasSize;
        renderCanvas.height = canvasSize;
        const renderCtx = renderCanvas.getContext('2d');
        if (renderCtx) renderCtx.drawImage(srcCanvas, 0, 0);

        newFrames.push({
          id: Math.random().toString(36).substring(2, 9),
          sourceCanvas: srcCanvas,
          canvas: renderCanvas,
          previewUrl: renderCanvas.toDataURL('image/png'),
          offsetX: 0,
          offsetY: 0,
        });

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

  // Upload Sprite Sheet file & init visual sizer preview
  const handleUploadSpriteSheet = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0]) return;
    const file = e.target.files[0];
    const img = new Image();
    img.src = URL.createObjectURL(file);

    img.onload = () => {
      setSpriteImage(img);
      setSpriteDims({ width: img.naturalWidth, height: img.naturalHeight });
      if (!stickerName) {
        const baseName = file.name.replace(/\.[^/.]+$/, '');
        setStickerName(baseName);
      }
    };
  };

  // Redraw Sprite Sheet visual cutter preview
  useEffect(() => {
    if (!spriteImage || !spritePreviewCanvasRef.current) return;
    const canvas = spritePreviewCanvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    canvas.width = spriteDims.width;
    canvas.height = spriteDims.height;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(spriteImage, 0, 0);

    // Draw uniform grid lines
    const cellW = Math.max(8, Math.floor((spriteDims.width - spriteMarginX * 2 - (spriteCols - 1) * spriteSpacingX) / spriteCols));
    const cellH = Math.max(8, Math.floor((spriteDims.height - spriteMarginY * 2 - (spriteRows - 1) * spriteSpacingY) / spriteRows));

    ctx.strokeStyle = '#00C896';
    ctx.lineWidth = 2;
    ctx.setLineDash([4, 4]);

    for (let r = 0; r < spriteRows; r++) {
      for (let c = 0; c < spriteCols; c++) {
        const x = spriteMarginX + c * (cellW + spriteSpacingX);
        const y = spriteMarginY + r * (cellH + spriteSpacingY);
        ctx.strokeRect(x, y, cellW, cellH);

        // Frame badge
        ctx.fillStyle = 'rgba(0, 200, 150, 0.9)';
        ctx.fillRect(x, y, 20, 14);
        ctx.fillStyle = '#FFFFFF';
        ctx.font = 'bold 9px monospace';
        ctx.fillText(`${r * spriteCols + c + 1}`, x + 4, y + 10);
      }
    }
  }, [spriteImage, spriteDims, spriteCols, spriteRows, spriteMarginX, spriteMarginY, spriteSpacingX, spriteSpacingY]);

  // Execute Sprite Sheet Slicing with Uniform Frame Size
  const handleSliceUniformSpriteSheet = () => {
    if (!spriteImage) return;

    const cellW = Math.max(8, Math.floor((spriteDims.width - spriteMarginX * 2 - (spriteCols - 1) * spriteSpacingX) / spriteCols));
    const cellH = Math.max(8, Math.floor((spriteDims.height - spriteMarginY * 2 - (spriteRows - 1) * spriteSpacingY) / spriteRows));

    const newFrames: FrameItem[] = [];

    for (let r = 0; r < spriteRows; r++) {
      for (let c = 0; c < spriteCols; c++) {
        const sx = spriteMarginX + c * (cellW + spriteSpacingX);
        const sy = spriteMarginY + r * (cellH + spriteSpacingY);

        const srcCanvas = document.createElement('canvas');
        srcCanvas.width = canvasSize;
        srcCanvas.height = canvasSize;
        const srcCtx = srcCanvas.getContext('2d');

        if (srcCtx) {
          srcCtx.imageSmoothingEnabled = true;
          // Scale to fit canvas preserving aspect ratio
          const scale = Math.min((canvasSize * 0.88) / cellW, (canvasSize * 0.88) / cellH);
          const dw = cellW * scale;
          const dh = cellH * scale;
          const dx = (canvasSize - dw) / 2;
          const dy = (canvasSize - dh) / 2;
          srcCtx.drawImage(spriteImage, sx, sy, cellW, cellH, dx, dy, dw, dh);
        }

        const renderCanvas = document.createElement('canvas');
        renderCanvas.width = canvasSize;
        renderCanvas.height = canvasSize;
        const renderCtx = renderCanvas.getContext('2d');
        if (renderCtx) renderCtx.drawImage(srcCanvas, 0, 0);

        newFrames.push({
          id: Math.random().toString(36).substring(2, 9),
          sourceCanvas: srcCanvas,
          canvas: renderCanvas,
          previewUrl: renderCanvas.toDataURL('image/png'),
          offsetX: 0,
          offsetY: 0,
        });
      }
    }

    setFrames(newFrames);
    setCompiledBlob(null);
    setCompiledUrl(null);
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

      const clonedSrc = document.createElement('canvas');
      clonedSrc.width = canvasSize;
      clonedSrc.height = canvasSize;
      const sCtx = clonedSrc.getContext('2d');
      if (sCtx) sCtx.drawImage(original.sourceCanvas, 0, 0);

      const clonedRender = document.createElement('canvas');
      clonedRender.width = canvasSize;
      clonedRender.height = canvasSize;
      const rCtx = clonedRender.getContext('2d');
      if (rCtx) rCtx.drawImage(original.canvas, 0, 0);

      copy.splice(index + 1, 0, {
        id: Math.random().toString(36).substring(2, 9),
        sourceCanvas: clonedSrc,
        canvas: clonedRender,
        previewUrl: clonedRender.toDataURL('image/png'),
        offsetX: original.offsetX,
        offsetY: original.offsetY,
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

  // Timeline Tools: Boomerang / Ping-Pong
  const boomerangFrames = () => {
    if (frames.length < 2) return;
    const middleReversed = frames.slice(1, -1).reverse();
    const clonedReversed = middleReversed.map((f) => {
      const clonedSrc = document.createElement('canvas');
      clonedSrc.width = canvasSize;
      clonedSrc.height = canvasSize;
      const sCtx = clonedSrc.getContext('2d');
      if (sCtx) sCtx.drawImage(f.sourceCanvas, 0, 0);

      const clonedRender = document.createElement('canvas');
      clonedRender.width = canvasSize;
      clonedRender.height = canvasSize;
      const rCtx = clonedRender.getContext('2d');
      if (rCtx) rCtx.drawImage(f.canvas, 0, 0);

      return {
        id: Math.random().toString(36).substring(2, 9),
        sourceCanvas: clonedSrc,
        canvas: clonedRender,
        previewUrl: clonedRender.toDataURL('image/png'),
        offsetX: f.offsetX,
        offsetY: f.offsetY,
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

  const activeFrame = frames[currentFrameIdx] || null;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Studio Animasi APNG & Stabilizer Posisi Frame"
      description={`Stabilkan getaran animasi dan kompilasi stiker APNG mulus untuk paket "${packName}"`}
      maxWidth="7xl"
    >
      <div className="space-y-4 max-h-[88vh] overflow-y-auto pr-1">
        {errorMessage && (
          <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{errorMessage}</span>
            </div>
            <button type="button" onClick={() => setErrorMessage(null)} className="text-rose-500 hover:text-rose-700">
              <X className="w-4 h-4" />
            </button>
          </div>
        )}

        {/* Studio Workspace Layout: 2 Columns */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-start">
          {/* Left Column (5 cols): Interactive Live Viewport & Stabilizer Stage */}
          <div className="lg:col-span-5 space-y-3 bg-neutral-50/80 p-3.5 rounded-2xl border border-neutral-200/90 text-neutral-800">
            {/* Viewport Toolbar */}
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-neutral-800 flex items-center gap-1.5">
                <Film className="w-3.5 h-3.5 text-brand-600" />
                Live Animation Viewport
              </span>

              {/* Background Theme Switcher */}
              <div className="flex items-center gap-1 bg-white p-0.5 rounded-lg border border-neutral-200 text-[10px]">
                <button
                  type="button"
                  onClick={() => setStageBg('checker')}
                  className={`px-1.5 py-0.5 rounded font-semibold transition-all ${
                    stageBg === 'checker' ? 'bg-neutral-900 text-white shadow-2xs' : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Catur
                </button>
                <button
                  type="button"
                  onClick={() => setStageBg('light')}
                  className={`px-1.5 py-0.5 rounded font-semibold transition-all ${
                    stageBg === 'light' ? 'bg-neutral-900 text-white shadow-2xs' : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Putih
                </button>
                <button
                  type="button"
                  onClick={() => setStageBg('dark')}
                  className={`px-1.5 py-0.5 rounded font-semibold transition-all ${
                    stageBg === 'dark' ? 'bg-neutral-900 text-white shadow-2xs' : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Gelap
                </button>
              </div>
            </div>

            {/* Live Canvas Viewport Box with Onion Skinning & Mouse Drag */}
            <div
              onMouseDown={handlePlayerMouseDown}
              onMouseMove={handlePlayerMouseMove}
              onMouseUp={handlePlayerMouseUp}
              className="w-full h-64 rounded-2xl border border-neutral-200/90 flex items-center justify-center p-3 relative overflow-hidden select-none cursor-move"
              style={{
                backgroundColor: stageBg === 'dark' ? '#0F172A' : '#ffffff',
                backgroundImage:
                  stageBg === 'checker'
                    ? 'linear-gradient(45deg, #f1f5f9 25%, transparent 25%), linear-gradient(-45deg, #f1f5f9 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f1f5f9 75%), linear-gradient(-45deg, transparent 75%, #f1f5f9 75%)'
                    : undefined,
                backgroundSize: '16px 16px',
                backgroundPosition: '0 0, 0 8px, 8px -8px, -8px 0px',
              }}
              title="Klik dan seret karakter langsung pada kanvas untuk menggeser posisinya (Nudge Offset)"
            >
              {frames.length > 0 ? (
                <>
                  <canvas
                    ref={playerCanvasRef}
                    width={canvasSize}
                    height={canvasSize}
                    className="max-h-full max-w-full object-contain filter drop-shadow-md pointer-events-none transition-transform duration-75"
                    style={{ transform: `scale(${zoomLevel})` }}
                  />

                  {/* Onion Skin Indicator Tag */}
                  {onionSkinEnabled && (
                    <div className="absolute top-2 left-2 px-2 py-0.5 bg-rose-500/80 text-white text-[9px] font-bold rounded-md shadow-xs pointer-events-none">
                      Onion Skin Aktif
                    </div>
                  )}

                  {/* Offset Overlay Tag */}
                  {activeFrame && (activeFrame.offsetX !== 0 || activeFrame.offsetY !== 0) && (
                    <div className="absolute bottom-2 left-2 px-2 py-0.5 bg-neutral-900/80 text-white font-mono text-[9px] rounded-md shadow-xs pointer-events-none">
                      Offset: {activeFrame.offsetX > 0 ? `+${activeFrame.offsetX}` : activeFrame.offsetX},{' '}
                      {activeFrame.offsetY > 0 ? `+${activeFrame.offsetY}` : activeFrame.offsetY} px
                    </div>
                  )}
                </>
              ) : (
                <div className="text-center text-neutral-400 space-y-1">
                  <Film className="w-8 h-8 mx-auto text-neutral-300" />
                  <p className="text-xs font-semibold text-neutral-700">Belum ada frame animasi</p>
                  <p className="text-[10px] text-neutral-400">Unggah frame atau sprite sheet di panel sebelah kanan</p>
                </div>
              )}
            </div>

            {/* Viewport Action Bar: Onion Skinning & Zoom */}
            <div className="flex items-center justify-between bg-white px-3 py-2 rounded-xl border border-neutral-200 text-xs">
              {/* Onion Skin Toggle */}
              <button
                type="button"
                onClick={() => setOnionSkinEnabled(!onionSkinEnabled)}
                className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg font-semibold transition-all ${
                  onionSkinEnabled
                    ? 'bg-brand-50 border border-brand-300 text-brand-700'
                    : 'bg-neutral-50 text-neutral-600 border border-neutral-200 hover:bg-neutral-100'
                }`}
                title="Tampilkan bayangan frame sebelumnya untuk mencocokkan garis kaki & badan"
              >
                <Eye className="w-3.5 h-3.5 text-brand-600" />
                <span>Onion Skinning</span>
              </button>

              {/* Zoom Selector */}
              <div className="flex items-center gap-1">
                <span className="text-[10px] text-neutral-400">Zoom:</span>
                <div className="flex items-center bg-neutral-100 rounded-lg p-0.5 text-[10px]">
                  {[1, 1.25, 1.5].map((z) => (
                    <button
                      key={z}
                      type="button"
                      onClick={() => setZoomLevel(z)}
                      className={`px-1.5 py-0.5 rounded font-semibold ${zoomLevel === z ? 'bg-white shadow-2xs' : 'text-neutral-500'}`}
                    >
                      {z}x
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Transport Scrub Bar */}
            <div className="bg-white p-3 rounded-xl border border-neutral-200 space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1">
                  <button
                    type="button"
                    onClick={() => {
                      setIsPlaying(false);
                      setCurrentFrameIdx(0);
                    }}
                    disabled={frames.length === 0}
                    className="p-1 rounded-lg text-neutral-600 hover:bg-neutral-100 disabled:opacity-40"
                    title="Ke Frame Pertama"
                  >
                    <SkipBack className="w-3.5 h-3.5" />
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setIsPlaying(false);
                      setCurrentFrameIdx((prev) => (prev > 0 ? prev - 1 : frames.length - 1));
                    }}
                    disabled={frames.length === 0}
                    className="p-1 rounded-lg text-neutral-600 hover:bg-neutral-100 disabled:opacity-40"
                    title="Frame Sebelumnya"
                  >
                    <ArrowLeft className="w-3.5 h-3.5" />
                  </button>

                  <button
                    type="button"
                    onClick={() => setIsPlaying(!isPlaying)}
                    disabled={frames.length === 0}
                    className="p-1.5 rounded-lg bg-brand-500 text-white hover:bg-brand-600 disabled:opacity-40 shadow-xs"
                    title={isPlaying ? 'Jeda Animasi' : 'Putar Animasi'}
                  >
                    {isPlaying ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5" />}
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setIsPlaying(false);
                      setCurrentFrameIdx((prev) => (prev + 1) % frames.length);
                    }}
                    disabled={frames.length === 0}
                    className="p-1 rounded-lg text-neutral-600 hover:bg-neutral-100 disabled:opacity-40"
                    title="Frame Berikutnya"
                  >
                    <ArrowRight className="w-3.5 h-3.5" />
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setIsPlaying(false);
                      setCurrentFrameIdx(Math.max(0, frames.length - 1));
                    }}
                    disabled={frames.length === 0}
                    className="p-1 rounded-lg text-neutral-600 hover:bg-neutral-100 disabled:opacity-40"
                    title="Ke Frame Terakhir"
                  >
                    <SkipForward className="w-3.5 h-3.5" />
                  </button>
                </div>

                <span className="text-xs font-mono font-bold text-neutral-700 bg-neutral-100 px-2 py-0.5 rounded-md">
                  Frame {frames.length > 0 ? currentFrameIdx + 1 : 0} / {frames.length}
                </span>
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
                  className="w-full accent-brand-500 h-1.5 bg-neutral-200 rounded-lg cursor-pointer"
                />
              )}
            </div>

            {/* Manual Frame Position Nudge Inspector */}
            {activeFrame && (
              <div className="bg-white p-3 rounded-xl border border-neutral-200 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] font-bold text-neutral-700 flex items-center gap-1.5 uppercase tracking-wider">
                    <Move className="w-3 h-3 text-brand-600" />
                    Koreksi Posisi Frame #{currentFrameIdx + 1}
                  </span>
                  <button
                    type="button"
                    onClick={() => setActiveFrameOffsetDirect(0, 0)}
                    className="text-[10px] text-neutral-400 hover:text-neutral-700 underline"
                  >
                    Reset (0,0)
                  </button>
                </div>

                <div className="flex items-center justify-between gap-3 text-xs">
                  {/* Nudge Buttons */}
                  <div className="flex items-center gap-1">
                    <button
                      type="button"
                      onClick={() => updateActiveFrameOffset(-1, 0)}
                      className="p-1.5 rounded-lg bg-neutral-100 hover:bg-neutral-200 text-neutral-700"
                      title="Geser Kiri (1px)"
                    >
                      <ArrowLeft className="w-3 h-3" />
                    </button>
                    <button
                      type="button"
                      onClick={() => updateActiveFrameOffset(0, -1)}
                      className="p-1.5 rounded-lg bg-neutral-100 hover:bg-neutral-200 text-neutral-700"
                      title="Geser Atas (1px)"
                    >
                      <ArrowUp className="w-3 h-3" />
                    </button>
                    <button
                      type="button"
                      onClick={() => updateActiveFrameOffset(0, 1)}
                      className="p-1.5 rounded-lg bg-neutral-100 hover:bg-neutral-200 text-neutral-700"
                      title="Geser Bawah (1px)"
                    >
                      <ArrowDown className="w-3 h-3" />
                    </button>
                    <button
                      type="button"
                      onClick={() => updateActiveFrameOffset(1, 0)}
                      className="p-1.5 rounded-lg bg-neutral-100 hover:bg-neutral-200 text-neutral-700"
                      title="Geser Kanan (1px)"
                    >
                      <ArrowRight className="w-3 h-3" />
                    </button>
                  </div>

                  {/* Offset Inputs */}
                  <div className="flex items-center gap-2 font-mono text-[11px]">
                    <div className="flex items-center gap-1 bg-neutral-50 px-2 py-1 rounded border border-neutral-200">
                      <span className="text-neutral-400">X:</span>
                      <input
                        type="number"
                        value={activeFrame.offsetX}
                        onChange={(e) => setActiveFrameOffsetDirect(parseInt(e.target.value) || 0, activeFrame.offsetY)}
                        className="w-10 bg-transparent font-bold text-neutral-800 text-right"
                      />
                    </div>
                    <div className="flex items-center gap-1 bg-neutral-50 px-2 py-1 rounded border border-neutral-200">
                      <span className="text-neutral-400">Y:</span>
                      <input
                        type="number"
                        value={activeFrame.offsetY}
                        onChange={(e) => setActiveFrameOffsetDirect(activeFrame.offsetX, parseInt(e.target.value) || 0)}
                        className="w-10 bg-transparent font-bold text-neutral-800 text-right"
                      />
                    </div>
                  </div>
                </div>
                <p className="text-[10px] text-neutral-400">
                  Tip: Gunakan tombol panah keyboard (Arrow keys) untuk menggeser 1px, atau Shift + Arrow untuk 5px.
                </p>
              </div>
            )}
          </div>

          {/* Right Column (7 cols): Auto-Stabilizer, Slicer & Timeline Settings */}
          <div className="lg:col-span-7 space-y-3.5">
            {/* Input Name & Tag */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 bg-neutral-50/80 p-3 rounded-xl border border-neutral-200">
              <div className="space-y-1">
                <label className="text-xs font-bold text-neutral-800">Nama Stiker Animasi</label>
                <input
                  type="text"
                  placeholder="Misal: Joget_Gembira / Kucing_Lucu"
                  value={stickerName}
                  onChange={(e) => setStickerName(e.target.value)}
                  className="w-full px-3 py-1.5 text-xs rounded-lg border border-neutral-200 bg-white font-medium"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-neutral-800">Tag / Reaksi Emoji</label>
                <input
                  type="text"
                  placeholder="Misal: dance / happy / cat"
                  value={stickerTag}
                  onChange={(e) => setStickerTag(e.target.value)}
                  className="w-full px-3 py-1.5 text-xs rounded-lg border border-neutral-200 bg-white"
                />
              </div>
            </div>

            {/* Auto-Stabilizer Box (Solusi Utama Jitter / Goyang) */}
            <div className="p-3.5 rounded-2xl bg-brand-50/50 border border-brand-200 space-y-2.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5">
                  <Anchor className="w-4 h-4 text-brand-600" />
                  <span className="text-xs font-bold text-brand-900">
                    Auto-Stabilizer Posisi (Kunci Titik Tumpu)
                  </span>
                </div>
                <div className="flex items-center gap-1 bg-white p-0.5 rounded-lg border border-brand-200 text-[11px]">
                  <button
                    type="button"
                    onClick={() => setAnchorMode('BOTTOM_CENTER')}
                    className={`px-2 py-0.5 rounded font-semibold transition-all ${
                      anchorMode === 'BOTTOM_CENTER' ? 'bg-brand-500 text-white shadow-2xs' : 'text-neutral-600'
                    }`}
                    title="Kunci garis kaki/tanah agar karakter tidak naik-turun"
                  >
                    Kaki / Bawah
                  </button>
                  <button
                    type="button"
                    onClick={() => setAnchorMode('CENTER')}
                    className={`px-2 py-0.5 rounded font-semibold transition-all ${
                      anchorMode === 'CENTER' ? 'bg-brand-500 text-white shadow-2xs' : 'text-neutral-600'
                    }`}
                    title="Pusatkan objek ke tengah kanvas (untuk icon/logo melayang)"
                  >
                    Pusat / Tengah
                  </button>
                </div>
              </div>

              <p className="text-[11px] text-neutral-600">
                Menyelaraskan seluruh frame agar titik tumpu karakter terkunci pada garis yang sama, melenyapkan animasi goyang (jitter/wobble) secara instan.
              </p>

              <div className="flex items-center gap-2">
                <Button
                  type="button"
                  size="sm"
                  variant="primary"
                  className="bg-brand-500 hover:bg-brand-600 text-white font-bold"
                  disabled={frames.length === 0 || isStabilizing}
                  isLoading={isStabilizing}
                  onClick={handleAutoStabilizeAll}
                  icon={<Sparkles className="w-3.5 h-3.5" />}
                >
                  ⚡ Auto-Stabilize Semua Frame
                </Button>

                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  disabled={frames.length === 0}
                  onClick={handleResetAllOffsets}
                >
                  Reset Offset
                </Button>
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
                      ? 'border-brand-600 text-brand-700'
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
                      ? 'border-brand-600 text-brand-700'
                      : 'border-transparent text-neutral-500 hover:text-neutral-800'
                  }`}
                >
                  <Grid3X3 className="w-3.5 h-3.5" />
                  Pemotong Sprite Sheet Seragam
                </button>
              </div>

              <Badge variant="neutral" size="sm">
                {frames.length} Frame Aktif
              </Badge>
            </div>

            {/* Upload Area depending on Active Tab */}
            {activeTab === 'SEQUENCE' ? (
              <div className="border-2 border-dashed border-neutral-300 rounded-2xl p-5 text-center hover:border-brand-500 transition-colors cursor-pointer relative bg-neutral-50/50">
                <input
                  type="file"
                  multiple
                  accept="image/png,image/webp,image/apng,image/gif"
                  onChange={handleUploadSequence}
                  className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                />
                <div className="space-y-1.5 text-neutral-600">
                  <Upload className="w-6 h-6 mx-auto text-brand-600" />
                  <p className="text-xs font-bold text-neutral-800">
                    Pilih File Frame Sekaligus (PNG / WEBP Transparan)
                  </p>
                  <p className="text-[11px] text-neutral-400">
                    Otomatis diurutkan berdasarkan penomoran nama file (misal: walk_01.png, walk_02.png)
                  </p>
                </div>
              </div>
            ) : (
              <div className="space-y-3 bg-neutral-50/80 p-3.5 rounded-2xl border border-neutral-200">
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
                  <div className="space-y-0.5">
                    <label className="text-[10px] font-semibold text-neutral-600">Kolom</label>
                    <input
                      type="number"
                      min="1"
                      max="16"
                      value={spriteCols}
                      onChange={(e) => setSpriteCols(Math.max(1, parseInt(e.target.value) || 1))}
                      className="w-full px-2 py-1 text-xs font-bold rounded-lg border border-neutral-200 bg-white"
                    />
                  </div>
                  <div className="space-y-0.5">
                    <label className="text-[10px] font-semibold text-neutral-600">Baris</label>
                    <input
                      type="number"
                      min="1"
                      max="16"
                      value={spriteRows}
                      onChange={(e) => setSpriteRows(Math.max(1, parseInt(e.target.value) || 1))}
                      className="w-full px-2 py-1 text-xs font-bold rounded-lg border border-neutral-200 bg-white"
                    />
                  </div>
                  <div className="space-y-0.5">
                    <label className="text-[10px] font-semibold text-neutral-600">Margin X / Y</label>
                    <div className="flex gap-1">
                      <input
                        type="number"
                        min="0"
                        value={spriteMarginX}
                        onChange={(e) => setSpriteMarginX(Math.max(0, parseInt(e.target.value) || 0))}
                        className="w-1/2 px-1.5 py-1 text-xs rounded border border-neutral-200 bg-white"
                        placeholder="MX"
                      />
                      <input
                        type="number"
                        min="0"
                        value={spriteMarginY}
                        onChange={(e) => setSpriteMarginY(Math.max(0, parseInt(e.target.value) || 0))}
                        className="w-1/2 px-1.5 py-1 text-xs rounded border border-neutral-200 bg-white"
                        placeholder="MY"
                      />
                    </div>
                  </div>
                  <div className="space-y-0.5">
                    <label className="text-[10px] font-semibold text-neutral-600">Spasi X / Y</label>
                    <div className="flex gap-1">
                      <input
                        type="number"
                        min="0"
                        value={spriteSpacingX}
                        onChange={(e) => setSpriteSpacingX(Math.max(0, parseInt(e.target.value) || 0))}
                        className="w-1/2 px-1.5 py-1 text-xs rounded border border-neutral-200 bg-white"
                        placeholder="SX"
                      />
                      <input
                        type="number"
                        min="0"
                        value={spriteSpacingY}
                        onChange={(e) => setSpriteSpacingY(Math.max(0, parseInt(e.target.value) || 0))}
                        className="w-1/2 px-1.5 py-1 text-xs rounded border border-neutral-200 bg-white"
                        placeholder="SY"
                      />
                    </div>
                  </div>
                </div>

                {/* Sprite Upload / Visual Preview */}
                {!spriteImage ? (
                  <div className="border-2 border-dashed border-neutral-300 rounded-xl p-3 text-center hover:border-brand-500 transition-colors cursor-pointer relative bg-white">
                    <input
                      type="file"
                      accept="image/png,image/webp,image/jpeg"
                      onChange={handleUploadSpriteSheet}
                      className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                    />
                    <div className="space-y-1 text-neutral-600">
                      <Scissors className="w-5 h-5 mx-auto text-brand-600" />
                      <p className="text-xs font-bold text-neutral-800">
                        Unggah Sprite Sheet Animasi ({spriteCols}x{spriteRows} Frame)
                      </p>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-2">
                    <div className="max-h-36 overflow-auto border border-neutral-200 rounded-xl bg-white p-2 flex items-center justify-center">
                      <canvas ref={spritePreviewCanvasRef} className="max-w-full max-h-32 object-contain" />
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="text-[11px] text-neutral-500 font-mono">
                        {spriteDims.width}x{spriteDims.height} px • {spriteCols * spriteRows} frame seragam
                      </span>
                      <Button
                        type="button"
                        size="sm"
                        variant="primary"
                        className="bg-brand-500 hover:bg-brand-600 text-white font-bold"
                        onClick={handleSliceUniformSpriteSheet}
                        icon={<Scissors className="w-3.5 h-3.5" />}
                      >
                        Potong Menjadi {spriteCols * spriteRows} Frame Animasi
                      </Button>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Animation Speed & Compilation Settings */}
            <div className="bg-neutral-50/80 p-3.5 rounded-2xl border border-neutral-200 space-y-3">
              <div>
                <div className="flex items-center justify-between text-xs font-bold text-neutral-800 mb-1">
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
                            ? 'bg-brand-500 text-white border-brand-500'
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
                  className="w-full accent-brand-500 h-1.5 bg-neutral-200 rounded-lg cursor-pointer"
                />
              </div>

              <div className="grid grid-cols-2 gap-3 pt-1">
                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-neutral-700">Dimensi Target</label>
                  <select
                    value={canvasSize}
                    onChange={(e) => setCanvasSize(parseInt(e.target.value))}
                    className="w-full px-2.5 py-1 text-xs rounded-lg border border-neutral-200 bg-white"
                  >
                    <option value="512">512 x 512 px (Standar Optimal LAJU)</option>
                    <option value="256">256 x 256 px (Kecil)</option>
                  </select>
                </div>

                <div className="space-y-1">
                  <label className="text-[11px] font-semibold text-neutral-700">Perulangan (Loop)</label>
                  <select
                    value={loopCount}
                    onChange={(e) => setLoopCount(parseInt(e.target.value))}
                    className="w-full px-2.5 py-1 text-xs rounded-lg border border-neutral-200 bg-white"
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
                  icon={<Repeat className="w-3.5 h-3.5 text-brand-600" />}
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
                    Kosongkan Frame
                  </Button>
                )}
              </div>

              {/* Compile Button */}
              <Button
                type="button"
                variant="primary"
                className="w-full py-2.5 bg-brand-500 hover:bg-brand-600 text-white font-bold"
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
          <div className="space-y-2 pt-2 border-t border-neutral-200">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-neutral-800">
                Timeline Urutan Frame ({frames.length} Frame)
              </span>
              <span className="text-[11px] text-neutral-400">
                Pilih frame untuk koreksi posisi per-frame • Geser urutan dengan tombol panah
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
                  className={`flex-shrink-0 w-24 p-2 rounded-2xl border bg-white cursor-pointer transition-all ${
                    currentFrameIdx === idx
                      ? 'border-brand-500 ring-2 ring-brand-200 shadow-sm'
                      : 'border-neutral-200 hover:border-neutral-300'
                  }`}
                >
                  <div
                    className="h-16 rounded-xl flex items-center justify-center overflow-hidden border border-neutral-100"
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
                        className="p-0.5 rounded hover:bg-neutral-100 text-brand-600"
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
        <div className="flex items-center justify-between pt-3 border-t border-neutral-100">
          <Button type="button" variant="outline" onClick={onClose} disabled={isSaving}>
            Tutup
          </Button>

          <Button
            type="button"
            variant="primary"
            className="bg-brand-500 hover:bg-brand-600 text-white font-bold"
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
