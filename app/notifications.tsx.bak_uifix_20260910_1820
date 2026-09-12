import React, { useState, useEffect } from 'react';
import { View, Text, ScrollView, TouchableOpacity, StyleSheet, Switch } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Colors, Spacing, BorderRadius, FontSize, Shadows } from '../src/constants/theme';

const STORAGE_KEY = 'notification_settings';

interface NotifSettings {
  pushEnabled: boolean;
  messageAlert: boolean;
  taskComplete: boolean;
  agentReply: boolean;
}

const DEFAULT_SETTINGS: NotifSettings = {
  pushEnabled: true,
  messageAlert: true,
  taskComplete: true,
  agentReply: true,
};

export default function NotificationsScreen() {
  const router = useRouter();
  const [settings, setSettings] = useState<NotifSettings>(DEFAULT_SETTINGS);

  useEffect(() => {
    AsyncStorage.getItem(STORAGE_KEY).then((stored) => {
      if (stored) {
        try {
          setSettings({ ...DEFAULT_SETTINGS, ...JSON.parse(stored) });
        } catch {}
      }
    }).catch(() => {});
  }, []);

  const updateSetting = async (key: keyof NotifSettings, value: boolean) => {
    const newSettings = { ...settings, [key]: value };
    setSettings(newSettings);
    try {
      await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(newSettings));
    } catch {}
  };

  const ToggleRow = ({ icon, label, desc, settingKey }: {
    icon: string; label: string; desc: string; settingKey: keyof NotifSettings;
  }) => (
    <View style={styles.row}>
      <View style={styles.rowLeft}>
        <View style={styles.iconWrap}>
          <Ionicons name={icon as any} size={20} color={Colors.textSecondary} />
        </View>
        <View style={styles.rowTextWrap}>
          <Text style={styles.rowLabel}>{label}</Text>
          <Text style={styles.rowDesc}>{desc}</Text>
        </View>
      </View>
      <Switch
        value={settings[settingKey]}
        onValueChange={(v) => updateSetting(settingKey, v)}
        trackColor={{ false: '#e5e7eb', true: 'rgba(96,48,255,0.3)' }}
        thumbColor={settings[settingKey] ? Colors.primary : '#9ca3af'}
      />
    </View>
  );

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backBtn}>
          <Ionicons name="arrow-back" size={22} color={Colors.text} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>通知设置</Text>
        <View style={{ width: 36 }} />
      </View>

      <ScrollView showsVerticalScrollIndicator={false}>
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>推送通知</Text>
          <ToggleRow
            icon="notifications-outline"
            label="推送通知"
            desc="接收系统推送通知"
            settingKey="pushEnabled"
          />
          <ToggleRow
            icon="chatbubble-outline"
            label="消息提醒"
            desc="新消息到达时提醒"
            settingKey="messageAlert"
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>自动化通知</Text>
          <ToggleRow
            icon="checkmark-done-outline"
            label="任务完成"
            desc="定时任务执行完成时通知"
            settingKey="taskComplete"
          />
          <ToggleRow
            icon="person-outline"
            label="Agent 回复"
            desc="Agent 生成回复时通知"
            settingKey="agentReply"
          />
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.backgroundSecondary },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: Spacing.md, paddingVertical: Spacing.sm,
    backgroundColor: '#fff', borderBottomWidth: 0.5, borderBottomColor: Colors.borderLight,
  },
  backBtn: { width: 36, height: 36, justifyContent: 'center', alignItems: 'center' },
  headerTitle: { fontSize: FontSize.lg, fontWeight: '700', color: Colors.text },
  section: {
    backgroundColor: '#fff', marginTop: Spacing.sm,
    borderRadius: BorderRadius.lg, marginHorizontal: Spacing.md,
    paddingHorizontal: Spacing.md, paddingTop: Spacing.sm,
    ...Shadows.sm,
  },
  sectionTitle: {
    fontSize: FontSize.xs, color: Colors.textTertiary, fontWeight: '600',
    textTransform: 'uppercase', letterSpacing: 1, paddingVertical: Spacing.xs,
  },
  row: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingVertical: Spacing.md,
    borderBottomWidth: 0.5, borderBottomColor: Colors.borderLight,
  },
  rowLeft: { flexDirection: 'row', alignItems: 'center', gap: Spacing.md, flex: 1 },
  iconWrap: {
    width: 36, height: 36, borderRadius: 10,
    backgroundColor: Colors.backgroundSecondary,
    justifyContent: 'center', alignItems: 'center',
  },
  rowTextWrap: { flex: 1 },
  rowLabel: { fontSize: FontSize.md, color: Colors.text, fontWeight: '500' },
  rowDesc: { fontSize: FontSize.xs, color: Colors.textTertiary, marginTop: 2 },
});
