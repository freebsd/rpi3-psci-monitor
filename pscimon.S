/*
 * Copyright (c) 2016 Raspberry Pi (Trading) Ltd.
 * Copyright (c) 2016 Stephen Warren <swarren@wwwdotorg.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * * Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * * Neither the name of the copyright holder nor the names of its contributors
 *   may be used to endorse or promote products derived from this software
 *   without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#define BIT(x) (1 << (x))

#define LOCAL_CONTROL		0x40000000
#define LOCAL_PRESCALER		0x40000008

#define OSC_FREQ		19200000

#define SCR_RW			BIT(10)
#define SCR_HCE			BIT(8)
#define SCR_SMD			BIT(7)
#define SCR_RES1_5		BIT(5)
#define SCR_RES1_4		BIT(4)
#define SCR_NS			BIT(0)
#define SCR_VAL \
    (SCR_RW | SCR_HCE | SCR_RES1_5 | SCR_RES1_4 | SCR_NS)

#define CPUECTLR_EL1		S3_1_C15_C2_1
#define CPUECTLR_EL1_SMPEN	BIT(6)

#define SPSR_EL3_D		BIT(9)
#define SPSR_EL3_A		BIT(8)
#define SPSR_EL3_I		BIT(7)
#define SPSR_EL3_F		BIT(6)
#define SPSR_EL3_MODE_EL2H	9
#define SPSR_EL3_VAL \
    (SPSR_EL3_D | SPSR_EL3_A | SPSR_EL3_I | SPSR_EL3_F | SPSR_EL3_MODE_EL2H)

#define PSCI_VERSION		0x84000000
#define PSCI_CPU_ON		0xC4000003
#define PSCI_SYSTEM_OFF		0x84000008
#define PSCI_SYSTEM_RESET	0x84000009

#define WDOG_ADDRESS		0x3f100000
#define WDOG_PASSWORD		0x5a000000

#define	FDT_BEGIN_NODE		0x00000001
#define	FDT_END_NODE		0x00000002
#define	FDT_PROP		0x00000003
#define	FDT_NOP			0x00000004
#define	FDT_END			0x00000009

#define	STR_MEMO		0x6f6d656d
#define	STR_RY			0x00007972
#define	STR_REG			0x72656700

#define RESERVE_SIZE		0x4000

.globl _start
_start:
	/*
	 * LOCAL_CONTROL:
	 * Bit 9 clear: Increment by 1 (vs. 2).
	 * Bit 8 clear: Timer source is 19.2MHz crystal (vs. APB).
	 */
	mov	x0, LOCAL_CONTROL
	str	wzr, [x0]
	/* LOCAL_PRESCALER; divide-by (0x80000000 / register_val) == 1 */
	mov	w1, 0x80000000
	str	w1, [x0, #(LOCAL_PRESCALER - LOCAL_CONTROL)]

	/* Set up CNTFRQ_EL0 */
	ldr	x0, =OSC_FREQ
	msr	CNTFRQ_EL0, x0

	/* Set up CNTVOFF_EL2 */
	msr	CNTVOFF_EL2, xzr

	/* Enable FP/SIMD */
	/* All set bits below are res1; bit 10 (TFP) is set to 0 */
	mov	x0, #0x33ff
	msr	CPTR_EL3, x0

	/* Set up SCR */
	mov	x0, #SCR_VAL
	msr	SCR_EL3, x0

	/* Set SMPEN */
	mov	x0, #CPUECTLR_EL1_SMPEN
	msr	CPUECTLR_EL1, x0

	/*
	 * Set up SCTLR_EL2
	 * All set bits below are res1. LE, no WXN/I/SA/C/A/M
	 */
	ldr	x0, =0x30c50830
	msr	SCTLR_EL2, x0


	adr	x0, el3_exception_vectors
	msr	vbar_el3, x0

	/* Switch to EL2 */
	mov	x0, #SPSR_EL3_VAL
	msr	spsr_el3, x0
	adr	x0, in_el2
	msr	elr_el3, x0
	eret
in_el2:
	mrs	x6, MPIDR_EL1
	and	x6, x6, #0x3
	cbz	x6, primary_cpu

	adr	x5, spin_table
secondary_spin:
	wfe
	lsl	x7, x6, #4
	ldr	x4, [x5, x7] /* mpentry */
	cbz	x4, secondary_spin
	add	x7, x7, 8
	ldr	x0, [x5, x7] /* mpentry arg */
	b	boot_kernel

primary_cpu:
	 bl	fixup_fdt_memory

	ldr	w4, kernel_entry32
	ldr	w0, dtb_ptr32

boot_kernel:
	mov	x1, #0
	mov	x2, #0
	mov	x3, #0
	br	x4

.ltorg

.org 0xf0
.globl stub_magic
stub_magic:
	.word 0x5afe570b
.org 0xf4
.globl stub_version
stub_version:
	.word 0
.org 0xf8
.globl dtb_ptr32
dtb_ptr32:
	.word 0x0
.org 0xfc
.globl kernel_entry32
kernel_entry32:
	.word 0x0

.globl spin_table
spin_table:
	.quad 0 /* CPU0 mpentry */
	.quad 0 /* CPU0 mpentry arg */
	.quad 0 /* CPU1 mpentry */
	.quad 0 /* CPU1 mpentry arg */
	.quad 0 /* CPU2 mpentry */
	.quad 0 /* CPU2 mpentry arg */
	.quad 0 /* CPU3 mpentry */
	.quad 0 /* CPU3 mpentry arg */

.align  11
.globl  el3_exception_vectors
el3_exception_vectors:
	eret     /* Sync, Current EL using SP0 */
	.align  7
	eret     /* IRQ, Current EL using SP0 */
	.align  7
	eret     /* FIQ, Current EL using SP0 */
	.align  7
	eret     /* SError, Current EL using SP0 */
	.align  7
	eret     /* Sync, Current EL using SPx */
	.align  7
	eret     /* IRQ, Current EL using SPx */
	.align  7
	eret     /* FIQ, Current EL using SPx */
	.align  7
	eret     /* SError, Current EL using SPx */
	.align  7
	b	handle_sync	/* Sync, Lower EL using AArch64 */
	.align  7
	eret     /* IRQ, Lower EL using AArch64 */
	.align  7
	eret     /* FIQ, Lower EL using AArch64 */
	.align  7
	eret     /* SError, Lower EL using AArch64 */
	.align  7
	eret     /* Sync, Lower EL using AArch32 */
	.align  7
	eret     /* IRQ, Lower EL using AArch32 */
	.align  7
	eret     /* FIQ, Lower EL using AArch32 */
	.align  7
	eret     /* SError, Lower EL using AArch32 */

handle_sync:
	ldr     x9, =PSCI_VERSION
	cmp     x0, x9
	b.eq    psci_version
	ldr     x9, =PSCI_CPU_ON
	cmp     x0, x9
	b.eq    psci_cpu_on
	ldr     x9, =PSCI_SYSTEM_OFF
	cmp     x0, x9
	b.eq    psci_reset
	ldr     x9, =PSCI_SYSTEM_RESET
	cmp     x0, x9
	b.eq    psci_reset
	/* fall through to invalid ID case */
invalid_smc_id:
	ldr     x0, =0xFFFFFFFF
	eret
psci_version:
	/* Return v0.2 */
	mov     x0, #0x00000002
	eret
psci_cpu_on:
	adr	x5, spin_table
	lsl	x1, x1, 4
	str	x2, [x5, x1]
	add	x1, x1, 8
	str	x3, [x5, x1]
	sev
	mov	x0, #0 /* x1 = 0 */
	eret
psci_reset:
	ldr	x0, =WDOG_ADDRESS
	ldr	w1, =WDOG_PASSWORD
	orr	w2, w1, #0x8
	orr	w2, w2, #0x2 /* 10 ticks (~150ms) */
	str	w2, [x0, #0x24]
	orr	w2, w1, #0x20 /* full reset */
	str	w2, [x0, #0x1c]
loop:
	b loop


/*
 * Cut off 0x4000 bytes from the memory area
 */
fixup_fdt_memory:
	ldr	w0, dtb_ptr32

	ldr	w1, [x0, #8]	/* off_dt_struct */
	rev	w1, w1
	ldr	w2, [x0, #12]	/* off_dt_strings */
	rev	w2, w2

	ldr	w10, =FDT_END
	ldr	w11, =FDT_BEGIN_NODE
	ldr	w12, =FDT_END_NODE
	ldr	w13, =FDT_PROP
	ldr	w14, =FDT_NOP
	mov	w15, #0		/* depth level */
	mov	w16, #0		/* is current node named "memory" ? */

tokens_loop:
	ldr	w3, [x0, x1]
	rev	w3, w3
	add	w1, w1, 4
	cmp	w3, w10 /* FDT_END */
	b.eq	done
	cmp	w3, w14 /* FDT_NOP */
	b.eq	tokens_loop
	cmp	w3, w11 /* FDT_BEGIN_NODE ? */
	b.eq	begin_node 
	cmp	w3, w12 /* FDT_END_NODE ? */
	b.eq	end_node 
	cmp	w3, w13 /* FDT_PROP ? */
	b.eq	property 
	b	done

begin_node:
	add	w15, w15, #1
	mov	w16, #0		/* is_memory_node = 0 */

check_memory_name:
	mov	w5, w1
	/* check if name is "memory" */
	ldr	w6, [x0, x5]
	ldr	w7, =STR_MEMO
	cmp	w6, w7
	b.ne	skip_name
	add	x5, x5, 4
	ldr	w6, [x0, x5]
	ldr	w7, =STR_RY
	cmp	w6, w7
	b.ne	skip_name
	mov	w16, w1		/* is_memory_node = <token_addr> */
skip_name:
	mov	w5, w1
name_loop:
	ldrb	w6, [x0, x5]
	add	w5, w5, #1
	cmp	w6, #0
	b.ne	name_loop

	add	w5, w5, #3 /* Align to next 32-bit boundary */
	bic	w5, w5, #3
	mov	w1, w5
	b 	tokens_loop

end_node:
	sub	w15, w15, #1
	mov	w16, #0		/* is_memory_node = 0 */
	b       tokens_loop

property:
	ldr	w3, [x0, x1] /* len */
	rev	w3, w3
	add	w1, w1, 4
	ldr	w4, [x0, x1] /* name off */
	rev	w4, w4
	add	w1, w1, 4
	/*
	 * check if the name is "reg"
	 * name is not aligned, so load it byte by byte
	 */
	add	w4, w4, w2
	ldr	w6, #0

	ldrb	w5, [x0, x4]
	add	w4, w4, 1
	orr	w6, w5, w6, lsl #8
	ldrb	w5, [x0, x4]
	add	w4, w4, 1
	orr	w6, w5, w6, lsl #8
	ldrb	w5, [x0, x4]
	add	w4, w4, 1
	orr	w6, w5, w6, lsl #8
	ldrb	w5, [x0, x4]
	orr	w6, w5, w6, lsl #8
	ldr	w5, =STR_REG
	cmp	w5, w6
	b.ne	not_memory_reg
	cmp	w16, #0
	b.eq	not_memory_reg
	cmp	w15, #2
	b.ne	not_memory_reg
	/* OK, this is what we're looking for */
	ldr	w5, [x0, x1]
	rev	w5, w5
	add	w5, w5, #RESERVE_SIZE
	rev	w5, w5
	str	w5, [x0, x1]
	add	w1, w1, 4
	ldr	w5, [x0, x1]
	rev	w5, w5
	sub	w5, w5, #RESERVE_SIZE
	rev	w5, w5
	str	w5, [x0, x1]

not_memory_reg:
	/* Align len */
	add	w3, w3, #3
	bic	w3, w3, #3
	/* move to the next property */
	add	w1, w1, w3
	b	tokens_loop
done:
	ret