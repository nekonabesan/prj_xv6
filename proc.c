#include "types.h"
#include "mmu.h"
#include "x86.h"
#include "proc.h"
#include "param.h"
#include "defs.h"

struct proc proc[NPROC];

/*
 *
 *
 *
 *
 */
void
setupsegs(struct proc *p)
{
  memset(&p->ts, 0, sizeof(struct Taskstate));
  p->ts.ts_ss0 = SEG_KDATA << 3;
  p->ts.ts_esp0 = (unsigned)(p->kstack + KSTACKSIZE);

  memset(&p->gdt, 0, sizeof(p->gdt));
  p->gdt[0] = SEG_NULL;
  p->gdt[SEG_KCODE] = SEG(STA_X|STA_R, 0, 0xffffffff, 0);
  p->gdt[SEG_KDATA] = SEG(STA_W, 0, 0xffffffff, 0);
  p->gdt[SEG_TSS] = SEG16(STS_T32A, (unsigned) &p->ts, sizeof(p->ts), 0);
  p->gdt[SEG_TSS].sd_s = 0;
  p->gdt[SEG_UCODE] = SEG(STA_X|STA_R, (unsigned)p->mem, p->sz, 3);
  p->gdt[SEG_UDATA] = SEG(STA_W, (unsigned)p->mem, p->sz, 3);
  p->gdt_pd.pd__garbage = 0;
  p->gdt_pd.pd_lim = sizeof(p->gdt) - 1;
  p->gdt_pd.pd_base = (unsigned) p->gdt;
}

extern void trapret();

/*
 *
 *
 */
 struct proc *
 newproc(struct proc *op)
 {
  struct proc *np;
  unsigned *sp;

  for(np = &proc[1]; np < &proc[NPROC]; np++)
    if(np->state == UNUSED)
      break;
  if(np >= &proc[NPROC])
    return 0;

  np->sz = op->sz;
  np->mem = kalloc(op->sz);
  if(np->mem == 0)
    return 0;
  memcpy(np->mem, op->mem, np->sz);
  np->kstack = kalloc(KSTACKSIZE);
  if(np->kstack == 0) {
    kfree(np->mem, op->sz);
    return 0;
  }
  np->tf = (struct Trapframe *) (np->kstack + KSTACKSIZE - sizeof(struct Trapframe));
  setupsegs(np);
  np->state = RUNNABLE;

  // set up kernel stack to return to user space
  *(np->tf) = *(op->tf);
  sp = (unsigned *) np->tf;
  *(--sp) = (unsigned) &trapret;    // for return from swtch()
  *(--sp) = 0;  // previous bp for leave in swtch()
  np->esp = (unsigned) sp;
  np->ebp = (unsigned) sp;

  cprintf("esp %x ebp %x mem %x\n", np->esp, np->ebp, np->mem);

  return np;
 }

/*
 * find a runnable process and switch to it.
 */
 void
 swtch(struct proc *op)
 {
   struct proc *np;

   while(1){
     for(np = op + 1; np != op; np++){
       if(np == &proc[NPROC])
        np = &proc[0];
       if(np->state == RUNNABLE)
        break;
     }
     if(np->state == RUNNABLE)
      break;
      // idle...
   }

   op->ebp = read_ebp();
   op->esp = read_esp();

   // XXX callee-saved registers?

   //
   //
   //
   asm volatile("lgdt %0" : : "g" (np->gdt_pd.pd_lim));
   asm volatile("movl %0, %%esp" : : "g" (np->esp));
   asm volatile("movl %0, %%ebp" : : "g" (np->ebp));
 }
