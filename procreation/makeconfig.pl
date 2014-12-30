#!/usr/bin/env perl

use warnings;
use strict;

use feature qw/say/;

use IPC::Open2;
use YAML::XS qw/LoadFile/;

my $smc = 0; # Debug flag
BEGIN {
   eval {
      require Smart::Comments;
      Smart::Comments->import();
   };
   $smc = 1
      unless $@;
}


my $config_file = '.makeconfig';
my $make_dir = '.';

sub usage
{
   print "./makeconfig [config_file] [directory]\n";
}

sub usage_die
{
   usage();
   die $_[0];
}

if (@ARGV) {
   if ($ARGV[0]) {
      if (-f $ARGV[0] && -r _) {
         $config_file = $ARGV[0]
      } else {
         usage_die "Can't read '$ARGV[0]'\n"
      }
   } else {
      usage_die "Config file should be provided.\n"
   }
   if ($ARGV[1]) {
      if ( -d $ARGV[1] ) {
         $make_dir = $ARGV[1]
      } else {
         usage_die "Wrong argument '$ARGV[1]'. Directory required.\n"
      }
   }
} else {
   usage_die "At least one argument should be provided.\n"
      unless -r $config_file;
}

### CONFIG FILE: $config_file
### KERNEL MAKEFILE DIRECTORY: $make_dir

my $config = LoadFile($config_file);

unless ($config) {
   die "Configuration file is empty.\n"
}

chdir $make_dir;

my $pid = open2(my $out, my $in, qw/make config/);

while (<$out>) {
   print $in "\n"
}

waitpid($pid, 0);

if ($smc) {
   require Printer;
   Printer->import();
   p $config;
}


