
all:	bcpl.s28

clean:
	rm *.s28 *.obj


bcpl.s28:	bcpl.obj
	java -classpath Dev65.jar uk.co.demon.obelisk.w65xx.Lk65 -bss "\$$0200-\$$003ff" -code "\$$0400-\$$ffff" -s28 -output bcpl.s28 *.obj	

bcpl.obj:	bcpl.asm
	java -classpath Dev65.jar uk.co.demon.obelisk.w65xx.As65 bcpl.asm

