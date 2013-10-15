require 'puppet/indirector/yaml'
require 'puppet/node'
require 'puppet/bodepd/scenario_helper'
require 'yaml'

class Puppet::Node::Scenario < Puppet::Indirector::Yaml
  desc <<-EOT

Defer to an external group of yaml config files to drive classification
and set global parameters.

The global parameters that are set are assumed to be the parameters
that are required to setup your override hierarchy for hiera calls.

The data passed back to Puppet is looked up as follows:

1. /etc/puppet/data/global.config

This file is expected to have a list of key value pairs that
will be forwarded to Puppet as global variables. These variables
can be used to configure how the hiera lookup overrides will work.

This file is also expected to contain the special key scenario:

The scenario key will be used to determine what roles are available
and what classes are supplied as a part of that role.

2. /etc/puppet/data/scenarios/<name>.yaml

This file contains a list of roles associated with your scenario.
Each of those roles has list of classes and class groups.

3. /etc/puppet/data/class_groups/<name>.yaml

Each class groups contains a list of classes that need to be
supplied to a scenario.

4. /etc/puppet/data/role_mappings.yaml

This file maps nodes to the roles that they should be assigned.

  EOT

  include Puppet::Bodepd::ScenarioHelper

  def find(request)
    classification_info = get_node_from_name(request.key)
    node = Puppet::Node.new(request.key)
    node.parameters = classification_info[:parameters]
    node.classes    = classification_info[:classes]
    node.fact_merge
    node
  end
end
