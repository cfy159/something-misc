AES是一种对称加密，就是加密与解密的密钥是一个。

## 1 安装环境

```python
pip install pycryptodome
```

## 2 加密所用的参数：
密	 钥：加密解密的时候都要使用它，数据类型为bytes
明	 文：需要加密的参数，数据类型为bytes
模	 式：加密模式：最常用的是EBC和CBC模式
iv偏移量：这个参数在ECB模式下不需要，在CBC模式下需要

## 3 加密解密注意事项： 

1. 密钥、明文和iv都必须为16字节或这16字节的倍数

2. 不足16字节和16字节倍数的需要进行补全

3. CBC模式下解密时需要重新创建AES对象，为了防止此类错误，可以任何模式下都重新创建AES对象
  **EBC模式加密解密：**

  ```python
  from Crypto.Cipher import AES
  
  key = b'1234567812345678' # 密钥，b是字节类型,如果是字符串可以encode转换成bytes
  text = b'aejflaeiofafeagg' # 明文
  aes = AES.new(key, AES.MODE_EBC) # EBC模式
  en_text = aes.encrypt(text) # 加密
  print("密文：", en_text)
  de_text = aes.decrypt(en_text) # 解密
  print("明文：", de_text)
  ```

​		**CBC模式加密解密:**

```python
from Crypto.Cipher import AES

key = b'1234567812345678' # 密钥，b是字节类型
iv = b'1234567812345678' #iv偏移量，bytes类型
text = b'aejflaeiofafeagg' # 明文
aes = AES.new(key, AES.MODE_CBC, iv) # CBC模式
en_text = aes.encrypt(text) # 加密
print("密文：", en_text)
aes = AES.new(key, AES.MODE_CBC, iv) # 在CBC模式下解密需要重新创建一个aes对象
de_text = aes.decrypt(en_text) # 解密
print("明文：", de_text)
# 如果CBC模式下加密解密不重新创建一个aes对象，就会报错：TypeError: decrypt() cannot be called after encrypt()
```



## 4 编码模式：
AES加密只接受bytes类型的数据，
如果要对中文进行编码或者经过base64编码的需要先进性编码或者解码，才能进行加密解密
例：
**-- 中文加密**

```python
from Crypto.Cipher import AES

key = b'1234567812345678'
text = "好好学习天天向上".encode('gbk') #gbk编码，是1个中文字符对应2个字节，8个中文正好16字节
aes = AES.new(key, AES.MODE_ECB) #创建一个aes对象
print(len(text)) # 16字节
en_text = aes.encrypt(text) #加密明文
print("密文：",en_text) #加密明文，bytes类型
de_text = aes.decrypt(en_text) # 解密密文
print("明文：",de_text.decode("gbk")) # 解密后同样需要进行解码
```

**-- base64解密**

```python
from Crypto.Cipher import AES
import base64

key = b'1234567812345678'
text = "好好学习天天向上"
aes = AES.new(key, AES.MODE_ECB)
en_text = base64.64encode(text)
en_text = base64.decodebytes(encode) # 进行base64解码
de_text = aes.decrypt(en_text)
print("明文：", de_text.decode("gbk"))
```



## 5 填充模式：
ZeroPadding:	用b'\x00'进行填充
PKCS7Padding:	当需要N个数据才能对齐时，填充字节数据N个N
PKCS5Padding:	同上
no padding:		16字节数据时可以不进行填充，不足时和ZeroPadding一样

**注意**：ZeroPadding填充会填充到下一次对齐为止，正好16bytes就会填充到32bytes。
	除了no padding 正好时不填充，其它都会填充到下次对齐
	进行填充后，解密需要自己剔除填充的位