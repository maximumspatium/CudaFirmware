;-------------------------------------------------------------------------
; Start of Cuda ROM
;-------------------------------------------------------------------------
		org $F00
        fcc "Copyright © 1989-93"
		fcb $D
        fcc "Some Company Name XX"
		fcb $D
		fcc "All rights reserved."
		fcb   0
		fcb   0
		fcb $19
		fcb   0
		fcb   2
		fcb   0
		fcb $25
		fcb   1
		fcb   0
		fcb   0
		fcb $A4
		fcb   0
		fcb $95
		fcb   0
		fcb $AF
		fcb   0
		fcb $AB

		fcc "Cuda 2.37" ; Human-readable firmware version string

IOInit:
        org $F57
        fcb 0 ; initial value for PORTA
		fcb 0 ; initial value for PORTB
		fcb 0 ; initial value for PORTC
		fcb 0 ; unused
		fcb $99   ; initial data direction for Port A (DDRA): OIIOOIIO (O - out, I - in)
		fcb $92   ; initial data direction for Port B (DDRB): OIIOIIOI
		fcb 8     ; initial data direction for Port C (DDRC): OIII

;--------------------------------------------------------------------------
; This entry point is actually the cold start, i.e. it will be called
; when Cuda Reset is occured. Please note that Cuda won't reset itself with
; the logic board reset! Cuda HW reset only happens when one
; of the following conditions is met:
; - logic board has been powered on without PRAM battery
; - a fresh PRAM battery has been inserted during power-off
; - Cuda reset pads on the logic board have been shorted
;
; Otherwise, Cuda continues to operate off of the battery,
; even when the logic board is powered off.
;--------------------------------------------------------------------------

ColdStart:
		rsp           ; reset stack pointer (SP <= $FF)
		jsr	sub_11B3  ; PLL test?
		lda	#$10
		sta	CPICSR
		lda	#3
		sta	TCS

        ;------------------------------------------------------------------
        ; write initial values to PORTA, PORTB, PORTC and DDRA, DDRB, DDRC
        ;------------------------------------------------------------------
		ldx	#6
loop1:
		lda	IOInit, x
		sta	, x
		decx
		bpl	loop1

        ;------------------------------------------------------------------
        ; clear 64 bytes of RAM in the address range $90...$CF
        ; This memory is used to maintain Cuda state
        ;------------------------------------------------------------------
		ldx	#$40
loop2:
		clr	byte_90, x
		decx
		bpl	loop2

        ;------------------------------------------------------------------
        ; zero the PRAM area which is actually a part of the MCU's internal
        ; RAM in the address range $100...$1FF.
        ;------------------------------------------------------------------
		clrx  ; X = 0, loop counter
		txa   ; A = 0, value to write
loop3:
		sta	word_100, x
		incx
		bne	loop3

        ;------------------------------------------------------------------
        ; This is the place where some funny stuff happens :))
        ; RAM bytes $AB...$AE contain current timestamp (i.e. number of seconds
        ; that have elapsed since 12:00 a.m., January 1, 1904). It will be
        ; continuously updated by the custom periodic interrupt (CPI) handler.
        ; The code below assign it the odd initial value of $630BD178
        ; that corresponds to Monday, 27. August 1956. This is apparently
        ; the birthdate of Cuda's designer Ray Montagne :)))
        ;------------------------------------------------------------------
		lda	#$63
		sta	byte_AB
		lda	#$B
		sta	byte_AC
		lda	#$D1
		sta	byte_AD
		lda	#$78
		sta	byte_AE

		bset	3, byte_A3
		bset	3, byte_A1
		jsr	sub_173C
		sta	byte_91

        ;------------------------------------------------------------------
        ; This seems to be the Warm start entry.
        ;------------------------------------------------------------------
loc_F9B:
		sei           ; disable interrupts
		rsp           ; reset stack pointer (SP <= $FF)
		jsr	sub_11B3  ; PLL init?

;---------------------------------------------------------------
; Self-check ROM ($1F00...$1FEF).
; We currently don't carry much about it.
;---------------------------------------------------------------
        org $1F00


;---------------------------------------------------------------
; Interrupt vectors
;---------------------------------------------------------------
		org $1FF0
        fcb   0			 ; reserved
        fcb   0			 ; reserved
        fcb   0			 ; reserved
        fcb   0			 ; reserved
        fcb   0			 ; reserved
        fcb   0			 ; reserved
        fdb CPIHandler	 ; Custom Periodic Interrupt
    	fdb TIHandler    ; Timer Interrupt
        fdb IRQHandler   ; IRQ/IRQ2
        fdb 0		     ; SWI (unused)
        fdb ColdStart	 ; Cuda HW Reset
