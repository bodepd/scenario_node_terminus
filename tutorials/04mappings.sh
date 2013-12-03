# So now we have nginx and django on one server,
# but they aren't talking to each other! We need
# to pass nginx a parameter to tell it where the
# downstream is.

# this isn't user specific, it's going to happen
# for all users of the scenario, so we'll put it
# in %{scenario}.yaml

echo "nginx::server::downstream_host: localhost" > /etc/puppet/data/hiera_data/django.yaml
echo "nginx::server::downstream_port: 5000" >> /etc/puppet/data/hiera_data/django.yaml

puppet apply -e ""

# So now nginx is proxying for our django app, which is good.
# Now let's say we want to run django on a different port.:
# This is a user customisation, so we'll keep it in user.yaml

echo "django::app::port: 6000" >> /etc/puppet/data/hiera_data/user.yaml

# OK, so we changed the django port and that worked, but nginx is still
# proxying for the old port. The solution to this is data mappings.

# Set up data mappings in config:
echo ":data_mapper:" >> /etc/puppet/hiera.yaml
echo "  :datadir: /etc/puppet/data/data_mappings" >> /etc/puppet/hiera.yaml

# It will follow the same hierarchy as hiera - %scenario or user.yaml
# can be used under the data_mappings directory. We'll use the scenario
# since this seems like a generally applicable mapping.
mkdir -p /etc/puppet/data/data_mappings
cat > /etc/puppet/data/data_mappings/django.yaml<<EOF
application_port:
  - django::app::port
  - nginx::server::downstream_port
EOF

# Now we edit user.yaml to include the application_port:
cat > /etc/puppet/data/hiera_data/user.yaml<<EOF
django::app::admin_pw: password
application_port: 6000
EOF

# We remove the port specification that was in django.yaml
echo "nginx::server::downstream_host: localhost" > /etc/puppet/data/hiera_data/django.yaml

# This results in both django and nginx modules agreeing on port 6000.
puppet apply -e ""
