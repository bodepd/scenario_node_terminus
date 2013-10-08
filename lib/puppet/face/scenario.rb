require 'puppet/face'
require 'puppet/bodepd/scenario_helper'

include Puppet::Bodepd::ScenarioHelper
Puppet::Face.define(:scenario, '0.0.1') do
  action :compile_role do


    summary "Compile an entire role for a specific scenario."

    arguments "role"

    option "--map_params_in_classes" do
      summary 'indicates the the parameters that are relevent to each class should be mapped in'
    end

    description <<-'EOT'
      Compiles the complete scenario
    EOT

    when_invoked do |role, options|
      compile_everything(role)
    end

  end

  action :get_classes do

    summary 'Get all classes from the provided data directory and role'

    arguments "role"

    description <<-'EOT'
      Given the provided data, get the full list of classes
    EOT

    when_invoked do |role, options|
      get_classes_from_role(role)
    end

  end

end
