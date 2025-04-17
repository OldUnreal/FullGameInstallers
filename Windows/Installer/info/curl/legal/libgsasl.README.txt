GNU SASL LIBRARY README -- Important introductory notes.
Copyright (C) 2002-2021 Simon Josefsson
See the end for copying conditions.

The GNU SASL Library is a library that implements the Simple
Authentication and Security Layer (SASL) framework and some plugins.

The GNU SASL Library is licensed under the GNU Lesser General Public
License (LGPL) version 2.1 (or later).  See the file COPYING.LIB.  The
GNU project typically uses the GNU General Public License (GPL) for
libraries, and not the LGPL, but for this project we decided that we
would get more help from the community if we used the LGPLv2.1+, as
other free SASL implementations exists.  See also
<http://www.gnu.org/licenses/why-not-lgpl.html>.

Some parts, such as the gnulib self-tests (gltests/) are licensed
under the GNU General Public License (GPL) version 3.0 (or later).
See the file COPYING.

The manual is not included in this directory, see the full GNU SASL
archive.

If you need help to use GNU SASL, or wish to help others, you are
invited to join our mailing list help-gsasl@gnu.org, see
<https://lists.gnu.org/mailman/listinfo/help-gsasl>.

Currently there is some support for the following mechanisms:

  - CRAM-MD5 (RFC 2195)
  - EXTERNAL (RFC 2222)
  - GSSAPI (RFC 2222, requires GSS, Heimdal or MIT Kerberos)
  - ANONYMOUS (RFC 2245)
  - PLAIN (RFC 2595)
  - SECURID (RFC 2808)
  - DIGEST-MD5 (RFC 2831)
  - SCRAM-SHA-1 and SCRAM-SHA-1-PLUS (RFC 5802)
  - SCRAM-SHA-256 and SCRAM-SHA-256-PLUS (RFC 7677)
  - GS2-KRB5 (RFC 5801, no CB, requires GSS, Heimdal, or MIT Kerberos)
  - SAML20 (RFC 6595)
  - OPENID20 (RFC 6616)
  - LOGIN (non-standard)
  - NTLM (non-standard, client only, requires Libntlm)
  - KERBEROS_V5 (experimental, requires Shishi)

The library should be portable to all C89 platforms.

For updates to the project, see <http://www.gnu.org/software/gsasl/>.

For any copyright year range specified as YYYY-ZZZZ in this package
note that the range specifies every single year in that closed interval.

----------------------------------------------------------------------
Copying and distribution of this file, with or without modification,
are permitted in any medium without royalty provided the copyright
notice and this notice are preserved.
