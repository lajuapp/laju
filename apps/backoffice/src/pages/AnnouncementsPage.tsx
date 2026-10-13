import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  Sparkles,
  Plus,
  Trash2,
  AlertCircle,
  Eye,
  Clock,
  ExternalLink,
  Image as ImageIcon,
  Type,
  Upload,
  CheckCircle,
  Smartphone,
  Video,
  Play,
} from 'lucide-react';
import {
  useAnnouncementsList,
  useCreateAnnouncement,
  useUpdateAnnouncement,
  useDeleteAnnouncement,
} from '../hooks/useAnnouncements';
import { useMediaUpload } from '../hooks/useMediaUpload';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { ConfirmModal } from '../components/ui/ConfirmModal';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';
import { usePagination } from '../hooks/usePagination';
import { resolveMediaUrl } from '../api/client';

const COLOR_PRESETS = [
  { name: 'Dark Navy', hex: '#0F172A' },
  { name: 'Deep Slate', hex: '#1E293B' },
  { name: 'Forest Green', hex: '#15803D' },
  { name: 'Royal Purple', hex: '#7E22CE' },
  { name: 'Crimson Red', hex: '#B91C1C' },
  { name: 'Warm Amber', hex: '#C2410C' },
  { name: 'Ocean Blue', hex: '#0369A1' },
];

const announcementSchema = z.object({
  title: z.string().min(3, 'Announcement title must be at least 3 characters'),
  content: z.string().min(5, 'Announcement content must be at least 5 characters'),
  type: z.enum(['INFO', 'WARNING', 'MAINTENANCE']),
  targetType: z.enum(['ALL', 'SPECIFIC', 'BULK']).default('ALL'),
  targetUserIds: z.string().optional(),
  isActive: z.boolean().default(true),
  mediaType: z.enum(['TEXT', 'IMAGE', 'VIDEO']).default('TEXT'),
  mediaUrl: z.string().optional(),
  backgroundColor: z.string().default('#1E293B'),
  durationHours: z.number().default(24),
  actionTitle: z.string().optional(),
  actionUrl: z.string().optional(),
});

type AnnouncementFormValues = z.infer<typeof announcementSchema>;

export function AnnouncementsPage() {
  const { data: announcements, isLoading } = useAnnouncementsList();
  const createAnnouncement = useCreateAnnouncement();
  const updateAnnouncement = useUpdateAnnouncement();
  const deleteAnnouncement = useDeleteAnnouncement();
  const mediaUpload = useMediaUpload();

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [filePreview, setFilePreview] = useState<string | null>(null);
  const [videoDuration, setVideoDuration] = useState<number | null>(null);

  const [deleteModal, setDeleteModal] = useState<{
    isOpen: boolean;
    id: string;
    title: string;
  }>({ isOpen: false, id: '', title: '' });

  const pagination = usePagination(announcements || [], { initialPageSize: 10 });

  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors },
  } = useForm<AnnouncementFormValues>({
    resolver: zodResolver(announcementSchema),
    defaultValues: {
      title: '',
      content: '',
      type: 'INFO',
      targetType: 'ALL',
      targetUserIds: '',
      isActive: true,
      mediaType: 'TEXT',
      mediaUrl: '',
      backgroundColor: '#1E293B',
      durationHours: 24,
      actionTitle: '',
      actionUrl: '',
    },
  });

  const watchMediaType = watch('mediaType');
  const watchTargetType = watch('targetType');
  const watchBackgroundColor = watch('backgroundColor');
  const watchTitle = watch('title');
  const watchContent = watch('content');
  const watchActionTitle = watch('actionTitle');
  const watchActionUrl = watch('actionUrl');
  const watchMediaUrl = watch('mediaUrl');

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setErrorMessage(null);

      if (watchMediaType === 'VIDEO') {
        const video = document.createElement('video');
        video.preload = 'metadata';
        const objectUrl = URL.createObjectURL(file);
        video.onloadedmetadata = () => {
          if (video.duration > 60.5) {
            setErrorMessage(
              `Video length exceeds the 1-minute limit (${Math.round(video.duration)}s). Please use a video under 60 seconds.`
            );
            setSelectedFile(null);
            setFilePreview(null);
            setVideoDuration(null);
            return;
          }
          setSelectedFile(file);
          setFilePreview(objectUrl);
          setVideoDuration(Math.round(video.duration));
        };
        video.onerror = () => {
          setErrorMessage('Failed to load video metadata. Please ensure the file is a valid MP4 or WebM video.');
          setSelectedFile(null);
          setFilePreview(null);
          setVideoDuration(null);
        };
        video.src = objectUrl;
      } else {
        setSelectedFile(file);
        setFilePreview(URL.createObjectURL(file));
        setVideoDuration(null);
      }
    }
  };

  const onSubmit = async (data: AnnouncementFormValues) => {
    try {
      setErrorMessage(null);
      let finalMediaUrl = data.mediaUrl;

      if (selectedFile) {
        const uploadRes = await mediaUpload.mutateAsync(selectedFile);
        finalMediaUrl = uploadRes.url;
      }

      const parsedTargetUserIds = data.targetUserIds
        ? data.targetUserIds.split(',').map((id) => id.trim()).filter(Boolean)
        : undefined;

      await createAnnouncement.mutateAsync({
        ...data,
        targetUserIds: parsedTargetUserIds,
        mediaUrl: finalMediaUrl,
      });

      setIsModalOpen(false);
      reset();
      setSelectedFile(null);
      setFilePreview(null);
      setVideoDuration(null);
    } catch (err: any) {
      setErrorMessage(
        err.response?.data?.message || 'Failed to publish official announcement story'
      );
    }
  };

  const handleToggleActive = (id: string, currentStatus: boolean) => {
    updateAnnouncement.mutate({ id, isActive: !currentStatus });
  };

  const handleOpenDelete = (id: string, title: string) => {
    setDeleteModal({ isOpen: true, id, title });
  };

  const handleConfirmDelete = () => {
    deleteAnnouncement.mutate(deleteModal.id, {
      onSuccess: () => {
        setDeleteModal({ isOpen: false, id: '', title: '' });
      },
    });
  };

  const getTypeBadge = (type: string) => {
    switch (type) {
      case 'WARNING':
        return <Badge variant="warning">Notice</Badge>;
      case 'MAINTENANCE':
        return <Badge variant="error">Maintenance</Badge>;
      default:
        return <Badge variant="brand">Broadcast</Badge>;
    }
  };

  const getTargetBadge = (targetType: string = 'ALL', userCount?: number) => {
    switch (targetType) {
      case 'SPECIFIC':
        return <Badge variant="neutral">Single User</Badge>;
      case 'BULK':
        return <Badge variant="neutral">{userCount || 0} Target Users</Badge>;
      default:
        return <Badge variant="brand">All Users (Broadcast)</Badge>;
    }
  };

  const formatExpiryTime = (expiresAt?: string | null, durationHours?: number) => {
    if (durationHours === 0) return 'Permanent';
    if (!expiresAt) return '24 Hours';

    const diffMs = new Date(expiresAt).getTime() - Date.now();
    if (diffMs <= 0) return 'Expired';

    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    if (diffHours < 24) return `${diffHours}h remaining`;
    const days = Math.floor(diffHours / 24);
    return `${days}d remaining`;
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
              Official Stories & Announcements
            </h1>
            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800">
              <Sparkles className="w-3 h-3 text-amber-600" />
              Automated Story
            </span>
          </div>
          <p className="text-xs text-neutral-500 mt-1">
            Broadcast stories appear directly in the mobile client Status tab with official verified badges.
          </p>
        </div>

        <Button
          variant="primary"
          icon={<Plus className="w-4 h-4" />}
          onClick={() => {
            setErrorMessage(null);
            reset();
            setSelectedFile(null);
            setFilePreview(null);
            setVideoDuration(null);
            setIsModalOpen(true);
          }}
        >
          Create Story Announcement
        </Button>
      </div>

      {/* Announcements Table */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3.5">Story Preview</th>
                <th className="px-5 py-3.5">Title & Message</th>
                <th className="px-5 py-3.5">Type & Target</th>
                <th className="px-5 py-3.5">Duration / Expiry</th>
                <th className="px-5 py-3.5">Views</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5">Published At</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={8} className="px-5 py-8 text-center text-neutral-400">
                    Loading official stories...
                  </td>
                </tr>
              ) : pagination.paginatedItems && pagination.paginatedItems.length > 0 ? (
                pagination.paginatedItems.map((item) => (
                  <tr key={item.id} className="hover:bg-neutral-50/50 transition-colors">
                    {/* Thumbnail Story 9:16 */}
                    <td className="px-5 py-3.5 w-16">
                      <div
                        className="w-12 h-20 rounded-lg overflow-hidden border border-neutral-200 relative flex items-center justify-center shadow-xs bg-cover bg-center"
                        style={{
                          backgroundColor: item.backgroundColor || '#0F172A',
                          backgroundImage: item.mediaType === 'IMAGE' && item.mediaUrl ? `url(${resolveMediaUrl(item.mediaUrl)})` : undefined,
                        }}
                      >
                        {item.mediaType === 'VIDEO' && item.mediaUrl ? (
                          <div className="relative w-full h-full flex items-center justify-center bg-black">
                            <video
                              src={resolveMediaUrl(item.mediaUrl)}
                              className="w-full h-full object-cover"
                              muted
                              playsInline
                            />
                            <div className="absolute inset-0 bg-black/30 flex items-center justify-center">
                              <div className="w-5 h-5 rounded-full bg-white/80 flex items-center justify-center shadow-xs">
                                <Play className="w-2.5 h-2.5 text-neutral-900 fill-neutral-900 ml-0.5" />
                              </div>
                            </div>
                          </div>
                        ) : !item.mediaUrl ? (
                          <div className="p-1 text-center">
                            <span className="text-[7px] font-bold text-white line-clamp-3 leading-tight drop-shadow-xs">
                              {item.title}
                            </span>
                          </div>
                        ) : null}
                        <span className="absolute bottom-1 right-1 bg-black/60 text-[8px] text-white px-1 rounded font-semibold z-10">
                          {item.mediaType === 'VIDEO' ? '1m' : '9:16'}
                        </span>
                      </div>
                    </td>

                    <td className="px-5 py-3.5 max-w-xs">
                      <p className="font-bold text-neutral-900 flex items-center gap-1.5">
                        {item.title}
                        {item.mediaType === 'VIDEO' ? (
                          <span className="text-[10px] text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded font-medium flex items-center gap-0.5">
                            <Video className="w-2.5 h-2.5" /> Video (Max 1m)
                          </span>
                        ) : item.mediaType === 'IMAGE' ? (
                          <span className="text-[10px] text-sky-600 bg-sky-50 px-1.5 py-0.5 rounded font-medium flex items-center gap-0.5">
                            <ImageIcon className="w-2.5 h-2.5" /> Flyer
                          </span>
                        ) : (
                          <span className="text-[10px] text-purple-600 bg-purple-50 px-1.5 py-0.5 rounded font-medium flex items-center gap-0.5">
                            <Type className="w-2.5 h-2.5" /> Text
                          </span>
                        )}
                      </p>
                      <p className="text-neutral-500 text-[11px] mt-0.5 line-clamp-2 leading-relaxed">
                        {item.content}
                      </p>
                      {item.actionUrl && (
                        <div className="mt-1 flex items-center gap-1 text-[10px] text-blue-600 font-medium">
                          <ExternalLink className="w-2.5 h-2.5" />
                          <span>{item.actionTitle || 'Open Link'}</span>
                        </div>
                      )}
                    </td>

                    <td className="px-5 py-3.5 space-y-1">
                      <div>{getTypeBadge(item.type)}</div>
                      <div>{getTargetBadge(item.targetType, item.targetUserCount)}</div>
                    </td>

                    <td className="px-5 py-3.5 text-neutral-700 font-medium text-[11px]">
                      <div className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5 text-neutral-400" />
                        <span>{formatExpiryTime(item.expiresAt, item.durationHours)}</span>
                      </div>
                      <span className="text-[10px] text-neutral-400">
                        {item.durationHours === 0 ? 'Permanent' : `${item.durationHours || 24} Hours`}
                      </span>
                    </td>

                    <td className="px-5 py-3.5">
                      <div className="inline-flex items-center gap-1 text-xs font-semibold text-neutral-700 bg-neutral-100 px-2 py-1 rounded-md">
                        <Eye className="w-3.5 h-3.5 text-neutral-500" />
                        <span>{item.viewsCount || 0}</span>
                      </div>
                    </td>

                    <td className="px-5 py-3.5">
                      {item.isActive ? (
                        <Badge variant="success">Active</Badge>
                      ) : (
                        <Badge variant="neutral">Inactive</Badge>
                      )}
                    </td>

                    <td className="px-5 py-3.5 text-neutral-500 text-[11px]">
                      {new Date(item.createdAt).toLocaleDateString('en-US', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>

                    <td className="px-5 py-3.5 text-right space-x-2">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleToggleActive(item.id, item.isActive)}
                      >
                        {item.isActive ? 'Deactivate' : 'Activate'}
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="text-rose-600 hover:text-rose-700 hover:bg-rose-50"
                        onClick={() => handleOpenDelete(item.id, item.title)}
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </Button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={8} className="px-5 py-8 text-center text-neutral-400">
                    No official announcements posted yet
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer */}
        <div className="px-5 pb-4">
          <Pagination
            currentPage={pagination.currentPage}
            totalPages={pagination.totalPages}
            totalItems={pagination.totalItems}
            pageSize={pagination.pageSize}
            onPageChange={pagination.goToPage}
            onPageSizeChange={pagination.setPageSize}
          />
        </div>
      </div>

      {/* Modal Create Official Announcement */}
      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Publish Official Announcement Story"
        description="Broadcast a 9:16 story with verified official badge to all active client users"
        maxWidth="3xl"
      >
        {errorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            {/* Form Fields */}
            <div className="lg:col-span-7 space-y-4">
              <div>
                <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                  Story Format
                </label>
                <div className="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setValue('mediaType', 'TEXT');
                      setSelectedFile(null);
                      setFilePreview(null);
                      setVideoDuration(null);
                    }}
                    className={`flex items-center justify-center gap-1.5 p-2.5 rounded-xl border text-xs font-semibold transition-all ${
                      watchMediaType === 'TEXT'
                        ? 'border-neutral-900 bg-neutral-900 text-white shadow-xs'
                        : 'border-neutral-200 bg-white text-neutral-600 hover:bg-neutral-50'
                    }`}
                  >
                    <Type className="w-4 h-4" />
                    Gradient Text
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setValue('mediaType', 'IMAGE');
                      setSelectedFile(null);
                      setFilePreview(null);
                      setVideoDuration(null);
                    }}
                    className={`flex items-center justify-center gap-1.5 p-2.5 rounded-xl border text-xs font-semibold transition-all ${
                      watchMediaType === 'IMAGE'
                        ? 'border-neutral-900 bg-neutral-900 text-white shadow-xs'
                        : 'border-neutral-200 bg-white text-neutral-600 hover:bg-neutral-50'
                    }`}
                  >
                    <ImageIcon className="w-4 h-4" />
                    Flyer (9:16)
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setValue('mediaType', 'VIDEO');
                      setSelectedFile(null);
                      setFilePreview(null);
                      setVideoDuration(null);
                    }}
                    className={`flex items-center justify-center gap-1.5 p-2.5 rounded-xl border text-xs font-semibold transition-all ${
                      watchMediaType === 'VIDEO'
                        ? 'border-neutral-900 bg-neutral-900 text-white shadow-xs'
                        : 'border-neutral-200 bg-white text-neutral-600 hover:bg-neutral-50'
                    }`}
                  >
                    <Video className="w-4 h-4" />
                    Video (Max 1m)
                  </button>
                </div>
              </div>

              {watchMediaType === 'IMAGE' && (
                <div>
                  <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                    Upload Flyer Banner (9:16 Recommended)
                  </label>
                  <label className="border-2 border-dashed border-neutral-300 rounded-xl p-4 flex flex-col items-center justify-center gap-2 hover:bg-neutral-50 transition-colors cursor-pointer text-center block">
                    <Upload className="w-6 h-6 text-neutral-400" />
                    <div>
                      <span className="text-xs font-semibold text-neutral-800">
                        {selectedFile ? selectedFile.name : 'Choose image file'}
                      </span>
                      <p className="text-[11px] text-neutral-400 mt-0.5">
                        PNG, JPG, WEBP (1080 x 1920 px recommended)
                      </p>
                    </div>
                    <input
                      type="file"
                      accept="image/*"
                      onChange={handleFileChange}
                      className="hidden"
                    />
                  </label>
                </div>
              )}

              {watchMediaType === 'VIDEO' && (
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="block text-[11px] font-bold text-neutral-700 uppercase tracking-wider">
                      Upload Story Video (Max 1 Minute)
                    </label>
                    <span className="text-[10px] font-bold text-amber-600 bg-amber-50 px-2 py-0.5 rounded-md border border-amber-200">
                      60s Limit
                    </span>
                  </div>
                  <label className="border-2 border-dashed border-neutral-300 rounded-xl p-4 flex flex-col items-center justify-center gap-2 hover:bg-neutral-50 transition-colors cursor-pointer text-center block">
                    <Video className="w-6 h-6 text-neutral-400" />
                    <div>
                      <span className="text-xs font-semibold text-neutral-800">
                        {selectedFile ? selectedFile.name : 'Choose video file'}
                      </span>
                      <p className="text-[11px] text-neutral-400 mt-0.5">
                        MP4, WebM (Duration max 60 seconds)
                      </p>
                    </div>
                    {videoDuration !== null && (
                      <div className="mt-1 inline-flex items-center gap-1 px-2.5 py-1 bg-emerald-50 border border-emerald-200 text-emerald-700 rounded-full text-[11px] font-semibold">
                        <CheckCircle className="w-3.5 h-3.5" />
                        <span>Duration: {videoDuration} seconds (Valid ≤ 60s)</span>
                      </div>
                    )}
                    <input
                      type="file"
                      accept="video/mp4,video/webm,video/quicktime"
                      onChange={handleFileChange}
                      className="hidden"
                    />
                  </label>
                </div>
              )}

              {watchMediaType === 'TEXT' && (
                <div>
                  <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                    Story Background Color
                  </label>
                  <div className="flex flex-wrap items-center gap-2 mb-2">
                    {COLOR_PRESETS.map((preset) => (
                      <button
                        key={preset.hex}
                        type="button"
                        onClick={() => setValue('backgroundColor', preset.hex)}
                        className={`w-7 h-7 rounded-full border-2 transition-all flex items-center justify-center ${
                          watchBackgroundColor === preset.hex
                            ? 'border-neutral-900 ring-2 ring-neutral-400 scale-110'
                            : 'border-transparent hover:scale-105'
                        }`}
                        style={{ backgroundColor: preset.hex }}
                        title={preset.name}
                      >
                        {watchBackgroundColor === preset.hex && (
                          <div className="w-1.5 h-1.5 rounded-full bg-white" />
                        )}
                      </button>
                    ))}
                  </div>
                  <Input
                    placeholder="#1E293B"
                    {...register('backgroundColor')}
                    error={errors.backgroundColor?.message}
                  />
                </div>
              )}

              <Input
                label="Story Title"
                placeholder="e.g. LAJU Network v2.5 Feature Release!"
                {...register('title')}
                error={errors.title?.message}
              />

              <div>
                <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                  Story Content & Message
                </label>
                <textarea
                  {...register('content')}
                  rows={3}
                  placeholder="Enter the broadcast message for users..."
                  className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900 transition-all resize-none"
                />
                {errors.content && (
                  <p className="text-[11px] text-rose-600 font-medium mt-1">
                    {errors.content.message}
                  </p>
                )}
              </div>

              <div>
                <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                  Story Duration
                </label>
                <select
                  {...register('durationHours', { valueAsNumber: true })}
                  className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 bg-white focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900"
                >
                  <option value={24}>24 Hours (Standard Story)</option>
                  <option value={48}>48 Hours (2 Days)</option>
                  <option value={72}>3 Days</option>
                  <option value={168}>7 Days (1 Week)</option>
                  <option value={0}>Permanent (Until deleted)</option>
                </select>
              </div>

              {/* Action Button */}
              <div className="grid grid-cols-2 gap-3 p-3 bg-neutral-50 rounded-xl border border-neutral-100">
                <div className="col-span-2">
                  <span className="text-[11px] font-bold text-neutral-700 uppercase tracking-wider">
                    Link Action Button (Optional)
                  </span>
                  <p className="text-[10px] text-neutral-400 mt-0.5">
                    Displays an action pill button at the bottom of the story
                  </p>
                </div>
                <Input
                  label="Button Label"
                  placeholder="e.g. Open Link"
                  {...register('actionTitle')}
                />
                <Input
                  label="Target URL"
                  placeholder="https://..."
                  {...register('actionUrl')}
                />
              </div>

              {/* Target Audience */}
              <div>
                <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                  Target Audience
                </label>
                <select
                  {...register('targetType')}
                  className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 bg-white focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900"
                >
                  <option value="ALL">📢 All Users (Broadcast)</option>
                  <option value="SPECIFIC">👤 Single User</option>
                  <option value="BULK">👥 Bulk User List</option>
                </select>
              </div>

              {watchTargetType === 'SPECIFIC' && (
                <div>
                  <Input
                    label="Username / User ID"
                    placeholder="@john or 08123456789"
                    {...register('targetUserIds')}
                  />
                </div>
              )}

              {watchTargetType === 'BULK' && (
                <div>
                  <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                    Target List (Comma / Newline Separated)
                  </label>
                  <textarea
                    rows={2}
                    placeholder="@john, @jane, 081234567890"
                    {...register('targetUserIds')}
                    className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900 transition-all resize-none"
                  />
                </div>
              )}

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="isActive"
                  {...register('isActive')}
                  className="rounded border-neutral-300 text-neutral-900 focus:ring-neutral-900 h-4 w-4"
                />
                <label htmlFor="isActive" className="text-xs text-neutral-700 font-medium cursor-pointer">
                  Activate and broadcast this official story immediately
                </label>
              </div>
            </div>

            {/* Live 9:16 Smartphone Mockup Preview */}
            <div className="lg:col-span-5 flex flex-col items-center">
              <label className="block text-[11px] font-bold text-neutral-700 mb-2 uppercase tracking-wider self-start flex items-center gap-1.5">
                <Smartphone className="w-3.5 h-3.5 text-neutral-500" />
                Live Mobile Preview (9:16)
              </label>

              <div className="w-[230px] h-[408px] rounded-[32px] bg-black p-2.5 shadow-2xl border-4 border-neutral-800 relative flex flex-col overflow-hidden">
                <div className="absolute top-3 left-1/2 -translate-x-1/2 w-14 h-3 bg-neutral-900 rounded-full z-30" />

                <div
                  className="w-full h-full rounded-[22px] overflow-hidden relative flex flex-col justify-between p-3.5 bg-cover bg-center transition-colors"
                  style={{
                    backgroundColor: watchBackgroundColor || '#1E293B',
                    backgroundImage: filePreview && watchMediaType === 'IMAGE' ? `url(${filePreview})` : undefined,
                  }}
                >
                  {watchMediaType === 'VIDEO' && (filePreview || watchMediaUrl) && (
                    <video
                      src={filePreview || watchMediaUrl}
                      autoPlay
                      loop
                      muted
                      playsInline
                      className="absolute inset-0 w-full h-full object-cover z-0"
                    />
                  )}

                  <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-transparent to-black/80 pointer-events-none z-0" />

                  {/* Top Bar */}
                  <div className="relative z-10 space-y-2 pt-2">
                    <div className="w-full h-0.5 bg-white/30 rounded-full overflow-hidden">
                      <div className="w-1/2 h-full bg-white rounded-full animate-pulse" />
                    </div>

                    <div className="flex items-center gap-2">
                      <div className="w-7 h-7 rounded-full bg-sky-500 flex items-center justify-center text-white font-bold text-[10px] ring-2 ring-white/50 shadow-sm">
                        L
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-1">
                          <span className="text-[11px] font-bold text-white drop-shadow-sm truncate">
                            LAJU Official
                          </span>
                          <CheckCircle className="w-3 h-3 text-sky-400 fill-sky-400" />
                        </div>
                        <span className="text-[9px] text-white/70">Verified</span>
                      </div>
                    </div>
                  </div>

                  {/* Center Text */}
                  <div className="relative z-10 my-auto text-center px-2 py-4">
                    <h3 className="text-sm font-extrabold text-white leading-tight drop-shadow-md">
                      {watchTitle || 'Official Story Title'}
                    </h3>
                    <p className="text-[11px] text-white/90 mt-1.5 leading-relaxed drop-shadow-sm line-clamp-5">
                      {watchContent || 'Announcement content will appear here...'}
                    </p>
                  </div>

                  {/* Bottom: Action Button */}
                  <div className="relative z-10 pb-1">
                    {watchActionTitle && (
                      <div className="w-full py-1.5 px-3 rounded-full bg-white/95 text-neutral-900 text-center font-bold text-[10px] shadow-lg flex items-center justify-center gap-1">
                        <span>{watchActionTitle}</span>
                        <ExternalLink className="w-2.5 h-2.5" />
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <p className="text-[10px] text-neutral-400 mt-2 text-center">
                9:16 Fullscreen Story Viewer
              </p>
            </div>
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              variant="primary"
              isLoading={createAnnouncement.isPending || mediaUpload.isPending}
            >
              Publish Official Story
            </Button>
          </div>
        </form>
      </Modal>

      {/* Delete Announcement Modal */}
      <ConfirmModal
        isOpen={deleteModal.isOpen}
        onClose={() => setDeleteModal({ isOpen: false, id: '', title: '' })}
        onConfirm={handleConfirmDelete}
        title="Delete Official Story"
        description={`Are you sure you want to delete story "${deleteModal.title}"? It will be removed from user feeds.`}
        confirmText="Delete Story"
        cancelText="Cancel"
        variant="danger"
        isLoading={deleteAnnouncement.isPending}
      />
    </div>
  );
}
