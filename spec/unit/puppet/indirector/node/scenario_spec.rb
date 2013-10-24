require 'spec_helper'
require 'puppet'
require 'tempfile'
require 'puppet/indirector/node/scenario'
describe Puppet::Node::Scenario do

  let(:request) do
    Puppet::Indirector::Request.new(:node,
                                    :find,
                                    "the-node-named-foo",
                                    :environment => "production")
  end

  before :each do
    Puppet.initialize_settings
  end

  it 'should be able to return a node' do
    info = {
      :classes => [1],
      :parameters => {'1' => '2'}
    }
    node_indirector = Puppet::Node::Scenario.new
    node_indirector.expects(:get_node_from_name).with('the-node-named-foo').returns(info)
    node = node_indirector.find(request)
    node.classes.should == [1]
    node.parameters['1'].should == '2'
  end

end
