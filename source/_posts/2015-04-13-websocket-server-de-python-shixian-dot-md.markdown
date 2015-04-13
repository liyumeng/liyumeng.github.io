---
layout: post
title: "WebSocket Server 的Python实现.md"
date: 2015-04-13 20:02:49 +0800
comments: true
categories: 

---
## WebSocket Server端的Python实现 ##

**WebSocket** 是一种HTML5新的协议，它实现了浏览器与服务器全双工通信。为了大家能对WebSocket有更深入的了解，我们还是先看看浏览器的正常的Http请求都干了什么。

![](http://i2.tietuku.com/14cbfc2972b5206f.jpg)

如上图，我们平时用浏览器访问网页，一般都是由浏览器向服务器发送一个Http请求，服务器返回相应的数据，其过程可描述为:

1. 客户端（浏览器）与服务器建立TCP连接，进行TCP连接的三次握手
2. TCP连接建立之后，浏览器向服务端发送HTTP请求数据包
3. 服务端收到浏览器的数据，根据请求内容，向浏览器发送数据
4. 进行四次挥手关闭TCP连接

按照上面的方式，我们在访问一次网页的时候就需要多次建立TCP连接，TCP的建立和关闭是比较耗资源的，所以为了更有效地利用TCP连接，在HTTP1.1中规定了默认保持长连接，也就是数据传输完成后，不进行四次挥手关闭TCP连接，而是保持TCP连接，等待同域名下继续使用这个通道传输数据。

但Http长连接的方式对于服务器来说仍然只是被动的接收数据，无法主动向浏览器发送数据，因此便有了WebSocket。比如原来想实现一个WebQQ的功能，就需要浏览器轮询式地每隔几秒向服务器发送查询请求，看看是否有新消息。有了WebSocket，服务端一旦发现有新消息通知了，就会立即主动向浏览器发送数据，即快捷又节省资源。

### WebSocket的握手 ###

进行WebSocket连接也需要发送一次Http请求，这次请求通常被称为**握手**，这个握手和TCP连接的三次握手不是一个概念，TCP是在传输层的握手，这次握手是在应用层的，是在传输层基础上的。说白了就是人为规定了一种Http请求头格式，一旦浏览器按这种格式发送，就视为要进行WebSocket连接。格式如下：

**Request Headers:**

	GET ws://localhost:8000/echo HTTP/1.1
	Host: localhost:8000
	Upgrade: websocket
	Connection: Upgrade
	Sec-WebSocket-Version: 13
	Sec-WebSocket-Key: 8zFkAy+naxm3Gg8pnMHKwA==

**Response Headers:**

	 HTTP/1.1 101 Switching Protocols
	 Upgrade: websocket
	 Connection: Upgrade
	 Sec-WebSocket-Accept: sDV9wEDoveIgEhi7kD3G2Vlr6gA=
	 Sec-WebSocket-Protocol: chat 

看完了WebSocket握手的协议，我们先来写点代码吧，看看用Python如何来实现WebSocket的Server。既然是Server，我们只需要完成Response Headers的生成，Request Headers是浏览器自己生成的。

首先创建一个socket监听，用来接收浏览器发来的请求

    s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
    s.bind('127.0.0.1','8000')
	s.listen(5)
	print 'Waiting for connection ......'

这里socket监听的端口设置的是8000，也可设置成其他端口,`listen(5)`表示的是最多同时建立5个socket连接

	while True:
		sock,addr=s.accept()
		t=threading.Thread(target=websocketlink,args=(sock,addr))
		t.start()

上面的代码主要是不断接收浏览器请求，然后创建一个处理线程，去处理这个请求，主线程只负责监听并接收请求。
创建线程这两个参数`target`, `args` 一个是函数名，一个是传入的参数，可见我们之后需要创建一个名叫`websocketlink`的函数来处理请求。

这里需要注意的是浏览器发送过来的握手信息（也就是Http请求）必须携带头字段`Sec-WebSocket-Key`,而服务端收到这个请求之后，返回的握手信息，也一定要携带`Sec-WebSocket-Accept`。这两个值的关系有如下处理逻辑：将`Sec-WebSocket-Key`的值与`258EAFA5-E914-47DA-95CA-C5AB0DC85B11`（这个值是协议里规定的）相连接，组成的字符串进行SHA-1散列（160位），再进行base-64编码，即得到了Sec-WebSocket-Accept的值。


	def websocketlink(sock,addr):
	    print 'Accept new web socket from %s:%s...' % addr
	
	    #从socket数据中转换成header的dictionary
	    headers = get_headers(sock)
	    
	    #这里根据浏览器发送来的Sec-WebSocket-Key计算出要返回的Sec-WebSocket-Accept的值
	    key = headers['Sec-WebSocket-Key']
	    sha1 = hashlib.sha1()
	    sha1.update(key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
	    accept_value = base64.b64encode(sha1.digest())
	    
	    response = ('HTTP/1.1 101 Switching Protocols\r\n'
	              'Upgrade: websocket\r\n'
	              'Connection: Upgrade\r\n'
	              'Sec-WebSocket-Accept: %s\r\n'
	              '\r\n' % accept_value)
	
	    #使用socket发送数据
	    sock.send(response)
	    #握手完毕

		while True:
		    #开始接受数据
		    is_finished,opcode,data = receive_frame(sock)
		    print data
		    #将收到的数据发回去
		    print send_frame(sock, data)
		    pass


从上面可以看出，我们要实现的功能，就是把浏览器发送的信息，再输出回去。get_headers函数的内容如下：

	#从socket数据中转换成header的dictionary
	def get_headers(sock):
		while True:
		    data = sock.recv(1024)
		    print 'request:',data
		    if not data or len(data) < 1024:
		        break
		headers = {}
		for header in data.split('\r\n'):
		    items = header.split(':',2)
		    if len(items) < 2:
		        continue
		    headers[items[0]] = items[1].strip()
		return headers


###数据传输阶段###
完成了WebSocket握手之后，我们便可以开始进行数据传输了，编写传输代码之前，我们需要了解WebSocket的基本帧协议，如下图：
![](http://i2.tietuku.com/70b219809b2daab0.png)

这是官方协议中给出的帧协议图，如果看着不方便，可以看看下面我自己画的这个：

![](http://i2.tietuku.com/85363867a3755d87.jpg)

按照这个协议便可写出传输数据的代码了，如下：

    #接收浏览器的数据
    def receive_frame(sock):
	    bytes_1_2 = sock.recv(2)
	    byte_1 = ord(bytes_1_2[0])
	    byte_2 = ord(bytes_1_2[1])
	    #读最高位,结束标识
	    is_finished = byte_1 >> 7 & 1
	    #低4位是传输数据的类型
	    opcode = byte_1 & 0xf
	    if opcode == 0x8:
	    print 'connection closed.'
	    return is_finished,opcode,''
	    #第2个字节的最高位表示是否对数据进行了掩码运算
	    is_mask = byte_2 >> 7 & 1
	    #低7位表示传输数据的长度
	    length = byte_2 & 0x7f
	    
	    length_data = ""
	    #如果负载长度是126,之后的两个字节也将被解释为16位无符号整数的负载长度
	    if length == 0x7e:
	    length_data = sock.recv(2)
	    length = struct.unpack("!H", length_data)[0]
	    #如果负载长度是127,之后的8个字节也将被解释为一个64位无符号整数的负载长度
	    elif length == 0x7f:
	    length_data = sock.recv(8)
	    length = struct.unpack("!Q", length_data)[0]
	    mask_key = ""
	    #如果进行了掩码运算,要读出32位的掩码数据
	    if is_mask:
	    mask_key = sock.recv(4)
	    #接下来就是真正传输的数据了
	    data = sock.recv(length)
	    if is_mask:
	    data = mask_or_unmask(mask_key, data)
	    return is_finished, opcode, data

掩码mask_key是客户端随机选择的32位值，每个帧必须选择一个新的掩码，掩码是不可预测的。它不影响数据的长度。进行掩码和解掩码的过程相同，所以可以使用相同的函数，掩码长度是4个字节，具体算法是：数据的每4个字节都与掩码取异或。代码如下：

	def mask_or_unmask(mask_key, data):
        #1个字节的int
        _m = array.array("B", mask_key)
        _d = array.array("B", data)
        #mask_key是4个字节,所以余4
        for i in xrange(len(_d)):
            _d[i] ^= _m[i % 4]
        return _d.tostring()

服务端发送数据不需要进行掩码，所以`is_mask=False`,代码如下：

	def send_frame(sock,data):
	    is_finish=True
	    is_mask=False
	    opcode=0x01
	    byte_1=opcode
	    if is_finish:
	        byte_1=byte_1|0x80
	    frame_data=struct.pack('B',byte_1)
	    
	    length=len(data)
	    byte_2=0
	    if is_mask:
	        byte_2=0x80
	    #如果数据太长,126和127只是个标识
	    if length<126:
	        frame_data+=struct.pack('B',byte_2|length)
	    elif length<=0xFFFF:
	        frame_data+=struct.pack('!BH',byte_2|126,length)
	    else:
	        frame_data+=struct.pack('!BQ',byte_2|127,length)
	        
	    #data=data.encode('utf-8')
	    if is_mask:
	        mask=os.urandom(4)
	        data=mask+mask_or_unmask(mask,data)
	        
	    frame_data+=data
	    sock.send(frame_data)
	    return len(frame_data)

到此，websocket的服务端就完成了，我们还需要一个浏览器的页面，向服务端发送请求，大家可以使用点击进入这个网页对自己的websocket server 程序进行测试，也可以下载下面的两个源码文件，进行测试。