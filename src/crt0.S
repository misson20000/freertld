.section .text.jmp, "x"
NORELOC__filestart:
.global _start
_start:
	b start
	.word _mod_header - _start

.section .data.mod0
	.word 0, 8
.global _mod_header
_mod_header:
	.ascii "MOD0"
	.word __dynamic_start - _mod_header
	.word __bss_start - _mod_header
	.word __bss_start - _mod_header
	.word 0, 0 // eh_frame_hdr start/end
	.word 0 // runtime-generated module object offset

.section .text, "x"
.global start
start:
	cmp x0, #0
	b.ne entry_exception
	mov w19, w1

	// nintendo uses some dirty trick with
	// bl and reading x30 back out to get
	// offsets for this, but I just use adrp
	adrp x0, __bss_start
	add x0, x0, #:lo12:__bss_start
	adrp x2, __bss_end
	add x2, x2, #:lo12:__bss_end
	
	sub x2, x2, x0 // size
	mov w1, #0 // value
	bl memset

	adrp x0, _start
	add x0, x0, #:lo12:_start // should be 0, but just for consistency

	adrp x1, __dynamic_start
	add x1, x1, #:lo12:__dynamic_start
	
	//bl probe_modules // probe_modules((void*) aslr_base, (Elf64_Dyn*) &dynamic)
	//bl __nnDetailInitLibc0 // imported
	mov w0, w19
	//bl nnosInitialize
	// TODO
	svc 0x26

entry_exception:
	// check if exception_handler_enabled is set
	adrp x2, exception_handler_enabled
	ldr w2, [x2, #:lo12:exception_handler_enabled]
	cbz w2, return_f801_from_exception // f801 if not enabled
	// check for nn::os::detail::UserExceptionHandler(void)
	adrp x2, :got:_ZN2nn2os6detail20UserExceptionHandlerEv
	ldr x2, [x2, :got_lo12:_ZN2nn2os6detail20UserExceptionHandlerEv]
	cbz x2, return_f801_from_exception // f801 if it's null
	br x2 // let it deal with exception

return_f801_from_exception:
	mov x0, #0xf801
	bl svcReturnFromException
return_f801_from_exception_loop:
	b return_f801_from_exception_loop

.section .data
exception_handler_enabled:
	.word 0
