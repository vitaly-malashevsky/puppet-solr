# == Class: solr::config
# This class sets up solr install
#
# === Parameters
# - The $cores to create
#
# === Actions
# - Copies a new jetty default file
# - Creates solr home directory
# - Downloads the required solr version, extracts war and copies logging jars
# - Creates solr data directory
# - Creates solr config file with cores specified
# - Links solr home directory to jetty webapps directory
#
class solr::config(
  $cores          = $solr::params::cores,
  $version        = $solr::params::solr_version,
  $mirror         = $solr::params::mirror_site,
  $jetty_home     = $solr::params::jetty_home,
  $solr_home      = $solr::params::solr_home,
  ) inherits solr::params {

  if versioncmp($version, '4.1.0') < 0 {
    $prefix = 'apache-solr'
  } else {
    $prefix = 'solr'
  }
  $dl_name        = "${prefix}-${version}.tgz"
  $download_url   = "${mirror}/${version}/${dl_name}"

  #Copy the jetty config file
  file { '/etc/default/jetty':
    ensure  => file,
    source  => 'puppet:///modules/solr/jetty-default',
    require => Package['jetty'],
  }

  file { $solr_home:
    ensure    => directory,
    owner     => 'jetty',
    group     => 'jetty',
    require   => Package['jetty'],
  }

  # download only if WEB-INF is not present and tgz file is not in /tmp:
  exec { 'solr-download':
    path      =>  ['/usr/bin', '/usr/sbin', '/bin'],
    command   =>  "wget ${download_url}",
    cwd       =>  '/tmp',
    creates   =>  "/tmp/${dl_name}",
    onlyif    =>  "test ! -d ${solr_home}/WEB-INF && test ! -f /tmp/${dl_name}",
    timeout   =>  0,
    require   => File[$solr_home],
  }

  exec { 'extract-solr':
    path      =>  ['/usr/bin', '/usr/sbin', '/bin'],
    command   =>  "tar xzvf ${dl_name}",
    cwd       =>  '/tmp',
    onlyif    =>  "test -f /tmp/${dl_name} && test ! -d /tmp/${prefix}-${version}",
    require   =>  Exec['solr-download'],
  }

  exec { 'copy-solr':
    path      =>  ['/usr/bin', '/usr/sbin', '/bin'],
    command   =>  "jar xvf /tmp/${prefix}-${version}/dist/${prefix}-${version}.war",
    cwd       =>  $solr_home,
    onlyif    =>  "test ! -d ${solr_home}/WEB-INF",
    require   =>  Exec['extract-solr'],
  }

  # have to copy logging jars separately from solr 4.3 onwards
  if versioncmp($version, '4.3.0') >= 0 {
    exec { 'copy-solr-logging':
      path      =>  ['/usr/bin', '/usr/sbin', '/bin'],
      command   =>  "cp /tmp/${prefix}-${version}/example/lib/ext/*.jar WEB-INF/lib",
      cwd       =>  $solr_home,
      onlyif    =>  "test -d /tmp/${prefix}-${version}/example/lib/ext",
      require   =>  Exec['extract-solr', 'copy-solr'],
    }
  }

  file { '/var/lib/solr':
    ensure    => directory,
    owner     => 'jetty',
    group     => 'jetty',
    mode      => '0700',
    require   => Package['jetty'],
  }

  file { "${solr_home}/solr.xml":
    ensure    => 'file',
    owner     => 'jetty',
    group     => 'jetty',
    content   => template('solr/solr.xml.erb'),
    require   => File['/etc/default/jetty'],
  }

  file { "${jetty_home}/webapps/solr":
    ensure    => 'link',
    target    => $solr_home,
    require   => File["${solr_home}/solr.xml"],
  }

  solr::core { $cores:
    require   =>  File["${jetty_home}/webapps/solr"],
  }
}

