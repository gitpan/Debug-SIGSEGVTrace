package Debug::SIGSEGVFault;

use 5.006;

use strict;
use warnings;

use Debug::SIGSEGVTrace (); # The C/XS code is in that module's .so object

our $VERSION = '0.01';

1;
__END__

=head1 NAME

Debug::SIGSEGVFault - Generate a SegFault

=head1 SYNOPSIS

  use Debug::SIGSEGVFault;
  Debug::SIGSEGVFault::segv();

=head1 DESCRIPTION

This module implements a buggy C function which tries to dereference a
NULL pointer, which generates a segfault. It is used to test the
C<Debug::SIGSEGVTrace> module that attempts to automatically generate
a backtrace when segfault happens without needing the core file.

C<Debug::SIGSEGVFault::segv()> calls another proper C function which
calls a buggy C function, which generates a core-file.

For example this is the trace that generated on my machine:

  #0  0x402b979b in crash_now_for_real (
      suicide_message=0x402ba040 "Cannot stand this life anymore")
      at SIGSEGVTrace.xs:246
  #1  0x402b97bd in crash_now (
      suicide_message=0x402ba040 "Cannot stand this life anymore",
      attempt_num=42) at SIGSEGVTrace.xs:253
  #2  0x402b983e in XS_Debug__SIGSEGVFault_segv (cv=0x81751e4)
      at SIGSEGVTrace.xs:262
  #3  0x400851ec in Perl_pp_entersub ()
     from /usr/lib/perl5/5.6.1/i386-linux/CORE/libperl.so

And the corresponding C code around line 246 is:

 243: crash_now_for_real(char *suicide_message)
 244: {
 245:     int *p = NULL;
 246:     printf("%d", *p); /* cause a segfault */

=head1 EXPORT

None.

=head1 AUTHOR

Stas Bekman E<lt>stas@stason.orgE<gt>

=head1 SEE ALSO

perl(3), C<Debug::SIGSEGVTrace(3)>.

=cut
