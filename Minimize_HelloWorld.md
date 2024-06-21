---
title: 最小化 Hello World 代码
date: 2024-06-19
categories:
- C语言
- x86_64 汇编
- 就是玩儿
tags:
- C语言
- x86_64 汇编
- 就是玩儿
---

# 最小化 Hello World 代码

这是一个最简单的 HelloWorld 程序

```c
#include "stdio.h"
int main(){
    printf("Hello World!\n");
    return 0;
}
```

编译运行

```bash
gcc ver1.c -o ver1
```

运行就会输出 `Hello World!` 

看看编译后的输出大小
```bash
ls -l ver1
-rwxr-xr-x 1 neolux neolux 15440  6月11日 22:38 ver1

ls -lh ver1
-rwxr-xr-x 1 neolux neolux 16K  6月11日 22:38 ver1
```

当我们把静态库一起编译到文件里后再来看看

```bash
gcc -static ver1.c -o ver1_static

./ver1_static
Hello World!

ls -l ver1_static
-rwxr-xr-x 1 neolux neolux 762680  6月11日 22:38 ver1_static

ls -lh ver1_static
-rwxr-xr-x 1 neolux neolux 745K  6月11日 22:38 ver1_static
```

程序一下子变得很大了  
下面开始精简程序

## 使用编译参数优化空间

C语言代码不变，更改编译参数

```bash
gcc -static -Os -s ver1.c -o ver1_Os

ls -l ver1_Os
-rwxr-xr-x 1 neolux neolux 682456  6月11日 22:38 ver1_Os

ls -lh ver1_Os
-rwxr-xr-x 1 neolux neolux 667K  6月11日 22:38 ver1_Os
```

- 使用 `-Os` 优化代码的体积
- `-s` 移除调试信息，能够降低 elf 文件的体积

## 使用汇编

C 语言优化空间有限，通过使用汇编语言来尝试优化可执行文件的体积

```assembly
.text

.global main

main:
	mov $str_helloworld, %rdi
	call puts
	mov $0, %rax
	ret

str_helloworld:
	.string "Hello World!\n"
```

```bash
gcc -static -Os -s ver2.s -o ver2

ls -l ver2
-rwxr-xr-x 1 neolux neolux 682456  6月11日 22:41 ver2

ls -lh ver2
-rwxr-xr-x 1 neolux neolux 667K  6月11日 22:41 ver2
```

和刚才相比并没有减少字节，因为代码中仍然使用了 _libc_ 的代码，下面尝试抛弃 _libc_

## 不使用 _libc_

```assembly
.text
.global _start
_start:
  mov $1, %rax # syscall: 1(write)
  mov $1, %rdi # fd: 1(stdout)
  mov $str_helloworld, %rsi # buffer: str_helloworld
  mov $13, %rdx #count: 13(strlen)
  syscall

  # exit(0)
  mov $60, %rax
  mov $0, %rdi
  syscall

str_helloworld:
  .string "Hello World!\n"
```

- 不用 `main()` 做程序入口，而是使用 `_start` 符号作为程序入口
- 不使用 `puts()`、`printf()` 作为输出函数，而是直接调用 `write` 方法向 `stdout` 输出数据
- 手动调用 `exit` 推出程序

编译

```bash
gcc -static -s -nostdlib ver3.s -o ver3

ls -l ver3
-rwxr-xr-x 1 neolux neolux 4536  6月11日 22:45 ver3

ls -lh ver3
-rwxr-xr-x 1 neolux neolux 4.5K  6月11日 22:45 ver3
```

程序只剩下 4.5K 的大小

## N Magic

来查看可执行文件的信息

```bash
readelf -S ver3
There are 5 section headers, starting at offset 0x1078:

节头：
  [号] 名称              类型             地址              偏移量
       大小              全体大小          旗标   链接   信息   对齐
  [ 0]                   NULL             0000000000000000  00000000
       0000000000000000  0000000000000000           0     0     0
  [ 1] .note.gnu.pr[...] NOTE             0000000000400158  00000158
       0000000000000030  0000000000000000   A       0     0     8
  [ 2] .note.gnu.bu[...] NOTE             0000000000400188  00000188
       0000000000000024  0000000000000000   A       0     0     4
  [ 3] .text             PROGBITS         0000000000401000  00001000
       000000000000003c  0000000000000000  AX       0     0     1
  [ 4] .shstrtab         STRTAB           0000000000000000  0000103c
       0000000000000037  0000000000000000           0     0     1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  D (mbind), l (large), p (processor specific)
```

`.note.gnu.bu` 从 00000188 开始，大小仅有 0x24, 而 `.text` 在 00001000， 这中间整整有 0x0E78 的空间都被浪费了，
因为默认情况下，`.text` 按照页对齐，有利于提升加载速度，我们可以关闭这个特性，使用 `--nmagic`

```bash
gcc -static -s nostdlib ver3.s -Wl,--nmagic -o ver3_nmagic

ls -l ver3_nmagic
-rwxr-xr-x 1 neolux neolux 808  6月11日 22:47 ver3_nmagic

ls -lh ver3_nmagic
-rwxr-xr-x 1 neolux neolux 808  6月11日 22:47 ver3_nmagic
```

文件只有 808 了，相比于 C语言链接静态库的体积已经减少了 99.89% 

## 禁用 build-id

```bash
readelf -a ver3_nmagic
ELF 头：
  Magic：  7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00 
  类别:                              ELF64
  数据:                              2 补码，小端序 (little endian)
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI 版本:                          0
  类型:                              EXEC (可执行文件)
  系统架构:                          Advanced Micro Devices X86-64
  版本:                              0x1
  入口点地址：              0x400174
  程序头起点：              64 (bytes into file)
  Start of section headers:          488 (bytes into file)
  标志：             0x0
  Size of this header:               64 (bytes)
  Size of program headers:           56 (bytes)
  Number of program headers:         4
  Size of section headers:           64 (bytes)
  Number of section headers:         5
  Section header string table index: 4

节头：
  [号] 名称              类型             地址              偏移量
       大小              全体大小          旗标   链接   信息   对齐
  [ 0]                   NULL             0000000000000000  00000000
       0000000000000000  0000000000000000           0     0     0
  [ 1] .note.gnu.pr[...] NOTE             0000000000400120  00000120
       0000000000000030  0000000000000000   A       0     0     8
  [ 2] .note.gnu.bu[...] NOTE             0000000000400150  00000150
       0000000000000024  0000000000000000   A       0     0     4
  [ 3] .text             PROGBITS         0000000000400174  00000174
       000000000000003c  0000000000000000  AX       0     0     1
  [ 4] .shstrtab         STRTAB           0000000000000000  000001b0
       0000000000000037  0000000000000000           0     0     1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  D (mbind), l (large), p (processor specific)

There are no section groups in this file.

程序头：
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  LOAD           0x0000000000000120 0x0000000000400120 0x0000000000400120
                 0x0000000000000090 0x0000000000000090  R E    0x8
  NOTE           0x0000000000000120 0x0000000000400120 0x0000000000400120
                 0x0000000000000030 0x0000000000000030  R      0x8
  NOTE           0x0000000000000150 0x0000000000400150 0x0000000000400150
                 0x0000000000000024 0x0000000000000024  R      0x4
  GNU_PROPERTY   0x0000000000000120 0x0000000000400120 0x0000000000400120
                 0x0000000000000030 0x0000000000000030  R      0x8

 Section to Segment mapping:
  段节...
   00     .note.gnu.property .note.gnu.build-id .text 
   01     .note.gnu.property 
   02     .note.gnu.build-id 
   03     .note.gnu.property 

There is no dynamic section in this file.

该文件中没有重定位信息。
No processor specific unwind information to decode

No version information found in this file.

Displaying notes found in: .note.gnu.property
  所有者            Data size   Description
  GNU                  0x00000020       NT_GNU_PROPERTY_TYPE_0
      Properties: x86 feature used: x86
        x86 ISA used: x86-64-baseline

Displaying notes found in: .note.gnu.build-id
  所有者            Data size   Description
  GNU                  0x00000014       NT_GNU_BUILD_ID (unique build ID bitstring)
    Build ID: c420275597ab00b8ff7692020a0f3955353c7188
```

一个 Section Header 的大小是 64B, 而且 `.note.gnu.build-id` 占了 36B。可以禁用 build-id 来节省空间

```bash
gcc -static -s -nostdlib ver3.s -Wl,--nmagic -Wl,--build-id=none -o ver3_nmagic_nobuildid

ls -l ver3_nmagic_nobuildid
-rwxr-xr-x 1 neolux neolux 632  6月11日 22:49 ver3_nmagic_nobuildid
```

又减少了 176B

## 优化指令

- 在原本的汇编指令中，`mov $0, %R` 来给寄存器置 0，占用了7个字节，而使用 `xor %R, %R` 一样可以置0，只占 3 字节
- `xor %R, %R; inc %R` 占用 6 字节，而 `mov $1, %R` 占用 7 字节

因此可以优化代码

```assembly
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
```

编译输出
```bash
gcc -static -s -nostdlib ver3.s -Wl,--nmagic -Wl,--build-id=none -o ver3_xor

ls -l ver3_xor
-rwxr-xr-x 1 neolux neolux 624  6月11日 22:59 ver3_xor
```

至此 HelloWorld 程序只有 624B 的大小



