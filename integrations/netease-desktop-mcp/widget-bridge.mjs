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
        ...process.env, NETEASE_MUSIC_PATH: 'C:\\Program Files\\NetEase\\CloudMusic\\cloudmusic.exe', NETEASE_MCP_PORT: '9223',
      } });
      client = new Client({ name: 'gpt-niang-now-playing', version: '1.0.0' });
      await client.connect(transport);
    }
    const result = await client.callTool({ name: 'netease_get_now_playing', arguments: {} }, undefined, { timeout: 12000 });
    if (result.isError) throw new Error(result.content?.[0]?.text || 'MCP status failed');
    const state = result.structuredContent?.result ?? JSON.parse(result.content[0].text);
    publish({ connected: true, title: state.title, artists: state.artists, playing: state.playing, trackId: state.trackId, positionSeconds: state.positionSeconds, lyric: state.lyric, error: null });
  } catch (error) {
    publish({ connected: false, playing: null, title: null, artists: null, error: error.message });
    await client?.close().catch(() => {});
    client = null;
  }
  await new Promise(resolve => setTimeout(resolve, 500));
}
