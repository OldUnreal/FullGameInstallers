What This Is
============

Long ago QUIC was created. For the past years Akamai and Microsoft have
collaborated on maintaining QUIC support via the BoringSSL APIs. However,
OpenSSL focused on their own implementation, deprioritizing other features and
improvements.

We're focused on treating the most important security protocol in the world,
and the implementation that powers cryptography across the open source
ecosystem with the importance and care it deserves.

We're going to keep API compatibility, but add new APIs that serve
programmers better, remove old cruft and deepen deprecation to help migrate
to a better world

This fork is based on OpenSSL 3.3 release, with some features and fixes
cherry-picked from OpenSSL. If there's something you find missing, please
[open an issue](https://github.com/quictls/quictls/issues) or -- better yet
:) -- make a [pull request](https://github.com/quictls/quictls/pulls).

What about FIPS?
----------------

Thanks to the provider interface we can load the OpenSSL FIPS module, and
will continue to do so. At some point we'll discuss how to get a FIPS
certification that really works for the open source world.

How can I contribute?
---------------------

Open a PR! Your code must be Apache 2 licensed. We are interested in
expanding compatibility with BoringSSL and LibreSSL, simplifying and
improving the security of some grotty code, cleaning this up, and
adding new features, even before RFCs are final.

We're also interested in KEM interfaces and postquantum algorithms, and if an
issue appeals to you, feel free to jump in and get started on it.

However, there's a bunch of design stuff that also needs to happen, but we'll
make sure to have the conversation in an open manner.

Where/how can I report vulnerabilities?
---------------------------------------

Please see our [security
policy](https://github.com/quictls/quictls/blob/main/SECURITY.md)
for information on how to report vulnerabilities in
QuicTLS to us. We are committed to sharing items with OpenSSL,
BoringSSL, and LibreSSL as necessary.


What about sonames and the like?
-------------------------------

So far we haven't changed them, but we likely will. At the same time API
and generally ABI compatibility is a big priority for us.

Who are you?
------------

This is a collaborative effort, currently among a small group of *SSL
developers. We welcome your involvement, please join us! We hope to
turn this over to the ASF if we build enough momentum. There is a
mailing list, [quictls-setup](https://groups.google.com/u/1/g/quictls-setup)
for anyone interested in helping set up the governance.

This is a collaborative effort between [Akamai](https://www.akamai.com) and
[Microsoft](https://www.microsoft.com). We welcome anyone to contribute and
join. We are working on setting up more formal structures and welcome
participation beyond writing code as well.
