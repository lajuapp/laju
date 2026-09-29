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

  // Crop Boxes State (Interactive individual frames)
  const [boxes, setBoxes] = useState<CropBox[]>([]);
  const [selectedBoxId, setSelectedBoxId] = useState<string | null>(null);
  const [lockAspectRatio, setLockAspectRatio] = useState(false);

  // Active Tool & Viewport (Zoom & Pan)
  const [activeTool, setActiveTool] = useState<ActiveTool>('select');
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const [isSpacePressed, setIsSpacePressed] = useState(false);

  // Uniform Grid Generator Config
  const [cols, setCols] = useState(4);
  const [rows, setRows] = useState(4);
  const [marginX, setMarginX] = useState(0);
  const [marginY, setMarginY] = useState(0);
  const [spacingX, setSpacingX] = useState(0);
  const [spacingY, setSpacingY] = useState(0);

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
    type: 'move' | 'resize' | 'draw' | 'pan';
    boxId?: string;
    handle?: ResizeHandle;
    startX: number;
    startY: number;
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
      setNamePrefix(packName.replace(/\s+/g, '_'));
    }
  }, [isOpen, packName]);

  // Spacebar pan listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.code === 'Space' && !e.repeat && document.activeElement?.tagName !== 'INPUT') {
        setIsSpacePressed(true);
      }
      // Delete selected box with Delete / Backspace key
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

      // Draw onto backing canvas
      if (imageCanvasRef.current) {
        imageCanvasRef.current.width = img.naturalWidth;
        imageCanvasRef.current.height = img.naturalHeight;
        const ctx = imageCanvasRef.current.getContext('2d');
        if (ctx) {
          ctx.clearRect(0, 0, img.naturalWidth, img.naturalHeight);
          ctx.drawImage(img, 0, 0);
        }
      }

      // Initial fit zoom
      if (viewportContainerRef.current) {
        const vpW = viewportContainerRef.current.clientWidth - 40;
        const vpH = viewportContainerRef.current.clientHeight - 40;
        const scale = Math.min(1, Math.min(vpW / img.naturalWidth, vpH / img.naturalHeight));
        setZoom(Math.max(0.2, Math.round(scale * 100) / 100));
        setPan({ x: 0, y: 0 });
      }

      // Generate initial uniform grid by aspect ratio
      const w = img.naturalWidth;
      const h = img.naturalHeight;
      let initialCols = 4;
      let initialRows = 4;
      if (w > h) {
        const aspect = Math.round(w / h);
        initialCols = Math.min(12, Math.max(3, aspect * 3));
        initialRows = 3;
      }
      setCols(initialCols);
      setRows(initialRows);
      generateUniformGrid(initialCols, initialRows, img.naturalWidth, img.naturalHeight);
    };
  };

  // Redraw canvas image when sheetImage changes
  useEffect(() => {
    if (!sheetImage || !imageCanvasRef.current) return;
    const canvas = imageCanvasRef.current;
    canvas.width = sheetDimensions.width;
    canvas.height = sheetDimensions.height;
    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(sheetImage, 0, 0);
    }
  }, [sheetImage, sheetDimensions]);

  // Generate Uniform Grid Boxes
  const generateUniformGrid = (
    c = cols,
    r = rows,
    w = sheetDimensions.width,
    h = sheetDimensions.height,
    mx = marginX,
    my = marginY,
    sx = spacingX,
    sy = spacingY
  ) => {
    if (w <= 0 || h <= 0) return;
    const cellW = Math.max(8, Math.floor((w - mx * 2 - (c - 1) * sx) / c));
    const cellH = Math.max(8, Math.floor((h - my * 2 - (r - 1) * sy) / r));

    const newBoxes: CropBox[] = [];
    for (let rowIdx = 0; rowIdx < r; rowIdx++) {
      for (let colIdx = 0; colIdx < c; colIdx++) {
        newBoxes.push({
          id: Math.random().toString(36).substring(2, 9),
          x: mx + colIdx * (cellW + sx),
          y: my + rowIdx * (cellH + sy),
          width: cellW,
          height: cellH,
        });
      }
    }
    setBoxes(newBoxes);
    setSelectedBoxId(newBoxes[0]?.id || null);
  };

  // Smart Auto-Detect Frames (Connected Component Clustering on Alpha / Background)
  const handleAutoDetectFrames = () => {
    if (!sheetImage || !imageCanvasRef.current) {
      setErrorMessage('Unggah file sprite sheet terlebih dahulu');
      return;
    }

    setIsProcessing(true);
    setErrorMessage(null);

    // Run in requestAnimationFrame to let UI render loading spinner
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
        const maxDist = (bgTolerance / 100) * 441.67; // max Euclidean distance between RGB (sqrt(3 * 255^2))

        // Downsample grid for high-speed clustering (scale by 4)
        const step = Math.max(2, Math.min(6, Math.floor(Math.max(w, h) / 400)));
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

            let isContent = a > 25;
            if (isContent && removeBgColor) {
              const dist = Math.sqrt((r - tr) ** 2 + (g - tg) ** 2 + (b - tb) ** 2);
              if (dist <= maxDist) {
                isContent = false;
              }
            }
            if (isContent) {
              mask[gy * gridW + gx] = 1;
            }
          }
        }

        // BFS Connected Component Labeling
        const visited = new Uint8Array(gridW * gridH);
        const detectedBoxes: CropBox[] = [];

        for (let gy = 0; gy < gridH; gy++) {
          for (let gx = 0; gx < gridW; gx++) {
            const mIdx = gy * gridW + gx;
            if (mask[mIdx] === 1 && visited[mIdx] === 0) {
              // Start flood fill
              let minGX = gx, maxGX = gx, minGY = gy, maxGY = gy;
              const queue: number[] = [mIdx];
              visited[mIdx] = 1;

              while (queue.length > 0) {
                const curr = queue.pop()!;
                const cy = Math.floor(curr / gridW);
                const cx = curr % gridW;

                if (cx < minGX) minGX = cx;
                if (cx > maxGX) maxGX = cx;
                if (cy < minGY) minGY = cy;
                if (cy > maxGY) maxGY = cy;

                // Check 4-connected neighbors
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

              // Convert grid bounds back to pixel bounds
              const boxW = (maxGX - minGX + 1) * step;
              const boxH = (maxGY - minGY + 1) * step;

              // Filter noise / tiny artifacts
              if (boxW >= 16 && boxH >= 16) {
                // Add comfortable 6px padding around detected frame
                const pad = 6;
                const finalX = Math.max(0, minGX * step - pad);
                const finalY = Math.max(0, minGY * step - pad);
                const finalW = Math.min(w - finalX, boxW + pad * 2);
                const finalH = Math.min(h - finalY, boxH + pad * 2);

                detectedBoxes.push({
                  id: Math.random().toString(36).substring(2, 9),
                  x: finalX,
                  y: finalY,
                  width: finalW,
                  height: finalH,
                });
              }
            }
          }
        }

        if (detectedBoxes.length === 0) {
          setErrorMessage('Tidak ditemukan kontur objek stiker. Coba gunakan fitur Grid Standar atau tambah kotak manual.');
        } else {
          // Sort spatially left-to-right, top-to-bottom
          detectedBoxes.sort((a, b) => {
            const diffY = a.y - b.y;
            if (Math.abs(diffY) > 28) return diffY;
            return a.x - b.x;
          });
          setBoxes(detectedBoxes);
          setSelectedBoxId(detectedBoxes[0]?.id || null);
        }
      } catch (err: any) {
        setErrorMessage('Gagal mendeteksi kontur: ' + err.message);
      } finally {
        setIsProcessing(false);
      }
    });
  };

  // Convert Client Mouse Coordinates to SVG Pixel Coordinates
  const getSvgCoordinates = (e: React.MouseEvent | MouseEvent): { x: number; y: number } => {
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
  };

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

  // Mouse Down Handler for Viewport & SVG Overlay
  const handleMouseDown = (e: React.MouseEvent) => {
    if (!sheetImage) return;

    // Pan mode (Middle click or Spacebar held or Pan tool active)
    if (e.button === 1 || isSpacePressed || activeTool === 'pan') {
      e.preventDefault();
      dragActionRef.current = {
        type: 'pan',
        startX: e.clientX,
        startY: e.clientY,
        initialPan: { ...pan },
      };
      return;
    }

    if (e.button !== 0) return; // Only left click for box interaction

    const coords = getSvgCoordinates(e);

    // Eyedropper tool
    if (activeTool === 'eyedropper') {
      handlePickColor(coords);
      return;
    }

    // Draw tool: Start new box
    if (activeTool === 'draw') {
      const newBox: CropBox = {
        id: Math.random().toString(36).substring(2, 9),
        x: coords.x,
        y: coords.y,
        width: 10,
        height: 10,
      };
      setBoxes((prev) => [...prev, newBox]);
      setSelectedBoxId(newBox.id);

      dragActionRef.current = {
        type: 'draw',
        boxId: newBox.id,
        startX: coords.x,
        startY: coords.y,
        initialBox: { ...newBox },
      };
      return;
    }

    // Select tool on background: deselect
    setSelectedBoxId(null);
  };

  // Start Box Move Drag
  const handleBoxMouseDown = (e: React.MouseEvent, box: CropBox) => {
    if (isSpacePressed || activeTool === 'pan' || activeTool === 'draw' || activeTool === 'eyedropper') return;
    e.stopPropagation();
    setSelectedBoxId(box.id);

    const coords = getSvgCoordinates(e);
    dragActionRef.current = {
      type: 'move',
      boxId: box.id,
      startX: coords.x,
      startY: coords.y,
      initialBox: { ...box },
    };
  };

  // Start Handle Resize Drag
  const handleHandleMouseDown = (e: React.MouseEvent, box: CropBox, handle: ResizeHandle) => {
    if (isSpacePressed || activeTool === 'pan' || activeTool === 'draw' || activeTool === 'eyedropper') return;
    e.stopPropagation();
    setSelectedBoxId(box.id);

    const coords = getSvgCoordinates(e);
    dragActionRef.current = {
      type: 'resize',
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
    const boxId = action.boxId;
    if (!boxId) return;

    if (action.type === 'move') {
      const init = action.initialBox!;
      const dx = coords.x - action.startX;
      const dy = coords.y - action.startY;

      const newX = Math.max(0, Math.min(sheetDimensions.width - init.width, init.x + dx));
      const newY = Math.max(0, Math.min(sheetDimensions.height - init.height, init.y + dy));

      setBoxes((prev) =>
        prev.map((b) => (b.id === boxId ? { ...b, x: Math.round(newX), y: Math.round(newY) } : b))
      );
    } else if (action.type === 'resize') {
      const init = action.initialBox!;
      const handle = action.handle!;
      const dx = coords.x - action.startX;
      const dy = coords.y - action.startY;

      let newX = init.x;
      let newY = init.y;
      let newW = init.width;
      let newH = init.height;

      // Handle West
      if (handle.includes('w')) {
        const clampedW = Math.max(12, init.width - dx);
        newX = init.x + (init.width - clampedW);
        newW = clampedW;
      }
      // Handle East
      if (handle.includes('e')) {
        newW = Math.max(12, Math.min(sheetDimensions.width - init.x, init.width + dx));
      }
      // Handle North
      if (handle.includes('n')) {
        const clampedH = Math.max(12, init.height - dy);
        newY = init.y + (init.height - clampedH);
        newH = clampedH;
      }
      // Handle South
      if (handle.includes('s')) {
        newH = Math.max(12, Math.min(sheetDimensions.height - init.y, init.height + dy));
      }

      // Aspect Ratio Lock
      if (lockAspectRatio) {
        const size = Math.max(newW, newH);
        newW = size;
        newH = size;
      }

      // Clamp within sheet bounds
      newX = Math.max(0, Math.min(sheetDimensions.width - 12, newX));
      newY = Math.max(0, Math.min(sheetDimensions.height - 12, newY));
      newW = Math.min(sheetDimensions.width - newX, newW);
      newH = Math.min(sheetDimensions.height - newY, newH);

      setBoxes((prev) =>
        prev.map((b) =>
          b.id === boxId
            ? { ...b, x: Math.round(newX), y: Math.round(newY), width: Math.round(newW), height: Math.round(newH) }
            : b
        )
      );
    } else if (action.type === 'draw') {
      const init = action.initialBox!;
      const curX = coords.x;
      const curY = coords.y;

      let x = Math.min(init.x, curX);
      let y = Math.min(init.y, curY);
      let w = Math.abs(curX - init.x);
      let h = Math.abs(curY - init.y);

      if (lockAspectRatio) {
        const max = Math.max(w, h);
        w = max;
        h = max;
      }

      w = Math.max(12, Math.min(sheetDimensions.width - x, w));
      h = Math.max(12, Math.min(sheetDimensions.height - y, h));

      setBoxes((prev) =>
        prev.map((b) =>
          b.id === boxId
            ? { ...b, x: Math.round(x), y: Math.round(y), width: Math.round(w), height: Math.round(h) }
            : b
        )
      );
    }
  }, [sheetDimensions, lockAspectRatio]);

  const handleMouseUp = useCallback(() => {
    if (dragActionRef.current?.type === 'draw') {
      // Revert to select tool after drawing a box
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

  // Selected Box Reference
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

        // Clamp
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
    if (!sheetImage || boxes.length === 0) {
      setErrorMessage('Belum ada kotak potongan stiker yang dikonfigurasi');
      return;
    }

    setIsProcessing(true);
    setErrorMessage(null);

    // Run async to avoid blocking UI
    setTimeout(() => {
      try {
        // Parse Color Key for Chroma Key
        let tr = 255, tg = 255, tb = 255;
        if (removeBgColor) {
          const hex = bgColorHex.replace('#', '');
          tr = parseInt(hex.substring(0, 2), 16) || 255;
          tg = parseInt(hex.substring(2, 4), 16) || 255;
          tb = parseInt(hex.substring(4, 6), 16) || 255;
        }
        const maxDist = (bgTolerance / 100) * 441.67;

        // Sort boxes spatially left-to-right, top-to-bottom
        const sortedBoxes = [...boxes].sort((a, b) => {
          const diffY = a.y - b.y;
          if (Math.abs(diffY) > 28) return diffY;
          return a.x - b.x;
        });

        const newSlices: SlicedStickerItem[] = [];

        sortedBoxes.forEach((box, idx) => {
          // 1. Extract raw crop
          const rawCanvas = document.createElement('canvas');
          rawCanvas.width = box.width;
          rawCanvas.height = box.height;
          const rawCtx = rawCanvas.getContext('2d', { willReadFrequently: true });
          if (!rawCtx) return;

          rawCtx.drawImage(sheetImage, box.x, box.y, box.width, box.height, 0, 0, box.width, box.height);

          // 2. Apply Chroma Key (Background Color Removal) if enabled
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
                  // Fully transparent
                  data[i + 3] = 0;
                  a = 0;
                } else if (dist < maxDist + 20) {
                  // Soft antialiased feather edge
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

          // 3. Normalize into standard 512x512 Sticker Canvas
          const targetCanvas = document.createElement('canvas');
          targetCanvas.width = targetSize;
          targetCanvas.height = targetSize;
          const targetCtx = targetCanvas.getContext('2d');
          if (!targetCtx) return;

          targetCtx.imageSmoothingEnabled = true;
          targetCtx.imageSmoothingQuality = 'high';

          if (hasContent && autoTrim && maxX >= minX && maxY >= minY) {
            // Trim whitespace and fit neatly into targetSize with safe margin
            const trimmedW = maxX - minX + 1;
            const trimmedH = maxY - minY + 1;
            const scale = Math.min((targetSize * 0.88) / trimmedW, (targetSize * 0.88) / trimmedH);
            const drawW = trimmedW * scale;
            const drawH = trimmedH * scale;
            const drawX = (targetSize - drawW) / 2;
            const drawY = (targetSize - drawH) / 2;

            targetCtx.drawImage(rawCanvas, minX, minY, trimmedW, trimmedH, drawX, drawY, drawW, drawH);
          } else {
            // Simple center fit
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
      title="Studio Ekstraktor Sprite Sheet Stiker (Advanced Visual Cutter)"
      description={`Tarik, ubah ukuran, dan potong stiker secara visual langsung pada gambar sprite sheet paket "${packName}"`}
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
          {/* Left Control & Inspector Panel (4 cols) */}
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
                      {sheetDimensions.width} x {sheetDimensions.height} px • {boxes.length} kotak potong
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

            {/* Multi-Strategy Frame Generator Toolbar */}
            <div className="space-y-2 bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs">
              <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider block">
                Metode Potong Cepat
              </span>

              <div className="grid grid-cols-2 gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="w-full text-xs font-semibold justify-center border-brand-300 hover:border-brand-500 hover:bg-brand-50/50 text-brand-700"
                  disabled={!sheetImage || isProcessing}
                  onClick={handleAutoDetectFrames}
                  icon={<Sparkles className="w-3.5 h-3.5 text-brand-500" />}
                >
                  Deteksi Kontur
                </Button>

                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="w-full text-xs font-semibold justify-center text-neutral-700"
                  disabled={!sheetImage}
                  onClick={() => generateUniformGrid()}
                  icon={<Grid className="w-3.5 h-3.5 text-neutral-500" />}
                >
                  Bagi Grid Rata
                </Button>
              </div>

              {/* Grid Settings Inputs */}
              <div className="grid grid-cols-2 gap-2 pt-1 text-[11px]">
                <div className="flex items-center justify-between bg-neutral-50 px-2 py-1 rounded-lg border border-neutral-200">
                  <span className="text-neutral-500">Kolom</span>
                  <input
                    type="number"
                    min="1"
                    max="32"
                    value={cols}
                    onChange={(e) => setCols(Math.max(1, parseInt(e.target.value) || 1))}
                    className="w-12 text-center text-xs font-bold bg-white rounded border border-neutral-200 py-0.5"
                  />
                </div>
                <div className="flex items-center justify-between bg-neutral-50 px-2 py-1 rounded-lg border border-neutral-200">
                  <span className="text-neutral-500">Baris</span>
                  <input
                    type="number"
                    min="1"
                    max="32"
                    value={rows}
                    onChange={(e) => setRows(Math.max(1, parseInt(e.target.value) || 1))}
                    className="w-12 text-center text-xs font-bold bg-white rounded border border-neutral-200 py-0.5"
                  />
                </div>
              </div>
            </div>

            {/* Precision Numeric Inspector (Selected Box) */}
            <div className="space-y-2 bg-white p-3 rounded-xl border border-neutral-200 shadow-2xs">
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
                    <div className="space-y-1">
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
                    <div className="space-y-1">
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
                    <div className="space-y-1">
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
                    <div className="space-y-1">
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
                      <span>1:1 Ratio</span>
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
                <div className="text-center py-4 text-neutral-400 text-xs">
                  <MousePointer className="w-5 h-5 mx-auto mb-1 text-neutral-300" />
                  Klik salah satu kotak stiker di kanvas untuk mengubah posisi & ukurannya secara presisi
                </div>
              )}
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
                  onClick={() => setActiveTool('draw')}
                  className={`px-2.5 py-1 rounded-md font-semibold flex items-center gap-1.5 transition-all ${
                    activeTool === 'draw' ? 'bg-brand-500 text-white shadow-xs' : 'text-neutral-600 hover:bg-neutral-100'
                  }`}
                  title="Tambah Kotak Baru (Tarik kursor di kanvas)"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>+ Tambah Kotak</span>
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
                  {boxes.length} Kotak Siap Dipotong
                </Badge>
                {boxes.length > 0 && (
                  <button
                    type="button"
                    onClick={() => {
                      if (confirm('Hapus semua kotak potongan?')) {
                        setBoxes([]);
                        setSelectedBoxId(null);
                      }
                    }}
                    className="text-[11px] text-rose-600 hover:underline"
                  >
                    Kosongkan
                  </button>
                )}
              </div>
            </div>

            {/* Interactive Viewport Container */}
            <div
              ref={viewportContainerRef}
              onMouseDown={handleMouseDown}
              className={`w-full h-[460px] rounded-2xl border border-neutral-200/90 overflow-hidden relative select-none flex items-center justify-center ${
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
                  className="relative origin-center transition-transform duration-75 ease-out"
                  style={{
                    width: sheetDimensions.width,
                    height: sheetDimensions.height,
                    transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom})`,
                  }}
                >
                  {/* Base Image Canvas */}
                  <canvas
                    ref={imageCanvasRef}
                    className="absolute inset-0 pointer-events-none drop-shadow-md rounded"
                    style={{ width: sheetDimensions.width, height: sheetDimensions.height }}
                  />

                  {/* SVG Overlay: Crop Boxes, Labels, and 8-point Resize Handles */}
                  <svg
                    ref={svgOverlayRef}
                    className="absolute inset-0 w-full h-full pointer-events-auto"
                    width={sheetDimensions.width}
                    height={sheetDimensions.height}
                  >
                    {boxes.map((box, idx) => {
                      const isSelected = box.id === selectedBoxId;
                      const strokeColor = isSelected ? '#00C896' : 'rgba(6, 182, 212, 0.85)';
                      const fillColor = isSelected ? 'rgba(0, 200, 150, 0.12)' : 'rgba(6, 182, 212, 0.04)';
                      const handleSize = Math.max(7, Math.min(14, 8 / zoom));

                      return (
                        <g key={box.id} className="cursor-move">
                          {/* Main Box Rect */}
                          <rect
                            x={box.x}
                            y={box.y}
                            width={box.width}
                            height={box.height}
                            fill={fillColor}
                            stroke={strokeColor}
                            strokeWidth={Math.max(1.5, 2 / zoom)}
                            strokeDasharray={isSelected ? 'none' : `${4 / zoom},${4 / zoom}`}
                            onMouseDown={(e) => handleBoxMouseDown(e, box)}
                          />

                          {/* Index Label Badge */}
                          <rect
                            x={box.x + 2}
                            y={box.y + 2}
                            width={Math.max(20, 24 / zoom)}
                            height={Math.max(14, 16 / zoom)}
                            fill={isSelected ? '#00C896' : 'rgba(6, 182, 212, 0.9)'}
                            rx={3 / zoom}
                            className="pointer-events-none"
                          />
                          <text
                            x={box.x + Math.max(10, 12 / zoom)}
                            y={box.y + Math.max(11, 13 / zoom)}
                            textAnchor="middle"
                            fill="#FFFFFF"
                            fontSize={Math.max(9, 10 / zoom)}
                            fontFamily="monospace"
                            fontWeight="bold"
                            className="pointer-events-none select-none"
                          >
                            {idx + 1}
                          </text>

                          {/* 8-Point Resize Handles (Only for selected box) */}
                          {isSelected && (
                            <>
                              {/* NW */}
                              <rect
                                x={box.x - handleSize / 2}
                                y={box.y - handleSize / 2}
                                width={handleSize}
                                height={handleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-nwse-resize"
                                onMouseDown={(e) => handleHandleMouseDown(e, box, 'nw')}
                              />
                              {/* N */}
                              <rect
                                x={box.x + box.width / 2 - handleSize / 2}
                                y={box.y - handleSize / 2}
                                width={handleSize}
                                height={handleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-ns-resize"
                                onMouseDown={(e) => handleHandleMouseDown(e, box, 'n')}
                              />
                              {/* NE */}
                              <rect
                                x={box.x + box.width - handleSize / 2}
                                y={box.y - handleSize / 2}
                                width={handleSize}
                                height={handleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-nesw-resize"
                                onMouseDown={(e) => handleHandleMouseDown(e, box, 'ne')}
                              />
                              {/* E */}
                              <rect
                                x={box.x + box.width - handleSize / 2}
                                y={box.y + box.height / 2 - handleSize / 2}
                                width={handleSize}
                                height={handleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-ew-resize"
                                onMouseDown={(e) => handleHandleMouseDown(e, box, 'e')}
                              />
                              {/* SE */}
                              <rect
                                x={box.x + box.width - handleSize / 2}
                                y={box.y + box.height - handleSize / 2}
                                width={handleSize}
                                height={handleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-nwse-resize"
                                onMouseDown={(e) => handleHandleMouseDown(e, box, 'se')}
                              />
                              {/* S */}
                              <rect
                                x={box.x + box.width / 2 - handleSize / 2}
                                y={box.y + box.height - handleSize / 2}
                                width={handleSize}
                                height={handleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-ns-resize"
                                onMouseDown={(e) => handleHandleMouseDown(e, box, 's')}
                              />
                              {/* SW */}
                              <rect
                                x={box.x - handleSize / 2}
                                y={box.y + box.height - handleSize / 2}
                                width={handleSize}
                                height={handleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-nesw-resize"
                                onMouseDown={(e) => handleHandleMouseDown(e, box, 'sw')}
                              />
                              {/* W */}
                              <rect
                                x={box.x - handleSize / 2}
                                y={box.y + box.height / 2 - handleSize / 2}
                                width={handleSize}
                                height={handleSize}
                                fill="#FFFFFF"
                                stroke="#00C896"
                                strokeWidth={2 / zoom}
                                className="cursor-ew-resize"
                                onMouseDown={(e) => handleHandleMouseDown(e, box, 'w')}
                              />
                            </>
                          )}
                        </g>
                      );
                    })}
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
                <Badge variant="brand">{selectedCount} Dipilih</Badge>
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
