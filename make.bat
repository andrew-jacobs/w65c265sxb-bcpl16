java -classpath Dev65.jar uk.co.demon.obelisk.w65xx.As65 bcpl.asm
if errorlevel 1 pause
java -classpath Dev65.jar uk.co.demon.obelisk.w65xx.Lk65 -code $0000-$7fff -s28 -output bcpl.s28 *.obj 
if errorlevel 1 pause