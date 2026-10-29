using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

// Read-only Windows media-session metadata. No login, cookies, audio or account data.
public static class DesktopMediaState {
    static Type managerType,sessionType,mediaType;
    static object manager;
    static readonly JavaScriptSerializer json=new JavaScriptSerializer();
    static Type WinType(string name){return Type.GetType("Windows.Media.Control."+name+", Windows.Media.Control, ContentType=WindowsRuntime",true);}
    static object Await(object operation,Type resultType){
        Type extension=Type.GetType("System.WindowsRuntimeSystemExtensions, System.Runtime.WindowsRuntime, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089",true);
        foreach(MethodInfo method in extension.GetMethods()){
            if(method.Name=="AsTask"&&method.IsGenericMethodDefinition&&method.GetGenericArguments().Length==1&&method.GetParameters().Length==1){
                var task=(Task)method.MakeGenericMethod(resultType).Invoke(null,new[]{operation});
                if(!task.Wait(5000))throw new TimeoutException("Media session request timed out");
                return task.GetType().GetProperty("Result").GetValue(task,null);
            }
        }
        throw new InvalidOperationException("Windows media projection unavailable");
    }
    static object Property(object value,string name){return value.GetType().GetProperty(name).GetValue(value,null);}
    static string Provider(string source){
        source=(source??"").ToLowerInvariant();
        if(source.Contains("spotify"))return "spotify";
        if(source.Contains("qqmusic"))return "qqmusic";
        if(source.Contains("cloudmusic")||source.Contains("netease"))return "netease";
        return null;
    }
    static object Snapshot(){
        if(manager==null){
            managerType=WinType("GlobalSystemMediaTransportControlsSessionManager");
            sessionType=WinType("GlobalSystemMediaTransportControlsSession");
            mediaType=WinType("GlobalSystemMediaTransportControlsSessionMediaProperties");
            manager=Await(managerType.GetMethod("RequestAsync").Invoke(null,null),managerType);
        }
        var rows=new List<object>();
        var sessions=(IEnumerable)managerType.GetMethod("GetSessions").Invoke(manager,null);
        foreach(object session in sessions){
            string source=(string)sessionType.GetProperty("SourceAppUserModelId").GetValue(session,null),provider=Provider(source);
            if(provider==null)continue;
            try{
                object media=Await(sessionType.GetMethod("TryGetMediaPropertiesAsync").Invoke(session,null),mediaType);
                object playback=sessionType.GetMethod("GetPlaybackInfo").Invoke(session,null);
                object timeline=sessionType.GetMethod("GetTimelineProperties").Invoke(session,null);
                string state=Property(playback,"PlaybackStatus").ToString();
                rows.Add(new {provider=provider,title=(string)Property(media,"Title"),artists=(string)Property(media,"Artist"),
                    playing=state=="Playing",playbackState=state,positionSeconds=((TimeSpan)Property(timeline,"Position")).TotalSeconds,
                    durationSeconds=(((TimeSpan)Property(timeline,"EndTime"))-((TimeSpan)Property(timeline,"StartTime"))).TotalSeconds,
                    updatedAt=((DateTimeOffset)Property(timeline,"LastUpdatedTime")).ToUnixTimeMilliseconds(),source="windows_media_session"});
            }catch(Exception e){rows.Add(new {provider=provider,error=e.GetBaseException().GetType().Name,source="windows_media_session"});}
        }
        return new {ok=true,sessions=rows};
    }
    public static void Main(){
        Console.InputEncoding=new System.Text.UTF8Encoding(false);Console.OutputEncoding=new System.Text.UTF8Encoding(false);
        while(Console.ReadLine()!=null){
            try{Console.WriteLine(json.Serialize(Snapshot()));}
            catch(Exception e){Console.WriteLine(json.Serialize(new {ok=false,error=e.GetBaseException().GetType().Name,sessions=new object[0]}));}
        }
    }
}
