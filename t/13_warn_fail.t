#!/usr/bin/env perl
use warnings;
use strict;

# Tests for the Perl module IPC::Run3::Shell
# 
# Copyright (c) 2014 Hauke Daempfling (haukex@zero-g.net).
# 
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl 5 itself.
# 
# For more information see the "Perl Artistic License",
# which should have been distributed with your copy of Perl.
# Try the command "perldoc perlartistic" or see
# http://perldoc.perl.org/perlartistic.html .

use FindBin ();
use lib $FindBin::Bin;
use IPC_Run3_Shell_Testlib;

use Test::More;
use Test::Fatal 'exception';

use IPC::Run3::Shell ':run', [ perl1 => 'perl', '-e', 'print "foo @ARGV"' ];
use warnings FATAL=>'IPC::Run3::Shell';

my $s = IPC::Run3::Shell->new();

# test some simple error cases
like exception { run(); 1 },
	qr/empty command/, "error checking 1";
like exception { perl1('x',undef,'',0,'0E0',undef,'z'); 1 },
	qr/undefined values?/, "undefs";
like exception { run('perl','-e',[1,2]); 1 },
	qr/contains?.+references/, "error checking 2";
like exception { run('perl','-e',{a=>2},'--'); 1 },
	qr/contains?.+references/, "error checking 3";
like exception { run('perl','-e',sub {}); 1 },
	qr/contains?.+references/, "error checking 4";
like exception { run('perl','-e',IPC::Run3::Shell->new()); 1 },
	qr/contains?.+references/, "error checking 5";
like exception { IPC::Run3::Shell->import({},'perl',{}); 1 },
	qr/contains?.+references/, "import error checking 1";
like exception { IPC::Run3::Shell->import({},'perl',undef); 1 },
	qr/contains?.+undefined/, "import error checking 2";
like exception { IPC::Run3::Shell->import(':BAD_SYMBOL'); 1 },
	qr/can't export "BAD_SYMBOL"/, "import error checking 3";
like exception { IPC::Run3::Shell->import([]); 1 },
	qr/no function name/, "import error checking 4";
like exception { IPC::Run3::Shell->import(['']); 1 },
	qr/no function name/, "import error checking 5";
like exception { IPC::Run3::Shell->import(['x']); 1 },
	qr/empty command/, "import error checking 6";
like exception { IPC::Run3::Shell->make_cmd(); 1 },
	qr/called as a method/, "make_cmd as a method";
# this one checks some logic for the OO interface
like exception {
		IPC::Run3::Shell::make_cmd()->(bless {}, 'IPC_Run3_Shell_Testlib::FooBar'); 1
	}, qr/contains?.+references/, "blessed ref as first arg";

# failure tests
like exception { $s->perl('-e','exit 1'); 1 },
	qr/exit (status|value) 1\b/, "fail 1";
diag "in the following test, errors referring to \"this_command_shouldnt_exist\" can be safely ignored as long as the test passes";
like exception { $s->this_command_shouldnt_exist; 1 },
	qr/\QCommand "this_command_shouldnt_exist" failed/, "fail 2";
like exception { $s->perl('-e','exit 123'); 1 },
	qr/exit (status|value) 123\b/, "fail 3";
like exception { is $s->perl({_BAD_OPT=>1},'-e','print "foo"'), "foo", "unknown opt 1A" },
	qr/\Qunknown option "_BAD_OPT"/, "unknown opt 1B";
# NOTE that in Windows, apparently the following test causes perl to exit with "exit status 9"
# instead of recognizing that it was killed by a signal.
like exception { $s->perl('-e','kill 9, $$'); 1 },
	( $^O eq 'MSWin32' ? qr/exit status 9\b/ : qr/signal 9, without coredump|\Qsignal "KILL" (9)\E/ ), "fail 4";

{ # warning tests
	use warnings FATAL=>'all', NONFATAL=>'IPC::Run3::Shell';
	ok exception { my $x = 0 + undef; }, 'double-check warning fatality 1';
	my @w1 = warns {
			is $s->perl('-e','print "foo"; exit 1'), "foo", "warning test 1A"; is $?, 1<<8, "warning test 1B";
			ok !$s->this_command_shouldnt_exist(), "warning test 2A"; is $?, $^O eq 'MSWin32' ? 0xFF00 : -1, "warning test 2B";
			is $s->perl({stdout=>\my $x},'-e','print "foo"; exit 123'), 123, "warning test 3A"; is $?, 123<<8, "warning test 3B";
			is $x, "foo", "warning test 3C";
			is $s->perl('-e','kill 9, $$'), '', "warning test 4A"; is $?, $^O eq 'MSWin32' ? 9<<8 : 9, "warning test 4B";
		};
	is @w1, 4, "warning test count";
	like $w1[0], qr/exit (status|value) 1\b/, "warning test 1C";
	like $w1[1], qr/\QCommand "this_command_shouldnt_exist" failed/, "warning test 2C";
	like $w1[2], qr/exit (status|value) 123\b/, "warning test 3D";
	like $w1[3], ( $^O eq 'MSWin32' ? qr/exit status 9\b/ : qr/signal 9, without coredump|\Qsignal "KILL" (9)\E/ ), "warning test 4C";
	# make sure fail_on_stderr is still fatal
	like exception { $s->perl({fail_on_stderr=>1},'-e','print STDERR "bang"') },
		qr/\Qwrote to STDERR: "bang"/, "fail_on_stderr with nonfatal warnings";
	# we test for exceptions in several places, here we check that those are actually just fatal warnings
	my @w3 = warns {
			is $s->perl({allow_exit=>'A'},'-e','print "foo"'), "foo", "allow_exit warn 1A";
			is $s->perl('-e','print ">>@ARGV<<"','--','x',undef,0,undef,'y'), ">>x  0  y<<", "undef/ref warn 1A";
			like $s->perl('-e','print ">>@ARGV<<"','--','x',[1,2],'y'), qr/^>>x ARRAY\(0x[0-9a-fA-F]+\) y<<$/, "undef/ref warn 1B";
			is $s->perl({_BAD_OPT=>1},'-e','print "foo"'), "foo", "unknown opt 2A";
		};
	is @w3, 4, "warn count";
	like $w3[0], qr/allow_exit.+isn't numeric/, "allow_exit warn 1C";
	like $w3[1], qr/undefined values?/, "undef/ref warn 1D";
	like $w3[2], qr/contains?.+references/, "undef/ref warn 1E";
	like $w3[3], qr/\Qunknown option "_BAD_OPT"/, "unknown opt 2B";
}

{ # disable warnings
	use warnings FATAL=>'all';
	no warnings 'IPC::Run3::Shell';  ## no critic (ProhibitNoWarnings)
	ok exception { my $x = 0 + undef; }, 'double-check warning fatality 2';
	is warns {
			# note these are just copied from the "warnings tests" above
			is $s->perl('-e','print "foo"; exit 1'), "foo", "no warn 1A"; is $?, 1<<8, "no warn 1B";
			ok !$s->this_command_shouldnt_exist(), "no warn 2A"; is $?, $^O eq 'MSWin32' ? 0xFF00 : -1, "no warn 2B";
			is $s->perl({stdout=>\my $x},'-e','print "foo"; exit 123'), 123, "no warn 3A"; is $?, 123<<8, "no warn 3B";
			is $x, "foo", "no warn 3C";
			is $s->perl('-e','kill 9, $$'), '', "no warn 4A"; is $?, $^O eq 'MSWin32' ? 9<<8 : 9, "no warn 4B";
			
			is $s->perl({allow_exit=>'A'},'-e','print "foo"'), "foo", "no warn 5";
			is $s->perl('-e','print ">>@ARGV<<"','--','x',undef,0,undef,'y'), ">>x  0  y<<", "no warn 6";
			like $s->perl('-e','print ">>@ARGV<<"','--','x',[1,2],'y'), qr/^>>x ARRAY\(0x[0-9a-fA-F]+\) y<<$/, "no warn 7";
			is $s->perl({_BAD_OPT=>1},'-e','print "foo"'), "foo", "unknown opt 3";
		}, 0, "no warnings";
	# make sure fail_on_stderr is still fatal
	like exception { $s->perl({fail_on_stderr=>1},'-e','print STDERR "bang"') },
		qr/\Qwrote to STDERR: "bang"/, "fail_on_stderr without warnings";
}

# only IPC::Run3::Shell warnings enabled
is warns {
		no warnings;  ## no critic (ProhibitNoWarnings)
		use warnings FATAL=>'IPC::Run3::Shell';
		is 5 + undef, 5, "check warnings disabled";
		like exception { $s->perl('-e','exit 123'); 1 }, qr/exit (status|value) 123\b/, "module warn only";
	}, 0, "module warnings only";


done_testing;

