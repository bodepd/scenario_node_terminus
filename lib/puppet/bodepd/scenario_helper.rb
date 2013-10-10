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

      def get_hiera_data_from_key(key, options)
        certname      = options[:certname_for_facts]
        global_config = get_global_config
        Puppet.info("Finding our nodes facts and merging them with global dat;
")
        global_cofig  = find_facts(certname).merge(global_config)
        data_mapping  = lookup_data_mapping(key, global_config)
        hiera_data    = lookup_hiera_data(data_mapping || key, global_config)
        Puppet.info("Found value: '#{hiera_data}'")
        hiera_data
      end

      # returns a list of all classes assocated with a role
      def get_classes_from_role(role, options)
        certname      = options[:certname_for_facts]
        global_config = get_global_config
        global_cofig  = find_facts(certname).merge(global_config)
        get_classes_per_scenario(global_config, role)
      end

      # given a role, figure out what classes are included, and
      # what parameters are set to what values for those classes
      def compile_everything(role, options)
        certname      = options[:certname_for_facts]
        global_config = find_facts(certname).merge(get_global_config)
        class_list = get_classes_per_scenario(global_config, role)
        class_hash = {}
        class_list.each do |x|
          class_hash[x] = {}
        end

        # get all keys from data_mappings
        data_mappings = compile_data_mappings(global_config)

        # get hiera data
        hiera_data    = compile_hiera_data(
                          global_config,
                          'hiera_data',
                          options[:interpolate_hiera_data]
                        )

        # resolve hiera lookups
        lookedup_data = {}
        data_mappings.each do |k,v|
          if hiera_data[v] == nil
            if v =~ /%\{([^\}]*)\}/
              lookedup_data[k] = interpolate_string(v, global_config.merge(hiera_data))
            else
              if class_hash[get_namespace(v)]
                raise(Exception, "data mapping #{v} not found in hiera data")
              end
            end
          else
            lookedup_data[k] = hiera_data[v]
          end
        end

        lookups = hiera_data.merge(lookedup_data)
        lookup_without_globals= {}
        lookups.each do |k,v|
          klass_name = get_namespace(k)
          if class_hash[klass_name]
            class_hash[klass_name][k] = v
          end
        end
        class_hash

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

      # load the global config from $confdir/data/config.yaml
      # and verify that it specifies a scenario
      def get_global_config
        # load the global configuration data
        global_config = {}
        global_config_file = get_data_file(data_dir, 'config.yaml')
        if File.exists?(global_config_file)
          global_config = YAML.load_file(global_config_file)
        else
          raise(Exception, 'config.yaml must exist')
        end
        if ! global_config || ! global_config['scenario']
          raise(Exception, 'scenario must be defined in config.yaml')
        end
        Puppet.info("Found scenario: #{global_config['scenario']} in #{global_config_file}")
        Puppet.info("Using scenario to help determine hiera globals")
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
        scenario_file = get_data_file(File.join(data_dir, 'scenarios'), "#{name}.yaml")
        unless File.exists?(scenario_file)
          raise(Exception, "scenario file #{scenario_file} does not exist")
        end
        YAML.load_file(scenario_file)
      end

      # returns all classes in the specified groups

      # I may need to be clever enough to try to find dep loops
      # or not even allow class groups to contain class groups
      def get_classes_from_groups(group_names, scope={})
        # expect that each group file
        if group_names
          group_dir = File.join(data_dir, 'class_groups')
          group_names.reduce([]) do |result, name|
            group_file = get_data_file(group_dir, "#{name}.yaml")
            unless File.exists?(group_file)
              raise(Exception, "Group file #{group_file} does not exist")
            end
            class_group = YAML.load_file(group_file)
            result +
            (class_group['classes'] || []).map{|x| interpolate_string(x, scope)} +
            get_classes_from_groups(
              (class_group['class_groups'] || []).map{|x| interpolate_string(x, scope)}, scope
            )
          end.uniq
        else
          []
        end
      end


      # given the name of a node, figure out its role
      def get_role(name)
        role_mapper = get_data_file(data_dir, 'role_mappings.yaml')
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
        global_data = compile_hiera_data(scope, 'global_hiera_params')
        Puppet.debug("Found global data: #{global_data.inspect}")
        global_data
      end

      #
      # take a hiera config file,diretory and scope
      # and use it to retrieve all valid keys in hiera
      #
      def get_keys_per_dir(scope, dir)
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
          yamlfile = get_data_file(File.join(data_dir, dir), "#{source}.yaml")
          Puppet.debug("Searching #{yamlfile} for keys")
          if File.exists?(yamlfile)
            config = YAML.load_file(yamlfile)
            config.each do |k, v|
              data = yield(k,v,data)
            end
          end
        end
        data
      end

      def compile_data_mappings(scope ={})
        get_keys_per_dir(scope, 'data_mappings') do |k, v, data|
          v = Array(v)
          v.each do |x|
            data[x] ||= k
          end
          data
        end
      end

      def lookup_data_mapping(key, scope={})
        Puppet.info("Looking for hiera key: #{key} in data mappings")
        get_keys_per_dir(scope, 'data_mappings') do |k, v, data|
          v = Array(v)
          v.each do |x|
            if x == key
              Puppet.info("Found key: '#{k}' matching: '#{x}'")
              Puppet.info("We will now stop traversing the data_mappings hierarchy")
              Puppet.info("Now, we will look up this key in the hiera_data")
              return k
            end
            puts x if x =~ /#{key}/
          end
        end
        Puppet.info("Did not find anything matching parameter: #{key}")
        return nil
      end

      def lookup_hiera_data(key, scope={})
        Puppet.info("Looking for hiera key: #{key}")
        get_keys_per_dir(scope, 'hiera_data') do |k, v, data|
          if k == key
            Puppet.info("Found key in hiera with value: #{v}")
            Puppet.info("We will not stop traversing hiera_data")
            if v =~ /%\{([^\}]*)\}/
              Puppet.info("Interpolating value from globals and facts")
              return interpolate_string(v, scope)
            else
              return v
            end
          end
        end
      end

      def compile_hiera_data(scope ={}, dir='hiera_data', interpolate_hiera_data=true)
        get_keys_per_dir(scope, dir) do |k, v, data|
          data[k] ||= \
                    ((interpolate_hiera_data &&
                     interpolate_string(v, scope)) ||
                     v
                    ) 
          data
        end
      end

      #
      # get the hierarchy configured in the specified hiera file
      # The hierarchy default to scenario/%{scenario}, common if
      # if cannot find one
      #
      def get_hierarchy(file)
        default_hierarchy = ["scenario/%{scenario}", 'common']
        if File.exists?(file)
          (YAML.load_file(file) || {})[:hierarchy] || default_hierarchy
        else
          default_hierarchy
        end
      end

      # get Puppet's confdir
      def confdir
        Puppet[:confdir]
      end

      # get the datadir
      def data_dir
        @data_dir ||= File.join(Puppet[:confdir], 'data')
      end

      def interpolate_string(string, scope)
        if string.is_a?(String)
          string.gsub(/%\{([^\}]*)\}/) do
            scope[$1] || raise(Exception, "Interpolation for #{$1} failed")
          end
        else
          string
        end
      end

      def find_facts(certname)
        Puppet.info("Finding facts for host: #{certname} using terminus: #{Puppet[:facts_terminus]}")
        if facts = Puppet::Face[:facts, :current].find(certname)
          Puppet.debug(facts.to_yaml)
          facts.values
        else
          Puppet.warning("No facts found for: #{certname}")
          {}
        end
      end

      private

        # This method is just here to make testing easier.
        # this way, I can just stub out this method and return
        # a tmpfile for testing purposes
        def get_data_file(dir, file_name)
          File.join(dir, file_name)
        end

        def get_namespace(param)
          param_a = param.split('::')
          if param_a.size > 1
            return param_a[0..-2].join('::')
          else
            ''
            #raise("Param: #{param} has no namespace")
          end
        end

    end
  end
end
