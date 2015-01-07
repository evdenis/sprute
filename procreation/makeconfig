#!/usr/bin/env perl

use warnings;
use strict;

use List::Util qw/any/;
use IO::Handle;
use IO::Select;
require 'sys/ioctl.ph';

BEGIN {
   eval {
      require Smart::Comments;
      Smart::Comments->import();
   };
}


my $config_file = '.makeconfig';
my $make_dir = '.';

sub usage
{
   print "./makeconfig [config file] [kernel directory]\n";
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
         my $res = 0;
         opendir my $kdir, $ARGV[1] or goto OUT;
            my @files = readdir $kdir;
         closedir $kdir;

         #Check for standard files
         foreach my $kf (qw(Kbuild Kconfig MAINTAINERS Makefile drivers include arch kernel security)) {
            goto OUT
               unless any { $_ eq $kf } @files;
         }

         $res = 1;
OUT:
         if ($res) {
            $make_dir = $ARGV[1]
         } else {
            usage_die "'$ARGV[1]' is not a kernel directory.\n"
         }

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


my %config;
{
   open my $f, '<', $config_file
      or die "Can't open $config_file.\n";

   while(<$f>) {
      chomp;
      s/#.*+//;
      if (m/\A\h*+\Z/) {
         next;
      }
      if (m/\A\h*+(\w++)\h++(yes|mod|no)\h*+\Z/) {
         $config{$1} = $2
      } else {
         warn "Error in line '$_'. Ignoring.\n"
      }
   }
}

unless (%config) {
   die "Configuration file is empty.\n"
}

chdir $make_dir;

my ($parent_read, $parent_write);
my ($child_read,  $child_write);

pipe($parent_read, $child_write) and
pipe($child_read,  $parent_write) or
   die "Failed to setup pipe: $!";
$parent_write->autoflush(1);
$child_write->autoflush(1);
#autoflush STDOUT 1;
$child_read->blocking(1);
$parent_read->blocking(1);


if (my $pid = fork()) {
   close $parent_read; close $parent_write;

   my %answers = (
      yes => 'y',
      no  => 'n',
      mod => 'm',
      y   => 'y',
      n   => 'n',
      m   => 'm',
      module => 'm'
   );


   my $s = IO::Select->new();
   $s->add($child_read);
   my $fd;
   my $lastline = '';

   while (1) {
      $fd = undef;
      ($fd) = $s->can_read(1);
      if ($fd) {
         my $size = pack("L", 0);
         $child_read->ioctl(FIONREAD(), $size);
         $size = unpack("L", $size);

         last unless $size;

         $child_read->read(my $c, $size);
         #print "$c";
         $lastline .= $c;
         if ($lastline =~ m/\[[^]]*+\]:?\h*+(\(NEW\)\h*+)?\Z/) {
            my $ok = 0;
            foreach my $k (keys %config) {
               if (rindex($lastline, $k) != -1) {
                  print $child_write "$answers{$config{$k}}\n";
                  print "SWITCH: $k $config{$k}\n";
                  delete $config{$k};
                  $ok = 1;
                  last
               }
            }

            print $child_write "\n"
               unless $ok;
            $lastline = '';
         }
      }
   }

   waitpid($pid, 0);

   foreach (keys %config) {
      print STDERR "UNDEF: $_\n"
   }

} else {
   close $child_read; close $child_write;

   open STDOUT, '>&', $parent_write;
   open STDIN,  '<&', $parent_read;
   exec qw/make config/;
}

