include puppet::repo::puppetlabs

Exec["apt_update"] -> Package <| |>

case $::osfamily {
  'Redhat': {
    $puppet_version = '3.2.3-1.el6'
    $pkg_list       = ['git', 'curl', 'httpd']
  }
  'Debian': {
    $puppet_version = '3.2.3-1puppetlabs1'
    $pkg_list       = ['git', 'curl', 'vim', 'cobbler']
    package { 'puppet-common':
      ensure => $puppet_version,
    }
  }
}

package { 'puppet':
  ensure  => $puppet_version,
}
