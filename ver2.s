.text

.global main

main:
	mov $str_helloworld, %rdi
	call puts
	mov $0, %rax
	ret

str_helloworld:
	.string "Hello World!\n"


