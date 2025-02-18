.model tiny
extrn InitKeyDisplay:near, GetKeyA:near, Display8:near
;8259a�˿�
_8259_0 equ 0250h
_8259_1 equ 0251h
;8253�˿�
_8253_0 equ 0260h
_8253_1 equ 0261h
_8253_2 equ 0262h
_8253_ct equ 0263h
;8255�˿�
_8255_pa equ 0270h
_8255_pb equ 0271h
_8255_pc equ 0272h
_8255_ct equ 0273h

.stack 100
.data
    buffer db 8 dup(0); �������ʾ������
    bfi db 0; �Ƿ������������(0:����, 1:��ͣ)
    bclockwise db 0; ����(0: ��ʱ��, 1:˳ʱ��)
    bneeddisplay db 0; ��һ����, �Ƿ���Ҫ��ʾ 
    stepcontrol db 0; �������������һ��ֵ
    setcount db 0; ���ò��������ֵ, �粽������ת��
    stepcount dw 0; �������ʾ�Ĳ���ֵ
    setstep db 0; ���ò��� 
    setspeed db 0; ����ת��
    count dw 20000; 8253������ֵ, �������ӵ�ϵͳclkΪ1M,��1us��һ��ʱ���ź�
                 ; ��5100 * 1us = 5.1ms = 0.0051s/��
    styletype db 0;ת����ʽ(4��, ˫4��, ��8��)
    ; 11hΪ���ĵĳ�ֵ, 33hΪ˫���ĵĳ�ֵ, ʣ��Ϊ�����ĵ�һ��ֵ
    control db 11h, 33h, 10h, 30h, 20h, 60h, 40h, 0c0h, 80h, 90h
    done db 0; ���õĲ����Ƿ�����

.code
main:
    ;��ʼ�����ݶκ�ջ��
    mov ax, @data
    mov ds, ax
    mov es, ax
    nop
    ;һϵ�г�ʼ��
    call InitKeyDisplay
    call init8255
    call init8253
    call init8259
    call wriIntver

    ;��ʼ������ܺͲ������
    mov bfi, 1; δ�������
    mov bl, styletype; ���幤����ʽ(4��, ˫4��, ��8��)
    lea si, control; 
    mov al, [si + bx]; (��4��)->11h, (˫4��)->33h, (��˫8��)->10h
    mov stepcontrol, al;
    ;��ʼ��ʾD99 0000
    mov buffer, 0
    mov buffer + 1, 0
    mov buffer + 2, 0
    mov buffer + 3, 0
    mov buffer + 4, 10h
    mov buffer + 5, 9
    mov buffer + 6, 9
    mov buffer + 7, 0dh
    mov bclockwise, 1;��ʼĬ��˳ʱ��
    ;���ת����ʽ
check_styletype:
    ;��C�˿�
    mov dx, _8255_pc;
    in al, dx; 
    ;Ҫ��3λ�͵�2λ�ж�ת����ʽ
    ror al, 2
    and al, 3
    mov styletype, al;����ת����ʽ
    cmp styletype, 3
    jz check_styletype;ֻ��0, 1, 2���ַ�ʽ
    ;��ʾ������Լ���ȡ��ֵ
start1:
    lea si, buffer
    call Display8; ��ʾ8λ�����
check_key:
    call GetKeyA; ��ð���
    ;20ms����(�����)
    ; mov cx, 20000
    ; loop $
    jc start2; cf=1��ʾ�а���, al=����
    cmp bneeddisplay, 0; �ް���, �鿴�Ƿ�ת��������ʾ
    jz check_key; ����Ҫ��ʾ�͵ȴ���ֵ����
    ;��Ҫ��ʾ
    mov bneeddisplay, 0; ��ǰ�Ѿ���ʾ��, ����
    cmp bfi, 0; �ж��Ƿ���Ҫת��
    jz exe; bfi=0��ʾ����, ���ж�
    jmp stop; bfi=1��ʾ��ͣ, Ҫ���ж�

    ;�жϼ�ֵ
start2:
    ;����
    mov cx, 500
    loop $
    cmp al, 0ah; if key == 'A'
    jnz start3
    ;A��������(���ĵ������״̬, ����ͣ�俪��, ��������ͣ)
    ;Aֻ��ͣ, ����ʾ
    xor bfi, 1; �ı�����״̬
    cmp bfi, 1; �ж�
    jz stop; bfi=1˵��Ҫ����������ͣ
start:
    call getcount
    cmp buffer + 7, 0bh; �����B��������������
    jz bc
    cmp buffer + 7, 0ch; �����C��������������
    jz bc
    ;�����ǰ���de
    jmp de
zhongzhuan:
    jmp start1
de:
    mov al, setcount; ȡ���ڴ���setcount
    mov setstep, al; ���ò���setcount
    cmp setstep, 0; ����0��
    jz start1; ���0������ʾ���ȴ���ֵ����
    jmp exe; ��������

    ;(�����)
    ;����Ϊbc��������
    ;��Ϊ����λ,���ʴ�00-99һ��100��
    ;��300��ʼ���εݼ�100(�� 5ms/�� ��ʼÿ������0.1ms, �����������ʽ���)
    ;�����һ��б��Ϊ����һԪ���κ���
    ;speed = 10100 - 100 * setcount
bc:
    mov setstep, 07fh; ��ղ���
    mov al, setcount; al = setcount
    mov setspeed, al; ��������
    mov ah, 0; 
    mov bx, 50; bx = 50
    mul bl; ax = 50 * setcount, ���9900���ᳬ��Χ
    mov bx, ax; bx = 50 * setcount
    mov ax, 20000; ax = 10000
    sub ax, bx; ax = 10000 - 50 * setcount
    mov count, ax; count�µļ�����ֵ
    call init8253; �������ü�����9253

exe:
    mov done, 0; deҪִ��, �����жϽ�����־λ, ����ǰ��δ����
    sti; ���ж�, �����ж�
    cmp done, 1; �ж��ж��Ƿ����
    jnz zhongzhuan; û�н�����ȥ�жϰ������
    ; ���������һ���ж�
stop:
    cli; ���ж�
    mov bfi, 1;��ǰΪ��ͣ
    jmp start1; ��ɺ��ȥ�жϰ������

start3:
    ;�жϳ���'A'�������������
    cmp al, 0fh; �������'F', �������
    jz F
    cmp bfi, 1; �жϵ�ǰ���״̬
    jz input; �������ͣ��״̬, ��ȥ����0-9, b-e
    jmp exe; �����������״̬��ȥִ���ж�;
input:
    cmp al, 9; �ж������Ƿ�Ϊ0-9
    ja start4; �������9, ���ö�Ӧ�İ�������
    mov ah, buffer + 5; ������������ֵ
    mov buffer + 6, ah
    mov buffer + 5, al
    jmp start1; ��ɺ��ȥ�жϰ������
start4:
    mov buffer + 7, al; ������ֵ[b,c,d,e]����buffer+7
    cmp al, 0Bh; �ж��ǲ���b
    jz bd; ˳ʱ��ת
    cmp al, 0Dh; �ж��ǲ���d
    jz bd; ˳ʱ��ת
    mov bclockwise, 0; ����Ϊ��ʱ��
    jmp start1; ��ɺ��ȥ�жϰ������
bd:
    mov bclockwise, 1; ����Ϊ˳ʱ��
    jmp start1; ��ɺ��ȥ�жϰ������
F:
    cli ; ���ж�
    call hltfunction; ͣ����ʾ'88888888'
    hlt ; ͣ��

;*******************************************************
;�ӳ�����: hltfunction
;����: ͣ����ʾ'ffffffff'
;��ڲ���: ��
;���ڲ���: ��
hltfunction proc near
    ;�����ֳ�
    push cx
    push ax
    push dx
    mov al, 0ffh; λ��=0ffh
    mov dx, _8255_pb
    out dx, al; Ϩ�������
    mov al, 80h; 8����
    mov dx, _8255_pa
    out dx, al; ����
    mov al, 0; 
    mov dx, _8255_pb
    out dx, al
    ;�����500us�ӳ�(�����)
    mov cx, 500
    loop $
    ;�ָ��ֳ�
    pop dx;
    pop ax;
    pop cx;
    ret
hltfunction endp;

;*******************************************************
;�ӳ�����: t0
;����: �жϳ���
;��ڲ���: setstep, bneeddisplay, stepcontrol 
;���ڲ���: ��
t0 proc near
    ;�����ֳ�
    push ax
    push dx
    mov al, stepcontrol; ���´�ת����ֵ�������
    mov dx, _8255_pc; c�ڸ�4λ���ӵĵ������
    out dx, al
    cmp setstep, 0; ����һ�²����������ֽ����ж�;
    jz exit
    call setstepcontrol; �����µ���һ��ת������ֵ
    mov bneeddisplay, 1; ��һ����Ҫ��ʾ�µĲ���
    call calstep; �����²���
    cmp setstep, 07fh; �ж��ж��Ƿ������²���
    jz t0_1; û�����ò�����B, Cģʽ, ֱ�ӽ����ж�
    dec setstep; �ж�һ�����õĲ���-1
    cmp setstep, 0; �ж���û������
    jnz t0_1; û�������ֱ�ӷ���
    ;����Ļ�Ҫ����bfi�͹��ж�
    mov done, 1; �����
    cli 
    mov bfi, 1; �����ͣ
    jmp t0_1
exit:
    cli
t0_1:
    mov dx, _8259_0; EOI
    mov al, 20h
    out dx, al
    ;�ָ��ֳ�
    pop dx
    pop ax
    iret
t0 endp

;*******************************************************
;�ӳ�����: calstep
;����: �����µĲ���ֵ
;��ڲ���: buffer[0-2], stepcount 
;���ڲ���: buffer[0-2]
calstep proc near
    ;�����ֳ�
    push cx
    push bx
    call setstepcount; �Ȼ�ȡ����ܵĵ�ǰ����ֵ
    mov cx, 3; ����һ��3λ
    lea bx, buffer; �����׵�ַ
    cmp bclockwise, 1; �ж�ת������
    jz setclockwise
setanticlockwise:
    ;��ʱ��ת
    cmp byte ptr[bx + 3], 1; �жϲ���Ϊ�����Ǹ���, ����Ϊ0, ����Ϊ1
    jz stepinc; ����Ǹ���, ����+1
    cmp stepcount, 0; ����, �жϲ���Ϊ'0000', ��һ��Ӧ�ñ�Ϊ'1001', ��+0->-1
    jnz setanticlockwise1; ���������, ����-1
    ;�����'0000', ��һ����Ϊ'1001'
    mov byte ptr[bx + 3], 1; '1'
    mov byte ptr[bx], 1
    jmp getstep; �õ����µ���ʾֵ
setanticlockwise1:
    jmp stepdec; ����-1
setclockwise:
    cmp byte ptr[bx + 3], 0; �ж��������Ǹ���
    jz stepinc;���������, �� + 1
    ; ˵���Ǹ���
    cmp setcount, 1; �ж��ǲ���'1001',��һ��Ӧ�ñ�Ϊ'0000'
    jnz setclockwise1; ����, ����ֱ�Ӳ���-1
    mov byte ptr[bx + 3], 0h; ���'0000'
    mov byte ptr[bx], 0
    jmp getstep
setclockwise1:
    jmp stepdec; ����-1

    ;�ӷ���Ҫ�����ǲ���'999', ���������'000', ���򲻱�
stepinc:
    inc byte ptr [bx]; ����+1
    cmp byte ptr [bx], 0ah; �ж���û�н�λ
    jnz getstep; �޽�λ���˳�
    mov byte ptr [bx], 0; �н�λ�ʹ����λ
    inc bx
    loop stepinc
    ;˵�����н�λ��'999', ��ʱ�൱���޷��ű��'000'
    lea bx, buffer;
    mov cx, 3; 
stepinc1:
    mov byte ptr [bx], 0
    inc bx
    loop stepinc1
    ;�ӷ���Ҫ�����ǲ���'999', ���������'000', ���򲻱�
    jmp getstep

stepdec:
    dec byte ptr [bx]; ����-1
    cmp byte ptr [bx], 0ffh; ��λ�Ƿ�Ҫ��λ
    jnz getstep; �޽�λ���˳�
    mov byte ptr [bx], 9; �н�λ, ��ǰλΪ9
    inc bx
    loop stepdec; ��һ
getstep:
    ;�ָ��ֳ�
    pop bx
    pop cx
    ;��ȡ�˲������ؼ���
    ret
calstep endp

;*******************************************************
;�ӳ�����: setstepcount
;����: ��ȡ��ǰ����ܵĲ���, ����3λ��ֵ
;��ڲ���: buffer[0-2] 
;���ڲ���: stepcount
setstepcount proc near
    ;�����ֳ�
    push ax
    push bx
    push dx
    ;�ؾ�����ֵ 123 = (((1 * 10) + 2) * 10 + 3)
    mov al, buffer + 2;
    mov bx, 10
    mul bl
    add al, buffer + 1;
    mul bl
    add al, buffer;
    adc ah, 0
    mov dx, 0;
    mul bx
    adc ah, 0
    mov stepcount, ax
    ;�ָ��ֳ�
    pop dx
    pop bx
    pop ax
    ret
setstepcount endp

;*******************************************************
;�ӳ�����: setstepcontrol
;����: ����stepcontrol, �´δ��͸����������ֵ, ˳ʱ���൱��Ҫ����ror, ��ʱ��Ϊ����rol
;      ����0, 1 4��ֻ��control���ж�Ӧ��������������
;      �����ǵ�˫8��, styletype��¼��Ϊ��˫8�ĵ�ƫ����
;��ڲ���: styletypeת����ʽ 
;���ڲ���: stepcontrol
setstepcontrol proc near
    ;�����ֳ�
    push bx
    push ax
    mov bx, 0
    mov bl, styletype; ��ת����ʽ����bl
    mov al, [control + bx]; ��ת����ʽ�����鴫��stepcontrol
    mov stepcontrol, al
    ;���е�˫8��
    cmp bx, 2
    jnb danshuang8pai
    cmp bclockwise, 1; �����жϵ��ת������
    jz controlclockwise; ˳ʱ��
controlanticlockwise:
    rol [control + bx], 1; ��ʱ��Ҫ�����ƶ�һλ
    jmp scan
controlclockwise:
    ror [control + bx], 1; ˳ʱ��Ҫ�����ƶ�һλ
    jmp scan
danshuang8pai:
    cmp bclockwise, 1; �жϵ��ת������
    jz danshuang8pai_clockwise; ˳ʱ��
danshaung8pai_anticlockwise:
    dec bx; ��ʱ����ֵ����, ��Ӧ���ƫ����������
    cmp bx, 1; ѭ��
    jnz scan
    mov bx, 9;
    jnz scan;
danshuang8pai_clockwise:
    inc bx; ˳ʱ����ֵ����, ��Ӧ���ƫ����������
    cmp bx, 10; ѭ��
    jnz scan
    mov bx, 2
scan:
    mov styletype, bl; ��ƫ��������styletype��
    mov al, [control + bx]; alΪ�´ε��ֵ
    mov stepcontrol, al; ����stepcontrol
    ;�ָ��ֳ�
    pop ax
    pop bx
    ret
setstepcontrol endp

;*******************************************************
;�ӳ�����: getcount
;����: ���ò��������ֵ, �粽������ת��
;��ڲ���: buffer+6, buffer+5
;���ڲ���: setcount
getcount proc near
    ;�ؾ����㲽��, ���ò�����������ת��
    ;�����ֳ�
    push bx
    push ax
    mov al, buffer + 6
    mov bx, 10
    mul bl
    add al, buffer + 5
    mov setcount, al
    ;�ָ��ֳ�
    pop ax
    pop bx
    ret
getcount endp

;*******************************************************
;�ӳ�����: init8255
;����: ��ʼ��8255
;��ڲ���: ��
;���ڲ���: ��
init8255 proc near
    ;������ʽ
    mov dx, _8255_ct
    mov al, 10000001b; pc0-3����(key), pc4-7���(���)
    out dx, al; 
    dec dx; 
    dec dx; pb��
    ;��B�����ffh,����ܲ���ʾ
    mov al, 0ffh
    out dx, al;
    ret
init8255 endp

;*******************************************************
;�ӳ�����: init8253
;����: ��ʼ��8253������
;��ڲ���: ��
;���ڲ���: ��
init8253 proc near
    mov dx, _8253_ct
    mov al, 00110100b; T0ģʽ2, �����Ƽ���
    out dx, al
    mov dx, _8253_0
    ;��8λ
    mov ax, count 
    out dx, al
    ;��8λ
    mov al, ah
    out dx, al; 
    ret
init8253 endp

;*******************************************************
;�ӳ�����: init8259
;����: �жϴ�����8259��ʼ��
;��ڲ���: ��
;���ڲ���: ��
init8259 proc near
    mov dx, _8259_0
    ;icw1
    mov al, 00010011b; ������, ��Ƭ, ��Ҫicw4
    out dx, al
    mov dx, _8259_1
    ;icw2�ж�������
    mov al, 08h
    out dx, al
    ;icw4
    mov al, 09h; ����ȫǶ�׷�ʽ, ���巽ʽ, ���Զ�
    out dx, al
    ;ocw1
    mov al, 0feh; ��������ir0
    out dx, al
    ret
init8259 endp

;*******************************************************
;�ӳ�����: wriIntver
;����: �ж��������ʼ��
;��ڲ���: ��
;���ڲ���: ��
wriIntver proc near
    push es
    push di
    push ax
    mov ax, 0
    mov es, ax
    mov di, 20h; 8 * 4 = 32d = 20h
    lea ax, t0;�жϳ���ƫ�Ƶ�ַ
    stosw 
    mov ax, cs;�жϳ���ε�ַ
    stosw
    pop ax
    pop di
    pop es
    ret
wriIntver endp

chunriying proc near
    ;�����ֳ�
    push dx
    ;�ָ��ֳ�
    mov dx, _8255_pa;
    mov al, 00001000b;
    out dx, al;
    call delay
    mov al, 00000100b;
    out dx, al;
    call delay
    mov al, 00000010b;
    out dx, al;
    call delay
    mov al, 00000100b;
    out dx, al;
    call delay
    mov al, 00001000b
    out dx, al;
    call delay
    mov al, 00010000b
    out dx, al;
    call delay
    mov al, 00001000b;
    out dx, al;
    call delay
    mov al, 00000100b
    out dx, al;
    call delay

    mov dx, _8255_pa;
    mov al, 00001000b;
    out dx, al;
    call delay
    mov al, 00000100b;
    out dx, al;
    call delay
    mov al, 00000010b;
    out dx, al;
    call delay
    mov al, 00000100b;
    out dx, al;
    call delay
    mov al, 00001000b
    out dx, al;
    call delay
    mov al, 00010000b
    out dx, al;
    call delay
    mov al, 00001000b;
    out dx, al;
    call delay
    mov al, 00000100b
    out dx, al;
    call delay

    mov dx, _8255_pa;
    mov al, 00001000b;
    out dx, al;
    call delay
    mov al, 00000100b;
    out dx, al;
    call delay
    mov al, 00000010b;
    out dx, al;
    call delay
    mov al, 00000100b;
    out dx, al;
    call delay
    mov al, 00001000b
    out dx, al;
    call delay
    mov al, 00010000b
    out dx, al;
    call delay
    mov al, 00001000b;
    out dx, al;
    call delay
    mov al, 00000100b
    out dx, al;
    call delay

    mov dx, _8255_pa;
    mov al, 00001000b;
    out dx, al;
    call delay
    mov al, 00000100b;
    out dx, al;
    call delay
    mov al, 00000010b;
    out dx, al;
    call delay
    mov al, 00000100b;
    out dx, al;
    call delay
    mov al, 00001000b
    out dx, al;
    call delay
    mov al, 00010000b
    out dx, al;
    call delay
    mov al, 00001000b;
    out dx, al;
    call delay
    mov al, 00000100b
    out dx, al;
    call delay
    pop dx
chunriying endp

delay proc near
    push cx
    mov cx, 100
    loop $
    pop cx
delay endp
end main

