//
//
//

GET "HOSTHDR"

MANIFEST $(
	UIFR = #XDF48
$)

LET DELAY (MSEC) BE
$(
    LET START = TICKS ()
    $(
	IF (TICKS () - START) > MSEC DO RETURN
    $) REPEAT
$)

AND UARTSR (UART) = UART!TABLE #XDF70, #XDF72, #XDF74, #XDF76

AND UARTDR (UART) = UART!TABLE #XDF71, #XDF73, #XDF75, #XDF77

AND UARTTX (UART, DATA) BE
$(
    $(
	IF RDHOST(UIFR) & (UART!TABLE #x20,#x40,#x60,#x80) DO
	$(
	    WRHOST (UARTDR (UART), DATA)
	    RETURN
	$)
    $) REPEAT
$)

AND UARTRX (UART) = VALOF
$(
    RESULTIS RDHOST (UARTDR (UART))
$)
