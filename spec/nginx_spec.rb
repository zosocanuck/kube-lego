require 'spec_helper'
require 'net/http'


RSpec.describe "nginx-ingress" do

  before (:all) do 
    helm_init
  end

  let (:nginx_chart_version) do
    '0.3.1'
  end

  let (:namespace) do
    'test-ns'
  end

  let (:service_ip) do
    service_lb_ip(namespace, "#{namespace}-nginx-ingress-nginx-ingress-controller")
  end

  context 'watches its namespace' do
    it 'installs nginx chart' do
      helm_deploy_nginx(
        namespace: namespace,
        chart_version: nginx_chart_version,
        name: "#{namespace}-nginx-ingress",
        set: {
          'controller.scope.enabled': true,
        },
      )
    end

    it 'gets load balancer IP' do
      service_ip
    end

    it 'deploys kube-lego' do
      helm_deploy_kube_lego(
        namespace: namespace,
        name: "#{namespace}-kube-lego",
        set: {
          'image.tag': 'canary',
          'image.pullPolicy': 'Always',
          'config.LEGO_LOG_LEVEL': 'debug',
          'config.LEGO_EMAIL': 'tech+kube-lego-dev@jetstack.io',
        },
      )
    end

    it 'deploys app-a' do
      domains = [
       "app-a.#{service_ip}.xip.io",
       "app-a-stage.#{service_ip}.xip.io",
      ]
      helm_deploy_hello_world(
        namespace: namespace,
        name: "#{namespace}-app-a",
        set: {
          'replicaCount': '1',
          'ingress.domains': domains,
          'ingress.acme': true,
        },
      )
    end

    it 'has a reachable app-a' do
      expect(http_get("http://app-a-stage.#{service_ip}.xip.io/").body).to match(/Hello world from K8S!/)
    end

    it 'has a staging certificate' do
      resp = https_get_certifiate("https://app-a-stage.#{service_ip}.xip.io/")
      expect(resp[1]).to eq(:staging)
      expect(resp[3]).to match_array([
        "app-a-stage.#{service_ip}.xip.io",
        "app-a.#{service_ip}.xip.io"
      ])
    end
  end

  context 'watches all namespaces' do
  end

end
