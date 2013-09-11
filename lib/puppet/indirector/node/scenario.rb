require 'puppet/indirector/yaml'
require 'puppet/node'
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

  def find(request)

    # create a node
    node = Puppet::Node.new(request.key)
    
    # get the global configuration
    @global_config = get_global_config

    # get the scenario
    scenario = @global_config['scenario']

    # retrieve classes per roles from scenario
    roles = get_role_classes_from_scenario(scenario)

    # get classes from roles
    role = get_role(request.key)

    raise(Exception, "Node: #{request.key} has no valid role assigned") unless roles

    @global_config['openstack_role'] = role
    class_list = (roles[role] || [])


    # set parameters and class in the node
    node.parameters=@global_config
    node.classes=class_list

    # merge facts into the node
    node.fact_merge

    # pass the node back to Puppet
    node
  end

  def confdir
    Puppet[:confdir]
  end

  def data_dir
    @data_dir ||= File.join(Puppet[:confdir], 'data')
  end

  # load the global config from $confdir/data/config.yaml
  # and verify that it specifies a scenario
  def get_global_config
    # load the global configuration data
    global_config_file = File.join(data_dir, 'config.yaml')
    unless File.exists?(global_config_file)
      raise(Exception, "#{global_config_file} does not exist")
    end
    global_config = YAML.load_file(global_config_file)
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
      role_classes[role_name] = (values['classes'] || []) + get_classes_from_groups(values['class_groups'])
    end
    role_classes
  end

  # load a scenario's YAML
  def get_scenario_data(name)
    scenario_file = File.join(data_dir, 'scenarios', "#{name}.yaml")
    unless File.exists?(scenario_file)
      raise(Exception, "scenario file #{scenario_file} does not exist")
    end
    YAML.load_file(scenario_file)
  end

  # returns all classes in the specified groups

  # I may need to be clever enough to try to find dep loops
  # or not even allow class groups to contain class groups
  def get_classes_from_groups(group_names)
    # expect that each group file
    if group_names
      group_dir = File.join(data_dir, 'class_groups')
      group_names.reduce([]) do |result, name|
        group_file = File.join(group_dir, "#{name}.yaml")
        unless File.exists?(group_file)
          raise(Exception, "Group file #{group_file} does not exist")
        end
        class_group = YAML.load_file(group_file)
        result +
        (class_group['classes'] || []).map{|x| interpolate_string(x)} +
        get_classes_from_groups(
          (class_group['class_groups'] || []).map{|x| interpolate_string(x)}
        )
      end
    else
      []
    end
  end

  def interpolate_string(string)
    string.gsub(/%\{([^\}]*)\}/) do
      name = $1
      @global_config[$1] || raise(Exception, "Interpolation for #{name} failed")
    end
  end

  # given the name of a node, figure out its role
  def get_role(name)
    role_mapper = File.join(data_dir, 'role_mappings.yaml')
    unless File.exists?(role_mapper)
      raise(Exception, "Role mapping file: #{role_mapper} should exist")
    end
    YAML.load_file(role_mapper)[name]
  end

end
