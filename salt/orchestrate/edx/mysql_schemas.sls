#!jinja|yaml

{% set ENVIRONMENT = salt.environ.get('ENVIRONMENT') %}
{% set environment = salt.pillar.get('environments:{}'.format(ENVIRONMENT)) %}
{% set purposes = environment.purposes %}
{% set edxlocal_databases = {
  'XQUEUE_MYSQL_DB_NAME': 'xqueue',
  'EDXAPP_MYSQL_DB_NAME': 'edxapp',
  }
%}

{% set edxapp_mysql_host = 'mysql.service.{}.consul'.format(ENVIRONMENT) %}
{% set edxapp_mysql_port = 3306 %}
{% set edxapp_mysql_creds = salt.vault.read(
    'mysql-{env}/creds/admin'.format(
        env=ENVIRONMENT)) %}

{% for db,name in edxlocal_databases.iteritems() %}
{% for purpose in purposes %}
edxapp_create_db_{{ name }}_{{ purpose }}:
  mysql_database.present:
    - name: {{ name }}_{{ purpose|replace('-', '_') }}
    - connection_user: {{ edxapp_mysql_creds.data.username }}
    - connection_pass: {{ edxapp_mysql_creds.data.password }}
    - connection_host: {{ edxapp_mysql_host }}
    - connection_port: {{ edxapp_mysql_port }}
{% endfor %}
{% endfor %}
