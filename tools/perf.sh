#!/bin/bash
# Misura FPS sulla Fire TV. Uso: bash tools/perf.sh build  |  bash tools/perf.sh run [secondi]
# Il gioco stampa "PERF fps=..." solo se esiste user://perf.txt (lo crea questo script).
A=/c/Users/simon/AppData/Local/Android/Sdk/platform-tools/adb.exe
T=192.168.1.59:5555
P=com.buzz.quizparty
G="/c/Users/simon/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
cd /c/react/BUZZ
timeout 20 $A connect $T > /dev/null
if [ "$1" = build ]; then
  export JAVA_HOME="/c/Program Files/Microsoft/jdk-17.0.20.101-hotspot"
  timeout 300 "$G" --headless --path . --export-debug "Android" export/buzz-debug.apk 2>&1 | grep -iE "error" | grep -v "resources still" | head -5
  timeout 20 $A connect $T > /dev/null; timeout 120 $A -s $T install -r export/buzz-debug.apk | tail -1
  exit
fi
timeout 10 $A -s $T shell am force-stop $P
timeout 10 $A -s $T shell "run-as $P rm -f files/perf.txt"
timeout 10 $A -s $T shell "run-as $P sh -c 'mkdir -p files; echo on > files/perf.txt'"
timeout 10 $A -s $T logcat -c
timeout 10 $A -s $T shell monkey -p $P 1 > /dev/null
(sleep 15; timeout 10 $A -s $T shell "dumpsys meminfo $P" | grep -E "GL mtrack|TOTAL PSS|TOTAL  " | head -2) &
timeout ${2:-40} $A -s $T logcat -s godot:I 2>/dev/null | grep PERF
wait
timeout 10 $A -s $T shell "dumpsys meminfo $P | grep -E 'GL mtrack|TOTAL '" | head -2
timeout 10 $A -s $T shell am force-stop $P
timeout 10 $A -s $T shell "run-as $P rm -f files/perf.txt"
