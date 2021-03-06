group { "puppet":
	ensure => present,
}

File {
  owner => 'vagrant',
  group => 'vagrant',
  mode  => '0644',
}

file { "/home/vagrant/tmp":
	ensure => directory,
	mode => 0777
}

exec { "apt-get update":
	command => "apt-get update && touch /home/vagrant/tmp/aptgetupdated",
	path => "/usr/bin",
	onlyif => "test ! -e /home/vagrant/tmp/aptgetupdated",
	require => File["/home/vagrant/tmp"]
}

class puppet {
	package { 'puppet':
		ensure => latest
	}
}

class htop {
	package { "htop":
		ensure => present,
		require => Exec["apt-get update"]
	}
}

class remove_apache {
	#upstart not found workaround
	file { '/etc/init.d/apache2':
 		ensure => link,
    	target => '/lib/init/upstart-job',
    	replace => 'no',
    	owner => 'root',
    	group => 'root',
    	mode => 0755,
    }
	service { 'apache2':
		ensure => stopped,
		enable => false,
		subscribe => File['/etc/init.d/apache2']
	}
	package { 'apache2':
	    ensure => absent
	}
	exec { 'autoremove':
	    command => '/usr/bin/apt-get autoremove --purge -y',
	    subscribe => Package['apache2'],
	    refreshonly => true
	}	
}


class php {
	package { ["php5", "php5-fpm", "php5-cli", "php5-mysql", "php5-memcache", "php5-xdebug", "php5-mcrypt"]:
		ensure => present,
		require => Exec["apt-get update"]
	}	
	service { "php5-fpm":
		ensure => running,
		require => Package["php5-fpm"]
	}
	file { "/etc/php5/fpm/pool.d/www.conf":
		ensure => file,
		source => "/vagrant/myserverconfigs/php5-fpm/www.conf",
		require => Package["php5-fpm"],
		notify => Service["php5-fpm"]
	}
	file { "/etc/php5/fpm/php.ini":
		ensure => file,
		source => "/vagrant/myserverconfigs/php5-fpm/php.ini",
		require => Package["php5-fpm"],
		notify => Service["php5-fpm"]
	}
}

class nginx {
	package { "nginx":
		ensure => present,
		require => Exec["apt-get update"]
	}
	file { "/etc/nginx/sites-available/vagranttest-nginx.conf":
		ensure => file,
		source => "/vagrant/myserverconfigs/nginx/sites-available/vagranttest-nginx.conf",
		require => Package["nginx"],
		notify => Service["nginx"],
	}
	file { "/etc/nginx/sites-enabled/vagranttest-nginx.conf":
		ensure => link,
		target => "/etc/nginx/sites-available/vagranttest-nginx.conf",
		require => File["/etc/nginx/sites-available/vagranttest-nginx.conf"],
		notify => Service["nginx"]
	}	
	service { "nginx":
		ensure => "running",
		require => Package["nginx"]
	}
}

class mysql {
	package { ["mysql-server"]:
		ensure => present,
		require => Exec["apt-get update"]
	}
	service { "mysql":
		ensure => running,
		require => Package["mysql-server"]
	}
	file { "/etc/mysql/conf.d/myinnodbsettings.cnf":
		ensure => file,
		path => "/etc/mysql/conf.d/myinnodbsettings.cnf",
		source => "/vagrant/myserverconfigs/mysql/myinnodbsettings.cnf",
		require => Package["mysql-server"],
		notify => Service["mysql"]
	}
	exec { "set-mysql-password":
		unless => 'mysqladmin -uroot -proot status',
		command => 'mysqladmin -uroot password root',
		path => ['/bin', '/usr/bin'],
		require => Service['mysql']
	}
	exec { "create-sql-structure-data":
		command => "/vagrant/myserverconfigs/shellscripts/importsql.sh",
		path => ["/bin", "/usr/bin"],
		require => [Exec["set-mysql-password"], File['/home/vagrant/tmp']],
		onlyif => "test ! -e /home/vagrant/tmp/sqlexecuted",
	}	
}

class phpmyadmin {
	package { "phpmyadmin":
		ensure => present,
		require => [Package["php5"], Package["mysql-server"]]
	}
	file { "/usr/share/phpmyadmin/config.inc.php":
		ensure => file,
		source => "/vagrant/myserverconfigs/phpmyadmin/config.inc.php",
		require => Package["phpmyadmin"]
	}	
}

class rsync {

	$synctovagrant = "/vagrant/myserverconfigs/shellscripts/rsync.sh"
	$synctohost = "/vagrant/myserverconfigs/shellscripts/rsync-2host.sh &"

	package { "rsync":
		ensure => present
	}

	exec { "rsync-project-dirs":
		command => $synctovagrant,
		path => ["/bin", "/usr/bin"],
		require => Package["rsync"],
	}

	exec { "rsync-project-dirs-2host":
		command => $synctohost,
		path => ["/bin", "/usr/bin"],
		require => [Package["rsync"], Exec["rsync-project-dirs"]],
		user => 'vagrant'
	}	
}

include php
include mysql
include phpmyadmin
include htop
include remove_apache
include nginx
include rsync