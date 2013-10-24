require File.join(
  File.dirname(__FILE__), '..', '..',
  'puppet/bodepd/scenario_helper.rb'
)
class Hiera
  module Backend
    class Data_mapper_backend

      include Puppet::Bodepd::ScenarioHelper

      def lookup(key, scope, order_override, resolution_type)
        unless data_bindings = scope['node_data_bindings']
          raise(
            Exception,
            "expected variable: #{node_data_bindings} to be set from node terminus"
          )
        end
        interpolate_data(data_bindings[key], scope)
      end

    end

  end
end
