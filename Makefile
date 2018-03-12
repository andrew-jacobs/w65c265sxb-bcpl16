
all:	bcpl.s28


bcpl.s28:	bcpl.obj
	java -classpath Dev65.jar uk.co.demon.obelisk.w65xx.Lk65 -code "0000-32767" -s28 -output bcpl.s28 *.obj	

bcpl.obj:	bcpl.asm
	java -classpath Dev65.jar uk.co.demon.obelisk.w65xx.As65 bcpl.asm

