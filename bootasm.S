#define SEG_NULL                                                               \
  .word 0, 0;                                                                  \
  .byte 0, 0, 0, 0
#define SEG(type,base,lim)                                                     \
    .word (((lim) >> 12) & 0xffff), ((base) & 0xffff);                         \
    .byte (((base) >> 16) & 0xff), (0x90 | (type)),                            \
          (0xC0 | (((lim) >> 28) & 0xf)), (((base) >> 24) & 0xff)

#define STA_X       0x8         // Executable segment
#define STA_E       0x4         // Expand down (non-executable segments)
#define STA_C       0x4         // Conforming code segment (executable only)
#define STA_W       0x2         // Writeable (non-executable segments)
#define STA_R       0x2         // Readable (executable segments)
#define STA_A       0x1         // Accessed

.set PROT_MODE_CSEG,0x8           # code segment selector
.set PROT_MODE_DSEG,0x10    # data segment selector
.set CR0_PE_ON,0x1         # protected mode enable flag

################################################################################
#
#
#
#
#
#
#
#
#
#
################################################################################

.globl start                                  # Entry point
start:                .code16                 # This runs in real mode
              cli                             # Disable interrupts
              cld                             # String operations increment

              # Set up the important data segment registers (DS, ES, SS).
              xorw  %ax,%ax                   # Segment number zero
              movw  %ax,%ds                   # -> Data Segment
              movw  %ax,%es                   # -> Extra Segment
              movw  %ax,%ss                   # -> Stack Segment

              # Set up the stack pointer, growing downward from 0x7c00.
              movw  $start,%sp                # Stack Pointer

#### Enable A20:
####
####
####
####
####
####

seta20.1:     inb     $0x64,%al                     # Get status
              testb   $0x2,%al                      # Busy?
              jnz     seta20.1                      # Yes
              movb    $0xd1,%al                     # Command: Write
              outb    %al,$0x64                     # output port
seta20.2:     inb     $0x64,%al                     # Get status
              testb   $0x2,%al                      # Busy?
              jnz     seta20.2                      # Yes
              movb    $0xdf,%al                     # Enable
              outb    %al,$0x60                     #  A20

#### Switch from real to protected mode
####
####
####
####
####
####
####
####

real_to_prot: cli                                   # Mandatory since we dont set up an IDT
              lgdt    gdtdesc                       # load GDT -- mandatory in protected mode
              movl    %cr0, %eax                    # turn on protected mode
              orl     $CR0_PE_ON, %eax              #
              movl    %eax, %cr0                    #
              ### CPU magic: jump to relocation, flush prefetch queue, and reload %cs
              ###
              ###
              ljmp    $PROT_MODE_CSEG, $protcseg

#### we are in 32-bit protected mode (hence the .code32)
.code32
protcseg:
              # Set up the protected-mode data segment registers
              movw    $PROT_MODE_DSEG, %ax          # Our data segment selector
              movw    %ax, %ds                      # -> DS: Data Segment
              movw    %ax, %es                      # -> ES: Extra Segment
              movw    %ax, %fs                      # -> FS
              movw    %ax, %gs                      # -> GS
              movw    %ax, %ss                      # -> SS: Stack Segment

              call cmain                            # finish the boot load from C.
                                                    # cmain() should not return
spin:         jmp spin                              # ..but in case it does, spin

.p2align 2                                          # force 4 byte alignment
gdt:
      SEG_NULL                                      # null seg
      SEG(STA_X|STA_R, 0x0, 0xffffffff)             # code seg
      SEG(STA_W, 0x0, 0xffffffff)                   # data seg

gdtdesc:
      .word 0x17                      # sizeof(gdt) - 1
      .long     gdt                     # address gdt
