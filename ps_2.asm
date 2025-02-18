.model tiny
extrn InitKeyDisplay:near, GetKeyA:near, Display8:near
;8259a端口
_8259_0 equ 0250h
_8259_1 equ 0251h
;8253端口
_8253_0 equ 0260h
_8253_1 equ 0261h
_8253_2 equ 0262h
_8253_ct equ 0263h
;8255端口
_8255_pa equ 0270h
_8255_pb equ 0271h
_8255_pc equ 0272h
_8255_ct equ 0273h
_8251_0 equ 0240h
_8251_1 equ 0241h
.stack 100
.data
    buffer db 8 dup(10h); 数码管显示缓冲区
.code
main:
    ;初始化数据段和栈段
    mov ax, @data
    mov ds, ax
    nop
    ;一系列初始化
    call InitKeyDisplay
    call init8255
    call init8251

L:
    lea si, buffer;
    call Display8;
    call receive
    jmp L

;*******************************************************
;子程序名: init8255
;功能: 初始化8255
;入口参数: 无
;出口参数: 无
init8255 proc near
    ;工作方式
    mov dx, _8255_ct
    mov al, 10000001b; pc0-3输入(key), pc4-7输出(电机)
    out dx, al; 
    dec dx; 
    dec dx; pb口
    ;往B口输出ffh,数码管不显示
    mov al, 0ffh
    out dx, al;
    ret
init8255 endp

;*******************************************************
;子程序名: init8251
;功能: 串行通信装置8251初始化
;入口参数: 无
;出口参数: 无
init8251 proc near
    ;复位操作
    mov cx, 3
    mov al, 0
    mov dx, _8251_1;
aga:
    out dx, al; 软复位先写入3个00, 再写一个40h
    call delay; 
    loop aga
    mov al, 40h
    out dx, al; 写入40h
    call delay
    ;8251初始化
    mov al, 01001110b; 异步方式x16, 字符长度8位, 1位停止位, 不带奇偶校验
    out dx, al;
    call delay
    mov al, 00010110b; 清除错误标志, 允许接受, 数据终端准备好
    out dx, al;
    ret
init8251 endp

;*******************************************************
;子程序名: delay
;功能: 延迟
;入口参数: 无
;出口参数: 无
delay proc near
    push cx
    mov cx, 10
    loop $
    pop cx
    ret
delay endp

;*******************************************************
;子程序名: receive
;功能: 8251发送数据
;入口参数: 无
;出口参数: 无
receive proc near
    lea di, buffer
receive1:
    call receivebyte
    stosb
    loop receive1
    ret
receive endp

receivebyte proc near
    mov dx, _8251_1
receivebyte1:
    push si
    lea si, buffer
    call Display8
    pop si
    in al, dx7
    test al, 2
    jz receivebyte1
    mov dx, _8251_0
    in al, dx
    ret
receivebyte endp

INIT_8253 PROC NEAR
    push dx
    push ax;
    mov dx, _8253_ct;
    mov al, 01110111b; 
    out dx, al;
    mov dx, _8251_1;
    mov al, 26h;
    out dx, al;
    mov al, 0;
    out dx, al;
    pop ax
    pop dx
    RET
INIT_8253 ENDP

end main
