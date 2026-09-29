import React, { useState, useEffect, useRef } from 'react';
import {
  Grid,
  Scissors,
  Upload,
  CheckCircle,
  AlertCircle,
  Sparkles,
  Layers,
  Sliders,
  Eye,
  Check,
  X,
  RefreshCw,
  FolderDown,
  Trash2,
} from 'lucide-react';
import { Modal } from '../ui/Modal';
import { Button } from '../ui/Button';
import { Badge } from '../ui/Badge';
import { useMediaUpload } from '../../hooks/useMediaUpload';
import { useAddBulkStickers } from '../../hooks/useStickers';

interface SpriteSheetExtractorModalProps {
  isOpen: boolean;
  onClose: () => void;
  packId: string;
  packName: string;
}

interface SlicedStickerItem {
  id: string;
  canvas: HTMLCanvasElement;
  previewUrl: string;
  name: string;
  emoji: string;
  selected: boolean;
  isEmpty: boolean;
}

export function SpriteSheetExtractorModal({
  isOpen,
  onClose,
  packId,
  packName,
}: SpriteSheetExtractorModalProps) {
  const mediaUpload = useMediaUpload();
  const addBulkStickers = useAddBulkStickers();

  // Sprite Sheet Image State
  const [sheetFile, setSheetFile] = useState<File | null>(null);
  const [sheetImage, setSheetImage] = useState<HTMLImageElement | null>(null);
  const [sheetDimensions, setSheetDimensions] = useState<{ width: number; height: number }>({ width: 0, height: 0 });

  // Grid Configuration (Phaser style)
  const [sliceMode, setSliceMode] = useState<'GRID' | 'DIMENSIONS'>('GRID');
  const [cols, setCols] = useState(4);
  const [rows, setRows] = useState(4);
  const [frameWidth, setFrameWidth] = useState(128);
  const [frameHeight, setFrameHeight] = useState(128);
  const [marginX, setMarginX] = useState(0);
  const [marginY, setMarginY] = useState(0);
  const [spacingX, setSpacingX] = useState(0);
  const [spacingY, setSpacingY] = useState(0);

  // Processing Options
  const [autoTrim, setAutoTrim] = useState(true);
  const [targetSize, setTargetSize] = useState(512);
  const [namePrefix, setNamePrefix] = useState('Stiker');

  // Slices State
  const [slices, setSlices] = useState<SlicedStickerItem[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState({ current: 0, total: 0 });
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Canvas Refs
  const gridOverlayCanvasRef = useRef<HTMLCanvasElement | null>(null);

  // Reset when modal opens
  useEffect(() => {
    if (isOpen) {
      setSheetFile(null);
      setSheetImage(null);
      setSheetDimensions({ width: 0, height: 0 });
      setSlices([]);
      setErrorMessage(null);
      setIsUploading(false);
      setNamePrefix(packName.replace(/\s+/g, '_'));
    }
  }, [isOpen, packName]);

  // Handle Sprite Sheet File Upload
  const handleSheetUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0]) return;
    const file = e.target.files[0];
    setSheetFile(file);
    setErrorMessage(null);

    const img = new Image();
    img.src = URL.createObjectURL(file);
    img.onload = () => {
      setSheetImage(img);
      setSheetDimensions({ width: img.naturalWidth, height: img.naturalHeight });

      // Suggest reasonable cols & rows based on aspect ratio
      const w = img.naturalWidth;
      const h = img.naturalHeight;
      if (w === h) {
        setCols(4);
        setRows(4);
      } else if (w > h) {
        const aspect = Math.round(w / h);
        setCols(aspect * 3);
        setRows(3);
      }
    };
  };

  // Redraw Interactive Grid Overlay when settings or image changes
  useEffect(() => {
    if (!sheetImage || !gridOverlayCanvasRef.current) return;
    const canvas = gridOverlayCanvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    canvas.width = sheetDimensions.width;
    canvas.height = sheetDimensions.height;

    // Draw the source sprite sheet
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(sheetImage, 0, 0);

    // Draw cutting grid overlay lines (Phaser style)
    const computedCols = sliceMode === 'GRID' ? cols : Math.floor((sheetDimensions.width - marginX) / (frameWidth + spacingX));
    const computedRows = sliceMode === 'GRID' ? rows : Math.floor((sheetDimensions.height - marginY) / (frameHeight + spacingY));

    const cellW = sliceMode === 'GRID'
      ? Math.floor((sheetDimensions.width - marginX * 2 - (cols - 1) * spacingX) / cols)
      : frameWidth;
    const cellH = sliceMode === 'GRID'
      ? Math.floor((sheetDimensions.height - marginY * 2 - (rows - 1) * spacingY) / rows)
      : frameHeight;

    ctx.strokeStyle = '#06B6D4'; // Cyan grid
    ctx.lineWidth = 2;
    ctx.setLineDash([4, 4]);

    for (let r = 0; r < computedRows; r++) {
      for (let c = 0; c < computedCols; c++) {
        const x = marginX + c * (cellW + spacingX);
        const y = marginY + r * (cellH + spacingY);

        ctx.strokeRect(x, y, cellW, cellH);

        // Cell number watermark
        ctx.fillStyle = 'rgba(6, 182, 212, 0.85)';
        ctx.font = 'bold 12px monospace';
        ctx.fillText(`${r * computedCols + c + 1}`, x + 6, y + 16);
      }
    }
  }, [sheetImage, sheetDimensions, sliceMode, cols, rows, frameWidth, frameHeight, marginX, marginY, spacingX, spacingY]);

  // Execute Sprite Slicing & Auto-trim
  const handleExtractSlices = () => {
    if (!sheetImage) {
      setErrorMessage('Unggah gambar sprite sheet terlebih dahulu');
      return;
    }

    setIsProcessing(true);
    setErrorMessage(null);

    try {
      const computedCols = sliceMode === 'GRID' ? cols : Math.floor((sheetDimensions.width - marginX) / (frameWidth + spacingX));
      const computedRows = sliceMode === 'GRID' ? rows : Math.floor((sheetDimensions.height - marginY) / (frameHeight + spacingY));

      const cellW = sliceMode === 'GRID'
        ? Math.floor((sheetDimensions.width - marginX * 2 - (cols - 1) * spacingX) / cols)
        : frameWidth;
      const cellH = sliceMode === 'GRID'
        ? Math.floor((sheetDimensions.height - marginY * 2 - (rows - 1) * spacingY) / rows)
        : frameHeight;

      const newSlices: SlicedStickerItem[] = [];

      for (let r = 0; r < computedRows; r++) {
        for (let c = 0; c < computedCols; c++) {
          const srcX = marginX + c * (cellW + spacingX);
          const srcY = marginY + r * (cellH + spacingY);

          // Extract single cell
          const cellCanvas = document.createElement('canvas');
          cellCanvas.width = cellW;
          cellCanvas.height = cellH;
          const cellCtx = cellCanvas.getContext('2d', { willReadFrequently: true });
          if (!cellCtx) continue;

          cellCtx.drawImage(sheetImage, srcX, srcY, cellW, cellH, 0, 0, cellW, cellH);

          // Check if frame is empty / completely transparent
          const imgData = cellCtx.getImageData(0, 0, cellW, cellH);
          let hasContent = false;
          let minX = cellW, minY = cellH, maxX = 0, maxY = 0;

          for (let py = 0; py < cellH; py++) {
            for (let px = 0; px < cellW; px++) {
              const idx = (py * cellW + px) * 4;
              const alpha = imgData.data[idx + 3];
              if (alpha > 10) {
                hasContent = true;
                if (px < minX) minX = px;
                if (px > maxX) maxX = px;
                if (py < minY) minY = py;
                if (py > maxY) maxY = py;
              }
            }
          }

          // Target sticker canvas (standard 512x512)
          const targetCanvas = document.createElement('canvas');
          targetCanvas.width = targetSize;
          targetCanvas.height = targetSize;
          const targetCtx = targetCanvas.getContext('2d');
          if (!targetCtx) continue;

          targetCtx.imageSmoothingEnabled = true;
          targetCtx.imageSmoothingQuality = 'high';

          if (hasContent && autoTrim && maxX >= minX && maxY >= minY) {
            // Trim whitespace and fit neatly into targetSize
            const trimmedW = maxX - minX + 1;
            const trimmedH = maxY - minY + 1;
            const scale = Math.min((targetSize * 0.88) / trimmedW, (targetSize * 0.88) / trimmedH);
            const drawW = trimmedW * scale;
            const drawH = trimmedH * scale;
            const drawX = (targetSize - drawW) / 2;
            const drawY = (targetSize - drawH) / 2;

            targetCtx.drawImage(cellCanvas, minX, minY, trimmedW, trimmedH, drawX, drawY, drawW, drawH);
          } else {
            // Simple center fit
            const scale = Math.min(targetSize / cellW, targetSize / cellH);
            const drawW = cellW * scale;
            const drawH = cellH * scale;
            const drawX = (targetSize - drawW) / 2;
            const drawY = (targetSize - drawH) / 2;
            targetCtx.drawImage(cellCanvas, 0, 0, cellW, cellH, drawX, drawY, drawW, drawH);
          }

          const indexNumber = newSlices.length + 1;
          newSlices.push({
            id: Math.random().toString(36).substring(2, 9),
            canvas: targetCanvas,
            previewUrl: targetCanvas.toDataURL('image/png'),
            name: `${namePrefix} ${indexNumber}`,
            emoji: '',
            selected: hasContent, // automatically unselect empty transparent cells
            isEmpty: !hasContent,
          });
        }
      }

      setSlices(newSlices);
    } catch (err: any) {
      setErrorMessage('Gagal memproses sprite sheet: ' + err.message);
    } finally {
      setIsProcessing(false);
    }
  };

  // Toggle selection
  const toggleSelect = (index: number) => {
    setSlices((prev) => {
      const copy = [...prev];
      copy[index] = { ...copy[index], selected: !copy[index].selected };
      return copy;
    });
  };

  // Select all or Deselect all
  const selectAll = (select: boolean) => {
    setSlices((prev) => prev.map((s) => ({ ...s, selected: select && !s.isEmpty })));
  };

  // Update Slice Name / Tag
  const updateSlice = (index: number, field: 'name' | 'emoji', value: string) => {
    setSlices((prev) => {
      const copy = [...prev];
      copy[index] = { ...copy[index], [field]: value };
      return copy;
    });
  };

  // Apply Prefix to all selected slices
  const applyPrefixToAll = () => {
    setSlices((prev) => {
      let counter = 1;
      return prev.map((s) => ({
        ...s,
        name: s.selected ? `${namePrefix} ${counter++}` : s.name,
      }));
    });
  };

  // Execute Upload All Selected Slices to Backend
  const handleUploadAll = async () => {
    const selectedSlices = slices.filter((s) => s.selected);
    if (selectedSlices.length === 0) {
      setErrorMessage('Pilih minimal 1 stiker untuk diunggah');
      return;
    }

    setIsUploading(true);
    setUploadProgress({ current: 0, total: selectedSlices.length });
    setErrorMessage(null);

    try {
      const uploadedItems: Array<{ name: string; imageUrl: string; emoji?: string }> = [];

      for (let i = 0; i < selectedSlices.length; i++) {
        const item = selectedSlices[i];
        setUploadProgress({ current: i + 1, total: selectedSlices.length });

        // Convert canvas to blob & file
        const blob = await new Promise<Blob | null>((resolve) => {
          item.canvas.toBlob(resolve, 'image/png');
        });

        if (!blob) throw new Error('Gagal mengonversi kanvas stiker ke file');

        const cleanFilename = `${item.name.replace(/\s+/g, '_').toLowerCase()}.png`;
        const file = new File([blob], cleanFilename, { type: 'image/png' });

        const uploadRes = await mediaUpload.mutateAsync(file);
        uploadedItems.push({
          name: item.name.trim() || `Stiker ${i + 1}`,
          imageUrl: uploadRes.url,
          emoji: item.emoji.trim() || undefined,
        });
      }

      // Add bulk stickers to pack
      await addBulkStickers.mutateAsync({
        packId,
        items: uploadedItems,
      });

      onClose();
    } catch (err: any) {
      setErrorMessage(err.response?.data?.message || err.message || 'Gagal mengekstrak dan mengunggah stiker');
    } finally {
      setIsUploading(false);
    }
  };

  const selectedCount = slices.filter((s) => s.selected).length;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Ekstraktor Sprite Sheet Stiker (Phaser Tools Engine)"
      description={`Potong sprite sheet atlas menjadi item stiker terpisah untuk paket "${packName}" secara instan`}
      maxWidth="7xl"
    >
      <div className="space-y-5 max-h-[85vh] overflow-y-auto pr-1">
        {errorMessage && (
          <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        {/* Top Split: Upload & Grid Settings on Left, Interactive Overlay on Right */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 items-start">
          {/* Controls Column (5 cols) */}
          <div className="lg:col-span-5 space-y-4 bg-neutral-50/70 p-4 rounded-2xl border border-neutral-200/80">
            {/* Upload Box */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-neutral-800 flex items-center gap-1.5">
                <Upload className="w-3.5 h-3.5 text-cyan-600" />
                Unggah File Sprite Sheet / Atlas
              </label>

              <div className="border-2 border-dashed border-neutral-300 rounded-xl p-4 text-center hover:border-cyan-500 transition-colors cursor-pointer relative bg-white">
                <input
                  type="file"
                  accept="image/png,image/webp,image/jpeg"
                  onChange={handleSheetUpload}
                  className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                />
                {sheetFile ? (
                  <div className="space-y-1 text-neutral-700">
                    <p className="text-xs font-bold truncate max-w-[280px] mx-auto">{sheetFile.name}</p>
                    <p className="text-[11px] text-cyan-600 font-mono">
                      {sheetDimensions.width} x {sheetDimensions.height} px
                    </p>
                  </div>
                ) : (
                  <div className="space-y-1 text-neutral-500">
                    <Scissors className="w-6 h-6 mx-auto text-neutral-400" />
                    <p className="text-xs font-semibold text-neutral-800">
                      Pilih Gambar Sprite Sheet (PNG / WEBP)
                    </p>
                    <p className="text-[11px] text-neutral-400">
                      Bisa berupa koleksi 4x4, 3x3, atau atlas gambar bertumpuk
                    </p>
                  </div>
                )}
              </div>
            </div>

            {/* Slicing Mode Tabs */}
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-neutral-800 flex items-center gap-1.5">
                  <Sliders className="w-3.5 h-3.5 text-neutral-700" />
                  Konfigurasi Pembagian Grid
                </label>
                <div className="flex bg-neutral-200/70 p-0.5 rounded-lg text-[11px]">
                  <button
                    type="button"
                    onClick={() => setSliceMode('GRID')}
                    className={`px-2 py-0.5 rounded-md font-semibold transition-all ${
                      sliceMode === 'GRID' ? 'bg-white text-neutral-900 shadow-2xs' : 'text-neutral-500'
                    }`}
                  >
                    Jumlah Kolom & Baris
                  </button>
                  <button
                    type="button"
                    onClick={() => setSliceMode('DIMENSIONS')}
                    className={`px-2 py-0.5 rounded-md font-semibold transition-all ${
                      sliceMode === 'DIMENSIONS' ? 'bg-white text-neutral-900 shadow-2xs' : 'text-neutral-500'
                    }`}
                  >
                    Ukuran Frame (Px)
                  </button>
                </div>
              </div>

              {sliceMode === 'GRID' ? (
                <div className="grid grid-cols-2 gap-3 bg-white p-3 rounded-xl border border-neutral-200/80">
                  <div className="space-y-1">
                    <span className="text-[11px] font-semibold text-neutral-600">Kolom (Columns)</span>
                    <input
                      type="number"
                      min="1"
                      max="32"
                      value={cols}
                      onChange={(e) => setCols(Math.max(1, parseInt(e.target.value) || 1))}
                      className="w-full px-2.5 py-1.5 text-xs font-bold rounded-lg border border-neutral-200 bg-neutral-50/50"
                    />
                  </div>
                  <div className="space-y-1">
                    <span className="text-[11px] font-semibold text-neutral-600">Baris (Rows)</span>
                    <input
                      type="number"
                      min="1"
                      max="32"
                      value={rows}
                      onChange={(e) => setRows(Math.max(1, parseInt(e.target.value) || 1))}
                      className="w-full px-2.5 py-1.5 text-xs font-bold rounded-lg border border-neutral-200 bg-neutral-50/50"
                    />
                  </div>
                </div>
              ) : (
                <div className="grid grid-cols-2 gap-3 bg-white p-3 rounded-xl border border-neutral-200/80">
                  <div className="space-y-1">
                    <span className="text-[11px] font-semibold text-neutral-600">Lebar Frame (Px)</span>
                    <input
                      type="number"
                      min="16"
                      max="2048"
                      value={frameWidth}
                      onChange={(e) => setFrameWidth(Math.max(16, parseInt(e.target.value) || 16))}
                      className="w-full px-2.5 py-1.5 text-xs font-bold rounded-lg border border-neutral-200 bg-neutral-50/50"
                    />
                  </div>
                  <div className="space-y-1">
                    <span className="text-[11px] font-semibold text-neutral-600">Tinggi Frame (Px)</span>
                    <input
                      type="number"
                      min="16"
                      max="2048"
                      value={frameHeight}
                      onChange={(e) => setFrameHeight(Math.max(16, parseInt(e.target.value) || 16))}
                      className="w-full px-2.5 py-1.5 text-xs font-bold rounded-lg border border-neutral-200 bg-neutral-50/50"
                    />
                  </div>
                </div>
              )}

              {/* Margin & Spacing Toggle */}
              <div className="grid grid-cols-4 gap-2 bg-white p-2.5 rounded-xl border border-neutral-200/80 text-[10px]">
                <div className="space-y-0.5">
                  <span className="text-neutral-500">Margin X</span>
                  <input
                    type="number"
                    min="0"
                    value={marginX}
                    onChange={(e) => setMarginX(Math.max(0, parseInt(e.target.value) || 0))}
                    className="w-full px-1.5 py-1 rounded border border-neutral-200"
                  />
                </div>
                <div className="space-y-0.5">
                  <span className="text-neutral-500">Margin Y</span>
                  <input
                    type="number"
                    min="0"
                    value={marginY}
                    onChange={(e) => setMarginY(Math.max(0, parseInt(e.target.value) || 0))}
                    className="w-full px-1.5 py-1 rounded border border-neutral-200"
                  />
                </div>
                <div className="space-y-0.5">
                  <span className="text-neutral-500">Spasi X</span>
                  <input
                    type="number"
                    min="0"
                    value={spacingX}
                    onChange={(e) => setSpacingX(Math.max(0, parseInt(e.target.value) || 0))}
                    className="w-full px-1.5 py-1 rounded border border-neutral-200"
                  />
                </div>
                <div className="space-y-0.5">
                  <span className="text-neutral-500">Spasi Y</span>
                  <input
                    type="number"
                    min="0"
                    value={spacingY}
                    onChange={(e) => setSpacingY(Math.max(0, parseInt(e.target.value) || 0))}
                    className="w-full px-1.5 py-1 rounded border border-neutral-200"
                  />
                </div>
              </div>
            </div>

            {/* Smart Processing Options */}
            <div className="space-y-2 bg-white p-3 rounded-xl border border-neutral-200/80">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={autoTrim}
                  onChange={(e) => setAutoTrim(e.target.checked)}
                  className="rounded text-cyan-600 focus:ring-cyan-500 w-4 h-4"
                />
                <span className="text-xs font-semibold text-neutral-800">
                  Auto-Trim Transparansi Kosong & Center
                </span>
              </label>
              <p className="text-[11px] text-neutral-400 pl-6">
                Memangkas area kosong transparan di sekitar stiker lalu menempatkannya proporsional di tengah kanvas 512x512 px.
              </p>
            </div>

            {/* Extract Slices Button */}
            <Button
              type="button"
              variant="primary"
              className="w-full py-2.5 bg-cyan-600 hover:bg-cyan-700 text-white"
              disabled={!sheetImage || isProcessing}
              isLoading={isProcessing}
              onClick={handleExtractSlices}
              icon={<Scissors className="w-4 h-4" />}
            >
              Ekstrak Slices Menjadi Stiker
            </Button>
          </div>

          {/* Interactive Atlas Preview Column (7 cols) */}
          <div className="lg:col-span-7 space-y-2">
            <div className="flex items-center justify-between text-xs font-bold text-neutral-800">
              <span className="flex items-center gap-1.5">
                <Eye className="w-3.5 h-3.5 text-cyan-600" />
                Pratinjau Garis Potong Atlas (Garis Cyan = Potongan Stiker)
              </span>
              {sheetImage && (
                <span className="text-[11px] text-neutral-400 font-mono">
                  {cols * rows} calon stiker
                </span>
              )}
            </div>

            <div
              className="w-full h-[360px] rounded-2xl border border-neutral-200/80 overflow-auto flex items-center justify-center p-3 relative"
              style={{
                backgroundColor: '#ffffff',
                backgroundImage:
                  'linear-gradient(45deg, #f1f5f9 25%, transparent 25%), linear-gradient(-45deg, #f1f5f9 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f1f5f9 75%), linear-gradient(-45deg, transparent 75%, #f1f5f9 75%)',
                backgroundSize: '16px 16px',
                backgroundPosition: '0 0, 0 8px, 8px -8px, -8px 0px',
              }}
            >
              {sheetImage ? (
                <canvas
                  ref={gridOverlayCanvasRef}
                  className="max-w-full max-h-full object-contain filter drop-shadow-md rounded-lg"
                />
              ) : (
                <div className="text-center text-neutral-400 space-y-1">
                  <Grid className="w-10 h-10 mx-auto text-neutral-300" />
                  <p className="text-xs font-medium">Belum ada sprite sheet yang diunggah</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Bottom Slices Gallery & Final Batch Publisher */}
        {slices.length > 0 && (
          <div className="space-y-4 pt-4 border-t border-neutral-200">
            {/* Gallery Toolbar */}
            <div className="flex flex-wrap items-center justify-between gap-3 bg-neutral-50 p-3 rounded-xl border border-neutral-200">
              <div className="flex items-center gap-3">
                <span className="text-xs font-bold text-neutral-900">
                  Hasil Potongan: {slices.length} Stiker
                </span>
                <Badge variant="brand">{selectedCount} Dipilih</Badge>
                <div className="flex items-center gap-1 text-[11px]">
                  <button
                    type="button"
                    onClick={() => selectAll(true)}
                    className="text-cyan-700 hover:underline font-semibold"
                  >
                    Pilih Semua
                  </button>
                  <span className="text-neutral-300">•</span>
                  <button
                    type="button"
                    onClick={() => selectAll(false)}
                    className="text-neutral-500 hover:underline"
                  >
                    Batal Pilih
                  </button>
                </div>
              </div>

              {/* Template Prefix Assigner */}
              <div className="flex items-center gap-2">
                <span className="text-xs text-neutral-500">Awalan Nama:</span>
                <input
                  type="text"
                  value={namePrefix}
                  onChange={(e) => setNamePrefix(e.target.value)}
                  placeholder="Nama awalan"
                  className="px-2.5 py-1 text-xs rounded-lg border border-neutral-200 bg-white font-medium"
                />
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  onClick={applyPrefixToAll}
                >
                  Terapkan ke Semua
                </Button>
              </div>
            </div>

            {/* Slices Grid */}
            <div className="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-3 max-h-72 overflow-y-auto pr-1">
              {slices.map((slice, idx) => (
                <div
                  key={slice.id}
                  onClick={() => toggleSelect(idx)}
                  className={`p-2.5 rounded-xl border transition-all cursor-pointer relative flex flex-col items-center justify-between ${
                    slice.selected
                      ? 'bg-white border-cyan-500 ring-2 ring-cyan-200 shadow-xs'
                      : 'bg-neutral-50/50 border-neutral-200 opacity-50 hover:opacity-80'
                  }`}
                >
                  {/* Selection Checkbox Pill */}
                  <div className="absolute top-1.5 left-1.5 z-10">
                    <input
                      type="checkbox"
                      checked={slice.selected}
                      onChange={() => toggleSelect(idx)}
                      onClick={(e) => e.stopPropagation()}
                      className="rounded text-cyan-600 focus:ring-cyan-500 w-3.5 h-3.5"
                    />
                  </div>

                  <span className="absolute top-1.5 right-1.5 text-[9px] font-mono text-neutral-400">
                    #{idx + 1}
                  </span>

                  {/* Thumbnail on Transparency */}
                  <div
                    className="w-16 h-16 rounded-lg flex items-center justify-center p-1 overflow-hidden mt-3 border border-neutral-100"
                    style={{
                      backgroundColor: '#ffffff',
                      backgroundImage:
                        'linear-gradient(45deg, #f1f5f9 25%, transparent 25%), linear-gradient(-45deg, #f1f5f9 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f1f5f9 75%), linear-gradient(-45deg, transparent 75%, #f1f5f9 75%)',
                      backgroundSize: '8px 8px',
                      backgroundPosition: '0 0, 0 4px, 4px -4px, -4px 0px',
                    }}
                  >
                    <img
                      src={slice.previewUrl}
                      alt={slice.name}
                      className="max-w-full max-h-full object-contain"
                    />
                  </div>

                  <div className="mt-2 w-full space-y-1" onClick={(e) => e.stopPropagation()}>
                    <input
                      type="text"
                      value={slice.name}
                      onChange={(e) => updateSlice(idx, 'name', e.target.value)}
                      className="w-full text-[10px] font-bold px-1.5 py-0.5 rounded border border-neutral-200 text-center truncate"
                    />
                    <input
                      type="text"
                      value={slice.emoji}
                      placeholder=":tag:"
                      onChange={(e) => updateSlice(idx, 'emoji', e.target.value)}
                      className="w-full text-[9px] font-mono px-1.5 py-0.5 rounded border border-neutral-100 text-center text-neutral-500"
                    />
                  </div>
                </div>
              ))}
            </div>

            {/* Upload Progress Bar */}
            {isUploading && (
              <div className="space-y-1.5 p-3.5 bg-cyan-50 rounded-xl border border-cyan-200">
                <div className="flex justify-between text-xs font-semibold text-cyan-900">
                  <span>Menerbitkan stiker ke paket "{packName}"...</span>
                  <span>{uploadProgress.current} / {uploadProgress.total}</span>
                </div>
                <div className="w-full bg-cyan-200 rounded-full h-2 overflow-hidden">
                  <div
                    className="bg-cyan-600 h-2 rounded-full transition-all duration-300"
                    style={{ width: `${(uploadProgress.current / uploadProgress.total) * 100}%` }}
                  />
                </div>
              </div>
            )}
          </div>
        )}

        {/* Modal Footer */}
        <div className="flex items-center justify-between pt-4 border-t border-neutral-100">
          <Button type="button" variant="outline" onClick={onClose} disabled={isUploading}>
            Tutup
          </Button>

          <Button
            type="button"
            variant="primary"
            className="bg-cyan-600 hover:bg-cyan-700 text-white"
            disabled={selectedCount === 0 || isUploading}
            isLoading={isUploading}
            onClick={handleUploadAll}
            icon={<FolderDown className="w-4 h-4" />}
          >
            Ekstrak & Tambahkan Semua ke Paket ({selectedCount} Stiker)
          </Button>
        </div>
      </div>
    </Modal>
  );
}
