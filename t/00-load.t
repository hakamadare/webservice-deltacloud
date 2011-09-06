#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'WebService::Deltacloud' ) || print "Bail out!
";
}

diag( "Testing WebService::Deltacloud $WebService::Deltacloud::VERSION, Perl $], $^X" );
