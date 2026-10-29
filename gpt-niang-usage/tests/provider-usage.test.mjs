import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {accountUsage,codexUsage,opencodeUsage,providers} from '../runtime/provider-usage.mjs';
test('Windows environment credentials retain case-insensitive lookup',{skip:process.platform!=='win32'},async()=>{
 const result=await accountUsage({id:'openrouter',name:'OpenRouter',keyEnv:'REVIEW_KEY',managementKeyEnv:'REVIEW_ADMIN'},{env:{Review_Key:'fixture',review_admin:'admin-fixture'},fetcher:async(url,options)=>{
  const credit=String(url).endsWith('/credits');assert.equal(options.headers.Authorization,'Bearer '+(credit?'admin-fixture':'fixture'));
  return {ok:true,json:async()=>({data:credit?{total_credits:10,total_usage:2}:{limit:5,limit_remaining:3}})};
 }});assert.equal(result.status,'ok');assert.equal(result.keyLimit.remaining,3);
});
test('Codex cumulative snapshots and archive copies count once',async t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'niang-usage-'));t.after(()=>fs.rmSync(root,{recursive:true,force:true}));fs.mkdirSync(path.join(root,'sessions'));fs.mkdirSync(path.join(root,'archived_sessions'));
 const rows=[{type:'session_meta',payload:{id:'same'}},...[10,20,20].map(n=>({type:'event_msg',payload:{type:'token_count',info:{total_token_usage:{input_tokens:n-2,output_tokens:2,cached_input_tokens:3,total_tokens:n}}}}))].map(JSON.stringify).join('\n');
 for(const d of ['sessions','archived_sessions'])fs.writeFileSync(path.join(root,d,'x.jsonl'),rows);
 const result=await codexUsage(root);assert.equal(result.total,20);assert.equal(result.sessions,1);assert.equal(result.cached,3);
});
test('official account query paginates and does not send secrets to configured base URL',async()=>{
 const p={...providers[0],baseUrl:'https://evil.invalid'};let count=0;
 const result=await accountUsage(p,{env:{OPENAI_ADMIN_KEY:'test-only'},fetcher:async(url,options)=>{
  assert.equal(url.hostname,'api.openai.com');assert.equal(options.redirect,'error');count++;
  return {ok:true,json:async()=>({data:[{results:[{input_tokens:10,output_tokens:2,input_cached_tokens:3}]}],next_page:count===1?'next':null})};
 }});assert.equal(count,2);assert.equal(result.input,20);assert.equal(result.output,4);
});
test('missing key, HTTP failure and unsupported endpoint are not zero token results',async()=>{
 assert.equal((await accountUsage(providers[0],{env:{}})).status,'unconfigured');
 assert.equal((await accountUsage(providers[0],{env:{OPENAI_ADMIN_KEY:'test'},fetcher:async()=>({ok:false,status:403})})).status,'error');
 assert.equal((await accountUsage(providers.find(p=>p.id==='custom'))).status,'unsupported');
});
test('balance is a separate metric',async()=>{
 const result=await accountUsage(providers.find(p=>p.id==='deepseek'),{env:{DEEPSEEK_API_KEY:'test'},fetcher:async()=>({ok:true,json:async()=>({balance_infos:[{currency:'CNY',total_balance:'2.50'}]})})});
 assert.equal(result.kind,'balance');assert.equal(result.input,undefined);
});
test('OpenCode missing database is no data rather than zero',async()=>{assert.equal((await opencodeUsage(path.join(os.tmpdir(),'missing-niang-db'))).status,'no_data');});
test('OpenRouter queries credits with management key and limit with the current key',async()=>{
 const p=providers.find(p=>p.id==='openrouter');
 const r=await accountUsage(p,{env:{OPENROUTER_API_KEY:'current',OPENROUTER_MANAGEMENT_KEY:'management'},fetcher:async(url,options)=>{
  const credit=String(url).endsWith('/credits');assert.equal(options.headers.Authorization,`Bearer ${credit?'management':'current'}`);assert.equal(options.redirect,'error');
  return {ok:true,json:async()=>({data:credit?{total_credits:100,total_usage:30}:{limit:10,limit_remaining:0}})};
 }});assert.equal(r.credits.remaining,70);assert.equal(r.keyLimit.remaining,0);assert.equal(r.status,'ok');
});
test('OpenRouter missing credit permission preserves key result and unlimited is explicit',async()=>{
 const p=providers.find(p=>p.id==='openrouter');
 const r=await accountUsage(p,{env:{OPENROUTER_API_KEY:'current'},fetcher:async()=>({ok:true,json:async()=>({data:{limit:null,limit_remaining:null}})})});
 assert.equal(r.credits.status,'unconfigured');assert.equal(r.keyLimit.status,'ok');assert.equal(r.keyLimit.limit,null);assert.equal(r.status,'partial');
});
test('real worker receives saved credentials through stdin without persisting them',async t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'niang-credential-pipe-'));t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
 const fixture=path.join(root,'fetch-fixture.mjs');
 fs.writeFileSync(fixture,`globalThis.fetch=async(url,options)=>({ok:options.headers.Authorization==='Bearer fixture-only-secret',status:401,json:async()=>({data:{limit:20,limit_remaining:12}})});`);
 fs.writeFileSync(path.join(root,'providers.json'),'[]');
 const worker=fileURLToPath(new URL('../runtime/provider-usage.mjs',import.meta.url));
 const child=spawn(process.execPath,['--import',pathToFileURL(fixture).href,worker,root,'--credentials-stdin'],{windowsHide:true,env:{...process.env,CODEX_HOME:path.join(root,'codex'),OPENCODE_DB:path.join(root,'missing.db')},stdio:['pipe','pipe','pipe']});
 let output='',errors='';child.stdout.on('data',c=>output+=c);child.stderr.on('data',c=>errors+=c);
 child.stdin.end(JSON.stringify({requestId:'pipe-test',providers:[{id:'openrouter',name:'OpenRouter',enabled:true,keyEnv:'UNSET_TEST_KEY',managementKeyEnv:'UNSET_TEST_MANAGEMENT',credentials:{key:'fixture-only-secret'}}]}));
 const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve)});
 assert.equal(code,0);const text=fs.readFileSync(path.join(root,'provider-usage.json'),'utf8'),result=JSON.parse(text);
 assert.equal(result.requestId,'pipe-test');assert.equal(result.accounts[0].keyLimit.status,'ok');assert.equal(result.accounts[0].keyLimit.remaining,12);
 assert.equal((text+output+errors).includes('fixture-only-secret'),false);
});
