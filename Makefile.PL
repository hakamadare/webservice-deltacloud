use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WebService::Deltacloud',
    AUTHOR              => q{Steve Huff <shuff@cpan.org>},
    VERSION_FROM        => 'lib/WebService/Deltacloud.pm',
    ABSTRACT_FROM       => 'lib/WebService/Deltacloud.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WebService-Deltacloud-*' },
);
