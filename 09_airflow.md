# airflow各种问题

## 调度参数
ds 用的是上一天的时间


## 配置时区
vim values.yaml


config:
  core:
    dags_folder: '{{ include "airflow_dags" . }}'
    # This is ignored when used with the official Docker image
    load_examples: 'False'
    executor: '{{ .Values.executor }}'
    # For Airflow 1.10, backward compatibility; moved to [logging] in 2.0
    colored_console_log: 'False'
    remote_logging: '{{- ternary "True" "False" .Values.elasticsearch.enabled }}'
    default_timezone: 'Asia/Shanghai'

  logging:
    remote_logging: '{{- ternary "True" "False" .Values.elasticsearch.enabled }}'
    colored_console_log: 'False'
  metrics:
    statsd_on: '{{ ternary "True" "False" .Values.statsd.enabled }}'
    statsd_port: 9125
    statsd_prefix: airflow
    statsd_host: '{{ printf "%s-statsd" .Release.Name }}'
  webserver:
    enable_proxy_fix: 'True'
    default_ui_timezone: 'Asia/Shanghai'



  webserver:
    enable_proxy_fix: 'True'
    default_ui_timezone: 'Asia/Shanghai'
    expose_config: 'non-sensitive-only'



## helm部署
helm upgrade --install airflow . --namespace airflow --create-namespace   --set dags.persistence.enabled=true   --set dags.persistence.existingClaim=airflow-dags   --set dags.gitSync.enabled=false   --set logs.persistence.enabled=true   --set logs.persistence.existingClaim=airflow-logs

## uid
uid 如果用默认设置，会是50000，如果不知道为啥一直在用1001，可以改values.yaml，把50000改成1001就行。

## 报警
必须显式配置


## Dockerfile
如果需要在airflow的worker里安装软件或者python的包，可以自己做个镜像，然后在values.yaml里用自己的镜像即可。 不知道为啥，values.yaml里repo的地址不支持写ip，所以如果想用本地的镜像库的话，估计需要在k8s里搞一下域名解析。图简单可以直接用阿里云的镜像服务，目前是免费的。下面是dockerfile
```yaml
FROM apache/airflow:latest-python3.10
USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  build-essential gcc wget sshpass

RUN wget http://prdownloads.sourceforge.net/ta-lib/ta-lib-0.4.0-src.tar.gz && \
  tar -xvzf ta-lib-0.4.0-src.tar.gz && \
  cd ta-lib/ && \
  ./configure --prefix=/usr && \
  make && \
  make install

USER airflow
COPY requirements.txt /
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" -r /requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple --trusted-host pypi.tuna.tsinghua.edu.cn

```
编译镜像的命令
```bash
TAG=local_py310_v5
docker build . -t apache/airflow:$TAG
docker tag apache/airflow:$TAG registry.cn-beijing.aliyuncs.com/reponame/airflow:$TAG
docker push registry.cn-beijing.aliyuncs.com/reponame/airflow:$TAG
```

value.yaml更改
```yaml
# Images
images:
  airflow:
    repository: registry.cn-beijing.aliyuncs.com/reponame/airflow
    tag: local_py310_v5
    # Specifying digest takes precedence over tag.
    digest: ~
    pullPolicy: IfNotPresent
```

