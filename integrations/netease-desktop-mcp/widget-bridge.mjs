import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const output = process.argv[2];
if (!output) throw new Error('Missing status output path');
const root = path.dirname(fileURLToPath(import.meta.url));
let client, transport, closed = false;
const publish = value => {
  const temporary = `${output}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify({ ...value, at: Date.now() }), 'utf8');
  fs.renameSync(temporary, output);
};
const close = async () => {
  if (closed) return;
  closed = true;
  try { await client?.close(); } finally { process.exit(0); }
};
process.stdin.resume();
process.stdin.on('end', close);
process.on('SIGTERM', close);
while (!closed) {
  try {
    if (!client) {
      transport = new StdioClientTransport({ command: process.execPath, args: [path.join(root, 'src/server.mjs')], stderr: 'ignore', env: {
        ...process.env, NO_PROXY:[process.env.NO_PROXY,'127.0.0.1','localhost'].filter(Boolean).join(','), NETEASE_MUSIC_PATH: 'C:\\Program Files\\NetEase\\CloudMusic\\cloudmusic.exe', NETEASE_MCP_PORT: '9223',
      } });
      client = new Client({ name: 'gpt-niang-now-playing', version: '1.0.0' });
      await client.connect(transport);
    }
    const sourcesFile=path.join(path.dirname(output),'music-sources.json');
    const settings=fs.existsSync(sourcesFile)?JSON.parse(fs.readFileSync(sourcesFile,'utf8')):{netease:true};
    const providers=['netease','qqmusic','spotify'].filter(id=>settings[id]===true);
    const result = await client.callTool({ name: 'desktop_music_get_now_playing', arguments: {providers} }, undefined, { timeout: 20000 });
    if (result.isError) throw new Error(result.content?.[0]?.text || 'MCP status failed');
    const data = result.structuredContent?.result ?? JSON.parse(result.content[0].text),state=data.selected;
    publish({connected:state?.connected??data.players.some(p=>p.connected),provider:state?.provider??null,title:state?.title??null,artists:state?.artists??null,playing:!!state?.playing,trackId:state?.trackId??null,positionSeconds:state?.positionSeconds??null,lyric:state?.lyric??null,players:data.players,error:null});
  } catch (error) {
    publish({ connected: false, playing: null, title: null, artists: null, error: error.message });
    await client?.close().catch(() => {});
    client = null;
  }
  await new Promise(resolve => setTimeout(resolve, 500));
}
