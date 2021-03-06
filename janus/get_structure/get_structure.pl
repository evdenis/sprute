#!/usr/bin/env perl

use strict;
use warnings;
use 5.10.0;
use feature qw(say);

use File::Basename;
use File::Slurp qw(read_file);
use List::MoreUtils qw(uniq);
use Getopt::Long qw(:config gnu_getopt);

my $path        = '';
my $struct_name = '';
my $strip       = 0;
my $rem_macro   = 0;
my $extract_ops = 0;
my $mark_fields = 0;

GetOptions(
   'path|p=s'              => \$path,
   'name|n=s'              => \$struct_name,
   'strip|s!'              => \$strip,
   'remove_macro|r!'       => \$rem_macro,
   'extract_operations|e!' => \$extract_ops,
   'mark_fields|m!'        => \$mark_fields,
) or die "Incorrect usage!\n";

#TODO: we should use simple ifdef/endif macro with mark_fields
if ( $extract_ops or $mark_fields ) {
   $strip = 1;
   $rem_macro = 1;
}

if ( ! -r $path or !$struct_name or ( $extract_ops and $mark_fields ) ) {
   die "Incorrect usage!\n";
}

my $defn_file = $path;
my @decl_files;
my $decl_query = 'grep --include="*.c" -lre "struct[[:blank:]]\+' . $struct_name . '[[:blank:]]\+[[:alnum:]_]\+[[:blank:]]*=" ';

if ( -d $path ) {
   my $defn_query = 'grep --include="*.h" -lre "struct[[:blank:]]\+' . $struct_name . '[[:blank:]]*{"' . ' ' . $path;
   my @defn_files = qx($defn_query);

   if ( @defn_files eq 0 ) {
      die "Error: could not find definition\n";
   } elsif ( @defn_files gt 1 ) {
      die "Error: multiple definition\n";
   } else {
      $defn_file = $defn_files[0];
      chomp $defn_file;
   }
} else {
   $path = dirname($path);
}

$path =~ s/include.*$//;
$decl_query .= $path;
@decl_files = qx($decl_query);

my $file = read_file($defn_file);

sub preffered_names
{
   my @ret;
   foreach my $i ($_[0]) {
      push(@ret, $i) if $i =~ m/(addr|buf(fer)?|cmd|fd|flags?|fpos|iocb|iocmd|ioctl|len(gth)?|offset|page|pos|ppos|size|start)/;
   }
   return @ret;
}

sub find_arg_name
{
   my ($file_name, $struct_name, $line, $field_name, $arg_num) = @_;
   my $file = read_file($file_name);

   while ( $file =~ m/
      (?<sdefn>
         struct
         \s+
            $struct_name
         \s+
         \w+ #struct name
         \s*
         =
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
      my $sinit = $+{sbody};

      $sinit =~ m/\.$field_name\s*=\s*(?<fn_name>\w+),?/m;
      my $init_func_name = $+{fn_name};

      if ( $init_func_name ) {
         my $ret_val = substr($line, 0, index($line, '('));

         $ret_val =~ s/^\s*//g;
         $ret_val =~ s/\s*$//g;
         $ret_val .= $ret_val =~ m/\*$/ ? '\s*' : '\s+';

         $ret_val =~ s/\s+/ /g;
         $ret_val =~ s/(?<!\*) (?=\w)/\\s+/g;
         $ret_val =~ s/ \*/\\s*\\*/g;
         $ret_val =~ s/\*\*/\\*\\s*\\*/g;
         $ret_val =~ s/\* /\\*\\s*/g;

         my $saved_pos = pos($file);
         pos($file) = 0;

         while ( $file =~ m/
               $ret_val
               $init_func_name
               \s*                  # spaces between name and arguments
               (?<fargs>
                  \(
                   (?:
                      (?>[^\(\)]+)
                      |
                      (?&fargs)
                   )+
                  \)
               )
               \s*                  # spaces between arguments and function body
               (?:
                  (?:
                     (?:__(?:acquires|releases|attribute__)\s*(?<margs>\((?:(?>[^\(\)]+)|(?&margs))+\)))
                     |
                     __attribute_const__
                     |
                     CONSTF
                     |
                     \\
                  )\s*
               )*
               (?>
                  (?<fbody>                    # function body group
                     \{                # begin of function body
                     (?:               # recursive pattern
                        (?>[^\{\}]+)
                        |
                        (?&fbody)
                     )*
                     \}                # end of function body
                  )
               )
            /gmx ) {
            my $fargs = $+{fargs};
            $fargs =~ s/\b__(user|maybe_unused)\b//g;
            $fargs =~ s/^\(\s*//;
            $fargs =~ s/\s*\)$//;
            my @args = split /,/, $fargs;

            $args[$arg_num] =~ m/(?<arg_name>\w+)\s*$/;
            return $+{arg_name};
         }

         pos($file) = $saved_pos;
      }
   }

   return;
}

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

sub check_arg_type
{
   my $argline = $_[0];
   my $argname = $_[1];

   if (!defined($argname)) {
      return;
   }

   $argline =~ s/\b__user\b//g;
   $argline =~ s/\{|\}//g;

   $argline =~ s/(\b((static)|(inline)|(extern)|(const)|(volatile)|(union))\s+)*//g;
   $argline =~ s/\b${argname}\b//;
   $argline =~ s/\s+/ /g;
   $argline =~ s/^\s*//;
   $argline =~ s/\s*$//;

   return $argline;
}

sub simple_type
{
   my $type = $_[0];
   defined($type) && $type !~ m/(\b(struct)|(union)|(spinlock_t)\b)|\*/;
}

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
         $struct_name =~ m/^(?<st_name>\w+)_operations$/;
         my $ops_struct_name = $struct_name;
         $ops_struct_name = $+{st_name} if $+{st_name};
         $decl =~ s/^[\s\n]*struct[\s\n]+\w+[\s\n]*{//;
         $decl =~ s/[\s\n]*}[\s\n]*;[\s\n]*$//;
         my @lines = split /;/, $decl;
         foreach my $line (@lines) {

            $line =~ s/\n//mg;
            $line =~ s/\s+/ /g;

            if ( $line =~ m/\(\*(?<fname>\w+)\)\s*(?<fargs>\((?:(?>[^()]+)|(?&fargs))+\))/ ) {
               sub arg_normalize {
                  my $count = () = $_[0] =~ m/\b$_[1]\b/g;

                  if ($count > 1) {
                     my $i = 1;
                     $_[0] =~ s/\b$_[1]\b/sub { return $_[0].$i++; }->($_[1]);/eg;
                  }
               }

               my $fname = $+{fname};
               my $fargs = $+{fargs};
               $fargs =~ s/^\(//;
               $fargs =~ s/\)$//;
               my @args = split /,/, $fargs;
               my $argline = '(';

               foreach my $i (0 .. $#args) {
                  sub arg_filter {
                     $_[0] = $_[1] if $_[0] =~ m/\bstruct\s+$_[1]/;
                  }
                  if ($args[$i] eq 'void') {
                     $args[$i] = '';
                  } else {
                     if (
                        ! arg_filter( $args[$i], "inode" ) &&
                        ! arg_filter( $args[$i], "dentry" ) &&
                        ! arg_filter( $args[$i], "file" ) &&
                        ! arg_filter( $args[$i], "super" )
                     ) {
                        my $arg_name = check_arg_name($args[$i]);
                        if (!$arg_name) {
                           my @arg_names;
                           foreach my $j (0 .. $#decl_files) {
                              chomp $decl_files[$j];
                              $arg_name = find_arg_name($decl_files[$j], $struct_name, $line, $fname, $i);
                              if ($arg_name) {
                                 push(@arg_names, $arg_name);
                                 last if (length($arg_name) >= 3 && $j == 0);
                              }
                           }
                           @arg_names = uniq(@arg_names);
                           @arg_names = grep { $_ !~ m/((inode)|(dentry)|(file)|(super))/ } @arg_names;
                           @arg_names = reverse sort {length $a <=> length $b} @arg_names;
                           if (scalar(@arg_names) == 0)
                           {
                              warn "Not able to find argument name for:\n";
                              warn "structure: $struct_name\n";
                              warn "operation: $line\n";
                              warn "argument:  $i\n";
                              warn "Assigning default name: 'var'\n";
                              push(@arg_names, 'var');
                           }
                           #my @pr_arg_names = preffered_names(@arg_names);
                           #warn join(' ', @arg_names);
                           $arg_name = $arg_names[0];
                           #$arg_name = $arg_names[int($#arg_names/2)];
                           #$arg_name = $pr_arg_names[0] ? $pr_arg_names[0] : $arg_names[0];
                           #$arg_name = $pr_arg_names[0] ? $pr_arg_names[0] : $arg_names[int($#arg_names/2)];
                        }
                        $args[$i] = $arg_name;
                     }
                  }
               }

               #normalization
               foreach my $i (0..$#args) {
                  my $index = 1;
                  foreach my $arg (@args[$i+1 .. $#args]) {
                     if ($arg and $args[$i] eq $arg) {
                        $args[$i] .= '1' if $args[$i] =~ m/\w+/;
                        $arg .= ++$index;
                     }
                  }
               }

               #filter
               #@args = grep { m/(file)|(inode)|(dentry)|(super)/ } @args;
               
               if (@args) {
                  say "\@define ops_${ops_struct_name}_${fname}( " . join(', ', @args) . " )\n%(";
                  foreach my $arg (@args) {
                     given ( $arg ) {
                        when ( /^file/ )   { say "\t\@make_file_concolic( \@${arg} )" }
                        when ( /^inode/ )  { say "\t\@make_inode_concolic( \@${arg} )" }
                        when ( /^dentry/ ) { say "\t\@make_dentry_concolic( \@${arg} )" }
                        when ( /^super/ )  { say "\t\@make_super_concolic( \@${arg} )" }
                     }
                  }
                  say "%)\n";
               }
            }
         }
      } elsif ( $mark_fields ) {
         $struct_name =~ m/^(?<st_name>\w+)_block$/;
         my $sc_struct_name = $struct_name;
         $sc_struct_name = $+{st_name} if $+{st_name};

         $decl =~ s/^[\s\n]*struct[\s\n]+\w+[\s\n]*{//;
         $decl =~ s/[\s\n]*}[\s\n]*;[\s\n]*$//;
         # first we should filter only simple fields. There should be no nested unions and stuff like that.
         my @lines = split /;/, $decl;
         say "\@define make_${sc_struct_name}_concolic( ${sc_struct_name} )\n%(";
         say "\tdesc = sprintf(\"${sc_struct_name} addr: %p\", \@${sc_struct_name} )\n";

         my $flag = 0;
         foreach my $line (@lines) {
            my $arg_name = check_arg_name($line);
            my $arg_type = check_arg_type($line, $arg_name);
            $line =~ s/\s+/ /g;
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;
            $line =~ s/\n//g;
            $line .= ';';
            #say "NAME:\t" . $arg_name . "\nTYPE:\t" . $arg_type if defined $arg_name;
            if ( simple_type($arg_type) ) {
               print "\n" if $flag;
               say "\t//" . $line;
               say "\ts2e_make_concolic( &\@${sc_struct_name}->${arg_name}, %{ sizeof( ${arg_type} ) %}, desc . \" ${arg_name}\" )\n";
               $flag = 0;
            } else {
               say "\t//" . $line;
               $flag = 1;
            }
         }
         say "%)"
      }
   }

   say $decl if !( $extract_ops or $mark_fields );
}
