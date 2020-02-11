;*************************************************
; setup.asm                                      *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************


;;
;; ��� setup ģʽ�ǹ��õģ����� ..\common\ Ŀ¼��
;; ����д����̵ĵ� 1 ������ ��
;;

%include "..\inc\support.inc"
%include "..\inc\protected.inc"
%include "..\inc\system_manage_region.inc"
%include "..\inc\apic.inc"


;;
;; ˵����
;; 1) ģ�鿪ʼ���� SETUP_SEGMENT
;; 2) ģ��ͷ�Ĵ���ǡ�ģ�� size��
;; 3) load_module() ������ģ����ص� SETUP_SEGMENT λ����
;; 4) SETUP ģ��ġ���ڵ㡱�ǣ�SETUP_SEGMENT + 0x18
        
        [SECTION .text]
        org SETUP_SEGMENT


;;
;; �� 0x8000 ��������������� (LOADER_BLOCK)
;;         
SetupLenth      DD SETUP_LENGTH                 ; ���ģ��� size
CpuIndex        DD 0FFFFFFFFh                   ; CPU index
CurrentVideo    DD 0B8000h					    ; CurrentVideo
ApStage1Lock    DD 1                            ; stage1��setup���׶ε���
ApStage2Lock    DD 1                            ; stage2��protected���׶ε���
ApStage3Lock    DD 1                            ; stage3��long���׶ε���    
MMap.Size       DQ 0
MMap.Base:      DQ 0                            ; �ڴ�����ĵ����ַ
MMap.Length:    DQ 0                            ; �ڴ�����ĳ���
MMap.Type:      DD 0                            ; �ڴ����������:


;;
;; ģ�鵱ǰ������ 16 λʵģʽ��
;;
        bits 16
        
SetupEntry:                                             ; ����ģ��������ڵ㡣
        cli
        cld
        NMI_DISABLE
        call enable_a20  
        DISABLE_8259 

        lock inc DWORD [CpuIndex]
        call check_cpu_environment
        call get_system_memory
        call protected_mode_enter
                

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;; ������ 32 λ���� ;;;;;;;;;;;;;;;;;;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
        bits 32

        ;;
        ;; ����������ݵĳ�ʼ������:
        ;; 1) ���ȣ���ʼ�� SDA��System Data Area����������
        ;; 2) Ȼ�󣬳�ʼ�� PCB��Processor Control Block����������
        ;;
        ;; ˵��:
        ;; 1) SDA ���������д������������Ա����ȳ�ʼ��
        ;; 2) PCB ������ logical processor ���ݣ���֧�� 16 �� PCB ��
        ;; 3) PCB �����Ƕ�̬���䣬ÿ�� PCB ���ַ��ͬ
        ;; 
        ;;
        ;; fs ��˵����
        ;;      1) fs ָ�� SDA��System Data Area������������ logical processor �������������
        ;; ע�⣺
        ;;      1) ��Ҫ��֧�� 64 λ�Ĵ������ϲ���ֱ��д IA_FS_BASE �Ĵ�����
        ;;      2) ������Ҫ��������ģʽ������ FS �λ�ַ
        ;;      3) GS �λ�ַ�ں��������и���
        ;;        
        call init_system_data_area


PcbInitEntry:
        ;;
        ;; ���� PCB��Processor Control Block������
        ;; ˵����
        ;; 1) �˴�Ϊ logical processor �� PCB ��ʼ����ڣ����� BSP �� AP��
        ;; 2) ÿ�� logical processor ����Ҫ��������� PCB ���ݳ�ʼ��
        ;; 
        call init_processor_control_block
        call init_apic
        call init_processor_basic_info
        call init_processor_topology_info
        call init_debug_capabilities_info
        call init_memory_type_manage
        call init_perfmon_unit

%ifndef DBG
        ;;
        ;; Stage1 �׶������������Ƿ�Ϊ BSP
        ;; 1) �ǣ����� INIT-SIPI-SIPI ����
        ;; 2) ����ȴ����� SIPI 
        ;;
        cmp BYTE [gs: PCB.IsBsp], 1
        jne ApStage1End

        ;;
        ;; ���� BSP ��1�׶ε��������
        ;; 1) ���� INIT-SIPI-SIPI ���и� AP 
        ;; 2) �ȴ����� AP ��1�׶����
        ;; 3) ת���½׶ι���
        ;;
        call wait_for_ap_stage1_done
%endif         

        ;;
        ;; ����Ƿ���Ҫ���� longmode
        ;; 1) �ǣ����� stage2, ���� stage3 �׶Σ�longmode ģʽ��
        ;; 2) �񣬽��� stage2 �׶�
        ;;
        cmp DWORD [fs: SDA.ApLongmode], 1
        mov eax, [PROTECTED_SEGMENT+4]
        cmove eax, [LONG_SEGMENT+4]
        jmp eax


%ifndef DBG      
        ;;
        ;; AP��1�׶������˵����
        ;; 1) ���� ApInitDoneCount ����ֵ
        ;; 1) AP �ȴ���2�׶������ȴ� BSP ���� stage2 ����
        ;;
        
ApStage1End:  
        ;;
        ;; ������ɼ���
        ;;
        lock inc DWORD [fs: SDA.ApInitDoneCount]

        ;;
        ;; ���ŵ�1�׶� AP Lock
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage1LockPointer]
        xchg [ebx], eax

%ifdef TRACE
	call dump_trace_message
%endif
        ;;
        ;; ����Ƿ���Ҫ���� longmode
        ;; 1) �ǣ����� stage2, �ȴ� stage3 �������� stage3 �׶Σ�longmode ģʽ��
        ;; 2) �񣬵ȴ� stage2 �������� stage2 �׶�
        ;;
        cmp DWORD [fs: SDA.ApLongmode], 1
        je ApStage1End.WaitStage3

        ;;
        ;; ���ڵȴ� stage2 ��������
        ;;
        mov esi, [fs: SDA.Stage2LockPointer]
        call get_spin_lock
        ;;
        ;; ���� stage2
        ;;
        jmp [PROTECTED_SEGMENT+8]
        
ApStage1End.WaitStage3:
        ;;
        ;; ���ڵȴ� stage3 ������
        ;;
        mov esi, [fs: SDA.Stage3LockPointer]
        call get_spin_lock                
        ;;
        ;; ���� stage3
        ;; 
        jmp [LONG_SEGMENT+8]


%endif

    

;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
;$      AP Stage1 Startup Routine       $
;$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$


        bits 16

times 4096 - ($ - $$)   DB      0


ApStage1Entry:

        cli
        cld

        ;;
        ;; real mode ��ʼ����
        ;;
        xor ax, ax
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov sp, BOOT_SEGMENT
        jmp WORD 0 : ApStage1Entry.Next
ApStage1Entry.Next:        
       
        ;;
        ;; ��� ApLock���Ƿ����� AP ���� startup routine ִ��
        ;;
        xor eax, eax
        xor esi, esi
        inc esi
        
        ;;
        ;; ���������
        ;;
AcquireApStage1Lock:
        lock cmpxchg [ApStage1Lock], esi
        jz AcquireApStage1LockOk
        
CheckApStage1Lock:
        mov eax, [ApStage1Lock]
        test eax, eax 
        jz AcquireApStage1Lock
        pause
        jmp CheckApStage1Lock
        

        
AcquireApStage1LockOk:
        ;;
        ;; AP stage1 ǰ�ڴ���
        ;;
        lock inc DWORD [CpuIndex]
        call check_cpu_environment
        call protected_mode_enter



        bits 32
        
%if 0
;; ������Ϊ���Զ����� !!
        call init_processor_control_block
        call init_apic
        call init_processor_basic_info
        call init_processor_topology_info
        call init_debug_capabilities_info
        call init_memory_type_manage
        call init_perfmon_unit


        ;;
        ;; ������ɼ���
        ;;
        lock inc DWORD [fs: SDA.ApInitDoneCount]
        ;;
        ;; ���ŵ�1�׶� AP Lock
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage1LockPointer]
        xchg [ebx], eax

call dump_trace_message
        ;;
        ;; ���ڵȴ� stage2 ��������
        ;;
        mov esi, [fs: SDA.Stage2LockPointer]
        call get_spin_lock

        ;;
        ;; ���� stage2
        ;;
        jmp [PROTECTED_SEGMENT+8]
        

%endif
        ;;
        ;; ת�� PCB ��ʼ��
        ;; 
        mov eax, PcbInitEntry
        jmp eax
        

   

;-----------------------------------------
; dump_trace_message():
; ˵��:
;       ��ӡ trace ��Ϣ
;-----------------------------------------
dump_trace_message:
        mov esi, Status.CpuIdMsg        
        call __puts
        mov esi, [gs: PCB.LogicalId]
        call __dump_hex
        mov esi, ','
        call __putc
        cmp DWORD [fs: SDA.ApLongmode], 1
        mov esi, Stage1.Msg2
        je dump_trace_message.@1
        mov esi, Stage1.Msg1
dump_trace_message.@1:
        call __puts
        ret




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ������ include �����ĺ���ģ��        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        bits 16
                
%include "..\lib\crt16.asm"                 
 
  
        bits 32
;;
;; �������ʹ���� stage1 �׶�
;;        
%include "..\lib\print.asm"
%include "..\lib\crt.asm"        
%include "..\lib\LocalVideo.asm"
%include "..\lib\system_data_manage.asm" 
%include "..\lib\mem.asm"
%include "..\lib\page32.asm"
%include "..\lib\apic.asm"
%include "..\lib\ioapic.asm"
%include "..\lib\pci.asm"
%include "..\lib\mtrr.asm"
%include "..\lib\debug.asm"
%include "..\lib\perfmon.asm"
%include "..\lib\pic8259a.asm"
%include "..\lib\smp.asm"
%include "..\lib\stage1.asm"
%include "..\lib\services.asm"
%include "..\lib\data.asm"





        [SECTION .data]
        ALIGN 16

;;
;; stage1 �� GDT �� TSS ����
;;
setup.Gdt     times (16*128)  DB 0
setup.Tss     times (16*128)  DB 0

        
;;
;; ģ�鳤��
;;
SETUP_LENGTH    EQU     $ - SETUP_SEGMENT



; end of setup        
