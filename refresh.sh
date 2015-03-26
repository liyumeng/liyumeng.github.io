#!/bin/bash
rake 'install[greyshade-jianshu,y]'
rake generate
chromium-browser http://localhost:4000
rake preview
