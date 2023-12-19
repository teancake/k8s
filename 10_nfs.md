## nfs问题排查

当从Starrocks大量读或者写数据时，经常出现starrocks的operator pod挂掉，经排查跟内存和CPU资源无关。最终定位到是starrocks使用的NFS存储的原因。

通过查看NFS主机的日志， 发现网卡eno1有挂掉的记录“Detected Hardware Unit Hang” ，使用 `journalctl -b -1` 可以列出上次机器启动后所有的日志。



通过搜索发现，把网卡的 TCP Segmentation Offload功能关掉就行，命令是`sudo ethtool -K eno1 tso off`


可以通过命令`ethtool --show-features eno1 | grep tcp`查看tso的状态。


TCP Offload Engine (TOE) is a technology used in modern NICs to move the processing of the TCP/IP stack from the system’s main CPU to the NIC.
