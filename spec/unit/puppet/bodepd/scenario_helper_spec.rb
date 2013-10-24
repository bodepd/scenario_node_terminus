require 'puppet/bodepd/scenario_helper'
require 'spec_helper'
require 'tempfile'
describe 'scenerio helper methods' do

  include Puppet::Bodepd::ScenarioHelper

  # stubs the data file to a specific tmp file
  def data_file_stubber(name, file_path, dir)

    self.stubs(
      :get_data_file
    ).with(dir, "#{name}.yaml").returns(file_path)
  end

  # stubs class_groups
  def class_group_file_stubber(name, file_path)
    data_file_stubber(name, file_path, '/etc/puppet/data/class_groups')
  end

  # stubs config.yaml
  def config_file_stubber(file_name)
    data_file_stubber('config', file_name, '/etc/puppet/data')
  end

  # stubs global_hiera_params
  def global_file_stubber(global_name, file_name)
    data_file_stubber(global_name, file_name, '/etc/puppet/data/global_hiera_params')
  end

  def scenario_file_stubber(name, tmp_file)
    data_file_stubber(name, tmp_file, '/etc/puppet/data/scenarios')
  end

  def role_mapper_file_stubber(tmp_file_name)
    data_file_stubber('role_mappings', tmp_file_name, '/etc/puppet/data')
  end

  def hiera_data_file_stubber(name, tmp_file_name)
    data_file_stubber(name, tmp_file_name, '/etc/puppet/data/hiera_data')
  end

  def data_mapper_file_stubber(name, tmp_file_name)
    data_file_stubber(name, tmp_file_name, '/etc/puppet/data/data_mappings')
  end

  def setup_data_mappings
    @data_mapping_1 = tmp_file(<<-EOT
verbose:
  - foo::verbose
  - bar::verbose
"interpolation_%{foo}":
  - foo::somevar
  - bar::somevar
duder:
  - var1
  - var2
EOT
    )
    @data_mapping_2 = tmp_file(<<-EOT
verbose:
  - foo::verbose
  - blah::verbose
debug:
  - bar::verbose
  - bar::somevar
EOT
    )
    data_mapper_file_stubber('common', @data_mapping_1)
    data_mapper_file_stubber('scenario/scenario_name', @data_mapping_2)
  end

  def setup_hiera_data
    @hiera_data_1 = tmp_file(<<-EOT
key: value
overridable_key: default_value
array:
  - one
hash
  one: two
EOT
    )
    @hiera_data_2 = tmp_file(<<-EOT
interpolated: "%{foo}"
overridable_key: overridden_value
array:
  - two
hash:
  three: four
EOT
    )
    hiera_data_file_stubber('common', @hiera_data_1)
    hiera_data_file_stubber('scenario/scenario_name', @hiera_data_2 )
  end

  # sets up config.yaml
  def setup_config_test_data
    @config = tmp_file(<<-EOT
scenario: scenario_name
EOT
    )
    config_file_stubber(@config)
  end

  # sets up global config
  def setup_global_test_data
    @global_common = tmp_file(<<-EOT
foo: bar
bar: blah
EOT
    )
    @global_scenario = tmp_file(<<-EOT
foo: baz
four: value
blah: "%{scenario}"
EOT
    )
    global_file_stubber('common', @global_common)
    global_file_stubber('scenario/scenario_name', @global_scenario)
  end

  def setup_node_role_mapping
    @roles = tmp_file(<<-EOT
node1: role1
node2: role2
EOT
    )
    role_mapper_file_stubber(@roles)
  end

  def setup_scenario_test_data
    @scenario = tmp_file(<<-EOT
roles:
  role1:
    classes:
      - one
    class_groups:
      - bar
      - foo
  role2:
    classes:
      - "%{foo}"
EOT
    )
    scenario_file_stubber('scenario_name' ,@scenario)
  end

  # used to setup some class groups that can be used
  # for testing
  def setup_class_group_test_data
    class_group_file_stubber('none', get_non_file)
    @class_group_foo = tmp_file(<<-EOT
classes:
  - one
  - two
  - three
EOT
    )
    @class_group_bar = tmp_file(<<-EOT
classes:
  - "%{four}"
class_groups:
  - baz
EOT
    )
    @class_group_baz = tmp_file(<<-EOT
classes:
  - five
EOT
      )
    @class_group_blah = tmp_file(<<-EOT
class_groups:
  - blah
EOT
      )
    class_group_file_stubber('foo', @class_group_foo)
    class_group_file_stubber('bar', @class_group_bar)
    class_group_file_stubber('baz', @class_group_baz)
    class_group_file_stubber('blah', @class_group_blah)
  end

  before do
    Puppet.stubs(:[]).with(:confdir).returns('/etc/puppet/')
    @empty_file = tmp_file('')
  end

  describe 'when getting node from name' do

    describe 'when role_mapping is valid' do
      before do
        self.stubs(:find_facts).returns({'key'=> 'value'})
        setup_config_test_data
        setup_global_test_data
        setup_scenario_test_data
        setup_class_group_test_data
        setup_node_role_mapping
        setup_hiera_data
        setup_data_mappings
      end
      it 'should return class list and globals' do
        node1 = get_node_from_name('node1')
        node1[:classes].sort.should == ['five', 'one', 'three', 'two', 'value']
        params = node1[:parameters]
        params['role'].should     == 'role1'
        params['blah'].should     == 'scenario_name'
        params['foo'].should      == 'baz'
        params['four'].should     == 'value'
        params['scenario'].should == 'scenario_name'
        params['bar'].should      == 'blah'
      end
      it 'should be able to interpolate inline classes' do
        node2 = get_node_from_name('node2')
        node2[:classes].include?('baz').should be_true
      end
      it 'should support interpolation of class groups'
      it 'should not return classes for nodes without roles' do
        node3 = get_node_from_name('node3')
        params = node3[:parameters]
        node3[:classes].should == []
        params['role'].should be_nil
        params['blah'].should     == 'scenario_name'
        params['foo'].should      == 'baz'
        params['four'].should     == 'value'
        params['scenario'].should == 'scenario_name'
        params['bar'].should      == 'blah'
      end
      it 'should compile data in node_data_bindings parameter' do
        node3 = get_node_from_name('node3')
        puts node3[:parameters]['node_data_bindings'].inspect
      end
    end

  end

  describe 'when compiling everything' do

    it 'should be able to get all class with their parameters'

  end

  describe 'when compiling all data' do

     before do
       setup_config_test_data
       setup_global_test_data
       #setup_hiera_data
       #setup_data_mappings
     end

    describe 'when data_mappings do not match keys' do

      before do
        local_data_mapping = tmp_file(<<-EOT
verbose:
  foo::verbose
EOT
        )
        data_mapper_file_stubber('common', local_data_mapping)
        local_hiera = tmp_file(<<-EOT
somevar: value
EOT
        )
        hiera_data_file_stubber('common', local_hiera)
      end

      it 'when key matches class, we should fail' do

        expect do
          compile_all_data({}, ['foo'], {})
        end.to raise_error(Exception, /data mapping verbose not found/)

      end

      it 'when key does not match class, warn, and set it to nil' do
        data = compile_all_data({}, [], {})
        data['foo::verbose'].should be_nil
        data.has_key?('foo::verbose')
      end

    end


    describe 'when keys match' do

      before do
        local_data_mapping = tmp_file(<<-EOT
key:
  class::param
"my_%{foo}":
  dude::duder
EOT
        )
        data_mapper_file_stubber('common', local_data_mapping)
        local_hiera = tmp_file(<<-EOT
foo: bar
key: value
a: "%{blah}"
EOT
        )
        hiera_data_file_stubber('common', local_hiera)
      end


      it 'should be able to resovle partial string mathces' do
        data = compile_all_data({}, [], {})
        data['dude::duder'].should == 'my_bar'
      end

      it 'should be able to process a basic match' do
        data = compile_all_data({}, [], {})
        data['class::param'].should == 'value'
      end

      it 'should allow non-mapping hiera globals' do
        data = compile_all_data({}, [], {})
        data['foo'].should == 'bar'
      end

      it 'should not interpolate hiera data by default' do
        data = compile_all_data({}, [], {})
        data['a'].should == '%{blah}'
      end

      it 'should interpolate when enabled' do
        data = compile_all_data({'blah' => 'v2'}, [], {:interpolate_hiera_data => true})
        data['a'].should == 'v2'
      end

      it 'should fail when it cannot interpolate' do
        expect do
          compile_all_data({}, [], {:interpolate_hiera_data => true})
        end.to raise_error(Exception, /Interpolation for blah failed/)
      end

    end

    it 'hiera keys should override data_mappings' do
      local_data_mapping = tmp_file(<<-EOT
key:
  class::param
EOT
        )
      data_mapper_file_stubber('common', local_data_mapping)
      local_hiera = tmp_file(<<-EOT
key: value
class::param: overridden_value
EOT
        )
      hiera_data_file_stubber('common', local_hiera)
      data = compile_all_data({}, [], {})
      data['class::param'].should == 'overridden_value'
    end
  end

  describe 'when getting path information' do
    it 'should get puppet\'s confdir' do
      confdir.should == '/etc/puppet/'
    end
    it 'should get the datadir' do
      data_dir.should == '/etc/puppet/data'
    end
  end

  describe 'when getting global data' do

    it 'should fail where there is no config.yaml' do
      get_non_file
      self.expects(:get_data_file).with('/etc/puppet/data', 'config.yaml').returns(get_non_file)
      expect do
        get_global_config
      end.to raise_error(Exception, /config\.yaml must exist/)
    end
    it 'should fail when no scenario is set' do
      self.expects(:get_data_file).with('/etc/puppet/data', 'config.yaml').returns(@empty_file)
      expect do
        get_global_config
      end.to raise_error(Exception, /scenario must be defined in config\.yaml/)
    end
    it 'should load global settings' do
      setup_config_test_data
      setup_global_test_data
      self.expects('get_hierarchy').returns(["scenario/%{scenario}", 'common'])
      config = get_global_config
      config['foo'].should      == 'baz'
      config['blah'].should     == 'scenario_name'
      config['scenario'].should == 'scenario_name'
    end

  end

  describe 'when getting classes from groups' do
    before do
      setup_class_group_test_data
    end
    it 'should fail if the class group file does not exist' do
      get_classes_from_groups(['foo']).should == ['one', 'two', 'three']
    end
    it 'should be able to get classes from a single group' do
      expect do
        get_classes_from_groups(['none'])
      end.to raise_error
    end
    it 'should be able to get classes from multiple groups with interpolation' do
      get_classes_from_groups(['foo', 'bar'], {'four' => 'f'}).should == \
        ['one', 'two', 'three', 'f', 'five']
      get_classes_from_groups(['foo', 'bar', 'baz'], {'four' => 'f'}).should == \
        ['one', 'two', 'three', 'f', 'five']
    end
    # TODO this test should pass. The code should be smart enough to protect
    # against infinite recursion
    #it 'should be able to get classes from multiple groups with interpolation' do
    #  get_classes_from_groups(['blah']).should == \
    #    ['one', 'two', 'three', 'f', 'five']
    #end
  end

  # can I not use a hiera lib for this?
  describe 'when interpolating a string' do
    before do
      @interp_scope = {'one' => 1, 'two' => 2}
    end
    it 'should interpolate matches' do
      interpolate_string("foo", @interp_scope).should == 'foo'
      interpolate_string("dude%{one}", @interp_scope).should == 'dude1'
      interpolate_string("dude%{one}f%{two}e", @interp_scope).should == 'dude1f2e'
    end
    it 'should fail when there is no match' do
      expect do
        interpolate_string("dude%{one}f%{two}e%{three}", @interp_scope)
      end.to raise_error(Exception, /Interpolation for three failed/)
    end
    it 'does not perform interpolation on arrays (yet...)' do
      interpolate_string(['one', 'two', "%{three}"], @interp_scope).should == \
        ['one', 'two', "%{three}"]
    end

  end

  describe 'when getting role' do
    before do
      @role_file = tmp_file(<<-EOT
foo: bar
foo.bar: baz
EOT
      )
    end
    describe 'with invalid role file' do
      it 'should fail when the role_mapping file does not exist' do
        self.expects(:get_data_file).with('/etc/puppet/data', 'role_mappings.yaml').returns(get_non_file)
        expect do
          get_role('foo')
        end.to raise_error(Exception, /should exist/)
      end
    end
    describe 'with valid role file' do
      before do
        self.expects(:get_data_file).with('/etc/puppet/data', 'role_mappings.yaml').returns(@role_file)
      end
      it 'should be able to match role' do
        get_role('foo').should == 'bar'
      end
      it 'should be able to match with partial fqdn' do
        get_role('foo.blah').should == 'bar'
      end
      it 'should match whole name over partial' do
        get_role('foo.bar').should == 'baz'
      end
      it 'should return nil to indicate no match' do
        get_role('bar').should be_nil
      end
    end
  end

  describe 'when compiling hiera data' do
    before :each do
      Puppet.stubs(:[]).with(:confdir).returns('/etc/puppet/')
      # stub the expected hierarchy
      self.expects('get_hierarchy').returns(["scenario/%{scenario}", 'common'])
      # stub the expected files to be found
      setup_hiera_data
    end
    it 'should support basic lookup' do
      scope_hash = {'scenario' => 'scenario_name', 'foo' => 'blah'}
      hiera_data = compile_hiera_data(scope_hash)
      hiera_data['key'].should == 'value'
    end
    it 'should interpolate by default' do
      scope_hash = {'scenario' => 'scenario_name', 'foo' => 'blah'}
      hiera_data = compile_hiera_data(scope_hash)
      hiera_data['interpolated'].should == 'blah'
    end
    it 'should support overrides' do
      scope_hash = {'scenario' => 'scenario_name', 'foo' => 'blah'}
      hiera_data = compile_hiera_data(scope_hash)
      hiera_data['overridable_key'].should == 'overridden_value'
    end
    it 'should override entire arrays' do
      scope_hash = {'scenario' => 'scenario_name', 'foo' => 'blah'}
      hiera_data = compile_hiera_data(scope_hash)
      hiera_data['array'].should == ['two']
    end
    it 'should override entire hashes' do
      scope_hash = {'scenario' => 'scenario_name', 'foo' => 'blah'}
      hiera_data = compile_hiera_data(scope_hash)
      hiera_data['hash'].should == {'three' => 'four'}
    end
    it 'should not interpolate when interpolate_data is set to false' do
      scope_hash = {'scenario' => 'scenario_name', 'foo' => 'blah'}
      hiera_data = compile_hiera_data(scope_hash, 'hiera_data', false)
      hiera_data['interpolated'].should == '%{foo}'
    end
  end

  describe 'when compiling all data_mappings' do

    before :each do
      Puppet.stubs(:[]).with(:confdir).returns('/etc/puppet/')
      # stub the expected hierarchy
      self.expects('get_hierarchy').returns(["scenario/%{scenario}", 'common'])
      # stub the expected files to be found
      setup_data_mappings
    end

    it 'should support basic lookups' do
      scope_hash = {'scenario' => 'scenario_name', 'foo' => 'blah'}
      compiled_keys = compile_data_mappings(scope_hash)
      compiled_keys['var1'].should == 'duder'
      compiled_keys['var2'].should == 'duder'
    end

    it 'should support overrides' do
      scope_hash = {'scenario' => 'scenario_name', 'foo' => 'blah'}
      compiled_keys = compile_data_mappings(scope_hash)
      compiled_keys['bar::verbose'].should == 'debug'
    end

    it 'should not yet perform interpolation' do
      scope_hash = {'scenario' => 'scenario_name', 'foo' => 'blah'}
      compiled_keys = compile_data_mappings(scope_hash)
      compiled_keys['foo::somevar'].should == 'interpolation_%{foo}'
    end

  end

  describe 'when retrieving hierarchy' do

    before do
      @tmp_good_file = tmp_file(<<-EOF
:hierarchy:
  - one
  - "two/%{two}"
EOF
      )
      @tmp_bad_file  = tmp_file('')
    end

    it 'should return defaults if it cannot find one' do
      self.stubs(:get_hierarchy_file).returns(@tmp_bad_file)
      get_hierarchy.should == ["scenario/%{scenario}", 'common']
    end

    it 'should return defaults if it file doees not exist' do
      self.stubs(:get_hierarchy_file).returns(get_non_file)
      get_hierarchy.should == ["scenario/%{scenario}", 'common']
    end

    it 'should return the current hierarchy' do
      self.stubs(:get_hierarchy_file).returns(@tmp_good_file)
      get_hierarchy.should == ['one', "two/%{two}"]
    end

  end

  def get_non_file
    no_file = Tempfile.new('baz')
    path    = no_file.path
    no_file.unlink
    path
  end

  def tmp_file(string)
    good_file = Tempfile.new('foo')
    filename  = good_file.path
    good_file.write(string)
    good_file.close
    filename
  end

end
