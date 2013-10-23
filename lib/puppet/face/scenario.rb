require File.join(
  File.dirname(__FILE__), '..', '..',
  'puppet/bodepd/scenario_helper.rb'
)
include Puppet::Bodepd::ScenarioHelper

Puppet::Face.define(:scenario, '0.0.1') do
  action :compile_role do


    option '--certname_for_facts CERTNAME' do
      summary 'The certname to use to retrieve facts used to compile hierarchies'
      default_to { Puppet[:certname] }
    end

    option '--interpolate_hiera_data' do
      summary 'Tells hiera to interpolate its data'
    end

    summary "Compile an entire role for a specific scenario."

    arguments "role"

    option "--map_params_in_classes" do
      summary 'indicates the the parameters that are relevent to each class should be mapped in'
    end

    description <<-'EOT'
      Compiles the complete scenario

      If the hierarchy to get those classes requires facts, you
      may have to set the internal Puppet options of facts_terminus
      and certname in order to get the correct facts for testing.
    EOT

    when_invoked do |role, options|
      compile_everything(role, options)
    end

  end

  action :get_classes do

    summary 'Get all classes from the provided data directory and role'

    arguments 'role'

    description <<-'EOT'
      Given the provided data, get the full list of classes.

      If the hierarchy to get those classes requires facts, you
      may have to set the internal Puppet options of facts_terminus
      and certname in order to get the correct facts for testing.
    EOT

    when_invoked do |role, options|
      get_classes_from_role(role, options)
    end

  end

  action :get_hiera_data do

    summary 'get the current value of a piece of data'

    arguments 'key'

    option '--interpolate_hiera_data' do
      summary 'Tells hiera to interpolate its data'
    end

    option '--certname_for_facts CERTNAME' do
      summary 'The certname to use to retrieve facts used to compile hierarchies'
      default_to { Puppet[:certname] }
    end

    when_invoked do |key, options|
      get_hiera_data_from_key(key, options)
    end

  end

  action :get_scenario do

    summary 'returns the name of the current scenario'

    when_invoked do |options|
      get_scenario_name
    end

  end

  action :get_roles do

    summary 'returns the list of roles for the currently configure scenario'

    when_invoked do |options|
      get_all_roles
    end

  end

  action :get_class_group do

    summary 'return list of classes with their data bindings for a given class group.'

    arguments 'class_group'

    when_invoked do |class_group, options|
      get_class_group_data(class_group, options)
    end
  end

end
