package e2e

import (
	"fmt"
	"strings"

	log "github.com/Sirupsen/logrus"
)

type HelmDeployOpts struct {
	Chart        string
	ChartVersion string
	Name         string
	Set          map[string]interface{}
}

func (t *E2ETest) helmCleanup() error {
	stdout, stderr, err := t.Execute(t.helmPath, "list", "--namespace", t.namespace)
	if err != nil {
		return fmt.Errorf("helm listing namespace deployments failed: %s, %s", err, stderr)
	}

	for _, line := range strings.Split(stdout, "\n")[1:] {
		if line == "" {
			continue
		}
		deployment := strings.Fields(line)[0]
		_, stderr, err := t.Execute(t.helmPath, "delete", "--purge", deployment)
		if err != nil {
			log.Warnf("error cleaning up '%s' using helm: %s, %s", deployment, err, stderr)
		}
	}

	return nil

}

func (t *E2ETest) helmDeploy(opts *HelmDeployOpts) error {
	args := []string{
		"upgrade",
		"--install",
	}

	if opts.ChartVersion != "" {
		args = append(args, "--version", opts.ChartVersion)
	}

	args = append(args, "--namespace", t.namespace)

	if opts.Set != nil {
		sets := []string{}
		for key, value := range opts.Set {
			switch value := value.(type) {
			default:
				fmt.Printf("unexpected type %T in set values", value)
			case int64, int32, int:
				sets = append(sets, fmt.Sprintf("%s=%d", key, value))
			case bool:
				sets = append(sets, fmt.Sprintf("%s=%t", key, value))
			case string:
				sets = append(sets, fmt.Sprintf("%s=%s", key, value))
			case []string:
				sets = append(sets, fmt.Sprintf("%s={%s}", key, strings.Join(value, ",")))
			}
		}
		if len(args) > 0 {
			args = append(args, "--set", strings.Join(sets, ","))
		}
	}

	args = append(args, opts.Name, opts.Chart)

	stdout, stderr, err := t.Execute(t.helmPath, args...)

	if err != nil {
		return fmt.Errorf("helm delpoy %s %+v failed: %s, %s", t.helmPath, args, err, stderr)
	}
	log.Debugf("helm delpoy %s %+v succesful: %s", t.helmPath, args, stdout)
	return nil
}
