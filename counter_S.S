	.data
counter:	.quad 0
GPIO:		.quad 0
	.text
	.global setup
	.global interrupt
	.global setOutput
	.global setInput
	.global setHigh
	.global setLow

interrupt:
	incq	counter
	cmpq	$16, counter
	je		lReset
lStart:
	movq	$0, %rax		# Reset rax

	movb	$4, %dil		# dil = current bit index in the number
	movl	counter, %eax
	movl	$2, %ebx
lDiv:
	movl 	$0, %edx

	divl	%ebx			# counter / 2
	#						# quotient = eax
	#						# remainder = edx

	cmpl	$0, %edx
	je		lSetZero
	# SET GPIO[dil] TO REMAINDER
	pushq	%rax			# push quotient to stack
	pushq	%rdi			# push current bit index to stack
	call	setHigh
	popq	%rdi			# pop current bit index from stack
	popq	%rax			# pop quotient from stack

	decb	%dil
	cmpb	$0, %dil
	jg		lDiv
	jmp		lEnd

lSetZero:
	pushq	%rax			# push quotient to stack
	pushq	%rdi			# push current bit index to stack
	call	setLow
	popq	%rdi			# pop current bit index from stack
	popq	%rax			# pop quotient from stack

	decb	%dil
	cmpb	$0, %dil
	jg		lDiv
lEnd:
	ret
lReset:
	movq	$0, counter
	jmp		lStart

setup:
	movl	$0x60, %esi
	movl	$0xFFFF, %edx
	movl	$0x1000, %ecx
	movl	$0x9E, %r10d
	movl	$0xFF, %r11d

	shll 	$16, %esi

	andl	%ecx, %edx		# %rdx = %rcx and %rdx
	orl 	%esi, %edx		# %rdx = %rsi or %rdx

	notl	%r10d			# %r10 = inverse of %r10
	andl	%r10d, %r11d	# %r11 = %r10 and %r11

	orl		%r11d, %edx		# %rdx = %r11 or %rdx = address to gpio
	movl	%edx, GPIO		# GPIO = address of gpio

	movb	$0, %dil
	call	setInput
	movb	$1, %dil
	call 	setOutput
	movb	$2, %dil
	call	setOutput
	movb	$3, %dil
	call	setOutput
	movb 	$4, %dil
	call	setOutput
	ret

setOutput:
	#### Parameters ####
	# %dil = pin number

	movq	$0, %rdx 		# set all 64 bits in rdx register to 0
	movq	GPIO, %rax
	movw	(%rax), %dx

	movq	$0, %rsi		# set all bits in rsi register to 0
	movw	$0x2, %si
	shlw	$6, %si


	movb	$4, %r8b
	subb	%dil, %r8b
	shlb	$1, %r8b
	movb	%r8b, %cl

	shlw	%cl, %si

	orw		%si, %dx
	movw	%dx, (%rax)
	ret


setInput:
	#### Parameters ####
	# %dil = pin number

	pushq	%rdi			# push pin number to stack for later use
	movq	$0, %rdi		# Make sure there are no old bits still in the rdi register
	popq	%rdi			# get pin number from stack
	movq	GPIO, %rax		# eax = address of gpio
	movw	(%rax), %dx		# %dx = first two bytes of gpio
	
	pushq	%rdi			# push pin number to stack for later use
	shrw	$3, %di			# %edi = pin number / 8

	addw	%di, %dx		# %dx = gpio_addr + (GPIO_NR / 8)


	popq	%rdi			# %dil = pin number
	movq	$0, %rcx		# reset %rcx
	movb 	$3, %cl			# %cl = 3
	subb	%dil, %cl		# %cl = 3 - pin number
	shlb	$1, %cl			# %cl = %cl * 2

	pushq	%rdx			# push gpio_addr + (GPIO_NR / 8)
	movq	$0, %rax		# reset %rax
	movl	%ecx, %eax		# %eax = (3 - pin number) * 2
	movq	$0, %rdx		# reset %rdx for div operation
	movl	$8, %ebx		# %ebx = 8 
	div		%ebx			# %edx = %eax % 8
	addl	$8, %edx		# %edx = %edx + 8

	movq	$0, %r10		# clear r10
	movw	$0x3, %r10w		# %r10w = 0x3
	movb	%dl, %cl		# for left shift
	shlw	%cl, %r10w 		# %r10w = 0x3 << %dl


	popq	%rdx			# pop gpio_addr + (GPIO_NR / 8)
	orw		%r10w, %dx		# %dx = 0x3 << ((((3-GPIO_NR)*2) % 8)+8) | gpio_addr + (GPIO_NR / 8)

	movl	GPIO, %eax		# set %eax to the address of gpio because its value has been changed in div
	movw	%dx, (%rax)		# set first two bytes of gpio to the two bytes in %dx
	ret


setHigh:
	#### Parameters ####
	# %dil = pin number

	movq 	GPIO, %rax
	addq 	$3, %rax		# %edx = (int*)gpio_addr + 3
	movl	(%rax), %edx

	movl	$0x3, %esi
	shll	$4, %esi
	incl	%esi			# %esi = ((0x3 << 4) + 1)

	subb	$1, %dil
	shlb	$3, %dil		# %dil = (8 * (GPIO_NR - 1))
	movb	%dil, %cl		# for left shift operation

	shll	%cl, %esi		# %esi = ((0x3 << 4)+1) << (8*(GPIO_NR-1))

	orl		%esi, %edx		# %edx = (int*)gpio_addr + 3 |= ((0x3 << 4)+1) << (8*(GPIO_NR-1))
	movl	%edx, (%rax)	# move edx to the first 4 bytes in gpio array
	ret


setLow:
	#### Parameters  ####
	# %dil = pin number

	movq	GPIO, %rax
	addq	$3, %rax
	movl	(%rax), %edx

	subb	$1, %dil
	shlb	$3, %dil
	movb	%dil, %cl
	movl	$0xCF, %esi
	
	shll	%cl, %esi
	notl	%esi

	andl	%esi, %edx
	movl	%edx, (%rax)
	ret
