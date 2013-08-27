#!/usr/bin/env perl

use strict;
use warnings;
use 5.10.0;
use feature qw(say);

use File::Basename;
use File::Slurp qw(read_file);
#use List::MoreUtils qw(uniq);

my $path = $ARGV[0];

if ( ! defined($path) || ! -r $path ) {
   die "Incorrect usage!\n";
}

my $defn_file = $path;
my @defn_files; 

if ( -d $path ) {
	my $defn_query = "grep --include=Makefile -rle 'obj-\$([[:alnum:]_]\\+)[[:space:]]*+\\?=[[:space:]]*'" . ' ' . $path;
   @defn_files = qx($defn_query);

   if ( @defn_files eq 0 ) {
      die "Error: could not find Makefiles\n";
   } else {
		chomp @defn_files;
   }
} else {
	push @defn_files, $path;
}


for my $file (@defn_files) {
	my $data = read_file($file);
	while ( $data =~ m/
								obj-\$\(\w+\)
								\s*
								[:+]?=
								\s*
								(?<modules>
									(?<body>
										[^\\\n]*
										\\\n
										(?&body)?
									)?
								.+
								)
								$
							/gmx ) {
		my @modules = $+{modules} =~ m/[\w_-]+(?=\.o)/g;
		for my $module (@modules) {
			my @deps;

         my $saved_pos = pos($data);

			say $file . ' ' . $module;
			push @deps, $+{deps} while ( $data =~ m/
																	${module}-y
																	\s*
																	[:+]?=
																	\s*
																	(?<deps>
																		(?<body>
																			[^\\\n]*
																			\\\n
																			(?&body)?
																		)?
																	.+
																	)
																	$
																/gmx );
			#push @deps, $+{deps} while ( $data =~ m/${module}-objs\s*[:+]?=\s*(?<deps>(?<body>[^\\\n]*\\\n(?&body)?)?.+)$/g );
			say @deps;
			#while ( $data =~ m/${module}-objs\s*[:+]?=\s*(?<deps>(?<body>[^\\\n]*\\\n(?&body)?)?.+)$/g ) {
				#push @deps, $+{deps};
				#say $+{deps};
			#}
			#my $deps = $+{deps};
			#say @deps;
			#if (defined $deps) {
			#	say $module . ' := ' . $deps;
			#}
         pos($data) = $saved_pos;
		}
	}
}

