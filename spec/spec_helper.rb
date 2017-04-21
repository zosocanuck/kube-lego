require 'open3'
require 'yaml'
require 'logger'

$logger = Logger.new(STDERR)
$logger.level = Logger::DEBUG

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


  def https_get_certifiate(url)
    uri = URI(url)
    Net::HTTP.start(
      uri.host,
      uri.port,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE,
      :verify_callback => lambda do |ok, cert_store|
        $logger.debug cert_store.inspect
        return true
      end,
    ) do |http|
      request = Net::HTTP::Get.new uri
      response = http.request request
      $logger.debug response.to_hash
    end
  end
end

RSpec.configure do |config|
  config.default_formatter = 'doc'
  config.register_ordering(:defined) do |items|
    items
  end
  config.include Helpers
end
