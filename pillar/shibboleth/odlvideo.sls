{% import_yaml salt.cp.cache_file('salt://environment_settings.yml') as env_settings }
{% set ENVIRONMENT = salt.environ.get('ENVIRONMENT', 'rc-apps') %}
{% set env_data = env_settings[ENVIRONMENT] %}
{% set server_domain_name = env_data.purposes['odl-video-service'].domain %}

nginx-shibboleth:
  overrides:
    generate_sp_cert: False
  secrets:
    key: |
      {{ salt.vault.read('secret-odl-video/{env}/shibboleth/sp-key'.format(env=ENVIRONMENT).data.value|indent(6) }}
    cert: |
      {{ salt.vault.read('secret-odl-video/{env}/shibboleth/sp-cert'.format(env=ENVIRONMENT).data.value|indent(6) }}
  config:
    shibboleth2:
      SPConfig:
        RequestMapper:
          RequestMap:
            Host:
              name: {{ server_domain_name }}
        ApplicationDefaults:
          entityID: https://{{ server_domain_name }}/shibboleth
