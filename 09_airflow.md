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



