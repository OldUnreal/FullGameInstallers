# Libidn2 README -- Introduction information

Libidn2 is a free software implementation of IDNA2008, Punycode and
Unicode TR46.  Its purpose is to encode and decode internationalized
domain names.

For technical reference, see:

 * [IDNA2008 Framework](https://tools.ietf.org/html/rfc5890)
 * [IDNA2008 Protocol](https://tools.ietf.org/html/rfc5891)
 * [IDNA2008 Unicode tables](https://tools.ietf.org/html/rfc5892)
 * [IDNA2008 Bidi rule](https://tools.ietf.org/html/rfc5893)
 * [Punycode](https://tools.ietf.org/html/rfc3492)
 * [Unicode IDNA Compatibility Processing](https://www.unicode.org/reports/tr46/)

The library contains functionality to convert internationalized domain
names to and from ASCII Compatible Encoding (ACE).

The API consists of two main functions, `idn2_to_ascii_8z` for
converting data from UTF-8 to ASCII Compatible Encoding (ACE), and
`idn2_to_unicode_8z8z` to convert ACE names into UTF-8 format. There
are several variations of these main functions, which accept UTF-32,
or input in the local system encoding. All functions assume
zero-terminated strings.

This library is backwards (API) compatible with the [libidn
library](https://www.gnu.org/software/libidn/).  Replacing the
`idna.h` header with `idn2.h` into a program is sufficient to switch
the application from IDNA2003 to IDNA2008 as supported by this
library.

Libidn2 is believed to be a complete IDNA2008 and TR46 implementation
and contains an extensive test-suite.

You can check the current test code coverage
[here](https://libidn.gitlab.io/libidn2/coverage/index.html) and the
current fuzzing code coverage
[here](https://libidn.gitlab.io/libidn2/fuzz-coverage/index.html) that
is part of the continuous fuzzing project
[OSS-Fuzz](https://issues.oss-fuzz.com/issues?q=is:open%20libidn2).


# License

The source code for the C library (libidn2.a or libidn.so) are
dual-licensed under the terms of either the GNU General Public License
version 2.0 or later - see the file [COPYINGv2](COPYINGv2) - or the
GNU Lesser General Public License version 3.0 or later - see the file
[COPYING.LESSERv3](COPYING.LESSERv3) - or both in parallel as here.

The command line tool, self tests, examples, and other auxiliary
files, are licensed under the GNU General Public License version 3.0
or later - see the file [COPYING](COPYING).

The license of the Unicode character data files (which are parsed into
static storage in the library) are documented in
[COPYING.unicode](COPYING.unicode).

Other files are licensed as indicated in each file.  There may be
exceptions to these general rules, see each file for precise
information.

For any copyright year range specified as YYYY-ZZZZ in this package
note that the range specifies every single year in that closed interval.

# Online docs

[API reference](https://libidn.gitlab.io/libidn2/reference/api-index-full.html)

[Manual](https://libidn.gitlab.io/libidn2/manual/libidn2.html)


# Obtaining the source

Software releases of libidn2 can be downloaded from
https://ftp.gnu.org/gnu/libidn/ and ftp://ftp.gnu.org/gnu/libidn/

Development of libidn2 is organized [through GitLab
website](https://gitlab.com/libidn/libidn2), and there is [an issue
tracker for reporting bugs](https://gitlab.com/libidn/libidn2/issues).


# Building & Dependencies

Before building you should consider installing the
[dependencies](DEPENDENCIES.md).

When building from a release tarball archive, after unpacking you
build the package like this:

```
./configure
make
make check
```

# Contributing

See [the contributing document](CONTRIBUTING.md).


# Estimating code coverage

You need [LCOV](https://github.com/linux-test-project/lcov) installed.

To test the code coverage of the test suite use the following:

```
./configure --enable-code-coverage
make && make check && make code-coverage-capture
```

The current coverage report can be found [here](https://libidn.gitlab.io/libidn2/coverage/).


# Fuzzing

Libidn2 is being continuously fuzzed by [OSS-Fuzz](https://github.com/google/oss-fuzz).

Of course you can do local fuzzing on your own, see `fuzz/README.md` for instructions.

The code coverage of our fuzzers can be found [here](https://libidn.gitlab.io/libidn2/fuzz-coverage/).
