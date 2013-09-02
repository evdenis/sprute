#!/usr/bin/env perl

use strict;
use warnings;
use 5.10.0;
use feature qw(say);

use File::Slurp qw(read_file);

#TODO: module name
#TODO: arg names
#TODO: duplicating functions
#TODO: out of the module functions
#TODO: module dependence

my $module = "fat";

foreach my $i (<>) {
   $i =~ m/^(?<st>\w+);(?<op>\w+)=(?<cb>\w+)$/;
   my ($struct, $callback, $function) = ($+{st}, $+{op}, $+{cb});

   if ($struct and $callback and $function) {
      if ( $function !~ m/^generic_/ ) {
         #FIXME: remove hardcoded path
         my $libfile = "/home/work/workspace/sprute/staplib/vfslib_${struct}.stpm"; 
         my $operation = "ops_${struct}_${callback}";

         my $lib = read_file($libfile);
         $lib =~ m/${operation}\s*\((?<args>[^)]+)\)/m;
         die("Can't find arguments.") if not $+{args};
         my @args = split(/,/, $+{args});

         say "probe module( \"${module}\" ).function( \"${function}\" ) {";
         say "\t\@ops_${struct}_${callback}( " . join(', ', map { $_ =~ s/\s//g; '$' . $_; }  @args) . " )";
         say "}\n";
      }
   }
}
