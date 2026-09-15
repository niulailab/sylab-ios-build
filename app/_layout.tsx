
import { Alert } from "react-native";
setTimeout(async () => {
  const r: string[] = [];
  try { const e = await fetch("https://www.apple.com/", {method:"HEAD"}); r.push("apple:"+e.status); } catch(e:any){ r.push("apple:"+e.message); }
  try { const e = await fetch("https://s.symsgf.xyz/", {method:"HEAD"}); r.push("web:"+e.status); } catch(e:any){ r.push("web:"+e.message); }
  try { const e = await fetch("https://s.symsgf.xyz/v1/conversations",{headers:{Authorization:"Bearer pat_f360e4508904a857bf1466629c9ecc4f53abd2c4cb6572fa76667fceefb24de4"}}); r.push("api:"+e.status); } catch(e:any){ r.push("api:"+e.message); }
  Alert.alert("Net Diag", r.join("\n"));
}, 2000);

import React, { useEffect } from 'react';
import { Stack, useRouter, useSegments } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { View, ActivityIndicator, StyleSheet, Text, TouchableOpacity } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useAuthStore } from '../src/store/auth';
import { queueManager } from '../src/queue/queueTaskManager';
import { Colors } from '../src/constants/theme';


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
    if (!user && !inAuthGroup) {
      router.replace('/login');
    } else if (user && inAuthGroup) {
      router.replace('/(tabs)');
    }
  }, [isRestoring, user, segments]);

  if (isRestoring) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator size="large" color={Colors.primary} />
      </View>
    );
  }

  return (
    <SafeAreaProvider>
    <GestureHandlerRootView style={{ flex: 1 }}>
      <StatusBar style="auto" />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="login" />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen
          name="chat/[id]"
          options={{
            headerShown: true,
            title: "sylab 对话",
            headerStyle: { backgroundColor: "#fff" },
            headerTitleStyle: { fontSize: 17, fontWeight: "700" },
            headerShadowEnabled: false,
            headerTitleContainerStyle: { paddingHorizontal: 0 },
            headerRightContainerStyle: { paddingRight: 16 },
            headerLeftContainerStyle: { paddingLeft: 16 },
          }}
        />
        <Stack.Screen name="register" options={{ headerShown: false }} />
        <Stack.Screen name="forgot-password" options={{ headerShown: false }} />
        <Stack.Screen
          name="projects/[id]"
          options={{
            headerShown: true,
            title: '项目文件',
            headerStyle: { backgroundColor: '#fff' },
            headerTitleStyle: { fontSize: 17, fontWeight: '700' },
            headerShadowEnabled: false,
            headerTitleContainerStyle: { paddingHorizontal: 0 },
            headerRightContainerStyle: { paddingRight: 16 },
            headerLeftContainerStyle: { paddingLeft: 16 },
          }}
        />
      </Stack>
    </GestureHandlerRootView>
    </SafeAreaProvider>
  );
}

export default function RootLayout() {
  const restore = useAuthStore((s) => s.restore);
  

  useEffect(() => {
    restore();
    queueManager.init();
  }, []);

  return <RootErrorBoundary><RootLayoutNav /></RootErrorBoundary>;
}

const styles = StyleSheet.create({
  loading: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' },
});
\n
// === NETWORK DIAGNOSTIC ===
import { Alert } from "react-native";

async function runNetDiagnostic() {
  const results: string[] = [];
  
  // Test 1: Can we reach apple.com?
  try {
    const r1 = await fetch("https://www.apple.com/", { method: "HEAD" });
    results.push(`apple.com: OK ${r1.status}`);
  } catch (e: any) {
    results.push(`apple.com: FAIL ${e.message}`);
  }
  
  // Test 2: Can we reach s.symsgf.xyz root (web page)?
  try {
    const r2 = await fetch("https://s.symsgf.xyz/", { method: "HEAD" });
    results.push(`s.symsgf.xyz/: OK ${r2.status}`);
  } catch (e: any) {
    results.push(`s.symsgf.xyz/: FAIL ${e.message}`);
  }
  
  // Test 3: Can we reach the API?
  try {
    const r3 = await fetch("https://s.symsgf.xyz/v1/conversations", {
      headers: { "Authorization": "Bearer pat_f360e4508904a857bf1466629c9ecc4f53abd2c4cb6572fa76667fceefb24de4" }
    });
    results.push(`API: OK ${r3.status}`);
  } catch (e: any) {
    results.push(`API: FAIL ${e.message}`);
  }
  
  // Test 4: Try Cloudflare trace
  try {
    const r4 = await fetch("https://s.symsgf.xyz/cdn-cgi/trace");
    const text = await r4.text();
    const lines = text.split("\n").filter((l: string) => l.startsWith("ip=") || l.startsWith("tls=") || l.startsWith("http="));
    results.push(`CF-trace: ${lines.join(" ")}`);
  } catch (e: any) {
    results.push(`CF-trace: FAIL ${e.message}`);
  }
  
  Alert.alert("网络诊断", results.join("\n"), [{ text: "OK" }]);
}

setTimeout(() => { runNetDiagnostic(); }, 2000);
// === END DIAGNOSTIC ===

