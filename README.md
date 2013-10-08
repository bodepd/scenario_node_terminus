# about

This module contains a custom node terminus that allows
for scenarios based deployments

# installation

1. install this module
2. synchronize it's plugins
3. configure puppet.conf

    [master]
      node_terminus=scenario

# usage

Confiugre the following yaml files in /etc/puppet/data

* config.yaml
    global config that will be passed to Puppet as top scope variables
    it also contains a special key called scenarios

* scnarios/<name>.yaml
    Directory that contains the possible deployment scenarios.
    Each scenario contains the following:

** roles - list of roles that exist as a part of that scenario
*** each role contains a list of classes specified as either classes or class_groups

* class_gorups/<name>.yaml

Contains a list of classes available in each class group

* role_mappings.yaml

Contains a list of hostnames that the roles that they should be suppied.

# command line tools

This module also comes with a collection of tools that can be used for debugging:

All of these utilities are implemented as a Puppet Face. To see the available commands, run:

    puppet help scenario

or to learn about an individual commadn:

    puppet help scenerio get_classes

It currently supports two commands:

To retrieve the list of classes that are associated with a role:

    puppet scenario get_clases <ROLE_NAME> --render-as yaml

To retrieve the list of classes together with their specified data:

    puppet scenario compile_role <ROLE_NAME> --render-as yaml
