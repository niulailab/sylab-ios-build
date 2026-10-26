import React, { useCallback, useEffect, useState } from 'react';
import {
  View, Text, FlatList, StyleSheet, TouchableOpacity, Alert, TextInput,
  Modal, KeyboardAvoidingView, Platform, ScrollView, ActivityIndicator, SafeAreaView,
} from 'react-native';
import { useNavigation } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../src/hooks/useTheme';
import { Colors } from '../src/constants/theme';
import { useAuthStore } from '../src/store/auth';
import { byokApi, BYOK_PRESETS, ByokModel } from '../src/api/byok';
import { SafeAlert } from '../src/utils/safeAlert';

type Provider = 'deepseek'|'zhipu'|'qwen'|'kimi'|'doubao'|'custom';

export default function MyModelsScreen() {
  const { isDark } = useTheme();
  const insets = useSafeAreaInsets();
  const nav = useNavigation();
  const user = useAuthStore(s => s.user);
  const [list, setList] = useState<ByokModel[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [modal, setModal] = useState<{ open:boolean; editing:ByokModel|null }>({ open:false, editing:null });
  const [activeId, setActiveId] = useState<number|null>(null);

  useEffect(() => {
    nav.setOptions({ title:'我的 AI 模型', headerBackTitle:'' });
  }, []);

  const refresh = useCallback(async () => {
    if (!user?.id) return;
    try {
      const [items, act] = await Promise.all([byokApi.list(user.id), byokApi.active(user.id)]);
      setList(items || []);
      setActiveId(act?.id ?? null);
    } catch (e:any) {
      SafeAlert.alert('加载失败', e?.message || String(e));
    } finally {
      setLoading(false); setRefreshing(false);
    }
  }, [user?.id]);

  useEffect(() => { refresh(); }, [refresh]);
  useEffect(() => nav.addListener('focus', refresh), [nav, refresh]);

  const onAdd = () => setModal({ open:true, editing:null });
  const onEdit = (m:ByokModel) => setModal({ open:true, editing:m });
  const onDelete = (m:ByokModel) => {
    if (!user?.id) return;
    Alert.alert('删除模型', `确定删除「${m.display_name}」？`, [
      { text:'取消', style:'cancel' },
      { text:'删除', style:'destructive', onPress: async () => {
        try {
          await byokApi.remove(user.id, m.id);
          await refresh();
        } catch(e:any) { SafeAlert.alert('删除失败', e?.message || String(e)); }
      }},
    ]);
  };
  const onSetDefault = async (m:ByokModel) => {
    if (!user?.id) return;
    try {
      await byokApi.setActive(user.id, m.id, 1);
      await refresh();
    } catch(e:any){ SafeAlert.alert('切换失败', e?.message || String(e)); }
  };

  if (loading) return (
    <View style={[styles.center,{paddingTop:insets.top}]}><ActivityIndicator size="large" color={Colors.primary} /></View>
  );

  const isUsingMy = activeId !== null;

  return (
    <SafeAreaView style={[styles.container,{paddingTop:insets.top, backgroundColor:isDark?'#0f172a':'#fff'}]}>
      {/* 顶部卡片：账号级开关 */}
      <View style={[styles.headerCard, {backgroundColor: isUsingMy ? (isDark?'#2d1b69':'#f3eeff'):(isDark?'#1e293b':'#f1f5f9'), marginHorizontal:16, borderRadius:16, padding:16, marginBottom:12}]}>
        <View style={{flexDirection:'row', alignItems:'center'}}>
          <Ionicons name={isUsingMy?'flash':'cloud-outline'} size={22} color={isUsingMy?Colors.primary:(isDark?'#94a3b8':'#64748b')} />
          <Text style={[styles.headerTitle,{color:isDark?'#f1f5f9':'#0f172a', marginLeft:8, flex:1}]}>
            {isUsingMy ? '正在使用我的模型' : '正在使用平台模型'}
          </Text>
        </View>
        <Text style={[styles.headerSub,{color: isDark?'#94a3b8':'#64748b', marginTop:6, fontSize:12, lineHeight:18}]}>
          {isUsingMy
            ? '聊天将走你配置的自有模型，不消耗平台积分。生图/视频仍扣费。'
            : '聊天走 sylab 平台模型（GLM/DeepSeek）。选中下方任意模型即可切换。'}
        </Text>
        {!isUsingMy && list.length === 0 && (
          <TouchableOpacity onPress={onAdd} style={[styles.addBtn,{backgroundColor:Colors.primary, marginTop:10}]}>
            <Text style={{color:'#fff',fontWeight:'700',fontSize:14}}>＋ 添加第一个模型</Text>
          </TouchableOpacity>
        )}
      </View>

      <FlatList
        data={list}
        keyExtractor={i => String(i.id)}
        refreshing={refreshing}
        onRefresh={()=>{setRefreshing(true); refresh();}}
        contentContainerStyle={{padding:16, paddingBottom:100}}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Ionicons name="cube-outline" size={48} color={isDark?'#475569':'#cbd5e1'} />
            <Text style={[styles.emptyText,{color:isDark?'#94a3b8':'#64748b', marginTop:12}]}>还没有自定义模型</Text>
            <Text style={{color:isDark?'#64748b':'#94a3b8', fontSize:12, marginTop:4, textAlign:'center', paddingHorizontal:32}}>
              填入你在厂商申请的 API key 就能用，额度走你自己的账号
            </Text>
          </View>
        }
        renderItem={({ item }) => (
          <TouchableOpacity onPress={()=>onEdit(item)} activeOpacity={0.8} style={[styles.card,{backgroundColor:isDark?'#1e293b':'#fff', borderColor:item.is_default?Colors.primary:(isDark?'#334155':'#e2e8f0'), borderWidth:item.is_default?2:1}]}>
            <View style={styles.cardTop}>
              <View style={{flex:1}}>
                <View style={{flexDirection:'row', alignItems:'center'}}>
                  <Text style={[styles.cardTitle,{color:isDark?'#f1f5f9':'#0f172a'}]}>{item.display_name}</Text>
                  <View style={[styles.tag,{backgroundColor:(BYOK_PRESETS as any)[item.provider]?.name?'#8B5CF6':'#0EA5E9'}]}>
                    <Text style={{color:'#fff', fontSize:10}}>{(BYOK_PRESETS as any)[item.provider]?.name || item.provider}</Text>
                  </View>
                  {item.is_default===1 && <View style={[styles.tag,{backgroundColor:Colors.primary, marginLeft:4}]}><Text style={{color:'#fff',fontSize:10}}>默认</Text></View>}
                </View>
                <Text style={[styles.cardMeta,{color:isDark?'#94a3b8':'#64748b', marginTop:4, fontSize:12}]} numberOfLines={1}>
                  {item.model_name} · {item.base_url}
                </Text>
                <Text style={[styles.cardMeta,{color:isDark?'#64748b':'#94a3b8', marginTop:2, fontSize:11, fontFamily: 'Menlo'}]}>
                  {item.key_hint}
                </Text>
              </View>
              <View style={{gap:8}}>
                {item.is_default!==1 && (
                  <TouchableOpacity onPress={()=>onSetDefault(item)} style={styles.iconBtn}>
                    <Ionicons name="star-outline" size={20} color={Colors.primary} />
                  </TouchableOpacity>
                )}
                <TouchableOpacity onPress={()=>onDelete(item)} style={styles.iconBtn}>
                  <Ionicons name="trash-outline" size={20} color="#ef4444" />
                </TouchableOpacity>
              </View>
            </View>
            {item.last_test_ok!==null && (
              <View style={{flexDirection:'row', alignItems:'center', marginTop:8}}>
                <Ionicons name={item.last_test_ok===1?'checkmark-circle':'alert-circle'} size={14} color={item.last_test_ok===1?'#10b981':'#ef4444'} />
                <Text style={[styles.cardMeta,{color:isDark?'#94a3b8':'#64748b', marginLeft:4, flex:1}]} numberOfLines={1}>
                  {item.last_test_ok===1 ? '最近测试通过' : (item.last_test_msg || '最近测试失败')}
                </Text>
              </View>
            )}
          </TouchableOpacity>
        )}
      />

      {list.length>0 && (
        <TouchableOpacity onPress={onAdd} style={[styles.fab, {backgroundColor:Colors.primary, bottom: 24+insets.bottom, right:20}]}>
          <Ionicons name="add" size={24} color="#fff" />
        </TouchableOpacity>
      )}

      <FormModal
        visible={modal.open}
        editing={modal.editing}
        onClose={()=>setModal({open:false, editing:null})}
        onSaved={()=>{setModal({open:false, editing:null}); refresh();}}
      />
    </SafeAreaView>
  );
}

function FormModal({ visible, editing, onClose, onSaved }:{
  visible:boolean; editing:ByokModel|null; onClose:()=>void; onSaved:()=>void
}) {
  const { isDark } = useTheme();
  const user = useAuthStore(s=>s.user);
  const [provider, setProvider] = useState<Provider>('deepseek');
  const [name, setName] = useState('');
  const [baseUrl, setBaseUrl] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [modelName, setModelName] = useState('');
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [testMsg, setTestMsg] = useState('');
  const [models, setModels] = useState<{id:string;name:string}[]>([]);
  const [fetching, setFetching] = useState(false);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [providers, setProviders] = useState<{key:Provider;label:string}[]>(
    Object.entries(BYOK_PRESETS).map(([k,v])=>({key:k as Provider, label:(v as any).name}))
  );

  useEffect(()=>{
    if (visible) {
      if (editing) {
        setProvider((editing.provider as Provider) || 'custom');
        setName(editing.display_name || '');
        setBaseUrl(editing.base_url || '');
        setApiKey(''); // 不回填明文
        setModelName(editing.model_name || '');
      } else {
        setProvider('deepseek');
        setName(''); setBaseUrl(BYOK_PRESETS.deepseek.url); setApiKey(''); setModelName(BYOK_PRESETS.deepseek.default_model);
      }
      setTestMsg('');
    }
  }, [visible, editing]);

  const onPickProvider = (p:Provider) => {
    setProvider(p);
    const preset = BYOK_PRESETS[p];
    setModels([]);
    if (!editing) {
      setBaseUrl(preset.url);
      setModelName(preset.default_model);
      setName(preset.name);
    }
  };

  // 填完 base_url + key 后点「获取」，从端点真实拉取可用模型列表
  const onFetchModels = async () => {
    if (!user?.id) return;
    if (!baseUrl.trim()) { SafeAlert.alert('请先填写 Base URL'); return; }
    if (!apiKey.trim() && !editing) { SafeAlert.alert('请先填写 API Key'); return; }
    setFetching(true); setTestMsg('');
    try {
      const r = await byokApi.listModels({
        base_url: baseUrl.trim().replace(/\/+$/,''),
        api_key: apiKey.trim(),
        provider,
        user_id: user.id,
        ...(editing ? { id: editing.id } : {}),
      });
      if (r.ok && r.models && r.models.length) {
        setModels(r.models);
        setPickerOpen(true);
      } else if (r.ok) {
        setTestMsg('⚠️ 端点未返回任何模型，请手动填写模型名');
      } else {
        setTestMsg('❌ ' + (r.msg || '获取失败'));
      }
    } catch(e:any) {
      setTestMsg('❌ ' + (e?.message || String(e)));
    } finally { setFetching(false); }
  };

  const onSave = async () => {
    if (!user?.id) return;
    if (!name.trim()) { SafeAlert.alert('请填写名称'); return; }
    if (!baseUrl.trim()) { SafeAlert.alert('请填写 base_url'); return; }
    if (!editing && !apiKey.trim()) { SafeAlert.alert('请填写 API key'); return; }
    if (!modelName.trim()) { SafeAlert.alert('请填写模型名'); return; }
    setSaving(true);
    try {
      await byokApi.upsert({
        user_id:user.id, provider, display_name:name.trim(),
        base_url: baseUrl.trim().replace(/\/+$/,''), api_key: apiKey.trim(),
        model_name:modelName.trim(), is_default: editing?.is_default ?? 0,
        ...(editing ? { id: editing.id } : {}),
      });
      onSaved();
    } catch(e:any) {
      SafeAlert.alert('保存失败', e?.message || String(e));
    } finally { setSaving(false); }
  };

  const onTest = async () => {
    if (!user?.id) return;
    if (!baseUrl.trim() || !modelName.trim() || !apiKey.trim()) {
      setTestMsg('测试需先填 base_url、模型名和 key'); return;
    }
    setTesting(true); setTestMsg('');
    try {
      const r = await byokApi.test({ user_id:user.id, base_url:baseUrl.trim().replace(/\/+$/,''), api_key:apiKey.trim(), model_name:modelName.trim(), provider });
      if (r.ok) setTestMsg('✅ 连通正常 ('+r.status+')');
      else setTestMsg('❌ '+(r.message || ('HTTP '+r.status)));
    } catch(e:any) {
      setTestMsg('❌ '+ (e?.message || String(e)));
    } finally { setTesting(false); }
  };

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <KeyboardAvoidingView behavior={Platform.OS==='ios'?'padding':undefined} style={{flex:1}} keyboardVerticalOffset={Platform.OS==='ios'?60:0}>
        <View style={[styles.modalOverlay, {backgroundColor:'rgba(0,0,0,0.45)'}]}>
          <ScrollView contentContainerStyle={styles.modalContent} keyboardShouldPersistTaps="handled">
            <View style={[styles.modalCard,{backgroundColor:isDark?'#1e293b':'#fff'}]}>
              <Text style={[styles.modalTitle,{color:isDark?'#f1f5f9':'#0f172a'}]}>{editing?'编辑模型':'添加模型'}</Text>

              <Text style={styles.label}>厂商</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{marginBottom:10, marginHorizontal:-4}}>
                {providers.map(p => (
                  <TouchableOpacity key={p.key} onPress={()=>onPickProvider(p.key)}
                    style={[styles.chip,{ backgroundColor: provider===p.key ? Colors.primary : (isDark?'#334155':'#f1f5f9'), borderColor: provider===p.key ? Colors.primary : 'transparent', marginRight:6 }]}>
                    <Text style={{ color: provider===p.key ? '#fff' : (isDark?'#cbd5e1':'#334155'), fontSize:12, fontWeight:'600' }}>{p.label}</Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>

              <Text style={styles.label}>显示名称</Text>
              <TextInput value={name} onChangeText={setName} placeholder="例如 我的DeepSeek" placeholderTextColor="#94a3b8"
                style={[styles.input,{color:isDark?'#f1f5f9':'#0f172a', borderColor:isDark?'#334155':'#e2e8f0', backgroundColor:isDark?'#0f172a':'#fff'}]} />

              <Text style={styles.label}>Base URL{provider==='custom'?' (OpenAI 兼容)':''}</Text>
              <TextInput value={baseUrl} onChangeText={setBaseUrl} placeholder="https://..." placeholderTextColor="#94a3b8"
                autoCapitalize="none" autoCorrect={false}
                style={[styles.input,{color:isDark?'#f1f5f9':'#0f172a', borderColor:isDark?'#334155':'#e2e8f0', backgroundColor:isDark?'#0f172a':'#fff'}]} />

              <Text style={styles.label}>API Key{editing?' (留空=沿用旧 key)':''}</Text>
              <TextInput value={apiKey} onChangeText={setApiKey} placeholder="sk-..." placeholderTextColor="#94a3b8"
                secureTextEntry autoCapitalize="none" autoCorrect={false}
                style={[styles.input,{color:isDark?'#f1f5f9':'#0f172a', borderColor:isDark?'#334155':'#e2e8f0', backgroundColor:isDark?'#0f172a':'#fff'}]} />

              <Text style={styles.label}>模型名</Text>
              <View style={{flexDirection:'row', alignItems:'center'}}>
                <TextInput value={modelName} onChangeText={setModelName} placeholder="点右侧「获取」选择" placeholderTextColor="#94a3b8"
                  autoCapitalize="none" autoCorrect={false}
                  style={[styles.input,{flex:1, marginBottom:0, color:isDark?'#f1f5f9':'#0f172a', borderColor:isDark?'#334155':'#e2e8f0', backgroundColor:isDark?'#0f172a':'#fff'}]} />
                <TouchableOpacity onPress={onFetchModels} disabled={fetching}
                  style={{marginLeft:8, paddingHorizontal:12, height:38, borderRadius:8, justifyContent:'center', alignItems:'center', flexDirection:'row', backgroundColor:isDark?'#334155':'#e2e8f0'}}>
                  {fetching
                    ? <ActivityIndicator size="small" color={Colors.primary} />
                    : <><Ionicons name="cloud-download-outline" size={15} color={isDark?'#cbd5e1':'#475569'} style={{marginRight:3}} /><Text style={{color:isDark?'#cbd5e1':'#475569', fontSize:12, fontWeight:'600'}}>获取</Text></>}
                </TouchableOpacity>
              </View>

              <View style={{flexDirection:'row', gap:8, marginTop:8}}>
                <TouchableOpacity onPress={onTest} disabled={testing} style={[styles.btn,{backgroundColor:'#10b981', flex:1, flexDirection:'row', justifyContent:'center'}]}>
                  {testing ? <ActivityIndicator color="#fff" /> : <><Ionicons name="wifi-outline" size={16} color="#fff" style={{marginRight:4}} /><Text style={{color:'#fff', fontWeight:'600'}}>测试连通</Text></>}
                </TouchableOpacity>
                <TouchableOpacity onPress={onSave} disabled={saving} style={[styles.btn,{backgroundColor:Colors.primary, flex:1, flexDirection:'row', justifyContent:'center'}]}>
                  {saving ? <ActivityIndicator color="#fff" /> : <><Ionicons name="checkmark" size={16} color="#fff" style={{marginRight:4}} /><Text style={{color:'#fff', fontWeight:'600'}}>保存</Text></>}
                </TouchableOpacity>
              </View>

              {testMsg ? <Text style={{color: testMsg.startsWith('✅')?'#10b981':'#ef4444', fontSize:12, marginTop:8, lineHeight:16}}>{testMsg}</Text> : null}

              <TouchableOpacity onPress={onClose} style={[styles.btn,{backgroundColor:'transparent', borderWidth:1, borderColor:isDark?'#334155':'#e2e8f0', marginTop:8}]}>
                <Text style={{color:isDark?'#cbd5e1':'#475569', fontWeight:'600'}}>取消</Text>
              </TouchableOpacity>
            </View>
          </ScrollView>
        </View>
      </KeyboardAvoidingView>

      {pickerOpen ? (
        <View style={[StyleSheet.absoluteFill,{backgroundColor:'rgba(0,0,0,0.5)', justifyContent:'center', padding:24}]}>
          <View style={{backgroundColor:isDark?'#1e293b':'#fff', borderRadius:14, maxHeight:'70%', overflow:'hidden'}}>
            <Text style={{padding:14, fontSize:15, fontWeight:'700', color:isDark?'#f1f5f9':'#0f172a'}}>选择模型（{models.length}）</Text>
            <FlatList data={models} keyExtractor={m=>m.id}
              renderItem={({item})=>(
                <TouchableOpacity onPress={()=>{ setModelName(item.id); setPickerOpen(false); }}
                  style={{paddingHorizontal:14, paddingVertical:11, borderTopWidth:StyleSheet.hairlineWidth, borderTopColor:isDark?'#334155':'#e2e8f0'}}>
                  <Text style={{fontSize:14, color:isDark?'#f1f5f9':'#0f172a'}} numberOfLines={1}>{item.id}</Text>
                  {item.name && item.name!==item.id ? <Text style={{fontSize:11, color:'#94a3b8', marginTop:2}} numberOfLines={1}>{item.name}</Text> : null}
                </TouchableOpacity>
              )} />
            <TouchableOpacity onPress={()=>setPickerOpen(false)}
              style={{padding:13, alignItems:'center', borderTopWidth:StyleSheet.hairlineWidth, borderTopColor:isDark?'#334155':'#e2e8f0'}}>
              <Text style={{color:'#64748b', fontWeight:'600'}}>取消</Text>
            </TouchableOpacity>
          </View>
        </View>
      ) : null}
    </Modal>
  );
}

const styles = StyleSheet.create({
  container:{ flex:1 },
  center:{ flex:1, justifyContent:'center', alignItems:'center' },
  headerCard:{ },
  headerTitle:{ fontSize:16, fontWeight:'700' },
  headerSub:{ fontSize:12, lineHeight:18 },
  addBtn:{ paddingVertical:10, borderRadius:8, alignItems:'center' },
  card:{ borderRadius:14, padding:14, marginBottom:10 },
  cardTop:{ flexDirection:'row', alignItems:'flex-start' },
  cardTitle:{ fontSize:15, fontWeight:'700' },
  cardMeta:{ fontSize:12 },
  tag:{ paddingHorizontal:6, paddingVertical:2, borderRadius:4, marginLeft:6 },
  iconBtn:{ width:34, height:34, borderRadius:17, justifyContent:'center', alignItems:'center' },
  empty:{ flex:1, justifyContent:'center', alignItems:'center', paddingVertical:60 },
  emptyText:{ fontSize:15, fontWeight:'600' },
  fab:{ position:'absolute', width:54, height:54, borderRadius:27, justifyContent:'center', alignItems:'center', elevation:6, shadowColor:'#000', shadowOpacity:0.2, shadowRadius:8, shadowOffset:{width:0,height:4} },
  modalOverlay:{ flex:1, justifyContent:'flex-end' },
  modalContent:{ padding:16, paddingBottom:32 },
  modalCard:{ borderRadius:16, padding:16 },
  modalTitle:{ fontSize:17, fontWeight:'700', marginBottom:12 },
  label:{ fontSize:12, fontWeight:'600', color:'#64748b', marginTop:8, marginBottom:4 },
  input:{ borderWidth:1, borderRadius:8, paddingHorizontal:10, paddingVertical:8, fontSize:14, marginBottom:4 },
  chip:{ paddingHorizontal:10, paddingVertical:6, borderRadius:16, borderWidth:1 },
  btn:{ paddingVertical:10, borderRadius:8, alignItems:'center' },
});
