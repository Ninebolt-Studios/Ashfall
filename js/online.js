/* Dustline online over PeerJS — no accounts. The lobby is local-only; a match room
   runs real WebRTC: the first player on a code becomes the hub, others connect to it. */
(function(){
var ICE={ iceServers:[
  { urls:'stun:stun.l.google.com:19302' },
  { urls:'stun:stun.cloudflare.com:3478' },
  { urls:'stun:stun1.l.google.com:19302' },
  { urls:'stun:global.stun.twilio.com:3478' },
  { urls:'turn:openrelay.metered.ca:80', username:'openrelayproject', credential:'openrelayproject' },
  { urls:'turn:openrelay.metered.ca:443', username:'openrelayproject', credential:'openrelayproject' },
  { urls:'turn:openrelay.metered.ca:443?transport=tcp', username:'openrelayproject', credential:'openrelayproject' },
  { urls:'turn:relay1.expressturn.com:3478', username:'ef3XVR3GVWZ3EY7F5A', credential:'YRbFf7qQj0rHqUQ8' }
] };
function setStat(st,err){ try{ window.__dsStat={ state:st, err:err||null, t:Date.now() }; }catch(e){} }
setStat('idle');

/* Lobby: no network. Just reports this one player so the menu can say "only you". */
function stubRoom(){
  var pr={}, L=[];
  function emit(){ var s=[{peer:'me',sameTab:true,presence:pr}]; L.forEach(function(f){try{f({peers:s});}catch(e){}}); }
  return { onPeers:function(f){ L.push(f); setTimeout(emit,0); return function(){}; },
    peers:function(){ return [{peer:'me',sameTab:true,presence:pr}]; },
    presence:function(o){ pr=o||{}; return Promise.resolve(); },
    join:function(sub){ return Promise.resolve(matchRoom('dustline-'+String(sub))); },
    leave:function(){ return Promise.resolve(); } };
}

/* Match room: real PeerJS hub/peer. */
function matchRoom(hubId){
  var S={ id:null, pr:{}, L:[], peers:{}, isHub:false, peer:null, hub:null, conn:null, conns:{}, dead:false, timer:null, last:0, started:false, linked:false };
  function snap(){ var o=[{peer:S.id||'me',sameTab:true,presence:S.pr}]; for(var id in S.peers){ if(id===S.id)continue; o.push({peer:id,sameTab:false,presence:S.peers[id]||{}}); } return o; }
  function emit(){ var s=snap(); S.L.forEach(function(f){try{f({peers:s});}catch(e){}}); }
  function matched(){ if(!S.linked){ S.linked=true; setStat('matched'); } }
  function startHub(){ S.isHub=true; S.id=hubId; S.peers[S.id]=S.pr; setStat('hosting');
    S.hub.on('connection',function(c){
      c.on('open',function(){ S.conns[c.peer]=c; matched(); });
      c.on('data',function(d){ if(d&&d.t==='p'){ S.peers[c.peer]=d.pr||{}; matched(); } });
      var drop=function(){ delete S.conns[c.peer]; delete S.peers[c.peer]; emit(); };
      c.on('close',drop); c.on('error',drop);
    });
    emit();
  }
  function connectHub(){ setStat('joining'); S.peer=new Peer(undefined,{debug:0,config:ICE}); onCall(S.peer);
    S.peer.on('open',function(id){ S.id=id; S.peers[S.id]=S.pr;
      S.conn=S.peer.connect(hubId,{reliable:true,serialization:'json'});
      S.conn.on('open',function(){ setStat('server'); });
      S.conn.on('data',function(d){ if(d&&d.t==='s'&&d.s){ var keep={}; keep[S.id]=S.pr; for(var k in d.s){ if(k!==S.id)keep[k]=d.s[k]; } S.peers=keep; matched(); emit(); } });
      S.conn.on('close',function(){ reconnect(900); });
      S.conn.on('error',function(){ reconnect(1300); });
      emit();
    });
    S.peer.on('disconnected',function(){ try{S.peer.reconnect();}catch(e){} });
    S.peer.on('error',function(e){ setStat('error', e&&e.type||'peer'); reconnect(2500); });
  }
  function reconnect(ms){ if(S.dead)return; try{if(S.peer)S.peer.destroy();}catch(e){} try{if(S.hub&&S.hub!==S.peer)S.hub.destroy();}catch(e){} S.peer=null; S.hub=null; S.conn=null; S.isHub=false; S.conns={}; setTimeout(claim, ms||700); }
  function onCall(p){ try{ p.on('call',function(c){ try{ if(window.__dlOnCall) window.__dlOnCall(c); else c.close(); }catch(e){} }); }catch(e){} }
  function claim(){ if(S.dead)return; var settled=false; setStat('connecting'); S.hub=new Peer(hubId,{debug:0,config:ICE}); onCall(S.hub);
    S.hub.on('open',function(){ settled=true; S.peer=S.hub; startHub(); });
    S.hub.on('disconnected',function(){ try{S.hub.reconnect();}catch(e){} });
    S.hub.on('error',function(e){
      if(!settled && e && e.type==='unavailable-id'){ settled=true; try{S.hub.destroy();}catch(x){} connectHub(); }
      else if(!settled){ setStat('error', e&&e.type||'server'); reconnect(2500); }
    });
  }
  function ensure(){ if(S.started)return; S.started=true; if(!window.Peer){ setStat('no-webrtc'); return; } claim();
    S.timer=setInterval(function(){ if(S.dead||!S.id)return; var now=Date.now();
      if(S.isHub){ S.peers[S.id]=S.pr; var m={}; for(var id in S.peers)m[id]=S.peers[id]; for(var k in S.conns){ var c=S.conns[k]; if(c&&c.open){ try{c.send({t:'s',s:m});}catch(e){} } } emit(); }
      else if(S.conn&&S.conn.open&&(now-S.last>60)){ S.last=now; try{S.conn.send({t:'p',pr:S.pr});}catch(e){} }
    },66);
  }
  return {
    onPeers:function(f){ S.L.push(f); ensure(); setTimeout(emit,0); return function(){}; },
    peers:function(){ ensure(); return snap(); },
    presence:function(o){ S.pr=o||{}; ensure(); return Promise.resolve(); },
    join:function(sub){ return Promise.resolve(matchRoom('dustline-'+String(sub))); },
    call:function(id,stream){ try{ return S.peer&&S.id ? S.peer.call(id,stream,{metadata:{v:1}}) : null; }catch(e){ return null; } },
    leave:function(){ S.dead=true; clearInterval(S.timer); setStat('idle'); setTimeout(function(){ try{if(S.peer)S.peer.destroy();}catch(e){} },200); return Promise.resolve(); }
  };
}
window.claude={ use:function(n){ return Promise.resolve(n==='room' ? stubRoom() : null); } };
})();
