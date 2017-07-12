package secret

import (
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"time"

	"github.com/jetstack/kube-lego/pkg/kubelego_const"
	"github.com/jetstack/kube-lego/pkg/utils"

	"github.com/Sirupsen/logrus"
	k8sErrors "k8s.io/apimachinery/pkg/api/errors"
	k8sMeta "k8s.io/apimachinery/pkg/apis/meta/v1"
	k8sLabels "k8s.io/apimachinery/pkg/labels"
	k8sSelection "k8s.io/apimachinery/pkg/selection"
	k8sApiTyped "k8s.io/client-go/kubernetes/typed/core/v1"
	k8sApi "k8s.io/client-go/pkg/api/v1"
)

// List will lookup Secret resources in the cluster set in client.KubeClient(),
// in the namespace provided and matching the given labels. If no secrets exist
func List(client kubelego.KubeLego, namespace string, labels map[string]string) ([]*Secret, error) {
	var err error
	selector := k8sLabels.NewSelector()
	for key, val := range labels {
		req, err := k8sLabels.NewRequirement(key, k8sSelection.Equals, []string{val})
		if err != nil {
			return nil, fmt.Errorf("error creating label requirement: %s", err.Error())
		}
		selector = selector.Add(*req)
	}
	secrets, err := client.KubeClient().Secrets(namespace).List(k8sMeta.ListOptions{
		LabelSelector: selector.String(),
	})
	if err != nil {
		return nil, fmt.Errorf("error listing secrets: %s", err.Error())
	}
	// no secrets exist matching the selector, so create a new one
	if len(secrets.Items) == 0 {
		// todo (@munnerz): ensure that the token name generated does not already exist
		return []*Secret{New(client, namespace, fmt.Sprintf("kube-lego-%s", utils.RandomToken(6)))}, nil
	}
	s := make([]*Secret, len(secrets.Items))
	for i, secret := range secrets.Items {
		s[i] = &Secret{
			// todo (@munnerz): perform a deep copy of the secret instead of referencing it.
			// when we switch to a shared informer for these objects, this will cause havoc
			// on the cache
			SecretApi: &secret,
			exists:    true,
			kubelego:  client,
		}
	}
	return s, nil
}

func New(client kubelego.KubeLego, namespace string, name string) *Secret {
	secret := &Secret{
		exists:   true,
		kubelego: client,
	}

	var err error
	secret.SecretApi, err = client.KubeClient().Secrets(namespace).Get(name, k8sMeta.GetOptions{})
	if err != nil {
		if k8sErrors.IsNotFound(err) {
			secret.SecretApi = &k8sApi.Secret{
				ObjectMeta: k8sMeta.ObjectMeta{
					Namespace: namespace,
					Name:      name,
				},
			}
			secret.Log().Info("Attempting to create new secret")
			secret.exists = false
		} else {
			client.Log().Warn("Error while getting secret: ", err)
		}
	}

	return secret
}

func (o *Secret) Log() *logrus.Entry {
	log := o.kubelego.Log().WithField("context", "secret")

	if o.SecretApi != nil && o.SecretApi.Name != "" {
		log = log.WithField("name", o.SecretApi.Name)
	}
	if o.SecretApi != nil && o.SecretApi.Namespace != "" {
		log = log.WithField("namespace", o.SecretApi.Namespace)
	}
	return log
}

func (o *Secret) client() k8sApiTyped.SecretInterface {
	return o.kubelego.KubeClient().Secrets(o.SecretApi.Namespace)
}

func (o *Secret) Save() (err error) {
	var obj *k8sApi.Secret
	if o.exists {
		obj, err = o.client().Update(o.SecretApi)
	} else {
		obj, err = o.client().Create(o.SecretApi)
	}
	if err != nil {
		o.Log().Warn("Error while storing secret: ", err)
		return
	}
	o.Log().Info("Secret successfully stored")
	o.SecretApi = obj
	return
}

func (o *Secret) Exists() bool {
	return o.exists
}

func (o *Secret) TlsDomains() ([]string, error) {

	cert, err := o.tlsCertPem()
	if err != nil {
		return []string{}, err
	}

	return cert.DNSNames, nil
}

func (o *Secret) TlsExpireTime() (time.Time, error) {
	cert, err := o.tlsCertPem()
	if err != nil {
		return time.Time{}, err
	}

	return cert.NotAfter, nil
}

func (o *Secret) KubeLego() kubelego.KubeLego {
	return o.kubelego
}

func (o *Secret) Object() *k8sApi.Secret {
	return o.SecretApi
}

func (o *Secret) TlsDomainsInclude(domains []string) bool {

	tlsDomainsMap := make(map[string]bool)
	tlsDomainsSlice, err := o.TlsDomains()
	if err != nil {
		return false
	}
	for _, domain := range tlsDomainsSlice {
		tlsDomainsMap[domain] = true
	}

	for _, domain := range domains {
		if val, ok := tlsDomainsMap[domain]; !ok || !val {
			return false
		}
	}

	return true
}

func (o *Secret) tlsCertPem() (cert *x509.Certificate, err error) {
	key := kubelego.TLSCertKey

	certBytes, ok := o.SecretApi.Data[key]
	if !ok {
		err = fmt.Errorf("Data field '%s' not found", key)
		return
	}

	block, _ := pem.Decode(certBytes)
	if block == nil {
		err = fmt.Errorf("Error parsing PEM certificate in '%s'", key)
		return
	}

	return x509.ParseCertificate(block.Bytes)
}
