package xraylogger

import (
	"context"
	"log"
	"os"

	"github.com/aws/aws-xray-sdk-go/xray"
)

type XRayLogger struct {
	logger  *log.Logger
	traceID string
}

func New(ctx context.Context) *XRayLogger {
	return &XRayLogger{
		logger:  log.New(os.Stdout, "", log.LstdFlags),
		traceID: xray.TraceID(ctx),
	}
}

func (l *XRayLogger) Info(msg string) {
	l.logger.Printf("[INFO] [Trace-ID: %s] %s", l.traceID, msg)
}

func (l *XRayLogger) Debug(msg string) {
	l.logger.Printf("[DEBUG] [Trace-ID: %s] %s", l.traceID, msg)
}

func (l *XRayLogger) Error(msg string) {
	l.logger.Printf("[ERROR] [Trace-ID: %s] %s", l.traceID, msg)
}
