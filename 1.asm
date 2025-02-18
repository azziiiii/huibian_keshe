.model tiny
extrn InitKeyDisplay:near, GetKeyA:near, Display8:near
; 8259a端口
_8259_0 equ 0250h
_8259_1 equ 0251h
; 8253端口
_8253_0 equ 0260h
_8253_1 equ 0261h
_8253_2 equ 0262h
_8253_ct equ 0263h
; 8255端口
_8255_pa equ 0270h
_8255_pb equ 0271h
_8255_pc equ 0272h
_8255_ct equ 0273h
_8251_0 equ 0240h
_8251_1 equ 0241h

.stack 100
.data
    buffer db 8 dup(0)   ; 数码管显示缓冲区
    buf_index dw 0       ; 缓冲区索引
    data_ready db 0      ; 数据接收完成标志
.code
main:
    ; 初始化数据段和栈段
    mov ax, @data
    mov ds, ax
    nop
    ; 一系列初始化
    call InitKeyDisplay
    call init8255
    call init8251
    call init8259
    lea si, buffer

L:
    STI                     ; 开中断
    cmp data_ready, 1       ; 检查是否有新数据
    jne L                   ; 如果没有，继续循环
    mov data_ready, 0       ; 重置标志
    call Display8           ; 刷新数码管显示
    jmp L                   ; 返回主循环

;*******************************************************
; 子程序名: init8255
; 功能: 初始化8255
; 入口参数: 无
; 出口参数: 无
init8255 proc near
    ; 工作方式
    mov dx, _8255_ct
    mov al, 10000001b       ; pc0-3输入(key), pc4-7输出(电机)
    out dx, al
    dec dx
    dec dx                  ; pb口
    ; 往B口输出ffh,数码管不显示
    mov al, 0ffh
    out dx, al
    ret
init8255 endp

;*******************************************************
; 子程序名: init8259
; 功能: 初始化8259
; 入口参数: 无
; 出口参数: 无
init8259 proc near
    mov ax, 0
    mov es, ax
    mov bx, 42h*4
    mov ax, offset receive_IRQ
    mov es:[bx], ax
    mov ax, seg receive_IRQ
    mov es:[bx+2], ax
    ; 工作方式
    mov al, 00010011B
    mov dx, _8259_0
    out dx, al
    mov al, 01000000B
    mov dx, _8259_1
    out dx, al
    mov al, 00000001B
    out dx, al
    mov al, 11111011B
    out dx, al
    STI
    ret
init8259 endp

;*******************************************************
; 子程序名: init8251
; 功能: 串行通信装置8251初始化
; 入口参数: 无
; 出口参数: 无
init8251 proc near
    ; 复位操作
    mov cx, 3
    mov al, 0
    mov dx, _8251_1
aga:
    out dx, al              ; 软复位先写入3个00, 再写一个40h
    call delay
    loop aga
    mov al, 40h
    out dx, al              ; 写入40h
    call delay
    ; 8251初始化
    mov al, 01001110b       ; 异步方式x16, 字符长度8位, 1位停止位, 不带奇偶校验
    out dx, al
    call delay
    mov al, 00010110b       ; 清除错误标志, 允许接受, 数据终端准备好
    out dx, al
    ret
init8251 endp

;*******************************************************
; 子程序名: delay
; 功能: 延迟
; 入口参数: 无
; 出口参数: 无
delay proc near
    push cx
    mov cx, 500
    loop $
    pop cx
    ret
delay endp

;*******************************************************
; 中断处理程序: receive_IRQ
; 功能: 接收数据并存储到缓冲区
; 入口参数: 无
; 出口参数: 无
receive_IRQ proc far
    ; 保护现场
    push ax
    push bx
    push cx
    push dx
    push si
    push ds

    ; 设置DS段为数据段
    mov ax, @data
    mov ds, ax

    ; 检查缓冲区索引
    mov bx, buf_index
    cmp bx, 8               ; 如果缓冲区已满，则不再接收
    jae skip_receive

    ; 接收数据
    mov dx, _8251_0
    in al, dx               ; 读取一个字节
    mov si, offset buffer
    add si, bx              ; 定位到缓冲区位置
    mov [si], al            ; 保存到缓冲区
    inc bx
    mov buf_index, bx       ; 更新缓冲区索引

    ; 如果缓冲区已满，设置数据准备标志
    cmp bx, 8
    jne skip_receive
    mov data_ready, 1       ; 标志新数据到达

skip_receive:
    ; 发送中断结束信号 (EOI)
    mov al, 20h
    out _8259_0, al

    ; 恢复现场
    pop ds
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret
receive_IRQ endp
end main
