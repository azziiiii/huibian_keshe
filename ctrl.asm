;send.asm
INCLUDE 8251.inc
.MODEL TINY
EXTRN InitKeyDisplay:NEAR, GetKeyA:NEAR, DisPlay8:NEAR
EXTRN Init8251:NEAR, Init8253_T1:NEAR,Sendbyte:NEAR,RecvByte:NEAR

; I/O端口定义
; Con_8251	EQU	0241H

.STACK 100

.DATA
CurrentPos   	DW  	0       	; 当前位置计数，范围-1000到1000
Direction    	DB  	0       	; 0=顺时针，1=逆时针
Command      	DB  	0       	; 当前命令
DisplayBuf   	DB  	8 DUP(0)	; 显示缓冲区

.CODE
START:
	MOV 	AX,@DATA
	MOV 	DS,AX
	MOV 	ES,AX
	CALL	CONTROL_MAIN
	MOV 	AX,4C00H
	INT 	21H

; 控制机主程序
CONTROL_MAIN 	PROC 	NEAR
	CALL 	Init8251
	CALL	Init8253_T1
	CALL 	InitKeyDisplay

CONTROL_LOOP:
	CALL 	GetKeyA       	; 读取键盘输入
    	JNB 	CHECK_POSITION  ; 无按键则检查位置信息
	CMP 	AL,0AH          ; 检查命令类型
    	JB  	CHECK_POSITION
	MOV 	Command,AL      ; 保存命令
    	; 发送命令
    	CALL 	Sendbyte      	; 发送命令

    	; 如果是B,C,D,E命令，还需要发送参数
    	CMP 	AL,0AH         	; A命令
    	JE 	CHECK_POSITION
    	CMP 	AL,0FH         	; F命令
    	JE 	CONTROL_EXIT

    	; 读取并发送参数
    	CALL 	ReadTwoDigits
    	CALL 	Sendbyte
	MOV	AL, AH
	CALL	Sendbyte

CHECK_POSITION:
    	; 检查是否有位置信息
    	MOV 	DX,Con_8251
    	IN 	AL,DX
    	TEST 	AL,02H        	; 测试接收缓冲
    	JZ 	CONTROL_LOOP

    	; 接收并显示位置信息
    	CALL 	RecvByte
	MOV	Direction,AL
	CALL	RecvByte
	MOV	AH,AL
	CALL	RecvByte
	XCHG	AH,AL
	MOV	CurrentPos,AX
    	; 更新显示缓冲区并显示
	LEA	SI,DisplayBuf
    	CALL 	UpdateDisplay

    	JMP 	CONTROL_LOOP

CONTROL_EXIT:
    	RET
CONTROL_MAIN 	ENDP



; ReadTwoDigits - 读取两位十进制数字
; 输入: 无
; 输出: AX = 读取到的两位数值(0-99)
ReadTwoDigits 	PROC 	NEAR
    	PUSH 	CX

    	XOR 	AX,AX     	; 清零AX用于存储结果
    	MOV 	CX,2       	; 需要读取2位数字


ReadDigit_Wait:    
	CALL 	UpdateDisplay
    	CALL 	GetKeyA     	; 读取键盘输入
    	JNB 	ReadDigit_Wait	; 无按键则继续等待

    	; 检查输入是否为数字(0-9)
    	CMP 	AL,9H
    	JA  	ReadDigit_Wait ; 大于'9'则无效

    	; 将当前数字合并到结果中
    	LEA	SI,DisplayBuf
    	MOV 	AH,DisplayBuf[0]
	MOV	DisplayBuf[1],AH
    	MOV 	DisplayBuf[0],AL  ; 显示到对应位置

    	LOOP 	ReadDigit_Wait

    	POP 	CX

    	RET
ReadTwoDigits 	ENDP


	
; 更新显示子程序
; 输入参数：SI
UpdateDisplay 	PROC 	NEAR
    	PUSH 	AX
    	PUSH 	SI
	PUSH	DI
	PUSH	CX

    	; 显示方向标志
    	MOV 	AL,Direction
    	MOV 	[SI + 7],AL
    	; 显示位置值
	LEA	DI,[SI + 4]
	MOV	AX,CurrentPos	
	MOV	CX,3
    	CALL 	ConvertToDisplay
	; 分隔符
	MOV	BYTE PTR [SI + 3], 10H
	; 命令信息
    	MOV	AL, Command
	MOV	[SI + 2],AL

    	CALL 	Display8

	POP	CX
    	POP 	DI
	POP	SI
    	POP 	AX
    	RET
UpdateDisplay 	ENDP



;for(int i = 0; i < CX; i++, AX /= 10)
;	DI[i] = AX % 10
;将AX的每一位分别提取出来用于显示
;输入参数：DI, CX, AX
ConvertToDisplay	PROC	NEAR	
	;LEA	DI,DisplayBuf + 4	
	CLD	
	MOV	BX,10	
ConvertLoop:
	XOR	DX,DX	
	DIV	BX	;[DX, AX] / BX，商存在AX里，余数在DX里
	XCHG	AX,DX	;交换
	STOSB		;AL -> [(ES:DI)], DI = DI + 1
	MOV	AX,DX	
	LOOP	ConvertLoop
	RET		
ConvertToDisplay	ENDP

END	START

