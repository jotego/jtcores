.org 0
ljmp main

.org 0x100
main:
	; start-up wait
	mov r0,#0xff
l0:	djnz r0,l0

	; write 32kBytes of 0x55
	mov dptr,#0x8000
	clr  p3.0
	mov  a,#0x55
	mov  r0,#0x80
lram1:
	mov  r1,#0
lram2:
	movx @dptr,a
	inc dpl
	djnz r1,lram2
	djnz r0,lram1

	; read it back
	mov dptr,#0x8000
	mov  r0,#0x80
lram3:
	mov  r1,#0
lram4:
	movx a,@dptr
	inc dpl
	clr c
	subb  a,#0x55
	jz good
	clr  p3.7	; signal the error
good:
	djnz r1,lram4
	djnz r0,lram3

	; close the test
	setb p3.0
	clr  p3.1
	setb p3.1
lend:	sjmp lend
.end
	