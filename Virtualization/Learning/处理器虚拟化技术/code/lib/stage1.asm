;*************************************************
; stage1.asm                                     *
; Copyright (c) 2009-2013 ��־                   *
; All rights reserved.                           *
;*************************************************




	bits 16

;-------------------------------------------------------------------
; set_stage1_gdt:
; input:
;       esi - GDT ���ַ 
; output:
;       eax - ���� GDT pointer
; ������
;       1) ��ʼ����ʱ�� GDT ����
;	2) �˺��������� 16 λ real-mode �� 
;-------------------------------------------------------------------
set_stage1_gdt:
        push edx
        add esi, 10h
        xor eax, eax

        ;;
        ;; ���û��� GDT ����
        ;; 1) entry 0:          NULL descriptor
        ;; 2) entry 1,2��       64-bit kernel code/data ������
        ;; 3) entry 3,4:        32-bit user code/data ������
        ;; 4) entry 5,6:        64-bit user code/data ������
        ;; 5) entry 7,8:        32-bit kernel code/data ������                
        ;; 6) entry 9,10:       fs/gs ��ʹ��
        ;; 

	    ;;		
        ;; NULL descriptor
        ;;
        mov [esi], eax
        mov [esi+4], eax

        ;;
        ;; 64-bit Kernel CS/SS ����������˵����
        ;; 1���� x64 ��ϵ����������������Ϊ��
        ;;      * CS = 00209800_00000000h (L=P=1, G=D=0, C=R=A=0)
        ;;      * SS = 00009200_00000000h (L=1, G=B=0, W=1, E=A=0)
        ;; 2) �� VMX �ܹ���, ��VM-exit ���� host ��Ὣ����������Ϊ��
        ;;      * CS = 00AF9B00_0000FFFFh (G=L=P=1, D=0, C=0, R=A=1, limit=4G)
        ;;      * SS = 00CF9300_0000FFFFh (G=P=1, B=1, E=0, W=A=1, limit=4G)
        ;;
        ;; 3) ��ˣ�Ϊ���� host �����������һ�£����ｫ��������Ϊ��
        ;;      * CS = 00AF9A00_0000FFFFh (G=L=P=1, D=0, C=A=0, R=1, limit=4G)
        ;;      * SS = 00CF9200_0000FFFFh (G=P=1, B=1, E=A=0, W=1, limit=4G)  
        ;
        mov DWORD [esi+KernelCsSelector64],   0000FFFFh
        mov DWORD [esi+KernelCsSelector64+4], 00AF9A00h
        mov DWORD [esi+KernelSsSelector64],   0000FFFFh
        mov DWORD [esi+KernelSsSelector64+4], 00CF9200h   

        ;;
        ;; 32-bit User CS/SS ������
        ;;
        mov DWORD [esi+UserCsSelector32],   0000FFFFh
        mov DWORD [esi+UserCsSelector32+4], 00CFFA00h
        mov DWORD [esi+UserSsSelector32],   0000FFFFh
        mov DWORD [esi+UserSsSelector32+4], 00CFF200h

        ;;
        ;; 64-bit User CS/SS ������
        ;;
        mov DWORD [esi+UserCsSelector64], eax
        mov DWORD [esi+UserCsSelector64+4], 0020F800h
        mov DWORD [esi+UserSsSelector64], eax
        mov DWORD [esi+UserSsSelector64+4], 0000F200h

        ;;
        ;; 32-bit Kernel CS/SS ������
        ;;
        mov DWORD [esi+KernelCsSelector32],   0000FFFFh
        mov DWORD [esi+KernelCsSelector32+4], 00CF9A00h
        mov DWORD [esi+KernelSsSelector32],   0000FFFFh
        mov DWORD [esi+KernelSsSelector32+4], 00CF9200h  

        ;;
        ;; FS base = 12_0000h, limit = 1M, DPL = 0
        ;;
        mov DWORD [esi+FsSelector],   0000FFFFh
        mov DWORD [esi+FsSelector+4], 000F9212h


        ;;
        ;; GS base = 10_0000h + index * PCB_SIZE
        ;;
        mov eax, PCB_SIZE
        mul DWORD [CpuIndex] 
        add eax, PCB_PHYSICAL_BASE
        mov [esi+GsSelector+4], eax
        mov WORD [esi+GsSelector],    0FFFFh
        mov [esi+GsSelector+2], eax
        mov WORD [esi+GsSelector+5],  0F92h

        ;;
        ;; TSS description
        ;;
        mov edx, [CpuIndex]
        shl edx, 7
        add edx, setup.Tss
        mov [esi+TssSelector32+4], edx
        mov WORD [esi+TssSelector32], 067h
        mov [esi+TssSelector32+2], edx
        mov WORD [esi+TssSelector32+5], 0089h

        ;;
        ;; ���� TSS ����
        ;;
        mov eax, [CpuIndex]
        shl eax, 13
        lea eax, [eax+KERNEL_STACK_PHYSICAL_BASE+0FF0h]
        mov WORD [edx+tss32.ss0], KernelSsSelector32
        mov [edx+tss32.esp0], eax
        mov WORD [edx+tss32.IomapBase], 0

        ;;
        ;; GDT pointer: ��ʱ GDT base ʹ�������ַ
        ;;
        lea eax, [esi-10h]
        mov WORD  [eax], 12 * 8 - 1		; GDT limit
        mov DWORD [eax+2], esi			; GDT base
        pop edx
        ret




	    bits 32

;-------------------------------------------------------------------
; set_global_gdt:
; input:
;       esi - GDT ��ַ
; output:
;       none
; ������
;       1) ��ʼ�� SDA ����� GDT ����
;	    2) �˺��������� 32 λ protected-mode ��
;-------------------------------------------------------------------
set_global_gdt:
        add esi, 10h
        xor eax, eax

        ;;
        ;; ���û��� GDT ����
        ;; 1) entry 0:          NULL descriptor
        ;; 2) entry 1,2��       64-bit kernel code/data ������
        ;; 3) entry 3,4:        32-bit user code/data ������
        ;; 4) entry 5,6:        64-bit user code/data ������
        ;; 5) entry 7,8:        32-bit kernel code/data ������                
        ;; 6) entry 9,10:       fs/gs ��ʹ��
        ;; 7) entry 11,12:      TSS ��������̬����
        ;; 

        ;;		
        ;; NULL descriptor
        ;;
        mov [esi], eax
        mov [esi+4], eax	


        ;;
        ;; 64-bit Kernel CS/SS ����������˵����
        ;; 1���� x64 ��ϵ����������������Ϊ��
        ;;      * CS = 00209800_00000000h (L=P=1, G=D=0, C=R=A=0)
        ;;      * SS = 00009200_00000000h (L=1, G=B=0, W=1, E=A=0)
        ;; 2) �� VMX �ܹ���, ��VM-exit ���� host ��Ὣ����������Ϊ��
        ;;      * CS = 00AF9B00_0000FFFFh (G=L=P=1, D=0, C=0, R=A=1, limit=4G)
        ;;      * SS = 00CF9300_0000FFFFh (G=P=1, B=1, E=0, W=A=1, limit=4G)
        ;;
        ;; 3) ��ˣ�Ϊ���� host �����������һ�£����ｫ��������Ϊ��
        ;;      * CS = 00AF9A00_0000FFFFh (G=L=P=1, D=0, C=A=0, R=1, limit=4G)
        ;;      * SS = 00CF9200_0000FFFFh (G=P=1, B=1, E=A=0, W=1, limit=4G)  
        ;
        mov DWORD [esi+KernelCsSelector64],   0000FFFFh
        mov DWORD [esi+KernelCsSelector64+4], 00AF9A00h
        mov DWORD [esi+KernelSsSelector64],   0000FFFFh
        mov DWORD [esi+KernelSsSelector64+4], 00CF9200h   

        ;;
        ;; 32-bit User CS/SS ������
        ;;
        mov DWORD [esi+UserCsSelector32],   0000FFFFh
        mov DWORD [esi+UserCsSelector32+4], 00CFFA00h
        mov DWORD [esi+UserSsSelector32],   0000FFFFh
        mov DWORD [esi+UserSsSelector32+4], 00CFF200h

        ;;
        ;; 64-bit User CS/SS ������
        ;;
        mov DWORD [esi+UserCsSelector64], eax
        mov DWORD [esi+UserCsSelector64+4], 0020F800h
        mov DWORD [esi+UserSsSelector64], eax
        mov DWORD [esi+UserSsSelector64+4], 0000F200h

        ;;
        ;; 32-bit Kernel CS/SS ������
        ;;
        mov DWORD [esi+KernelCsSelector32],   0000FFFFh
        mov DWORD [esi+KernelCsSelector32+4], 00CF9A00h
        mov DWORD [esi+KernelSsSelector32],   0000FFFFh
        mov DWORD [esi+KernelSsSelector32+4], 00CF9200h  

        ;;
        ;; FS base = 8002_0000h, limit = 1M, DPL = 0
        ;;
        mov DWORD [esi+FsSelector],   0000FFFFh
        mov DWORD [esi+FsSelector+4], 800F9202h
        mov DWORD [esi+GsSelector],   0000FFFFh
        mov DWORD [esi+GsSelector+4], 800F9200h 
	
        ;;
        ;; GS base = PCB.Base, limit = 1M, DPL = 0
        ;;
        mov eax, [gs: PCB.Base] 
        mov [esi+GsSelector+4], eax
        mov WORD [esi+GsSelector],    0FFFFh
        mov [esi+GsSelector+2], eax
        mov WORD [esi+GsSelector+5],  0F92h


        ;;
        ;; TSS description
        ;;
        mov eax, [gs: PCB.TssBase] 
        mov [esi+TssSelector32+4], eax
        mov DWORD [esi+TssSelector32+2], eax
        mov WORD [esi+TssSelector32+5], 0089h
        neg eax
        lea eax, [eax+SDA_BASE+SDA.Iomap+2000h-1]
        mov [esi+TssSelector32], ax

        ;;
        ;; GDT pointer: ��ʱ GDT base ʹ�������ַ
        ;;
        lea eax, [esi-10h]
        mov esi, [CpuIndex]
        shl esi, 8
        add esi, SDA_BASE+SDA.Gdt+10h
        mov WORD  [eax], 12 * 8 - 1		; GDT limit
        mov DWORD [eax+2], esi			; GDT base

        ;;
        ;; ע�⣬Ϊ����Ӧ�� 64-bit ������
        ;; 1) ����Ҫ���� longmode ʱ����Ҫ��������һ���յ� GDT ������ ��
        ;;
        cmp DWORD [fs: SDA.ApLongmode], 1
        jne set_global_gdt.@0
        mov DWORD [esi+TssSelector32+8], 0
        mov DWORD [esi+TssSelector32+12], 0
        mov WORD [eax], 13 * 8 - 1 
        
set_global_gdt.@0:
        ;;
        ;; ���� TSS ����
        ;;
        mov esi, [gs: PCB.TssPhysicalBase]
        mov ax, [fs: SDA.KernelSsSelector]
        mov [esi+tss32.ss0], ax
        
        ;;
        ;; ����һ�� kernel ʹ�õ� stack����Ϊ�жϷ�������ʹ��
        ;;
        mov eax, 2000h
        lock add [fs:SDA.KernelStackPhysicalBase], eax
        lock xadd [fs: SDA.KernelStackBase], eax
        add eax, 0FF0h
        mov [esi+tss32.esp0], eax
        
        add eax, 1000h
        mov [gs: PCB.KernelStack], eax
        mov DWORD [gs: PCB.KernelStack+4], 0FFFFF800h

        ;;
        ;; ���� IOmap ��ַ
        ;;
        mov eax, SDA_BASE+SDA.Iomap
        sub eax, [gs: PCB.TssBase]
        mov [esi+tss32.IomapBase], ax                           ; Iomap ƫ����
        ret


;-------------------------------------------------------------------
; init_system_data_area()
; input:
;       none
; output:
;       none
; ������
;       1) ��ʼ��ϵ�y��������SDA��
;       2) �˺���ִ���� 32-bit ����ģʽ��
;-------------------------------------------------------------------
init_system_data_area:
        push ecx
        push edx
        ;;
        ;; ��ַ˵����
        ;; 1) ���еĵ�ֵַʹ�� 64 λ
        ;; 2) �� 32 λʹ���� legacy ģʽ�£�ӳ�� 32 λֵ
        ;; 3) �� 32 λʹ���� 64-bit ģʽ�£�ӳ�� 64 λֵ
        ;;
        
        
        ;;
        ;; SDA ������Ϣ˵����
        ;; 1) SDA.Base ֵ��
        ;;      1.1) legacy �� SDA_BASE = 8002_0000h
        ;;      1.2) 64-bit �� SDA_BASE = ffff_f800_8000_0000h
        ;; 2) SDA.PhysicalBase ֵ��
        ;;      2.1) legacy �� 64-bit �±��ֲ��䣬Ϊ 12_0000h
        ;; 3) SDA.PcbBase ֵ��
        ;;      3.1) ָ�� BSP �� PCB ���򣬼���8000_0000h
        ;; 4) SDA.PcbPhysicalBase ֵ��
        ;;      4.1) ָ�� BSP �� PCB �����ַ������10_0000h
        ;;
        mov edx, 0FFFFF800h                                             ; 64 λ��ַ�еĸ� 32 λ
        xor ecx, ecx
        
        mov DWORD [fs: SDA.Base], SDA_BASE                              ; SDA �����ַ
        mov [fs: SDA.Base + 4], edx
        mov DWORD [fs: SDA.PhysicalBase], SDA_PHYSICAL_BASE             ; SDA �����ַ
        mov [fs: SDA.PhysicalBase + 4], ecx
        mov DWORD [fs: SDA.PcbBase], PCB_BASE                           ; ָ�� BSP �� PCB ����
        mov [fs: SDA.PcbBase + 4], edx
        mov DWORD [fs: SDA.PcbPhysicalBase], PCB_PHYSICAL_BASE          ; ָ�� BSP �� PCB ����
        mov [fs: SDA.PcbPhysicalBase + 4], ecx
        mov [fs: SDA.ProcessorCount], ecx                               ; �� processor count
        mov DWORD [fs: SDA.Size], SDA_SIZE                              ; SDA size
        mov DWORD [fs: SDA.VideoBufferHead], 0B8000h
        mov DWORD [fs: SDA.VideoBufferHead + 4], ecx
        mov DWORD [fs: SDA.VideoBufferPtr], 0B8000h
        mov DWORD [fs: SDA.VideoBufferPtr + 4], ecx
        mov DWORD [fs: SDA.TimerCount], ecx
        mov DWORD [fs: SDA.LastStatusCode], ecx
        mov DWORD [fs: SDA.UsableProcessorMask], ecx                    ; UsableProcessorMask ָʾ������
        mov DWORD [fs: SDA.ProcessMask], ecx                            ; process queue = 0��������
        mov DWORD [fs: SDA.ProcessMask + 4], ecx
        mov DWORD [fs: SDA.NmiIpiRequestMask], ecx
        
        ;;
        ;; ���������ڴ� size
        ;;
        mov eax, [MMap.Size]
        mov ecx, [MMap.Size + 4]
        shrd eax, ecx, 10                                               ; ת��Ϊ KB ��λ
        mov [fs: SDA.MemorySize], eax
               
        ;;
        ;; ����boot������
        ;;
        mov al, [7C03h]
        mov [fs: SDA.BootDriver], al
        
        ;;
        ;; �����Ҫ���� longmode ���� __X64 ����
        ;; 1��SDA.ApLongmode = 1 ʱ���������д��������� longmode ģʽ
        ;; 2) SDA.ApLongmode = 0 ʱ��ʹ�� legacy ����
        ;;
%ifdef  __X64
        mov DWORD [fs: SDA.ApLongmode], 1
%else
        mov DWORD [fs: SDA.ApLongmode], 0
%endif              
        
        
        ;;
        ;; ��ʼ�� PCB pool ��������¼
        ;; 1) PCB pool ������ÿ�� logical processor ����˽�е� PCB ��
        ;; 2) ��֧�� 16 �� logical processor
        ;; 3) PCB pool ��ַΪ PCB_BASE = 8000_0000h��PCB_POOL_SIZE = 128K
        ;; 4) PCB pool �����ַ PCB_PHYSICAL_BASE = 10_0000h
        ;;
        mov DWORD [fs: SDA.PcbPoolBase], PCB_BASE                       ; PCB pool ��ַ
        mov [fs: SDA.PcbPoolBase+4], edx
        mov DWORD [fs: SDA.PcbPoolPhysicalBase], PCB_PHYSICAL_POOL      ; PCB pool �����ַ
        mov DWORD [fs: SDA.PcbPoolPhysicalBase+4], ecx
        mov DWORD [fs: SDA.PcbPoolPhysicalTop], SDA_PHYSICAL_BASE-1     ; PCB pool ����
        mov DWORD [fs: SDA.PcbPoolPhysicalTop+4], ecx
        mov DWORD [fs: SDA.PcbPoolTop], PCB_BASE+PCB_POOL_SIZE-1
        mov DWORD [fs: SDA.PcbPoolTop+4], edx
        mov DWORD [fs: SDA.PcbPoolSize], PCB_POOL_SIZE
        
        ;;
        ;; ��ʼ�� TSS ���� pool ��¼
        ;; 1) TSS pool ����Ϊÿ�� logical processor ����˽�е� TSS ��
        ;; 2) ÿ�η���Ķ�� TssPoolGranularity = 100h �ֽ�
        ;;
        mov DWORD [fs: SDA.TssPoolBase], SDA_BASE + SDA.Tss             ; TSS pool ��ַ
        mov [fs: SDA.TssPoolBase+4], edx
        mov DWORD [fs: SDA.TssPoolPhysicalBase], SDA_PHYSICAL_BASE+SDA.Tss
        mov [fs: SDA.TssPoolPhysicalBase+4], ecx
        mov DWORD [fs: SDA.TssPoolTop], SDA_BASE+SDA.Tss+0FFFh          ; TSS pool ����
        mov DWORD [fs: SDA.TssPoolTop+4], edx
        mov DWORD [fs: SDA.TssPoolPhysicalTop], SDA_PHYSICAL_BASE+SDA.Tss+0FFFh
        mov DWORD [fs: SDA.TssPoolPhysicalTop+4], ecx
        mov DWORD [fs: SDA.TssPoolGranularity], 100h                    ; TSS ���������Ϊ 100h �ֽ�
        
        ;;
        ;; ���� GDT selector
        ;;
        mov WORD [fs: SDA.KernelCsSelector],   KernelCsSelector32
        mov WORD [fs: SDA.KernelSsSelector],   KernelSsSelector32
        mov WORD [fs: SDA.UserCsSelector],     UserCsSelector32
        mov WORD [fs: SDA.UserSsSelector],     UserSsSelector32
        mov WORD [fs: SDA.FsSelector],         FsSelector
        mov WORD [fs: SDA.SysenterCsSelector], KernelCsSelector32
        mov WORD [fs: SDA.SyscallCsSelector],  KernelCsSelector32
        mov WORD [fs: SDA.SysretCsSelector],   UserCsSelector32	

        ;;
        ;; ���� IDT pointer
        ;; 1) ��ʱ IDT base ʹ�������ַ
        ;;
        mov DWORD [fs: SDA.IdtBase], SDA_PHYSICAL_BASE+SDA.Idt
        mov [fs: SDA.IdtBase+4], edx
        mov WORD [fs: SDA.IdtLimit], 256 * 16 - 1                       ; Ĭ�ϱ��� 255 �� vector��Ϊ longmode �£�
        mov DWORD [fs: SDA.IdtTop], SDA_PHYSICAL_BASE+SDA.Idt           ; top ָ�� base
        mov [fs: SDA.IdtTop+4], edx
        
        ;;
        ;; ��ʼ SRT��ϵͳ�������̱���Ϣ
        ;;
        mov DWORD [fs: SRT.Base], SDA_BASE+SRT.Base                   ; SRT ��ַ
        mov [fs: SRT.Base+4], edx
        mov DWORD [fs: SRT.PhysicalBase], SDA_PHYSICAL_BASE + SRT.Base  ; SRT �����ַ
        mov [fs: SRT.PhysicalBase + 4], ecx
        mov DWORD [fs: SRT.Size], SRT_SIZE - SDA_SIZE
        mov DWORD [fs: SRT.Top], SRT_TOP
        mov DWORD [fs: SRT.Top + 4], edx
        mov DWORD [fs: SRT.Index], SDA_BASE + SRT.Entry
        mov DWORD [fs: SRT.Index + 4], edx
        mov DWORD [fs: SRT.ServiceRoutineVector], SYS_SERVICE_CALL      ; ϵͳ��������������
                

        ;;
        ;; ��ʼ�� paging ����ֵ��legacy ģʽ�£�
        ;;
        mov DWORD [fs: SDA.XdValue], 0                                  ; XD λ�� 0
        mov DWORD [fs: SDA.PtBase], PT_BASE                             ; PT ���ַΪ 0C0000000h
        mov DWORD [fs: SDA.PtTop], PT_TOP                               ; PT ����Ϊ 0C07FFFFFh
        mov DWORD [fs: SDA.PtPhysicalBase], PT_PHYSICAL_BASE            ; PT �������ַΪ 200000h
        mov DWORD [fs: SDA.PdtBase], PDT_BASE                           ; PDT ���ַΪ 0C0600000h
        mov DWORD [fs: SDA.PdtTop], PDT_TOP                             ; PDT ����Ϊ 0C0603FFFh        
        mov DWORD [fs: SDA.PdtPhysicalBase], PDT_PHYSICAL_BASE          ; PDT �������ַΪ 800000h
        
        ;;
        ;; ��ʼ legacy ģʽ�µ� PPT ��¼
        ;; 1) PPT �������ַ = SDA_PHYSICAL_BASE + SDA.Ppt
        ;; 2) PPT ���ַ = SDA_BASE + SDA.Ppt
        ;; 3) PPT ���� = SDA_BASE + SDA.Ppt + 31
        ;;
        mov DWORD [fs: SDA.PptPhysicalBase], PPT_PHYSICAL_BASE
        mov DWORD [fs: SDA.PptBase], PPT_BASE
        mov DWORD [fs: SDA.PptTop], PPT_TOP
      
        ;;
        ;; ��ʼ�� long-mode �µ� page ����ֵ
        ;;
        mov eax, 0FFFFF6FBh
        mov DWORD [fs: SDA.PtBase64], 0
        mov DWORD [fs: SDA.PtBase64 + 4], 0FFFFF680h
        mov DWORD [fs: SDA.PdtBase64], 40000000h
        mov DWORD [fs: SDA.PdtBase64 + 4], eax
        mov DWORD [fs: SDA.PptBase64], 7DA00000h
        mov DWORD [fs: SDA.PptBase64 + 4], eax
        mov DWORD [fs: SDA.PxtBase64], 7DBED000h
        mov DWORD [fs: SDA.PxtBase64 + 4], eax
        mov DWORD [fs: SDA.PtTop64], 0FFFFFFFFh
        mov DWORD [fs: SDA.PtTop64 + 4], 0FFFFF6FFh
        mov DWORD [fs: SDA.PdtTop64], 7FFFFFFFh
        mov DWORD [fs: SDA.PdtTop64 + 4], eax
        mov DWORD [fs: SDA.PptTop64], 7DBFFFFFh
        mov DWORD [fs: SDA.PptTop64 + 4], eax
        mov DWORD [fs: SDA.PxtTop64], 7DBEDFFFh
        mov DWORD [fs: SDA.PxtTop64 + 4], eax
        mov DWORD [fs: SDA.PxtPhysicalBase64], PXT_PHYSICAL_BASE64
        mov DWORD [fs: SDA.PxtPhysicalBase64 + 4], 0
        mov DWORD [fs: SDA.PptPhysicalBase64], PPT_PHYSICAL_BASE64
        mov DWORD [fs: SDA.PptPhysicalBase64 + 4], 0
        mov BYTE [fs: SDA.PptValid], 0
        
        ;;
        ;; PT pool �����¼:
        ;; 1) �� PT pool ����220_0000h - 2ff_ffffh��ffff_f800_8220_000h��
        ;; 2) ���� Pt pool ����20_0000h - 09f_ffffh��ffff_f800_8020_0000h��
        ;;
        mov DWORD [fs: SDA.PtPoolPhysicalBase], PT_POOL_PHYSICAL_BASE64
        mov DWORD [fs: SDA.PtPoolPhysicalBase + 4], 0
        mov DWORD [fs: SDA.PtPoolPhysicalTop], PT_POOL_PHYSICAL_TOP64
        mov DWORD [fs: SDA.PtPoolPhysicalTop + 4], 0
        mov DWORD [fs: SDA.PtPoolSize], PT_POOL_SIZE
        mov DWORD [fs: SDA.PtPoolSize + 4], 0
        mov DWORD [fs: SDA.PtPoolBase], 82200000h
        mov DWORD [fs: SDA.PtPoolBase + 4], 0FFFFF800h
        
        mov DWORD [fs: SDA.PtPool2PhysicalBase], PT_POOL2_PHYSICAL_BASE64
        mov DWORD [fs: SDA.PtPool2PhysicalBase + 4], 0
        mov DWORD [fs: SDA.PtPool2PhysicalTop], PT_POOL2_PHYSICAL_TOP64
        mov DWORD [fs: SDA.PtPool2PhysicalTop + 4], 0
        mov DWORD [fs: SDA.PtPool2Size], PT_POOL2_SIZE
        mov DWORD [fs: SDA.PtPool2Size + 4], 0
        mov DWORD [fs: SDA.PtPool2Base], 80200000h
        mov DWORD [fs: SDA.PtPool2Base + 4], 0FFFFF800h
        
        mov BYTE [fs: SDA.PtPoolFree], 1
        mov BYTE [fs: SDA.PtPool2Free], 1

        ;;
        ;; VMX Ept(extended page table)�����¼
        ;; 1) PXT ������FFFF_F800_C0A0_0000h - FFFF_F800_C0BF_FFFFh(A0_0000h - BF_FFFFh)
        ;; 2) PPT �������� SDA ��
        ;;
        mov eax, [fs: SDA.Base]
        mov edx, [fs: SDA.PhysicalBase]
        add eax, SDA.EptPxt - SDA.Base
        add edx, SDA.EptPxt - SDA.Base        
        mov DWORD [fs: SDA.EptPxtBase64], eax
        mov DWORD [fs: SDA.EptPxtPhysicalBase64], edx
        mov DWORD [fs: SDA.EptPptBase64], 0C0A00000h
        mov DWORD [fs: SDA.EptPptPhysicalBase64], 0A00000h
        add eax, (200000h - 1)
        mov DWORD [fs: SDA.EptPxtTop64], eax
        mov DWORD [fs: SDA.EptPptTop64], 0C0BFFFFFh
                
        mov DWORD [fs: SDA.EptPxtBase64 + 4], 0FFFFF800h
        mov DWORD [fs: SDA.EptPxtPhysicalBase64 + 4], 0
        mov DWORD [fs: SDA.EptPptBase64 + 4], 0FFFFF800h
        mov DWORD [fs: SDA.EptPptPhysicalBase64 + 4], 0
        mov DWORD [fs: SDA.EptPxtTop64 + 4], 0FFFFF800h
        mov DWORD [fs: SDA.EptPptTop64 + 4], 0FFFFF800h
        
        
        
        ;;
        ;; ��ʼ�� stack �� pool ������Ϣ
        ;; 1) legacy �£� KERNEL_STACK_BASE  = ffe0_0000h
        ;;                USER_STACK_BASE    = 7fe0_0000h
        ;;                KERNEL_POOL_BASE   = 8320_0000h
        ;;                USER_POOL_BASE     = 7300_1000h
        ;;
        ;; 2) 64-bit ��:  KERNEL_STACK_BASE64 = ffff_ff80_ffe0_0000h
        ;;                USER_STACK_BASE64   = 0000_0000_7fe0_0000h
        ;;                KERNEL_POOL_BASE64  = ffff_f800_8320_0000h
        ;;                USER_POOL_BASE64    = 0000_0000_7300_1000h
        ;;
        ;; 3) �����ַ:   KERNEL_STACK_PHYSICAL_BASE = 0104_0000h
        ;;               USER_STACK_PHYSICAL_BASE    = 0101_0000h
        ;;               KERNEL_POOL_PHYSICAL_BASE   = 0320_0000h
        ;;               USER_POOL_PHYSICAL_BASE     = 0300_1000h
        ;;
        xor ecx, ecx
        mov DWORD [fs: SDA.UserStackBase], USER_STACK_BASE
        mov [fs: SDA.UserStackBase+4], ecx
        mov DWORD [fs: SDA.UserStackPhysicalBase], USER_STACK_PHYSICAL_BASE
        mov [fs: SDA.UserStackPhysicalBase + 4], ecx
        mov DWORD [fs: SDA.KernelStackBase], KERNEL_STACK_BASE
        mov DWORD [fs: SDA.KernelStackBase + 4], 0FFFFFF80h
        mov DWORD [fs: SDA.KernelStackPhysicalBase], KERNEL_STACK_PHYSICAL_BASE
        mov [fs: SDA.KernelStackPhysicalBase + 4], ecx
        mov DWORD [fs: SDA.UserPoolBase], USER_POOL_BASE
        mov [fs: SDA.UserPoolBase + 4], ecx
        mov DWORD [fs: SDA.UserPoolPhysicalBase], USER_POOL_PHYSICAL_BASE
        mov [fs: SDA.UserPoolPhysicalBase + 4], ecx
        mov DWORD [fs: SDA.KernelPoolBase], KERNEL_POOL_BASE
        mov DWORD [fs: SDA.KernelPoolBase + 4], 0FFFFF800h
        mov DWORD [fs: SDA.KernelPoolPhysicalBase], KERNEL_POOL_PHYSICAL_BASE
        mov [fs: SDA.KernelPoolPhysicalBase + 4], ecx

        ;;
        ;; ��ʼ�� BTS Pool �� PEBS pool �����¼
        ;;
        mov edx, 0FFFFF800h
        mov ebx, [fs: SDA.Base]
        lea eax, [ebx + SDA.BtsBuffer]
        mov [fs: SDA.BtsPoolBase], eax                          ; BTS Pool ��ַ
        mov [fs: SDA.BtsPoolBase + 4], edx
        add eax, 0FFFh                                          ; 4K size
        mov DWORD [fs: SDA.BtsBufferSize], 100h                 ; ÿ�� BTS buffer Ĭ��Ϊ 100h 
        mov [fs: SDA.BtsPoolTop], eax                           ; BTS pool ����
        mov [fs: SDA.BtsPoolTop + 4], edx
        mov DWORD [fs: SDA.BtsRecordMaximum], 10                ; ÿ�� BTS buffer ������� 10 ����¼
        lea eax, [ebx + SDA.PebsBuffer]
        mov [fs: SDA.PebsPoolBase], eax                         ; PEBS Pool ��ַ
        mov [fs: SDA.PebsPoolBase + 4], edx
        add eax, 3FFFh                                          ; 16K size
        mov DWORD [fs: SDA.PebsBufferSize], 400h                ; ÿ�� PEBS buffer Ĭ��Ϊ 400h
        mov [fs: SDA.PebsPoolTop], eax                          ; PEBS pool ����
        mov [fs: SDA.PebsPoolTop + 4], edx
        mov DWORD [fs: SDA.PebsRecordMaximum], 5                ; ÿ�� Pebs buffer ������� 5 ����¼
        
        
        ;;
        ;; ��ʼ�� VM domain pool �����¼
        ;;
        mov DWORD [fs: SDA.DomainPhysicalBase], DOMAIN_PHYSICAL_BASE
        mov DWORD [fs: SDA.DomainPhysicalBase + 4], 0
        mov DWORD [fs: SDA.DomainBase], DOMAIN_BASE
        mov DWORD [fs: SDA.DomainBase + 4], 0FFFFF800h
        
        ;;
        ;; ��ʼ�� GPA ӳ���б�����¼
        ;;
        mov eax, SDA_BASE + SDA.GpaMappedList
        mov [fs: SDA.GmlBase], eax
        mov DWORD [fs: SDA.GmlBase + 4], 0FFFFF800h

%ifdef DEBUG_RECORD_ENABLE
        ;;
        ;; ��ʼ�� DRS �����¼
        ;; 1) DrsBase = DrsBuffer
        ;; 2) DrsHeadPtr = DrsTailPtr = DrsBuffer
        ;; 3) DrsIndex = DrsBuffer
        ;; 4) DrsCount = 0
        ;;
        mov eax, [fs: SDA.Base]
        lea eax, [eax + SDA.DrsBuffer]
        mov [fs: SDA.DrsBase], eax
        mov DWORD [fs: SDA.DrsBase + 4], 0FFFFF800h
        mov [fs: SDA.DrsHeadPtr], eax
        mov DWORD [fs: SDA.DrsHeadPtr + 4], 0FFFFF800h
        mov [fs: SDA.DrsTailPtr], eax
        mov DWORD [fs: SDA.DrsTailPtr + 4], 0FFFFF800h        
        mov [fs: SDA.DrsIndex], eax
        mov DWORD [fs: SDA.DrsIndex + 4], 0FFFFF800h
        mov DWORD [fs: SDA.DrsCount], 0
        add eax, MAX_DRS_COUNT * DRS_SIZE
        mov [fs: SDA.DrsTop], eax
        mov DWORD [fs: SDA.DrsTop + 4], 0FFFFF800h        
        mov DWORD [fs: SDA.DrsMaxCount], MAX_DRS_COUNT
        
        ;;
        ;; ��ʼ��ͷ�ڵ� PrevDrs �� NextDrs
        ;;
        mov edx, [fs: SDA.PhysicalBase]
        add edx, SDA.DrsBuffer
        xor eax, eax
        mov [edx + DRS.PrevDrs], eax
        mov [edx + DRS.PrevDrs + 4], eax
        mov [edx + DRS.NextDrs], eax
        mov [edx + DRS.NextDrs + 4], eax      
        mov DWORD [edx + DRS.RecordNumber], 0
%endif        
        

        ;;
        ;; ��ʼ�� DMB ��¼
        ;;
        mov eax, [fs: SDA.Base]
        add eax, SDA.DecodeManageBlock
        mov [fs: SDA.DmbBase], eax
        mov DWORD [fs: SDA.DmbBase + 4], 0FFFFF800h
        add eax, DMB.DecodeBuffer
        mov edx, [fs: SDA.PhysicalBase]
        mov [edx + SDA.DecodeManageBlock + DMB.DecodeBufferHead], eax
        mov [edx + SDA.DecodeManageBlock + DMB.DecodeBufferPtr], eax
        mov DWORD [edx + SDA.DecodeManageBlock + DMB.DecodeBufferHead + 4], 0FFFFF800h
        mov DWORD [edx + SDA.DecodeManageBlock + DMB.DecodeBufferPtr + 4], 0FFFFF800h        
        
        ;;
        ;; ��ʼ�� EXTINT_RTE �����¼
        ;;
        mov eax, [fs: SDA.Base]
        add eax, SDA.ExtIntRteBuffer
        mov [fs: SDA.ExtIntRtePtr], eax
        mov DWORD [fs: SDA.ExtIntRtePtr + 4], 0FFFFF800h
        mov [fs: SDA.ExtIntRteIndex], eax
        mov DWORD [fs: SDA.ExtIntRteIndex + 4], 0FFFFF800h
        mov DWORD [fs: SDA.ExtIntRteCount], 0
        
        ;;
        ;; ���� pic8259 ���쳣�������̣�ȱʡ���жϷ�������
        ;;
        call setup_pic8259
        call install_default_exception_handler
        call install_default_interrupt_handler        
                
        ;;
        ;; ���� AP �� startup routine ��ڵ�ַ
        ;;
        mov eax, ApStage1Entry
        mov [fs: SDA.ApStartupRoutineEntry], eax
        mov DWORD [fs: SDA.Stage1LockPointer], ApStage1Lock
        mov DWORD [fs: SDA.Stage2LockPointer], ApStage2Lock
        mov DWORD [fs: SDA.Stage3LockPointer], ApStage3Lock
        mov DWORD [fs: SDA.ApStage], 0
        
        pop edx
        pop ecx
        ret
        




;-------------------------------------------------------------------
; alloc_pcb_base()
; input:
;       none
; output:
;       eax - PCB �����ַ
;       edx - PCB �����ַ
; ������
;       1) ÿ���������� PCB ��ַʹ�� alloc_pcb_base() ������
;       2) edx:eax - ���� PCB ��������ַ�Ͷ�Ӧ�������ַ
;       2) �� stage1��legacy ��δ��ҳ��ʹ��
;-------------------------------------------------------------------
alloc_pcb_base:
        push ebx
        mov eax, [CpuIndex]
        mov ebx, PCB_SIZE
        mul ebx
        mov edx, eax
        add edx, [fs: SDA.PcbPoolBase]
        add eax, [fs: SDA.PcbPoolPhysicalBase]
        mov ebx, eax
        mov esi, PCB_SIZE
        mov edi, eax
        call zero_memory
        mov eax, ebx                        
        pop ebx
        ret



;-------------------------------------------------------------------
; alloc_tss_base()
; input:
;       none
; output:
;       eax - Tss �������ַ
;       edx - Tss �������ַ
; ����:
;       1) �� TSS POOL �����һ�� TSS ��ռ�       
;       2) ��� TSS Pool ���꣬����ʧ�ܣ����� 0 ֵ
;       3) �� stage1 �׶ε���
;-------------------------------------------------------------------
alloc_tss_base:
        push ebx
        mov eax, [CpuIndex]
        shl eax, 8                              ; CpuIndex * 100h
        mov edx, eax
        add edx, [fs: SDA.TssPoolBase]
        add eax, [fs: SDA.TssPoolPhysicalBase]
        mov edi, ebx
        mov esi, 100h
        call zero_memory
        mov eax, ebx
        pop ebx
        ret
        


;-------------------------------------------------------------------
; alloc_stage1_kernel_stack_4k_base()
; input:
;       none
; output:
;       eax - stack base
; ������
;       1) ���� stage1 �׶�ʹ�õ� kernel stack
;-------------------------------------------------------------------
alloc_stage1_kernel_stack_4k_base:
        mov eax, 4096
        mov edx, eax
        lock xadd [fs: SDA.KernelStackPhysicalBase], eax
        lock xadd [fs: SDA.KernelStackBase], edx 
        ret


;-------------------------------------------------------------------
; alloc_stage1_kernel_pool_base()
; input:
;       esi - ҳ����
; output:
;       eax - �����ַ
;       edx - �����ַ
; ������
;       1) �ڡ�stage1 �׶η���� kernel pool
;       2) ���������ַ
;-------------------------------------------------------------------
alloc_stage1_kernel_pool_base:
        push ecx
        lea ecx, [esi - 1]
        mov eax, 4096
        shl eax, cl
        mov edx, eax
        lock xadd [fs: SDA.KernelPoolBase], eax 
        lock xadd [fs: SDA.KernelPoolPhysicalBase], edx
        pop ecx
        ret
        
        

;-----------------------------------------------------------------------
; init_processor_control_block()
; input:
;       none
; output:
;       none
; ����:
;       1) ��ʼ���������� PCB ����
;-----------------------------------------------------------------------
init_processor_control_block:
        push edx
        push ecx
        push ebx
        
        ;;
        ;; ���� PCB ��ַ
        ;;
        call alloc_pcb_base                             ; edx:eax = VA:PA
        mov [gs: PCB.PhysicalBase], eax
        mov [gs: PCB.Base], edx
        mov DWORD [gs: PCB.PhysicalBase+4], 0
        mov DWORD [gs: PCB.Base+4], 0FFFFF800h
        mov ebx, edx

        ;;
        ;; ���� TSS ��
        ;;
        call alloc_tss_base                             ; edx:eax ���� VA:PA 
        mov [gs: PCB.TssPhysicalBase], eax
        mov [gs: PCB.TssBase], edx
        mov DWORD [gs: PCB.TssPhysicalBase+4], 0
        mov DWORD [gs: PCB.TssBase+4], 0FFFFF800h
        mov DWORD [gs: PCB.TssLimit], (1000h+2000h-1)
        mov DWORD [gs: PCB.IomapBase], SDA_BASE+SDA.Iomap
        mov DWORD [gs: PCB.IomapBase+4], 0FFFFF800h
        mov DWORD [gs: PCB.IomapPhysicalBase], SDA_PHYSICAL_BASE+SDA.Iomap      

        ;;
        ;; ���� GDT ��
        ;;
        mov eax, [CpuIndex]
        shl eax, 8
        lea esi, [eax+SDA_PHYSICAL_BASE+SDA.Gdt]
        lea eax, [eax+SDA_BASE+SDA.Gdt]
        mov [gs: PCB.GdtPointer], eax
        mov DWORD [gs: PCB.GdtPointer+4], 0FFFFF800h
        call set_global_gdt

        ;;
        ;; Gs/Tss selector
        ;;
        mov WORD [gs: PCB.GsSelector], GsSelector
        mov WORD [gs: PCB.TssSelector], TssSelector32 

        ;;
        ;; ���� PCB ������¼
        ;; 1) ��ַ�ĸ� 32 λʹ���� 64-bit ģʽ��
 
        mov DWORD [gs: PCB.Size], PCB_SIZE
        mov eax, [fs: SDA.Base]
        mov [gs: PCB.SdaBase], eax                      ; ָ�� SDA ����
        mov DWORD [gs: PCB.SdaBase+4], 0FFFFF800h
        add eax, SRT.Base                               ; SRT �����ַ��λ�� SDA ֮��
        mov [gs: PCB.SrtBase], eax                      ; ָ�� System Service Routine Table ����    
        mov DWORD [gs: PCB.SrtBase+4], 0FFFFF800h
        mov eax, [fs: SDA.PhysicalBase]     
        mov [gs: PCB.SdaPhysicalBase], eax
        add eax, SRT.Base
        mov [gs: PCB.SrtPhysicalBase], eax
        mov eax, [gs: PCB.PhysicalBase]
        add eax, PCB.Ppt
        mov [gs: PCB.PptPhysicalBase], eax

        ;;
        ;; ���� ReturnStackPointer
        ;;
        lea eax, [ebx+PCB.ReturnStack]
        mov [gs: PCB.ReturnStackPointer], eax
        mov DWORD [gs: PCB.ReturnStackPointer+4], 0FFFFF800h
        
        ;;
        ;; ȱʡ�� TPR ����Ϊ 3
        ;;
        mov BYTE [gs: PCB.CurrentTpl], INT_LEVEL_THRESHOLD
        mov BYTE [gs: PCB.PrevTpl], 0
        

        ;;
        ;; ���� LDT ������Ϣ
        ;; ע�⣺
        ;; 1) LDT ��ʱΪ�գ�����ʹ�������ַ
        ;; 2) ��ַ�� 32 λʹ���� 64-bit ģʽ��
        ;;
        mov DWORD [gs: PCB.LdtBase], SDA_BASE+SDA.Ldt
        mov DWORD [gs: PCB.LdtBase+4], 0FFFFF800h
        mov DWORD [gs: PCB.LdtTop], SDA_BASE+SDA.Ldt
        mov DWORD [gs: PCB.LdtTop+4], 0FFFFF800h
        

        
        ;;
        ;; ���� context ����ָ��
        ;; 1) �� stage1 ʹ�������ַ
        ;;
        lea eax, [ebx+PCB.Context]
        mov [gs: PCB.ContextBase], eax
        lea eax, [ebx+PCB.XMMStateImage]
        mov [gs: PCB.XMMStateImageBase], eax

        ;;
        ;; ���䱾�ش洢��
        ;;
        mov esi, LSB_SIZE+0FFFh
        shr esi, 12
        call alloc_stage1_kernel_pool_base                              ; edx:eax = PA:VA
        mov [gs: PCB.LsbBase], eax
        mov DWORD [gs: PCB.LsbBase+4], 0FFFFF800h
        mov [gs: PCB.LsbPhysicalBase], edx
        mov DWORD [gs: PCB.LsbPhysicalBase+4], 0        
        mov ecx, eax                                                    ; ecx = LSB
        
        ;;
        ;; ��� LSB ��
        ;;
        mov esi, LSB_SIZE
        mov edi, edx
        call zero_memory
                
        ;;
        ;; ���� LSB ������Ϣ
        ;;
        mov [edx+LSB.Base], ecx
        mov DWORD [edx+LSB.Base+4], 0FFFFF800h                      ; LSB.Base
        mov [edx+LSB.PhysicalBase], edx
        mov DWORD [edx+LSB.PhysicalBase+4], 0                       ; LSB.PhysicalBase
        
        ;;
        ;; local video buffer ��¼
        ;;
        lea esi, [ecx+LSB.LocalVideoBuffer]
        mov [edx+LSB.LocalVideoBufferHead], esi
        mov DWORD [edx+LSB.LocalVideoBufferHead+4], 0FFFFF800h      ; LSB.LocalVideoBufferHead
        mov [edx+LSB.LocalVideoBufferPtr], esi
        mov DWORD [edx+LSB.LocalVideoBufferPtr+4], 0FFFFF800h       ; LSB.LocalVideoBufferPtr
        
        ;;
        ;; local keyboard buffer ��¼
        ;;
        lea esi, [ecx+LSB.LocalKeyBuffer]
        mov [edx+LSB.LocalKeyBufferHead], esi
        mov DWORD [edx+LSB.LocalKeyBufferHead+4], 0FFFFF800h        ; LSB.LocalKeyBufferHead
        mov [edx+LSB.LocalKeyBufferPtr], esi
        mov DWORD [edx+LSB.LocalKeyBufferPtr+4], 0FFFFF800h         ; LSB.LocalKeyBufferPtr 
        mov DWORD [edx+LSB.LocalKeyBufferSize], 256                   ; LSB.LocalKeyBufferPtr = 256
               
        
        ;;
        ;; ���� VMCS ����ָ�루����ָ�룩
        ;; 1) VmcsA ָ�� GuestA
        ;; 2) VmcsB ָ�� GuestB
        ;; 3) VmcsC ָ�� GuestC
        ;; 4) VmcsD ָ�� GuestD
        ;;
        mov edx, 0FFFFF800h
        mov ecx, [gs: PCB.Base]
        lea eax, [ecx+PCB.GuestA]
        mov [gs: PCB.VmcsA], eax
        mov [gs: PCB.VmcsA+4], edx
        lea eax, [ecx+PCB.GuestB]
        mov [gs: PCB.VmcsB], eax
        mov [gs: PCB.VmcsB+4], edx        
        lea eax, [ecx+PCB.GuestC]
        mov [gs: PCB.VmcsC], eax
        mov [gs: PCB.VmcsC+4], edx     
        lea eax, [ecx+PCB.GuestD]
        mov [gs: PCB.VmcsD], eax
        mov [gs: PCB.VmcsD+4], edx                             
        

        ;;
        ;; ���´�����״̬
        ;; 
        lidt [fs: SDA.IdtPointer]
        mov eax, CPU_STATUS_PE
        or DWORD [gs: PCB.ProcessorStatus], eax
                
        pop ebx
        pop ecx
        pop edx
        ret



;-----------------------------------------------------------------------
; install_default_exception_handler()
; input:
;       none
; output:
;       none
; ������
;       1) ��װĬ�ϵ��쳣��������
;-----------------------------------------------------------------------
install_default_exception_handler:
        push ecx
        xor ecx, ecx
install_default_exception_handler.loop:        
        mov esi, ecx
        mov edi, [ExceptionHandlerTable+ecx*8]
        call install_kernel_interrupt_handler32
        inc ecx
        cmp ecx, 20
        jb install_default_exception_handler.loop
        pop ecx
        ret
        
        
        
;-----------------------------------------------------
; local_interrupt_default_handler()
; ������
;       �������� local �ж�Դȱʡ��������
;-----------------------------------------------------
local_interrupt_default_handler:
        push ebp
        push eax
        
%ifdef __X64
        LoadGsBaseToRbp
%else
        mov ebp, [gs: PCB.Base]
%endif

        test DWORD [ebp+PCB.ProcessorStatus], CPU_STATUS_PG
        REX.Wrxb
        mov eax, [ebp+PCB.LapicBase]
        REX.Wrxb
        cmovz eax, [ebp+PCB.LapicPhysicalBase]
        mov DWORD [eax+ESR], 0
        mov DWORD [eax+EOI], 0
        pop eax
        pop ebp
        REX.Wrxb
        iret        



;-----------------------------------------------------
; install_default_interrupt_handler()
; ����:
;       ��װĬ�ϵ��жϷ�������
;-----------------------------------------------------
install_default_interrupt_handler:
        push ecx
        xor ecx, ecx
        
        ;;
        ;; ˵��:
        ;; 1) ��װ local vector table ��������
        ;; 2) ��װ IPI ��������
        ;; 3) ��װϵͳ��������(40h �жϵ��ã�
        ;;
     
        ;;
        ;; ��װȱʡ�� local �ж�Դ��������
        ;;
        call install_default_local_interrupt_handler

        ;;
        ;; PIC8259 ��Ӧ���жϷ�������
        ;;
        mov esi, PIC8259A_IRQ0_VECTOR
        mov edi, timer_8259_handler
        call install_kernel_interrupt_handler32

        mov esi, PIC8259A_IRQ1_VECTOR
        mov edi, keyboard_8259_handler
        call install_kernel_interrupt_handler32

%if 0
        call init_ioapic_keyboard
%endif

        ;;
        ;; ���� IRQ1 �жϷ�������
        ;;
        mov esi, IOAPIC_IRQ1_VECTOR
        mov edi, ioapic_keyboard_handler
        call install_kernel_interrupt_handler32

        
        ;;
        ;; ��װ IPI ��������
        ;;       
        mov esi, IPI_VECTOR
        mov edi, dispatch_routine
        call install_kernel_interrupt_handler32
        
        mov esi, IPI_ENTRY_VECTOR
        mov edi, goto_entry
        call install_kernel_interrupt_handler32

        ;;
        ;; ��װϵͳ���÷�������
        ;;
        mov esi, [fs: SRT.ServiceRoutineVector]
        mov edi, sys_service_routine
        call install_user_interrupt_handler32

        pop ecx
        ret
         


;-----------------------------------------------------
; install_default_local_interrupt_handler()
; ������
;       ��װȱʡ local interrupt
;-----------------------------------------------------
install_default_local_interrupt_handler:
        mov esi, LAPIC_PERFMON_VECTOR
        mov edi, local_interrupt_default_handler
        call install_kernel_interrupt_handler32
        
        mov esi, LAPIC_TIMER_VECTOR
        mov edi, local_interrupt_default_handler
        call install_kernel_interrupt_handler32
        
        mov esi, LAPIC_ERROR_VECTOR
        mov edi, local_interrupt_default_handler
        call install_kernel_interrupt_handler32       
        ret




        

;-----------------------------------------------------
; wait_for_ap_stage1_done()
; input:
;       none
; output:
;       none
; ������
;       1) ���� INIT-SIPI-SIPI ��Ϣ��� AP
;       2) �ȴ� AP ��ɵ�1�׶ι���
;-----------------------------------------------------
wait_for_ap_stage1_done:
        push ebx
        push edx
        
        ;;
        ;; local APIC ��1�׶�ʹ�������ַ
        ;;
        mov ebx, [gs: PCB.LapicPhysicalBase]
        
        ;;
        ;; ���� IPIs��ʹ�� INIT-SIPI-SIPI ����
        ;; 1) �� SDA.ApStartupRoutineEntry ��ȡ startup routine ��ַ
        ;;      
        mov DWORD [ebx+ICR0], 000c4500h                         ; ���� INIT IPI, ʹ���� processor ִ�� INIT
        mov esi, 10 * 1000                                      ; ��ʱ 10ms
        call delay_with_us
        
        ;;
        ;; ���淢������ SIPI��ÿ����ʱ 200us
        ;; 1) ��ȡ Ap Startup Routine ��ַ
        ;;
        mov edx, [fs: SDA.ApStartupRoutineEntry]
        shr edx, 12                                             ; 4K �߽�
        and edx, 0FFh
        or edx, 000C4600h                                       ; Start-up IPI

        ;;
        ;; �״η��� SIPI
        ;;
        mov DWORD [ebx+ICR0], edx                               ; ���� Start-up IPI
        mov esi, 200                                            ; ��ʱ 200us
        call delay_with_us
        
        ;;
        ;; �ٴη��� SIPI
        ;;
        mov DWORD [ebx+ICR0], edx                               ; �ٴη��� Start-up IPI
        mov esi, 200
        call delay_with_us

        ;;
        ;; ���ŵ�1�׶� AP Lock
        ;;
        xor eax, eax
        mov ebx, [fs: SDA.Stage1LockPointer]
        xchg [ebx], eax

        ;;
        ;; BSP ����ɹ���, ����ֵΪ 1
        ;;
        mov DWORD [fs: SDA.ApInitDoneCount], 1

        ;;
        ;; �ȴ� AP ��� stage1 ����:
        ;; ��鴦�������� ProcessorCount �Ƿ���� LocalProcessorCount ֵ
        ;; 1)�ǣ����� AP ��� stage1 ����
        ;; 2)���ڵȴ�
        ;;
wait_for_ap_stage1_done.@0:        
        xor eax, eax
        lock xadd [fs: SDA.ApInitDoneCount], eax
        cmp eax, CPU_COUNT_MAX
        jae wait_for_ap_stage1_done.ok
        cmp eax, [gs: PCB.LogicalProcessorCount]
        jae wait_for_ap_stage1_done.ok
        pause
        jmp wait_for_ap_stage1_done.@0
         
wait_for_ap_stage1_done.ok:
        ;;
        ;;  AP ���� stage1 ״̬
        ;;
        mov DWORD [fs: SDA.ApStage], 1
        pop edx
        pop ebx
        ret
        



