import axios from 'axios';
import { Platform } from 'react-native';
import Constants from 'expo-constants';
import type { CreditBalance, CreditTransaction, ModelPricing, ActionPricing, CardRedeemResponse, ApiResponse } from '../types/api';

import { RUNTIME_BASE as API_BASE } from '../config/runtime';

// 积分服务用独立的 axios 实例，不需要 bearer/session 认证，用 user_id 做标识
const creditsClient = axios.create({
  baseURL: API_BASE,
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
});

export const creditsApi = {
  // 查询余额
  getBalance: (userId: string): Promise<CreditBalance> =>
    creditsClient.post('/token-api/api/balance', { user_id: userId }).then(r => r.data.data || r.data),

  // 消费记录
  getTransactions: (userId: string, params?: { page?: number; page_size?: number }): Promise<{ items: CreditTransaction[]; total: number }> =>
    creditsClient.get('/token-api/api/transactions', { params: { user_id: userId, ...params } }).then(r => r.data.data || r.data),

  // 模型价格表
  getModelPricing: (): Promise<ModelPricing[]> =>
    creditsClient.get('/token-api/api/pricing').then(r => r.data.data || r.data),

  // 动作价格表
  getActionPricing: (): Promise<ActionPricing[]> =>
    creditsClient.get('/token-api/api/action/pricing').then(r => r.data.data || r.data),

  // 卡密兑换
  redeemCard: (userId: string, cardCode: string): Promise<CardRedeemResponse> =>
    creditsClient.post('/token-api/api/card/redeem', { user_id: userId, card_code: cardCode }).then(r => r.data.data || r.data),

  // ============ 在线充值（网程PAY：微信/支付宝）============
  // 充值套餐列表
  getPayPlans: (): Promise<{ plans: Array<{ id: string; money: string; credits: string; label: string }> }> =>
    creditsClient.post('/token-api/api/pay/plans', {}).then(r => r.data),

  // 创建支付订单，返回跳转支付的 pay_url 和订单号
  createPay: (userId: string, plan: string, payType: 'alipay' | 'wxpay'): Promise<{ status: string; pay_url: string; out_trade_no: string }> =>
    creditsClient.post('/token-api/api/pay/create', { user_id: userId, plan, pay_type: payType }).then(r => r.data),

  // 轮询订单是否已支付到账
  getPayStatus: (outTradeNo: string): Promise<{ status: string; paid: boolean }> =>
    creditsClient.get(`/token-api/api/pay/status/${outTradeNo}`).then(r => r.data),

  // 按 token 数量扣费：每 200 token 扣 1 积分
  deductByTokens: (userId: string, totalTokens: number, modelName?: string): Promise<{
    status: string;
    cost: string;
    balance?: string;
    message?: string;
  }> => {
    const cost = Math.ceil(totalTokens / 200); // 每200 token = 1积分，向上取整
    if (cost <= 0) {
      return Promise.resolve({ status: 'ok', cost: '0', message: '无需扣费' });
    }
    return creditsClient.post('/token-api/api/deduct', {
      user_id: userId,
      total_tokens: totalTokens,
      fixed_cost: cost,
      ...(modelName ? { model_name: modelName } : {}),
    }).then(r => r.data);
  },
};
