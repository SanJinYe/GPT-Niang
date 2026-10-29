import fs from 'node:fs';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';

export class WindowsMediaReader {
  constructor(){this.child=null;this.pending=null;this.queue=Promise.resolve();}
  async read(){
    const job=this.queue.then(()=>this.readOne());this.queue=job.catch(()=>{});return job;
  }
  async readOne(){
    if(process.platform!=='win32')throw new Error('WINDOWS_MEDIA_REQUIRES_WINDOWS');
    if(!this.child){
      const root=path.dirname(fileURLToPath(import.meta.url)),output=path.join(root,'../runtime-bin/DesktopMediaState.exe'),source=path.join(root,'DesktopMediaState.cs');
      fs.mkdirSync(path.dirname(output),{recursive:true});
      if(!fs.existsSync(output)||fs.statSync(source).mtimeMs>fs.statSync(output).mtimeMs){
        const compiler=path.join(process.env.WINDIR||'C:\\Windows','Microsoft.NET/Framework64/v4.0.30319/csc.exe');
        execFileSync(compiler,['/nologo','/target:exe',`/out:${output}`,'/reference:System.Web.Extensions.dll',source],{windowsHide:true,timeout:30000,stdio:'pipe'});
      }
      const child=spawn(output,[],{windowsHide:true,stdio:['pipe','pipe','pipe']});this.child=child;
      child.stderr.resume();
      createInterface({input:child.stdout}).on('line',line=>{
        const pending=this.pending;if(!pending)return;this.pending=null;clearTimeout(pending.timer);
        try{const value=JSON.parse(line);if(!value.ok)throw new Error(`WINDOWS_MEDIA_UNAVAILABLE: ${value.error}`);pending.resolve(value.sessions);}catch(error){pending.reject(error);}
      });
      const failed=()=>{if(this.child===child)this.child=null;if(this.pending){clearTimeout(this.pending.timer);this.pending.reject(new Error('WINDOWS_MEDIA_HELPER_EXITED'));this.pending=null;}};
      child.on('error',failed);child.on('exit',failed);
    }
    return new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>{this.pending=null;this.child?.kill();this.child=null;reject(new Error('WINDOWS_MEDIA_TIMEOUT'));},12000);
      this.pending={resolve,reject,timer};this.child.stdin.write('{}\n');
    });
  }
  close(){this.child?.stdin.end();this.child=null;}
}
