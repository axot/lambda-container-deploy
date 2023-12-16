package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-xray-sdk-go/xray"
	"github.com/jpillora/ipfilter"

	"github.com/axot/lambda-container-deploy/xraylogger"
)

func homeHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	log := xraylogger.New(ctx)

	// Add annotation and metadata
	xray.AddAnnotation(ctx, "User", "example-user")
	xray.AddMetadata(ctx, "debug-info", "sample metadata")

	log.Info("home")
	io.WriteString(w, "home")
}

func topHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	log := xraylogger.New(ctx)

	// Add annotation and metadata
	xray.AddAnnotation(ctx, "User", "example-user2")
	xray.AddMetadata(ctx, "debug-info", "sample metadata2")

	log.Info("hello world")
	io.WriteString(w, "hello world")
}

func addWhiteListIPs(f *ipfilter.IPFilter) {
	// Get the WHITE_IP_LIST environment variable
	whiteIPList := os.Getenv("WHITE_IP_LIST")

	// Check if the environment variable is set
	if whiteIPList == "" {
		fmt.Println("WHITE_IP_LIST environment variable is not set")
		return
	}

	// Split the WHITE_IP_LIST into separate IP addresses/CIDR ranges
	ipList := strings.Split(whiteIPList, ",")

	// Iterate over each IP/CIDR in the list
	for _, ip := range ipList {
		fmt.Println("IP/CIDR:", ip)
		f.AllowIP(ip)
	}
}

func main() {
	f := ipfilter.New(ipfilter.Options{
		AllowedIPs:     []string{"192.168.0.0/16", "10.0.0.0/8", "172.16.0.0/12"},
		BlockByDefault: true,
		TrustProxy:     true,
	})

	addWhiteListIPs(f)

	http.Handle("/home", xray.Handler(xray.NewFixedSegmentNamer("myApp"), f.Wrap(http.HandlerFunc(homeHandler))))
	http.Handle("/", xray.Handler(xray.NewFixedSegmentNamer("myApp"), f.Wrap(http.HandlerFunc(topHandler))))

	http.ListenAndServe(":8000", nil)
}
