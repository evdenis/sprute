#!/usr/bin/env perl

use strict;
use warnings;
use 5.10.0;
use feature qw(say);

use File::Slurp qw(read_file);
#use List::MoreUtils qw(uniq);
use Getopt::Long qw(:config gnu_getopt);

#TODO: arg names
#TODO: module dependence

my $path = '';
my $depdb = '';
my $cbdir = '';
my $module = '';

GetOptions(
   'path|p=s' => \$path,
   'depdb|d=s' => \$depdb,
   'cbdir|c=s' => \$cbdir,
   'module|m=s' => \$module,
) or die "Incorrect usage!\n";

die "Path, depdb, cbdir and module should be set.\n" if ( ! ( $path and $module and $depdb and $cbdir ) );
die "${path} - is not a path to kernel sources dir." if (! -f "${path}/Kbuild");
die "Can't read ${depdb}" if (! -r $depdb);
die "There is no such directory ${cbdir}" if (! -d $cbdir);
die "Can't read ${module} in ${cbdir}" if (! -r "${cbdir}/${module}.sprute");

my @modules_files = read_file($depdb, chomp => 1);

my @dbstr = grep(/\/${module}.ko :=/, @modules_files);

die "Wrong format of ${depdb}: number of ${module}.ko occurences $#dbstr." if ( $#dbstr ne 0 );

my @module_files = $dbstr[0] =~ m/\b([[:alnum:]\/\-\_]+\.o)\b/g;
@module_files = map { $path . substr($_, 0, -2) . '.c' } @module_files;

my @operations = grep(!/^\s*$/, read_file("${cbdir}/${module}.sprute", chomp => 1));

my @ungenerated;

sub uniq
{
   my %seen;
   grep { $_ =~ m/=(?<cb>\w+)$/; my $cond = !$seen{$+{cb}?$+{cb}:$_}++; push @ungenerated, $_ if !$cond; $cond } @_;
}

@operations = uniq(@operations);


foreach my $i (@operations) {
   $i =~ m/^(?<st>\w+);(?<op>\w+)=(?<cb>\w+)$/;
   my ($struct, $callback, $function) = ($+{st}, $+{op}, $+{cb});

   if ($struct and $callback and $function) {
      my @query = (
                  'grep',
                  '-Pzlqe',
                  '(?s)\b' . $function . '\s*(?<fargs>\((?:(?>[^\(\)]+)|(?&fargs))+\))\s*(?:(?:(?:__(?:acquires|releases|attribute__)\s*(?<margs>\((?:(?>[^\(\)]+)|(?&margs))+\)))|__attribute_const__|CONSTF|\\\\)\s*)*\{',
                  @module_files
            );

      system( @query );

      if ( $? eq 0 ) {
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
      } else {
         push @ungenerated, $i;
      }
   }
}

say "/*\n * " . join("\n * ", @ungenerated) . "\n */";

