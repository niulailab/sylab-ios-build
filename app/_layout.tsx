import React, { useEffect } from 'react';
import { Stack, useRouter, useSegments } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { View, ActivityIndicator, StyleSheet, Text, TouchableOpacity, Alert } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useAuthStore } from '../src/store/auth';
import { queueManager } from '../src/queue/queueTaskManager';
import { Colors } from '../src/constants/theme';

// === NETWORK DIAGNOSTIC (v108.8) - IPv6 test ===
let _diagShown = false;
async function runDiag(): Promise<string[]> {
  const r: string[] = [];
  // 1. Baseline
  try { const e = await fetch("https://www.apple.com/", {method:"HEAD"}); r.push("1.apple:OK "+e.status); } catch(e:any){ r.push("1.apple:FAIL "+e.message); }
  // 2. s.symsgf.xyz domain (let system choose)
  try { const e = await fetch("https://s.symsgf.xyz/", {method:"HEAD"}); r.push("2.domain:OK "+e.status); } catch(e:any){ r.push("2.domain:FAIL "+e.message); }
  // 3. Direct IPv4 with Host header
  try { const e = await fetch("https://[2606:4700:3032::ac43:a899]/", {method:"HEAD", headers:{Host:"s.symsgf.xyz"}}); r.push("3.ipv6-direct:OK "+e.status); } catch(e:any){ r.push("3.ipv6:FAIL "+e.message); }
  // 4. Direct IPv4
  try { const e = await fetch("https://104.21.26.237/", {method:"HEAD", headers:{Host:"s.symsgf.xyz"}}); r.push("4.ipv4:OK "+e.status); } catch(e:any){ r.push("4.ipv4:FAIL "+e.message); }
  // 5. cloudflare.com
  try { const e = await fetch("https://www.cloudflare.com/", {method:"HEAD"}); r.push("5.cflare:OK "+e.status); } catch(e:any){ r.push("5.cflare:FAIL "+e.message); }
  // 6. Another domain on same IPv6 range
  try { const e = await fetch("https://[2606:4700:3032::ac43:a899]/", {method:"HEAD", headers:{Host:"ai.symsgf.xyz"}}); r.push("6.ipv6-ai:OK "+e.status); } catch(e:any){ r.push("6.ipv6-ai:FAIL "+e.message); }
  return r;
}

setTimeout(async () => {
  if (_diagShown) return;
  _diagShown = true;
  const results = await runDiag();
  Alert.alert("NetDiag v108.8", results.join("\n"), [{text:"OK"}]);
}, 2500);
// === END DIAGNOSTIC ===

class RootErrorBoundary extends React.Component<{children: React.ReactNode}, {hasError: boolean; error: string}> {
  constructor(props: {children: React.ReactNode}) {
    super(props);
    this.state = { hasError: false, error: '' };
  }
  static getDerivedStateFromError(error: any) {
    return { hasError: true, error: String(error?.message || error) };
  }
  componentDidCatch(error: any, info: any) {
    console.error('[RootErrorBoundary]', error, info);
  }
  render() {
    if (this.state.hasError) {
      return (
        <View style={{flex:1, justifyContent:'center', alignItems:'center', padding:20, backgroundColor:'#fff'}}>
          <Text style={{fontSize:20, fontWeight:'bold', color:'#ef4444', marginBottom:12}}>App Error</Text>
          <Text style={{fontSize:13, color:'#6b7280', textAlign:'center', marginBottom:20}}>{this.state.error}</Text>
          <TouchableOpacity onPress={() => this.setState({hasError:false, error:''})} style={{padding:12, backgroundColor:'#8B5CF6', borderRadius:8}}>
            <Text style={{color:'#fff', fontSize:15, fontWeight:'600'}}>Retry</Text>
          </TouchableOpacity>
        </View>
      );
    }
    return this.props.children;
  }
}

function RootLayoutNav() {
  const { isRestoring, user } = useAuthStore();
  const segments = useSegments();
  const router = useRouter();
  useEffect(() => {
    if (isRestoring) return;
    const inAuthGroup = segments[0] === 'login' || segments[0] === 'register' || segments[0] === 'forgot-password';
    if (!user && !inAuthGroup) { router.replace('/login'); } else if (user && inAuthGroup) { router.replace('/(tabs)'); }
  }, [isRestoring, user, segments]);
  if (isRestoring) { return <View style={styles.loading}><ActivityIndicator size="large" color={Colors.primary} /></View>; }
  return (
    <SafeAreaProvider>
    <GestureHandlerRootView style={{ flex: 1 }}>
      <StatusBar style="auto" />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="login" />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="chat/[id]" options={{ headerShown: true, title: "sylab 对话", headerStyle: { backgroundColor: "#fff" }, headerTitleStyle: { fontSize: 17, fontWeight: "700" }, headerShadowEnabled: false, headerTitleContainerStyle: { paddingHorizontal: 0 }, headerRightContainerStyle: { paddingRight: 16 }, headerLeftContainerStyle: { paddingLeft: 16 }, }} />
        <Stack.Screen name="register" options={{ headerShown: false }} />
        <Stack.Screen name="forgot-password" options={{ headerShown: false }} />
        <Stack.Screen name="projects/[id]" options={{ headerShown: true, title: '项目文件', headerStyle: { backgroundColor: '#fff' }, headerTitleStyle: { fontSize: 17, fontWeight: '700' }, headerShadowEnabled: false, headerTitleContainerStyle: { paddingHorizontal: 0 }, headerRightContainerStyle: { paddingRight: 16 }, headerLeftContainerStyle: { paddingLeft: 16 }, }} />
      </Stack>
    </GestureHandlerRootView>
    </SafeAreaProvider>
  );
}

export default function RootLayout() {
  const restore = useAuthStore((s) => s.restore);
  useEffect(() => { restore(); queueManager.init(); }, []);
  return <RootErrorBoundary><RootLayoutNav /></RootErrorBoundary>;
}

const styles = StyleSheet.create({ loading: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' },});
