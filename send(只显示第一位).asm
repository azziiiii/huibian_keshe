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
;8251端口
_8251_0 equ 0240h
_8251_1 equ 0241h
.stack 100
.data
    buffer db 8 dup(0); 数码管显示缓冲区
    cc db 0;
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
    mov buffer, 10h
    mov buffer + 1, 10h
    mov buffer + 2, 10h
    mov buffer + 3, 10h
    mov buffer + 4, 10h
    mov buffer + 5, 10h
    mov buffer + 6, 10h
    mov buffer + 7, 10h
start1:
    lea si, buffer
    call Display8; 显示8位数码管
check_key:
    call GetKeyA; 获得按键
    jnc check_key;
    mov cx, 10
    loop $
    mov buffer, al;
    mov buffer + 1, 10h; 
    mov buffer + 2, 10h; 
    mov buffer + 3, 10h; 
    mov buffer + 4, 10h; 
    mov buffer + 5, 10h; 
    mov buffer + 6, 10h; 
    mov buffer + 7, 10h;
    mov cc, al;
    call send; 发送数据
    jmp start1

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
    mov al, 00100001b; 允许8251发送数据, 请求发送
    out dx, al;
    call delay
    ret
init8251 endp

;*******************************************************
;子程序名: delay
;功能: 延迟
;入口参数: 无
;出口参数: 无
delay proc near
    push cx
    mov cx, 500
    loop $
    pop cx
    ret
delay endp

;*******************************************************
;子程序名: send
;功能: 8251发送数据
;入口参数: 无
;出口参数: 无
send proc near
    ;保护现场
    push di
    push ax
    push dx
    lea di, cc; 设置发送数据缓存地址
send8251:
    mov dx, _8251_1;
    in al, dx; 读入状态字
    and al, 01h; 查询TxRDY有效否?
    jz send8251; TxRDY = 0, 无效则等待
    mov dx, _8251_0;
    mov al, [di]; 向8251输出一个字节的数据
    out dx, al;
    pop dx
    pop ax
    pop di
    ret
send endp

end main


