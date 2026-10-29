import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import readline from 'node:readline';
import {fileURLToPath} from 'node:url';

export const providers=[
 {id:'openai',name:'OpenAI',baseUrl:'https://api.openai.com/v1',protocol:'OpenAI',keyEnv:'OPENAI_ADMIN_KEY'},
 {id:'anthropic',name:'Anthropic',baseUrl:'https://api.anthropic.com/v1',protocol:'Anthropic',keyEnv:'ANTHROPIC_ADMIN_KEY'},
 {id:'gemini',name:'Gemini',baseUrl:'https://generativelanguage.googleapis.com/v1beta',protocol:'Gemini',keyEnv:'GEMINI_API_KEY'},
 {id:'deepseek',name:'DeepSeek',baseUrl:'https://api.deepseek.com',protocol:'OpenAI',keyEnv:'DEEPSEEK_API_KEY'},
 {id:'ark',name:'Ark / 方舟',baseUrl:'https://ark.cn-beijing.volces.com/api/v3',protocol:'OpenAI',keyEnv:'ARK_API_KEY'},
 {id:'openrouter',name:'OpenRouter',keyEnv:'OPENROUTER_API_KEY',managementKeyEnv:'OPENROUTER_MANAGEMENT_KEY'},
 {id:'siliconflow',name:'硅基流动',baseUrl:'https://api.siliconflow.cn/v1',protocol:'OpenAI',keyEnv:'SILICONFLOW_API_KEY'},
 {id:'custom',name:'自定义兼容接口',baseUrl:'',protocol:'OpenAI',keyEnv:''},
].map(p=>({...p,enabled:p.id==='ark',models:''}));
const number=x=>Number.isFinite(Number(x))?Number(x):0;
export function credentialValue(env,name){
 if(!name)return undefined;
 if(env[name]!==undefined)return env[name];
 if(process.platform==='win32'){const actual=Object.keys(env).find(key=>key.toUpperCase()===name.toUpperCase());return actual===undefined?undefined:env[actual];}
 return undefined;
}
async function* files(root){if(!fs.existsSync(root))return;for(const e of await fs.promises.readdir(root,{withFileTypes:true})){const p=path.join(root,e.name);if(e.isDirectory())yield* files(p);else if(e.name.endsWith('.jsonl'))yield p;}}
export async function codexUsage(root=process.env.CODEX_HOME||path.join(os.homedir(),'.codex')){
 const sessions=new Map();let damaged=0,seen=0;
 for(const dir of ['sessions','archived_sessions'])for await(const file of files(path.join(root,dir))){
  seen++;let id=file,usage=null;
  try{for await(const line of readline.createInterface({input:fs.createReadStream(file),crlfDelay:Infinity})){
   if(!line.includes('"token_count"')&&!line.includes('"session_meta"'))continue;
   let row;try{row=JSON.parse(line);}catch{damaged++;continue;}
   if(row.type==='session_meta'&&row.payload?.id)id=row.payload.id;
   if(row.type==='event_msg'&&row.payload?.type==='token_count'){
    const t=row.payload.info?.total_token_usage;
    if(t&&(!usage||number(t.total_tokens)>number(usage.total_tokens)))usage=t;
   }
  }}catch{damaged++;}
  if(usage&&(!sessions.has(id)||number(usage.total_tokens)>number(sessions.get(id).total_tokens)))sessions.set(id,usage);
 }
 const sum={input:0,output:0,cached:0,total:0};for(const t of sessions.values()){sum.input+=number(t.input_tokens);sum.output+=number(t.output_tokens);sum.cached+=number(t.cached_input_tokens);sum.total+=number(t.total_tokens);}
 return {source:'本机 Codex 会话累计记录',period:'本机现存记录（含归档）',...sum,sessions:sessions.size,status:damaged?'partial':sessions.size?'ok':'no_data',note:`扫描 ${seen} 个文件；${damaged} 条读取异常。缓存输入已包含在输入中；分叉继承、记录缺失可能影响累计值，不等同账户账单。`};
}
export async function opencodeUsage(dbPath=process.env.OPENCODE_DB||path.join(os.homedir(),'.local/share/opencode/opencode.db')){
 if(!fs.existsSync(dbPath))return {source:'本机 OpenCode 数据库',status:'no_data',note:'未找到数据库；可用 OPENCODE_DB 指定路径。'};
 let db;try{
  const {DatabaseSync}=await import('node:sqlite');db=new DatabaseSync(dbPath,{readOnly:true});
  const names=db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map(x=>x.name);
  if(names.includes('session_v2')){
   const t=db.prepare('SELECT COUNT(*) AS sessions, SUM(tokens_input) AS input, SUM(tokens_output) AS output, SUM(tokens_reasoning) AS reasoning, SUM(tokens_cache_read) AS cached, SUM(tokens_cache_write) AS cacheWrite FROM session_v2').get();
   return {source:'本机 OpenCode session_v2 累计记录',period:'本机现存会话',status:t.sessions?'ok':'no_data',...Object.fromEntries(Object.entries(t).map(([k,v])=>[k,number(v)])),note:'缓存与推理按数据库原字段单列，不猜测总量；会话分叉及删档可能影响累计值。'};
  }
  if(names.includes('message')){
   const t={input:0,output:0,reasoning:0,cached:0,cacheWrite:0,messages:0};
   for(const row of db.prepare('SELECT data FROM message').iterate()){const x=JSON.parse(row.data);if(x.role!=='assistant'||!x.tokens)continue;const v=x.tokens;t.messages++;t.input+=number(v.input);t.output+=number(v.output);t.reasoning+=number(v.reasoning);t.cached+=number(v.cache?.read);t.cacheWrite+=number(v.cache?.write);}
   return {source:'本机 OpenCode message 记录',period:'本机现存消息',status:t.messages?'ok':'no_data',...t,note:'缓存与推理单列；不是账户账单。'};
  }
  return {source:'本机 OpenCode 数据库',status:'unsupported',note:'数据库版本未支持，未将缺失数据当作零。'};
 }catch{return {source:'本机 OpenCode 数据库',status:'error',note:'数据库读取失败，请检查路径、版本或文件占用。'};}finally{db?.close();}
}
export async function accountUsage(p,{fetcher=fetch,env=process.env,now=Date.now()}={}){
 const base={source:`${p.name} 厂商账户接口`,provider:p.id};
 if(p.id==='openrouter'){
  const read=async(endpoint,key,parse)=>{
   if(!key)return {status:'unconfigured'};
   try{const response=await fetcher(`https://openrouter.ai/api/v1/${endpoint}`,{headers:{Authorization:`Bearer ${key}`},redirect:'error',signal:AbortSignal.timeout(15000)});
    if(!response.ok)return {status:'error',http:response.status};
    return {status:'ok',...parse((await response.json()).data)};
   }catch{return {status:'error'};}
  };
  const valid=x=>typeof x==='number'&&Number.isFinite(x);
  const [credits,keyLimit]=await Promise.all([
   read('credits',credentialValue(env,p.managementKeyEnv||'OPENROUTER_MANAGEMENT_KEY'),d=>{if(!valid(d?.total_credits)||!valid(d?.total_usage))throw Error();return {remaining:d.total_credits-d.total_usage};}),
   read('key',credentialValue(env,p.keyEnv),d=>{if(!d||!Object.hasOwn(d,'limit')||(d.limit!==null&&!valid(d.limit))||(d.limit!==null&&!valid(d.limit_remaining)))throw Error();return {limit:d.limit,remaining:d.limit===null?null:d.limit_remaining,usage:valid(d.usage)?d.usage:null,reset:d.limit_reset??null};})
  ]);
  return {...base,status:credits.status==='ok'&&keyLimit.status==='ok'?'ok':'partial',kind:'openrouter',credits,keyLimit,period:'查询时额度'};
 }
 if(['ark','gemini','custom'].includes(p.id))return {...base,status:'unsupported',note:p.id==='ark'?'Coding Plan 剩余比例见下方 Ark 卡片；不能换算成 token。':'未配置受支持的账户汇总接口；兼容推理 API 不代表支持账户用量查询。'};
 const spec=providers.find(x=>x.id===p.id);if(!spec)return {...base,status:'unsupported'};
 // Usage credentials never follow a user-edited inference URL or an HTTP redirect.
 const secret=credentialValue(env,p.keyEnv);if(!secret)return {...base,status:'unconfigured',note:'请在设置中保存查询密钥。OpenAI / Anthropic 需要管理查询权限。'};
 const start=new Date(now-7*86400000),end=new Date(now);let url,headers={Authorization:`Bearer ${secret}`};
 if(p.id==='openai'){url=new URL('https://api.openai.com/v1/organization/usage/completions');url.search=new URLSearchParams({start_time:String(Math.floor(+start/1000)),end_time:String(Math.floor(now/1000)),bucket_width:'1d',limit:'7'});}
 if(p.id==='anthropic'){url=new URL('https://api.anthropic.com/v1/organizations/usage_report/messages');url.search=new URLSearchParams({starting_at:start.toISOString(),ending_at:end.toISOString(),bucket_width:'1d',limit:'7'});headers={'x-api-key':secret,'anthropic-version':'2023-06-01'};}
 if(p.id==='deepseek')url=new URL('https://api.deepseek.com/user/balance');
 if(p.id==='siliconflow')url=new URL('https://api.siliconflow.cn/v1/user/info');
 try{
  const totals={input:0,output:0,cached:0,cacheWrite:0};const pages=new Set();
  for(let page=0;page<100;page++){
   const response=await fetcher(url,{headers,redirect:'error',signal:AbortSignal.timeout(15000)});
   if(!response.ok)return {...base,status:'error',note:`账户接口 HTTP ${response.status}；请检查管理密钥、权限和服务状态。`};
   const data=await response.json();
   if(p.id==='deepseek'){if(!Array.isArray(data.balance_infos))throw Error();return {...base,status:'ok',kind:'balance',balances:data.balance_infos.map(x=>({currency:x.currency,remaining:x.total_balance})),period:'查询时余额',note:'余额不是 token 用量。'};}
   if(p.id==='siliconflow'){if(data.data?.totalBalance==null)throw Error();return {...base,status:'ok',kind:'balance',balances:[{currency:'CNY',remaining:data.data.totalBalance}],period:'查询时余额',note:'余额不是 token 用量。'};}
   if(!Array.isArray(data.data))throw Error();
   for(const bucket of data.data)for(const r of bucket.results||[]){totals.input+=number(r.input_tokens??r.uncached_input_tokens);totals.output+=number(r.output_tokens);totals.cached+=number(r.input_cached_tokens??r.cache_read_input_tokens);totals.cacheWrite+=number(r.cache_creation?.ephemeral_1h_input_tokens)+number(r.cache_creation?.ephemeral_5m_input_tokens);}
   const next=data.next_page;if(!next&&!data.has_more)return {...base,status:'ok',kind:'tokens',period:`${start.toISOString()} 至 ${end.toISOString()}`, ...totals,note:p.id==='openai'?'缓存输入包含在输入中。':'输入为未缓存输入；缓存读取、写入单列。'};
   if(!next||pages.has(next))throw Error();pages.add(next);url.searchParams.set('page',next);
  }
  throw Error();
 }catch{return {...base,status:'error',note:'账户查询失败或响应格式不完整；未使用部分数据冒充完整用量。'};}
}
export async function run(stateDir,request=null){
 const configFile=path.join(stateDir,'providers.json');const configured=request?.providers??(fs.existsSync(configFile)?JSON.parse(fs.readFileSync(configFile,'utf8')):providers);
 const [codex,opencode,accounts]=await Promise.all([codexUsage(),opencodeUsage(),Promise.all(configured.filter(p=>p.enabled&&['openai','anthropic','openrouter','deepseek','siliconflow'].includes(p.id)).map(p=>{
  const env={...process.env};
  if(p.credentials?.key)env[p.keyEnv]=p.credentials.key;
  if(p.credentials?.managementKey)env[p.managementKeyEnv]=p.credentials.managementKey;
  return accountUsage(p,{env});
 }))]);
 const result={requestId:request?.requestId??null,at:new Date().toISOString(),local:[codex,opencode],accounts};const file=path.join(stateDir,'provider-usage.json');fs.writeFileSync(file+'.tmp',JSON.stringify(result));fs.renameSync(file+'.tmp',file);return result;
}
async function readRequest(){process.stdin.setEncoding('utf8');let input='';for await(const chunk of process.stdin){input+=chunk;if(Buffer.byteLength(input)>262144)throw Error('Request too large');}const request=JSON.parse(input);if(!Array.isArray(request.providers)||!request.requestId)throw Error('Invalid request');return request;}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 (async()=>run(process.argv[2],process.argv.includes('--credentials-stdin')?await readRequest():null))().catch(()=>{process.stderr.write('Usage query failed\n');process.exitCode=1;});
}
