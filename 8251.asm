;8251.asm
INCLUDE 8251.inc
.MODEL TINY
.STACK 100

.CODE

	PUBLIC Init8251
	PUBLIC Init8253_T1
	PUBLIC Reset8251
	PUBLIC Sendbyte
	PUBLIC RecvByte
; 8251初始化子程序
Init8251	PROC	NEAR	
	CALL	Reset8251	
	MOV	DX,Con_8251	
	; 0111 1110
	MOV	AL,7EH		;波特率系数为16，8个数据位
	OUT	DX,AL		;一个停止位，偶校验
	CALL	DLTIME		;延时
	; 0001 0101
	MOV	AL,15H	     	;允许接收和发送发送数据，清错误标志
	OUT	DX,AL	
	CALL	DLTIME	
	RET		
Init8251	ENDP	


;CLK1 = 2M Hz		
Init8253_T1	PROC	NEAR	
	MOV	DX,Con_8253	
	; 01 - 01 - 011 - 1
	MOV	AL,57H		;定时器1，方式3
	OUT	DX,AL	

	MOV	DX,T1_8253	
	MOV	AL,26H		;BCD码26(2000000/26)=16*4800
	OUT	DX,AL	
	RET			
Init8253_T1	ENDP


Reset8251	PROC	NEAR	
	MOV	DX,Con_8251	
	MOV	AL,0	
	OUT	DX,AL		;向控制口写入"0"
	CALL	DLTIME		;延时，等待写操作完成
	OUT	DX,AL		;向控制口写入"0"
	CALL	DLTIME		;延时
	OUT	DX,AL		;向控制口写入"0"
	CALL	DLTIME		;延时
	MOV  	AL,40H		;向控制口写入复位字40H
	OUT	DX,AL	
	CALL	DLTIME	
	RET		
Reset8251	ENDP		



;发送一个字节，输入参数 AL
Sendbyte	PROC	NEAR	
	PUSH	DX
	PUSH	AX	
	MOV	DX,Con_8251	;读入状态
Wait_Tx:	

	; D0: TxRDY，发送器是否准备好
	IN	AL,DX	
	TEST	AL,1	
	JZ	Wait_Tx		;允许数据发送吗？
	POP	AX		;发送
	MOV	DX,Dat_8251	
	OUT	DX,AL	
	POP	DX
	RET		
Sendbyte		ENDP		



; 接受一个字节，ZF = 0，且将结果存入AL
RecvByte	PROC	NEAR	
	PUSH	DX
	MOV	DX,Con_8251	
	
Wait_Rx:
	; D1: RxRDY，接收器是否准备好
	IN	AL,DX		;读入状态
	TEST	AL,2	
	JZ	Wait_Rx		;有数据吗？
	MOV	DX,Dat_8251	;有
	IN	AL,DX	
Recv_Exit:
	POP	DX
	RET		
RecvByte	ENDP		


;延时
DLTIME	PROC	NEAR	
	MOV	CX,10	
	LOOP	$	
	RET		
DLTIME	ENDP

END		

