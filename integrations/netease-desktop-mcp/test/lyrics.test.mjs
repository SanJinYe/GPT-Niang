import test from 'node:test';
import assert from 'node:assert/strict';
import { parseLrc, lyricAt, LyricsReader } from '../src/lyrics.mjs';
test('timed lyrics handle repeated stamps, fractional seconds, intro, blank interlude and seeking', () => {
  const lines = parseLrc('[ar:Test]\n[00:01.25][00:05.500]First\n[00:03.00]\n[00:10]Second');
  assert.equal(lines.length, 4);
  assert.equal(lyricAt(lines, 0).status, 'intro');
  assert.equal(lyricAt(lines, 1.3).text, 'First');
  assert.equal(lyricAt(lines, 3.1).status, 'interlude');
  assert.equal(lyricAt(lines, 11).text, 'Second');
  assert.equal(lyricAt(lines, 2).text, 'First');
  assert.equal(lyricAt(lines, null).status, 'unknown_position');
});
test('lyrics cache is per song and unavailable lyrics never reuse previous song text', async () => {
  let calls = 0;
  const reader = new LyricsReader(async url => {
    calls++;
    return { ok: true, json: async () => ({ code: 200, lrc: { lyric: url.includes('id=1&') ? '[00:00]Sample' : '' } }) };
  });
  assert.equal((await reader.current({ trackId: '1', positionSeconds: 2 })).text, 'Sample');
  await reader.current({ trackId: '1', positionSeconds: 3 });
  assert.equal(calls, 1);
  assert.equal((await reader.current({ trackId: '2', positionSeconds: 2 })).status, 'no_lyrics');
  assert.equal((await reader.current({ trackId: null, positionSeconds: 2 })).text, '');
});
