import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import {
  Scissors,
  Upload,
  Sparkles,
  Layers,
  Check,
  X,
  RefreshCw,
  FolderDown,
  Trash2,
  ZoomIn,
  ZoomOut,
  Maximize2,
  Move,
  Plus,
  Copy,
  Lock,
  Unlock,
  Pipette,
  Wand2,
  ArrowUp,
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  MousePointer,
  Grid,
  Columns,
  Rows,
  AlertCircle,
  RotateCcw,
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

export interface CropBox {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
  customized?: boolean;
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

type ActiveTool = 'select' | 'pan' | 'eyedropper' | 'add_box';
type ResizeHandle = 'nw' | 'n' | 'ne' | 'e' | 'se' | 's' | 'sw' | 'w';

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
  const [sheetImageSrc, setSheetImageSrc] = useState<string | null>(null);
  const [sheetImage, setSheetImage] = useState<HTMLImageElement | null>(null);
  const [sheetDimensions, setSheetDimensions] = useState<{ width: number; height: number }>({ width: 0, height: 0 });

  // Master Unified Grid Parameters (Matriks Utama)
  const [gridX, setGridX] = useState(0);
  const [gridY, setGridY] = useState(0);
  const [gridWidth, setGridWidth] = useState(0);
  const [gridHeight, setGridHeight] = useState(0);
  const [cols, setCols] = useState(4);
  const [rows, setRows] = useState(3);
  const [spacingX, setSpacingX] = useState(0);
  const [spacingY, setSpacingY] = useState(0);

  // Boxes State (Array of individual frames)
  const [boxes, setBoxes] = useState<CropBox[]>([]);
  const [selectedBoxId, setSelectedBoxId] = useState<string | null>(null);
  const [lockAspectRatio, setLockAspectRatio] = useState(false);

  // Active Tool & Viewport (Zoom & Pan)
  const [activeTool, setActiveTool] = useState<ActiveTool>('select');
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const [isSpacePressed, setIsSpacePressed] = useState(false);
  const [isDragging, setIsDragging] = useState(false);

  // Magic Background Remover (Chroma / Color Key)
  const [removeBgColor, setRemoveBgColor] = useState(false);
  const [bgColorHex, setBgColorHex] = useState('#FFFFFF');
  const [bgTolerance, setBgTolerance] = useState(25);

  // Auto-Trim, Target Resolution & Anti-Blur (Cegah Gambar Pecah)
  const [autoTrim, setAutoTrim] = useState(true);
  const [outputResolutionMode, setOutputResolutionMode] = useState<'512' | 'native' | '1024'>('512');
  const [preventUpscaleBlur, setPreventUpscaleBlur] = useState(true);
  const [namePrefix, setNamePrefix] = useState('Stiker');

  // Slices Gallery State
  const [slices, setSlices] = useState<SlicedStickerItem[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState({ current: 0, total: 0 });
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // DOM Refs
  const viewportContainerRef = useRef<HTMLDivElement | null>(null);
  const svgOverlayRef = useRef<SVGSVGElement | null>(null);
  const offscreenCanvasRef = useRef<HTMLCanvasElement | null>(null);

  // Drag Action Tracking Ref
  const dragActionRef = useRef<{
    type: 'pan' | 'master_move' | 'master_resize' | 'box_move' | 'box_resize' | 'draw_new';
    handle?: ResizeHandle;
    boxId?: string;
    startX: number;
    startY: number;
    initialGrid?: { x: number; y: number; width: number; height: number };
    initialBox?: CropBox;
    initialPan?: { x: number; y: number };
    // Snapshot of grid params at drag start (avoids stale closure issues in handleMouseMove)
    snapCols?: number;
    snapRows?: number;
    snapSpacingX?: number;
    snapSpacingY?: number;
    // Snapshot of boxes at drag start (for master_move shift)
    snapBoxes?: CropBox[];
  } | null>(null);


  // Clean up object URLs when modal unmounts or closes
  useEffect(() => {
    return () => {
      if (sheetImageSrc && sheetImageSrc.startsWith('blob:')) {
        URL.revokeObjectURL(sheetImageSrc);
      }
    };
  }, [sheetImageSrc]);

  // Reset when modal opens
  useEffect(() => {
    if (isOpen) {
      setSheetFile(null);
      setSheetImageSrc(null);
      setSheetImage(null);
      setSheetDimensions({ width: 0, height: 0 });
      setGridX(0);
      setGridY(0);
      setGridWidth(0);
      setGridHeight(0);
      setCols(4);
      setRows(3);
      setBoxes([]);
      setSelectedBoxId(null);
      setSlices([]);
      setErrorMessage(null);
      setIsUploading(false);
      setZoom(1);
      setPan({ x: 0, y: 0 });
      setActiveTool('select');
      setNamePrefix(packName.replace(/\s+/g, '_'));
      setSpacingX(0);
      setSpacingY(0);
      setOutputResolutionMode('512');
      setPreventUpscaleBlur(true);
    }
  }, [isOpen, packName]);

  // Spacebar pan listener & Delete key listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.code === 'Space' && !e.repeat && document.activeElement?.tagName !== 'INPUT') {
        setIsSpacePressed(true);
      }
      if ((e.key === 'Delete' || e.key === 'Backspace') && selectedBoxId && document.activeElement?.tagName !== 'INPUT') {
        e.preventDefault();
        setBoxes((prev) => prev.filter((b) => b.id !== selectedBoxId));
        setSelectedBoxId(null);
      }
    };
    const handleKeyUp = (e: KeyboardEvent) => {
      if (e.code === 'Space') {
        setIsSpacePressed(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
    };
  }, [selectedBoxId]);

  // Regenerate Uniform Grid Boxes
  // Uses continuous float arithmetic internally, only rounds final pixel positions.
  // The last cell in each row/column is always snapped to the exact grid boundary
  // to prevent 1-2px rounding overflow that SVG clips by default.
  const generateUniformGridBoxes = useCallback((
    gx: number,
    gy: number,
    gw: number,
    gh: number,
    cCount: number,
    rCount: number,
    spX: number,
    spY: number
  ): CropBox[] => {
    if (gw <= 0 || gh <= 0 || cCount <= 0 || rCount <= 0) return [];
    // Float cell size — NO rounding here to avoid accumulation
    const cellW_f = Math.max(8, (gw - (cCount - 1) * spX) / cCount);
    const cellH_f = Math.max(8, (gh - (rCount - 1) * spY) / rCount);

    const newBoxes: CropBox[] = [];
    for (let r = 0; r < rCount; r++) {
      for (let c = 0; c < cCount; c++) {
        const x = Math.round(gx + c * (cellW_f + spX));
        const y = Math.round(gy + r * (cellH_f + spY));
        // Snap last column/row to exact grid boundary to eliminate rounding overflow
        const xEnd = c === cCount - 1
          ? Math.round(gx + gw)
          : Math.round(gx + (c + 1) * (cellW_f + spX) - spX);
        const yEnd = r === rCount - 1
          ? Math.round(gy + gh)
          : Math.round(gy + (r + 1) * (cellH_f + spY) - spY);

        newBoxes.push({
          id: `cell_${r}_${c}`,
          x,
          y,
          width: Math.max(8, xEnd - x),
          height: Math.max(8, yEnd - y),
          customized: false,
        });
      }
    }
    return newBoxes;
  }, []);


  // Recalculate Master Grid Bounding Box from current boxes
  const syncMasterGridFromBoxes = (currentBoxes: CropBox[]) => {
    if (currentBoxes.length === 0) return;
    let minX = currentBoxes[0].x;
    let minY = currentBoxes[0].y;
    let maxX = currentBoxes[0].x + currentBoxes[0].width;
    let maxY = currentBoxes[0].y + currentBoxes[0].height;

    for (const b of currentBoxes) {
      if (b.x < minX) minX = b.x;
      if (b.y < minY) minY = b.y;
      if (b.x + b.width > maxX) maxX = b.x + b.width;
      if (b.y + b.height > maxY) maxY = b.y + b.height;
    }

    setGridX(minX);
    setGridY(minY);
    setGridWidth(maxX - minX);
    setGridHeight(maxY - minY);
  };


  // Handle Sprite Sheet File Upload
  const handleSheetUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0]) return;
    const file = e.target.files[0];
    setSheetFile(file);
    setErrorMessage(null);

    const objectUrl = URL.createObjectURL(file);
    setSheetImageSrc(objectUrl);

    const img = new Image();
    img.src = objectUrl;
    img.onload = () => {
      setSheetImage(img);
      const w = img.naturalWidth;
      const h = img.naturalHeight;
      setSheetDimensions({ width: w, height: h });
      setSpacingX(0);
      setSpacingY(0);

      // Grid selalu menutupi 100% seluruh lebar dan tinggi gambar (ujung ke ujung)
      setGridX(0);
      setGridY(0);
      setGridWidth(w);
      setGridHeight(h);

      // Tentukan jumlah kolom dan baris berdasarkan rasio aspek gambar
      const ratio = w / h;
      let initCols = 4;
      let initRows = 3;

      if (ratio >= 1.42) {
        initCols = 6;
        initRows = 4;
      } else if (ratio >= 1.15) {
        initCols = 4;
        initRows = 3;
      } else if (ratio <= 0.75) {
        initCols = 3;
        initRows = 4;
      } else {
        initCols = 4;
        initRows = 4;
      }

      setCols(initCols);
      setRows(initRows);

      // Generate grid 100% penuh menutupi lebar & tinggi gambar
      const initialBoxes = generateUniformGridBoxes(0, 0, w, h, initCols, initRows, 0, 0);
      setBoxes(initialBoxes);
      setSelectedBoxId(null);

      // Fit zoom so entire image is visible in the viewport
      if (viewportContainerRef.current) {
        const vpW = viewportContainerRef.current.clientWidth - 48;
        const vpH = viewportContainerRef.current.clientHeight - 48;
        const scale = Math.min(1, Math.min(vpW / w, vpH / h));
        setZoom(Math.max(0.15, Math.round(scale * 100) / 100));
        setPan({ x: 0, y: 0 });
      }
    };
  };


  // Deterministik & Zero-Drift Coordinate Transformation using native SVG CTM
  const getSvgCoordinates = useCallback(
    (e: React.MouseEvent | MouseEvent): { x: number; y: number } => {
      const svg = svgOverlayRef.current;
      if (!svg || sheetDimensions.width <= 0 || sheetDimensions.height <= 0) return { x: 0, y: 0 };

      try {
        const ctm = svg.getScreenCTM();
        if (ctm) {
          const pt = svg.createSVGPoint();
          pt.x = e.clientX;
          pt.y = e.clientY;
          const svgP = pt.matrixTransform(ctm.inverse());
          return {
            x: Math.round(svgP.x),
            y: Math.round(svgP.y),
          };
        }
      } catch (_e) {}

      // Fallback
      const rect = svg.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return { x: 0, y: 0 };
      const scaleX = sheetDimensions.width / rect.width;
      const scaleY = sheetDimensions.height / rect.height;
      return {
        x: Math.round((e.clientX - rect.left) * scaleX),
        y: Math.round((e.clientY - rect.top) * scaleY),
      };
    },
    [sheetDimensions]
  );


  // Eyedropper Color Picker
  const handlePickColor = (coords: { x: number; y: number }) => {
    if (!sheetImage) return;
    const canvas = document.createElement('canvas');
    canvas.width = sheetDimensions.width;
    canvas.height = sheetDimensions.height;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.drawImage(sheetImage, 0, 0);

    const pixel = ctx.getImageData(coords.x, coords.y, 1, 1).data;
    const hex = `#${((1 << 24) + (pixel[0] << 16) + (pixel[1] << 8) + pixel[2]).toString(16).slice(1).toUpperCase()}`;
    setBgColorHex(hex);
    setRemoveBgColor(true);
    setActiveTool('select');
  };

  // Change Columns / Rows and rebuild un-customized boxes
  const updateGridColsRows = (newCols: number, newRows: number, fitImage = false) => {
    const c = Math.max(1, Math.min(24, newCols));
    const r = Math.max(1, Math.min(24, newRows));
    setCols(c);
    setRows(r);

    let gx = gridX;
    let gy = gridY;
    let gw = gridWidth;
    let gh = gridHeight;

    // Automatically expand to full image if requested or if current bounds are squashed/zero
    if (
      fitImage ||
      gw <= 0 ||
      gh <= 0 ||
      (sheetDimensions.width > 0 && gw < sheetDimensions.width * 0.5) ||
      (sheetDimensions.height > 0 && gh < sheetDimensions.height * 0.5)
    ) {
      gx = 0;
      gy = 0;
      gw = sheetDimensions.width;
      gh = sheetDimensions.height;
      setGridX(0);
      setGridY(0);
      setGridWidth(gw);
      setGridHeight(gh);
    }

    const newBoxes = generateUniformGridBoxes(gx, gy, gw, gh, c, r, spacingX, spacingY);
    setBoxes(newBoxes);
    setSelectedBoxId(null);
  };

  // Reset all boxes back to pristine uniform grid
  const handleResetToUniformGrid = () => {
    const newBoxes = generateUniformGridBoxes(gridX, gridY, gridWidth, gridHeight, cols, rows, spacingX, spacingY);
    setBoxes(newBoxes);
    setSelectedBoxId(null);
  };

  // Snap Master Grid Top to Y=0 (Penuh ke Atas)
  const handleSnapMasterGridToTop = () => {
    if (sheetDimensions.height <= 0) return;
    const newH = Math.min(sheetDimensions.height, gridY + gridHeight);
    setGridY(0);
    setGridHeight(newH);
    setBoxes(generateUniformGridBoxes(gridX, 0, gridWidth, newH, cols, rows, spacingX, spacingY));
  };

  // Snap Master Grid Bottom to Y=sheetDimensions.height (Penuh ke Bawah)
  const handleSnapMasterGridToBottom = () => {
    if (sheetDimensions.height <= 0) return;
    const newH = Math.max(rows * 16, sheetDimensions.height - gridY);
    setGridHeight(newH);
    setBoxes(generateUniformGridBoxes(gridX, gridY, gridWidth, newH, cols, rows, spacingX, spacingY));
  };

  // Nudge Master Grid Position
  const handleNudgeMasterGrid = (dx: number, dy: number) => {
    if (sheetDimensions.width <= 0 || sheetDimensions.height <= 0) return;
    const minY = -(gridHeight * 0.8);
    const maxY = sheetDimensions.height - gridHeight * 0.2;
    const minX = -(gridWidth * 0.8);
    const maxX = sheetDimensions.width - gridWidth * 0.2;
    const newX = Math.max(minX, Math.min(maxX, gridX + dx));
    const newY = Math.max(minY, Math.min(maxY, gridY + dy));
    setGridX(newX);
    setGridY(newY);
    setBoxes(generateUniformGridBoxes(newX, newY, gridWidth, gridHeight, cols, rows, spacingX, spacingY));
  };

  // Reset a specific customized box back to its theoretical grid cell
  const handleResetSingleBoxToGrid = (boxId: string) => {
    const defaultBoxes = generateUniformGridBoxes(gridX, gridY, gridWidth, gridHeight, cols, rows, spacingX, spacingY);
    const boxIdx = boxes.findIndex((b) => b.id === boxId);
    if (boxIdx >= 0 && defaultBoxes[boxIdx]) {
      setBoxes((prev) =>
        prev.map((b, idx) => (idx === boxIdx ? { ...defaultBoxes[boxIdx], customized: false } : b))
      );
    }
  };

  // Snap Master Grid to Full 100% Image Bounds (Seluruh Kanvas Gambar)
  const handleFitMasterGridToFullImage = () => {
    if (sheetDimensions.width <= 0 || sheetDimensions.height <= 0) return;
    setGridX(0);
    setGridY(0);
    setGridWidth(sheetDimensions.width);
    setGridHeight(sheetDimensions.height);

    const newBoxes = generateUniformGridBoxes(0, 0, sheetDimensions.width, sheetDimensions.height, cols, rows, spacingX, spacingY);
    setBoxes(newBoxes);
  };





  // Center Master Grid with Clean Margin (96% Coverage)
  const handleFitMasterGridWithMargin = () => {
    if (sheetDimensions.width <= 0 || sheetDimensions.height <= 0) return;
    const padX = Math.round(sheetDimensions.width * 0.02);
    const padY = Math.round(sheetDimensions.height * 0.02);
    const newW = sheetDimensions.width - padX * 2;
    const newH = sheetDimensions.height - padY * 2;

    setGridX(padX);
    setGridY(padY);
    setGridWidth(newW);
    setGridHeight(newH);

    const newBoxes = generateUniformGridBoxes(padX, padY, newW, newH, cols, rows, spacingX, spacingY);
    setBoxes(newBoxes);
  };


  // Smart Flood-Fill Auto-Detect Frames (With 28px Proximity Merge)
  const handleAutoDetectFrames = () => {
    if (!sheetImage) return;
    setIsProcessing(true);
    setErrorMessage(null);

    requestAnimationFrame(() => {
      try {
        const w = sheetDimensions.width;
        const h = sheetDimensions.height;
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        if (!ctx) throw new Error('Kanvas deteksi tidak dapat diinisialisasi');

        ctx.drawImage(sheetImage, 0, 0);
        const imgData = ctx.getImageData(0, 0, w, h);
        const data = imgData.data;

        let bgR = 255, bgG = 255, bgB = 255;
        if (removeBgColor) {
          const hex = bgColorHex.replace('#', '');
          bgR = parseInt(hex.substring(0, 2), 16);
          bgG = parseInt(hex.substring(2, 4), 16);
          bgB = parseInt(hex.substring(4, 6), 16);
        }

        const isSolidPixel = (px: number, py: number): boolean => {
          if (px < 0 || px >= w || py < 0 || py >= h) return false;
          const idx = (py * w + px) * 4;
          const alpha = data[idx + 3];
          if (alpha < 25) return false;

          if (removeBgColor) {
            const r = data[idx];
            const g = data[idx + 1];
            const b = data[idx + 2];
            const colorDist = Math.sqrt((r - bgR) ** 2 + (g - bgG) ** 2 + (b - bgB) ** 2);
            const maxDist = (bgTolerance / 100) * 441.67;
            if (colorDist <= maxDist) return false;
          }
          return true;
        };

        const step = 4;
        const gridW = Math.ceil(w / step);
        const gridH = Math.ceil(h / step);
        const mask = new Uint8Array(gridW * gridH);

        for (let gy = 0; gy < gridH; gy++) {
          for (let gx = 0; gx < gridW; gx++) {
            const px = gx * step;
            const py = gy * step;
            if (isSolidPixel(px, py)) {
              mask[gy * gridW + gx] = 1;
            }
          }
        }

        const visited = new Uint8Array(gridW * gridH);
        const rawBoxes: CropBox[] = [];

        for (let gy = 0; gy < gridH; gy++) {
          for (let gx = 0; gx < gridW; gx++) {
            const idx = gy * gridW + gx;
            if (mask[idx] === 1 && visited[idx] === 0) {
              let minGX = gx;
              let maxGX = gx;
              let minGY = gy;
              let maxGY = gy;

              const queue: number[] = [idx];
              visited[idx] = 1;

              while (queue.length > 0) {
                const cur = queue.pop()!;
                const cx = cur % gridW;
                const cy = Math.floor(cur / gridW);

                if (cx < minGX) minGX = cx;
                if (cx > maxGX) maxGX = cx;
                if (cy < minGY) minGY = cy;
                if (cy > maxGY) maxGY = cy;

                const neighbors = [
                  [cx + 1, cy],
                  [cx - 1, cy],
                  [cx, cy + 1],
                  [cx, cy - 1],
                ];

                for (const [nx, ny] of neighbors) {
                  if (nx >= 0 && nx < gridW && ny >= 0 && ny < gridH) {
                    const nIdx = ny * gridW + nx;
                    if (mask[nIdx] === 1 && visited[nIdx] === 0) {
                      visited[nIdx] = 1;
                      queue.push(nIdx);
                    }
                  }
                }
              }

              const boxW = (maxGX - minGX + 1) * step;
              const boxH = (maxGY - minGY + 1) * step;

              if (boxW >= 14 && boxH >= 14) {
                rawBoxes.push({
                  id: Math.random().toString(36).substring(2, 9),
                  x: minGX * step,
                  y: minGY * step,
                  width: boxW,
                  height: boxH,
                  customized: true,
                });
              }
            }
          }
        }

        // Iterative Proximity Merging (28px gap tolerance)
        const gapTolerance = 28;
        let mergedList = [...rawBoxes];
        let didMerge = true;

        while (didMerge) {
          didMerge = false;
          for (let i = 0; i < mergedList.length; i++) {
            for (let j = i + 1; j < mergedList.length; j++) {
              const a = mergedList[i];
              const b = mergedList[j];

              const overlapX = !(a.x + a.width + gapTolerance < b.x || b.x + b.width + gapTolerance < a.x);
              const overlapY = !(a.y + a.height + gapTolerance < b.y || b.y + b.height + gapTolerance < a.y);

              if (overlapX && overlapY) {
                const minX = Math.min(a.x, b.x);
                const minY = Math.min(a.y, b.y);
                const maxX = Math.max(a.x + a.width, b.x + b.width);
                const maxY = Math.max(a.y + a.height, b.y + b.height);

                mergedList[i] = {
                  id: a.id,
                  x: minX,
                  y: minY,
                  width: maxX - minX,
                  height: maxY - minY,
                  customized: true,
                };
                mergedList.splice(j, 1);
                didMerge = true;
                break;
              }
            }
            if (didMerge) break;
          }
        }

        const pad = 6;
        const finalDetected = mergedList
          .map((box) => {
            const finalX = Math.max(0, box.x - pad);
            const finalY = Math.max(0, box.y - pad);
            const finalW = Math.min(w - finalX, box.width + pad * 2);
            const finalH = Math.min(h - finalY, box.height + pad * 2);
            return {
              ...box,
              x: finalX,
              y: finalY,
              width: finalW,
              height: finalH,
            };
          })
          .filter((b) => b.width >= 24 && b.height >= 24);

        if (finalDetected.length === 0) {
          setErrorMessage('Tidak ditemukan karakter stiker. Gunakan fitur Grid Terpadu.');
        } else {
          // Sort spatially left-to-right, top-to-bottom
          finalDetected.sort((a, b) => {
            const diffY = a.y - b.y;
            if (Math.abs(diffY) > 36) return diffY;
            return a.x - b.x;
          });
          setBoxes(finalDetected);
          syncMasterGridFromBoxes(finalDetected);
          setSelectedBoxId(finalDetected[0]?.id || null);
        }
      } catch (err: any) {
        setErrorMessage('Gagal mendeteksi kontur: ' + err.message);
      } finally {
        setIsProcessing(false);
      }
    });
  };

  // Viewport Mouse Down
  const handleMouseDown = (e: React.MouseEvent) => {
    if (!sheetImage) return;

    // Pan mode (Middle click or Spacebar held or Pan tool active)
    if (e.button === 1 || isSpacePressed || activeTool === 'pan') {
      e.preventDefault();
      setIsDragging(true);
      dragActionRef.current = {
        type: 'pan',
        startX: e.clientX,
        startY: e.clientY,
        initialPan: { ...pan },
      };
      return;
    }

    const coords = getSvgCoordinates(e);

    // Eyedropper mode
    if (activeTool === 'eyedropper') {
      handlePickColor(coords);
      return;
    }

    // Add new custom box tool
    if (activeTool === 'add_box') {
      const newBox: CropBox = {
        id: Math.random().toString(36).substring(2, 9),
        x: coords.x,
        y: coords.y,
        width: 48,
        height: 48,
        customized: true,
      };
      setBoxes((prev) => [...prev, newBox]);
      setSelectedBoxId(newBox.id);
      setIsDragging(true);

      dragActionRef.current = {
        type: 'draw_new',
        boxId: newBox.id,
        startX: coords.x,
        startY: coords.y,
        initialBox: { ...newBox },
      };
      return;
    }

    // Deselect if clicking on empty viewport canvas background
    setSelectedBoxId(null);
  };

  // Start Master Grid Move Drag (Drag Outer Solid Boundary)
  const handleMasterGridMouseDown = (e: React.MouseEvent) => {
    if (isSpacePressed || activeTool === 'pan' || activeTool === 'eyedropper') return;
    e.stopPropagation();
    setIsDragging(true);

    const coords = getSvgCoordinates(e);
    dragActionRef.current = {
      type: 'master_move',
      startX: coords.x,
      startY: coords.y,
      initialGrid: { x: gridX, y: gridY, width: gridWidth, height: gridHeight },
      // Snapshot current grid params & boxes to avoid stale closure reads
      snapCols: cols,
      snapRows: rows,
      snapSpacingX: spacingX,
      snapSpacingY: spacingY,
      snapBoxes: boxes.map((b) => ({ ...b })),
    };
  };

  // Start Master Grid Resize Drag (8 Handles on Master Boundary)
  const handleMasterHandleMouseDown = (e: React.MouseEvent, handle: ResizeHandle) => {
    if (isSpacePressed || activeTool === 'pan' || activeTool === 'eyedropper') return;
    e.stopPropagation();
    setIsDragging(true);

    const coords = getSvgCoordinates(e);
    dragActionRef.current = {
      type: 'master_resize',
      handle,
      startX: coords.x,
      startY: coords.y,
      initialGrid: { x: gridX, y: gridY, width: gridWidth, height: gridHeight },
      // Snapshot current grid params to avoid stale closure reads
      snapCols: cols,
      snapRows: rows,
      snapSpacingX: spacingX,
      snapSpacingY: spacingY,
    };
  };


  // Start Individual Box Move Drag
  const handleBoxMouseDown = (e: React.MouseEvent, box: CropBox) => {
    if (isSpacePressed || activeTool === 'pan' || activeTool === 'eyedropper' || activeTool === 'add_box') return;
    e.stopPropagation();
    setSelectedBoxId(box.id);
    setIsDragging(true);

    const coords = getSvgCoordinates(e);
    dragActionRef.current = {
      type: 'box_move',
      boxId: box.id,
      startX: coords.x,
      startY: coords.y,
      initialBox: { ...box },
    };
  };

  // Start Individual Box Handle Resize Drag (8 Handles on Selected Box)
  const handleBoxHandleMouseDown = (e: React.MouseEvent, box: CropBox, handle: ResizeHandle) => {
    if (isSpacePressed || activeTool === 'pan' || activeTool === 'eyedropper' || activeTool === 'add_box') return;
    e.stopPropagation();
    setSelectedBoxId(box.id);
    setIsDragging(true);

    const coords = getSvgCoordinates(e);
    dragActionRef.current = {
      type: 'box_resize',
      boxId: box.id,
      handle,
      startX: coords.x,
      startY: coords.y,
      initialBox: { ...box },
    };
  };

  // Mouse Move Global Listener
  const handleMouseMove = useCallback((e: MouseEvent) => {
    const action = dragActionRef.current;
    if (!action) return;

    if (action.type === 'pan') {
      const dx = e.clientX - action.startX;
      const dy = e.clientY - action.startY;
      setPan({
        x: (action.initialPan?.x || 0) + dx,
        y: (action.initialPan?.y || 0) + dy,
      });
      return;
    }

    const coords = getSvgCoordinates(e);
    const dx = coords.x - action.startX;
    const dy = coords.y - action.startY;

    // 1. MASTER GRID MOVE: Shift ALL boxes by delta
    if (action.type === 'master_move') {
      const init = action.initialGrid!;
      // Allow flexible positioning: grid can go from -(gridH * 0.8) to (sheetH - gridH * 0.2)
      // so user can always reach the top/bottom of the image even if grid is large
      const minY = -(init.height * 0.8);
      const maxY = sheetDimensions.height - init.height * 0.2;
      const minX = -(init.width * 0.8);
      const maxX = sheetDimensions.width - init.width * 0.2;

      const newX = Math.round(Math.max(minX, Math.min(maxX, init.x + dx)));
      const newY = Math.round(Math.max(minY, Math.min(maxY, init.y + dy)));
      const deltaX = newX - init.x;
      const deltaY = newY - init.y;

      setGridX(newX);
      setGridY(newY);

      // Shift ALL snapshotted boxes by delta
      const initBoxes = action.snapBoxes || [];
      setBoxes(initBoxes.map((b) => ({
        ...b,
        x: Math.round(b.x + deltaX),
        y: Math.round(b.y + deltaY),
      })));
      return;
    }

    // 2. MASTER GRID RESIZE: Pull handles to stretch all rows & columns simultaneously
    if (action.type === 'master_resize') {
      const init = action.initialGrid!;
      const handle = action.handle!;
      const snapC = action.snapCols ?? cols;
      const snapR = action.snapRows ?? rows;
      const snapSX = action.snapSpacingX ?? spacingX;
      const snapSY = action.snapSpacingY ?? spacingY;

      const minW = snapC * 12;
      const minH = snapR * 12;

      let newX = init.x;
      let newY = init.y;
      let newW = init.width;
      let newH = init.height;

      // Handle West (Left edge) - pin right edge
      if (handle.includes('w')) {
        const targetX = Math.min(init.x + init.width - minW, init.x + dx);
        newX = targetX;
        newW = init.x + init.width - targetX;
      }
      // Handle East (Right edge) - pin left edge
      if (handle.includes('e')) {
        const targetRight = Math.max(init.x + minW, init.x + init.width + dx);
        newW = targetRight - init.x;
      }
      // Handle North (Top edge) - pin bottom edge
      if (handle.includes('n')) {
        const targetY = Math.min(init.y + init.height - minH, init.y + dy);
        newY = targetY;
        newH = init.y + init.height - targetY;
      }
      // Handle South (Bottom edge) - pin top edge
      if (handle.includes('s')) {
        const targetBottom = Math.max(init.y + minH, init.y + init.height + dy);
        newH = targetBottom - init.y;
      }

      newX = Math.round(newX);
      newY = Math.round(newY);
      newW = Math.round(newW);
      newH = Math.round(newH);

      setGridX(newX);
      setGridY(newY);
      setGridWidth(newW);
      setGridHeight(newH);

      const resizedBoxes = generateUniformGridBoxes(newX, newY, newW, newH, snapC, snapR, snapSX, snapSY);
      setBoxes(resizedBoxes);
      return;
    }

    // 3. INDIVIDUAL BOX MOVE
    if (action.type === 'box_move') {
      const boxId = action.boxId!;
      const init = action.initialBox!;

      const newX = Math.round(Math.max(0, Math.min(sheetDimensions.width - init.width, init.x + dx)));
      const newY = Math.round(Math.max(0, Math.min(sheetDimensions.height - init.height, init.y + dy)));

      setBoxes((prev) =>
        prev.map((b) => (b.id === boxId ? { ...b, x: newX, y: newY, customized: true } : b))
      );
      return;
    }

    // 4. INDIVIDUAL BOX RESIZE (8 Handles on Selected Box)
    if (action.type === 'box_resize') {
      const boxId = action.boxId!;
      const init = action.initialBox!;
      const handle = action.handle!;

      let newX = init.x;
      let newY = init.y;
      let newW = init.width;
      let newH = init.height;

      if (handle.includes('w')) {
        const targetX = Math.max(0, Math.min(init.x + init.width - 12, init.x + dx));
        newX = targetX;
        newW = init.x + init.width - targetX;
      }
      if (handle.includes('e')) {
        const targetRight = Math.min(sheetDimensions.width, Math.max(init.x + 12, init.x + init.width + dx));
        newW = targetRight - init.x;
      }
      if (handle.includes('n')) {
        const targetY = Math.max(0, Math.min(init.y + init.height - 12, init.y + dy));
        newY = targetY;
        newH = init.y + init.height - targetY;
      }
      if (handle.includes('s')) {
        const targetBottom = Math.min(sheetDimensions.height, Math.max(init.y + 12, init.y + init.height + dy));
        newH = targetBottom - init.y;
      }

      if (lockAspectRatio) {
        const max = Math.max(newW, newH);
        newW = max;
        newH = max;
      }

      setBoxes((prev) =>
        prev.map((b) =>
          b.id === boxId
            ? {
                ...b,
                x: Math.round(newX),
                y: Math.round(newY),
                width: Math.round(newW),
                height: Math.round(newH),
                customized: true,
              }
            : b
        )
      );
      return;
    }


    // 5. DRAW NEW BOX
    if (action.type === 'draw_new') {
      const boxId = action.boxId!;

      const minX = Math.min(action.startX, coords.x);
      const minY = Math.min(action.startY, coords.y);
      const w = Math.max(16, Math.abs(coords.x - action.startX));
      const h = Math.max(16, Math.abs(coords.y - action.startY));

      setBoxes((prev) =>
        prev.map((b) =>
          b.id === boxId
            ? {
                ...b,
                x: Math.round(minX),
                y: Math.round(minY),
                width: Math.round(w),
                height: Math.round(h),
                customized: true,
              }
            : b
        )
      );
      return;
    }
  }, [sheetDimensions, lockAspectRatio, generateUniformGridBoxes, getSvgCoordinates]);


  // Global Mouse Up Listener
  const handleMouseUp = useCallback(() => {
    setIsDragging(false);
    if (dragActionRef.current?.type === 'draw_new') {
      setActiveTool('select');
    }
    dragActionRef.current = null;
  }, []);

  // Window Event Listeners for Dragging
  useEffect(() => {
    if (isDragging) {
      window.addEventListener('mousemove', handleMouseMove);
      window.addEventListener('mouseup', handleMouseUp);
      return () => {
        window.removeEventListener('mousemove', handleMouseMove);
        window.removeEventListener('mouseup', handleMouseUp);
      };
    }
  }, [isDragging, handleMouseMove, handleMouseUp]);

  // Inspector Actions for Selected Box
  const selectedBox = useMemo(() => {
    return boxes.find((b) => b.id === selectedBoxId) || null;
  }, [boxes, selectedBoxId]);

  const updateSelectedBox = (updates: Partial<CropBox>) => {
    if (!selectedBoxId) return;
    setBoxes((prev) =>
      prev.map((b) => {
        if (b.id !== selectedBoxId) return b;
        const updated = { ...b, ...updates, customized: true };
        updated.x = Math.max(0, Math.min(sheetDimensions.width - (updated.width || 8), updated.x));
        updated.y = Math.max(0, Math.min(sheetDimensions.height - (updated.height || 8), updated.y));
        return updated;
      })
    );
  };

  const nudgeSelectedBox = (deltaX: number, deltaY: number) => {
    if (!selectedBox) return;
    updateSelectedBox({
      x: selectedBox.x + deltaX,
      y: selectedBox.y + deltaY,
    });
  };

  const duplicateSelectedBox = () => {
    if (!selectedBox) return;
    const newBox: CropBox = {
      ...selectedBox,
      id: Math.random().toString(36).substring(2, 9),
      x: Math.min(sheetDimensions.width - selectedBox.width, selectedBox.x + 24),
      y: Math.min(sheetDimensions.height - selectedBox.height, selectedBox.y + 24),
      customized: true,
    };
    setBoxes((prev) => [...prev, newBox]);
    setSelectedBoxId(newBox.id);
  };

  const deleteSelectedBox = () => {
    if (!selectedBoxId) return;
    setBoxes((prev) => prev.filter((b) => b.id !== selectedBoxId));
    setSelectedBoxId(null);
  };

  // Zoom Helpers
  const handleZoom = (delta: number) => {
    setZoom((prev) => Math.min(5, Math.max(0.1, Math.round((prev + delta) * 100) / 100)));
  };

  const handleResetZoomPan = () => {
    if (viewportContainerRef.current && sheetDimensions.width > 0) {
      const vpW = viewportContainerRef.current.clientWidth - 48;
      const vpH = viewportContainerRef.current.clientHeight - 48;
      const scale = Math.min(1, Math.min(vpW / sheetDimensions.width, vpH / sheetDimensions.height));
      setZoom(Math.max(0.15, Math.round(scale * 100) / 100));
      setPan({ x: 0, y: 0 });
    } else {
      setZoom(1);
      setPan({ x: 0, y: 0 });
    }
  };

  // Extract Slices from Boxes
  const handleExtractSlices = () => {
    if (!sheetImage || boxes.length === 0) return;
    setIsProcessing(true);
    setErrorMessage(null);

    requestAnimationFrame(() => {
      try {
        let bgR = 255, bgG = 255, bgB = 255;
        if (removeBgColor) {

          const hex = bgColorHex.replace('#', '');
          bgR = parseInt(hex.substring(0, 2), 16);
          bgG = parseInt(hex.substring(2, 4), 16);
          bgB = parseInt(hex.substring(4, 6), 16);
        }

        const newSlices: SlicedStickerItem[] = [];

        boxes.forEach((box, idx) => {
          if (box.width <= 0 || box.height <= 0) return;

          const rawCropCanvas = document.createElement('canvas');
          rawCropCanvas.width = box.width;
          rawCropCanvas.height = box.height;
          const rawCtx = rawCropCanvas.getContext('2d', { willReadFrequently: true });
          if (!rawCtx) return;

          // Draw directly from native sheetImage for 100% source fidelity and crispness
          rawCtx.imageSmoothingEnabled = true;
          rawCtx.imageSmoothingQuality = 'high';
          rawCtx.drawImage(
            sheetImage,
            box.x,
            box.y,
            box.width,
            box.height,
            0,
            0,
            box.width,
            box.height
          );

          if (removeBgColor) {
            const imgData = rawCtx.getImageData(0, 0, box.width, box.height);
            const d = imgData.data;
            const maxDist = (bgTolerance / 100) * 441.67;

            for (let i = 0; i < d.length; i += 4) {
              const r = d[i];
              const g = d[i + 1];
              const b = d[i + 2];
              const a = d[i + 3];
              if (a > 0) {
                const dist = Math.sqrt((r - bgR) ** 2 + (g - bgG) ** 2 + (b - bgB) ** 2);
                if (dist <= maxDist) {
                  d[i + 3] = 0;
                }
              }
            }
            rawCtx.putImageData(imgData, 0, 0);
          }

          let cropCanvas = rawCropCanvas;
          let isEmpty = false;

          if (autoTrim) {
            const imgData = rawCtx.getImageData(0, 0, box.width, box.height);
            const d = imgData.data;
            let minX = box.width;
            let minY = box.height;
            let maxX = 0;
            let maxY = 0;
            let hasVisiblePixel = false;

            for (let py = 0; py < box.height; py++) {
              for (let px = 0; px < box.width; px++) {
                const a = d[(py * box.width + px) * 4 + 3];
                if (a > 15) {
                  hasVisiblePixel = true;
                  if (px < minX) minX = px;
                  if (px > maxX) maxX = px;
                  if (py < minY) minY = py;
                  if (py > maxY) maxY = py;
                }
              }
            }

            if (!hasVisiblePixel) {
              isEmpty = true;
            } else {
              const trimW = maxX - minX + 1;
              const trimH = maxY - minY + 1;

              const trimmedCanvas = document.createElement('canvas');
              trimmedCanvas.width = trimW;
              trimmedCanvas.height = trimH;
              const trimCtx = trimmedCanvas.getContext('2d');
              if (trimCtx) {
                trimCtx.imageSmoothingEnabled = true;
                trimCtx.imageSmoothingQuality = 'high';
                trimCtx.drawImage(rawCropCanvas, minX, minY, trimW, trimH, 0, 0, trimW, trimH);
                cropCanvas = trimmedCanvas;
              }
            }
          }

          const targetCanvas = document.createElement('canvas');
          if (outputResolutionMode === 'native') {
            // Resolusi Asli 100%: Tajam maksimal, tanpa resample/upscale blur (anti-pecah)
            targetCanvas.width = cropCanvas.width;
            targetCanvas.height = cropCanvas.height;
            const targetCtx = targetCanvas.getContext('2d');
            if (targetCtx && !isEmpty) {
              targetCtx.imageSmoothingEnabled = true;
              targetCtx.imageSmoothingQuality = 'high';
              targetCtx.drawImage(cropCanvas, 0, 0);
            }
          } else {
            const targetDimension = outputResolutionMode === '1024' ? 1024 : 512;
            targetCanvas.width = targetDimension;
            targetCanvas.height = targetDimension;
            const targetCtx = targetCanvas.getContext('2d');
            if (targetCtx && !isEmpty) {
              targetCtx.imageSmoothingEnabled = true;
              targetCtx.imageSmoothingQuality = 'high';

              const safeMargin = 20;
              const availSize = targetDimension - safeMargin * 2;

              let scale = Math.min(availSize / cropCanvas.width, availSize / cropCanvas.height);
              // Cegah blur: Jika gambar lebih kecil dari target kanvas dan opsi anti-blur aktif,
              // pertahankan ukuran 1:1 tajam tanpa dipaksa upscale pecah
              if (preventUpscaleBlur && cropCanvas.width < availSize && cropCanvas.height < availSize) {
                scale = 1.0;
              }

              const drawW = Math.round(cropCanvas.width * scale);
              const drawH = Math.round(cropCanvas.height * scale);
              const drawX = Math.round((targetDimension - drawW) / 2);
              const drawY = Math.round((targetDimension - drawH) / 2);

              targetCtx.drawImage(cropCanvas, drawX, drawY, drawW, drawH);
            }
          }


          const padNum = (idx + 1).toString().padStart(2, '0');
          const stickerName = `${namePrefix}_${padNum}`;

          newSlices.push({
            id: `slice_${idx}_${Date.now()}`,
            canvas: targetCanvas,
            previewUrl: targetCanvas.toDataURL('image/png'),
            name: stickerName,
            emoji: '',
            selected: !isEmpty,
            isEmpty,
          });
        });

        setSlices(newSlices);
      } catch (err: any) {
        setErrorMessage('Gagal memotong stiker: ' + err.message);
      } finally {
        setIsProcessing(false);
      }
    });
  };

  // Toggle Slices Selection
  const toggleSelect = (idx: number) => {
    setSlices((prev) =>
      prev.map((s, i) => (i === idx ? { ...s, selected: !s.selected } : s))
    );
  };

  const selectAll = (select: boolean) => {
    setSlices((prev) => prev.map((s) => ({ ...s, selected: select })));
  };

  const updateSlice = (idx: number, field: 'name' | 'emoji', value: string) => {
    setSlices((prev) =>
      prev.map((s, i) => (i === idx ? { ...s, [field]: value } : s))
    );
  };

  const applyPrefixToAll = () => {
    if (!namePrefix.trim()) return;
    setSlices((prev) =>
      prev.map((s, idx) => {
        const padNum = (idx + 1).toString().padStart(2, '0');
        return { ...s, name: `${namePrefix.trim()}_${padNum}` };
      })
    );
  };

  // Upload Slices to Backend Sticker Pack
  const handleUploadAll = async () => {
    const selectedSlices = slices.filter((s) => s.selected);
    if (selectedSlices.length === 0) return;

    setIsUploading(true);
    setUploadProgress({ current: 0, total: selectedSlices.length });
    setErrorMessage(null);

    try {
      const uploadedItems: { name: string; imageUrl: string; emoji?: string }[] = [];

      for (let i = 0; i < selectedSlices.length; i++) {
        const item = selectedSlices[i];
        setUploadProgress({ current: i + 1, total: selectedSlices.length });

        const blob = await new Promise<Blob | null>((resolve) => {
          item.canvas.toBlob((b) => resolve(b), 'image/png');
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
  const masterHandleSize = Math.max(13, Math.min(24, 18 / zoom));
  const boxHandleSize = Math.max(10, Math.min(18, 14 / zoom));


  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Studio Ekstraktor Sprite Sheet Stiker"
      description={`Tarik grid serentak atau sesuaikan stiker individu pada paket "${packName}"`}
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

        {/* Studio Workspace Layout */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-start">
          {/* Left Control Panel (4 cols) */}
          <div className="lg:col-span-4 space-y-3.5 bg-neutral-50/80 p-3.5 rounded-2xl border border-neutral-200/90 text-neutral-800">
            {/* Upload Area */}
            <div className="space-y-1">
              <label className="text-xs font-bold text-neutral-800 flex items-center gap-1.5">
                <Upload className="w-3.5 h-3.5 text-brand-600" />
                Sprite Sheet / Atlas Gambar
              </label>

              <div className="border-2 border-dashed border-neutral-300 rounded-xl p-3 text-center hover:border-brand-500 transition-colors cursor-pointer relative bg-white">
                <input
                  type="file"
                  accept="image/png,image/webp,image/jpeg"
                  onChange={handleSheetUpload}
                  className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                />
                {sheetFile ? (
                  <div className="space-y-0.5 text-neutral-700">
                    <p className="text-xs font-bold truncate max-w-[240px] mx-auto text-brand-700">{sheetFile.name}</p>
                    <p className="text-[11px] text-neutral-500 font-mono">
                      {sheetDimensions.width} x {sheetDimensions.height} px • {boxes.length} stiker terdeteksi
                    </p>
                  </div>
                ) : (
                  <div className="space-y-1 text-neutral-500 py-1">
                    <Scissors className="w-5 h-5 mx-auto text-neutral-400" />
                    <p className="text-xs font-semibold text-neutral-800">Pilih File Sprite Sheet</p>
                    <p className="text-[10px] text-neutral-400">PNG transparan atau latar solid (WEBP/JPG)</p>
                  </div>
                )}
              </div>
            </div>

            {/* UNIFIED GRID CONTROLLER (Pengaturan Matriks) */}
            <div className="space-y-3 bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider flex items-center gap-1">
                  <Grid className="w-3.5 h-3.5 text-brand-600" />
                  Matriks Grid Fleksibel
                </span>
                <button
                  type="button"
                  onClick={handleResetToUniformGrid}
                  className="text-[10px] font-semibold text-brand-600 hover:text-brand-700 hover:underline flex items-center gap-1"
                  title="Kembalikan semua kotak ke ukuran rata"
                >
                  <RotateCcw className="w-2.5 h-2.5" />
                  Ratakan Grid
                </button>
              </div>

              {/* Fit 100% Full Image Button */}
              <button
                type="button"
                onClick={handleFitMasterGridToFullImage}
                disabled={!sheetImage}
                className="w-full flex items-center justify-center gap-1.5 py-1.5 rounded-lg bg-brand-500 hover:bg-brand-600 text-white text-[11px] font-bold transition-all disabled:opacity-40 disabled:cursor-not-allowed shadow-sm"
                title="Paskan seluruh grid menutupi 100% tinggi dan lebar gambar"
              >
                <Maximize2 className="w-3.5 h-3.5" />
                Penuh 100% Ukuran Gambar
              </button>

              {/* Quick Presets Pills */}
              <div className="space-y-1">
                <span className="text-[10px] font-semibold text-neutral-500">Preset Grid Cepat:</span>
                <div className="flex flex-wrap gap-1">
                  {[
                    { label: '6 × 4 (24)', c: 6, r: 4 },
                    { label: '4 × 3 (12)', c: 4, r: 3 },
                    { label: '4 × 4 (16)', c: 4, r: 4 },
                    { label: '3 × 3 (9)',  c: 3, r: 3 },
                    { label: '5 × 4 (20)', c: 5, r: 4 },
                    { label: '6 × 5 (30)', c: 6, r: 5 },
                    { label: '3 × 4 (12)', c: 3, r: 4 },
                    { label: '2 × 2 (4)',  c: 2, r: 2 },
                  ].map((preset) => {
                    const isActive = cols === preset.c && rows === preset.r;
                    return (
                      <button
                        key={preset.label}
                        type="button"
                        onClick={() => updateGridColsRows(preset.c, preset.r, true)}
                        className={`text-[10px] px-2 py-0.5 rounded-md font-bold transition-all ${
                          isActive
                            ? 'bg-brand-500 text-white shadow-2xs'
                            : 'bg-neutral-100 hover:bg-neutral-200 text-neutral-600'
                        }`}
                      >
                        {preset.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Manual Columns & Rows Inputs */}
              <div className="grid grid-cols-2 gap-2 text-xs">
                <div className="space-y-1">
                  <span className="text-[10px] font-semibold text-neutral-500 flex items-center gap-1">
                    <Columns className="w-3 h-3 text-brand-600" /> Kolom
                  </span>
                  <div className="flex items-center gap-1">
                    <button
                      type="button"
                      onClick={() => updateGridColsRows(cols - 1, rows)}
                      className="px-2 py-1 rounded bg-neutral-100 hover:bg-neutral-200 text-xs font-bold"
                    >
                      -
                    </button>
                    <input
                      type="number"
                      min="1"
                      max="24"
                      value={cols}
                      onChange={(e) => updateGridColsRows(parseInt(e.target.value) || 1, rows)}
                      className="w-full text-center py-1 font-bold rounded border border-neutral-200 bg-neutral-50"
                    />
                    <button
                      type="button"
                      onClick={() => updateGridColsRows(cols + 1, rows)}
                      className="px-2 py-1 rounded bg-neutral-100 hover:bg-neutral-200 text-xs font-bold"
                    >
                      +
                    </button>
                  </div>
                </div>

                <div className="space-y-1">
                  <span className="text-[10px] font-semibold text-neutral-500 flex items-center gap-1">
                    <Rows className="w-3 h-3 text-brand-600" /> Baris
                  </span>
                  <div className="flex items-center gap-1">
                    <button
                      type="button"
                      onClick={() => updateGridColsRows(cols, rows - 1)}
                      className="px-2 py-1 rounded bg-neutral-100 hover:bg-neutral-200 text-xs font-bold"
                    >
                      -
                    </button>
                    <input
                      type="number"
                      min="1"
                      max="24"
                      value={rows}
                      onChange={(e) => updateGridColsRows(cols, parseInt(e.target.value) || 1)}
                      className="w-full text-center py-1 font-bold rounded border border-neutral-200 bg-neutral-50"
                    />
                    <button
                      type="button"
                      onClick={() => updateGridColsRows(cols, rows + 1)}
                      className="px-2 py-1 rounded bg-neutral-100 hover:bg-neutral-200 text-xs font-bold"
                    >
                      +
                    </button>
                  </div>
                </div>
              </div>

              {/* Spacing Sliders */}
              <div className="grid grid-cols-2 gap-2 text-xs pt-1 border-t border-neutral-100">
                <div className="space-y-1">
                  <div className="flex justify-between text-[10px] text-neutral-500">
                    <span>Jeda X</span>
                    <span className="font-mono">{spacingX}px</span>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="64"
                    value={spacingX}
                    onChange={(e) => {
                      const val = parseInt(e.target.value);
                      setSpacingX(val);
                      setBoxes(generateUniformGridBoxes(gridX, gridY, gridWidth, gridHeight, cols, rows, val, spacingY));
                    }}
                    className="w-full accent-brand-500 h-1 bg-neutral-200 rounded-lg cursor-pointer"
                  />
                </div>

                <div className="space-y-1">
                  <div className="flex justify-between text-[10px] text-neutral-500">
                    <span>Jeda Y</span>
                    <span className="font-mono">{spacingY}px</span>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="64"
                    value={spacingY}
                    onChange={(e) => {
                      const val = parseInt(e.target.value);
                      setSpacingY(val);
                      setBoxes(generateUniformGridBoxes(gridX, gridY, gridWidth, gridHeight, cols, rows, spacingX, val));
                    }}
                    className="w-full accent-brand-500 h-1 bg-neutral-200 rounded-lg cursor-pointer"
                  />
                </div>
              </div>

              {/* Grid Snap & Alignment Tools */}
              <div className="space-y-1.5 pt-1.5 border-t border-neutral-100">
                <span className="text-[10px] font-semibold text-neutral-500">Paskan Grid ke Gambar:</span>
                <div className="grid grid-cols-2 gap-1.5">
                  <button
                    type="button"
                    onClick={handleFitMasterGridToFullImage}
                    disabled={!sheetImage}
                    className="py-1 text-xs font-bold rounded-lg bg-brand-50 hover:bg-brand-100 text-brand-800 border border-brand-300 transition-colors text-center shadow-2xs"
                    title="Ratakan seluruh grid memenuhi 100% ukuran file gambar (ujung ke ujung)"
                  >
                    Penuh (100%)
                  </button>
                  <button
                    type="button"
                    onClick={handleFitMasterGridWithMargin}
                    disabled={!sheetImage}
                    className="py-1 text-xs font-semibold rounded-lg bg-neutral-100 hover:bg-neutral-200 text-neutral-700 transition-colors text-center"
                    title="Pusatkan grid dengan margin 2% di tiap sisi"
                  >
                    Margin (96%)
                  </button>
                </div>

                <div className="grid grid-cols-2 gap-1.5 pt-0.5">
                  <button
                    type="button"
                    onClick={handleSnapMasterGridToTop}
                    disabled={!sheetImage}
                    className="py-1 text-[11px] font-medium rounded-lg bg-neutral-100 hover:bg-neutral-200 text-neutral-700 transition-colors text-center flex items-center justify-center gap-1"
                    title="Tarik sisi atas grid langsung ke ujung paling atas gambar (Y=0)"
                  >
                    <ArrowUp className="w-3 h-3 text-brand-600" />
                    Paling Atas (Y=0)
                  </button>
                  <button
                    type="button"
                    onClick={handleSnapMasterGridToBottom}
                    disabled={!sheetImage}
                    className="py-1 text-[11px] font-medium rounded-lg bg-neutral-100 hover:bg-neutral-200 text-neutral-700 transition-colors text-center flex items-center justify-center gap-1"
                    title="Tarik sisi bawah grid langsung ke ujung paling bawah gambar"
                  >
                    <ArrowDown className="w-3 h-3 text-brand-600" />
                    Paling Bawah
                  </button>
                </div>

                {/* Geser Grid Manual (Nudge) */}
                <div className="flex items-center justify-between pt-1">
                  <span className="text-[10px] text-neutral-500 font-semibold">Geser Posisi Grid:</span>
                  <div className="flex items-center gap-1">
                    <button
                      type="button"
                      onClick={() => handleNudgeMasterGrid(-16, 0)}
                      disabled={!sheetImage}
                      className="p-1 rounded bg-neutral-100 hover:bg-neutral-200 text-neutral-700"
                      title="Geser Grid ke Kiri (16px)"
                    >
                      <ArrowLeft className="w-3 h-3" />
                    </button>
                    <button
                      type="button"
                      onClick={() => handleNudgeMasterGrid(0, -16)}
                      disabled={!sheetImage}
                      className="p-1 rounded bg-neutral-100 hover:bg-neutral-200 text-neutral-700"
                      title="Geser Grid ke Atas (16px)"
                    >
                      <ArrowUp className="w-3 h-3" />
                    </button>
                    <button
                      type="button"
                      onClick={() => handleNudgeMasterGrid(0, 16)}
                      disabled={!sheetImage}
                      className="p-1 rounded bg-neutral-100 hover:bg-neutral-200 text-neutral-700"
                      title="Geser Grid ke Bawah (16px)"
                    >
                      <ArrowDown className="w-3 h-3" />
                    </button>
                    <button
                      type="button"
                      onClick={() => handleNudgeMasterGrid(16, 0)}
                      disabled={!sheetImage}
                      className="p-1 rounded bg-neutral-100 hover:bg-neutral-200 text-neutral-700"
                      title="Geser Grid ke Kanan (16px)"
                    >
                      <ArrowRight className="w-3 h-3" />
                    </button>
                  </div>
                </div>
              </div>
            </div>



            {/* INDIVIDUAL FRAME INSPECTOR (Ubah Ukuran Stiker Tertentu / By-Frame) */}
            <div className="bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs space-y-2.5">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider flex items-center gap-1.5">
                  <Layers className="w-3.5 h-3.5 text-brand-600" />
                  Inspector Kotak Stiker
                </span>
                {selectedBox && (
                  <Badge variant={selectedBox.customized ? 'brand' : 'neutral'} size="sm">
                    {selectedBox.customized ? 'Ukuran Khusus' : 'Sesuai Grid'}
                  </Badge>
                )}
              </div>

              {selectedBox ? (
                <div className="space-y-2.5">
                  <div className="flex items-center justify-between text-xs bg-neutral-50 p-2 rounded-lg border border-neutral-200/80">
                    <span className="font-bold text-brand-800">
                      Stiker #{boxes.findIndex((b) => b.id === selectedBox.id) + 1}
                    </span>
                    <div className="flex items-center gap-1.5">
                      {selectedBox.customized && (
                        <button
                          type="button"
                          onClick={() => handleResetSingleBoxToGrid(selectedBox.id)}
                          className="text-[10px] text-neutral-500 hover:text-brand-600 underline"
                          title="Kembalikan ukuran kotak ini ke standar grid"
                        >
                          Reset ke Grid
                        </button>
                      )}
                      <span className="text-[10px] font-mono text-neutral-500">
                        {selectedBox.width} × {selectedBox.height} px
                      </span>
                    </div>
                  </div>

                  {/* Manual Coordinate & Dimension Inputs */}
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div className="space-y-0.5">
                      <span className="text-[10px] font-semibold text-neutral-500">Posisi X (Px)</span>
                      <input
                        type="number"
                        min="0"
                        max={sheetDimensions.width}
                        value={selectedBox.x}
                        onChange={(e) => updateSelectedBox({ x: parseInt(e.target.value) || 0 })}
                        className="w-full px-2 py-1 font-mono text-xs font-bold rounded-lg border border-neutral-200 bg-neutral-50/50"
                      />
                    </div>
                    <div className="space-y-0.5">
                      <span className="text-[10px] font-semibold text-neutral-500">Posisi Y (Px)</span>
                      <input
                        type="number"
                        min="0"
                        max={sheetDimensions.height}
                        value={selectedBox.y}
                        onChange={(e) => updateSelectedBox({ y: parseInt(e.target.value) || 0 })}
                        className="w-full px-2 py-1 font-mono text-xs font-bold rounded-lg border border-neutral-200 bg-neutral-50/50"
                      />
                    </div>
                    <div className="space-y-0.5">
                      <span className="text-[10px] font-semibold text-neutral-500">Lebar / W (Px)</span>
                      <input
                        type="number"
                        min="8"
                        max={sheetDimensions.width}
                        value={selectedBox.width}
                        onChange={(e) => updateSelectedBox({ width: parseInt(e.target.value) || 8 })}
                        className="w-full px-2 py-1 font-mono text-xs font-bold rounded-lg border border-neutral-200 bg-neutral-50/50 text-brand-700"
                      />
                    </div>
                    <div className="space-y-0.5">
                      <span className="text-[10px] font-semibold text-neutral-500">Tinggi / H (Px)</span>
                      <input
                        type="number"
                        min="8"
                        max={sheetDimensions.height}
                        value={selectedBox.height}
                        onChange={(e) => updateSelectedBox({ height: parseInt(e.target.value) || 8 })}
                        className="w-full px-2 py-1 font-mono text-xs font-bold rounded-lg border border-neutral-200 bg-neutral-50/50 text-brand-700"
                      />
                    </div>
                  </div>

                  {/* Inspector Nudge & Tools */}
                  <div className="flex items-center justify-between pt-1 border-t border-neutral-100">
                    <button
                      type="button"
                      onClick={() => setLockAspectRatio(!lockAspectRatio)}
                      className={`text-[11px] font-semibold flex items-center gap-1 px-2 py-1 rounded-lg border transition-all ${
                        lockAspectRatio ? 'bg-brand-50 border-brand-300 text-brand-700' : 'border-neutral-200 text-neutral-500'
                      }`}
                      title="Kunci rasio 1:1 (persegi)"
                    >
                      {lockAspectRatio ? <Lock className="w-3 h-3 text-brand-600" /> : <Unlock className="w-3 h-3" />}
                      <span>1:1</span>
                    </button>

                    {/* Nudge Buttons */}
                    <div className="flex items-center gap-1">
                      <button
                        type="button"
                        onClick={() => nudgeSelectedBox(-2, 0)}
                        className="p-1 rounded bg-neutral-100 hover:bg-neutral-200 text-neutral-600"
                        title="Geser Kiri (2px)"
                      >
                        <ArrowLeft className="w-3 h-3" />
                      </button>
                      <button
                        type="button"
                        onClick={() => nudgeSelectedBox(0, -2)}
                        className="p-1 rounded bg-neutral-100 hover:bg-neutral-200 text-neutral-600"
                        title="Geser Atas (2px)"
                      >
                        <ArrowUp className="w-3 h-3" />
                      </button>
                      <button
                        type="button"
                        onClick={() => nudgeSelectedBox(0, 2)}
                        className="p-1 rounded bg-neutral-100 hover:bg-neutral-200 text-neutral-600"
                        title="Geser Bawah (2px)"
                      >
                        <ArrowDown className="w-3 h-3" />
                      </button>
                      <button
                        type="button"
                        onClick={() => nudgeSelectedBox(2, 0)}
                        className="p-1 rounded bg-neutral-100 hover:bg-neutral-200 text-neutral-600"
                        title="Geser Kanan (2px)"
                      >
                        <ArrowRight className="w-3 h-3" />
                      </button>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-1">
                      <button
                        type="button"
                        onClick={duplicateSelectedBox}
                        className="p-1 rounded bg-neutral-100 hover:bg-neutral-200 text-neutral-600"
                        title="Duplikat Kotak Ini"
                      >
                        <Copy className="w-3.5 h-3.5" />
                      </button>
                      <button
                        type="button"
                        onClick={deleteSelectedBox}
                        className="p-1 rounded bg-rose-50 hover:bg-rose-100 text-rose-600"
                        title="Hapus Kotak Ini"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="text-center py-2.5 text-neutral-400 text-xs space-y-1">
                  <MousePointer className="w-4 h-4 mx-auto text-neutral-300" />
                  <p>Klik kotak stiker manapun di kanvas untuk menyesuaikan ukuran atau posisinya secara bebas.</p>
                </div>
              )}
            </div>

            {/* Smart Auto-Detect Button (Proximity Merging) */}
            <div className="bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider">
                  Deteksi Kontur Cerdas
                </span>
                <span className="text-[10px] text-brand-600 font-semibold">Proximity 28px</span>
              </div>
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="w-full text-xs font-bold justify-center border-brand-300 hover:border-brand-500 hover:bg-brand-50/50 text-brand-700"
                disabled={!sheetImage || isProcessing}
                isLoading={isProcessing}
                onClick={handleAutoDetectFrames}
                icon={<Sparkles className="w-3.5 h-3.5 text-brand-500" />}
              >
                Deteksi Otomatis & Gabung Bagian Tubuh
              </Button>
            </div>

            {/* Magic Chroma Key (Background Color Removal) */}
            <div className="space-y-2 bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs">
              <label className="flex items-center justify-between cursor-pointer">
                <span className="text-xs font-bold text-neutral-800 flex items-center gap-1.5">
                  <Wand2 className="w-3.5 h-3.5 text-brand-600" />
                  Hapus Background Warna Solid
                </span>
                <input
                  type="checkbox"
                  checked={removeBgColor}
                  onChange={(e) => setRemoveBgColor(e.target.checked)}
                  className="rounded text-brand-600 focus:ring-brand-500 w-4 h-4 cursor-pointer"
                />
              </label>

              {removeBgColor && (
                <div className="space-y-2 pt-1 border-t border-neutral-100 text-xs">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[11px] text-neutral-500">Warna Latar:</span>
                    <div className="flex items-center gap-1.5">
                      <input
                        type="color"
                        value={bgColorHex}
                        onChange={(e) => setBgColorHex(e.target.value.toUpperCase())}
                        className="w-6 h-6 rounded border border-neutral-300 cursor-pointer p-0"
                      />
                      <span className="font-mono text-xs text-neutral-700">{bgColorHex}</span>
                      <button
                        type="button"
                        onClick={() => setActiveTool('eyedropper')}
                        className={`p-1 rounded border transition-colors ${
                          activeTool === 'eyedropper' ? 'bg-brand-500 text-white border-brand-600' : 'bg-neutral-100 text-neutral-600 border-neutral-200'
                        }`}
                        title="Pipet Warna: Klik pada gambar untuk mengambil warna latar"
                      >
                        <Pipette className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>

                  <div className="space-y-1">
                    <div className="flex justify-between text-[11px] text-neutral-500">
                      <span>Toleransi Warna</span>
                      <span>{bgTolerance}%</span>
                    </div>
                    <input
                      type="range"
                      min="5"
                      max="75"
                      value={bgTolerance}
                      onChange={(e) => setBgTolerance(parseInt(e.target.value))}
                      className="w-full accent-brand-500 h-1.5 bg-neutral-200 rounded-lg cursor-pointer"
                    />
                  </div>
                </div>
              )}
            </div>

            {/* Resolution & Quality Controls (Anti-Pecah) */}
            <div className="bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs space-y-2.5">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider flex items-center gap-1.5">
                  <Sparkles className="w-3.5 h-3.5 text-brand-600" />
                  Resolusi & Kualitas Stiker
                </span>
                <Badge variant="brand" size="sm">Anti-Pecah</Badge>
              </div>

              {/* Resolution Mode Selector */}
              <div className="space-y-1">
                <span className="text-[10px] font-semibold text-neutral-500">Ukuran Target Kanvas:</span>
                <div className="grid grid-cols-3 gap-1">
                  <button
                    type="button"
                    onClick={() => setOutputResolutionMode('512')}
                    className={`px-2 py-1.5 rounded-lg text-xs font-bold transition-all text-center border ${
                      outputResolutionMode === '512'
                        ? 'bg-brand-50 border-brand-500 text-brand-800 ring-1 ring-brand-400'
                        : 'bg-neutral-50 border-neutral-200 text-neutral-600 hover:bg-neutral-100'
                    }`}
                  >
                    512×512
                    <span className="block text-[9px] font-normal text-neutral-400">Standar</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setOutputResolutionMode('native')}
                    className={`px-2 py-1.5 rounded-lg text-xs font-bold transition-all text-center border ${
                      outputResolutionMode === 'native'
                        ? 'bg-brand-50 border-brand-500 text-brand-800 ring-1 ring-brand-400'
                        : 'bg-neutral-50 border-neutral-200 text-neutral-600 hover:bg-neutral-100'
                    }`}
                  >
                    Asli (HD)
                    <span className="block text-[9px] font-normal text-brand-600">0% Pecah</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setOutputResolutionMode('1024')}
                    className={`px-2 py-1.5 rounded-lg text-xs font-bold transition-all text-center border ${
                      outputResolutionMode === '1024'
                        ? 'bg-brand-50 border-brand-500 text-brand-800 ring-1 ring-brand-400'
                        : 'bg-neutral-50 border-neutral-200 text-neutral-600 hover:bg-neutral-100'
                    }`}
                  >
                    1024×1024
                    <span className="block text-[9px] font-normal text-neutral-400">Super HD</span>
                  </button>
                </div>
              </div>

              {/* Anti-Blur Toggle */}
              {outputResolutionMode !== 'native' && (
                <label className="flex items-start gap-2 pt-1 border-t border-neutral-100 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={preventUpscaleBlur}
                    onChange={(e) => setPreventUpscaleBlur(e.target.checked)}
                    className="rounded text-brand-600 focus:ring-brand-500 w-3.5 h-3.5 mt-0.5"
                  />
                  <div className="space-y-0.5">
                    <span className="text-[11px] font-bold text-neutral-800 block">Jaga Ketajaman (Cegah Blur)</span>
                    <p className="text-[10px] text-neutral-400 leading-snug">
                      Mencegah gambar kecil ditarik melebihi ukuran aslinya agar stiker tidak pecah atau kabur.
                    </p>
                  </div>
                </label>
              )}

              {/* Auto-Trim Toggle */}
              <label className="flex items-start gap-2 pt-1 border-t border-neutral-100 cursor-pointer">
                <input
                  type="checkbox"
                  checked={autoTrim}
                  onChange={(e) => setAutoTrim(e.target.checked)}
                  className="rounded text-brand-600 focus:ring-brand-500 w-3.5 h-3.5 mt-0.5"
                />
                <div className="space-y-0.5">
                  <span className="text-[11px] font-bold text-neutral-800 block">Auto-Trim Area Transparan</span>
                  <p className="text-[10px] text-neutral-400 leading-snug">
                    Memangkas ruang kosong transparan di sekitar karakter stiker agar pas.
                  </p>
                </div>
              </label>
            </div>


            {/* Extract Slices Button */}
            <Button
              type="button"
              variant="primary"
              className="w-full py-2.5 bg-brand-500 hover:bg-brand-600 text-white font-bold shadow-sm"
              disabled={!sheetImage || boxes.length === 0 || isProcessing}
              isLoading={isProcessing}
              onClick={handleExtractSlices}
              icon={<Scissors className="w-4 h-4" />}
            >
              Ekstrak {boxes.length} Stiker
            </Button>
          </div>

          {/* Right Interactive Canvas Viewport (8 cols) */}
          <div className="lg:col-span-8 space-y-2">
            {/* Viewport Toolbar */}
            <div className="flex flex-wrap items-center justify-between gap-2 bg-neutral-50 px-3 py-2 rounded-xl border border-neutral-200 text-xs">
              {/* Tool Selector */}
              <div className="flex items-center bg-white rounded-lg p-0.5 border border-neutral-200 shadow-2xs">
                <button
                  type="button"
                  onClick={() => setActiveTool('select')}
                  className={`px-2.5 py-1 rounded-md font-semibold flex items-center gap-1.5 transition-all ${
                    activeTool === 'select' ? 'bg-brand-500 text-white shadow-xs' : 'text-neutral-600 hover:bg-neutral-100'
                  }`}
                  title="Pilih & Tarik Kotak (Select & Drag)"
                >
                  <MousePointer className="w-3.5 h-3.5" />
                  <span>Pilih & Tarik</span>
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTool('add_box')}
                  className={`px-2.5 py-1 rounded-md font-semibold flex items-center gap-1.5 transition-all ${
                    activeTool === 'add_box' ? 'bg-brand-500 text-white shadow-xs' : 'text-neutral-600 hover:bg-neutral-100'
                  }`}
                  title="Tarik Kursor di Kanvas untuk Menambah Kotak Baru"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>+ Kotak Baru</span>
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTool('pan')}
                  className={`px-2.5 py-1 rounded-md font-semibold flex items-center gap-1.5 transition-all ${
                    activeTool === 'pan' || isSpacePressed ? 'bg-brand-500 text-white shadow-xs' : 'text-neutral-600 hover:bg-neutral-100'
                  }`}
                  title="Geser Kanvas (Tahan Spacebar)"
                >
                  <Move className="w-3.5 h-3.5" />
                  <span>Geser</span>
                </button>
              </div>

              {/* Zoom & Fit Controls */}
              <div className="flex items-center gap-1.5">
                <button
                  type="button"
                  onClick={() => handleZoom(-0.1)}
                  className="p-1.5 rounded-lg bg-white border border-neutral-200 text-neutral-600 hover:bg-neutral-100"
                  title="Perkecil Kanvas"
                >
                  <ZoomOut className="w-3.5 h-3.5" />
                </button>
                <span className="font-mono text-xs font-bold text-neutral-700 min-w-[42px] text-center">
                  {Math.round(zoom * 100)}%
                </span>
                <button
                  type="button"
                  onClick={() => handleZoom(0.1)}
                  className="p-1.5 rounded-lg bg-white border border-neutral-200 text-neutral-600 hover:bg-neutral-100"
                  title="Perbesar Kanvas"
                >
                  <ZoomIn className="w-3.5 h-3.5" />
                </button>
                <button
                  type="button"
                  onClick={handleResetZoomPan}
                  className="p-1.5 rounded-lg bg-white border border-neutral-200 text-neutral-600 hover:bg-neutral-100"
                  title="Sesuaikan dengan Layar"
                >
                  <RefreshCw className="w-3.5 h-3.5" />
                </button>
              </div>

              {/* Status Badge */}
              <div className="flex items-center gap-2">
                <Badge variant="brand" size="sm">
                  {boxes.length} Kotak Stiker
                </Badge>
              </div>
            </div>

            {/* Interactive Viewport Container */}
            <div
              ref={viewportContainerRef}
              onMouseDown={handleMouseDown}
              className={`w-full h-[490px] rounded-2xl border border-neutral-200/90 overflow-hidden relative select-none flex items-center justify-center ${
                activeTool === 'pan' || isSpacePressed
                  ? 'cursor-grab active:cursor-grabbing'
                  : activeTool === 'add_box'
                  ? 'cursor-crosshair'
                  : activeTool === 'eyedropper'
                  ? 'cursor-cell'
                  : 'cursor-default'
              }`}
              style={{
                backgroundColor: '#ffffff',
                backgroundImage:
                  'linear-gradient(45deg, #f1f5f9 25%, transparent 25%), linear-gradient(-45deg, #f1f5f9 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f1f5f9 75%), linear-gradient(-45deg, transparent 75%, #f1f5f9 75%)',
                backgroundSize: '16px 16px',
                backgroundPosition: '0 0, 0 8px, 8px -8px, -8px 0px',
              }}
            >
              {sheetImageSrc && sheetDimensions.width > 0 ? (
                <div
                  className="relative origin-center"
                  style={{
                    width: sheetDimensions.width,
                    height: sheetDimensions.height,
                    transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom})`,
                    transition: isDragging ? 'none' : 'transform 75ms ease-out',
                  }}
                >
                  {/* Native Crisp Sprite Sheet Image (Guaranteed to show, 0 lag) */}
                  <img
                    src={sheetImageSrc}
                    alt="Sprite Sheet"
                    className="absolute inset-0 pointer-events-none select-none drop-shadow-md rounded"
                    style={{
                      width: sheetDimensions.width,
                      height: sheetDimensions.height,
                      imageRendering: zoom > 1.2 ? 'pixelated' : 'auto',
                    }}
                  />


                  {/* SVG Overlay: Crisp, Thin, Zero-Drift Coordinate Interactive Layer */}
                  <svg
                    ref={svgOverlayRef}
                    viewBox={`0 0 ${sheetDimensions.width} ${sheetDimensions.height}`}
                    className="absolute inset-0 w-full h-full pointer-events-auto"
                    width={sheetDimensions.width}
                    height={sheetDimensions.height}
                    overflow="visible"
                  >
                    {/* Layer 1: Individual Sticker Cells */}
                    {boxes.map((box, idx) => {
                      const isSelected = box.id === selectedBoxId;
                      return (
                        <g
                          key={box.id}
                          className="cursor-pointer"
                          onMouseDown={(e) => handleBoxMouseDown(e, box)}
                          onClick={(e) => {
                            e.stopPropagation();
                            setSelectedBoxId(box.id);
                          }}
                        >
                          {/* Cell Body & Stroke */}
                          <rect
                            x={box.x}
                            y={box.y}
                            width={box.width}
                            height={box.height}
                            fill={isSelected ? 'rgba(0, 200, 150, 0.12)' : 'rgba(0, 200, 150, 0.04)'}
                            stroke={isSelected ? '#00C896' : 'rgba(0, 200, 150, 0.75)'}
                            strokeWidth={isSelected ? Math.max(1.8, 2.5 / zoom) : Math.max(1, 1.2 / zoom)}
                            strokeDasharray={isSelected ? undefined : `${4 / zoom},${3 / zoom}`}
                            className={isSelected ? 'cursor-move' : 'hover:stroke-brand-500'}
                          />

                          {/* Cell Badge Number */}
                          <rect
                            x={box.x + 2}
                            y={box.y + 2}
                            width={Math.max(18, 20 / zoom)}
                            height={Math.max(12, 14 / zoom)}
                            fill={isSelected ? '#00C896' : 'rgba(0, 200, 150, 0.85)'}
                            rx={3 / zoom}
                            className="pointer-events-none"
                          />
                          <text
                            x={box.x + Math.max(9, 10 / zoom)}
                            y={box.y + Math.max(9, 11 / zoom)}
                            textAnchor="middle"
                            fill="#FFFFFF"
                            fontSize={Math.max(8, 9 / zoom)}
                            fontFamily="monospace"
                            fontWeight="bold"
                            className="pointer-events-none select-none"
                          >
                            {idx + 1}
                          </text>

                          {/* 8-Point Isolated Handles on Selected Box (Allows resizing this specific frame!) */}
                          {isSelected && (
                            <>
                              {/* NW */}
                              <rect
                                x={box.x - boxHandleSize / 2}
                                y={box.y - boxHandleSize / 2}
                                width={boxHandleSize}
                                height={boxHandleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-nwse-resize"
                                onMouseDown={(e) => handleBoxHandleMouseDown(e, box, 'nw')}
                              />
                              {/* N */}
                              <rect
                                x={box.x + box.width / 2 - boxHandleSize / 2}
                                y={box.y - boxHandleSize / 2}
                                width={boxHandleSize}
                                height={boxHandleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-ns-resize"
                                onMouseDown={(e) => handleBoxHandleMouseDown(e, box, 'n')}
                              />
                              {/* NE */}
                              <rect
                                x={box.x + box.width - boxHandleSize / 2}
                                y={box.y - boxHandleSize / 2}
                                width={boxHandleSize}
                                height={boxHandleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-nesw-resize"
                                onMouseDown={(e) => handleBoxHandleMouseDown(e, box, 'ne')}
                              />
                              {/* E (Melebarkan stiker ini secara khusus) */}
                              <rect
                                x={box.x + box.width - boxHandleSize / 2}
                                y={box.y + box.height / 2 - boxHandleSize / 2}
                                width={boxHandleSize}
                                height={boxHandleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-ew-resize"
                                onMouseDown={(e) => handleBoxHandleMouseDown(e, box, 'e')}
                              />
                              {/* SE */}
                              <rect
                                x={box.x + box.width - boxHandleSize / 2}
                                y={box.y + box.height - boxHandleSize / 2}
                                width={boxHandleSize}
                                height={boxHandleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-nwse-resize"
                                onMouseDown={(e) => handleBoxHandleMouseDown(e, box, 'se')}
                              />
                              {/* S */}
                              <rect
                                x={box.x + box.width / 2 - boxHandleSize / 2}
                                y={box.y + box.height - boxHandleSize / 2}
                                width={boxHandleSize}
                                height={boxHandleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-ns-resize"
                                onMouseDown={(e) => handleBoxHandleMouseDown(e, box, 's')}
                              />
                              {/* SW */}
                              <rect
                                x={box.x - boxHandleSize / 2}
                                y={box.y + box.height - boxHandleSize / 2}
                                width={boxHandleSize}
                                height={boxHandleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-nesw-resize"
                                onMouseDown={(e) => handleBoxHandleMouseDown(e, box, 'sw')}
                              />
                              {/* W */}
                              <rect
                                x={box.x - boxHandleSize / 2}
                                y={box.y + box.height / 2 - boxHandleSize / 2}
                                width={boxHandleSize}
                                height={boxHandleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-ew-resize"
                                onMouseDown={(e) => handleBoxHandleMouseDown(e, box, 'w')}
                              />
                            </>
                          )}
                        </g>
                      );
                    })}

                    {/* Layer 2: Master Boundary Box (Outer Boundary with 8 Master Handles to Stretch All Grid) */}
                    {gridWidth > 0 && gridHeight > 0 && (
                      <g className="master-outer-boundary">
                        {/* Master Drag Header Badge */}
                        <g
                          className="cursor-move"
                          onMouseDown={handleMasterGridMouseDown}
                          style={{ pointerEvents: 'all' }}
                        >
                          <rect
                            x={gridX}
                            y={Math.max(2, gridY - Math.max(22, 26 / zoom))}
                            width={Math.max(120, 140 / zoom)}
                            height={Math.max(18, 22 / zoom)}
                            rx={4 / zoom}
                            fill="#00C896"
                          />
                          <text
                            x={gridX + Math.max(60, 70 / zoom)}
                            y={Math.max(2, gridY - Math.max(22, 26 / zoom)) + Math.max(12, 15 / zoom)}
                            textAnchor="middle"
                            fill="#FFFFFF"
                            fontSize={Math.max(9, 11 / zoom)}
                            fontWeight="bold"
                            className="select-none pointer-events-none"
                          >
                            ✢ Geser Grid ({cols}×{rows})
                          </text>
                        </g>

                        {/* Outer Master Border (Drag to move entire grid by clicking border stroke) */}
                        <rect
                          x={gridX}
                          y={gridY}
                          width={gridWidth}
                          height={gridHeight}
                          fill="none"
                          stroke="#00C896"
                          strokeWidth={Math.max(2, 3 / zoom)}
                          pointerEvents="stroke"
                          className="cursor-move"
                          onMouseDown={handleMasterGridMouseDown}
                        />

                        {/* 8 Master Handles (Tarik untuk Melebarkan Seluruh Matriks Grid Bersamaan) */}
                        {/* NW */}
                        <rect
                          x={gridX - masterHandleSize / 2}
                          y={gridY - masterHandleSize / 2}
                          width={masterHandleSize}
                          height={masterHandleSize}
                          fill="#00C896"
                          stroke="#FFFFFF"
                          strokeWidth={1.5 / zoom}
                          className="cursor-nwse-resize"
                          onMouseDown={(e) => handleMasterHandleMouseDown(e, 'nw')}
                        />
                        {/* N */}
                        <rect
                          x={gridX + gridWidth / 2 - masterHandleSize / 2}
                          y={gridY - masterHandleSize / 2}
                          width={masterHandleSize}
                          height={masterHandleSize}
                          fill="#00C896"
                          stroke="#FFFFFF"
                          strokeWidth={1.5 / zoom}
                          className="cursor-ns-resize"
                          onMouseDown={(e) => handleMasterHandleMouseDown(e, 'n')}
                        />
                        {/* NE */}
                        <rect
                          x={gridX + gridWidth - masterHandleSize / 2}
                          y={gridY - masterHandleSize / 2}
                          width={masterHandleSize}
                          height={masterHandleSize}
                          fill="#00C896"
                          stroke="#FFFFFF"
                          strokeWidth={1.5 / zoom}
                          className="cursor-nesw-resize"
                          onMouseDown={(e) => handleMasterHandleMouseDown(e, 'ne')}
                        />
                        {/* E (Melebarkan Seluruh Kolom ke Kanan) */}
                        <rect
                          x={gridX + gridWidth - masterHandleSize / 2}
                          y={gridY + gridHeight / 2 - masterHandleSize / 2}
                          width={masterHandleSize}
                          height={masterHandleSize}
                          fill="#00C896"
                          stroke="#FFFFFF"
                          strokeWidth={1.5 / zoom}
                          className="cursor-ew-resize"
                          onMouseDown={(e) => handleMasterHandleMouseDown(e, 'e')}
                        />
                        {/* SE (Melebarkan Seluruh Grid secara Proporsional) */}
                        <rect
                          x={gridX + gridWidth - masterHandleSize / 2}
                          y={gridY + gridHeight - masterHandleSize / 2}
                          width={masterHandleSize}
                          height={masterHandleSize}
                          fill="#00C896"
                          stroke="#FFFFFF"
                          strokeWidth={1.5 / zoom}
                          className="cursor-nwse-resize"
                          onMouseDown={(e) => handleMasterHandleMouseDown(e, 'se')}
                        />
                        {/* S (Meninggikan Seluruh Baris ke Bawah) */}
                        <rect
                          x={gridX + gridWidth / 2 - masterHandleSize / 2}
                          y={gridY + gridHeight - masterHandleSize / 2}
                          width={masterHandleSize}
                          height={masterHandleSize}
                          fill="#00C896"
                          stroke="#FFFFFF"
                          strokeWidth={1.5 / zoom}
                          className="cursor-ns-resize"
                          onMouseDown={(e) => handleMasterHandleMouseDown(e, 's')}
                        />
                        {/* SW */}
                        <rect
                          x={gridX - masterHandleSize / 2}
                          y={gridY + gridHeight - masterHandleSize / 2}
                          width={masterHandleSize}
                          height={masterHandleSize}
                          fill="#00C896"
                          stroke="#FFFFFF"
                          strokeWidth={1.5 / zoom}
                          className="cursor-nesw-resize"
                          onMouseDown={(e) => handleMasterHandleMouseDown(e, 'sw')}
                        />
                        {/* W */}
                        <rect
                          x={gridX - masterHandleSize / 2}
                          y={gridY + gridHeight / 2 - masterHandleSize / 2}
                          width={masterHandleSize}
                          height={masterHandleSize}
                          fill="#00C896"
                          stroke="#FFFFFF"
                          strokeWidth={1.5 / zoom}
                          className="cursor-ew-resize"
                          onMouseDown={(e) => handleMasterHandleMouseDown(e, 'w')}
                        />
                      </g>
                    )}
                  </svg>
                </div>
              ) : (
                <div className="text-center text-neutral-400 space-y-1">
                  <Grid className="w-10 h-10 mx-auto text-neutral-300" />
                  <p className="text-xs font-semibold text-neutral-700">Belum ada gambar sprite sheet yang diunggah</p>
                  <p className="text-[11px] text-neutral-400">Pilih file pada panel kiri untuk memulai studio pemotongan</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Bottom Slices Gallery & Batch Publisher */}
        {slices.length > 0 && (
          <div className="space-y-3.5 pt-3 border-t border-neutral-200">
            {/* Gallery Toolbar */}
            <div className="flex flex-wrap items-center justify-between gap-3 bg-neutral-50 p-3 rounded-xl border border-neutral-200">
              <div className="flex items-center gap-3">
                <span className="text-xs font-bold text-neutral-900">
                  Hasil Potongan: {slices.length} Stiker
                </span>
                <Badge variant="brand" size="sm">{selectedCount} Dipilih</Badge>
                <div className="flex items-center gap-1 text-[11px]">
                  <button
                    type="button"
                    onClick={() => selectAll(true)}
                    className="text-brand-700 hover:underline font-semibold"
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
                  className={`p-2 rounded-xl border transition-all cursor-pointer relative flex flex-col items-center justify-between ${
                    slice.selected
                      ? 'bg-white border-brand-500 ring-2 ring-brand-200 shadow-xs'
                      : 'bg-neutral-50/50 border-neutral-200 opacity-50 hover:opacity-80'
                  }`}
                >
                  {/* Selection Checkbox */}
                  <div className="absolute top-1.5 left-1.5 z-10">
                    <input
                      type="checkbox"
                      checked={slice.selected}
                      onChange={() => toggleSelect(idx)}
                      onClick={(e) => e.stopPropagation()}
                      className="rounded text-brand-600 focus:ring-brand-500 w-3.5 h-3.5"
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
              <div className="space-y-1.5 p-3.5 bg-brand-50 rounded-xl border border-brand-200">
                <div className="flex justify-between text-xs font-semibold text-brand-900">
                  <span>Menerbitkan stiker ke paket "{packName}"...</span>
                  <span>{uploadProgress.current} / {uploadProgress.total}</span>
                </div>
                <div className="w-full bg-brand-200 rounded-full h-2 overflow-hidden">
                  <div
                    className="bg-brand-500 h-2 rounded-full transition-all duration-300"
                    style={{ width: `${(uploadProgress.current / uploadProgress.total) * 100}%` }}
                  />
                </div>
              </div>
            )}
          </div>
        )}

        {/* Modal Footer */}
        <div className="flex items-center justify-between pt-3 border-t border-neutral-100">
          <Button type="button" variant="outline" onClick={onClose} disabled={isUploading}>
            Tutup
          </Button>

          <Button
            type="button"
            variant="primary"
            className="bg-brand-500 hover:bg-brand-600 text-white font-bold"
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
