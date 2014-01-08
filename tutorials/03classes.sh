## Classes

# We included a small test class in the previous section, let's look at how we can use classes more effectively.

# Make some more serious looking classes: nginx and django
mkdir -p /etc/puppet/modules/nginx/manifests
mkdir -p /etc/puppet/modules/django/manifests

# Lets pretend this class sets up Nginx to act as a reverse proxy for A given downstream host+port
cat > /etc/puppet/modules/nginx/manifests/server.pp<<EOF
class nginx::server (
  \$port = '80',
  \$bind = 'localhost',

  \$downstream_host = undef,
  \$downstream_port = undef
) {
   notice("Nginx will bind to \${bind} on port \${port}")
   if \$downstream_host {
     notice("Nginx will proxy for \${downstream_host} on port \${downstream_port}")
   }
}
EOF

# Lets pretend this deploys our django app and runs it on a particular host + port, and it requires an admin password to be specified
cat > /etc/puppet/modules/django/manifests/app.pp<<EOF
class django::app(
  \$admin_pw,
  \$port = '5000',
  \$host = 'localhost'
){
   notice("Django will run on \${host} on port \${port}")
}
EOF

# So let's make a new scenario called 'django'
echo 'scenario: django' > /etc/puppet/data/config.yaml

# And let's make a role for this host:
echo 'precise64: appserver' > /etc/puppet/data/role_mappings.yaml

#Now, let's add both nginx and django to our role in the django scenario
cat > /etc/puppet/data/scenarios/django.yaml<<EOF
roles:
  appserver:
    classes:
      - nginx::server
      - django::app
EOF

# Now let's run.
puppet apply -e ""

# We need to specify the password for the django::app class! Take a look at the hiera order. We should add somewhere we can add user data. This should be above everything else in the order, so we can override defaults.
cat > /etc/puppet/hiera.yaml<<EOF
---
:backends:
  - data_mapper
:hierarchy:
  - user
  - %{scenario}
EOF

# Now we can add our admin password to user.yaml
echo "django::app::admin_pw: 'password'" > /etc/puppet/data/hiera_data/user.yaml

# Now let's try that again
puppet apply -e ""


# There is another abstraction we can use to group up classes. Let's say we have a number of classes we want to add to all of our nodes that are running django: one that installs supervisord and one that installs gunicorn.

mkdir -p /etc/puppet/modules/gunicorn/manifests
mkdir -p /etc/puppet/modules/supervisor/manifests
cat > /etc/puppet/modules/gunicorn/manifests/server.pp<<EOF
class gunicorn::server(
){
   notice("Installed Gunicorn")
}
EOF

cat > /etc/puppet/modules/supervisor/manifests/init.pp<<EOF
class supervisor::init(
){
   notice("Installed Supervisor")
}
EOF

# Django is a community module so we don't want to add includes there. We add them to the appserver role in the scenario yaml:
cat > /etc/puppet/data/scenarios/django.yaml<<EOF
roles:
  appserver:
    classes:
      - nginx::server
      - django::app
      - gunicorn::server
      - supervisor::init
EOF

# This is OK, but since the three classes at the bottom are essentially tied together, we can simplify the role by making a class group. The class group is matched by filename, so django_app.yaml will provide a class group of django_app
mkdir -p /etc/puppet/data/class_groups
cat > /etc/puppet/data/class_groups/django_app.yaml<<EOF
classes:
  - gunicorn::server
  - supervisor::init
  - django::app
EOF

# Now update our scenario to use the new class group
cat > /etc/puppet/data/scenarios/django.yaml<<EOF
roles:
  appserver:
    class_groups:
      - django_app
    classes:
      - nginx::server
EOF

# Now we should get the same thing, but we've grouped classes together to form a logical unit. This can also be useful if you want to include something on all your nodes, like monitoring and alert software, by creating a class_group that contains all the stuff that you want everywhere.
puppet apply -e ""
