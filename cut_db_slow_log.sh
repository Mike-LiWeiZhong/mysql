#!/bin/bash
# This's mysql slow cut scripts
# Author: Mike
# Date: 2019-01-10


time=`date -d yesterday +"%Y%m%d"`
delday=`date -d '7 days ago' "+%Y%m%d"`

cd /data/mysql/data1
rm -rf `hostname`-slow.$delday.log
cp -raf `hostname`-slow.log `hostname`-slow.$time.log
echo "" > `hostname`-slow.log
