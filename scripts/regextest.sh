#!/bin/bash
which node >/dev/null 2>&1 && echo "node ok" || echo "no node"
node - <<'JS'
const line = "做好了，公众号文章版：\n\n**📖 [CloudStream：把手机变成「无限片源」播放器 — GitHub万星开源，安卓党必装](https://s.symsgf.xyz/play/muilh1pclynn/)**\n\n**内容结构**（延续前两期的爆款模板）：";
// 模拟按行 split 后，含第一条 bold 的那一行
const lines = line.split('\n');
lines.forEach((ln,i)=>{
  const boldM = ln.match(/\*\*(.+?)\*\*/);
  const linkM = ln.match(/\[([^\]]+)\]\(([^)]+)\)/);
  console.log(`--- line${i}: ${JSON.stringify(ln.slice(0,40))}`);
  console.log('  boldM:', boldM? ('idx='+boldM.index+' inner='+JSON.stringify(boldM[1].slice(0,30))+' len='+boldM[0].length):'NULL');
  console.log('  linkM:', linkM? ('idx='+linkM.index):'NULL');
});
// 关键：整条不分行会怎样
const wholeBold = line.match(/\*\*(.+?)\*\*/);
console.log('WHOLE first bold inner head:', wholeBold? JSON.stringify(wholeBold[1].slice(0,40)):'NULL');
JS