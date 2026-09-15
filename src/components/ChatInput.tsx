import React, { useState, useRef, useEffect } from 'react';
import * as DocumentPicker from 'expo-document-picker';
import * as ImagePicker from 'expo-image-picker';
import * as FileSystem from 'expo-file-system';
import { View, TextInput, TouchableOpacity, Text, StyleSheet, Platform, Alert, ActivityIndicator, Modal, FlatList, Image } from 'react-native';
import { Colors, Spacing, BorderRadius, FontSize } from '../constants/theme';
import { Ionicons } from '@expo/vector-icons';
import { Audio } from 'expo-av';
import { getBearerToken } from '../api/client';

import { RUNTIME_BASE as API_BASE } from '../config/runtime';

// Module-level storage for pending file blobs when no conversationId exists yet
let _pendingFileBlobs: Array<{blob: Blob, name: string, type: string}> = [];
export function getPendingFiles() { return _pendingFileBlobs; }
export function clearPendingFiles() { _pendingFileBlobs = []; }

interface AttachedFile {
  name: string;
  size: number;
  type: string;
  blob?: Blob;
  uri?: string;
  previewUri?: string; // local uri for thumbnail (native asset.uri or web object URL)
}

// Extract a public URL from a /user-upload style response ({ code, data })
const extractUploadUrl = (result: any): string => {
  if (!result) return '';
  // data may be a JSON string or an object
  let d = result.data;
  if (typeof d === 'string') {
    try { d = JSON.parse(d); } catch { d = null; }
  }
  const url = (d && (d.url || d.file_url || d.download_url)) || result.url || result.file_url || '';
  return typeof url === 'string' ? url : '';
};

interface QuotedMessage {
  role: string;
  content: string;
}

interface ChatInputProps {
  onSend: (text: string, files?: AttachedFile[], fileIds?: string[]) => void;
  onStop?: () => void;
  isStreaming?: boolean;
  isDark?: boolean;
  placeholder?: string;
  onFileUploaded?: (file: { name: string; url: string }) => void;
  conversationId?: string;
  patToken?: string;
  quotedMessage?: QuotedMessage | null;
  onClearQuote?: () => void;
  initialText?: string;
}

const stripMd = (text: string): string => {
  if (!text) return "";
  return text
    .replace(/<img\s[^>]*alt="([^"]*)"[^>]*>/gi, (_, alt) => alt ? `[图片]` : "[图片]")
    .replace(/<img\s[^>]*>/gi, "[图片]")
    .replace(/<[^>]+>/g, "")
    .replace(/#{1,6}\s*/g, "")
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/\*(.+?)\*/g, "$1")
    .replace(/`(.+?)`/g, "$1")
    .replace(/\[(.+?)\]\(.+?\)/g, "$1")
    .replace(/!\[.*?\]\(.+?\)/g, "")
    .replace(/^[-*+]\s+/gm, "")
    .replace(/\n+/g, " ")
    .trim();
};

// Read a native file URI into a Blob (for project-files raw upload)
const uriToBlob = async (uri: string): Promise<Blob> => {
  const resp = await fetch(uri);
  return await resp.blob();
};

// Derive a filename from a URI
const fileNameFromUri = (uri: string, fallback: string): string => {
  try {
    const parts = uri.split('/');
    const last = parts[parts.length - 1];
    if (last && last.includes('.')) return last.split('?')[0];
  } catch {}
  return fallback;
};

export const ChatInput: React.FC<ChatInputProps> = ({
  onSend, onStop, isStreaming, isDark, placeholder,
  onFileUploaded, conversationId, patToken,
  quotedMessage, onClearQuote, initialText,
}) => {
  const [text, setText] = useState('');

  React.useEffect(() => {
    if (initialText && !text) {
      setText(initialText);
    }
  }, [initialText]);
  const [attachedFiles, setAttachedFiles] = useState<AttachedFile[]>([]);
  const [uploading, setUploading] = useState(false);
  const [showAttachMenu, setShowAttachMenu] = useState(false);
  const inputRef = useRef<TextInput>(null);
  const isSendingRef = useRef(false);
  const [inputHeight, setInputHeight] = useState(Platform.OS === 'web' ? 40 : 24);
  const [isRecording, setIsRecording] = useState(false);
  const [recordingDuration, setRecordingDuration] = useState(0);
  const recordingRef = useRef<Audio.Recording | null>(null);
  const recordingTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (Platform.OS !== 'web') return;
    if (!inputRef.current) return;
    const node = inputRef.current as any;
    const el = node?.getElement ? node.getElement() : node;
    if (!el) return;
    el.style.height = '1px';
    const newHeight = Math.min(el.scrollHeight, 120);
    setInputHeight(newHeight);
    el.style.height = newHeight + 'px';
  }, [text]);


  // ========== Voice Recording Functions ==========
  const startRecording = async () => {
    try {
      const perm = await Audio.requestPermissionsAsync();
      if (!perm.granted) {
        Alert.alert('\u9700\u8981\u6743\u9650', '\u8bf7\u5728\u8bbe\u7f6e\u4e2d\u5141\u8bb8\u8bbf\u95ee\u9ea6\u514b\u98ce');
        return;
      }
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInNitroIOS: true,
      });
      const { recording, status } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );
      // iOS requires prepareToRecordAsync after createAsync to actually start capturing
      await recording.prepareToRecordAsync();
      // Verify recording is actually recording
      if (!status.isRecording && !status.isDoneRecording) {
        console.warn('[ChatInput] Recording created but not in recording state, retrying...');
        await new Promise(r => setTimeout(r, 100));
      }
      recordingRef.current = recording;
      setIsRecording(true);
      setRecordingDuration(0);
      recordingTimerRef.current = setInterval(() => {
        setRecordingDuration(prev => prev + 1);
      }, 1000);
    } catch (e: any) {
      console.error('[ChatInput] Start recording error:', e?.message || e, e?.code);
      Alert.alert('录音启动失败', e?.message || '请检查麦克风权限或重试');
    }
  };

  const stopRecording = async () => {
    if (!recordingRef.current) return;
    try {
      if (recordingTimerRef.current) {
        clearInterval(recordingTimerRef.current);
        recordingTimerRef.current = null;
      }
      setIsRecording(false);
      await recordingRef.current.stopAndUnloadAsync();
      await Audio.setAudioModeAsync({ allowsRecordingIOS: false });
      const uri = recordingRef.current.getURI();
      recordingRef.current = null;
      if (!uri) return;

      // Upload audio to ASR endpoint
      const rawBlob = await (await fetch(uri)).blob();
      const asrHeaders: Record<string, string> = { 'Content-Type': 'audio/wav' };
      const bt2 = getBearerToken();
      if (bt2) asrHeaders['Authorization'] = 'Bearer ' + bt2;
      const resp = await fetch(API_BASE + '/api/asr/transcribe', {
        method: 'POST',
        headers: asrHeaders,
        body: rawBlob,
      });
      const data = await resp.json();
      if (data.code === 0 && data.data && data.data.text) {
        setText(prev => prev + (prev ? ' ' : '') + data.data.text);
      } else {
        console.warn('[ChatInput] ASR result:', data);
        if (data.code !== 0) {
          Alert.alert('\u8bed\u97f3\u8bc6\u522b\u5931\u8d25', data.msg || '\u8bf7\u91cd\u8bd5');
        }
      }
    } catch (e) {
      console.error('[ChatInput] Stop recording error:', e);
      Alert.alert('\u5f55\u97f3\u5931\u8d25', '\u8bf7\u7a0d\u540e\u91cd\u8bd5');
    }
  };

  const formatRecordingDuration = (seconds: number) => {
    const m = Math.floor(seconds / 60).toString().padStart(2, '0');
    const s = (seconds % 60).toString().padStart(2, '0');
    return m + ':' + s;
  };

  const handleSend = () => {
    if (isSendingRef.current) return;
    const trimmed = text.trim();
    if (!trimmed && attachedFiles.length === 0) return;
    isSendingRef.current = true;
    onSend(trimmed, attachedFiles.length > 0 ? attachedFiles : undefined);
    setText('');
    setAttachedFiles([]);
    setTimeout(() => { isSendingRef.current = false; }, 500);
  };

  const addFiles = (newFiles: AttachedFile[]) => {
    if (newFiles.length > 0) {
      setAttachedFiles(prev => [...prev, ...newFiles]);
    }
  };

  const handleDocumentPicker = async () => {
    setShowAttachMenu(false);
    if (Platform.OS === 'web') {
      const input = document.createElement('input');
      input.type = 'file';
      input.multiple = true;
      input.onchange = (e: any) => {
        const files = Array.from(e.target.files || []) as File[];
        addFiles(files.map(f => ({
          name: f.name,
          size: f.size,
          type: f.type || 'application/octet-stream',
          blob: f as Blob,
          previewUri: (f.type || '').startsWith('image/') ? URL.createObjectURL(f) : undefined,
        })));
      };
      input.click();
    } else {
      try {
        const result = await DocumentPicker.getDocumentAsync({
          multiple: true,
          type: '*/*',
          copyToCacheDirectory: true,
        });
        if (result.canceled) return;
        addFiles(result.assets.map((asset: any) => ({
          name: asset.name || 'unknown',
          size: asset.size || 0,
          type: asset.mimeType || 'application/octet-stream',
          uri: asset.uri,
        })));
      } catch (e) {
        console.error('[ChatInput] Document picker error:', e);
      }
    }
  };

  const handleImagePicker = async () => {
    setShowAttachMenu(false);
    if (Platform.OS === 'web') {
      const input = document.createElement('input');
      input.type = 'file';
      input.multiple = true;
      input.accept = 'image/*';
      input.onchange = (e: any) => {
        const files = Array.from(e.target.files || []) as File[];
        addFiles(files.map(f => ({
          name: f.name,
          size: f.size,
          type: f.type || 'image/jpeg',
          blob: f as Blob,
          previewUri: (f.type || 'image/jpeg').startsWith('image/') ? URL.createObjectURL(f) : undefined,
        })));
      };
      input.click();
      return;
    }
    try {
      const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) {
        Alert.alert('需要权限', '请在设置中允许访问照片库');
        return;
      }
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        allowsMultipleSelection: true,
        quality: 0.9,
      });
      if (result.canceled) return;
      addFiles(result.assets.map((asset: any) => ({
        name: asset.fileName || fileNameFromUri(asset.uri, `photo_${Date.now()}.jpg`),
        size: asset.fileSize || 0,
        type: asset.mimeType || 'image/jpeg',
        uri: asset.uri,
        previewUri: asset.uri,
      })));
    } catch (e) {
      console.error('[ChatInput] Image picker error:', e);
    }
  };

  const handleCamera = async () => {
    setShowAttachMenu(false);
    if (Platform.OS === 'web') {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.capture = 'environment';
      input.onchange = (e: any) => {
        const files = Array.from(e.target.files || []) as File[];
        addFiles(files.map(f => ({
          name: f.name,
          size: f.size,
          type: f.type || 'image/jpeg',
          blob: f as Blob,
          previewUri: (f.type || 'image/jpeg').startsWith('image/') ? URL.createObjectURL(f) : undefined,
        })));
      };
      input.click();
      return;
    }
    try {
      const perm = await ImagePicker.requestCameraPermissionsAsync();
      if (!perm.granted) {
        Alert.alert('需要权限', '请在设置中允许访问相机');
        return;
      }
      const result = await ImagePicker.launchCameraAsync({
        mediaTypes: ['images'],
        quality: 0.9,
      });
      if (result.canceled) return;
      addFiles(result.assets.map((asset: any) => ({
        name: asset.fileName || `photo_${Date.now()}.jpg`,
        size: asset.fileSize || 0,
        type: asset.mimeType || 'image/jpeg',
        uri: asset.uri,
        previewUri: asset.uri,
      })));
    } catch (e) {
      console.error('[ChatInput] Camera error:', e);
    }
  };

  const removeFile = (index: number) => {
    setAttachedFiles(prev => prev.filter((_, i) => i !== index));
  };

  const UPLOAD_URL = `${API_BASE}/user-upload`;

  // Upload a single file to /user-upload. Returns the public URL on success, or null.
  // Success criterion = we got a usable public URL (AI reads the image via this URL;
  // there is no separate coze file_id). This avoids false "upload failed" alerts when
  // the file was actually saved but a retry/timeout made the client think otherwise.
  const uploadOneFile = async (file: AttachedFile): Promise<string | null> => {
    const tryPost = async (): Promise<string | null> => {
      const parseBody = (bodyText: string): string => {
        try { return extractUploadUrl(JSON.parse(bodyText)) || ''; } catch { return ''; }
      };
      const xFileName = encodeURIComponent(file.name || 'upload.bin');

      // Native: FileSystem.uploadAsync BINARY_CONTENT first (efficient, streams from disk).
      if (Platform.OS !== 'web' && file.uri) {
        try {
          const uploadResp = await FileSystem.uploadAsync(UPLOAD_URL, file.uri, {
            httpMethod: 'POST',
            uploadType: FileSystem.FileSystemUploadType.BINARY_CONTENT,
            headers: {
              'Content-Type': file.type || 'application/octet-stream',
              'X-File-Name': xFileName,
            },
          });
          if (uploadResp.status >= 200 && uploadResp.status < 300) {
            const url = parseBody(uploadResp.body || '');
            if (url) return url;
          }
        } catch (e) {
          console.warn('[ChatInput] uploadAsync failed, fallback to fetch:', (e as any)?.message || e);
        }
      }

      // Unified fetch path (web native, and native fallback). Reads file:// into a Blob.
      let blob = file.blob;
      if (!blob && file.uri) {
        try { blob = await uriToBlob(file.uri); } catch (e) {
          console.warn('[ChatInput] uriToBlob failed:', (e as any)?.message || e);
        }
      }
      if (!blob) throw new Error('no file data');
      // Try raw binary with X-File-Name first (server saves with proper extension).
      const resp = await fetch(UPLOAD_URL, {
        method: 'POST',
        headers: {
          'Content-Type': file.type || 'application/octet-stream',
          'X-File-Name': xFileName,
        },
        body: blob as any,
      });
      if (resp.ok) {
        const url = parseBody(await resp.text());
        if (url) return url;
      }
      // Last resort: multipart/form-data (server also accepts it).
      // CRITICAL: web FormData.append must receive a real Blob/File — appending a
      // plain {uri,name,type} object stringifies to "[object Object]" and stores
      // garbage as the file. Only native React Native accepts the {uri} object form.
      const fd = new FormData();
      const cleanName = decodeURIComponent(xFileName);
      if (Platform.OS === 'web') {
        if (!blob) throw new Error('no file data for multipart');
        fd.append('file', blob as any, cleanName);
      } else {
        fd.append('file', { uri: file.uri, name: cleanName, type: file.type || 'application/octet-stream' } as any);
      }
      const resp2 = await fetch(UPLOAD_URL, { method: 'POST', body: fd as any, headers: { 'X-File-Name': xFileName } });
      if (resp2.ok) {
        const url = parseBody(await resp2.text());
        if (url) return url;
      }
      throw new Error('upload http status ' + resp.status + '/' + resp2.status);
    };

    const maxAttempts = Platform.OS !== 'web' ? 2 : 1;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const url = await tryPost();
        if (url) {
          console.log('[ChatInput] upload OK, url:', url);
          return url;
        }
      } catch (err: any) {
        console.warn(`[ChatInput] upload attempt ${attempt} error:`, err?.message || err);
      }
      if (attempt < maxAttempts) await new Promise(r => setTimeout(r, 1200));
    }
    console.error('[ChatInput] upload failed after', maxAttempts, 'attempts:', file.name);
    return null;
  };

  const handleUploadAndSend = async () => {
    if (isSendingRef.current) return;
    const effectiveConvId = conversationId || '';
    if (attachedFiles.length === 0) {
      handleSend();
      return;
    }

    isSendingRef.current = true;
    setUploading(true);
    const uploadedUrls: string[] = [];

    try {
      for (const file of attachedFiles) {
        // Single source of truth: upload to /user-upload, get a public URL.
        // AI reads the image via this URL — nothing else is needed for it to "see" it.
        const url = await uploadOneFile(file);
        uploadedUrls.push(url || '');
        if (url) onFileUploaded?.({ name: file.name, url });
      }
    } catch (e) {
      console.error('[ChatInput] 文件上传失败:', e);
    } finally {
      setUploading(false);
      setTimeout(() => { isSendingRef.current = false; }, 500);
    }

    const okCount = uploadedUrls.filter(Boolean).length;

    // Only abort + warn when NOTHING uploaded. If at least one file made it up,
    // proceed (AI can see the uploaded ones) instead of a scary false failure.
    if (okCount === 0) {
      Alert.alert(
        '附件上传失败',
        '图片/文件没能传到服务器，可能是网络不稳定。请重试，或换用截图/较小的文件。',
        [{ text: '知道了' }]
      );
      return;
    }
    if (okCount < attachedFiles.length) {
      console.warn(`[ChatInput] ${attachedFiles.length - okCount} file(s) failed; sending ${okCount} ok`);
    }

    // Store pending blobs for later sync (new conversation case)
    if (!effectiveConvId) {
      _pendingFileBlobs = await Promise.all(
        attachedFiles.map(async (f) => {
          let blob = f.blob;
          if (!blob && f.uri) {
            try { blob = await uriToBlob(f.uri); } catch { blob = new Blob([]); }
          }
          return { blob: blob || new Blob([]), name: f.name, type: f.type || 'application/octet-stream' };
        })
      );
    }

    let msgText = text.trim();
    const okNames = attachedFiles
      .map((f, i) => (uploadedUrls[i] ? f.name : null))
      .filter(Boolean) as string[];
    if (okNames.length > 0) {
      const fileNames = okNames.map(n => `\u{1F4CE}${n}`).join(' ');
      msgText = msgText ? `${msgText}\n${fileNames}` : fileNames;
    }

    // File metadata with public URLs (only successfully uploaded ones)
    const fileMeta = attachedFiles
      .map((f, i) => ({
        name: f.name,
        type: f.type || 'application/octet-stream',
        url: uploadedUrls[i] || '',
        fileId: '',
      }))
      .filter(m => m.url);
    onSend(msgText, fileMeta, undefined);
    setText('');
    setAttachedFiles([]);
  };

  const bgColor = isDark ? Colors.surfaceDark : '#fff';
  const borderColor = isDark ? Colors.borderDark : Colors.borderLight;
  const inputColor = isDark ? Colors.textInverse : Colors.text;
  const hasContent = text.trim() || attachedFiles.length > 0;

  const quoteLabel = quotedMessage ? (quotedMessage.role === 'user' ? '我' : 'AI') : '';
  const quotePreview = quotedMessage ? stripMd(quotedMessage.content).substring(0, 100) : '';

  const attachMenuItems = [
    { icon: 'image-outline', label: '照片', color: '#3b82f6', action: handleImagePicker },
    { icon: 'camera-outline', label: '拍照', color: '#10b981', action: handleCamera },
    { icon: 'document-outline', label: '文件', color: '#f59e0b', action: handleDocumentPicker },
  ];

  return (
    <View style={[styles.container, { backgroundColor: bgColor, borderTopColor: borderColor }]}>
      {quotedMessage && (
        <View style={styles.quoteBar}>
          <View style={styles.quoteIconWrap}>
            <Ionicons name="return-down-back-outline" size={14} color={Colors.primary} />
          </View>
          <View style={styles.quoteContent}>
            <Text style={styles.quoteLabel}>引用{quoteLabel}的消息</Text>
            <Text style={styles.quoteText} numberOfLines={2}>{quotePreview}</Text>
          </View>
          <TouchableOpacity onPress={onClearQuote} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
            <Ionicons name="close" size={18} color={Colors.textTertiary} />
          </TouchableOpacity>
        </View>
      )}

      {attachedFiles.length > 0 && (
        <View style={styles.attachments}>
          {attachedFiles.map((file, index) => {
            const isImage = (file.type || '').startsWith('image/') && (file.previewUri || file.uri);
            if (isImage) {
              const thumbUri = file.previewUri || file.uri;
              return (
                <View key={index} style={styles.thumbWrap}>
                  {Platform.OS === 'web' ? (
                    // [FIX] web: render a plain <img> for blob: preview URIs to avoid
                    // RN-Web ImageLoader prefetch (new window.Image) crash on object URLs
                    // @ts-ignore web-only DOM element
                    <img src={thumbUri} style={{ width: 64, height: 64, objectFit: 'cover', borderRadius: 8 }} />
                  ) : (
                    <Image
                      source={{ uri: thumbUri }}
                      style={styles.thumb}
                      resizeMode="cover"
                    />
                  )}
                  <TouchableOpacity
                    onPress={() => removeFile(index)}
                    style={styles.thumbRemove}
                    hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                  >
                    <Ionicons name="close-circle" size={18} color="#fff" />
                  </TouchableOpacity>
                </View>
              );
            }
            return (
              <View key={index} style={styles.attachmentChip}>
                <Ionicons
                  name={file.type.startsWith('video/') ? 'videocam' : 'document'}
                  size={14}
                  color={Colors.primary}
                />
                <Text style={styles.attachmentName}>{file.name}</Text>
                <TouchableOpacity onPress={() => removeFile(index)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
                  <Ionicons name="close-circle" size={16} color={Colors.textTertiary} />
                </TouchableOpacity>
              </View>
            );
          })}
        </View>
      )}

      <View style={[styles.inputRow, { backgroundColor: isDark ? Colors.surfaceSecondaryDark : '#eef0f4' }]}>
        <TouchableOpacity
          style={styles.attachBtn}
          onPress={() => setShowAttachMenu(true)}
          activeOpacity={0.7}
        >
          <Ionicons name="add" size={26} color={Colors.textSecondary} />
        </TouchableOpacity>

        <TextInput
          ref={inputRef}
          style={[styles.input, { color: inputColor, height: inputHeight }]}
          value={text}
          onChangeText={setText}
          placeholder={placeholder || '输入消息...'}
          placeholderTextColor={Colors.textTertiary}
          multiline
          maxLength={10000}
          returnKeyType="send"
          onSubmitEditing={handleUploadAndSend}
          blurOnSubmit={true}
          onKeyDown={(e: any) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              handleUploadAndSend();
            }
          }}
          onContentSizeChange={Platform.OS === 'web' ? undefined : (e: any) => {
            const h = Math.min(120, Math.max(24, Math.ceil(e.nativeEvent.contentSize.height)));
            setInputHeight(h);
          }}
        />

        {isRecording && (
          <View style={styles.recordingIndicator}>
            <View style={styles.recordingDot} />
            <Text style={styles.recordingTime}>{formatRecordingDuration(recordingDuration)}</Text>
          </View>
        )}
        <TouchableOpacity
          style={[styles.micBtn, isRecording ? styles.micBtnActive : {}]}
          onPressIn={startRecording}
          onPressOut={stopRecording}
          activeOpacity={0.7}
          disabled={isStreaming}
        >
          <Ionicons name={isRecording ? "radio" : "mic"} size={20} color={isRecording ? '#fff' : Colors.primary} />
        </TouchableOpacity>
        {isStreaming && (
          <TouchableOpacity style={styles.stopBtn} onPress={onStop} activeOpacity={0.7}>
            <Ionicons name="stop" size={18} color={Colors.danger} />
          </TouchableOpacity>
        )}
        <TouchableOpacity
          style={[styles.sendBtn, { backgroundColor: hasContent ? Colors.primary : 'transparent' }]}
          onPress={handleUploadAndSend}
          disabled={!hasContent || uploading}
          activeOpacity={0.7}
        >
          {uploading ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <Ionicons name="send" size={16} color={hasContent ? '#fff' : Colors.textTertiary} />
          )}
        </TouchableOpacity>
      </View>

      <Modal
        visible={showAttachMenu}
        transparent
        animationType="fade"
        onRequestClose={() => setShowAttachMenu(false)}
      >
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setShowAttachMenu(false)}
        >
          <View style={styles.attachMenu}>
            {attachMenuItems.map((item) => (
              <TouchableOpacity
                key={item.label}
                style={styles.attachMenuItem}
                onPress={item.action}
                activeOpacity={0.7}
              >
                <View style={[styles.attachMenuIcon, { backgroundColor: item.color + '18' }]}>
                  <Ionicons name={item.icon as any} size={22} color={item.color} />
                </View>
                <Text style={styles.attachMenuLabel}>{item.label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </TouchableOpacity>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { paddingHorizontal: Spacing.md, paddingTop: Spacing.sm, paddingBottom: Platform.OS === 'web' ? 34 : Spacing.sm },
  quoteBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.primary + '08',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginBottom: 8,
    borderLeftWidth: 3,
    borderLeftColor: Colors.primary,
  },
  quoteIconWrap: { marginRight: 8 },
  quoteContent: { flex: 1, marginRight: 8 },
  quoteLabel: { fontSize: 11, color: Colors.primary, fontWeight: '600', marginBottom: 2 },
  quoteText: { fontSize: 13, color: Colors.textSecondary },
  attachments: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginBottom: 8,
    paddingHorizontal: 4,
  },
  attachmentChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.primary + '10',
    borderRadius: 16,
    paddingHorizontal: 10,
    paddingVertical: 5,
    gap: 4,
    maxWidth: 200,
  },
  attachmentName: { fontSize: 12, color: Colors.text, maxWidth: 130 },
  thumbWrap: {
    width: 64, height: 64, borderRadius: BorderRadius.md,
    overflow: 'visible', position: 'relative', marginRight: 8, marginBottom: 4,
    borderWidth: 1, borderColor: Colors.borderLight,
  },
  thumb: { width: 64, height: 64, borderRadius: BorderRadius.md, backgroundColor: '#e5e7eb' },
  thumbRemove: {
    position: 'absolute', top: -8, right: -8, zIndex: 2,
    backgroundColor: 'rgba(0,0,0,0.45)', borderRadius: 11, width: 22, height: 22,
    alignItems: 'center', justifyContent: 'center',
  },
  inputRow: {
    flexDirection: 'row', alignItems: 'center',
    borderRadius: BorderRadius.full,
    paddingHorizontal: Spacing.sm, paddingVertical: 6,
  },
  attachBtn: {
    width: 40, height: 40, borderRadius: 20, borderWidth: 1, borderColor: Colors.border,
    justifyContent: 'center', alignItems: 'center',
  },
  input: { flex: 1, fontSize: FontSize.md, maxHeight: 120, lineHeight: 20, paddingVertical: Platform.OS === 'web' ? 2 : 0, marginLeft: Spacing.sm },
  sendBtn: { width: 40, height: 40, borderRadius: 20, justifyContent: 'center', alignItems: 'center', marginLeft: Spacing.sm },
  stopBtn: { width: 40, height: 40, borderRadius: 20, justifyContent: 'center', alignItems: 'center', marginLeft: Spacing.sm },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'flex-end',
  },
  attachMenu: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    paddingTop: 20,
    paddingBottom: 36,
    paddingHorizontal: 24,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    justifyContent: 'space-around',
  },
  attachMenuItem: {
    alignItems: 'center',
    gap: 8,
  },
  attachMenuIcon: {
    width: 56,
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
  },
  attachMenuLabel: {
    fontSize: 13,
    color: Colors.text,
    fontWeight: '500',
  },
  micBtn: {
    width: 40, height: 40, borderRadius: 20,
    justifyContent: 'center', alignItems: 'center',
    marginLeft: 4,
    backgroundColor: Colors.primary + '12',
  },
  micBtnActive: {
    backgroundColor: Colors.danger,
    transform: [{ scale: 1.1 }],
  },
  recordingIndicator: {
    flexDirection: 'row', alignItems: 'center', gap: 4,
    paddingHorizontal: 8,
  },
  recordingDot: {
    width: 8, height: 8, borderRadius: 4,
    backgroundColor: Colors.danger,
  },
  recordingTime: {
    fontSize: 13, color: Colors.danger, fontWeight: '600',
  },
});
