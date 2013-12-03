## Global Parameters

# Globals can be used to change the classes present in a role .
# Let's say we want to add a DB backend to our django/rails app

# Make some more dummy classes:
mkdir -p /etc/puppet/modules/postgres/manifests
mkdir -p /etc/puppet/modules/mysql/manifests

# postgres class
cat > /etc/puppet/modules/postgres/manifests/server.pp<<EOF
class postgres::server(
  \$password
)
{
       notice("Installing postgres")
}
EOF

# mysql class
cat > /etc/puppet/modules/mysql/manifests/server.pp<<EOF
class mysql::server(
  \$admin_password
)
{
       notice("Installing mysql")
}
EOF

# Now, what we want is to be able to change our app between using mysql and postgres,
# but without necessarily changing the scenario. This means we don't have to make
# scenarios for every single combination, we can just change one line of yaml and
# reuse the same scenario for both databases.

# First, we add the database choice into our heirarchy in hiera.yaml
# We also add a new file called common, that will be used for things
# that affect all deployments, not just the current scenario.

# We put common at the bottom, since in  practice, it's a collection of
# good defaults that the scenario and user may want to override
cat > /etc/puppet/hiera.yaml<<EOF
---
:backends:
  - data_mapper
:hierarchy:
  - user
  - %{scenario}
  - %{db_type}
  - common
:data_mapper:
  :datadir: /etc/puppet/data/data_mappings
EOF

# Now, we make a new directory for our globals:
mkdir -p /etc/puppet/data/global_hiera_params

# Now, because in our scenarios, we want to be able to choose a db,
# we put db_type into common.yaml
echo "db_type: postgres" >> /etc/puppet/data/global_hiera_params/common.yaml

# Let's add our DB to the django scenario:
cat > /etc/puppet/data/scenarios/django.yaml<<EOF
roles:
  appserver:
    class_groups:
      - django_app
    classes:
      - nginx::server
      - "%{db_type}::server"
EOF

# if we do a puppet apply now, the class will be included, but we haven't set its parameter
# so it will fail. We have the db_type as part of the hierarchy, so we can add postgres.yaml
# to hiera_data.
echo "postgres::server::password: test" >> /etc/puppet/data/hiera_data/postgres.yaml

# If we now apply our config, we should have postgres installed!
puppet apply -e ""

# Let's try out mysql. Change the db_type in the globals to mysql
echo "db_type: mysql" > /etc/puppet/data/global_hiera_params/common.yaml

# Now we need to pass in the argument for that class, the same as we did for pgsql
echo "mysql::server::admin_password: test" > /etc/puppet/data/hiera_data/mysql.yaml

# And test...
puppet apply -e ""

# And we're done! This should give you an idea of how you can use globals to switch between
# classes that you know you're going to need. Maybe you want to support deploying with mysql/postgres
# or apache/nginx. You can create new scenarios for each combination, but scenarios are a heavier
# tool that is best use for describing the hostname->role mappings, whereas a global is a good way to
# switch between implementations of a role. So in our case, the role might be 'database' and the db_type
# global can switch between mysql and postgres. A data_mapping for common parameters (like admin password)
# would also help simplify switching between the two.
