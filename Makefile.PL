use ExtUtils::MakeMaker;

WriteMakefile(
    NAME		=> 'Debug::SIGSEGVTrace',
    VERSION_FROM	=> 'SIGSEGVTrace.pm', # finds $VERSION
    PREREQ_PM		=> {},
    DEFINE		=> '-O0 -g',
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
     (ABSTRACT_FROM => 'SIGSEGVTrace.pm', # retrieve abstract from module
      AUTHOR        => 'Stas Bekman <stas@stason.org>') : ()),
    dist => {
              PREOP        => 'pod2text SIGSEGVTrace.pm > $(DISTVNAME)/README',
              COMPRESS     => 'gzip -9f',
              SUFFIX       => '.gz',
              ZIP          => 'zip',
              ZIPFLAGS     => '-r',
              DIST_DEFAULT => 'tardist',
             },
);
