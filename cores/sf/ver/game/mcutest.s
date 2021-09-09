.org 0
ljmp main

.org 0x100
main:
	mov r0,#0xff
l0:	djnz r0,l0
	mov dptr,#0xfff0
	clr  p3.0
	mov  a,#0x55
	movx @dptr,a
	mov  a,#0
	movx a,@dptr
	inc dpl
	movx @dptr,a
	setb p3.0
	clr  p3.1
	setb p3.1
lend:	sjmp lend
.end
	