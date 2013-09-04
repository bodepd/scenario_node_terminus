require 'puppet/node'
require 'yaml'

class Puppet::Node::Exec < Puppet::Indirector::Exec
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

  def find(request)

    # create a node
    node = Puppet::Node.new(name)
    
    # get the global configuration
    global_config = get_global_config

    # get the scenario
    scenario = global_config[:scenario]

    # retrieve classes per roles from scenario
    roles = get_role_classes_from_scenario(scenario)

    # get classes from roles
    class_list = roles[get_role(request.key)]

    # set parameters and class in the node
    node.parameters=global_configs
    node.classes=class_list

    # merge facts into the node
    node.fact_merge

    # pass the node back to Puppet
    node
  end

  def confdir
    Puppet[:confdir]
  end

  def datadir
    @data_dir = File.join(Puppet[:confdir], 'data')
  end

  # load the global config from $confdir/data/config.yaml
  # and verify that it specifies a scenario
  def get_global_config
    # load the global configuration data
    global_config_file = File.join(data_dir, 'config.yaml')
    unless File.exists?(global_config_file)
      raise(Exception, "#{global_config_file} does not exist")
    end
    global_config = YAML.load(global_config_file)
    unless global_config['scenario']
      raise(Exception, 'global config must specify key "scenario"')
    end
    global_config
  end

  # returns a hash that maps each role to all classes that will
  # be applied a part of that role
  def get_role_classes_from_scenario(name)
    role_classes = {}
    # iterate through each roles in a scenario
    get_scenario_data(name)['roles'].each do |role_name, values|
      role_classes['role_name'] = values['classes'] + get_classes_from_groups(values[''])
    end
    role_classes
  end

  # load a scenario's YAML
  def get_scenario_data(name)
    scenario_file = File.join(data_dir, 'scenarios', "#{name}.yaml")
    unless File.exsits?(scenario_file)
      raise(Exception, "scenario file #{scenario_file} does not exist")
    end
    YAML.load(scenario_file)
  end

  # returns all classes in the specified groups
  def get_classes_from_groups(group_names)
    # expect that each group file
    group_dir = File.join(data_dir, 'class_groups')
    group_names.reduce([]) do |result, name|
      group_file = File.join(group_dir, "#{name}.yaml")
      unless File.exists?(group_file)
        raise(Exception, "Group file #{group_file} does not exist")
      end
      result + YAML.load(group_file)
    end
  end


  def get_role(name)
    role_mapper = File.join(datadir, 'role_mappings.yaml')
    unless File.exists?(role_mapper)
      raise(Exception, "Role mapping file: #{role_mapper} should exist")
    end
    YAML.load(role_mapper)[name]
  end

end
