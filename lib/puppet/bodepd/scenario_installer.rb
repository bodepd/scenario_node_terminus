require File.join(
  File.dirname(__FILE__), '..', '..',
  'puppet/bodepd/scenario_helper.rb'
)
include Puppet::Bodepd::ScenarioHelper

module Puppet
  module Bodepd
    module ScenarioInstaller

      def setup_data(options={})
        global_config = get_global_config
        global_config['scenario'] = interact('scenario', get_scenario_name)
        # write out scenario
        if branch_question('Do you want to set global hiera params?', 'no')
          global_config.each do |k, v|
            unless k == 'scenario'
              global_config[k] = interact(k, v)
            end
          end
        end
        puts 'Now it is time to set user data'
        user_data = get_user_data
        user_data.each do |k,v|
          user_data[k] = interact(k,v)
        end
      end

      def interact(data_name, default_value)
        puts "Enter data for #{data_name}. Press enter to use default [#{default_value}]"
        $stdout.flush
        value = STDIN.gets.chomp
        value = value.empty? ? default_value : value
        raise(Exception, "Must support value for #{data_name}") if value == nil
        value
      end

      def branch_question(question, default_value='no')
        puts "#{question} Y|N [#{default_value}]"
        $stdout.flush
        value = STDIN.gets.chomp.downcase
        value = value.empty? ? default_value : value
        if ['y', 'yes'].include?(value)
          return true
        elsif ['n', 'no'].include?(value)
          return false
        else
          raise(Excetion, "#{value} is not value. excepts yes or no")
        end
      end

      def write_to_file(values, file)

      end

    end
  end
end
