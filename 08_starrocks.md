# starrocks的各种问题

## query超时

SET SESSION query_timeout=600;
执行SQL之前设置session变量。

所有的变量列表
https://docs.starrocks.io/en-us/2.5/reference/System_variable

保险起见，连接数据的时候也加上下面的参数

sqlalchemy.create_engine("starrocks://{}:{}@kube-starrocks-fe-service.starrocks.svc.cluster.local:9030/{}?charset=utf8".format(user, password, db_name),
                                connect_args={'connect_timeout': 600})



## select * 把operator打挂
目前还没有解决，不知道什么原因。临时方案是一次少取一些数据，多取几次。


## FE恢复
FE起不来，BE已经有很多数据了，如果重建FE节点，META数据丢了之后BE的数据就恢复不了了。
操作步骤见文档。
1. 把所有的FE都停掉，只起一个FE
2. 要找到一个META数据最全的FE节点，把它的PVC的内容拷到FE-0的文件夹里，覆盖FE-0的内容。
3. 改helm的配置，增加一行 metadata_failure_recovery=true
￼

4. helm upgrade --install starrocks . --namespace starrocks --create-namespace
5. 这个时候应该能把FE-0起来了，如果起不来，我也不知道该怎么办了。
6. 之后改helm的配置，把加的那行删掉。重新再upgrade
7. 把其它FE节点的PVC的文件平内容清空，这个如果不做的话，增加新的FE的时候，FE0会挂掉。
8. 增加新的FE.



## 下线BE节点
由于BE里存的是数据，如果有BE节点起不来，数据是无法查询的

但是如果想下线BE节点，可以按下面步骤，下线节点的数据会转移到正常节点里。

1. show backends; 查出来ip和heartbeatport
2.  ALTER SYSTEM DECOMMISSION BACKEND "host1:port", "host2:port"; host和port是第一步查出来的。比如 ALTER SYSTEM DECOMMISSION BACKEND "kube-starrocks-be-2.kube-starrocks-be-search.starrocks.svc.cluster.local:9050";
3. show backends; 查 TabletNum， 下线的节点的tabletnum应该是逐渐减小的，等减少到0了，就可以把节点关了。
4. SHOW PROC '/statistic'; 也可以看unhealthy的tabletnum。
￼




