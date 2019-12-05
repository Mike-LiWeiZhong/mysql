#!/bin/bash
# This MySQL5.6 Auto Install Scripts.
# Auth: Mike.liweizhong
# Write Date: 2019-12-05
# 配置mysql5.6.42本地安装支持CentOS6,CentOS7系列。



# 检查客户端操作系统版本
os_version=`grep -Po '[0-9](?=\.[0-9])' /etc/redhat-release|head -n1`


# 全局参数变量
HOSTNAME=`hostname`
LocalIP=`/sbin/ip addr |grep -E "eth0|em1"|grep inet |awk '{print $2}'|awk -F/ '{print $1}'|head -n1`
NETWORK=`/sbin/ip addr |grep -E "eth0|em1"|grep inet |awk '{print $2}'|awk -F/ '{print $1}'|head -n1|awk -F. '{print $3}'`
NETWORKS=`/sbin/ip addr |grep -E "eth0|em1"|grep inet |awk '{print $2}'|awk -F/ '{print $1}'|head -n1|awk -F. '{print $1,$2,$3}'|sed 's/ /./g'`
SERVERID=`/sbin/ip addr |grep -E "eth0|em1"|grep inet |awk '{print $2}'|awk -F/ '{print $1}'|head -n1|awk -F. '{print $4}'`




# 原数据库目录、数据目录备份
function mysql_backup (){
	if [ -d '/usr/local/mysql' ];then
          /etc/init.d/mysqld1 stop
          rm -rf /usr/local/mysql.`date +%Y%m%d`.old
	  rm -rf /usr/local/mysql
          mv /usr/local/mysql-* /usr/local/mysql.`date +%Y%m%d`.old
	fi

	if [ -d '/data/mysql/data1' ];then
          rm -rf /data/mysql/data1.`date +%Y%m%d`.old
          mv /data/mysql/data1 /data/mysql/data1.`date +%Y%m%d`.old
	fi
	
	if [ -d '/data/mysql/conf' ];then
          rm -rf /data/mysql/conf.`date +%Y%m%d`.old
          mv /data/mysql/conf /data/mysql/conf.`date +%Y%m%d`.old
	fi
}

# 数据库内存函数定义
function mysql_memory_conf(){
        memory=`free -m -t |grep Mem |awk '{print $2}'`
        SUM=`expr $memory / 1024`
        if [ $SUM -le 8 ] && [ $SUM -gt 4 ];then
                MEM=5
        elif [ $SUM -le 16 ] && [ $SUM -gt 8 ];then
                MEM=10
        elif [ $SUM -le 32 ] && [ $SUM -gt 16 ];then
                MEM=20
        elif [ $SUM -le 64 ] && [ $SUM -gt 32 ];then
                MEM=40
        elif [ $SUM -le 128 ] && [ $SUM -gt 64 ];then
                MEM=76
        else
                MEM=2
        fi
}

# 数据库二进制解压安装
function mysql_install(){
        yum -y install gcc gcc-c++ make automake expect git numactl mysql-utilities

        if [ -f /data/softsrc/mysql-5.6.46-linux-glibc2.12-x86_64.tar.gz ];then
          cd /data/softsrc;tar -xf mysql-5.6.46-linux-glibc2.12-x86_64.tar.gz -C /usr/local
        else
          mkdir -p /data/softsrc
          cd /data/softsrc;wget https://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-5.6.46-linux-glibc2.12-x86_64.tar.gz
	  tar -xf mysql-5.6.46-linux-glibc2.12-x86_64.tar.gz -C /usr/local
        fi

	cd /usr/local/;ln -s mysql-5.6.46-linux-glibc2.12-x86_64 mysql

	id mysql >/dev/null 2>&1
	if [ $? != 0 ];then
	 groupadd mysql
	 useradd -r -g mysql -s /bin/false mysql
	fi

	mkdir -p /data/mysql/data1
	mkdir -p /data/mysql/conf

        cd /data/softsrc;git clone https://github.com/Mike-LiWeiZhong/mysql.git
	cd /data/softsrc/mysql;cp -raf my1.cnf /data/mysql/conf/
        cd /data/softsrc/mysql;cp -raf mysqld1 /etc/init.d/
	
        sed -i "s/HostName/$HOSTNAME/g" /data/mysql/conf/my1.cnf
	sed -i "s/HostName/$HOSTNAME/g" /etc/init.d/mysqld1
	sed -i "s/Memory/$MEM/g" /data/mysql/conf/my1.cnf
	sed -i "s/ID/$SERVERID/g" /data/mysql/conf/my1.cnf
	sed -i "s/IP/$LocalIP/g" /data/mysql/conf/my1.cnf
}

# 数据库初始化函数
function mysql_init(){
	/usr/local/mysql/scripts/mysql_install_db --user=mysql --basedir=/usr/local/mysql --defaults-file=/data/mysql/conf/my1.cnf 
	chown -R mysql:mysql /data/mysql
	chown -R mysql:mysql /usr/local/mysql

       if [[ $os_version == "6" ]];then
          chmod +x /etc/init.d/mysqld1
          chkconfig --add mysqld1
          chkconfig mysqld1 on
          service mysqld1 start
        elif [[ $os_version == "7" ]];then
          chmod +x /etc/init.d/mysqld1
          cd /data/softsrc/mysql;cp -raf mysqld.service /usr/lib/systemd/system
          chmod 754 /usr/lib/systemd/system/mysqld.service
          systemctl enable mysqld
          systemctl start mysqld.service
        fi
}

# 依据传入的自定义数据库参数，配置自定义创建数据库以及账号配置函数
function mysql_conf(){
	MySQL_Bin=/usr/local/mysql/bin/mysql
	Socket=/data/mysql/data1/mysql.sock
	ROOTPWD="Mike@20191205!@#"
	MYSQLADMINPWD=`/usr/bin/mkpasswd -l 20 -d 5 -c 5 -C 5 -s 0`
	MYUSERPWD=`/usr/bin/mkpasswd -l 20 -d 5 -c 5 -C 5 -s 0`
	READONLYPWD=`/usr/bin/mkpasswd -l 20 -d 5 -c 5 -C 5 -s 0`

        $MySQL_Bin -uroot -S $Socket -e "update mysql.user set password=password('$ROOTPWD') where user='root' and host='localhost';flush privileges;"
        $MySQL_Bin -uroot -S $Socket -p$ROOTPWD -e "delete from mysql.user where password='';"
        $MySQL_Bin -uroot -S $Socket -p$ROOTPWD -e "GRANT ALL PRIVILEGES ON *.* TO 'mysqladmin'@'%' IDENTIFIED BY '$MYSQLADMINPWD' WITH GRANT OPTION;"
    	echo -e "\n"
    	echo -e "root password is: \033[32m $ROOTPWD \033[0m"
    	echo -e "mysqladmin password is: \033[32m $MYSQLADMINPWD \033[0m"
    	echo -e "\n"
    	echo "root: $ROOTPWD" > /root/secret.txt
	echo "mysqladmin: $MYSQLADMINPWD" >> /root/secret.txt
	echo -e "Local pwd file in  \033[32m /root/secret.txt \033[0m"
}

# 重启数据库服务函数
function mysql_restart(){
        if [[ $os_version == "6" ]];then
          cd /data/softsrc/mysql;cp -raf cut_db_slow_log.sh /data/scripts;chmod +x /data/scripts/cut_db_slow_log.sh
          cd /data/softsrc/mysql;cp -raf db_cron /etc/cron.d
          service mysqld1 restart
        elif [[ $os_version == "7" ]];then
          cd /data/softsrc/mysql;cp -raf cut_db_slow_log.sh /data/scripts;chmod +x /data/scripts/cut_db_slow_log.sh
          cd /data/softsrc/mysql;cp -raf db_cron /etc/cron.d
          systemctl restart mysqld.service
        fi
}

mysql_backup
mysql_install
mysql_init
mysql_conf
mysql_restart
