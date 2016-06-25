// Copyright (c) 2015 Klaus Post, released under MIT License. See LICENSE file.

// +build 386,!gccgo

// func cpuid(op uint32) (eax, ebx, ecx, edx uint32)
TEXT ·cpuid(SB), 7, $0
        XORL CX, CX
        MOVL op+0(FP), AX
        CPUID
        MOVL AX, eax+4(FP)
        MOVL BX, ebx+8(FP)
        MOVL CX, ecx+12(FP)
        MOVL DX, edx+16(FP)
        RET

