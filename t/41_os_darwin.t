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

# This is just a really simple sanity test to see if commands other than "perl" work.

use Test::More ($^O eq 'darwin') ? (tests=>3)
	: (skip_all=>"these tests run on darwin, this is $^O");

use IPC::Run3::Shell;
use warnings FATAL=>'IPC::Run3::Shell';

my $s = IPC::Run3::Shell->new;

my $d = $s->defaults('read','com.apple.Safari');
is $?, 0, 'defaults ran ok';
like $d, qr/\bHomePage\b/, 'found HomePage key';

my @ps = grep {/Dock/} $s->ps(-ax);
is $?, 0, 'ps ran ok';
note "Dock: @ps";

