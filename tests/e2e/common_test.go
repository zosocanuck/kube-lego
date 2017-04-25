package e2e

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"os/exec"

	log "github.com/Sirupsen/logrus"
	"github.com/hashicorp/go-multierror"
)

const NginxChart = "stable/nginx-ingress"
const NginxChartVersion = "0.3.1"

const HelloWorldChart = "../../contrib/helm-charts/jetstack-hello-world"

type E2ETest struct {
	helmPath string
	helmHome string

	kubectlPath string

	namespace string

	env []string
}

func (t *E2ETest) init() error {
	log.SetOutput(os.Stdout)
	log.SetLevel(log.DebugLevel)
	var result, err error

	// copy env vars
	t.env = os.Environ()

	// search for helm
	t.helmPath, err = exec.LookPath("helm")
	if err != nil {
		result = multierror.Append(result, err)
	} else {
		log.Debugf("found helm at '%s'\n", t.helmPath)
	}

	// search for kubectl
	t.kubectlPath, err = exec.LookPath("kubectl")
	if err != nil {
		result = multierror.Append(result, err)
	} else {
		log.Debugf("found kubectl at '%s'\n", t.kubectlPath)
	}

	// return here if already failed
	if result != nil {
		return result
	}

	// check for kubectl connectivity
	stdout, stderr, err := t.Execute(t.kubectlPath, "version")
	if err != nil {
		return fmt.Errorf("error while trying to connect to cluster: %s, %s", err, stderr)
	}
	log.Debugf("successfully connected to kubernetes: '%s'", stdout)

	// init temp helm directory
	t.helmHome, err = ioutil.TempDir("", "kube-lego-e2e-")
	if err != nil {
		return fmt.Errorf("error creating temp directory for HELM_HOME: %s", err)
	}
	envHelmHome := fmt.Sprintf("HELM_HOME=%s", t.helmHome)
	log.Debugf("created %s", envHelmHome)
	t.env = append(t.env, envHelmHome)

	// init helm / possibly upgrade
	stdout, stderr, err = t.Execute(t.helmPath, "init", "--upgrade")
	if err != nil {
		return fmt.Errorf("error while trying to init helm: %s, %s", err, stderr)
	}
	log.Debugf("successfully initialised helm: '%s'", stdout)

	return nil
}

func (t *E2ETest) DNSName(ip net.IP) string {
	return fmt.Sprintf("%s.xip.io", ip.String())
}

func (t *E2ETest) ServiceLBIP(labels string) (net.IP, error) {
	stdout, stderr, err := t.Execute(
		t.kubectlPath,
		"--namespace",
		t.namespace,
		"get",
		"services",
		"-l",
		labels,
		"-o",
		"jsonpath={.items[0].status.loadBalancer.ingress[0].ip}",
	)
	if err != nil {
		return nil, fmt.Errorf("error while trying to get service lb IP: %s, %s", err, stderr)
	}
	ip := net.ParseIP(stdout)
	if ip == nil {
		return nil, fmt.Errorf("error while parsing IP: %s", stdout)
	}
	log.Debugf("successfully got service lb IP: %s'", ip.String())
	return ip, nil
}

func (t *E2ETest) Execute(name string, arg ...string) (string, string, error) {
	cmd := exec.Command(name, arg...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	cmd.Env = t.env
	err := cmd.Run()
	return stdout.String(), stderr.String(), err
}
