/**
 * 头像/MinIO 文件地址归一化
 * 后端返回的头像地址多为容器内网地址 http://coze-minio:9000/opencoze/...
 * 手机/Web 外网无法访问，需转换为公网可访问的 /minio-files/ 代理路径。
 */
export function normalizeFileUrl(url?: string | null): string {
  if (!url) return '';
  const s = String(url).trim();
  if (!s) return '';
  // 已经是公网可访问地址直接返回（带签名的内网地址也要转换，见下）
  const minioMatch = s.match(/https?:\/\/[^/]+\/(opencoze\/.*)$/);
  if (minioMatch && s.includes('minio')) {
    // 内网 minio 地址（coze-minio:9000 等）→ 公网代理，去掉签名参数
    return `https://s.symsgf.xyz/minio-files/${minioMatch[1]}`.split('?')[0];
  }
  // 形如 /opencoze/... 开头的相对路径
  if (/^\/?opencoze\//.test(s)) {
    return `https://s.symsgf.xyz/minio-files/${s.replace(/^\//, '')}`.split('?')[0];
  }
  return s;
}
