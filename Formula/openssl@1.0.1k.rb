class OpensslAT101k < Formula
  homepage "https://openssl.org"
  url "https://www.openssl.org/source/openssl-1.0.1k.tar.gz"
  mirror "https://github.com/2a5A1Ghu1/homebrew-CryptoTap/raw/master/prerequisites/openssl/openssl-1.0.1k.tar.gz"
  sha256 "8f9faeaebad088e772f4ef5e38252d472be4d878c6b3a2718c10a4fcebe7a41c"

  #bottle do
  #  sha1 "3d0e5529a124be70266dd2a2074f4f84db38bb19" => :yosemite
  #  sha1 "449b81391bd9718b1ed7a37678c686b712669f38" => :mavericks
  #  sha1 "8f1b30f6352486726b8420e80cceeecd49a61f82" => :mountain_lion
  #end

  option :universal
  option "without-check", "Skip build-time tests (not recommended)"

  depends_on "makedepend" => :build

  keg_only :provided_by_osx,
    "Apple has deprecated use of OpenSSL in favor of its own TLS and crypto libraries"

  def configure_args; %W[
    --prefix=#{prefix}
    --openssldir=#{openssldir}
    no-ssl2
    no-ssl3
    no-zlib
  ]
  end

  def install
    # This could interfere with how we expect OpenSSL to build.
    ENV.delete("OPENSSL_LOCAL_CONFIG_DIR")

    # This ensures where Homebrew's Perl is needed the Cellar path isn't
    # hardcoded into OpenSSL's scripts, causing them to break every Perl update.
    # Whilst our env points to opt_bin, by default OpenSSL resolves the symlink.
    if which("perl") == Formula["perl"].opt_bin/"perl"
      ENV["PERL"] = Formula["perl"].opt_bin/"perl"
    end

    arch_args = %w[darwin64-x86_64-cc enable-ec_nistp_64_gcc_128]

    ENV.deparallelize
    system "perl", "./Configure", *(configure_args + arch_args)
    system "make"
    system "make", "test"
    system "make", "install", "MANDIR=#{man}", "MANSUFFIX=ssl"
  end

  def openssldir
    etc/"openssl@1.0.1k"
  end

  def post_install
    keychains = %w[
      /System/Library/Keychains/SystemRootCertificates.keychain
    ]

    certs_list = `security find-certificate -a -p #{keychains.join(" ")}`
    certs = certs_list.scan(
      /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m,
    )

    valid_certs = certs.select do |cert|
      IO.popen("#{bin}/openssl x509 -inform pem -checkend 0 -noout >/dev/null", "w") do |openssl_io|
        openssl_io.write(cert)
        openssl_io.close_write
      end

      $CHILD_STATUS.success?
    end

    openssldir.mkpath
    (openssldir/"cert.pem").atomic_write(valid_certs.join("\n") << "\n")
  end

  def caveats; <<~EOS
    A CA file has been bootstrapped using certificates from the system
    keychain. To add additional certificates, place .pem files in
      #{openssldir}/certs
    and run
      #{opt_bin}/c_rehash
  EOS
  end

  #test do
    # Make sure the necessary .cnf file exists, otherwise OpenSSL gets moody.
    # assert_predicate HOMEBREW_PREFIX/"etc/openssl@1.1/openssl.cnf", :exist?,
    #        "OpenSSL requires the .cnf file for some functionality"

    #Check OpenSSL itself functions as expected.
    #(testpath/"testfile.txt").write("This is a test file")
    #expected_checksum = "91b7b0b1e27bfbf7bc646946f35fa972c47c2d32"
    #system bin/"openssl", "dgst", "-sha256", "-out", "checksum.txt", "testfile.txt"
    #open("checksum.txt") do |f|
    #  checksum = f.read(100).split("=").last.strip
    #  assert_equal checksum, expected_checksum
    end
  #end
end
