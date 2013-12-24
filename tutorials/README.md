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

#### Install

Get basic tools

    apt-get update
    apt-get install git vim puppet -y

Install puppet modules we need to update to latest puppet

    cd /etc/puppet/modules
    git clone https://github.com/puppetlabs/puppetlabs-stdlib stdlib
    git clone https://github.com/stephenrjohnson/puppetlabs-puppet puppet
    git clone https://github.com/puppetlabs/puppetlabs-apt apt
    cd puppet && git checkout 0.0.18 && cd ..

Install scenario_node_terminus module

    git clone https://github.com/bodepd/scenario_node_terminus scenario_node_terminus

Install puppet 3.2.3

    puppet apply /vagrant/setup.pp

Create a testing module

    mkdir -p /etc/puppet/modules/testing/manifests
    cat > /etc/puppet/modules/testing/manifests/test.pp<<EOF
    class testing::test (
      \$message = "I like nothing"
    ) {
        notice("Message is: \${message}")
    }
    EOF

#### Scenarios

The main tool to inspect what's going on is the scenario sub command

    puppet scenario
    puppet scenario get_scenario

Set our scenario

    mkdir -p /etc/puppet/data
    echo "scenario: cats" > /etc/puppet/data/config.yaml

This should return 'cats'

    puppet scenario get_scenario

The scenario node terminus is now minimally set. Let's configure Hiera So that it will load data based on which scenario is set

    cat > /etc/puppet/hiera.yaml<<EOF
    ---
    :backends:
      - data_mapper
    :hierarchy:
      - %{scenario}
    EOF

The important thing to note is that based on which scenario we set, with this hierarchy the node terminus will load the scenario name with the yaml extension. Puppet.conf is set to load hiera from /etc/puppet/data/hiera_data, so a scenario of ‘cats’ will load data from /etc/puppet/data/hiera_data/cats.yaml


Create a role mapping. This will make the machine with hostname 'precise64' take the role of 'test'

    cat > /etc/puppet/data/role_mappings.yaml<<EOF
    precise64: test
    EOF

Now we create our scenario. The filename will be the scenario name, under the scenario directory. Include our test class in the role we made using the following syntax:

    mkdir -p /etc/puppet/data/scenarios
    cat > /etc/puppet/data/scenarios/cats.yaml<<EOF
    roles:
      test:
        classes:
          - testing::test
    EOF

So at this point, we have a scenario called ‘cats’, we have mapped a hostname ‘precise64’ to a role ‘test’, we have added the role ‘test’ to the scenario ‘cats’, and finally have included our test class ‘testing::test’ in the role. This allows us to say which nodes should be filling which roles in our deployment (role_mappings), it lets us say which roles should be available in our deployment (scenario), and it allows us to say which puppet classes should be in each role (scenario+roles)


Let's see what happens!

    puppet apply -e ""

The class we made takes a parameter. The strength of puppet modules is in their reusability. Recall that our hierarchy includes %{scenario}, and our hiera directory is data/hiera_data. We can pass in class parameters at any point in the hierarchy:

    mkdir -p /etc/puppet/data/hiera_data
    cat > /etc/puppet/data/hiera_data/cats.yaml<<EOF
    testing::test::message: 'I like cats!'
    EOF

This is how to change the data passed to a class based on which scenario is loaded. Observe the results:

    puppet apply -e ""

#### Classes

We included a small test class in the previous section, let's

look at how we can use classes more effectively.


Make some more serious looking classes: nginx and django

    mkdir -p /etc/puppet/modules/nginx/manifests
    mkdir -p /etc/puppet/modules/django/manifests

Lets pretend this class sets up Nginx to act as a reverse proxy for

A given downstream host+port

    cat > /etc/puppet/modules/nginx/manifests/server.pp<<EOF
    class nginx::server (
      \$port = '80',
      \$bind = 'localhost',

      \$downstream_host = undef,
      \$downstream_port = undef
    ) {
       notice("Nginx will bind to \${bind} on port \${port}")
       if \$downstream_host {
         notice("Nginx will proxy for \${downstream_host} on port \${downstream_port}")
       }
    }
    EOF

Lets pretend this deploys our django app and runs it on a particular

host + port, and it requires an admin password to be specified

    cat > /etc/puppet/modules/django/manifests/app.pp<<EOF
    class django::app(
      \$admin_pw,
      \$port = '5000',
      \$host = 'localhost'
    ){
       notice("Django will run on \${host} on port \${port}")
    }
    EOF

So let's make a new scenario called 'django'

    echo 'scenario: django' > /etc/puppet/data/config.yaml

And let's make a role for this host:

    echo 'precise64: appserver' > /etc/puppet/data/role_mappings.yaml

ow, let's add both nginx and django to our role in the django scenario

    cat > /etc/puppet/data/scenarios/django.yaml<<EOF
    roles:
      appserver:
        classes:
          - nginx::server
          - django::app
    EOF

Now let's run.

    puppet apply -e ""

We need to specify the password for the django::app class!

Take a look at the hiera order. We should add somewhere we

can add user data. This should be above everything else in

the order, so we can override defaults.

    cat > /etc/puppet/hiera.yaml<<EOF
    ---
    :backends:
      - data_mapper
    :hierarchy:
      - user
      - %{scenario}
    EOF

Now we can add our admin password to user.yaml

    echo "django::app::admin_pw: 'password'" > /etc/puppet/data/hiera_data/user.yaml

Now let's try that again

    puppet apply -e ""


There is another abstraction we can use to group up classes.

Let's say we have a number of classes we want to add to all

of our nodes that are running django: one that installs supervisord

and one that installs gunicorn.


    mkdir -p /etc/puppet/modules/gunicorn/manifests
    mkdir -p /etc/puppet/modules/supervisor/manifests
    cat > /etc/puppet/modules/gunicorn/manifests/server.pp<<EOF
    class gunicorn::server(
    ){
       notice("Installed Gunicorn")
    }
    EOF

    cat > /etc/puppet/modules/supervisor/manifests/init.pp<<EOF
    class supervisor::init(
    ){
       notice("Installed Supervisor")
    }
    EOF

Django is a community module so we don't want to add includes there.

We add them to the appserver role in the scenario yaml:

    cat > /etc/puppet/data/scenarios/django.yaml<<EOF
    roles:
      appserver:
        classes:
          - nginx::server
          - django::app
          - gunicorn::server
          - supervisor::init
    EOF

This is OK, but since the three classes at the bottom are essentially tied

together, we can simplify the role by making a class group. The class group

is matched by filename, so django_app.yaml will provide a class group of

django_app

    mkdir -p /etc/puppet/data/class_groups
    cat > /etc/puppet/data/class_groups/django_app.yaml<<EOF
    classes:
      - gunicorn::server
      - supervisor::init
      - django::app
    EOF

Now update our scenario to use the new class group

    cat > /etc/puppet/data/scenarios/django.yaml<<EOF
    roles:
      appserver:
        class_groups:
          - django_app
        classes:
          - nginx::server
    EOF

Now we should get the same thing, but we've grouped classes together

to form a logical unit. This can also be useful if you want to include

something on all your nodes, like monitoring and alert software, by

creating a base class_group that contains all the stuff that you want

everywhere.

    puppet apply -e ""

So now we have nginx and django on one server,

but they aren't talking to each other! We need

to pass nginx a parameter to tell it where the

downstream is.


this isn't user specific, it's going to happen

for all users of the scenario, so we'll put it

in %{scenario}.yaml


    echo "nginx::server::downstream_host: localhost" > /etc/puppet/data/hiera_data/django.yaml
    echo "nginx::server::downstream_port: 5000" >> /etc/puppet/data/hiera_data/django.yaml

    puppet apply -e ""

So now nginx is proxying for our django app, which is good.

Now let's say we want to run django on a different port.:

This is a user customisation, so we'll keep it in user.yaml


    echo "django::app::port: 6000" >> /etc/puppet/data/hiera_data/user.yaml

OK, so we changed the django port and that worked, but nginx is still

proxying for the old port. The solution to this is data mappings.


Set up data mappings in config:

    echo ":data_mapper:" >> /etc/puppet/hiera.yaml
    echo "  :datadir: /etc/puppet/data/data_mappings" >> /etc/puppet/hiera.yaml

It will follow the same hierarchy as hiera - %scenario or user.yaml

can be used under the data_mappings directory. We'll use the scenario

since this seems like a generally applicable mapping.

    mkdir -p /etc/puppet/data/data_mappings
    cat > /etc/puppet/data/data_mappings/django.yaml<<EOF
    application_port:
      - django::app::port
      - nginx::server::downstream_port
    EOF

Now we edit user.yaml to include the application_port:

    cat > /etc/puppet/data/hiera_data/user.yaml<<EOF
    django::app::admin_pw: password
    application_port: 6000
    EOF

We remove the port specification that was in django.yaml

    echo "nginx::server::downstream_host: localhost" > /etc/puppet/data/hiera_data/django.yaml

This results in both django and nginx modules agreeing on port 6000.

    puppet apply -e ""

#### Global Parameters

Globals can be used to change the classes present in a role .

Let's say we want to add a DB backend to our django/rails app


Make some more dummy classes:

    mkdir -p /etc/puppet/modules/postgres/manifests
    mkdir -p /etc/puppet/modules/mysql/manifests

postgres class

    cat > /etc/puppet/modules/postgres/manifests/server.pp<<EOF
    class postgres::server(
      \$password
    )
    {
           notice("Installing postgres")
    }
    EOF

mysql class

    cat > /etc/puppet/modules/mysql/manifests/server.pp<<EOF
    class mysql::server(
      \$admin_password
    )
    {
           notice("Installing mysql")
    }
    EOF

Now, what we want is to be able to change our app between using mysql and postgres,

but without necessarily changing the scenario. This means we don't have to make

scenarios for every single combination, we can just change one line of yaml and

reuse the same scenario for both databases.


First, we add the database choice into our heirarchy in hiera.yaml

We also add a new file called common, that will be used for things

that affect all deployments, not just the current scenario.


We put common at the bottom, since in  practice, it's a collection of

good defaults that the scenario and user may want to override

    cat > /etc/puppet/hiera.yaml<<EOF
    ---
    :backends:
      - data_mapper
    :hierarchy:
      - user
      - %{scenario}
      - %{db_type}
      - common
    :data_mapper:
      :datadir: /etc/puppet/data/data_mappings
    EOF

Now, we make a new directory for our globals:

    mkdir -p /etc/puppet/data/global_hiera_params

Now, because in our scenarios, we want to be able to choose a db,

we put db_type into common.yaml

    echo "db_type: postgres" >> /etc/puppet/data/global_hiera_params/common.yaml

Let's add our DB to the django scenario:

    cat > /etc/puppet/data/scenarios/django.yaml<<EOF
    roles:
      appserver:
        class_groups:
          - django_app
        classes:
          - nginx::server
          - "%{db_type}::server"
    EOF

if we do a puppet apply now, the class will be included, but we haven't set its parameter

so it will fail. We have the db_type as part of the hierarchy, so we can add postgres.yaml

to hiera_data.

    echo "postgres::server::password: test" >> /etc/puppet/data/hiera_data/postgres.yaml

If we now apply our config, we should have postgres installed!

    puppet apply -e ""

Let's try out mysql. Change the db_type in the globals to mysql

    echo "db_type: mysql" > /etc/puppet/data/global_hiera_params/common.yaml

Now we need to pass in the argument for that class, the same as we did for pgsql

    echo "mysql::server::admin_password: test" > /etc/puppet/data/hiera_data/mysql.yaml

And test...

    puppet apply -e ""

And we're done! This should give you an idea of how you can use globals to switch between

classes that you know you're going to need. Maybe you want to support deploying with mysql/postgres

or apache/nginx. You can create new scenarios for each combination, but scenarios are a heavier

tool that is best use for describing the hostname->role mappings, whereas a global is a good way to

switch between implementations of a role. So in our case, the role might be 'database' and the db_type

global can switch between mysql and postgres. A data_mapping for common parameters (like admin password)

would also help simplify switching between the two.


#### Globals that add classes

Globals can also be used to add classes to roles.

in the previous section we saw that we can swap

which class is included by a role based on a global,

but what if you want to sometimes add a class, and

sometimes have nothing at all?


An example of this is including debugging tools. Let's

make a new class that includes systemtap, which we don't

want on our prod servers, but which we do want on our QA

servers. Using a global, we can have the same scenario

for prod and QA, and change a single line of yaml to

add our debugging tool to the QA servers.


Create our systemtap class

    mkdir -p /etc/puppet/modules/systemtap/manifests
    cat > /etc/puppet/modules/systemtap/manifests/init.pp<<EOF
    class systemtap::init()
    {
      notice("Systemtap installed")
    }
    EOF

Add a debug global, we'll use user.yaml because racecar

    echo "debug: true" > /etc/puppet/data/global_hiera_params/user.yaml

Update the heirarchy to support the debug choice

    cat > /etc/puppet/hiera.yaml<<EOF
    ---
    :backends:
      - data_mapper
    :hierarchy:
      - user
      - %{scenario}
      - %{db_type}
      - debug/%{debug}
      - common
    :data_mapper:
      :datadir: /etc/puppet/data/data_mappings
    EOF

This will search for data in scenarios/debug/%{debug}, so let's make

that directory

    mkdir -p /etc/puppet/data/scenarios/debug

Now, if debug is true, we want to add the systemtap::init class to the appserver

role. We do that like so:

    cat > /etc/puppet/data/scenarios/debug/true.yaml<<EOF
    roles:
      appserver:
        classes:
          - systemtap::init
    EOF

Now when we apply, we should see systemtap added.

    puppet apply -e ""

If we set debug to anything other than true, it won't be added.

because the file name won't be there

    echo "debug: not_true" > /etc/puppet/data/global_hiera_params/user.yaml

    puppet apply -e ""

