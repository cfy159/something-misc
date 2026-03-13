# UUID模块

uuid是一种全局唯一标识符生成方式，用于创建独一无二的标识符，以下介绍uuid模块不同版本

1. ## uuid1
	
	基于MAC地址、时间戳和随机数来生成唯一的uuid
	uuid.uuid1(node=None, clock_seq=None)
	参数：
		node: 48位的整数，用于表示mac地址，若未提供则默认是本机的mac地址
		clock_seq: 14位的整数，用于在相同的时间戳和mac地址下提供额外的随机性，若未提供则默认使用一个随机值
2. ## uuid3
	
	基于命名空间和名字的md5散列值来生成uuid
	uuid.uuid3(namespace, name)
	参数：
		namespace: 用于生成uuid的命名空间
		name: 字符串，要生成的uuid名字
			-- namespace：
				uuid.NAMESPACE_DNS: DNS命名空间
				uuid.NAMESPACE_URL: URL命名空间
				uuid.NAMESPACE_OID: IOS对象标识符(OID)命名空间
				uuid.NAMESPACE_X500: X.500 DN（目录名）命名空间
3. ## uuid4
	
	基于随机数(或伪随机数)生成的唯一标识符
	uuid.uuid4()
4. ## uuid5
	
	基于命名空间和名称生成的标识符(和uuid3一样), 采用SHA-1散列算法
5. ## getnode()
	
	获取当前机器的硬件地址(通常是mac地址)，并将其转换为整数值代表当前机器的唯一标识
	uuid.getnode()
6. ## UUID()
	
	生成UUID，通用唯一识别码
	uuid.UUID(hex=None, bytes=None, bytes_le=None, fields=None, int=None, version=None)
	参数：
		hex: 表示UUID的32个字符串的十六进制字符串
		bytes: 16字节的字符串或字节序列
		bytes_le: 小端格式的16字节的字符串或字节序列
		fields: 包含uuid各个字段的元组
		int: 表示uuid的整数
		version: uuid的版本号，如果指定，会验证输入值是否符合该版本