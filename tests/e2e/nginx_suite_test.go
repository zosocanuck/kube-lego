package e2e

import (
	"fmt"
	"net"
	"testing"

	"github.com/cenk/backoff"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestNginx(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Nginx Suite")
}

var _ = Describe("Nginx Ingress", func() {
	var (
		test *E2ETest
	)

	BeforeSuite(func() {
		test = &E2ETest{
			namespace: "kube-lego-e2e-nginx-single",
		}
		err := test.init()
		Expect(err).NotTo(HaveOccurred())
	})

	AfterSuite(func() {
		err := test.helmCleanup()
		Expect(err).NotTo(HaveOccurred())
	})

	Context("watching single namespace", func() {
		var (
			serviceIP net.IP
		)
		It("should successfully deploy nginx-ingress", func() {
			err := test.helmDeploy(&HelmDeployOpts{
				Chart:        NginxChart,
				ChartVersion: NginxChartVersion,
				Name:         fmt.Sprintf("%s-nginx-ingress", test.namespace),
				Set: map[string]interface{}{
					"controller.scope.enabled": true,
				},
			})
			Expect(err).NotTo(HaveOccurred())
		})

		It("should get a load balancer IP allocated", func() {
			operation := func() error {
				var err error
				serviceIP, err = test.ServiceLBIP(fmt.Sprintf("app=nginx-ingress,component=controller,release=%s-nginx-ingress", test.namespace))
				return err
			}
			err := backoff.Retry(operation, backoff.NewExponentialBackOff())
			Expect(err).NotTo(HaveOccurred())
		})

		It("should successfully deploy hello-world app-a", func() {
			domain := test.DNSName(serviceIP)
			err := test.helmDeploy(&HelmDeployOpts{
				Chart: HelloWorldChart,
				Name:  fmt.Sprintf("%s-app-a", test.namespace),
				Set: map[string]interface{}{
					"replicaCount": 1,
					"ingress.acme": true,
					"ingress.domains": []string{
						fmt.Sprintf("app-a.%s", domain),
						fmt.Sprintf("app-a-stage.%s", domain),
					},
				},
			})
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
