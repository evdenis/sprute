#!/usr/bin/env perl

use strict;
use warnings;
use 5.10.0;
use feature qw(say);

use Getopt::Long qw(:config gnu_getopt);

my $path = '';
my $struct_name = '';
my $strip = 0;
my $rem_macro = 0;
my $extract_ops = 0;

GetOptions(
   'path|p=s' => \$path,
   'name|n=s' => \$struct_name,
   'strip|s!' => \$strip,
   'remove_macro|r!' => \$rem_macro,
   'extract_operations|e!' => \$extract_ops,
) or die "Incorrect usage!\n";

if ( $extract_ops ) {
   $strip = 1;
   $rem_macro = 1;
}

if ( ! -r $path or !$struct_name ) {
   die "Incorrect usage!\n";
}

if ( -d $path ) {
   my $exec_str = 'grep --include="*.h" -lre "struct[[:blank:]]\+' . $struct_name . '[[:blank:]]\+{"' . ' ' . $path;
   my @files = qx($exec_str);

   if ( @files eq 0 ) {
      die "Error: could not find definition\n";
   } elsif ( @files gt 1 ) {
      die "Error: multiple definition\n";
   } else {
      $path = $files[0];
      chomp $path;
   }
}

local $/ = undef;

open my $fh, "<", $path
   or die "could not open $path: $!";
my $file = <$fh>;
close $fh;


while ( $file =~ m/
   (?<sdecl>

   struct
   \s+
      $struct_name
   \s*
   (?>
      (?<sbody>
      \{
         (?:
            (?>[^\{\}]+)
            |
            (?&sbody)
         )*
      \}
      )
   )

   )
   /gmx) {

   my $decl = $+{sdecl} . ";";

   if ( $strip ) {
      #remove comments
      $decl =~ s#/\*[^*]*\*+([^/*][^*]*\*+)*/|//([^\\]|[^\n][\n]?)*?\n|("(\\.|[^"\\])*"|'(\\.|[^'\\])*'|.[^/"'\\]*)#defined $3 ? $3 : ""#gse;
      if ( $rem_macro ) {
         $decl =~ s/
            ^
            [ \t]*
            \#
            [ \t]*
            (?:
               e(?:lse|ndif)
               |
               line
               |
               include
               |
               undef
            )
            .*
            $
         //gmx;
         
         $decl =~ s/
            ^
            [ \t]*
            \#
            [ \t]*
            (?:
               define
               |
               elif
               |
               ifn?(?:def)?
            )
            [ \t]+
            (?<mbody>
               .*(?=\\\n)
               \\\n
               (?&mbody)?
            )?
            .+
            $
         //gmx;

      }
      #remove blank lines
      $decl =~ s/\n^\s*$//mg;

      if ( $rem_macro and $extract_ops ) {
         $decl =~ s/^[\s\n]*struct[\s\n]+\w+[\s\n]*{//;
         $decl =~ s/[\s\n]*}[\s\n]*;[\s\n]*$//;
         my @lines = split /;/, $decl;
         foreach my $line (@lines) {

            $line =~ s/\n//mg;
            $line =~ s/\s\s+/ /g;

            if ( $line =~ m/\(\*(?<fname>\w+)\)\s*(?<fargs>\((?:(?>[^()]+)|(?&fargs))+\))/ ) {
               sub arg_normalize {
                  my $count = () = $_[0] =~ m/$_[1]/g;

                  if ($count > 1) {
                     my $i = 1;
                     $_[0] =~ s/$_[1]/sub { return $_[0].$i++; }->($_[1]);/eg;
                  }
               }

               my $fname = $+{fname};
               my $fargs = $+{fargs};
               $fargs =~ s/^\(//;
               $fargs =~ s/\)$//;
               my @args = split /,/, $fargs;
               my $argline = '(';

               foreach my $arg (@args) {
                  sub arg_filter {
                     $_[0] = $_[1] if $_[0] =~ m/struct\s+$_[1]/;
                  }
                  if (
                     ! arg_filter( $arg, "inode" ) &&
                     ! arg_filter( $arg, "dentry" ) &&
                     ! arg_filter( $arg, "file" ) &&
                     ! arg_filter( $arg, "super" ) 
                  ) {
                     $arg = '';
                  }
                  $argline .= $arg . ', ' if $arg;
               }

               $argline =~ s/, $//;
               $argline .= ')';

               arg_normalize( $argline, "inode" );
               arg_normalize( $argline, "dentry" );
               arg_normalize( $argline, "file" );
               arg_normalize( $argline, "super" );

               say $fname . $argline;
            }
         }
      }
   }

   say $decl if !$extract_ops;
}
