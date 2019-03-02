
RHCSA评分脚本:
	教学环境下，在真机解压，server开机时执行./rht-checkcsa.py。按两下回车即可。


功能:
	Input(1):         check_all        完整测试(测试所有项)
	Input(ENTER):     check_no_user    部分测试(不包含用户密码的验证)
	!!!测试用户密码采用expect方式，比较慢，不建议使用
文件：
 	rht-checkcsa.py --> 主文件 
	checkcsa.py     --> 检测脚本，仅供参考
	.checkcsa 		--> 字节码文件

