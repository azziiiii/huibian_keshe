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

.stack 100
.data
    buffer db 8 dup(0); 数码管显示缓冲区
    bfi db 0; 是否启动步进电机(0:启动, 1:暂停)
    bclockwise db 0; 方向(0: 逆时针, 1:顺时针)
    bneeddisplay db 0; 走一步后, 是否需要显示 
    stepcontrol db 0; 给步进电机的下一个值
    setcount db 0; 设置步进电机的值, 如步数或者转速
    stepcount dw 0; 数码管显示的步数值
    setstep db 0; 设置步数 
    setspeed db 0; 设置转速
    count dw 40000; 8253计数初值, 假设连接的系统clk为1M,则1us有一个时钟信号
    styletype db 0;转动形式(4拍, 双4拍, 单8拍)
    ; 11h为四拍的初值, 33h为双四拍的初值, 剩余为单八拍的一组值
    control db 11h, 33h, 10h, 30h, 20h, 60h, 40h, 0c0h, 80h, 90h
    done db 0; 设置的步数是否走完

.code
main:
    ;初始化数据段和栈段
    mov ax, @data
    mov ds, ax
    mov es, ax
    nop
    ;一系列初始化
    call InitKeyDisplay
    call init8255
    call init8253
    call init8259
    call wriIntver

    ;初始化数码管和步进电机
    mov bfi, 1; 未启动电机
    mov bl, styletype; 定义工作形式(4拍, 双4拍, 单8拍)
    lea si, control; 
    mov al, [si + bx]; (单4拍)->11h, (双4拍)->33h, (单双8拍)->10h
    mov stepcontrol, al;
    ;初始显示D99 0000
    mov buffer, 0
    mov buffer + 1, 0
    mov buffer + 2, 0
    mov buffer + 3, 0
    mov buffer + 4, 10h
    mov buffer + 5, 9
    mov buffer + 6, 9
    mov buffer + 7, 0dh
    mov bclockwise, 1;初始默认顺时针
    ;检查转动方式
check_styletype:
    ;读C端口
    mov dx, _8255_pc;
    in al, dx; 
    ;要第3位和第2位判断转动方式
    ror al, 2
    and al, 3
    mov styletype, al;设置转动方式
    cmp styletype, 3
    jz check_styletype;只有0, 1, 2三种方式
    ;显示数码管以及获取键值
start1:
    lea si, buffer
    call Display8; 显示8位数码管
check_key:
    call GetKeyA; 获得按键
    jc start2; cf=1表示有按键, al=按键
    cmp bneeddisplay, 0; 无按键, 查看是否转动后需显示
    jz check_key; 不需要显示就等待键值输入
    ;需要显示
    mov bneeddisplay, 0; 当前已经显示了, 清零
    cmp bfi, 0; 判断是否需要转动
    jz exe; bfi=0表示启动, 开中断
    jmp stop; bfi=1表示暂停, 要关中断

    ;判断键值
start2:
    ;消抖(明天在测)
    mov cx, 500
    loop $
    cmp al, 0ah; if key == 'A'
    jnz start3
    ;A功能设置(更改电机运行状态, 即暂停变开启, 开启变暂停)
    ;A只暂停, 不显示
    xor bfi, 1; 改变运行状态
    cmp bfi, 1; 判断
    jz stop; bfi=1说明要从启动到暂停
start:
    call getcount
    cmp buffer + 7, 0bh; 如果是B功能则设置速率
    jz bc
    cmp buffer + 7, 0ch; 如果是C功能则设置速率
    jz bc
    ;否则是按键de
    jmp de
zhongzhuan:
    jmp start1
de:
    mov al, setcount; 取出内存中setcount
    mov setstep, al; 设置步数setcount
    cmp setstep, 0; 特判0步
    jz start1; 如果0步就显示并等待键值输入
    jmp exe; 否则启动

    ;(明天测)(变动)
    ;按键为bc设置速率
    ;因为就两位,速率从00-99一共100个
    ;从300开始依次递加100(从 5ms/步 开始每次增加0.1ms, 这样导致速率降低)
    ;因此是一个斜率为负的一元二次函数
    ;speed = 10100 - 100 * setcount
bc:
    mov setstep, 07fh; 清空步数
    mov al, setcount; al = setcount
    mov setspeed, al; 设置速率
    mov ah, 0; 
    mov bx, 150; bx = 50
    mul bl; ax = 50 * setcount, 最大9900不会超范围
    mov bx, ax; bx = 50 * setcount
    mov ax, 40000; ax = 10000
    sub ax, bx; ax = 40000 - 150 * setcount
    mov count, ax; count新的计数初值
    call init8253; 重新设置计数器9253

exe:
    mov done, 0; de要执行, 设置中断结束标志位, 即当前尚未结束
    sti; 开中断, 允许中断
    cmp done, 1; 判断中断是否结束
    jnz zhongzhuan; 没有结束就去判断按键情况
    ; 否则完成了一次中断
stop:
    cli; 关中断
    mov bfi, 1;当前为暂停
    jmp start1; 完成后就去判断按键情况

start3:
    ;判断除了'A'以外的其他按键
    cmp al, 0fh; 如果输入'F', 程序结束
    jz F
    cmp bfi, 1; 判断当前电机状态
    jz input; 如果处于停机状态, 就去设置0-9, b-e
    jmp exe; 如果处于启动状态就去执行中断;
input:
    cmp al, 9; 判断输入是否为0-9
    ja start4; 如果大于9, 设置对应的按键功能
    mov ah, buffer + 5; 从左往右输入值
    mov buffer + 6, ah
    mov buffer + 5, al
    jmp start1; 完成后就去判断按键情况
start4:
    mov buffer + 7, al; 将输入值[b,c,d,e]放入buffer+7
    cmp al, 0Bh; 判断是不是b
    jz bd; 顺时针转
    cmp al, 0Dh; 判断是不是d
    jz bd; 顺时针转
    mov bclockwise, 0; 方向为逆时针
    jmp start1; 完成后就去判断按键情况
bd:
    mov bclockwise, 1; 方向为顺时针
    jmp start1; 完成后就去判断按键情况
F:
    cli ; 关中断
    call hltfunction; 停机显示'88888888'
    hlt ; 停机

;*******************************************************
;子程序名: hltfunction
;功能: 停机显示'ffffffff'
;入口参数: 无
;出口参数: 无
hltfunction proc near
    ;保护现场
    push cx
    push ax
    push dx
    mov al, 0ffh; 位码=0ffh
    mov dx, _8255_pb
    out dx, al; 熄灭数码管
    mov al, 80h; 8段码
    mov dx, _8255_pa
    out dx, al; 段码
    mov al, 0; 
    mov dx, _8255_pb
    out dx, al
    ;数码管500us延迟(明天测)
    mov cx, 500
    loop $
    ;恢复现场
    pop dx;
    pop ax;
    pop cx;
    ret
hltfunction endp;

;*******************************************************
;子程序名: t0
;功能: 中断程序
;入口参数: setstep, bneeddisplay, stepcontrol 
;出口参数: 无
t0 proc near
    ;保护现场
    push ax
    push dx
    mov al, stepcontrol; 将下次转动的值传给电机
    mov dx, _8255_pc; c口高4位连接的电机输入
    out dx, al
    cmp setstep, 0; 特判一下步数走完了又进入中断;
    jz exit
    call setstepcontrol; 设置新的下一步转动输入值
    mov bneeddisplay, 1; 走一步后要显示新的步数
    call calstep; 计算新步数
    cmp setstep, 07fh; 判断判断是否设置新步数
    jz t0_1; 没有设置步数即B, C模式, 直接结束中断
    dec setstep; 中断一次设置的步数-1
    cmp setstep, 0; 判断有没有走完
    jnz t0_1; 没有走完就直接返回
    ;走完的话要设置bfi和关中断
    mov done, 1; 完成了
    cli 
    mov bfi, 1; 电机暂停
    jmp t0_1
exit:
    cli
t0_1:
    mov dx, _8259_0; EOI
    mov al, 20h
    out dx, al
    ;恢复现场
    pop dx
    pop ax
    iret
t0 endp

;*******************************************************
;子程序名: calstep
;功能: 计算新的步数值
;入口参数: buffer[0-2], stepcount 
;出口参数: buffer[0-2]
calstep proc near
    ;保护现场
    push cx
    push bx
    call setstepcount; 先获取数码管的当前步数值
    mov cx, 3; 步数一共3位
    lea bx, buffer; 数组首地址
    cmp bclockwise, 1; 判断转动方向
    jz setclockwise
setanticlockwise:
    ;逆时针转
    cmp byte ptr[bx + 3], 11h; 判断步数为正还是负数, 正数为0, 负数为-
    jz stepinc; 如果是负数, 步数+1
    cmp stepcount, 0; 正数, 判断步数为'0000', 下一步应该变为'-001', 即+0->-1
    jnz setanticlockwise1; 如果是正数, 步数-1
    ;如果是'0000', 下一步则为'-001'
    mov byte ptr[bx + 3], 11h; '-'
    mov byte ptr[bx + 2], 0; '0'
    mov byte ptr[bx + 1], 0; '0'
    mov byte ptr[bx], 1; '1'
    jmp getstep; 得到了新的显示值
setanticlockwise1:
    jmp stepdec; 步数-1
setclockwise:
    cmp byte ptr[bx + 3], 0; 判断正数还是负数
    jz stepinc;如果是正数, 则 + 1
    ; 说明是负数
    cmp setcount, 1; 判断是不是'-001',下一步应该变为'0000'
    jnz setclockwise1; 不是, 负数直接步数-1
    mov byte ptr[bx + 3], 0h; 变成'0000'
    mov byte ptr[bx], 0
    jmp getstep
setclockwise1:
    jmp stepdec; 步数-1

    ;加法需要特判是不是'999', 如果是则变成'000', 方向不变
stepinc:
    inc byte ptr [bx]; 步数+1
    cmp byte ptr [bx], 0ah; 判断有没有进位
    jnz getstep; 无进位就退出
    mov byte ptr [bx], 0; 有进位就处理进位
    inc bx
    loop stepinc
    ;说明都有进位即'999', 此时相当于无符号变成'000'
    lea bx, buffer;
    mov cx, 3; 
stepinc1:
    mov byte ptr [bx], 0
    inc bx
    loop stepinc1
    mov byte ptr [bx + 3], 0;只有0000
    ;加法需要特判是不是'999', 如果是则变成'000', 方向不变
    jmp getstep

stepdec:
    dec byte ptr [bx]; 步数-1
    cmp byte ptr [bx], 0ffh; 低位是否要借位
    jnz getstep; 无借位就退出
    mov byte ptr [bx], 9; 有借位, 当前位为9
    inc bx
    loop stepdec; 减一
getstep:
    ;恢复现场
    pop bx
    pop cx
    ;获取了步数返回即可
    ret
calstep endp

;*******************************************************
;子程序名: setstepcount
;功能: 获取当前数码管的步数, 即低3位的值
;入口参数: buffer[0-2] 
;出口参数: stepcount
setstepcount proc near
    ;保护现场
    push ax
    push bx
    push dx
    ;秦九韶算值 123 = (((1 * 10) + 2) * 10 + 3)
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
    ;恢复现场
    pop dx
    pop bx
    pop ax
    ret
setstepcount endp

;*******************************************************
;子程序名: setstepcontrol
;功能: 设置stepcontrol, 下次传送给步进电机的值, 顺时针相当于要右移ror, 逆时针为左移rol
;      对于0, 1 4拍只对control表中对应的数进行左右移
;      否则是单双8拍, styletype记录的为单双8拍的偏移量
;入口参数: styletype转动方式 
;出口参数: stepcontrol
setstepcontrol proc near
    ;保护现场
    push bx
    push ax
    mov bx, 0
    mov bl, styletype; 将转动方式送入bl
    mov al, [control + bx]; 将转动方式的数组传给stepcontrol
    mov stepcontrol, al
    ;特判单双8拍
    cmp bx, 2
    jnb danshuang8pai
    cmp bclockwise, 1; 否则判断电机转动方向
    jz controlclockwise; 顺时针
controlanticlockwise:
    rol [control + bx], 1; 逆时针要向左移动一位
    jmp scan
controlclockwise:
    ror [control + bx], 1; 顺时针要向右移动一位
    jmp scan
danshuang8pai:
    cmp bclockwise, 1; 判断电机转动方向
    jz danshuang8pai_clockwise; 顺时针
danshaung8pai_anticlockwise:
    dec bx; 逆时针数值右移, 对应表的偏移量是左移
    cmp bx, 1; 循环
    jnz scan
    mov bx, 9;
    jnz scan;
danshuang8pai_clockwise:
    inc bx; 顺时针数值左移, 对应表的偏移量是右移
    cmp bx, 10; 循环
    jnz scan
    mov bx, 2
scan:
    mov styletype, bl; 将偏移量存入styletype中
    mov al, [control + bx]; al为下次电机值
    mov stepcontrol, al; 设置stepcontrol
    ;恢复现场
    pop ax
    pop bx
    ret
setstepcontrol endp

;*******************************************************
;子程序名: getcount
;功能: 设置步进电机的值, 如步数或者转速
;入口参数: buffer+6, buffer+5
;出口参数: setcount
getcount proc near
    ;秦九韶算步数, 设置步数或者设置转速
    ;保护现场
    push bx
    push ax
    mov al, buffer + 6
    mov bx, 10
    mul bl
    add al, buffer + 5
    mov setcount, al
    ;恢复现场
    pop ax
    pop bx
    ret
getcount endp

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
;子程序名: init8253
;功能: 初始化8253计数器
;入口参数: 无
;出口参数: 无
init8253 proc near
    mov dx, _8253_ct
    mov al, 00110100b; T0模式2, 二进制计数
    out dx, al
    mov dx, _8253_0
    ;低8位
    mov ax, count 
    out dx, al
    ;高8位
    mov al, ah
    out dx, al; 
    ret
init8253 endp

;*******************************************************
;子程序名: init8259
;功能: 中断处理器8259初始化
;入口参数: 无
;出口参数: 无
init8259 proc near
    mov dx, _8259_0
    ;icw1
    mov al, 00010011b; 上升沿, 单片, 需要icw4
    out dx, al
    mov dx, _8259_1
    ;icw2中断向量号
    mov al, 08h
    out dx, al
    ;icw4
    mov al, 09h; 正常全嵌套方式, 缓冲方式, 非自动
    out dx, al
    ;ocw1
    mov al, 0feh; 允许申请ir0
    out dx, al
    ret
init8259 endp

;*******************************************************
;子程序名: wriIntver
;功能: 中断向量表初始化
;入口参数: 无
;出口参数: 无
wriIntver proc near
    push es
    push di
    push ax
    mov ax, 0
    mov es, ax
    mov di, 20h; 8 * 4 = 32d = 20h
    lea ax, t0;中断程序偏移地址
    stosw 
    mov ax, cs;中断程序段地址
    stosw
    pop ax
    pop di
    pop es
    ret
wriIntver endp

delay proc near
    push cx
    mov cx, 100
    loop $
    pop cx
delay endp
end main