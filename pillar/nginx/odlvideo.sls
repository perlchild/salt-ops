{% set env_settings = salt.cp.get_file_str("salt://environment_settings.yml")|load_yaml %}
{% set ENVIRONMENT = salt.environ.get('ENVIRONMENT', 'rc-apps') %}
{% set env_data = env_settings[ENVIRONMENT] %}
{% set server_domain_name = env_data.purposes['odl-video-service'].domain %}
{% set odl_wildcard = salt.vault.read('secret-operations/global/odl_wildcard_cert') %}

nginx:
  ng:
    install_from_source: True
    source_version: 1.13.8
    source_hash: 8410b6c31ff59a763abf7e5a5316e7629f5a5033c95a3a0ebde727f9ec8464c5
    certificates:
      odl_wildcard:
        public_cert: |
          {{ odl_wildcard.data.value|indent(10) }}
        private_key: |
          {{ odl_wildcard.data.key|indent(10) }}
    servers:
      managed:
        {{ app_name }}:
          - server:
              - server_name: {{ server_domain_name }}
              - listen:
                  - 80
              - listen:
                  - '[::]:80'
              - location /:
                  - return: 301 https://$host$request_uri
          - server:
              - server_name: {{ server_domain_name }}
              - listen:
                  - 443
                  - ssl
                  - default
              - listen:
                  - '[::]:443'
                  - ssl
              - root: /opt/odl-video-service/
              - ssl_certificate: /etc/nginx/ssl/odl_wildcard.crt
              - ssl_certificate_key: /etc/nginx/ssl/odl_wildcard.key
              - ssl_stapling: 'on'
              - ssl_stapling_verify: 'on'
              - ssl_session_timeout: 1d
              - ssl_session_tickets: 'off'
              - ssl_protocols:
                  - TLSv1.1
                  - TLSv1.2
                  - TLSv1.3
              - ssl_ciphers: "ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256\
                   :ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384\
                   :DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256\
                   :ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384\
                   :ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256\
                   :DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256\
                   :AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS"
              - ssl_prefer_server_ciphers: 'on'
              - resolver: 8.8.8.8
              - location /shibauthorizer:
                  - internal: ''
                  - include: fastcgi_params
                  - include: includes/shib_fastcgi_params
                  - fastcgi_pass: 'unix:/run/shibauthorizer.sock'
              - location /Shibboleth.sso:
                  - include: fastcgi_params
                  - include: includes/shib_fastcgi_params
                  - fastcgi_pass: 'unix:/run/shibresponder.sock'
              - location /login:
                  - include: includes/shib_clear_headers
                  - shib_request: /shibauthorizer
                  - shib_request_use_headers: 'on'
                  - include: uwsgi_params
                  - uwsgi_pass: unix:/run/odl-video/uwsgi.sock
              - location @django:
                  - include: uwsgi_params
                  - uwsgi_pass: unix:/run/odl-video/uwsgi.sock
              - location /:
                  - try_files:
                    - $uri
                    - $uri/
                    - @django
