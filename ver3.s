.text

.global _start

_start:
	xor %rax, %rax
	inc %rax
	mov %rax, %rdi
	mov $str_helloworld, %rsi
	mov $13, %rdx
	syscall

	mov $60, %rax
	xor %rdi, %rdi
	syscall

str_helloworld:
	.string "Hello World!\n"

