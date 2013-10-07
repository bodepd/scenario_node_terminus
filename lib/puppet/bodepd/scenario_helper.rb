#
# contains helper methods for scenario
# operations
#
require 'yaml'
require 'puppet'
require 'puppet/node'

module Puppet
  module Bodepd
    module ScenarioHelper

      def get_node_from_name(node_name)

        node = Puppet::Node.new(node_name)

        Puppet.debug("Looking up classes for #{node_name}")

        # get the global configuration
        global_config = get_global_config
        node.parameters = global_config

        # get classes from roles
        role                  = get_role(node_name)
        global_config['role'] = role

        # get classes from scenario and role
        node.classes = get_classes_per_scenario(global_config, role)

        # merge facts into the node
        node.fact_merge

        # pass the node back to Puppet
        node
      end

      # returns a list of all classes assocated with a role
      def get_classes_from_role(role)
        global_config = get_global_config
        get_classes_per_scenario(global_config, role)
      end

      def compile_everything(role)
        global_config = get_global_config
        class_list = get_classes_per_scenario(global_config, role)

        # get all keys from data_mappings
        data_mappings = get_keys_per_dir('data_mappings', global_config)

        puts data_mappings.to_yaml
        get_keys_per_dir('hiera_data', global_config)

      end

      def get_classes_per_scenario(global_config, role)
        scenario = global_config['scenario']
        if scenario
          Puppet.debug("Loading roles for scenario: #{scenario}")
          get_role_classes_from_scenario(scenario, global_config)[role]
        else
          Puppet.debug("Did not find a scenario, no classification will occur")
          []
        end
      end


      # return a list of all class parameters from the hierarcy
      # based on the global variables that we currently know about
      def get_all_class_params(global_config)

        # given this set of globals, I need to figure out the merge hierarchy

      end


      # get Puppet's confdir
      def confdir
        Puppet[:confdir]
      end

      # get the datadir
      def data_dir
        @data_dir ||= File.join(Puppet[:confdir], 'data')
      end

      # load the global config from $confdir/data/config.yaml
      # and verify that it specifies a scenario
      def get_global_config
        # load the global configuration data
        global_config = {}
        global_config_file = File.join(data_dir, 'config.yaml')
        if File.exists?(global_config_file)
          global_config = YAML.load_file(global_config_file)
        end
        overrides = get_global_hiera_data({'scenario' => global_config["scenario"]})
        global_config.merge(overrides)
      end

      # returns a hash that maps each role to all classes that will
      # be applied a part of that role
      def get_role_classes_from_scenario(name, scope)
        role_classes = {}
        # iterate through each roles in a scenario
        get_scenario_data(name)['roles'].each do |role_name, values|
          role_classes[role_name] = (values['classes'] || []) + get_classes_from_groups(values['class_groups'], scope)
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
      def get_classes_from_groups(group_names, scope)
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
            (class_group['classes'] || []).map{|x| interpolate_string(x, scope)} +
            get_classes_from_groups(
              (class_group['class_groups'] || []).map{|x| interpolate_string(x, scope)}, scope
            )
          end
        else
          []
        end
      end

      def interpolate_string(string, scope)
        string.gsub(/%\{([^\}]*)\}/) do
          name = $1
          scope[$1] || raise(Exception, "Interpolation for #{name} failed")
        end
      end

      # given the name of a node, figure out its role
      def get_role(name)
        role_mapper = File.join(data_dir, 'role_mappings.yaml')
        unless File.exists?(role_mapper)
          raise(Exception, "Role mapping file: #{role_mapper} should exist")
        end
        role_mappings = YAML.load_file(role_mapper)
        split_name = name.split('.')
        split_name.size.times do |x|
          cur_name = split_name[0..(split_name.size-x-1)].join('.')
          role = role_mappings[cur_name]
          if role
            Puppet.debug("Found role from role mappings: #{role}")
            return role
          end
        end
        Puppet.debug("Did not find role mapping for #{name}")
        return nil
      end


      #
      # get all keys and their values for all global hiera config
      #
      def get_global_hiera_data(scope)
        get_keys_per_dir('global_hiera_params', scope)
      end

      #
      # take a hiera config file,diretory and scope
      # and use it to retrieve all valid keys in hiera
      #
      def get_keys_per_dir(dir, scope={})
        begin
          require 'hiera'
        rescue
          Puppet.Warning("Hiera libraries could not be loaded")
          return {}
        end
        # get the hiera config file
        hiera_config_file  = File.join(Puppet[:confdir], 'hiera.yaml')
        data = {}
        # iterate through all data sources from this config file
        Hiera::Backend.datasources(
          scope,
          nil,
          get_hierarchy(hiera_config_file)
        ) do |source|
          # search for data overrides in the global_hiera_params directory
          yamlfile = File.join(data_dir, dir, "#{source}.yaml")
          Puppet.debug("Searching #{yamlfile} for keys")
          if File.exists?(yamlfile)
            config = YAML.load_file(yamlfile)
            config.each do |k, v|
              data[k] ||= v
            end
          end
        end 
        data
      end

      #
      # get the hierarchy configured in the specified hiera file
      # The hierarchy default to scenario/%{scenario}, common if
      # if cannot find one
      #
      def get_hierarchy(file)
        default_hierarchy = ["scenario/%{scenario}", 'common']
        if File.exists?(file)
puts  (YAML.load_file(file) || {})[:hierarchy]
          (YAML.load_file(file) || {})[:hierarchy] || default_hierarchy
        else
          default_hierarchy
        end
      end

    end

  end

end
