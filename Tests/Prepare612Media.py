exec((__import__('pathlib').Path('Tests/Prepare612Core.py').read_text()).split("edit('Lib/Sensitivity.ahk'")[0])
import base64, re, wave, io, struct, math
def embedded(p, func, seconds=None):
 source=read(p)
 original=base64.b64decode(''.join(re.findall(r'data \.= "([A-Za-z0-9+/=]+)"',source)))
 with wave.open(io.BytesIO(original),'rb') as w:
  rate=w.getframerate(); raw=w.readframes(w.getnframes()); channels=w.getnchannels()
  samples=list(struct.unpack('<'+'h'*(len(raw)//2),raw))
  a=[sum(samples[i:i+channels])/(channels*32768.) for i in range(0,len(samples),channels)]
  if seconds is not None:
   count=round(seconds*rate); old=a
   a=[]
   for i in range(count):
    position=i*(len(old)-1)/max(1,count-1); left=int(position); fraction=position-left
    a.append(old[left]*(1-fraction)+old[min(left+1,len(old)-1)]*fraction)
 lo,hi=1.,100.
 for _ in range(30):
  gain=(lo+hi)/2
  rms=math.sqrt(sum((math.tanh(x*gain)*.98)**2 for x in a)/len(a))
  if rms<10**(-3.2/20): lo=gain
  else: hi=gain
 a=[math.tanh(x*((lo+hi)/2))*.98 for x in a]
 fade=min(100,len(a)//8)
 for i in range(fade): a[i]*=i/max(1,fade-1);a[-1-i]*=i/max(1,fade-1)
 out=io.BytesIO()
 with wave.open(out,'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate)
  w.writeframes(struct.pack('<'+'h'*len(a),*[round(x*32767) for x in a]))
 data=base64.b64encode(out.getvalue()).decode()
 write(p,func+'() {\n    data := ""\n'+''.join('    data .= "'+data[i:i+120]+'"\n' for i in range(0,len(data),120))+'    return data\n}\n')
 print(p,'seconds',len(a)/rate,'RMS',20*math.log10(math.sqrt(sum(x*x for x in a)/len(a))))
embedded('Lib/ScareAudio1.ahk','ScareAudio1Data',.84)
embedded('Lib/ScareAudio2.ahk','ScareAudio2Data')
embedded('Lib/SonionScream.ahk','SonionScreamData')
(r/'Ui/scare2.png').unlink(missing_ok=True)
edit('Meso_Control.ahk','HorrorVolume := SequenceVolume','ScareLocalVolume := ScareVolume()\nScareStreamVolume := ScareVolume(true)\nHorrorVolume := SequenceVolume')
edit('Meso_Control.ahk','    MesoIniWrite(SequenceVolume, ConfigFile, "Audio", "SequenceVolume")','    global ScareLocalVolume, ScareStreamVolume\n    MesoIniWrite(ScareLocalVolume, ConfigFile, "Audio", "ScareVolume")\n    MesoIniWrite(ScareStreamVolume, ConfigFile, "Audio", "ScareOutputVolume")\n    MesoIniWrite(SequenceVolume, ConfigFile, "Audio", "SequenceVolume")')
edit('Lib/Editor.ahk','    tab.UseTab(3)','    global ScareLocalVolume, ScareStreamVolume, ScareLocalSlider, ScareStreamSlider, ScareLocalLabel, ScareStreamLabel\n    tab.UseTab(3)')
s=read('Lib/Editor.ahk'); a=s.index('    tab.UseTab(3)');b=s.index('    tab.UseTab(4)',a);block=s[a:b]
for old,new in [(554,589),(503,478),(497,472),(465,448),(425,406),(417,400),(383,370),(377,364),(350,342),(312,306)]: block=block.replace('y'+str(old)+' ','y'+str(new)+' ')
block=block.replace('    for slider in [AnnouncementSlider, TtsSlider, SequenceSlider]','''    SettingsGui.AddText("x40 y517 w230 h23", "Jumpscares · Meso")
    ScareLocalLabel := SettingsGui.AddText("x548 y517 w57 h23 Right", ScareLocalVolume "%")
    ScareLocalSlider := SettingsGui.AddSlider("x635 y511 w143 h29 Range0-100 ToolTip", ScareLocalVolume)
    SettingsGui.AddText("x40 y554 w230 h23", "Jumpscares · Output")
    ScareStreamLabel := SettingsGui.AddText("x548 y554 w57 h23 Right", ScareStreamVolume "%")
    ScareStreamSlider := SettingsGui.AddSlider("x635 y548 w143 h29 Range0-100 ToolTip", ScareStreamVolume)
    for slider in [AnnouncementSlider, TtsSlider, SequenceSlider, ScareLocalSlider, ScareStreamSlider]''')
write('Lib/Editor.ahk',s[:a]+block+s[b:])
edit('Lib/Editor.ahk','    SequenceVolumeLabel.Text := SequenceSlider.Value "%"','    global ScareLocalSlider, ScareStreamSlider, ScareLocalLabel, ScareStreamLabel\n    ScareLocalLabel.Text := ScareLocalSlider.Value "%"\n    ScareStreamLabel.Text := ScareStreamSlider.Value "%"\n    SequenceVolumeLabel.Text := SequenceSlider.Value "%"')
edit('Lib/Editor.ahk','    TickVolume := TickSlider.Value','    global ScareLocalVolume, ScareStreamVolume, ScareLocalSlider, ScareStreamSlider\n    ScareLocalVolume := ScareLocalSlider.Value\n    ScareStreamVolume := ScareStreamSlider.Value\n    TickVolume := TickSlider.Value')
edit('Lib/StreamScares.ahk','            Mci("setaudio " alias " volume to 1000")','            volume := event.Name = "321.wav" || event.Name = "scare1" || event.Name = "scare2" ? ScareVolume(true)*10 : 1000\n            Mci("setaudio " alias " volume to " volume)')
edit('Lib/StreamScares.ahk','            playing := OutputSpecialSounds[event.Id]','            playing := OutputSpecialSounds[event.Id]\n            if event.Name = "321.wav" || event.Name = "scare1" || event.Name = "scare2"\n                Mci("setaudio " playing " volume to " ScareVolume(true)*10)')
edit('Meso_Stream_Output.ahk','#Include Lib\\ScareAssets.ahk','#Include Lib\\ScareAssets.ahk\n#Include Lib\\ScareLocalAudio.ahk\n#Include Lib\\EffectLabels.ahk')
edit('Meso_Stream_Output.ahk','Volume: Min(100, 1.5 *','Volume: ScareVolume(true)/100 * Min(100, 1.5 *')
edit('Meso_Stream_Output.ahk','    HorrorStarted := NowMs()','    global RuntimeDir\n    HorrorStarted := NowMs()\n    WriteAtomic(RuntimeDir "\\local-scare-onset.state", Line(NewId(), "1.wav", HorrorStarted, 15000))')
edit('Meso_Stream_Output.ahk','    FigureStarted := now','    global RuntimeDir\n    WriteAtomic(RuntimeDir "\\local-scare-onset.state", Line(NewId(), "2.wav", now, 7000))\n    FigureStarted := now')
print('Audio and asset integration prepared')
