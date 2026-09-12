import React, { useState } from 'react';
import {
  View, Text, Modal, Image, ScrollView, TouchableOpacity, StyleSheet,
  Dimensions, Platform, Pressable, Linking, Alert, ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as FileSystem from 'expo-file-system';
// NOTE: expo-sharing 是新依赖，iOS 换壳基线包没有对应原生模块：
// 缺失模块在 native 层直接 fatal crash，JS try/catch 拦不住。
// 所以只能让 require 语句在 iOS 上永不执行（放进 Platform.OS === 'android' 分支），
// iOS 改为 Safari 打开图片 → 长按「存储图像」。

const { width: SCREEN_W, height: SCREEN_H } = Dimensions.get('window');

// Convert HTTP server URLs to HTTPS tunnel (iOS ATS / consistency)
function normalizeUrl(url: string): string {
  if (!url) return url;
  return url
    .replace(/http:\/\/36\.137\.84\.216:9091/g, 'https://s.symsgf.xyz')
    .replace(/http:\/\/127\.0\.0\.1:9091/g, 'https://s.symsgf.xyz')
    .replace(/http:\/\/localhost:9091/g, 'https://s.symsgf.xyz');
}

/**
 * ZoomableImage: full-screen image viewer.
 * - Tap thumbnail to open
 * - Pinch / double-tap to zoom (ScrollView handles pinch natively on native;
 *   double-tap toggles a 2.5x zoom for both web and native)
 * - Tap background / close button to dismiss
 * Reusable across chat bubbles and markdown.
 */
export const ZoomableImage: React.FC<{ uri: string; children: React.ReactNode }> = ({ uri, children }) => {
  const [visible, setVisible] = useState(false);
  const [zoomed, setZoomed] = useState(false);
  const safeUri = normalizeUrl(uri);

  const toggleZoom = () => setZoomed(z => !z);

  const [downloading, setDownloading] = useState(false);

  const handleSave = async () => {
    if (downloading) return;
    setDownloading(true);
    try {
      if (Platform.OS === 'web') {
        window.open(safeUri, '_blank');
      } else if (Platform.OS === 'android') {
        // Android 全量构建 APK 内含 expo-sharing 原生模块：下载后弹分享面板保存。
        let shared = false;
        try {
          const Sharing = require('expo-sharing');
          if (await Sharing.isAvailableAsync()) {
            const fileName = safeUri.split('/').pop()?.split('?')[0] || 'image.png';
            const localUri = FileSystem.cacheDirectory + fileName;
            const { uri } = await FileSystem.downloadAsync(safeUri, localUri);
            await Sharing.shareAsync(uri);
            shared = true;
          }
        } catch (se) {
          console.warn('Share unavailable, fallback to browser:', se);
        }
        if (!shared) {
          await Linking.openURL(safeUri);
        }
      } else {
        // iOS: 先下载到本地缓存，再通过 Share 面板保存/分享（无需跳 Safari）。
        try {
          const fileName = safeUri.split('/').pop()?.split('?')[0] || 'image.png';
          const localUri = FileSystem.cacheDirectory + fileName;
          const { uri: localPath } = await FileSystem.downloadAsync(safeUri, localUri);
          // 优先尝试 Share 面板（原生保存/分享）
          let shared = false;
          try {
            const Sharing = require('expo-sharing');
            if (await Sharing.isAvailableAsync()) {
              await Sharing.shareAsync(localPath, { UTI: 'public.image', mimeType: 'image/png' });
              shared = true;
            }
          } catch (se) {
            console.warn('[ImageLightbox] expo-sharing unavailable, fallback to browser:', se);
          }
          if (!shared) {
            // Share 不可用时才跳 Safari
            Alert.alert(
              '保存图片',
              '即将在浏览器中打开图片，请长按图片选择「存储图像」保存到相册。',
              [{ text: '好的', onPress: () => Linking.openURL(safeUri) }]
            );
          }
        } catch (e) {
          console.warn('[ImageLightbox] Download failed:', e);
          Alert.alert('Error', '下载失败，请稍后重试');
        }
      }
    } catch (e: any) {
      console.warn('Save failed:', e);
      if (Platform.OS !== 'web') Alert.alert('Error', e?.message || 'Retry later');
    } finally {
      setDownloading(false);
    }
  };

  return (
    <>
      <Pressable
        onPress={() => setVisible(true)}
        style={({ pressed }) => ({ opacity: pressed ? 0.85 : 1 })}
        accessibilityRole="imagebutton"
      >
        {children}
      </Pressable>
      <Modal visible={visible} transparent animationType="fade" onRequestClose={() => { setVisible(false); setZoomed(false); }}>
        <View style={lb.overlay}>
          <TouchableOpacity
            style={lb.closeBtn}
            onPress={() => { setVisible(false); setZoomed(false); }}
            hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
          >
            <Ionicons name="close-circle" size={30} color="#fff" />
          </TouchableOpacity>
          <TouchableOpacity
            style={lb.openBtn}
            onPress={() => Linking.openURL(safeUri).catch(() => {})}
            hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
          >
            <Ionicons name="open-outline" size={24} color="#fff" />
          </TouchableOpacity>
          <TouchableOpacity
            style={lb.saveBtn}
            onPress={handleSave}
            disabled={downloading}
            hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
          >
            {downloading ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <Ionicons name="download-outline" size={24} color="#fff" />
            )}
          </TouchableOpacity>
          <ScrollView
            style={{ flex: 1 }}
            contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', alignItems: 'center' }}
            maximumZoomScale={4}
            minimumZoomScale={1}
            zoomScale={Platform.OS === 'web' ? (zoomed ? 2.5 : 1) : undefined}
            showsHorizontalScrollIndicator={false}
            showsVerticalScrollIndicator={false}
            centerContent
            onTouchEnd={() => { /* native pinch handled by ScrollView */ }}
          >
            <Pressable onPress={toggleZoom}>
              <Image
                source={{ uri: safeUri }}
                style={zoomed ? lb.imageZoomed : lb.imageFit}
                resizeMode="contain"
              />
            </Pressable>
          </ScrollView>
          <Text style={lb.hint}>双击缩放 · 点击下载保存</Text>
        </View>
      </Modal>
    </>
  );
};

const lb = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.92)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  closeBtn: {
    position: 'absolute',
    top: Platform.OS === 'web' ? 24 : 48,
    right: 20,
    zIndex: 10,
    backgroundColor: 'rgba(0,0,0,0.4)',
    borderRadius: 20,
    padding: 4,
  },
  openBtn: {
    position: 'absolute',
    top: Platform.OS === 'web' ? 24 : 48,
    right: 64,
    zIndex: 10,
    backgroundColor: 'rgba(0,0,0,0.4)',
    borderRadius: 18,
    padding: 6,
  },
  saveBtn: {
    position: 'absolute',
    top: Platform.OS === 'web' ? 24 : 48,
    right: 108,
    zIndex: 10,
    backgroundColor: 'rgba(0,0,0,0.4)',
    borderRadius: 18,
    padding: 6,
  },
  imageFit: {
    width: SCREEN_W * 0.94,
    height: SCREEN_H * 0.7,
  },
  imageZoomed: {
    width: SCREEN_W * 0.94 * 2.5,
    height: SCREEN_H * 0.7 * 2.5,
  },
  hint: {
    position: 'absolute',
    bottom: Platform.OS === 'web' ? 20 : 40,
    color: 'rgba(255,255,255,0.7)',
    fontSize: 12,
  },
});

export default ZoomableImage;
