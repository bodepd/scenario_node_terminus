## Install

# Get basic tools
apt-get update
apt-get install git vim puppet -y

# Install puppet modules we need to update to latest puppet
cd /etc/puppet/modules
git clone https://github.com/puppetlabs/puppetlabs-stdlib stdlib
git clone https://github.com/stephenrjohnson/puppetlabs-puppet puppet
git clone https://github.com/puppetlabs/puppetlabs-apt apt
cd puppet && git checkout 0.0.18 && cd ..

# Install scenario_node_terminus module
git clone https://github.com/bodepd/scenario_node_terminus scenario_node_terminus

# Install puppet 3.2.3
puppet apply /vagrant/setup.pp

# Create a testing module
mkdir -p /etc/puppet/modules/testing/manifests
cat > /etc/puppet/modules/testing/manifests/test.pp<<EOF
class testing::test (
  \$message = "I like nothing"
) {
    notice("Message is: \${message}")
}
EOF
