
all:	bcpl.s28


bcpl.s28:	bcpl.obj
	java -classpath Dev65.jar uk.co.demon.obelisk.w65xx.Lk65 -bss "512-1023" -code "1024-32767" -s28 -output bcpl.s28 *.obj	

bcpl.obj:	bcpl.asm
	java -classpath Dev65.jar uk.co.demon.obelisk.w65xx.As65 bcpl.asm

