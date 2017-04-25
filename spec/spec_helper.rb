require 'open3'
require 'yaml'
require 'logger'

$logger = Logger.new(STDERR)
$logger.level = Logger::DEBUG

LetsEncryptProduction = <<EOS
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
EOS

LetsEncryptStaging = <<EOS
-----BEGIN CERTIFICATE-----
MIIFATCCAumgAwIBAgIRAKc9ZKBASymy5TLOEp57N98wDQYJKoZIhvcNAQELBQAw
GjEYMBYGA1UEAwwPRmFrZSBMRSBSb290IFgxMB4XDTE2MDMyMzIyNTM0NloXDTM2
MDMyMzIyNTM0NlowGjEYMBYGA1UEAwwPRmFrZSBMRSBSb290IFgxMIICIjANBgkq
hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA+pYHvQw5iU3v2b3iNuYNKYgsWD6KU7aJ
diddtZQxSWYzUI3U0I1UsRPTxnhTifs/M9NW4ZlV13ZfB7APwC8oqKOIiwo7IwlP
xg0VKgyz+kT8RJfYr66PPIYP0fpTeu42LpMJ+CKo9sbpgVNDZN2z/qiXrRNX/VtG
TkPV7a44fZ5bHHVruAxvDnylpQxJobtCBWlJSsbIRGFHMc2z88eUz9NmIOWUKGGj
EmP76x8OfRHpIpuxRSCjn0+i9+hR2siIOpcMOGd+40uVJxbRRP5ZXnUFa2fF5FWd
O0u0RPI8HON0ovhrwPJY+4eWKkQzyC611oLPYGQ4EbifRsTsCxUZqyUuStGyp8oa
aoSKfF6X0+KzGgwwnrjRTUpIl19A92KR0Noo6h622OX+4sZiO/JQdkuX5w/HupK0
A0M0WSMCvU6GOhjGotmh2VTEJwHHY4+TUk0iQYRtv1crONklyZoAQPD76hCrC8Cr
IbgsZLfTMC8TWUoMbyUDgvgYkHKMoPm0VGVVuwpRKJxv7+2wXO+pivrrUl2Q9fPe
Kk055nJLMV9yPUdig8othUKrRfSxli946AEV1eEOhxddfEwBE3Lt2xn0hhiIedbb
Ftf/5kEWFZkXyUmMJK8Ra76Kus2ABueUVEcZ48hrRr1Hf1N9n59VbTUaXgeiZA50
qXf2bymE6F8CAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMB
Af8wHQYDVR0OBBYEFMEmdKSKRKDm+iAo2FwjmkWIGHngMA0GCSqGSIb3DQEBCwUA
A4ICAQBCPw74M9X/Xx04K1VAES3ypgQYH5bf9FXVDrwhRFSVckria/7dMzoF5wln
uq9NGsjkkkDg17AohcQdr8alH4LvPdxpKr3BjpvEcmbqF8xH+MbbeUEnmbSfLI8H
sefuhXF9AF/9iYvpVNC8FmJ0OhiVv13VgMQw0CRKkbtjZBf8xaEhq/YqxWVsgOjm
dm5CAQ2X0aX7502x8wYRgMnZhA5goC1zVWBVAi8yhhmlhhoDUfg17cXkmaJC5pDd
oenZ9NVhW8eDb03MFCrWNvIh89DDeCGWuWfDltDq0n3owyL0IeSn7RfpSclpxVmV
/53jkYjwIgxIG7Gsv0LKMbsf6QdBcTjhvfZyMIpBRkTe3zuHd2feKzY9lEkbRvRQ
zbh4Ps5YBnG6CKJPTbe2hfi3nhnw/MyEmF3zb0hzvLWNrR9XW3ibb2oL3424XOwc
VjrTSCLzO9Rv6s5wi03qoWvKAQQAElqTYRHhynJ3w6wuvKYF5zcZF3MDnrVGLbh1
Q9ePRFBCiXOQ6wPLoUhrrbZ8LpFUFYDXHMtYM7P9sc9IAWoONXREJaO08zgFtMp4
8iyIYUyQAbsvx8oD2M8kRvrIRSrRJSl6L957b4AFiLIQ/GgV2curs0jje7Edx34c
idWw1VrejtwclobqNMVtG3EiPUIpJGpbMcJgbiLSmKkrvQtGng==
-----END CERTIFICATE-----
EOS

module Helpers
  def execute(cmd)
    Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value
      unless exit_status.success?
        puts "stdout is:" + stdout.read
        puts "stderr is:" + stderr.read
        fail "FAILED !!! #{cmd}"
      end
      $logger.debug("cmd '#{cmd}' exited #{exit_status.to_i}")
      stdout.read
    end
  end

  def service_lb_ip(namespace, name)
    ip = YAML.load(execute("kubectl --namespace #{namespace} get services -o yaml #{name}"))['status']['loadBalancer']['ingress'].first['ip']
    $logger.debug "detected service IP #{ip}"
    ip
  end

  def helm_init
    dir = Dir.mktmpdir
    version = execute('kubectl version')
    $logger.debug "connected to kube api #{version}"
    ENV['HELM_HOME'] = dir
    $logger.debug "using #{dir} as HELM_HOME"
    execute('helm init --upgrade')
    dir
  end

  def helm_deploy_nginx(opts={})
    o = {
      namespace: 'nginx-ingress',
      chart: 'stable/nginx-ingress',
      name: 'nginx-ingress',
      set: {},
    }
    o.update(opts)
    helm_delpoy(o)
  end

  def helm_deploy_hello_world(opts={})
    o = {
      namespace: 'hello-world',
      chart: 'contrib/helm-charts/jetstack-hello-world',
      name: 'hello-world',
      set: {},
    }
    o.update(opts)
    helm_delpoy(o)
  end

  def helm_deploy_kube_lego(opts={})
    o = {
      namespace: 'kube-lego',
      chart: 'contrib/helm-charts/kube-lego',
      name: 'kube-lego',
      set: {},
    }
    o.update(opts)
    helm_delpoy(o)
  end

  def helm_delpoy(opts={})
    cmd = [
      'helm',
      'upgrade',
      '--install',
    ]

    cmd += ['--version', opts[:chart_version]] if opts[:chart_version]
    cmd += ['--namespace', opts[:namespace]] if opts[:namespace]

    opts[:set].each do |key, value|

      if value.kind_of?(Array)
        value = "{#{value.join(',')}}"
      end
      cmd += ['--set', "#{key}=#{value}"]
    end

    cmd << opts[:name]
    cmd << opts[:chart]

    execute(cmd)
  end

  def http_get(uri_str, limit = 10)
    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    url = URI.parse(uri_str)
    req = Net::HTTP::Get.new(url.path)
    response = Net::HTTP.start(
      url.host,
      url.port,
      :use_ssl => url.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE,
    ) { |http| http.request(req) }
    case response
    when Net::HTTPSuccess     then response
    when Net::HTTPRedirection then http_get(response['location'], limit - 1)
    else
      response.error!
    end
  end

  def https_get_certifiate(url)
    uri = URI(url)
    sans = []
    cert = nil
    verify = :none
    response = Net::HTTP.start(
      uri.host,
      uri.port,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE,
      :verify_callback => lambda do |ok, cert_store|
        begin
          cert = cert_store.chain[0]
          subject_alt_name = cert.extensions.find {|e| e.oid == 'subjectAltName'}
          sans = subject_alt_name.value.split(', ').map { |v| v.gsub(/^DNS:/,'') }

          [[:production, LetsEncryptProduction], [:staging, LetsEncryptStaging]].each do |name, ca_cert|
            # create a CA store
            ca_store = OpenSSL::X509::Store.new
            ca_store.add_cert(OpenSSL::X509::Certificate.new(ca_cert))

            # add intermediate to CA store
            ca_store.add_cert(cert_store.chain[1])

            ctx = OpenSSL::X509::StoreContext.new(
              ca_store,
              cert_store.chain[0],
              [],
            )

            if ctx.verify == true
              verify = name
              return true
            end
            $logger.debug "cert #{cert.subject} doesn't match #{OpenSSL::X509::Certificate.new(ca_cert).subject}"
          end
          return false
        rescue => e
          $logger.error e.to_s
        end
      end,
    ) do |http|
      request = Net::HTTP::Get.new uri
      http.request request
    end
    return response, verify, cert, sans
  end
end

RSpec.configure do |config|
  config.default_formatter = 'doc'
  config.register_ordering(:defined) do |items|
    items
  end
  config.include Helpers
end
