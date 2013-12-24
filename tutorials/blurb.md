# Next-gen puppet-openstack tutorials

## Problem Statement

The old puppet-openstack module was/is difficult to work with for a couple of reasons:

- It is the top of a deep hierarchy, which means it needs to have all parameters for the lower classes. Adding data to deep classes is irritating as we have to work our way down.
- The top level classes aren't compose-able - openstack::all != openstack::control + openstack::compute
- It's not introspectable, which is painful when there are so many different ways to deploy and so much data involved.

## Solution

The scenario_node_terminus provides us with a number of mechanisms to alleviate these issues, and is paired with the data model in the puppet_openstack_builder project.

<https://github.com/bodepd/scenario_node_terminus>
<https://github.com/stackforge/puppet_openstack_builder>

### Scenario Node Terminus

The scenario node terminus relies on hiera for class data, is designed to use composable roles, uses yaml for everything, and provides introspection tools.

#### Requirements

These instructions use vagrant, which requires Virtualbox. Make sure both are installed before proceeding.
