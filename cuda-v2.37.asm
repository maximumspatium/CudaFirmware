;-------------------------------------------------------------------------
; Start of Cuda ROM
;-------------------------------------------------------------------------
    org     $F00
    fcc     "Copyright © 1989-93"
    fcb     $D
    fcc     "Some Company Name XX"
    fcb     $D
    fcc     "All rights reserved."
    fcb     0
    fcb     0
    fcb     $19
    fcb     0
    fcb     2
    fcb     0
    fcb     $25
    fcb     1
    fcb     0
    fcb     0
    fcb     $A4
    fcb     0
    fcb     $95
    fcb     0
    fcb     $AF
    fcb     0
    fcb     $AB

    fcc     "Cuda 2.37" ; Human-readable firmware version string

IOInit:
    org     $F57
    fcb     0     ; initial value for PORTA
    fcb     0     ; initial value for PORTB
    fcb     0     ; initial value for PORTC
    fcb     0     ; unused
    fcb     $99   ; initial data direction for Port A (DDRA): OIIOOIIO (O - out, I - in)
    fcb     $92   ; initial data direction for Port B (DDRB): OIIOIIOI
    fcb     8     ; initial data direction for Port C (DDRC): OIII

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
    rsp              ; reset stack pointer (SP <= $FF)
    jsr    sub_11B3  ; PLL test?
    lda    #$10
    sta    CPICSR
    lda    #3
    sta    TCS

    ;------------------------------------------------------------------
    ; write initial values to PORTA, PORTB, PORTC and DDRA, DDRB, DDRC
    ;------------------------------------------------------------------
    ldx    #6
loop1:
    lda    IOInit, x
    sta    , x
    decx
    bpl    loop1

    ;------------------------------------------------------------------
    ; clear 64 bytes of RAM in the address range $90...$CF
    ; This memory is used to maintain Cuda state
    ;------------------------------------------------------------------
    ldx    #$40
loop2:
    clr    byte_90, x
    decx
    bpl    loop2

    ;------------------------------------------------------------------
    ; zero the PRAM area which is actually a part of the MCU's internal
    ; RAM in the address range $100...$1FF.
    ;------------------------------------------------------------------
    clrx  ; X = 0, loop counter
    txa   ; A = 0, value to write
loop3:
    sta    word_100, x
    incx
    bne    loop3

    ;------------------------------------------------------------------
    ; This is the place where some funny stuff happens :))
    ; RAM bytes $AB...$AE contain current timestamp (i.e. number of seconds
    ; that have elapsed since 12:00 a.m., January 1, 1904). It will be
    ; continuously updated by the custom periodic interrupt (CPI) handler.
    ; The code below assign it the odd initial value of $630BD178
    ; that corresponds to Monday, 27. August 1956. This is apparently
    ; the birthdate of Cuda's designer Ray Montagne :)))
    ;------------------------------------------------------------------
    lda    #$63
    sta    byte_AB
    lda    #$B
    sta    byte_AC
    lda    #$D1
    sta    byte_AD
    lda    #$78
    sta    byte_AE

    bset    3, byte_A3
    bset    3, byte_A1
    jsr    sub_173C
    sta    byte_91

    ;------------------------------------------------------------------
    ; This seems to be the Warm start entry.
    ;------------------------------------------------------------------
loc_F9B:
    sei           ; disable interrupts
    rsp           ; reset stack pointer (SP <= $FF)
    jsr sub_11B3  ; PLL init?


    org $1274
;--------------------------------------------------------------------------
; Here we'll process the incoming packets.
;--------------------------------------------------------------------------
sub_1274:
    brset  PB3, PORTB, loc_12DF
    bclr   2, byte_A2
    clr    byte_B5
    jsr    sub_1488
    bcs    loc_12DF
    jsr    sub_1488
    bcs    loc_12DF
    lda    byte_BA
    sta    byte_B8
    lda    byte_B9
    sta    byte_B7
    bne    loc_1292     ; go if we got a non-ADB packet
    jmp    HandleADBpkt ; otherwise, treat it as an ADB packet

loc_1292:
    cmp    #1           ; is it a Cuda packet?
    beq    CmdDispatch  ; then process it
    lda    #1
    bra    loc_12A9

loc_129A:
    lda    byte_B7
    sta    byte_B9
    lda    byte_B8
    sta    byte_BA
    lda    #3
    jsr    loc_12A9
    sec
    rts

loc_12A9:
    sta    byte_93
    lda    byte_B7
    sta    byte_BB
    lda    byte_B8
    sta    byte_99
    lda    #2
    sta    byte_B9
    lda    byte_93
    sta    byte_BA
    lda    #1
    sta    byte_97
    sta    byte_96
    jmp    loc_13E7

    ; ---------------------------------------------------------
    ; Dispatch for Cuda pseudo commands.
    ; ---------------------------------------------------------
CmdDispatch:
    lda    byte_BA      ; A - Cuda pseudo commandID
    cmp    #$25         ; is the commandID >= 0x25 ?
    bcc    InvalidCmd   ; then it's invalid
    sta    byte_93      ;
    asla                ;
    add    byte_93      ; A = commandID * 3
    tax                 ; X = A
    jmp    CmdJT, x     ; jump to the command handler

InvalidCmd:
    clr    byte_B5
    jsr    sub_1488
    bcc    InvalidCmd
    lda    #2
    jmp    loc_12A9

loc_12DF:
    jsr    sub_15E1
    sec
    rts

    ; --------------------------------------------------------------
    ; Jump table for Cuda pseudo commands.
    ; Cuda shares the commands with its predecessor - Egret ASIC but
    ; Cuda does support only a subset of Egret commands.
    ; --------------------------------------------------------------
CmdJT:
    jmp     loc_1751    ; NopCmd (0x00)
    jmp     loc_1764    ; APoll    (0x01)
    jmp     loc_1781    ; Rd6805addr (0x02)
    jmp     loc_17B2    ; RdTime (0x03)
    jmp     InvalidCmd  ; RdRomSize (0x04)   - unimplemented in Cuda
    jmp     InvalidCmd  ; RdRomBase (0x05)   - unimplemented in Cuda
    jmp     InvalidCmd  ; RdRomHeader (0x06) - unimplemented in Cuda
    jmp     loc_17EA    ; RdPram (0x07)
    jmp     loc_1830    ; Wr6805Addr (0x08)
    jmp     loc_1858    ; WrTime (0x09)
    jmp     loc_1872    ; PwrDown (0x0A)
    jmp     loc_1883    ; WrPwrupTime (0x0B)
    jmp     loc_189B    ; WrPram (0x0C)
    jmp     loc_18D0    ; MonoReset (0x0D)
    jmp     loc_18E5    ; WrDFAC / WrIIC (0x0E)
    jmp     InvalidCmd  ; Egretdiags (0x0F)  - unimplemented in Cuda
    jmp     loc_1A03    ; RdCtlPanel / RdBattery (0x10)
    jmp     loc_1A1C    ; ResetEgret (0x11)
    jmp     loc_1A2A    ; EnDisVpp / SetIPL (0x12)
    jmp     loc_1A3F    ; EnDisFiles (0x13)
    jmp     loc_1A54    ; SetAutopoll (0x14)
    jmp     InvalidCmd  ; RdPramSize (0x15)  - unimplemented in Cuda
    jmp     loc_1A65    ; RdAutoRate (0x16)
    jmp     InvalidCmd  ; WrBusDelay (0x17)  - unimplemented in Cuda
    jmp     InvalidCmd  ; RdBusDelay (0x18)  - unimplemented in Cuda
    jmp     loc_1A7B    ; WrDevList (0x19)
    jmp     loc_1A90    ; RdDevList (0x1A)
    jmp     loc_1AAD    ; Wr1SecMode (0x1B)
    jmp     InvalidCmd  ; EnDisKbdNmi (0x1C) - unimplemented in Cuda
    jmp     InvalidCmd  ; EnDisParse (0x1D)  - unimplemented in Cuda
    jmp     InvalidCmd  ; WrHangTout (0x1E)  - unimplemented in Cuda
    jmp     InvalidCmd  ; RdHangTout (0x1F)  - unimplemented in Cuda
    jmp     InvalidCmd  ; SetDefDFAC (0x20)  - unimplemented in Cuda
    jmp     loc_1B11    ; EnDisPDM (0x21)
    jmp     loc_192C    ; DFACorIIC (0x22)
    jmp     loc_1B5E    ; WakeUpMode (0x23)
    jmp     loc_1B74    ; TimerTickle (0x24)

BadADBCmd:
    jmp    InvalidCmd

    ; --------------------------------------------------------------
    ; Here we'll process ADB packets.
    ; --------------------------------------------------------------
HandleADBpkt:
    lda    byte_B8      ; check if ADB SendReset command is requested
    and    #$F          ; ADB Command and device register will be 0 in this case
    beq    ADBSendReset ; go if the SendReset cmd is requested
    cmp    #1           ;
    beq    ADBFlush     ; go if the Flush command is requested
    cmp    #8           ; is (ADB command + dev register) < 8?
    bcs    BadADBCmd    ; then it's an invalid ADB command
    cmp    #$C          ; if (ADB command + dev register) > 0xC ?
    bcc    ADBTalk      ; then go to process the ADB Talk command

    ; --------------------------------------------------------------
    ; Otherwise, process the ADB Listen command.
    ; --------------------------------------------------------------
    clr    byte_B5

loc_136A:
    ldx    byte_B5
    cpx    #8
    bls    loc_1372
    dec    byte_B5

loc_1372:
    jsr    sub_1488
    bcc    loc_136A
    jsr    sub_144B
    ldx    byte_B5
    cpx    #2
    bcs    loc_1391
    stx    byte_96
    decx

loc_1383:
    lda    byte_B9, x
    sta    byte_99, x
    decx
    bpl    loc_1383
    lda    byte_B8
    jsr    sub_1CB8
    bra    loc_13C0

loc_1391:
    lda    #3
    jmp    loc_12A9

ADBSendReset:
    jsr    sub_1488
    bcc    loc_13D2
    lda    #$30
    sta    byte_B3
    lda    #$20
    sta    byte_B4

    ; --------------------------------------------------------------------
    ; We're going to reset the ADB bus now. According to the ADB protocol
    ; specification, we need to hold the ADB bus low for 3 ms to force all
    ; attached devices to reset themselves.
    ; --------------------------------------------------------------------
    bset   PA7, PORTA       ; set ADB data line out low
    ldx    #3               ;
    jsr    DelayXMillisecs  ; wait for 3 ms
    bclr   PA7, PORTA       ; set ADB data line out high
    ldx    #$1B             ; wait for another
    jsr    TenCyclesLoop    ; 135 µs
    bra    loc_13C0

ADBFlush:
    jsr    sub_1488
    bcc    loc_13D2
    jsr    sub_144B
    lda    byte_B8
    jsr    sub_1CB8

loc_13C0:
    jmp    sub_161E

    ; --------------------------------------------------------------
    ; Process the ADB Talk command.
    ; --------------------------------------------------------------
ADBTalk:
    jsr    sub_1488
    bcc    loc_13D2
    jsr    sub_144B
    lda    byte_B8
    jsr    sub_1CB8
    bra    sub_13DD

loc_13D2:
    lda    #3
    sta    byte_B5
    jsr    sub_1488
    bcc    loc_13D2
    bra    loc_1391



    org $1E18

;------------------------------------------------------------------
; Generic delay subroutine that spends 10 * X cycles.
; To get the real number of cycles spent, add additional 14 cycles
; for loading the counter + call + ret.
;------------------------------------------------------------------
TenCyclesLoop:
    nop
    nop
    decx
    bne    TenCyclesLoop
    rts

;---------------------------------------------------------------
; Another delay routine.
;---------------------------------------------------------------
sub_1E1E:
    lda    #$10

loc_1E20:
    ldx    #$13
    jsr    TenCyclesLoop
    deca
    bne    loc_1E20
    rts

;----------------------------------------------------------------
; This subroutine will wait for at least the specified number of
; milliseconds.
; The real delay is a bit longer - we need to add the additional
; 14 cycles for loading the counter + call + ret.
; This subroutine works only in the high-speed clock (2.097 MHz)
; mode.
; Params: X - number of milliseconds to wait
;----------------------------------------------------------------
DelayXMillisecs:
    cpx    #0
    beq    nullsub_1

loc_1E2D:
    lda    #$AE

loc_1E2F:
    nop
    nop
    nop
    deca
    bne    loc_1E2F
    decx
    bne    loc_1E2D

doNothing:
    rts

;----------------------------------------------------------------
; This subroutine will wait for at least 10 milliseconds.
; It supports both the low-speed (16.384 kHz) and
; the high-speed (2.097 MHz) mode.
; The real delay is a bit longer - we need to add the additional
; 14 cycles for loading the counter + call + ret.
; Params: X - number of milliseconds to wait
;----------------------------------------------------------------
Delay10Millisecs:
    brset  BCS, PLLC, loc_1E42 ; go if we're running at the high speed
    ldx    #$F              ; otherwise, wait for 15 * 10 + 14 cycles, i.e.
    jsr    TenCyclesLoop    ; 1/16384 * 164 * 1000 = 10 ms
    rts                     ; and return

loc_1E42:
    ldx    #$A              ; wait for 10 ms in the high-speed
    jsr    DelayXMillisecs  ; mode (2.097 MHz)
    rts                     ; and return

;----------------------------------------------------------------
; This subroutine will wait for at least 100 milliseconds.
; The real delay is a bit longer - we need to add the additional
; 14 cycles for loading the counter + call + ret.
; Params: X - number of milliseconds to wait
;----------------------------------------------------------------
Delay100Millisecs:
    brset  BCS, PLLC, loc_1E51 ; go if we're running at the high speed
    ldx    #$A1             ; otherwise, wait for 161 * 10 + 14 cycles, i.e.
    jsr    TenCyclesLoop    ; 1/16384 * 1624 * 1000 = 100 ms
    rts                     ; and return

loc_1E51:
    ldx    #$64             ; wait for 100 ms in the high-speed
    jsr    DelayXMillisecs  ; mode (2.097 MHz)
    rts                     ; and return


;---------------------------------------------------------------
; Self-check ROM ($1F00...$1FEF).
; We currently don't carry much about it.
;---------------------------------------------------------------
    org $1F00


;---------------------------------------------------------------
; Interrupt vectors
;---------------------------------------------------------------
    org $1FF0
    fcb   0         ; reserved
    fcb   0         ; reserved
    fcb   0         ; reserved
    fcb   0         ; reserved
    fcb   0         ; reserved
    fcb   0         ; reserved
    fdb CPIHandler  ; Custom Periodic Interrupt
    fdb TIHandler   ; Timer Interrupt
    fdb IRQHandler  ; IRQ/IRQ2
    fdb 0           ; SWI (unused)
    fdb ColdStart   ; Cuda HW Reset
