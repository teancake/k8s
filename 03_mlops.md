# 升级操作系统内核
参考https://huangzhongde.cn/istio/Chapter1/Chapter1-3.html

# virsh 
```bash

# virsh 查看资源
dominfo 
# virsh 调整资源
setvcpus kube-worker-cen0 4 --maximum --config
setvcpus kube-worker-cen0 4 --config
setmaxmem kube-worker-cen0 16G --config
setmem kube-worker-cen0 16G --config
# 之后shutdown再restart domain就行

```
