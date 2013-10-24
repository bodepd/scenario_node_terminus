class Hiera
  module Backend
    class Data_mapper_backend

      def lookup(key, scope, order_override, resolution_type)
        require 'puppet/bodepd/scenario_helper'
        unless data_bindings = scope['node_data_bindings']
          raise(
            Exception,
            "expected variable: #{node_data_bindings} to be set from node terminus"
          )
        end
        include Puppet::Bodepd::ScenerioHelper
        interpolate_data(data_bindings[key], scope)
      end

    end

  end
end
