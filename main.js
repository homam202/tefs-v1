import {BleClient} from '@capacitor-community/bluetooth-le';
import {Capacitor} from '@capacitor/core';
import {Share} from '@capacitor/share';

const $=id=>document.getElementById(id),UART='6e400001-b5a0-f393-e0a9-e50e24dcca9e',TXC='6e400003-b5a0-f393-e0a9-e50e24dcca9e';
const T={
ar:{scan:'مسح مباشر',v3:'ثلاثي الأبعاد',ana:'تحليل',ble:'بلوتوث',files:'الملفات',set:'الإعدادات',connect:'اتصال',sim:'محاكاة',cal:'معايرة',base:'خط الأساس',sig:'قيمة الإشارة',width:'العرض',length:'الطول',step:'خطوة النبضة',pulses:'عدد النبضات',start:'البداية',left:'يسار',right:'يمين',pat:'النمط',zig:'متعرج',par:'متوازٍ',res:'الدقة',thr:'العتبة',auto:'تلقائي كل',rec:'تسجيل',undo:'تراجع',new:'جديد',save:'حفظ',line:'الخط',vol:'حجمي',grid:'جدول القيم',fp:'إزالة الأهداف الكاذبة',ec:'تصحيح الأخطاء',cf:'تصفية الألوان',sat:'التشبع',dref:'عمق مرجعي',targets:'الأهداف',note:'العمق تقديري ويحتاج معايرة بهدف معلوم',imp:'استيراد',lang:'اللغة',metal:'معدن',void:'فراغ',none:'لا شيء',open:'فتح',ren:'تسمية',shr:'مشاركة',del:'حذف',s0:'تربة جافة',s1:'جيرية',s2:'صخرية',s3:'طينية',s4:'رمل جاف',s5:'سطح خرساني',conn:'متصل',disc:'غير متصل',noF:'لا ملفات',at:'عند'},
en:{scan:'Live Scan',v3:'3D Scan',ana:'Analysis',ble:'Bluetooth',files:'Files',set:'Settings',connect:'Connect',sim:'Simulate',cal:'Calibrate',base:'Base value',sig:'Signal',width:'Width',length:'Length',step:'Pulse step',pulses:'Pulse count',start:'Start',left:'Left',right:'Right',pat:'Pattern',zig:'Zigzag',par:'Parallel',res:'Resolution',thr:'Threshold',auto:'Auto every',rec:'Record',undo:'Undo',new:'New',save:'Save',line:'Line',vol:'Volumetric',grid:'Values grid',fp:'Remove false targets',ec:'Error correction',cf:'Color filter',sat:'Saturation',dref:'Ref. depth',targets:'Targets',note:'Depth is an estimate; calibrate with a known target',imp:'Import',lang:'Language',metal:'Metal',void:'Void',none:'None',open:'Open',ren:'Rename',shr:'Share',del:'Delete',s0:'Dry soil',s1:'Calcareous',s2:'Rocky',s3:'Clay',s4:'Dry sand',s5:'Concrete',conn:'Connected',disc:'Disconnected',noF:'No files',at:'at'},
fr:{scan:'Scan direct',v3:'Scan 3D',ana:'Analyse',ble:'Bluetooth',files:'Fichiers',set:'Réglages',connect:'Connecter',sim:'Simuler',cal:'Calibrer',base:'Valeur de base',sig:'Signal',width:'Largeur',length:'Longueur',step:'Pas',pulses:'Impulsions',start:'Départ',left:'Gauche',right:'Droite',pat:'Motif',zig:'Zigzag',par:'Parallèle',res:'Résolution',thr:'Seuil',auto:'Auto chaque',rec:'Enregistrer',undo:'Annuler',new:'Nouveau',save:'Sauver',line:'Ligne',vol:'Volumétrique',grid:'Grille',fp:'Retirer fausses cibles',ec:'Correction erreurs',cf:'Filtre couleur',sat:'Saturation',dref:'Prof. réf.',targets:'Cibles',note:'Profondeur estimée ; calibrer avec une cible connue',imp:'Importer',lang:'Langue',metal:'Métal',void:'Vide',none:'Aucun',open:'Ouvrir',ren:'Renommer',shr:'Partager',del:'Suppr.',s0:'Sol sec',s1:'Calcaire',s2:'Rocheux',s3:'Argile',s4:'Sable sec',s5:'Béton',conn:'Connecté',disc:'Déconnecté',noF:'Aucun fichier',at:'à'}};
let L='ar',tab='scan',S={cols:10,rows:10,data:[],idx:0,path:[],buf:[],base:0,soil:0,v3:0,sim:null,ok:0};
const t=k=>T[L][k]||k,avg=a=>a.reduce((s,v)=>s+v,0)/(a.length||1);
const TABS=['scan','3d','ana','ble','files','set'],TK={scan:'scan','3d':'v3',ana:'ana',ble:'ble',files:'files',set:'set'};


const X=`soilT|التربة|Soil|Sol
snd|صوت|Sound|Son
sm|التقاط ذكي عند الثبات|Smart capture (when steady)|Capture auto (stable)
vb|اهتزاز|Vibrate|Vibration
stab|الثبات|Steadiness|Stabilité
surf|سطح 3D|3D surface|Surface 3D
heat|خريطة حرارية|Heatmap|Carte thermique
lay|طبقات العمق|Depth layers|Couches
pal|الألوان|Palette|Palette
rev|عكس|Reverse|Inverser
hmt|إخفاء المعادن|Hide metals|Masquer métaux
hvd|إخفاء الفراغات|Hide voids|Masquer vides
wf|شبكي|Wireframe|Filaire
top|علوي|Top|Dessus
front|أمامي|Front|Face
side|جانبي|Side|Côté
ang|مائل|Angled|Incliné
arot|دوران تلقائي|Auto-rotate|Rotation auto
interp|استيفاء|Interpolation|Interpolation
clr|مسح الكل|Clear all|Tout effacer
smod|حفظ نسخة معدلة|Save modified copy|Sauver copie modifiée
applied|الفلاتر المطبقة|Applied filters|Filtres appliqués
health|صحة المسح|Scan health|Santé du scan
mod|(معدّل)|(modified)|(modifié)
f_despike|إزالة النتوءات|Despike|Dépointage
f_destripe|إزالة الخطوط|Destripe|Dé-striage
f_bg|إزالة الخلفية|Background removal|Retrait du fond
f_smooth|تنعيم|Smooth|Lissage
f_bilat|حفظ الحواف|Edge-preserving|Préserve les bords
f_analytic|إشارة تحليلية|Analytic signal|Signal analytique
f_d2|مشتقة ثانية|2nd derivative|Dérivée 2e
f_up|استمرار علوي|Upward continuation|Prolongement haut
p_mag|افتراضي|Default|Défaut
p_jet|Jet|Jet|Jet
p_hot|Hot|Hot|Hot
p_vir|Viridis|Viridis|Viridis
p_rb|قوس قزح|Rainbow|Arc-en-ciel
p_el|Electric|Electric|Electric
rock|صخر|Rock|Roche
moist|رطوبة|Moisture|Humidité
shape_linear|خطي|Linear|Linéaire
shape_planar|مسطح|Planar|Planaire
shape_compact|مدمج|Compact|Compact
rel|موثوق|Reliable|Fiable
pos|محتمل|Possible|Possible
unc|غير مؤكد|Uncertain|Incertain
edge|حافة المسح مقطوعة|Scan edge cut|Bord coupé
lowres|دون دقة المسح|Below resolution|Sous la résolution
dist|توزيع الفئات|Class distribution|Répartition
m1|تغطية الشبكة|Grid coverage|Couverture
m2|إشارة بلا تشبع|Saturation-free|Sans saturation
m3|نقاء الإشارة|Signal purity|Pureté du signal
m4|تماسك الخطوط|Line coherence|Cohérence des lignes
m5|ثبات الخلفية|Background stability|Stabilité du fond
m6|الدعم المكاني|Spatial support|Support spatial
vE|ممتاز|Excellent|Excellent
vG|جيد|Good|Bon
vF|مقبول|Fair|Passable
vP|ضعيف – أعد المسح|Poor – rescan|Faible – refaire
dg0|كل المقاييس سليمة|All metrics healthy|Tout est sain
dg1|خلايا غير ممسوحة: |Unscanned cells: |Cellules non scannées : 
dg2|قيم مشبعة: |Saturated readings: |Valeurs saturées : 
dg3|ضوضاء نبضية عالية، جرّب إزالة النتوءات|High impulse noise, try Despike|Bruit impulsionnel, essayez Dépointage
dg4|خطوط بين الصفوف، جرّب إزالة الخطوط|Line striping, try Destripe|Stries, essayez Dé-striage
dg5|انجراف الخلفية، جرّب إزالة الخلفية|Background drift, try Background removal|Dérive du fond, essayez Retrait du fond
dg6|الخطوة كبيرة (>40 سم)|Coarse step (>40 cm)|Pas grossier (>40 cm)
sname|اسم المسح|Scan name|Nom du scan
info|تفاصيل|Details|Détails
badf|ملف غير صالح|Invalid file|Fichier invalide
pngweb|حفظ الصورة متاح في المتصفح فقط|PNG export works in browser only|Export PNG : navigateur seulement
devs|أجهزة قريبة|Nearby devices|Appareils proches
scand|بحث|Search|Rechercher
dcn|قطع الاتصال|Disconnect|Déconnecter
theme|المظهر|Theme|Thème
dark|داكن|Dark|Sombre
light|فاتح|Light|Clair
qE|ممتازة|Excellent|Excellente
qG|جيدة|Good|Bonne
qM|متوسطة|Medium|Moyenne
qW|ضعيفة|Weak|Faible
qP|سيئة|Poor|Mauvaise
png|صورة PNG|PNG image|Image PNG
v3d|ملف V3D|V3D file|Fichier V3D
ls|طبقة سطحية|Surface layer|Couche surface
lm|طبقة متوسطة|Middle layer|Couche moyenne
ld|طبقة عميقة|Deep layer|Couche profonde
4d|4D|4D|4D
fs|قوة المجال|Field strength|Force du champ
dfa|عامل العمق|Depth factor|Facteur de profondeur
nsh|أغلفة متداخلة|Nested shells|Enveloppes
clp|حاجز القطع|Clip barrier|Barrière
sol|حجم مصمت|Solid|Plein
frm|إطار المكعب|Cube frame|Cadre
bgg|شبكة الخلفية|Background grid|Grille
n4|نموذج تفسيري تقريبي للحقل مع العمق، وليس قياساً مباشراً|Interpretive depth model, not a direct measurement|Modèle interprétatif, pas une mesure directe`;
X.split('\n').forEach(l=>{const [k,a,e,f]=l.split('|');T.ar[k]=a;T.en[k]=e;T.fr[k]=f});
const SOILS=`dry|تربة جافة|Dry soil|Sol sec|1
dsand|رمل جاف|Dry sand|Sable sec|.8
wsand|رمل رطب|Damp sand|Sable humide|.9
calc|جيرية|Calcareous|Calcaire|.9
rock|صخرية|Rocky|Rocheux|1.3
clay|طينية|Clay|Argile|1.2
wclay|طين رطب|Wet clay|Argile humide|1.4
silt|غرينية|Silt|Limon|1.1
grav|حصوية|Gravel|Gravier|1.1
gran|غرانيتية|Granite|Granit|1.3
bas|بازلتية|Basaltic|Basaltique|1.5
org|عضوية|Organic|Organique|1
sal|مالحة|Saline|Salin|1.4
wet|رطبة|Wet soil|Sol humide|1.3
conc|سطح خرساني|Concrete|Béton|1.5
ash|رماد بركاني|Volcanic ash|Cendre volcanique|1.2`,SOK=[],SK=[];
SOILS.split('\n').forEach(l=>{const [k,a,e,f,x]=l.split('|');T.ar['so_'+k]=a;T.en['so_'+k]=e;T.fr['so_'+k]=f;SOK.push(k);SK.push(+x)});
const PAL={mag:[[0,[20,40,160]],[.35,[0,190,200]],[.5,[40,200,90]],[.75,[250,220,40]],[1,[230,40,40]]],
 jet:[[0,[0,0,143]],[.125,[0,0,255]],[.375,[0,255,255]],[.625,[255,255,0]],[.875,[255,0,0]],[1,[128,0,0]]],
 hot:[[0,[10,0,0]],[.4,[230,0,0]],[.75,[255,200,0]],[1,[255,255,255]]],
 vir:[[0,[68,1,84]],[.25,[59,82,139]],[.5,[33,145,140]],[.75,[94,201,98]],[1,[253,231,37]]],
 rb:[[0,[148,0,211]],[.2,[0,0,255]],[.4,[0,255,0]],[.6,[255,255,0]],[.8,[255,127,0]],[1,[255,0,0]]],
 el:[[0,[0,0,0]],[.3,[60,0,120]],[.6,[200,0,200]],[.8,[0,220,255]],[1,[255,255,255]]]};
S.flt=[];S.pal='mag';S.tl=1;S.dev=null;S.t0=0;
let DV={},AC,lb=0,lk='';
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function beep(k){if(!k){lk='';return}const n=Date.now();if(k===lk&&n-lb<500)return;lk=k;lb=n;
 try{AC=AC||new AudioContext();const o=AC.createOscillator(),g=AC.createGain();o.frequency.value=k==='m'?900:300;o.type=k==='m'?'sine':'square';g.gain.value=.15;o.connect(g);g.connect(AC.destination);o.start();o.stop(AC.currentTime+.18)}catch(e){}}
function ui2(){$('pal').innerHTML=Object.keys(PAL).map(k=>`<option value="${k}" ${k===S.pal?'selected':''}>${t('p_'+k)}</option>`).join('');
 $('fb').innerHTML=Object.keys(FL).map(k=>`<button onclick="fadd('${k}')">${t('f_'+k)}</button>`).join('');
 $('fl2').textContent=S.flt.length?t('applied')+': '+S.flt.map(k=>t('f_'+k)).join(' › '):'';devs()}
function lang(l){L=l;document.documentElement.lang=l;document.documentElement.dir=l==='ar'?'rtl':'ltr';$('lg').value=l;
 document.querySelectorAll('[data-i]').forEach(e=>e.textContent=t(e.dataset.i));
 $('nav').innerHTML=TABS.map(k=>`<button class="${k===tab?'on':''}" onclick="go('${k}')"><svg class="i"><use href="#s-${k}"/></svg>${t(TK[k])}</button>`).join('');
 $('soil').innerHTML='<select onchange="S.soil=+this.value;draw()">'+SOK.map((k,i)=>`<option value="${i}" ${i===S.soil?'selected':''}>${t('so_'+k)}</option>`).join('')+'</select>';
 $('ttl').textContent=t(TK[tab]);ui2();status();files();draw()}
function go(k){tab=k;document.querySelectorAll('.scr').forEach(e=>e.classList.remove('on'));$('p-'+k).classList.add('on');lang(L)}
function status(){const s=S.ok?t('conn'):t('disc');$('st').textContent=$('st2').textContent=s}

// ---- scan logic ----
function mk(){S.cols=Math.max(2,Math.round(+$('w').value*100/+$('stp').value));S.rows=Math.max(2,Math.round(+$('l').value*100/+$('stp').value));
 const p=[],lr=$('sd').value==='left';for(let r=0;r<S.rows;r++){const fw=$('pt').value==='z'?((r%2===0)===lr):lr;
  for(let c=0;c<S.cols;c++)p.push([r,fw?c:S.cols-1-c])}S.path=p}
function nw(){mk();S.t0=0;S.data=Array.from({length:S.rows},()=>Array(S.cols).fill(null));S.idx=0;draw()}
function sample(m){const v=Math.hypot(m[0],m[1],m[2]);S.buf.push(v);if(S.buf.length>60)S.buf.shift();
 if(S.az&&S.buf.length>=20){cal();S.az=0}
 {const w=S.buf.slice(-10),a=avg(w),sd=Math.sqrt(w.reduce((s,x)=>s+(x-a)*(x-a),0)/w.length),tl=Math.max(3,+$('th').value*.25);
  const se=$('stab');if(se){se.textContent=sd.toFixed(1);se.style.color=sd<tl?'#3fb950':'#e5484d'}
  if(sd>tl*2)S.armed=1;
  if($('sm')&&$('sm').checked&&S.armed&&sd<tl&&w.length>=10&&Date.now()-(S.lr||0)>1200){S.armed=0;rec()}}
 const d=v-S.base,bits=+$('rs').value,top=2**bits-1;$('live').textContent=Math.round(d);
 $('sig').textContent=Math.max(0,Math.min(top,Math.round(top/2+d*top/20000)));
 const th=+$('th').value*SK[S.soil],e=$('det');
 e.textContent=d>th?t('metal'):d<-th?t('void'):t('none');e.style.background=d>th?'#e5484d':d<-th?'#3b82f6':'#2a3748';if($('snd').checked)beep(d>th?'m':d<-th?'v':'')}
function cal(){if(S.buf.length){S.base=avg(S.buf.slice(-10));$('base').textContent=Math.round(S.base)}}
function rec(){if(S.idx>=S.path.length||!S.buf.length)return;S.lr=Date.now();if($('vb')&&$('vb').checked&&navigator.vibrate)navigator.vibrate(60);if(!S.t0)S.t0=Date.now();const [r,c]=S.path[S.idx++];
 S.data[r][c]=avg(S.buf.slice(-Math.max(1,+$('pls').value)))-S.base;draw()}
function undo(){if(S.idx>0){const [r,c]=S.path[--S.idx];S.data[r][c]=null;draw()}}
let at=null;$('au').onchange=()=>{clearInterval(at);if($('au').checked)at=setInterval(rec,Math.max(1,+$('dw').value)*1000)};
['w','l','stp','sd','pt'].forEach(i=>$(i).onchange=nw);

// ---- BLE & simulator ----
let tx='';
async function conn(id){try{await BleClient.initialize({androidNeverForLocation:true});
 if(!id){const d=await BleClient.requestDevice({optionalServices:[UART]});id=d.deviceId;DV[id]=DV[id]||{n:d.name||'?',rssi:''}}
 await BleClient.connect(id,()=>{S.ok=0;S.dev=null;status();devs()});stopSim();S.dev=id;
 await BleClient.startNotifications(id,UART,TXC,v=>{tx+=new TextDecoder().decode(v);let i;
  while((i=tx.indexOf('\n'))>=0){const p=tx.slice(0,i).split(',').map(Number);tx=tx.slice(i+1);if(p.length>=3&&p.every(isFinite))sample(p);else if(p.length===1&&isFinite(p[0]))sample([50000+p[0],0,0])}});S.az=1;
 S.ok=1;status();devs()}catch(e){$('st').textContent=(e&&e.message)||String(e)}}
async function disc(){try{if(S.dev)await BleClient.disconnect(S.dev)}catch(e){}S.ok=0;S.dev=null;stopSim();status();devs()}
const q=r=>t(r>=-60?'qE':r>=-70?'qG':r>=-80?'qM':r>=-90?'qW':'qP');
function devs(){$('dv').innerHTML=Object.entries(DV).map(([id,o])=>`<div class="f"><span>${esc(o.n)}<br><small>${esc(id)}</small></span><span>${o.rssi!==''?o.rssi+' dBm · '+q(o.rssi):''}</span><button onclick="conn('${esc(id)}')">${id===S.dev?t('conn'):t('connect')}</button></div>`).join('')}
async function scanDev(){if(!Capacitor.isNativePlatform())return conn();
 try{await BleClient.initialize({androidNeverForLocation:true});DV={};devs();
  await BleClient.requestLEScan({services:[UART]},r=>{DV[r.device.deviceId]={n:r.localName||r.device.name||'?',rssi:r.rssi};devs()});
  setTimeout(()=>BleClient.stopLEScan().catch(()=>{}),8000)}catch(e){$('st').textContent=(e&&e.message)||String(e)}}
function sim(){stopSim();S.ok=1;status();S.sim=setInterval(()=>{const [r,c]=S.path[Math.min(S.idx,S.path.length-1)];
 const d2=(r-S.rows*.35)**2+(c-S.cols*.6)**2,d3=(r-S.rows*.75)**2+(c-S.cols*.25)**2;
 sample([48000+900*Math.exp(-d2/10)-500*Math.exp(-d3/6)+(Math.random()-.5)*30,0,0])},100)}
function stopSim(){clearInterval(S.sim);S.sim=null}

// ---- processing ----
const med=a=>{a=a.filter(x=>x!==null).sort((x,y)=>x-y);return a.length?a[a.length>>1]:null};
const nb=(d,r,c)=>{const o=[];for(let a=-1;a<2;a++)for(let b=-1;b<2;b++)if(d[r+a]&&d[r+a][c+b]!==undefined)o.push(d[r+a][c+b]);return o};
const mapM=(d,f)=>d.map((row,r)=>row.map((v,c)=>f(v,r,c)));
const mad=a=>{a=a.filter(x=>x!==null);const m=med(a);return 1.4826*med(a.map(x=>Math.abs(x-m)))||1};
const sol=M=>{for(let i=0;i<3;i++){let p=i;for(let j=i+1;j<3;j++)if(Math.abs(M[j][i])>Math.abs(M[p][i]))p=j;[M[i],M[p]]=[M[p],M[i]];
 for(let j=0;j<3;j++)if(j!==i){const f=M[j][i]/M[i][i];for(let k=i;k<4;k++)M[j][k]-=f*M[i][k]}}return[0,1,2].map(i=>M[i][3]/M[i][i])};
const FL={
 despike:d=>{const m=mapM(d,(v,r,c)=>med(nb(d,r,c))),df=[];mapM(d,(v,r,c)=>df.push(v-m[r][c]));const s=mad(df);return mapM(d,(v,r,c)=>Math.abs(v-m[r][c])>3*s?m[r][c]:v)},
 destripe:d=>{const g=med(d.flat());return d.map(row=>{const m=med(row)-g;return row.map(v=>v-m)})},
 bg:d=>{let n=0,sx=0,sy=0,sz=0,sxx=0,syy=0,sxy=0,sxz=0,syz=0;mapM(d,(v,y,x)=>{n++;sx+=x;sy+=y;sz+=v;sxx+=x*x;syy+=y*y;sxy+=x*y;sxz+=x*v;syz+=y*v});
  const [a,b,c]=sol([[n,sx,sy,sz],[sx,sxx,sxy,sxz],[sy,sxy,syy,syz]]);return mapM(d,(v,y,x)=>v-(a+b*x+c*y))},
 smooth:d=>mapM(d,(v,r,c)=>{let s=0,w=0;for(let a=-1;a<2;a++)for(let b=-1;b<2;b++){const x=d[r+a]&&d[r+a][c+b];if(x!==undefined){const k=(a?1:2)*(b?1:2);s+=k*x;w+=k}}return s/w}),
 bilat:d=>{const sr=2*mad(d.flat());return mapM(d,(v,r,c)=>{let s=0,w=0;for(let a=-1;a<2;a++)for(let b=-1;b<2;b++){const x=d[r+a]&&d[r+a][c+b];if(x!==undefined){const k=Math.exp(-((x-v)**2)/(2*sr*sr))*(a||b?1:2);s+=k*x;w+=k}}return s/w})},
 analytic:d=>mapM(d,(v,r,c)=>Math.hypot(((d[r][c+1]??v)-(d[r][c-1]??v))/2,(((d[r+1]||[])[c]??v)-((d[r-1]||[])[c]??v))/2)),
 d2:d=>mapM(d,(v,r,c)=>{const a=nb(d,r,c);return -(a.reduce((s,x)=>s+x,0)-v-(a.length-1)*v)}),
 up:d=>FL.smooth(FL.smooth(FL.smooth(d)))};
function applyF(d){if(!S.flt.length)return d;const nl=d.map(r=>r.map(v=>v===null)),g=med(d.flat())??0;let m=d.map(r=>r.map(v=>v===null?g:v));
 S.flt.forEach(k=>m=FL[k](m));return m.map((r,i)=>r.map((v,j)=>nl[i][j]?null:v))}
const fadd=k=>{S.flt.push(k);ui2();draw()},fundo=()=>{S.flt.pop();ui2();draw()},fclr=()=>{S.flt=[];ui2();draw()};
function proc(){let d=S.data.map(r=>r.slice());
 if($('ec').checked)d=d.map(r=>{const m=med(r);return m===null?r:r.map(v=>v===null?v:v-m)});
 if($('fp').checked){const o=d.map(r=>r.slice());for(let r=0;r<S.rows;r++)for(let c=0;c<S.cols;c++){if(d[r][c]===null)continue;const n=[];
  for(let a=-1;a<2;a++)for(let b=-1;b<2;b++)if(o[r+a]&&o[r+a][c+b]!==undefined)n.push(o[r+a][c+b]);d[r][c]=med(n)}}
 return applyF(d)}
function samp(d,u,v){const c0=Math.floor(u),r0=Math.floor(v);let w=0,s=0;
 for(let a=0;a<2;a++)for(let b=0;b<2;b++){const r=r0+a,c=c0+b;if(r>=S.rows||c>=S.cols)continue;const x=d[r][c];if(x===null)continue;
  const k=(b?u-c0:1-(u-c0))*(a?v-r0:1-(v-r0));w+=k;s+=k*x}return w>1e-6?s/w:null}
function rng(d){const a=[];d.forEach(r=>r.forEach(v=>{if(v!==null)a.push(v)}));return a.length?[Math.min(...a),Math.max(...a),avg(a)]:[0,0,0]}
function col(v,mn,mx){let f=mx>mn?(v-mn)/(mx-mn):.5;const lo=$('c1').value/100,hi=$('c2').value/100;if(f<lo||f>hi)return'#26303c';
 const th=+$('th').value*SK[S.soil];if(($('hm').checked&&v>th)||($('hv').checked&&v<-th))return'#26303c';
 if($('rev').checked)f=1-f;const P=PAL[S.pal];let i=1;while(i<P.length-1&&f>P[i][0])i++;
 const [a,A]=P[i-1],[b,B]=P[i],u=Math.max(0,Math.min(1,(f-a)/(b-a))),c=A.map((x,j)=>x+(B[j]-x)*u),l=(c[0]+c[1]+c[2])/3,s=$('sa').value/90;
 return`rgb(${c.map(x=>Math.round(Math.max(0,Math.min(255,l+(x-l)*s)))).join(',')})`}

// ---- drawing ----
function heat(cv,d,nums){const g=cv.getContext('2d'),W=cv.width,H=cv.height,[mn,mx]=rng(d),cw=W/S.cols,ch=H/S.rows,N=+$('ip').value;g.clearRect(0,0,W,H);
 for(let r=0;r<S.rows;r++)for(let c=0;c<S.cols;c++)for(let a=0;a<N;a++)for(let b=0;b<N;b++){
  const u=Math.max(0,Math.min(S.cols-1,c+(b+.5)/N-.5)),v=Math.max(0,Math.min(S.rows-1,r+(a+.5)/N-.5)),x=samp(d,u,v);
  if(x===null)continue;g.fillStyle=col(x,mn,mx);g.fillRect(c*cw+b*cw/N,r*ch+a*ch/N,cw/N+1,ch/N+1)}
 g.strokeStyle='rgba(255,255,255,.12)';for(let i=0;i<=S.cols;i++){g.beginPath();g.moveTo(i*cw,0);g.lineTo(i*cw,H);g.stroke()}
 for(let i=0;i<=S.rows;i++){g.beginPath();g.moveTo(0,i*ch);g.lineTo(W,i*ch);g.stroke()}
 if(nums){if(S.idx<S.path.length){const [r,c]=S.path[S.idx];g.strokeStyle='#fff';g.lineWidth=3;g.strokeRect(c*cw+1,r*ch+1,cw-2,ch-2);g.lineWidth=1}
  g.fillStyle='#fff';g.font=Math.max(9,Math.min(cw,ch)*.3)+'px sans-serif';g.textAlign='center';g.textBaseline='middle';
  d.forEach((row,r)=>row.forEach((v,c)=>{if(v!==null)g.fillText(Math.round(v),c*cw+cw/2,r*ch+ch/2)}))}}
function iso(cv,d){const g=cv.getContext('2d'),W=cv.width,H=cv.height,[mn,mx]=rng(d),N=Math.round(+$('ip').value*7.5),a=$('yw').value*Math.PI/180,ca=Math.cos(a),sa=Math.sin(a),k=H*.28/((mx-mn)||1);g.clearRect(0,0,W,H);
 const P=(i,j)=>{const x=samp(d,i/N*(S.cols-1),j/N*(S.rows-1)),X=(i-N/2)/N,Y=(j-N/2)/N,rx=X*ca-Y*sa,ry=X*sa+Y*ca;
  return{x:W/2+rx*W*.7,y:H*.55+ry*W*.35*S.tl,z:x===null?null:(x-mn)*k,v:x,d:ry}};
 const q=[];for(let j=0;j<N;j++)for(let i=0;i<N;i++){const p=[P(i,j),P(i+1,j),P(i+1,j+1),P(i,j+1)];if(p.every(o=>o.z!==null))q.push(p)}
 q.sort((A,B)=>avg(A.map(o=>o.d))-avg(B.map(o=>o.d)));
 q.forEach(p=>{const cc=col(avg(p.map(o=>o.v)),mn,mx);g.fillStyle=cc;g.strokeStyle=$('wf').checked?cc:'rgba(0,0,0,.25)';g.beginPath();
  p.forEach((o,n)=>n?g.lineTo(o.x,o.y-o.z):g.moveTo(o.x,o.y-o.z));g.closePath();if(!$('wf').checked)g.fill();g.stroke()})}
function m3(m){S.v3=m;$('cv3').style.display=(m===0||m===3||m===4)?'block':'none';$('c4').style.display=m===4?'block':'none';$('grid').style.display=m===1?'grid':'none';$('lays').style.display=m===2?'block':'none';draw()}
function draw(){const raw=S.data,[mn,mx,av]=rng(raw);$('mn').textContent=Math.round(mn);$('mx').textContent=Math.round(mx);$('av').textContent=Math.round(av);
 $('ln').textContent=S.path.length?S.path[Math.min(S.idx,S.path.length-1)][0]+1:1;$('lt').textContent=S.rows;
 const d=proc();heat($('cv1'),raw,1);
 if(tab==='ana'){heat($('cv2'),d,1);targets(d)}
 if(tab==='3d'){if(S.v3===0)iso($('cv3'),d);else if(S.v3===3)heat($('cv3'),d,0);else if(S.v3===4)v4(d);else if(S.v3===2)layers(d);else gridv(d)}}
function v4(d){const cv=$('cv3'),g=cv.getContext('2d'),W=cv.width,H=cv.height;g.clearRect(0,0,W,H);
 const nz=12,df=+$('df').value/10,fs=+$('fs').value/100,N=+$('nsh').value,solid=$('sol').checked,clip=+$('clp').value/100,R=S.rows,C=S.cols;
 let cur=d.map(r=>r.map(v=>v===null?0:v));const V=[];
 for(let z=0;z<nz;z++){const w=1/(1+z*df*.35);V.push(cur.map(r=>r.map(v=>v*w)));const ps=1+Math.floor(z*df/6);for(let p=0;p<ps;p++)cur=FL.smooth(cur)}
 let vm=0;V.forEach(L=>L.forEach(r=>r.forEach(v=>{vm=Math.max(vm,Math.abs(v))})));if(!vm)return;
 const a=$('yw').value*Math.PI/180,ca=Math.cos(a),sa=Math.sin(a),p=(90-55*S.tl)*Math.PI/180,sp=Math.sin(p),cp=Math.cos(p),M=Math.max(C,R)/2,sc=W*.36,zx=.9;
 const P=(x,y,h)=>{const X=x*ca-y*sa,Y=x*sa+y*ca;return{sx:W/2+X*sc,sy:H/2-(Y*sp+h*cp)*sc,d:-Y*cp+h*sp}};
 const L0=vm*fs,sp2=vm*Math.max(.02,.95-fs)/Math.max(1,N-1),thick=sp2*.5,pts=[];
 for(let z=0;z<nz;z++)for(let r=0;r<R;r++){if(R>1&&r/(R-1)>clip)continue;for(let c=0;c<C;c++){const v=V[z][r][c],av=Math.abs(v);if(av<L0)continue;
  if(!solid){const k=Math.floor((av-L0)/sp2);if(k>=N||(av-L0)-k*sp2>thick)continue}
  const q=P((c-(C-1)/2)/M,((R-1)/2-r)/M,-z/nz*zx);q.v=v;q.al=solid?.1+.4*av/vm:.65;pts.push(q)}}
 pts.sort((A,B)=>A.d-B.d);const s=Math.max(2,sc*2/Math.max(C,R)*1.1);
 pts.forEach(o=>{g.globalAlpha=o.al;g.fillStyle=col(o.v,-vm,vm);g.fillRect(o.sx-s/2,o.sy-s/2,s,s)});g.globalAlpha=1;
 const xs=C/M/2,ys=R/M/2;
 if($('bg4').checked){g.strokeStyle='rgba(255,255,255,.12)';for(let i=0;i<=4;i++){const u=-xs+2*xs*i/4,w=-ys+2*ys*i/4;
  [[P(u,-ys,-zx),P(u,ys,-zx)],[P(-xs,w,-zx),P(xs,w,-zx)]].forEach(([A,B])=>{g.beginPath();g.moveTo(A.sx,A.sy);g.lineTo(B.sx,B.sy);g.stroke()})}}
 if($('frm').checked){g.strokeStyle='rgba(255,255,255,.4)';const cr=[];for(const hz of[0,-zx])for(const yy of[-ys,ys])for(const xx of[-xs,xs])cr.push(P(xx,yy,hz));
  [[0,1],[1,3],[3,2],[2,0],[4,5],[5,7],[7,6],[6,4],[0,4],[1,5],[2,6],[3,7]].forEach(([i,j])=>{g.beginPath();g.moveTo(cr[i].sx,cr[i].sy);g.lineTo(cr[j].sx,cr[j].sy);g.stroke()})}}
function toast(m){const e=$('msg');e.textContent=m;e.style.display='block';clearTimeout(toast.t);toast.t=setTimeout(()=>{e.style.display='none'},3500)}
function gridv(d){const g=$('grid'),[a,b]=rng(d);g.style.gridTemplateColumns=`repeat(${S.cols},1fr)`;
 g.innerHTML=d.map(r=>r.map(v=>`<div style="background:${v===null?'#1a222d':col(v,a,b)}">${v===null?'':Math.round(v)}</div>`).join('')).join('')}
function layers(d){const f=d.map(r=>r.map(v=>v===null?0:v)),s1=FL.smooth(FL.smooth(f)),s2=FL.smooth(FL.smooth(FL.smooth(FL.smooth(s1))));
 [d,s1,s2].forEach((m,i)=>heat($('l'+i),m.map((r,y)=>r.map((v,x)=>d[y][x]===null?null:v)),0))}
function cam(y,tl){$('yw').value=y;S.tl=tl;draw()}
setInterval(()=>{if($('ar').checked&&tab==='3d'&&(S.v3===0||S.v3===4)){$('yw').value=(+$('yw').value+2)%360;draw()}},80);
function detect(d){const th=+$('th').value*SK[S.soil],sg=mad(d.flat()),seen=d.map(r=>r.map(()=>0)),out=[],st=+$('stp').value,d0=+$('d0').value,a0=+$('a0').value;
 for(let r=0;r<S.rows;r++)for(let c=0;c<S.cols;c++){if(seen[r][c]||d[r][c]===null||Math.abs(d[r][c])<=th)continue;
  const q=[[r,c]],sg2=Math.sign(d[r][c]);let pk=[r,c,d[r][c]],n=0,b=[r,r,c,c];seen[r][c]=1;
  while(q.length){const [y,x]=q.pop();n++;b=[Math.min(b[0],y),Math.max(b[1],y),Math.min(b[2],x),Math.max(b[3],x)];if(Math.abs(d[y][x])>Math.abs(pk[2]))pk=[y,x,d[y][x]];
   [[1,0],[-1,0],[0,1],[0,-1]].forEach(([a,e])=>{const Y=y+a,X=x+e;if(d[Y]&&d[Y][X]!==undefined&&d[Y][X]!==null&&!seen[Y][X]&&Math.sign(d[Y][X])===sg2&&Math.abs(d[Y][X])>th){seen[Y][X]=1;q.push([Y,X])}})}
  const len=(b[1]-b[0]+1)*st,wid=(b[3]-b[2]+1)*st,asp=Math.max(len,wid)/Math.min(len,wid),z=Math.abs(pk[2])/Math.max(th,1);
  out.push({cls:pk[2]>0?(z>=3?'metal':'rock'):(z>=2.5?'void':'moist'),r:pk[0],c:pk[1],v:pk[2],len,wid,shape:n<4?'compact':asp>2.5?'linear':n>=9?'planar':'compact',
   conf:Math.min(.99,Math.max(.5,.5+(z-1)/8+(n>1?.05:0))),depth:Math.round(d0*Math.cbrt(a0/Math.abs(pk[2]))),edge:b[0]===0||b[2]===0||b[1]===S.rows-1||b[3]===S.cols-1,low:n===1})}
 return out.sort((a,b)=>Math.abs(b.v)-Math.abs(a.v))}
function targets(d){const o=detect(d),st=+$('stp').value,cnt={};o.forEach(x=>cnt[x.cls]=(cnt[x.cls]||0)+1);
 $('tg').innerHTML=(o.length?`<label>${t('dist')}: ${Object.entries(cnt).map(([k,n])=>t(k)+' '+n).join(' · ')}</label>`:'')+o.map(x=>`<div class="f"><span>${t(x.cls)} · ${Math.round(x.v)} nT<br><small>${t('shape_'+x.shape)} ${x.len}×${x.wid} cm @ (${(x.c*st/100).toFixed(1)},${(x.r*st/100).toFixed(1)}) m${x.edge?' · '+t('edge'):''}${x.low?' · '+t('lowres'):''}</small></span><span>${Math.round(x.conf*100)}% ${t(x.conf>=.8?'rel':x.conf>=.6?'pos':'unc')}</span><span>~${x.depth} cm</span></div>`).join('')||`<label>${t('none')}</label>`;
 health(d)}
function health(d){const raw=S.data,all=raw.flat(),a=all.filter(v=>v!==null);if(a.length<4){$('hl').innerHTML='';return}
 const n=all.length,cov=a.length/n,clip=a.filter(v=>Math.abs(v)>=9990).length,m3=d.map((r,i)=>r.map((v,j)=>v===null?null:med(nb(d,i,j)))),res=[];
 d.forEach((r,i)=>r.forEach((v,j)=>{if(v!==null&&m3[i][j]!==null)res.push(v-m3[i][j])}));
 const nz=mad(res),rg=(Math.max(...a)-Math.min(...a))||1,snr=20*Math.log10(rg/(nz*6)),spk=res.filter(x=>Math.abs(x)>5*nz).length/(res.length||1),
  rm=raw.map(r=>med(r)).filter(v=>v!==null),coh=1/(1+mad(rm)/mad(a)),g=med(a),f=raw.map(r=>r.map(v=>v===null?g:v)),b=FL.bg(f),pl=[];
 f.forEach((r,y)=>r.forEach((v,x)=>pl.push(v-b[y][x])));
 const dr=Math.max(...pl)-Math.min(...pl),stab=Math.max(0,1-dr/rg),span=Math.min(+$('w').value,+$('l').value),sup=Math.min(1,span/Math.max(.4,+$('d0').value/100*4)),
  sc=[cov,1-Math.min(1,clip/n*20),Math.min(1,Math.max(0,snr/30)),coh,stab,sup],ov=avg(sc),vd=ov>=.85?'vE':ov>=.7?'vG':ov>=.5?'vF':'vP',dg=[];
 if(cov<.98)dg.push(t('dg1')+(n-a.length));if(clip)dg.push(t('dg2')+clip);if(spk>.02)dg.push(t('dg3'));if(coh<.7)dg.push(t('dg4'));if(stab<.6)dg.push(t('dg5'));if(+$('stp').value>40)dg.push(t('dg6'));if(!dg.length)dg.push(t('dg0'));
 $('hl').innerHTML=`<div class="r"><span class="big">${Math.round(ov*100)}%</span><b>${t(vd)}</b></div>`+sc.map((s,i)=>`<div class="f"><span>${t('m'+(i+1))}</span><span style="flex:2"><div style="background:#2a3748;border-radius:4px"><div style="width:${Math.round(s*100)}%;background:var(--ac);height:8px;border-radius:4px"></div></div></span><span>${Math.round(s*100)}%</span></div>`).join('')+dg.map(x=>`<label>• ${x}</label>`).join('<br>')}

// ---- files ----
const getF=()=>{try{return JSON.parse(localStorage.getItem('rmf')||'[]')}catch(e){return[]}},setF=a=>{try{localStorage.setItem('rmf',JSON.stringify(a))}catch(e){toast('storage')}};
const pack=()=>({cols:S.cols,rows:S.rows,base:S.base,idx:S.idx,soil:S.soil,w:+$('w').value,l:+$('l').value,stp:+$('stp').value,data:S.data});
function thumb(d){try{const c=document.createElement('canvas');c.width=c.height=96;const sv=[S.rows,S.cols];S.rows=d.length;S.cols=d[0].length;
 try{heat(c,d,0)}finally{S.rows=sv[0];S.cols=sv[1]}return c.toDataURL('image/jpeg',.6)}catch(e){return''}}
function save(){const n=$('sn').value.trim();$('sn').value='';const f=getF();
 f.push({id:Date.now(),name:n||new Date().toLocaleString(),d:Object.assign(pack(),{pat:$('pt').value,sd:$('sd').value,t0:S.t0,t1:Date.now()}),th:thumb(S.data)});setF(f);files()}
function saveMod(){const x=proc(),f=getF();f.push({id:Date.now(),name:new Date().toLocaleString()+' '+t('mod'),mod:1,d:Object.assign(pack(),{data:x,pat:$('pt').value,sd:$('sd').value}),th:thumb(x)});setF(f);files()}
function files(){const f=getF().slice().reverse();$('fl').innerHTML=f.map(x=>`<div class="f">${x.th?`<img src="${x.th}" width="40" height="40" style="border-radius:6px">`:''}<span>${esc(x.name)}${x.mod?' ✎':''}</span><button onclick="op(${x.id})">${t('open')}</button><button onclick="dinfo(${x.id})">${t('info')}</button><button onclick="rn(${x.id})">${t('ren')}</button><button onclick="sh(${x.id})">${t('shr')}</button><button onclick="dl(${x.id})">${t('del')}</button></div>`).join('')||`<label>${t('noF')}</label>`}
function dinfo(id){const x=getF().find(a=>a.id===id),o=x.d,[a,b]=rng(o.data);
 toast([x.name,o.rows+'×'+o.cols,new Date(x.id).toLocaleString(),(o.pat||'-')+' / '+(o.sd||'-'),o.t0&&o.t1?Math.round((o.t1-o.t0)/1000)+' s':'','min '+Math.round(a)+' · max '+Math.round(b)].filter(Boolean).join(' · '))}
function v3d(){out('scan',JSON.stringify(Object.assign({v3d:1},pack(),{pat:$('pt').value,sd:$('sd').value})),'v3d')}
function png(){if(Capacitor.isNativePlatform())return toast(t('pngweb'));$('cv1').toBlob(b=>{const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='scan.png';a.click()})}
const theme=v=>{document.documentElement.dataset.th=v;try{localStorage.setItem('th',v)}catch(e){}};
function ld(o){if(o.pat)$('pt').value=o.pat;if(o.sd)$('sd').value=o.sd;$('w').value=o.w;$('l').value=o.l;$('stp').value=o.stp;mk();S.data=o.data;S.idx=o.idx;S.base=o.base;S.soil=o.soil||0;$('base').textContent=Math.round(o.base)}
function op(id){const x=getF().find(a=>a.id===id);if(x){ld(x.d);go('scan')}}
function rn(id){const f=getF(),x=f.find(a=>a.id===id),n=$('sn').value.trim();if(n){x.name=n;$('sn').value='';setF(f);files()}else toast(t('sname'))}
function dl(id){setF(getF().filter(a=>a.id!==id));files()}
function sh(id){const x=getF().find(a=>a.id===id);out(x.name,JSON.stringify(x),'json')}
function out(name,text,ext){if(Capacitor.isNativePlatform())return Share.share({title:name,text,dialogTitle:name}).catch(()=>{});
 const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([text]));a.download=name.replace(/\W+/g,'_')+'.'+ext;a.click()}
function imp(i){const fl=i.files[0];if(!fl)return;const r=new FileReader();r.onload=()=>{try{let o;
 if(/\.csv$/i.test(fl.name)){const m=r.result.trim().split(/\r?\n/).map(l=>l.split(',').map(x=>x.trim()===''?null:+x));o={cols:m[0].length,rows:m.length,base:0,idx:m.length*m[0].length,soil:0,w:m[0].length*.5,l:m.length*.5,stp:50,data:m}}
 else{o=JSON.parse(r.result);if(o.d)o=o.d}
 if(!o.data)throw 0;const f=getF();f.push({id:Date.now(),name:fl.name,d:o,th:thumb(o.data)});setF(f);files()}catch(e){toast(t('badf'))}};r.readAsText(fl)}
function csv(){out('scan',S.data.map(r=>r.map(v=>v===null?'':v.toFixed(1)).join(',')).join('\n'),'csv')}

function setSoil(i){S.soil=i;lang(L)}
Object.assign(window,{conn,disc,scanDev,sim,cal,rec,undo,nw,save,saveMod,m3,cam,draw,go,lang,op,rn,sh,dl,dinfo,imp,csv,v3d,png,theme,fadd,fundo,fclr,setSoil,S});
let th0='dark';try{th0=localStorage.getItem('th')||'dark'}catch(e){}
theme(th0);$('thm').value=th0;
mk();nw();lang('ar');
