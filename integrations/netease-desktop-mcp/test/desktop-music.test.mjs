import test from 'node:test';
import assert from 'node:assert/strict';
import {DesktopMusic,selectPlaying,matchLyricTrack} from '../src/desktop-music.mjs';
test('only checked playing sources selected, paused and unchecked sources excluded',()=>{
 const players=[{provider:'netease',connected:true,playing:true,updatedAt:20},{provider:'spotify',connected:true,playing:true,updatedAt:30}];
 assert.equal(selectPlaying(players,['netease']).provider,'netease');assert.equal(selectPlaying(players,[]),null);
 assert.equal(selectPlaying(players,['netease','spotify']).provider,'spotify');players[1].playing=false;assert.equal(selectPlaying(players,['spotify']),null);
});
test('cross-provider lyrics require unique title artist and duration match',()=>{
 const song={id:1,name:'Song',artists:[{name:'Artist'}],duration:100000},state={title:'Song',artists:'Artist',durationSeconds:100};
 assert.equal(matchLyricTrack([song],state),'1');assert.equal(matchLyricTrack([song,song],state),null);
 assert.equal(matchLyricTrack([song],{...state,artists:'Other'}),null);assert.equal(matchLyricTrack([song],{...state,durationSeconds:110}),null);
});
test('SMTC supports QQ without NetEase and unknown position is explicit',async()=>{
 const reader={read:async()=>[{provider:'qqmusic',title:'Song',artists:'Artist',playing:true,positionSeconds:0,durationSeconds:0}],close(){}};
 const music=new DesktopMusic({nowPlaying:async()=>{throw Error('OFFLINE')}},{reader});
 const players=await music.snapshot();assert.equal(players[1].connected,true);assert.equal(players[1].positionSeconds,null);
 assert.equal((await music.nowPlaying([])).selected,null);
});
test('song change during lyric fetch cannot return old lyrics',async()=>{
 let n=0;const reader={read:async()=>[{provider:'spotify',title:++n===1?'One':'Two',artists:'Artist',playing:true,durationSeconds:100,positionSeconds:10}],close(){}};
 const music=new DesktopMusic({nowPlaying:async()=>{throw Error('OFFLINE')}},{reader});music.lyric=async()=>({status:'ready',text:'Old line'});
 const result=await music.nowPlaying(['spotify']);assert.equal(result.selected.title,'Two');assert.equal(result.selected.lyric.status,'loading');assert.equal(result.selected.lyric.text,'');
});
