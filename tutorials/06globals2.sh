## Globals that add classes

# Globals can also be used to add classes to roles.
# in the previous section we saw that we can swap
# which class is included by a role based on a global,
# but what if you want to sometimes add a class, and
# sometimes have nothing at all?

# An example of this is including debugging tools. Let's
# make a new class that includes systemtap, which we don't
# want on our prod servers, but which we do want on our QA
# servers. Using a global, we can have the same scenario
# for prod and QA, and change a single line of yaml to
# add our debugging tool to the QA servers.

# Create our systemtap class
mkdir -p /etc/puppet/modules/systemtap/manifests
cat > /etc/puppet/modules/systemtap/manifests/init.pp<<EOF
class systemtap::init()
{
  notice("Systemtap installed")
}
EOF

# Add a debug global, we'll use user.yaml because racecar
echo "debug: true" > /etc/puppet/data/global_hiera_params/user.yaml

# Update the heirarchy to support the debug choice
cat > /etc/puppet/hiera.yaml<<EOF
---
:backends:
  - data_mapper
:hierarchy:
  - user
  - %{scenario}
  - %{db_type}
  - debug/%{debug}
  - common
:data_mapper:
  :datadir: /etc/puppet/data/data_mappings
EOF

# This will search for data in scenarios/debug/%{debug}, so let's make
# that directory
mkdir -p /etc/puppet/data/scenarios/debug

# Now, if debug is true, we want to add the systemtap::init class to the appserver
# role. We do that like so:
cat > /etc/puppet/data/scenarios/debug/true.yaml<<EOF
roles:
  appserver:
    classes:
      - systemtap::init
EOF

# Now when we apply, we should see systemtap added.
puppet apply -e ""

# If we set debug to anything other than true, it won't be added.
# because the file name won't be there
echo "debug: not_true" > /etc/puppet/data/global_hiera_params/user.yaml

puppet apply -e ""
