import React from 'react';
import { Platform } from 'react-native';
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../src/constants/theme';
import { useTheme } from '../../src/hooks/useTheme';

// Register Service Worker for PWA
if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js', { scope: '/' })
      .then((reg) => console.log('[SW] Registered'))
      .catch((err) => console.warn('[SW] Registration failed:', err));
  });
}


export default function TabLayout() {
  const { isDark } = useTheme();
  const tabBarBg = isDark ? '#1e293b' : '#fff';
  const headerBg = isDark ? '#1e293b' : '#fff';
  const headerTextColor = isDark ? '#f1f5f9' : Colors.text;

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: Colors.primary,
        tabBarInactiveTintColor: Colors.textTertiary,
        tabBarStyle: {
          borderTopWidth: 0,
          backgroundColor: tabBarBg,
          paddingBottom: Platform.OS === 'ios' ? 20 : 14,
          paddingTop: 6,
          height: Platform.OS === 'ios' ? 80 : 72,
          ...{ shadowColor: '#000', shadowOffset: { width: 0, height: -2 }, shadowOpacity: 0.06, shadowRadius: 8, elevation: 5 },
        },
        tabBarLabelStyle: { fontSize: 10, fontWeight: '600', marginTop: 2 },
        headerStyle: {
          backgroundColor: tabBarBg,
          elevation: 0,
          shadowOpacity: 0,
        },
        headerTitleStyle: { fontSize: 18, fontWeight: '700', color: headerTextColor },
        headerShadowAllowed: false,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: '项目',
          tabBarIcon: ({ color, size }) => <Ionicons name="folder" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="chat"
        options={{
          title: '对话',
          tabBarIcon: ({ color, size }) => <Ionicons name="chatbubbles" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="agents"
        options={{
          href: null,
          title: 'Agent',
          tabBarIcon: ({ color, size }) => <Ionicons name="people-circle" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="schedule"
        options={{
          href: null,
          title: '工具中心',
          tabBarIcon: ({ color, size }) => <Ionicons name="apps" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="skills"
        options={{
          title: '技能',
          tabBarIcon: ({ color, size }) => <Ionicons name="sparkles" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: '我的',
          tabBarIcon: ({ color, size }) => <Ionicons name="person" size={size} color={color} />,
        }}
      />
    </Tabs>
  );
}

