#!/usr/bin/env perl

use strict;
use warnings;
use 5.10.0;
use feature qw(say);

use File::Slurp qw(read_file);
#use List::MoreUtils qw(uniq);
use Getopt::Long qw(:config gnu_getopt);

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
die "${path} - is not a path to kernel sources dir.\n" if (! -f "${path}/Kbuild");
die "Can't read ${depdb}\n" if (! -r $depdb);
die "There is no such directory ${cbdir}\n" if (! -d $cbdir);
die "Can't read ${module} in ${cbdir}\n" if (! -r "${cbdir}/${module}.sprute");

my @modules_files = read_file($depdb, chomp => 1);

my @dbstr = grep(/\/${module}.ko :=/, @modules_files);

die "Wrong format of ${depdb}: number of ${module}.ko occurences $#dbstr.\n" if ( $#dbstr ne 0 );

sub check_arg_name
{
   my $argline = $_[0];

   $argline =~ s/\b__user\b//g;
   $argline =~ s/^\s*//;
   $argline =~ s/\s*$//;

   $argline =~ s/(\b((static)|(inline)|(extern)|(const)|(volatile)|(enum)|(struct)|(union))\s+)*//g;
   $argline =~ s/\*//g;
   $argline =~ s/long\s+(?=long)//;
   $argline =~ s/unsigned\s+(?=((long)|(int)|(char)|(short)))//;
   $argline =~ m/\w+\s+(?<arg_name>\w+)/;
   return $+{arg_name};
}


my @module_files = $dbstr[0] =~ m/\b([[:alnum:]\/\-\_]+\.o)\b/g;
@module_files = map { $path . substr($_, 0, -2) . '.c' } @module_files;

my @operations = grep(!/^\s*$/, read_file("${cbdir}/${module}.sprute", chomp => 1));

my @ungenerated;

sub uniq
{
   my %seen;
   grep { $_ =~ m/=(?<cb>\w+)$/; my $cond = !$seen{$+{cb}?$+{cb}:$_}++; push @ungenerated, $_ if !$cond; $cond } @_;
}

@operations = uniq( sort { my $str1 = $a; my $str2 = $b; $a =~ m/=(?<cb1>\w+)$/; $str1 = $+{cb1} if defined $+{cb1}; $b =~ m/=(?<cb2>\w+)$/; $str2 = $+{cb2} if defined $+{cb2}; $str1 cmp $str2 } @operations );

say "global mode=\"release\"\n";

foreach my $i (@operations) {
   $i =~ m/^(?<st>\w+);(?<op>\w+)=(?<cb>\w+)$/;
   my ($struct, $callback, $function) = ($+{st}, $+{op}, $+{cb});

   if ($struct and $callback and $function) {
      my @query = (
                  'grep',
                  '-PzHoe',
                  q!'(?m)\b! . $function . q!\s*\K(?<fargs>\((?:(?>[^\(\)]+)|(?&fargs))+\))(?=\s*(?:(?:(?:__(?:acquires|releases|attribute__)\s*(?<margs>\((?:(?>[^\(\)]+)|(?&margs))+\)))|__attribute_const__|CONSTF|\\\\)\s*)*\{)'!,
                  @module_files
            );
      my $str_query = join(' ', @query);
      my $output = qx($str_query);

      if ( $? eq 0 ) {
         my $count =()= $output =~ m/\.c:\(/g;
         if ($count ne 1) {
            print STDERR "There is more than definition of function ${function}\n";
            print STDERR "${output}";
            print STDERR "This function will not be included in stp file.\n";
            push @ungenerated, $i;
            next;
         }
         $output =~ s/\n//g;
         $output =~ s/\s+/ /g;
         $output =~ s/\)\s*$//;
         $output =~ s/^.+?\.c:\(//;

         my @arguments = split(/,/, $output);
         map { s/^\s+//; s/\s+$//; } @arguments;

         #filter
         #@arguments = grep { m/\bstruct\s+((inode)|(dentry)|(file)|(super))/ } @arguments;

         map { my $name = check_arg_name $_; if ($name) { $_ = $name } else { die "Can't find arg name in string: '$_'" } } @arguments;

         say "probe module( \"${module}\" ).function( \"${function}\" ) {";
         say "\tif ( mode == \"debug\" ) {";
         say "\t\tprintln( \"${function}\" )";
         say "\t} else {";
         say "\t\tif ( mode == \"s2e_debug\" ) {";
         say "\t\t\ts2e_message( \"${function}\" )";
         say "\t\t} else {";
         say "\t\t\t\@ops_${struct}_${callback}( " . join(', ', map { $_ =~ s/\s//g; '$' . $_; }  @arguments) . " )";
         say "\t\t}";
         say "\t}";
         say "}\n";
      } else {
         push @ungenerated, $i;
      }
   }
}

my $end = <<'PROBE';

probe end {
   s2e_kill_state(0, "Branch finished\n")
}

PROBE

print $end;

say "/*\n * " . join("\n * ", @ungenerated) . "\n */";

