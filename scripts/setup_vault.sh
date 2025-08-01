#bin/bash
docker-compose exec vault vault secrets enable database


docker-compose exec vault vault write database/config/demo \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(mysql:3306)/" \
    allowed_roles="demo-role" \
    username="root" password="rootpassword"


docker-compose exec vault vault write database/roles/demo-role \
    db_name=demo \
    creation_statements="
      CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';
      GRANT SELECT ON demo.* TO '{{name}}'@'%';
    " \
    default_ttl="1m" max_ttl="5m"

    vault secrets enable database

    vault write database/config/demo \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(mysql:3306)/" \
    allowed_roles="demo-role" \
    username="root" password="rootpassword"

    vault write database/roles/demo-role \
    db_name=demo \
    creation_statements="
      CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';
      GRANT SELECT, INSERT ON demo.* TO '{{name}}'@'%';
    " \
    default_ttl="1m" max_ttl="5m"