## Scenarios

# The main tool to inspect what's going on is the scenario sub command
puppet scenario
puppet scenario get_scenario

# Set our scenario
mkdir -p /etc/puppet/data
echo "scenario: cats" > /etc/puppet/data/config.yaml

# This should return 'cats'
puppet scenario get_scenario

# The scenario node terminus is now minimally set. Let's configure Hiera
# So that it will load data based on which scenario
# is set
cat > /etc/puppet/hiera.yaml<<EOF
---
:backends:
  - data_mapper
:hierarchy:
  - %{scenario}
EOF

#Create a testing module
mkdir -p /etc/puppet/modules/testing/manifests
cat > /etc/puppet/modules/testing/manifests/test.pp<<EOF
class testing::test (
  \$message = "I like nothing"
) {
    notice("Message is: \${message}")
}
EOF

# Create a role mappings. This will make the machine with
# hostname 'precise64' take the role of 'test'
cat > /etc/puppet/data/role_mappings.yaml<<EOF
precise64: test
EOF

# Now we create our scenario. The filename will be the scenario name,
# under the scenario directory. Include our test class in the role we
# made using the following syntax:
mkdir -p /etc/puppet/data/scenarios
cat > /etc/puppet/data/scenarios/cats.yaml<<EOF
roles:
  test:
    classes:
      - testing::test
EOF

# Let's see what happens!
puppet apply -e ""

# If we want to pass data in, we follow the hiera.yaml
# ordering we set up. At the moment, that is just going
# to load a file with the name of our current scenario
# under the hiera_data directory. Override the parameters
# by specifying the class and parameter name, then value,
# like so:
mkdir -p /etc/puppet/data/hiera_data
cat > /etc/puppet/data/hiera_data/cats.yaml<<EOF
testing::test::message: 'I like cats!'
EOF

# See what happens now:
puppet apply -e ""
