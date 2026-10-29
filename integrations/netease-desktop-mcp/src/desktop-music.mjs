import { WindowsMediaReader } from './windows-media.mjs';
import { LyricsReader } from './lyrics.mjs';
const ids=['netease','qqmusic','spotify'];
const normalize=s=>String(s??'').normalize('NFKC').toLowerCase().replace(/[^\p{L}\p{N}]/gu,'');
export function selectPlaying(players,enabled){
  return players.filter(p=>enabled.includes(p.provider)&&p.connected&&p.playing).sort((a,b)=>(b.updatedAt||0)-(a.updatedAt||0)||ids.indexOf(a.provider)-ids.indexOf(b.provider))[0]??null;
}
export function matchLyricTrack(songs,state){
  const title=normalize(state.title),artist=normalize(state.artists);
  const found=songs.filter(s=>normalize(s.name)===title&&((s.artists??[]).some(a=>normalize(a.name)===artist)||normalize((s.artists??[]).map(a=>a.name).join(''))===artist)&&(!state.durationSeconds||Math.abs(Number(s.duration)/1000-state.durationSeconds)<=3));
  return found.length===1?String(found[0].id):null;
}
export class DesktopMusic {
  constructor(netease,{reader=new WindowsMediaReader(),fetcher=fetch}={}){this.netease=netease;this.reader=reader;this.fetcher=fetcher;this.lyrics=new LyricsReader(fetcher);this.matches=new Map();}
  async snapshot(){
    let sessions=[],mediaError=null;
    try{sessions=await this.reader.read();}catch(e){mediaError=e.message;}
    const players=ids.map(provider=>{
      const s=sessions.filter(x=>x.provider===provider&&!x.error).sort((a,b)=>Number(b.playing)-Number(a.playing)||(b.updatedAt||0)-(a.updatedAt||0))[0];
      const elapsed=s?.playing&&s.updatedAt>0?Math.max(0,(Date.now()-s.updatedAt)/1000):0;
      return s?{...s,connected:true,positionSeconds:s.durationSeconds>0?Math.min(s.durationSeconds,s.positionSeconds+elapsed):null,updatedAt:Math.max(0,s.updatedAt||0)}:{provider,connected:false,playing:false,error:sessions.find(x=>x.provider===provider&&x.error)?.error||mediaError||'PLAYER_NOT_DETECTED'};
    });
    try{
      const state=await this.netease.nowPlaying();
      players[0]={...state,provider:'netease',connected:true,source:'netease_desktop_mcp',updatedAt:Math.max(0,sessions.find(s=>s.provider==='netease')?.updatedAt||0)};
    }catch(e){players[0].warning=e.message;}
    return players;
  }
  async lyric(state){
    if(state.provider==='netease'&&state.trackId)return {...await this.lyrics.current(state),source:'netease'};
    const key=[state.provider,normalize(state.title),normalize(state.artists),Math.round(state.durationSeconds||0)].join('|');
    let entry=this.matches.get(key);
    if(!entry||Date.now()>entry.expires){
      try{
        const url=new URL('https://music.163.com/api/search/get/web');url.search=new URLSearchParams({s:`${state.title} ${state.artists}`,type:'1',limit:'10'});
        const response=await this.fetcher(url,{headers:{Referer:'https://music.163.com/','User-Agent':'Mozilla/5.0'},signal:AbortSignal.timeout(5000)});
        if(!response.ok)throw new Error('LYRIC_SEARCH_UNAVAILABLE');
        const data=await response.json();entry={id:matchLyricTrack(data.result?.songs??[],state),expires:Date.now()+300000};
      }catch(e){return {status:'unavailable',text:'',error:e.message,source:'netease_match'};}
      this.matches.set(key,entry);if(this.matches.size>20)this.matches.delete(this.matches.keys().next().value);
    }
    if(!entry.id)return {status:'unknown_track',text:'',source:'netease_match'};
    return {...await this.lyrics.current({...state,trackId:entry.id}),source:'netease_match'};
  }
  async nowPlaying(enabled=ids){
    const players=await this.snapshot(),selected=selectPlaying(players,enabled);
    if(!selected)return {players,selected:null};
    const lyric=await this.lyric(selected);
    // Re-read after network work: never attach a previous track's lyric to a changed song.
    const latest=await this.snapshot(),current=selectPlaying(latest,enabled);
    if(!current||current.provider!==selected.provider||normalize(current.title)!==normalize(selected.title)||normalize(current.artists)!==normalize(selected.artists))return {players:latest,selected:current?{...current,lyric:{status:'loading',text:''}}:null};
    return {players:latest,selected:{...current,lyric:lyric.status==='ready'?await this.lyric(current):lyric}};
  }
  close(){this.reader.close();}
}
