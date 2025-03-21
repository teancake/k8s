## 使用NFS作为K8S的动态storageClass存储
用helm安装nfs-subdir-external-provisioner即可，注意需要修改server, path, storageClass.name等参数，如果需要做为默认存储的话，需要把storageClass.defaultClass设置为true。
如果nfs的storage一开始没有设置为默认存储，后续想改成默认的，可以用下面的命令，把nfs-storage替换为实际的storageClass就行。

```bash
kubectl patch storageclass nfs-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```



## nfs问题排查

当从Starrocks大量读或者写数据时，经常出现starrocks的operator pod挂掉，经排查跟内存和CPU资源无关。最终定位到是starrocks使用的NFS存储的原因。

通过查看NFS主机的日志， 发现网卡eno1有挂掉的记录“Detected Hardware Unit Hang” ，使用 `journalctl -b -1` 可以列出上次机器启动后所有的日志。


### 关闭TSO

通过搜索发现，把网卡的 TCP Segmentation Offload功能关掉就行，命令是`sudo ethtool -K eno1 tso off`


可以通过命令`ethtool --show-features eno1 | grep tcp`查看tso的状态。


TCP Offload Engine (TOE) is a technology used in modern NICs to move the processing of the TCP/IP stack from the system’s main CPU to the NIC.

### 永久关闭TSO
上面的ethtool命令重启之后就会失效，如果想重启之后TSO继续处于关闭的状态，有两个办法可以做，一个是写个systemctl的服务，执行ethtool的命令。另一个是例用systemd link里对TSO的配置功能，文档是 https://www.freedesktop.org/software/systemd/man/latest/systemd.link.html 
具体步骤是：在`/etc/systemd/network/`文件夹下面建一个文件，如`01-disable-tso.link`，把下面内容放进去，之后重启电脑就行

```
[Match]
OriginalName=eno1


[Link]
TCPSegmentationOffload=false
TCP6SegmentationOffload=false
```

注意Match下面的OriginalName要写网卡名称，Link下面TCP和TCP6都要写。
这种方式会对已经存在的link文件造成影响，会覆盖大于01的link配置，如果在`/usr/lib/systemd/network`,`/run/systemd/network`,`/usr/local/lib/systemd/network`, `/etc/systemd/network` 有link文件，要格外注意。

重启后，可以通过命令`ethtool --show-features eno1 | grep tcp`查看tso的状态。 也可以通过命令`journalctl -u systemd-networkd --since today` 来查看systemd-networkd的运行日志。

### NFS扩容
由于一开始没有对磁盘做逻辑卷，导致NFS共享数据所在的盘满了之后无法扩容。
方案是增加新的磁盘，做成逻辑卷，将原来的数据复制到新的磁盘里即可。这个方案需要停机，防止数据不一致。

有两点一定要注意：
1. 原来的nfs共享路径不能更改，需要建一个符号链接到新的磁盘路径。这样操作NFS和PV的配置都不需要动，数据复制完成之后所有节点开机即可。原因是K8S的PV建立的时候已经把nfs的共享路径固定下来了。即使改了nfs-subdir-external-provisioner的配置重新部署也不行，已有PV还是不会改。
2. 复制的时候一定要使用cp -a，它能够保留文件的时间、所有者和组，k8s的应用不一定会用什么user来创建文件，如果文件的所有者被更改了，k8s的应用就没有权限读写了。



