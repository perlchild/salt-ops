{% for profile in ['elasticsearch', 'kibana', 'fluentd'] %}
ensure_instance_profile_exists_for_{{ profile }}:
  boto_iam_role.present:
    - name: {{ profile }}-instance-role
{% endfor %}

deploy_logging_cloud_map:
  salt.function:
    - name: saltutil.runner
    - tgt: 'roles:master'
    - tgt_type: grain
    - arg:
        - cloud.map_run
    - kwarg:
        path: /etc/salt/cloud.maps.d/logging-map.yml
        parallel: True

resize_root_partitions_on_elasticsearch_nodes:
  salt.state:
    - tgt: 'roles:elasticsearch'
    - tgt_type: grain
    - sls: utils.grow_partition

load_pillar_data_on_logging_nodes:
  salt.function:
    - name: saltutil.refresh_pillar
      tgt: 'P@roles:(elasticsearch|kibana|fluentd)'
      tgt_type: compound

populate_mine_with_logging_node_data:
  salt.function:
    - name: mine.update
    - tgt: 'P@roles:(elasticsearch|kibana|fluentd)'
    - tgt_type: compound

build_logging_nodes:
  salt.state:
    - tgt: 'P@roles:(elasticsearch|kibana|fluentd)'
    - tgt_type: compound
    - highstate: True

# Obtain the grains for one of the elasticsearch nodes
{% set grains = salt.saltutil.runner(
    'mine.get',
    tgt='roles:elasticsearch', fun='grains.item', tgt_type='grain'
    ).items()[0][1] %}
# PUT the mapper template into the ES _template index
put_elasticsearch_mapper_template:
  http.query:
    - name: http://{{ grains['ec2:local_ipv4'] }}:9200/_template/logstash
    - data: '
      {
        "template":   "logstash-*",
        "settings" : {
          "index.refresh_interval" : "5s"
        },
        "mappings": {
          "_default_": {
            "_all": {
              "enabled": false
            },
            "dynamic_templates": [
              {
                "strings": {
                  "match_mapping_type": "string",
                  "mapping": {
                    "type": "string",
                    "fields": {
                      "raw": {
                        "type":  "string",
                        "index": "not_analyzed",
                        "ignore_above": 256
                      }
                    }
                  }
                }
              }
            ]
          }
        }
      }'
    - method: PUT
    - status: 200

{% set hosts = [] %}
{% for host, grains in salt.saltutil.runner(
    'mine.get',
    tgt='roles:kibana', fun='grains.item', tgt_type='grain'
    ).items() %}
{% do hosts.append(grains['external_ip']) %}
{% endfor %}
register_kibana_dns:
  boto_route53.present:
    - name: logs.odl.mit.edu
    - value: {{ hosts }}
    - zone: odl.mit.edu.
    - record_type: A

{% set hosts = [] %}
{% for host, grains in salt.saltutil.runner(
    'mine.get',
    tgt='G@roles:fluentd and G@roles:aggregator', fun='grains.item', tgt_type='compound'
    ).items() %}
{% do hosts.append(grains['external_ip']) %}
{% endfor %}
register_log_aggregator_dns:
  boto_route53.present:
    - name: log-input.odl.mit.edu
    - value: {{ hosts }}
    - zone: odl.mit.edu.
    - record_type: A

{% set hosts = [] %}
{% for host, grains in salt.saltutil.runner(
    'mine.get',
    tgt='G@roles:fluentd and G@roles:aggregator', fun='grains.item', tgt_type='compound'
    ).items() %}
{% do hosts.append(grains['ec2:local_hostname']) %}
{% endfor %}
register_log_aggregator_internal_dns:
  boto_route53.present:
    - name: log-input.private.odl.mit.edu
    - value: {{ hosts }}
    - zone: odl.mit.edu.
    - record_type: CNAME