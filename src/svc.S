	.section .text, "ax"
	.global svcReturnFromException
	.type svcReturnFromException, function
	.cfi_startproc
svcReturnFromException:
	svc 0x28
	ret
	.cfi_endproc
