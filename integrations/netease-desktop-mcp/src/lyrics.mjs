export function parseLrc(value) {
  const lines = [];
  for (const raw of String(value ?? '').split(/\r?\n/)) {
    const stamps = [...raw.matchAll(/\[(\d{1,3}):([0-5]\d)(?:[.:](\d{1,3}))?\]/g)];
    const text = raw.replace(/\[[^\]]*\]/g, '').trim();
    for (const m of stamps) lines.push({ at: Number(m[1]) * 60 + Number(m[2]) + Number(`0.${m[3] || 0}`), text });
  }
  return lines.sort((a, b) => a.at - b.at);
}
export function lyricAt(lines, seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return { status: 'unknown_position', text: '' };
  if (!lines.length) return { status: 'no_lyrics', text: '' };
  let low = 0, high = lines.length;
  while (low < high) { const mid = (low + high) >>> 1; if (lines[mid].at <= seconds) low = mid + 1; else high = mid; }
  if (!low) return { status: 'intro', text: '' };
  const line = lines[low - 1];
  return { status: line.text ? 'ready' : 'interlude', text: line.text, lineAt: line.at };
}
export class LyricsReader {
  constructor(fetcher = fetch) { this.fetcher = fetcher; this.cache = new Map(); }
  async current(state) {
    const id = String(state.trackId ?? '');
    if (!/^\d+$/.test(id)) return { status: 'unknown_track', text: '' };
    let entry = this.cache.get(id);
    if (!entry || entry.retryAt && Date.now() >= entry.retryAt) {
      try {
        const response = await this.fetcher(`https://music.163.com/api/song/lyric?id=${id}&lv=-1`, {
          headers: { Referer: 'https://music.163.com/', 'User-Agent': 'Mozilla/5.0' }, signal: AbortSignal.timeout(5000),
        });
        if (!response.ok) throw new Error(`Lyrics HTTP ${response.status}`);
        const data = await response.json();
        if (data.code !== 200) throw new Error('Lyrics response unavailable');
        entry = { lines: parseLrc(data.lrc?.lyric) };
      } catch (error) { entry = { error: error.message, retryAt: Date.now() + 30000 }; }
      this.cache.set(id, entry);
      if (this.cache.size > 8) this.cache.delete(this.cache.keys().next().value);
    }
    if (entry.error) return { status: 'unavailable', text: '', error: entry.error };
    return { ...lyricAt(entry.lines, state.positionSeconds), trackId: id };
  }
}
