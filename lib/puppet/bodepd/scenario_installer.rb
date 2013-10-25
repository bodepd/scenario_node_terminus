require File.join(
  File.dirname(__FILE__), '..', '..',
  'puppet/bodepd/scenario_helper.rb'
)
include Puppet::Bodepd::ScenarioHelper

module Puppet
  module Bodepd
    module ScenarioInstaller

      def setup_data(options={})
        scenario = get_scenario_name
        # override the scenario
        puts "Enter your scenario. Press enter to use default [#{scenario}]"
        $stdout.flush
        scenario_name = gets
      end

    end
  end
end
