import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import {
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
  Maximize,
  Minimize2,
  Columns,
  Rows,
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

type ActiveTool = 'select' | 'draw' | 'pan' | 'eyedropper';
type ResizeHandle = 'nw' | 'n' | 'ne' | 'e' | 'se' | 's' | 'sw' | 'w';
type EditorMode = 'UNIFIED_GRID' | 'FREE_BOXES';

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

  // Slicing Mode: Unified Grid (Master drag all) vs Free Boxes (Independent per frame)
  const [editorMode, setEditorMode] = useState<EditorMode>('UNIFIED_GRID');

  // Unified Master Grid State (Tarik Seluruh Grid Sekaligus)
  const [gridX, setGridX] = useState(0);
  const [gridY, setGridY] = useState(0);
  const [gridWidth, setGridWidth] = useState(100);
  const [gridHeight, setGridHeight] = useState(100);
  const [cols, setCols] = useState(4);
  const [rows, setRows] = useState(3);
  const [spacingX, setSpacingX] = useState(0);
  const [spacingY, setSpacingY] = useState(0);

  // Free Crop Boxes State (Mode Kotak Bebas)
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

  // Auto-Trim & Target Processing
  const [autoTrim, setAutoTrim] = useState(true);
  const [targetSize] = useState(512);
  const [namePrefix, setNamePrefix] = useState('Stiker');

  // Slices Gallery State
  const [slices, setSlices] = useState<SlicedStickerItem[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState({ current: 0, total: 0 });
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Canvas & Interaction Drag Tracking
  const imageCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const viewportContainerRef = useRef<HTMLDivElement | null>(null);
  const svgOverlayRef = useRef<SVGSVGElement | null>(null);

  const dragActionRef = useRef<{
    type: 'pan' | 'master_move' | 'master_resize' | 'box_move' | 'box_resize' | 'draw';
    handle?: ResizeHandle;
    boxId?: string;
    startX: number;
    startY: number;
    initialGrid?: { x: number; y: number; width: number; height: number };
    initialBox?: CropBox;
    initialPan?: { x: number; y: number };
  } | null>(null);

  // Reset when modal opens
  useEffect(() => {
    if (isOpen) {
      setSheetFile(null);
      setSheetImage(null);
      setSheetDimensions({ width: 0, height: 0 });
      setBoxes([]);
      setSelectedBoxId(null);
      setSlices([]);
      setErrorMessage(null);
      setIsUploading(false);
      setZoom(1);
      setPan({ x: 0, y: 0 });
      setActiveTool('select');
      setEditorMode('UNIFIED_GRID');
      setNamePrefix(packName.replace(/\s+/g, '_'));
      setSpacingX(0);
      setSpacingY(0);
    }
  }, [isOpen, packName]);

  // Spacebar pan and Delete listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.code === 'Space' && !e.repeat && document.activeElement?.tagName !== 'INPUT') {
        setIsSpacePressed(true);
      }
      if ((e.key === 'Delete' || e.key === 'Backspace') && selectedBoxId && editorMode === 'FREE_BOXES' && document.activeElement?.tagName !== 'INPUT') {
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
  }, [selectedBoxId, editorMode]);

  // Calculate Cells from Master Unified Grid
  const unifiedCells = useMemo(() => {
    if (gridWidth <= 0 || gridHeight <= 0 || cols <= 0 || rows <= 0) return [];
    const cellW = Math.max(8, (gridWidth - (cols - 1) * spacingX) / cols);
    const cellH = Math.max(8, (gridHeight - (rows - 1) * spacingY) / rows);

    const cells: CropBox[] = [];
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        cells.push({
          id: `cell_${r}_${c}`,
          x: Math.round(gridX + c * (cellW + spacingX)),
          y: Math.round(gridY + r * (cellH + spacingY)),
          width: Math.round(cellW),
          height: Math.round(cellH),
        });
      }
    }
    return cells;
  }, [gridX, gridY, gridWidth, gridHeight, cols, rows, spacingX, spacingY]);

  // Active Effective Boxes to display / slice
  const activeEffectiveBoxes: CropBox[] = useMemo(() => {
    return editorMode === 'UNIFIED_GRID' ? unifiedCells : boxes;
  }, [editorMode, unifiedCells, boxes]);

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
      const w = img.naturalWidth;
      const h = img.naturalHeight;
      setSheetDimensions({ width: w, height: h });

      // Init Master Unified Grid to cover 96% of the sheet neatly
      const initialMarginX = Math.round(w * 0.02);
      const initialMarginY = Math.round(h * 0.02);
      setGridX(initialMarginX);
      setGridY(initialMarginY);
      setGridWidth(w - initialMarginX * 2);
      setGridHeight(h - initialMarginY * 2);

      // Guess reasonable cols/rows (e.g. 4 cols x 3 rows for typical stickers)
      if (w > h) {
        setCols(4);
        setRows(3);
      } else {
        setCols(4);
        setRows(4);
      }
      setEditorMode('UNIFIED_GRID');

      // Draw image onto backing canvas
      if (imageCanvasRef.current) {
        imageCanvasRef.current.width = w;
        imageCanvasRef.current.height = h;
        const ctx = imageCanvasRef.current.getContext('2d');
        if (ctx) {
          ctx.clearRect(0, 0, w, h);
          ctx.drawImage(img, 0, 0);
        }
      }

      // Initial fit zoom
      if (viewportContainerRef.current) {
        const vpW = viewportContainerRef.current.clientWidth - 40;
        const vpH = viewportContainerRef.current.clientHeight - 40;
        const scale = Math.min(1, Math.min(vpW / w, vpH / h));
        setZoom(Math.max(0.2, Math.round(scale * 100) / 100));
        setPan({ x: 0, y: 0 });
      }
    };
  };

  // Convert Client Mouse Coordinates to SVG Pixel Coordinates
  const getSvgCoordinates = useCallback((e: React.MouseEvent | MouseEvent): { x: number; y: number } => {
    const svg = svgOverlayRef.current;
    if (!svg) return { x: 0, y: 0 };
    const pt = svg.createSVGPoint();
    pt.x = e.clientX;
    pt.y = e.clientY;
    const ctm = svg.getScreenCTM();
    if (!ctm) return { x: 0, y: 0 };
    const svgP = pt.matrixTransform(ctm.inverse());
    return {
      x: Math.round(Math.max(0, Math.min(sheetDimensions.width, svgP.x))),
      y: Math.round(Math.max(0, Math.min(sheetDimensions.height, svgP.y))),
    };
  }, [sheetDimensions]);

  // Eyedropper Color Picker
  const handlePickColor = (coords: { x: number; y: number }) => {
    if (!imageCanvasRef.current) return;
    const ctx = imageCanvasRef.current.getContext('2d');
    if (!ctx) return;
    const pixel = ctx.getImageData(coords.x, coords.y, 1, 1).data;
    const hex = `#${((1 << 24) + (pixel[0] << 16) + (pixel[1] << 8) + pixel[2]).toString(16).slice(1).toUpperCase()}`;
    setBgColorHex(hex);
    setRemoveBgColor(true);
    setActiveTool('select');
  };

  // Switch to Free Boxes (Bongkar Grid Jadi Kotak Bebas)
  const handleUnlockToFreeBoxes = () => {
    setBoxes([...unifiedCells]);
    setSelectedBoxId(unifiedCells[0]?.id || null);
    setEditorMode('FREE_BOXES');
  };

  // Switch back to Unified Grid
  const handleResetToUnifiedGrid = () => {
    setEditorMode('UNIFIED_GRID');
    setSelectedBoxId(null);
  };

  // Smart Auto-Detect Frames with Iterative Proximity Merging (Fixes Overlapping & Fragmented Boxes)
  const handleAutoDetectFrames = () => {
    if (!sheetImage || !imageCanvasRef.current) {
      setErrorMessage('Unggah file sprite sheet terlebih dahulu');
      return;
    }

    setIsProcessing(true);
    setErrorMessage(null);

    requestAnimationFrame(() => {
      try {
        const canvas = imageCanvasRef.current!;
        const ctx = canvas.getContext('2d', { willReadFrequently: true });
        if (!ctx) return;

        const w = sheetDimensions.width;
        const h = sheetDimensions.height;
        const imgData = ctx.getImageData(0, 0, w, h);
        const data = imgData.data;

        // Parse Target Color for Chroma Key if active
        let tr = 255, tg = 255, tb = 255;
        if (removeBgColor) {
          const hex = bgColorHex.replace('#', '');
          tr = parseInt(hex.substring(0, 2), 16) || 255;
          tg = parseInt(hex.substring(2, 4), 16) || 255;
          tb = parseInt(hex.substring(4, 6), 16) || 255;
        }
        const maxDist = (bgTolerance / 100) * 441.67;

        // Fine step (4px) to ensure no characters (including 4th column) are skipped
        const step = Math.max(2, Math.min(4, Math.floor(Math.max(w, h) / 500)));
        const gridW = Math.ceil(w / step);
        const gridH = Math.ceil(h / step);
        const mask = new Uint8Array(gridW * gridH);

        for (let gy = 0; gy < gridH; gy++) {
          for (let gx = 0; gx < gridW; gx++) {
            const px = Math.min(w - 1, gx * step);
            const py = Math.min(h - 1, gy * step);
            const idx = (py * w + px) * 4;
            const r = data[idx];
            const g = data[idx + 1];
            const b = data[idx + 2];
            const a = data[idx + 3];

            let isContent = a > 20;
            if (isContent && removeBgColor) {
              const dist = Math.sqrt((r - tr) ** 2 + (g - tg) ** 2 + (b - tb) ** 2);
              if (dist <= maxDist) isContent = false;
            }
            if (isContent) {
              mask[gy * gridW + gx] = 1;
            }
          }
        }

        // BFS Connected Component Labeling
        const visited = new Uint8Array(gridW * gridH);
        const rawBoxes: CropBox[] = [];

        for (let gy = 0; gy < gridH; gy++) {
          for (let gx = 0; gx < gridW; gx++) {
            const mIdx = gy * gridW + gx;
            if (mask[mIdx] === 1 && visited[mIdx] === 0) {
              let minGX = gx, maxGX = gx, minGY = gy, maxGY = gy;
              const queue: number[] = [mIdx];
              visited[mIdx] = 1;

              while (queue.length > 0) {
                const curr = queue.shift()!;
                const cy = Math.floor(curr / gridW);
                const cx = curr % gridW;

                if (cx < minGX) minGX = cx;
                if (cx > maxGX) maxGX = cx;
                if (cy < minGY) minGY = cy;
                if (cy > maxGY) maxGY = cy;

                const neighbors = [
                  { nx: cx + 1, ny: cy },
                  { nx: cx - 1, ny: cy },
                  { nx: cx, ny: cy + 1 },
                  { nx: cx, ny: cy - 1 },
                ];

                for (const { nx, ny } of neighbors) {
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

              // Filter out tiny single-pixel noise (less than 12x12)
              if (boxW >= 12 && boxH >= 12) {
                rawBoxes.push({
                  id: Math.random().toString(36).substring(2, 9),
                  x: minGX * step,
                  y: minGY * step,
                  width: boxW,
                  height: boxH,
                });
              }
            }
          }
        }

        // ITERATIVE PROXIMITY MERGING (Eliminates stacked boxes on single character like #5, #7, #10)
        const gapTolerance = 28; // merge boxes within 28px of each other
        let mergedList = [...rawBoxes];
        let didMerge = true;

        while (didMerge) {
          didMerge = false;
          for (let i = 0; i < mergedList.length; i++) {
            for (let j = i + 1; j < mergedList.length; j++) {
              const a = mergedList[i];
              const b = mergedList[j];

              // Check if boxes overlap or are within gap in both X and Y
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
                };
                mergedList.splice(j, 1);
                didMerge = true;
                break;
              }
            }
            if (didMerge) break;
          }
        }

        // Add 6px padding and clamp to image bounds
        const finalDetected = mergedList.map((box) => {
          const pad = 6;
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
        });

        // Filter out components that are still too small (e.g. stray dots)
        const filtered = finalDetected.filter((b) => b.width >= 24 && b.height >= 24);

        if (filtered.length === 0) {
          setErrorMessage('Tidak ditemukan karakter stiker. Coba gunakan fitur Grid Terpadu.');
        } else {
          // Sort spatially left-to-right, top-to-bottom
          filtered.sort((a, b) => {
            const diffY = a.y - b.y;
            if (Math.abs(diffY) > 32) return diffY;
            return a.x - b.x;
          });
          setBoxes(filtered);
          setSelectedBoxId(filtered[0]?.id || null);
          setEditorMode('FREE_BOXES'); // switch to free boxes so user sees clean detected outlines
        }
      } catch (err: any) {
        setErrorMessage('Gagal mendeteksi kontur: ' + err.message);
      } finally {
        setIsProcessing(false);
      }
    });
  };

  // Mouse Down on Canvas Viewport
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

    if (e.button !== 0) return; // Left click only

    const coords = getSvgCoordinates(e);

    // Eyedropper tool
    if (activeTool === 'eyedropper') {
      handlePickColor(coords);
      return;
    }

    // Draw tool in Free Boxes mode
    if (activeTool === 'draw' && editorMode === 'FREE_BOXES') {
      const newBox: CropBox = {
        id: Math.random().toString(36).substring(2, 9),
        x: coords.x,
        y: coords.y,
        width: 12,
        height: 12,
      };
      setBoxes((prev) => [...prev, newBox]);
      setSelectedBoxId(newBox.id);
      setIsDragging(true);

      dragActionRef.current = {
        type: 'draw',
        boxId: newBox.id,
        startX: coords.x,
        startY: coords.y,
        initialBox: { ...newBox },
      };
      return;
    }

    // Click on empty space in Free Boxes mode: deselect
    if (editorMode === 'FREE_BOXES') {
      setSelectedBoxId(null);
    }
  };

  // Start Master Unified Grid Move Drag (Tarik Seluruh Grid Sekaligus)
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
    };
  };

  // Start Master Unified Grid Resize Drag (Tarik Ujung Grid Melebarkan Semua Kolom/Baris)
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
    };
  };

  // Start Free Box Move Drag
  const handleBoxMouseDown = (e: React.MouseEvent, box: CropBox) => {
    if (isSpacePressed || activeTool === 'pan' || activeTool === 'draw' || activeTool === 'eyedropper') return;
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

  // Start Free Box Handle Resize Drag
  const handleHandleMouseDown = (e: React.MouseEvent, box: CropBox, handle: ResizeHandle) => {
    if (isSpacePressed || activeTool === 'pan' || activeTool === 'draw' || activeTool === 'eyedropper') return;
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

    // 1. MASTER GRID MOVE: Drag entire matrix
    if (action.type === 'master_move') {
      const init = action.initialGrid!;
      const dx = coords.x - action.startX;
      const dy = coords.y - action.startY;

      const newX = Math.max(0, Math.min(sheetDimensions.width - init.width, init.x + dx));
      const newY = Math.max(0, Math.min(sheetDimensions.height - init.height, init.y + dy));

      setGridX(Math.round(newX));
      setGridY(Math.round(newY));
      return;
    }

    // 2. MASTER GRID RESIZE: Pull handle to resize all columns/rows simultaneously!
    if (action.type === 'master_resize') {
      const init = action.initialGrid!;
      const handle = action.handle!;
      const dx = coords.x - action.startX;
      const dy = coords.y - action.startY;

      let newX = init.x;
      let newY = init.y;
      let newW = init.width;
      let newH = init.height;

      if (handle.includes('w')) {
        const clampedW = Math.max(cols * 16, init.width - dx);
        newX = init.x + (init.width - clampedW);
        newW = clampedW;
      }
      if (handle.includes('e')) {
        newW = Math.max(cols * 16, Math.min(sheetDimensions.width - init.x, init.width + dx));
      }
      if (handle.includes('n')) {
        const clampedH = Math.max(rows * 16, init.height - dy);
        newY = init.y + (init.height - clampedH);
        newH = clampedH;
      }
      if (handle.includes('s')) {
        newH = Math.max(rows * 16, Math.min(sheetDimensions.height - init.y, init.height + dy));
      }

      setGridX(Math.round(Math.max(0, newX)));
      setGridY(Math.round(Math.max(0, newY)));
      setGridWidth(Math.round(Math.min(sheetDimensions.width - newX, newW)));
      setGridHeight(Math.round(Math.min(sheetDimensions.height - newY, newH)));
      return;
    }

    // 3. FREE BOX MOVE
    if (action.type === 'box_move') {
      const boxId = action.boxId!;
      const init = action.initialBox!;
      const dx = coords.x - action.startX;
      const dy = coords.y - action.startY;

      const newX = Math.max(0, Math.min(sheetDimensions.width - init.width, init.x + dx));
      const newY = Math.max(0, Math.min(sheetDimensions.height - init.height, init.y + dy));

      setBoxes((prev) =>
        prev.map((b) => (b.id === boxId ? { ...b, x: Math.round(newX), y: Math.round(newY) } : b))
      );
      return;
    }

    // 4. FREE BOX RESIZE
    if (action.type === 'box_resize') {
      const boxId = action.boxId!;
      const init = action.initialBox!;
      const handle = action.handle!;
      const dx = coords.x - action.startX;
      const dy = coords.y - action.startY;

      let newX = init.x;
      let newY = init.y;
      let newW = init.width;
      let newH = init.height;

      if (handle.includes('w')) {
        const clampedW = Math.max(12, init.width - dx);
        newX = init.x + (init.width - clampedW);
        newW = clampedW;
      }
      if (handle.includes('e')) {
        newW = Math.max(12, Math.min(sheetDimensions.width - init.x, init.width + dx));
      }
      if (handle.includes('n')) {
        const clampedH = Math.max(12, init.height - dy);
        newY = init.y + (init.height - clampedH);
        newH = clampedH;
      }
      if (handle.includes('s')) {
        newH = Math.max(12, Math.min(sheetDimensions.height - init.y, init.height + dy));
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
                x: Math.round(Math.max(0, newX)),
                y: Math.round(Math.max(0, newY)),
                width: Math.round(Math.min(sheetDimensions.width - newX, newW)),
                height: Math.round(Math.min(sheetDimensions.height - newY, newH)),
              }
            : b
        )
      );
      return;
    }

    // 5. DRAW NEW BOX
    if (action.type === 'draw') {
      const boxId = action.boxId!;
      const init = action.initialBox!;
      let x = Math.min(init.x, coords.x);
      let y = Math.min(init.y, coords.y);
      let w = Math.abs(coords.x - init.x);
      let h = Math.abs(coords.y - init.y);

      if (lockAspectRatio) {
        const max = Math.max(w, h);
        w = max;
        h = max;
      }

      setBoxes((prev) =>
        prev.map((b) =>
          b.id === boxId
            ? {
                ...b,
                x: Math.round(Math.max(0, x)),
                y: Math.round(Math.max(0, y)),
                width: Math.round(Math.min(sheetDimensions.width - x, Math.max(12, w))),
                height: Math.round(Math.min(sheetDimensions.height - y, Math.max(12, h))),
              }
            : b
        )
      );
    }
  }, [getSvgCoordinates, sheetDimensions, cols, rows, lockAspectRatio]);

  const handleMouseUp = useCallback(() => {
    setIsDragging(false);
    if (dragActionRef.current?.type === 'draw') {
      setActiveTool('select');
    }
    dragActionRef.current = null;
  }, []);

  useEffect(() => {
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);
    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [handleMouseMove, handleMouseUp]);

  // Selected Box Reference in Free Mode
  const selectedBox = useMemo(() => {
    return boxes.find((b) => b.id === selectedBoxId) || null;
  }, [boxes, selectedBoxId]);

  // Update Selected Box Values via Inspector
  const updateSelectedBox = (fields: Partial<CropBox>) => {
    if (!selectedBoxId) return;
    setBoxes((prev) =>
      prev.map((b) => {
        if (b.id !== selectedBoxId) return b;
        let newX = fields.x !== undefined ? fields.x : b.x;
        let newY = fields.y !== undefined ? fields.y : b.y;
        let newW = fields.width !== undefined ? fields.width : b.width;
        let newH = fields.height !== undefined ? fields.height : b.height;

        if (lockAspectRatio && fields.width !== undefined) {
          newH = fields.width;
        } else if (lockAspectRatio && fields.height !== undefined) {
          newW = fields.height;
        }

        newX = Math.max(0, Math.min(sheetDimensions.width - 8, newX));
        newY = Math.max(0, Math.min(sheetDimensions.height - 8, newY));
        newW = Math.max(8, Math.min(sheetDimensions.width - newX, newW));
        newH = Math.max(8, Math.min(sheetDimensions.height - newY, newH));

        return { ...b, x: Math.round(newX), y: Math.round(newY), width: Math.round(newW), height: Math.round(newH) };
      })
    );
  };

  // Nudge Selected Box
  const nudgeSelectedBox = (dx: number, dy: number) => {
    if (!selectedBox) return;
    updateSelectedBox({
      x: selectedBox.x + dx,
      y: selectedBox.y + dy,
    });
  };

  // Duplicate Selected Box
  const duplicateSelectedBox = () => {
    if (!selectedBox) return;
    const newBox: CropBox = {
      id: Math.random().toString(36).substring(2, 9),
      x: Math.min(sheetDimensions.width - selectedBox.width, selectedBox.x + 16),
      y: Math.min(sheetDimensions.height - selectedBox.height, selectedBox.y + 16),
      width: selectedBox.width,
      height: selectedBox.height,
    };
    setBoxes((prev) => [...prev, newBox]);
    setSelectedBoxId(newBox.id);
  };

  // Delete Selected Box
  const deleteSelectedBox = () => {
    if (!selectedBoxId) return;
    setBoxes((prev) => prev.filter((b) => b.id !== selectedBoxId));
    setSelectedBoxId(null);
  };

  // Execute Extraction & Slicing into 512x512
  const handleExtractSlices = () => {
    if (!sheetImage || activeEffectiveBoxes.length === 0) {
      setErrorMessage('Belum ada kotak potongan stiker yang dikonfigurasi');
      return;
    }

    setIsProcessing(true);
    setErrorMessage(null);

    setTimeout(() => {
      try {
        let tr = 255, tg = 255, tb = 255;
        if (removeBgColor) {
          const hex = bgColorHex.replace('#', '');
          tr = parseInt(hex.substring(0, 2), 16) || 255;
          tg = parseInt(hex.substring(2, 4), 16) || 255;
          tb = parseInt(hex.substring(4, 6), 16) || 255;
        }
        const maxDist = (bgTolerance / 100) * 441.67;

        // Sort boxes spatially left-to-right, top-to-bottom
        const sortedBoxes = [...activeEffectiveBoxes].sort((a, b) => {
          const diffY = a.y - b.y;
          if (Math.abs(diffY) > 30) return diffY;
          return a.x - b.x;
        });

        const newSlices: SlicedStickerItem[] = [];

        sortedBoxes.forEach((box, idx) => {
          const rawCanvas = document.createElement('canvas');
          rawCanvas.width = box.width;
          rawCanvas.height = box.height;
          const rawCtx = rawCanvas.getContext('2d', { willReadFrequently: true });
          if (!rawCtx) return;

          rawCtx.drawImage(sheetImage, box.x, box.y, box.width, box.height, 0, 0, box.width, box.height);

          const imgData = rawCtx.getImageData(0, 0, box.width, box.height);
          const data = imgData.data;
          let hasContent = false;
          let minX = box.width, minY = box.height, maxX = 0, maxY = 0;

          for (let py = 0; py < box.height; py++) {
            for (let px = 0; px < box.width; px++) {
              const i = (py * box.width + px) * 4;
              let a = data[i + 3];

              if (a > 15 && removeBgColor) {
                const dist = Math.sqrt((data[i] - tr) ** 2 + (data[i + 1] - tg) ** 2 + (data[i + 2] - tb) ** 2);
                if (dist <= maxDist) {
                  data[i + 3] = 0;
                  a = 0;
                } else if (dist < maxDist + 20) {
                  const feather = (dist - maxDist) / 20;
                  data[i + 3] = Math.round(data[i + 3] * feather);
                  a = data[i + 3];
                }
              }

              if (a > 15) {
                hasContent = true;
                if (px < minX) minX = px;
                if (px > maxX) maxX = px;
                if (py < minY) minY = py;
                if (py > maxY) maxY = py;
              }
            }
          }

          if (removeBgColor) {
            rawCtx.putImageData(imgData, 0, 0);
          }

          // Normalize into standard 512x512 Sticker Canvas
          const targetCanvas = document.createElement('canvas');
          targetCanvas.width = targetSize;
          targetCanvas.height = targetSize;
          const targetCtx = targetCanvas.getContext('2d');
          if (!targetCtx) return;

          targetCtx.imageSmoothingEnabled = true;
          targetCtx.imageSmoothingQuality = 'high';

          if (hasContent && autoTrim && maxX >= minX && maxY >= minY) {
            const trimmedW = maxX - minX + 1;
            const trimmedH = maxY - minY + 1;
            const scale = Math.min((targetSize * 0.88) / trimmedW, (targetSize * 0.88) / trimmedH);
            const drawW = trimmedW * scale;
            const drawH = trimmedH * scale;
            const drawX = (targetSize - drawW) / 2;
            const drawY = (targetSize - drawH) / 2;

            targetCtx.drawImage(rawCanvas, minX, minY, trimmedW, trimmedH, drawX, drawY, drawW, drawH);
          } else {
            const scale = Math.min(targetSize / box.width, targetSize / box.height);
            const drawW = box.width * scale;
            const drawH = box.height * scale;
            const drawX = (targetSize - drawW) / 2;
            const drawY = (targetSize - drawH) / 2;
            targetCtx.drawImage(rawCanvas, 0, 0, box.width, box.height, drawX, drawY, drawW, drawH);
          }

          const indexNumber = idx + 1;
          newSlices.push({
            id: box.id,
            canvas: targetCanvas,
            previewUrl: targetCanvas.toDataURL('image/png'),
            name: `${namePrefix} ${indexNumber}`,
            emoji: '',
            selected: hasContent,
            isEmpty: !hasContent,
          });
        });

        setSlices(newSlices);
      } catch (err: any) {
        setErrorMessage('Gagal mengekstrak stiker: ' + err.message);
      } finally {
        setIsProcessing(false);
      }
    }, 50);
  };

  // Toggle selection
  const toggleSelect = (index: number) => {
    setSlices((prev) => {
      const copy = [...prev];
      copy[index] = { ...copy[index], selected: !copy[index].selected };
      return copy;
    });
  };

  const selectAll = (select: boolean) => {
    setSlices((prev) => prev.map((s) => ({ ...s, selected: select && !s.isEmpty })));
  };

  const updateSlice = (index: number, field: 'name' | 'emoji', value: string) => {
    setSlices((prev) => {
      const copy = [...prev];
      copy[index] = { ...copy[index], [field]: value };
      return copy;
    });
  };

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
  const masterHandleSize = Math.max(9, Math.min(16, 10 / zoom));

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Studio Ekstraktor Sprite Sheet Stiker (Master Grid Studio)"
      description={`Tarik seluruh grid secara serentak atau sesuaikan stiker individu pada paket "${packName}"`}
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
                      {sheetDimensions.width} x {sheetDimensions.height} px • {activeEffectiveBoxes.length} stiker siap potong
                    </p>
                  </div>
                ) : (
                  <div className="space-y-1 text-neutral-500 py-1">
                    <Scissors className="w-5 h-5 mx-auto text-neutral-400" />
                    <p className="text-xs font-semibold text-neutral-800">Pilih File Sprite Sheet</p>
                    <p className="text-[10px] text-neutral-400">PNG transparan atau latar warna (WEBP/JPG)</p>
                  </div>
                )}
              </div>
            </div>

            {/* Mode Switcher: UNIFIED_GRID vs FREE_BOXES */}
            <div className="bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs space-y-2.5">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider block">
                  Mode Pemotongan
                </span>
                <Badge variant={editorMode === 'UNIFIED_GRID' ? 'brand' : 'neutral'} size="sm">
                  {editorMode === 'UNIFIED_GRID' ? 'Grid Terpadu' : 'Kotak Bebas'}
                </Badge>
              </div>

              {/* Toggle Mode Buttons */}
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={handleResetToUnifiedGrid}
                  className={`py-1.5 px-2.5 rounded-lg text-xs font-bold flex items-center justify-center gap-1.5 border transition-all ${
                    editorMode === 'UNIFIED_GRID'
                      ? 'bg-brand-500 text-white border-brand-600 shadow-xs'
                      : 'bg-neutral-50 text-neutral-600 border-neutral-200 hover:bg-neutral-100'
                  }`}
                  title="Tarik seluruh grid secara serentak"
                >
                  <Grid className="w-3.5 h-3.5" />
                  <span>Grid Terpadu</span>
                </button>

                <button
                  type="button"
                  onClick={handleUnlockToFreeBoxes}
                  className={`py-1.5 px-2.5 rounded-lg text-xs font-bold flex items-center justify-center gap-1.5 border transition-all ${
                    editorMode === 'FREE_BOXES'
                      ? 'bg-brand-500 text-white border-brand-600 shadow-xs'
                      : 'bg-neutral-50 text-neutral-600 border-neutral-200 hover:bg-neutral-100'
                  }`}
                  title="Bongkar grid jadi kotak independen untuk edit stiker tertentu"
                >
                  <Layers className="w-3.5 h-3.5" />
                  <span>Kotak Bebas</span>
                </button>
              </div>

              {/* Mode Description Tip */}
              <p className="text-[10px] text-neutral-500 leading-relaxed">
                {editorMode === 'UNIFIED_GRID'
                  ? '💡 Tarik handle hijau master di kanvas: seluruh baris dan kolom membesar/mengecil bersamaan secara serentak.'
                  : '💡 Setiap kotak stiker independen. Anda bisa menarik atau memperlebar stiker tertentu (seperti burung tidur).'}
              </p>
            </div>

            {/* UNIFIED GRID CONTROLLER (Tarik Seluruh Grid Sekaligus) */}
            {editorMode === 'UNIFIED_GRID' ? (
              <div className="space-y-3 bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs">
                <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider block">
                  Pengaturan Matriks Grid
                </span>

                <div className="grid grid-cols-2 gap-2 text-xs">
                  <div className="space-y-1">
                    <span className="text-[10px] font-semibold text-neutral-500 flex items-center gap-1">
                      <Columns className="w-3 h-3 text-brand-600" /> Kolom
                    </span>
                    <div className="flex items-center gap-1">
                      <button
                        type="button"
                        onClick={() => setCols((c) => Math.max(1, c - 1))}
                        className="px-2 py-1 rounded bg-neutral-100 hover:bg-neutral-200 text-xs font-bold"
                      >
                        -
                      </button>
                      <input
                        type="number"
                        min="1"
                        max="24"
                        value={cols}
                        onChange={(e) => setCols(Math.max(1, parseInt(e.target.value) || 1))}
                        className="w-full text-center py-1 font-bold rounded border border-neutral-200 bg-neutral-50"
                      />
                      <button
                        type="button"
                        onClick={() => setCols((c) => Math.min(24, c + 1))}
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
                        onClick={() => setRows((r) => Math.max(1, r - 1))}
                        className="px-2 py-1 rounded bg-neutral-100 hover:bg-neutral-200 text-xs font-bold"
                      >
                        -
                      </button>
                      <input
                        type="number"
                        min="1"
                        max="24"
                        value={rows}
                        onChange={(e) => setRows(Math.max(1, parseInt(e.target.value) || 1))}
                        className="w-full text-center py-1 font-bold rounded border border-neutral-200 bg-neutral-50"
                      />
                      <button
                        type="button"
                        onClick={() => setRows((r) => Math.min(24, r + 1))}
                        className="px-2 py-1 rounded bg-neutral-100 hover:bg-neutral-200 text-xs font-bold"
                      >
                        +
                      </button>
                    </div>
                  </div>
                </div>

                {/* Spacing / Gutter Sliders (Zero-Overlap Gutter) */}
                <div className="grid grid-cols-2 gap-2 text-xs pt-1 border-t border-neutral-100">
                  <div className="space-y-0.5">
                    <div className="flex justify-between text-[10px] text-neutral-500">
                      <span>Jeda / Spasi X</span>
                      <span>{spacingX} px</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="48"
                      value={spacingX}
                      onChange={(e) => setSpacingX(parseInt(e.target.value) || 0)}
                      className="w-full accent-brand-500 h-1.5 bg-neutral-200 rounded-lg cursor-pointer"
                    />
                  </div>

                  <div className="space-y-0.5">
                    <div className="flex justify-between text-[10px] text-neutral-500">
                      <span>Jeda / Spasi Y</span>
                      <span>{spacingY} px</span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="48"
                      value={spacingY}
                      onChange={(e) => setSpacingY(parseInt(e.target.value) || 0)}
                      className="w-full accent-brand-500 h-1.5 bg-neutral-200 rounded-lg cursor-pointer"
                    />
                  </div>
                </div>

                {/* Quick Fit Fullsheet */}
                <button
                  type="button"
                  onClick={() => {
                    setGridX(0);
                    setGridY(0);
                    setGridWidth(sheetDimensions.width);
                    setGridHeight(sheetDimensions.height);
                  }}
                  className="w-full py-1 text-[11px] font-semibold text-neutral-600 bg-neutral-100 hover:bg-neutral-200 rounded-lg flex items-center justify-center gap-1 transition-colors"
                >
                  <Maximize2 className="w-3 h-3" />
                  <span>Ratakan Grid ke Batas Penuh Gambar</span>
                </button>
              </div>
            ) : (
              /* FREE BOXES CONTROLLER & INSPECTOR */
              <div className="space-y-2.5 bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs">
                <div className="flex items-center justify-between">
                  <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider flex items-center gap-1.5">
                    <Sliders className="w-3.5 h-3.5 text-brand-600" />
                    Inspector Kotak Terpilih
                  </span>
                  {selectedBox && (
                    <Badge variant="brand" size="sm">
                      #{boxes.findIndex((b) => b.id === selectedBox.id) + 1}
                    </Badge>
                  )}
                </div>

                {selectedBox ? (
                  <div className="space-y-2.5">
                    {/* Position & Size Inputs */}
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
                        title="Kunci rasio 1:1"
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
                          title="Duplikat Kotak"
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
                  <div className="text-center py-3 text-neutral-400 text-xs">
                    <MousePointer className="w-5 h-5 mx-auto mb-1 text-neutral-300" />
                    Klik salah satu kotak stiker di kanvas untuk menggeser atau mengubah ukurannya
                  </div>
                )}
              </div>
            )}

            {/* Smart Auto-Detect Button (With Proximity Merging) */}
            <div className="bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider">
                  Deteksi Kontur Cerdas
                </span>
                <span className="text-[10px] text-brand-600 font-semibold">Proximity Merge 28px</span>
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

            {/* Smart Processing Toggle */}
            <div className="bg-white p-3 rounded-xl border border-neutral-200 space-y-1">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={autoTrim}
                  onChange={(e) => setAutoTrim(e.target.checked)}
                  className="rounded text-brand-600 focus:ring-brand-500 w-4 h-4"
                />
                <span className="text-xs font-semibold text-neutral-800">Auto-Trim & Safe Margin 512x512</span>
              </label>
              <p className="text-[10px] text-neutral-400 pl-6">
                Memangkas area kosong transparan di sekitar stiker lalu memusatkannya proporsional ke kanvas standar 512x512 px.
              </p>
            </div>

            {/* Extract Slices Button */}
            <Button
              type="button"
              variant="primary"
              className="w-full py-2.5 bg-brand-500 hover:bg-brand-600 text-white font-bold shadow-sm"
              disabled={!sheetImage || activeEffectiveBoxes.length === 0 || isProcessing}
              isLoading={isProcessing}
              onClick={handleExtractSlices}
              icon={<Scissors className="w-4 h-4" />}
            >
              Ekstrak {activeEffectiveBoxes.length} Stiker
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
                {editorMode === 'FREE_BOXES' && (
                  <button
                    type="button"
                    onClick={() => setActiveTool('draw')}
                    className={`px-2.5 py-1 rounded-md font-semibold flex items-center gap-1.5 transition-all ${
                      activeTool === 'draw' ? 'bg-brand-500 text-white shadow-xs' : 'text-neutral-600 hover:bg-neutral-100'
                    }`}
                    title="Tambah Kotak Baru (Tarik kursor di kanvas)"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>+ Tambah Kotak</span>
                  </button>
                )}
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

              {/* Zoom Controls */}
              <div className="flex items-center gap-1.5">
                <button
                  type="button"
                  onClick={() => setZoom((z) => Math.max(0.2, Math.round((z - 0.15) * 100) / 100))}
                  className="p-1.5 rounded-lg bg-white border border-neutral-200 hover:bg-neutral-100 text-neutral-700"
                  title="Zoom Out"
                >
                  <ZoomOut className="w-3.5 h-3.5" />
                </button>
                <span className="font-mono text-xs font-bold px-1.5 text-neutral-700 min-w-[42px] text-center">
                  {Math.round(zoom * 100)}%
                </span>
                <button
                  type="button"
                  onClick={() => setZoom((z) => Math.min(3.5, Math.round((z + 0.15) * 100) / 100))}
                  className="p-1.5 rounded-lg bg-white border border-neutral-200 hover:bg-neutral-100 text-neutral-700"
                  title="Zoom In"
                >
                  <ZoomIn className="w-3.5 h-3.5" />
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setZoom(1);
                    setPan({ x: 0, y: 0 });
                  }}
                  className="p-1.5 rounded-lg bg-white border border-neutral-200 hover:bg-neutral-100 text-neutral-700"
                  title="Reset 100%"
                >
                  <RefreshCw className="w-3.5 h-3.5" />
                </button>
              </div>

              {/* Frame Count Badge */}
              <div className="flex items-center gap-2">
                <Badge variant="brand" size="sm">
                  {activeEffectiveBoxes.length} Kotak Stiker
                </Badge>
              </div>
            </div>

            {/* Interactive Viewport Container */}
            <div
              ref={viewportContainerRef}
              onMouseDown={handleMouseDown}
              className={`w-full h-[470px] rounded-2xl border border-neutral-200/90 overflow-hidden relative select-none flex items-center justify-center ${
                activeTool === 'pan' || isSpacePressed
                  ? 'cursor-grab active:cursor-grabbing'
                  : activeTool === 'draw'
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
              {sheetImage ? (
                <div
                  className="relative origin-center"
                  style={{
                    width: sheetDimensions.width,
                    height: sheetDimensions.height,
                    transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom})`,
                    transition: isDragging ? 'none' : 'transform 75ms ease-out',
                  }}
                >
                  {/* Base Image Canvas */}
                  <canvas
                    ref={imageCanvasRef}
                    className="absolute inset-0 pointer-events-none drop-shadow-md rounded"
                    style={{ width: sheetDimensions.width, height: sheetDimensions.height }}
                  />

                  {/* SVG Overlay: Zero-Overlap Unified Master Grid & Free Boxes */}
                  <svg
                    ref={svgOverlayRef}
                    className="absolute inset-0 w-full h-full pointer-events-auto"
                    width={sheetDimensions.width}
                    height={sheetDimensions.height}
                  >
                    {/* MODE 1: UNIFIED MASTER GRID (Tarik Seluruh Grid Sekaligus) */}
                    {editorMode === 'UNIFIED_GRID' && (
                      <g className="master-grid-group">
                        {/* 1. Shared Inner Cells (No overlapping duplicate borders) */}
                        {unifiedCells.map((cell, idx) => (
                          <g key={cell.id}>
                            <rect
                              x={cell.x}
                              y={cell.y}
                              width={cell.width}
                              height={cell.height}
                              fill="rgba(0, 200, 150, 0.06)"
                              stroke="rgba(0, 200, 150, 0.75)"
                              strokeWidth={Math.max(1, 1.5 / zoom)}
                              strokeDasharray={`${4 / zoom},${4 / zoom}`}
                              className="pointer-events-none"
                            />
                            {/* Cell Badge Number */}
                            <rect
                              x={cell.x + 2}
                              y={cell.y + 2}
                              width={Math.max(18, 20 / zoom)}
                              height={Math.max(12, 14 / zoom)}
                              fill="rgba(0, 200, 150, 0.9)"
                              rx={3 / zoom}
                              className="pointer-events-none"
                            />
                            <text
                              x={cell.x + Math.max(9, 10 / zoom)}
                              y={cell.y + Math.max(9, 11 / zoom)}
                              textAnchor="middle"
                              fill="#FFFFFF"
                              fontSize={Math.max(8, 9 / zoom)}
                              fontFamily="monospace"
                              fontWeight="bold"
                              className="pointer-events-none select-none"
                            >
                              {idx + 1}
                            </text>
                          </g>
                        ))}

                        {/* 2. Outer Master Boundary Box (Drag Body to Move Whole Matrix) */}
                        <rect
                          x={gridX}
                          y={gridY}
                          width={gridWidth}
                          height={gridHeight}
                          fill="transparent"
                          stroke="#00C896"
                          strokeWidth={Math.max(2, 2.5 / zoom)}
                          className="cursor-move"
                          onMouseDown={handleMasterGridMouseDown}
                        />

                        {/* 3. Outer Master 8 Resize Handles (Tarik Sudut/Tepi Melebarkan Semua Kolom & Baris) */}
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
                        {/* E (Melebarkan Semua Kolom dari Kiri ke Kanan) */}
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
                        {/* SE (Melebarkan Seluruh Matriks Serentak) */}
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
                        {/* S (Meninggikan Semua Baris dari Atas ke Bawah) */}
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

                    {/* MODE 2: FREE INDEPENDENT BOXES (Edit Khusus Kotak Stiker) */}
                    {editorMode === 'FREE_BOXES' && (
                      <g className="free-boxes-group">
                        {/* Layer 1: All Unselected Boxes */}
                        {boxes.map((box, idx) => {
                          if (box.id === selectedBoxId) return null;
                          return (
                            <g key={box.id} className="cursor-pointer" onClick={(e) => handleBoxMouseDown(e, box)}>
                              <rect
                                x={box.x}
                                y={box.y}
                                width={box.width}
                                height={box.height}
                                fill="rgba(6, 182, 212, 0.05)"
                                stroke="rgba(6, 182, 212, 0.75)"
                                strokeWidth={Math.max(1, 1.5 / zoom)}
                                strokeDasharray={`${4 / zoom},${4 / zoom}`}
                              />
                              <rect
                                x={box.x + 2}
                                y={box.y + 2}
                                width={Math.max(18, 20 / zoom)}
                                height={Math.max(12, 14 / zoom)}
                                fill="rgba(6, 182, 212, 0.85)"
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
                            </g>
                          );
                        })}

                        {/* Layer 2: Selected Box (Highlighted in Brand Green, Handles on Top) */}
                        {selectedBox && (
                          <g className="selected-box-layer">
                            <rect
                              x={selectedBox.x}
                              y={selectedBox.y}
                              width={selectedBox.width}
                              height={selectedBox.height}
                              fill="rgba(0, 200, 150, 0.15)"
                              stroke="#00C896"
                              strokeWidth={Math.max(2, 2.5 / zoom)}
                              className="cursor-move"
                              onMouseDown={(e) => handleBoxMouseDown(e, selectedBox)}
                            />

                            <rect
                              x={selectedBox.x + 2}
                              y={selectedBox.y + 2}
                              width={Math.max(22, 24 / zoom)}
                              height={Math.max(14, 16 / zoom)}
                              fill="#00C896"
                              rx={3 / zoom}
                              className="pointer-events-none"
                            />
                            <text
                              x={selectedBox.x + Math.max(11, 12 / zoom)}
                              y={selectedBox.y + Math.max(11, 13 / zoom)}
                              textAnchor="middle"
                              fill="#FFFFFF"
                              fontSize={Math.max(9, 10 / zoom)}
                              fontFamily="monospace"
                              fontWeight="bold"
                              className="pointer-events-none select-none"
                            >
                              {boxes.findIndex((b) => b.id === selectedBox.id) + 1}
                            </text>

                            {/* 8-Point Isolated Handles (No Overlap with Neighbors) */}
                            {/* NW */}
                            <rect
                              x={selectedBox.x - masterHandleSize / 2}
                              y={selectedBox.y - masterHandleSize / 2}
                              width={masterHandleSize}
                              height={masterHandleSize}
                              fill="#FFFFFF"
                              stroke="#00C896"
                              strokeWidth={2 / zoom}
                              className="cursor-nwse-resize"
                              onMouseDown={(e) => handleHandleMouseDown(e, selectedBox, 'nw')}
                            />
                            {/* N */}
                            <rect
                              x={selectedBox.x + selectedBox.width / 2 - masterHandleSize / 2}
                              y={selectedBox.y - masterHandleSize / 2}
                              width={masterHandleSize}
                              height={masterHandleSize}
                              fill="#FFFFFF"
                              stroke="#00C896"
                              strokeWidth={2 / zoom}
                              className="cursor-ns-resize"
                              onMouseDown={(e) => handleHandleMouseDown(e, selectedBox, 'n')}
                            />
                            {/* NE */}
                            <rect
                              x={selectedBox.x + selectedBox.width - masterHandleSize / 2}
                              y={selectedBox.y - masterHandleSize / 2}
                              width={masterHandleSize}
                              height={masterHandleSize}
                              fill="#FFFFFF"
                              stroke="#00C896"
                              strokeWidth={2 / zoom}
                              className="cursor-nesw-resize"
                              onMouseDown={(e) => handleHandleMouseDown(e, selectedBox, 'ne')}
                            />
                            {/* E */}
                            <rect
                              x={selectedBox.x + selectedBox.width - masterHandleSize / 2}
                              y={selectedBox.y + selectedBox.height / 2 - masterHandleSize / 2}
                              width={masterHandleSize}
                              height={masterHandleSize}
                              fill="#FFFFFF"
                              stroke="#00C896"
                              strokeWidth={2 / zoom}
                              className="cursor-ew-resize"
                              onMouseDown={(e) => handleHandleMouseDown(e, selectedBox, 'e')}
                            />
                            {/* SE */}
                            <rect
                              x={selectedBox.x + selectedBox.width - masterHandleSize / 2}
                              y={selectedBox.y + selectedBox.height - masterHandleSize / 2}
                              width={masterHandleSize}
                              height={masterHandleSize}
                              fill="#FFFFFF"
                              stroke="#00C896"
                              strokeWidth={2 / zoom}
                              className="cursor-nwse-resize"
                              onMouseDown={(e) => handleHandleMouseDown(e, selectedBox, 'se')}
                            />
                            {/* S */}
                            <rect
                              x={selectedBox.x + selectedBox.width / 2 - masterHandleSize / 2}
                              y={selectedBox.y + selectedBox.height - masterHandleSize / 2}
                              width={masterHandleSize}
                              height={masterHandleSize}
                              fill="#FFFFFF"
                              stroke="#00C896"
                              strokeWidth={2 / zoom}
                              className="cursor-ns-resize"
                              onMouseDown={(e) => handleHandleMouseDown(e, selectedBox, 's')}
                            />
                            {/* SW */}
                            <rect
                              x={selectedBox.x - masterHandleSize / 2}
                              y={selectedBox.y + selectedBox.height - masterHandleSize / 2}
                              width={masterHandleSize}
                              height={masterHandleSize}
                              fill="#FFFFFF"
                              stroke="#00C896"
                              strokeWidth={2 / zoom}
                              className="cursor-nesw-resize"
                              onMouseDown={(e) => handleHandleMouseDown(e, selectedBox, 'sw')}
                            />
                            {/* W */}
                            <rect
                              x={selectedBox.x - masterHandleSize / 2}
                              y={selectedBox.y + selectedBox.height / 2 - masterHandleSize / 2}
                              width={masterHandleSize}
                              height={masterHandleSize}
                              fill="#FFFFFF"
                              stroke="#00C896"
                              strokeWidth={2 / zoom}
                              className="cursor-ew-resize"
                              onMouseDown={(e) => handleHandleMouseDown(e, selectedBox, 'w')}
                            />
                          </g>
                        )}
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
