## Scenarios

# The main tool to inspect what's going on is the scenario sub command
puppet scenario
puppet scenario get_scenario

# Set our scenario
mkdir -p /etc/puppet/data
echo "scenario: cats" > /etc/puppet/data/config.yaml

# This should return 'cats'
puppet scenario get_scenario

# The scenario node terminus is now minimally set. Let's configure Hiera So that it will load data based on which scenario is set
cat > /etc/puppet/hiera.yaml<<EOF
---
:backends:
  - data_mapper
:hierarchy:
  - %{scenario}
EOF

# The important thing to note is that based on which scenario we set, with this hierarchy the node terminus will load the scenario name with the yaml extension. Puppet.conf is set to load hiera from /etc/puppet/data/hiera_data, so a scenario of ‘cats’ will load data from /etc/puppet/data/hiera_data/cats.yaml

# Create a role mapping. This will make the machine with hostname 'precise64' take the role of 'test'
cat > /etc/puppet/data/role_mappings.yaml<<EOF
precise64: test
EOF

# Now we create our scenario. The filename will be the scenario name, under the scenario directory. Include our test class in the role we made using the following syntax:
mkdir -p /etc/puppet/data/scenarios
cat > /etc/puppet/data/scenarios/cats.yaml<<EOF
roles:
  test:
    classes:
      - testing::test
EOF

# So at this point, we have a scenario called ‘cats’, we have mapped a hostname ‘precise64’ to a role ‘test’, we have added the role ‘test’ to the scenario ‘cats’, and finally have included our test class ‘testing::test’ in the role. This allows us to say which nodes should be filling which roles in our deployment (role_mappings), it lets us say which roles should be available in our deployment (scenario), and it allows us to say which puppet classes should be in each role (scenario+roles)

# Let's see what happens!
puppet apply -e ""

# The class we made takes a parameter. The strength of puppet modules is in their reusability. Recall that our hierarchy includes %{scenario}, and our hiera directory is data/hiera_data. We can pass in class parameters at any point in the hierarchy:
mkdir -p /etc/puppet/data/hiera_data
cat > /etc/puppet/data/hiera_data/cats.yaml<<EOF
testing::test::message: 'I like cats!'
EOF

# This is how to change the data passed to a class based on which scenario is loaded. Observe the results:
puppet apply -e ""
