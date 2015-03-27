#!/bin/bash

#-a表示重新加载模板
if [ $# -eq 0 ] || [ "$1" == "-a" ]
then 
    rake 'install[greyshade-jianshu,y]'
fi

#重新生成网页页面
rake generate
#在浏览器中打开页面
chromium-browser http://localhost:4000
#开启预览服务
rake preview
