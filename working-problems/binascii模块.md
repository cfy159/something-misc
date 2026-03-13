# binascii模块

binascii模块是python标准库中的一个模块，提供了二进制和ASCII、十六进制、base64编码和解码，

base64是一种将二进制数据转换为ASCII字符的常用方法。

1. 常用函数：
	a2b_uu(string)     # ascii -> 二进制
	b2a_uu(data)       # 二进制 -> ascii
	
	a2b_hex(data)      # 16进制 -> 二进制
	unhexlify(data)    # 同上
	b2a_hex(data)      # 二进制 -> 16进制
	hexlify(data) 	   # 同上
	
	a2b_base64(string) # base64 -> 二进制
	b2a_base64(data)   # 二进制 -> base64
	
2. 相关内置函数
	chr() # int -> ascii
	ord() # ascii -> int
	hex() # 十进制 -> 16进制
	oct() # 十进制 -> 8进制
	bin() # 十进制 -> 2进制