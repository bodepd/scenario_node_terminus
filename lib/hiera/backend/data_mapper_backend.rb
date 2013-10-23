class Hiera
  module Backend
    class Data_mapper_backend

      def lookup(key, scope, order_override, resolution_type)
        unless data_bindings = scope['node_data_bindings']
          raise(
            Exception,
            "expected variable: #{node_data_bindings} to be set from node terminus"
          )
        end
        data_bindings[key]
      end

    end

  end
end
