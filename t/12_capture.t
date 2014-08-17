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

use IPC::Run3::Shell;
use warnings FATAL=>'IPC::Run3::Shell';

my $s = IPC::Run3::Shell->new();

# simple capturing
output_is { $s->perl({stdout=>\undef},'-e','print "foo bar"'); 1 } '', '', "stdout to null";
is $s->perl('-e','print "foo bar"'), 'foo bar', "scalar context";
is_deeply [$s->perl('-e','print "foo\nbar\n"')], ["foo\n","bar\n"], "list context";

# stdin tests
is $s->perl({stdin=>\undef},'-e',';'), '', "stdin 1";
is $s->perl({stdin=>\"quz\nbaz"},'-e',';'), '', "stdin 2";
is $s->perl({stdin=>\undef},'-e','print "foo bar\n"'), "foo bar\n", "stdin 3";
is $s->perl({stdin=>\"quz\nbaz"},'-e','print "foo bar\n"'), "foo bar\n", "stdin 4";
is $s->perl({stdin=>\undef},'-pe',';'), "", "stdin 5";
is $s->perl({stdin=>\"quz\nbaz"},'-pe',';'), "quz\nbaz", "stdin 6";
is $s->perl({stdin=>\undef},'-e','$x=<STDIN>;print $x?"<<".uc($x).">>":"undef"'), "undef", "stdin 7";
is $s->perl({stdin=>\"quz\nbaz"},'-e','$x=<STDIN>;print $x?"<<".uc($x).">>":"undef"'), "<<QUZ\n>>", "stdin 8";

{ # stdout only (should return exit status, stderr should be unaffected)
	my ($x,$o);
	output_is { $x = $s->perl({stdout=>\$o,allow_exit=>[123]},'-e','warn "bar\n"; print "foo\n"; exit 123') } '', "bar\n", "stdout/stderr 1";
	is 123, $x, "exit value check";
	is $?, 123<<8, "exit value check 2";
	is "foo\n", $o, "stdout check";
}

{ # stderr only (scalar context, should return stdout)
	my $e;
	is $s->perl({stderr=>\$e},'-e','warn "bar\n"; print "foo\n"'), "foo\n", "stdout/stderr 2";
	is $?, 0, "exit value check";
	is $e, "bar\n", "stderr check";
}

{ # stderr only (void context, stdout should be unaffected)
	my $e;
	output_is { $s->perl({stderr=>\$e},'-e','warn "bar\n"; print "foo\n"'); 1 } "foo\n", '', "stdout/stderr 3";
	is $?, 0, "exit value check";
	is $e, "bar\n", "stderr check";
}

{ # all three (should return exit status, should capture stdout&err)
	my (@o,$e);
	is $s->perl({stdin=>\"foo\nbar",stdout=>\@o,stderr=>\$e,allow_exit=>[123]},'-pe','warn "quz\n"; END{$?=123}'), 123, "stdout/stderr 4";
	is $?, 123<<8, "exit value check";
	is_deeply \@o, ["foo\n","bar"], "stdout check";
	is $e, "quz\nquz\n", "stderr check";
}

# fail_on_stderr tests
like exception { $s->perl({fail_on_stderr=>1,stderr=>1},'-e','') },
	qr/can't use options stderr and fail_on_stderr at the same time/, "fail_on_stderr failure";
like exception { $s->perl({fail_on_stderr=>1},'-e','print STDERR "bang"') },
	qr/\Qwrote to STDERR: "bang"/, "fail_on_stderr 1";
like exception { $s->perl({fail_on_stderr=>1},'-e','warn "boop"') },
	qr/\Qwrote to STDERR: "boop at -e/, "fail_on_stderr 2";
like exception { $s->perl({fail_on_stderr=>1},'-e','die "blah"') },
	qr/\Qwrote to STDERR: "blah at -e/, "fail_on_stderr 3";
output_is { $s->perl({fail_on_stderr=>1},'-e','print "foo"'); 1
	} 'foo', '', 'fail_on_stderr nofail 1';
output_is { $s->perl({fail_on_stderr=>1},'-e','print STDERR ""'); 1
	} '', '', 'fail_on_stderr nofail 2';
output_is { $s->perl({fail_on_stderr=>1},'-e','print STDERR "\n"'); 1
	} '', '', 'fail_on_stderr nofail 3';
output_is { $s->perl({fail_on_stderr=>1,irs=>'A'},'-e','print STDERR "A"'); 1
	} '', '', 'fail_on_stderr nofail 4';

# redirection tests
output_is { $s->perl({stdout=>\*STDERR},'-MIO::Handle','-e','print STDOUT "ooo\n"; STDOUT->flush; print STDERR "eee\n"'); 1 }
	"", "ooo\neee\n", 'stdout -> stderr';
output_is { $s->perl({stderr=>\*STDOUT},'-MIO::Handle','-e','print STDOUT "ooo\n"; STDOUT->flush; print STDERR "eee\n"'); 1 }
	"ooo\neee\n", "", 'stderr -> stdout';

=for comment
We have disabled this block of tests because instead, we've simply documented
that any creative redirection of filehandles is dependent on the behavior of
IPC::Run3 (which might change in the future).
NOTE: If re-enabling this block, remove the underscore from "TO_DO" below!

# NOTE the following tests show that the way IPC::Run3 (currently!) works is that the stderr redirection
# takes effect first, and after that the stdout redirection takes effect.
# If IPC::Run3 ever changes that, these tests will break (and the TO DO tests below may start passing)
# Maybe we should make the following tests TO DO instead?
{
	my $e;
	output_is { $s->perl({stdout=>\*STDERR,stderr=>\$e},'-MIO::Handle','-e','print STDOUT "ooo\n"; STDOUT->flush; print STDERR "eee\n"'); 1 }
		"", "ooo\n", 'stdout -> stderr w/ capt';
	is $e, "eee\n", 'stderr';
}
{
	my $o;
	output_is { $s->perl({stdout=>\$o,stderr=>\*STDOUT},'-MIO::Handle','-e','print STDOUT "ooo\n"; STDOUT->flush; print STDERR "eee\n"'); 1 }
		"", "", 'stderr -> stdout w/ capt';
	is $o, "ooo\neee\n", 'stdout';
}
# NOTE this test checks the current state of things;
# the TO DO swap test below might be a "nice-to-have" feature?
output_is { $s->perl({stdout=>\*STDERR,stderr=>\*STDOUT},'-MIO::Handle','-e','print STDOUT "ooo\n"; STDOUT->flush; print STDERR "eee\n"'); 1 }
	"", "ooo\neee\n", 'stderr <-> stdout';

# not using output_is here because that doesn't seem to work with the the TO DO block
use Capture::Tiny 'capture';
# check IPC::Run3 first cause that's the source of the issue
use IPC::Run3 'run3';
my ($out0, $err0) = capture { run3(['perl','-e','print STDOUT "ooo\n"; print STDERR "eee\n"'],undef,\*STDERR,\*STDOUT) };
is $?, 0, 'run3 swap exit code';
my ($out1, $err1) = capture { $s->perl({stdout=>\*STDERR,stderr=>\*STDOUT},'-e','print STDOUT "ooo\n"; print STDERR "eee\n"') };
is $?, 0, 'our swap exit code';
TO_DO: { local $TO_DO = "swapping of STDOUT / STDERR not supported (yet??)";
	is $out0, "eee\n", 'run3 swapped stdout';
	is $err0, "ooo\n", 'run3 swapped stderr';
	is $out1, "eee\n", 'our swapped stdout';
	is $err1, "ooo\n", 'our swapped stderr';
}

=cut

done_testing;

