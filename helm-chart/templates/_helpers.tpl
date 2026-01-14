{{/*
Expand the name of the chart.
*/}}
{{- define "fleetdm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "fleetdm.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fleetdm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fleetdm.labels" -}}
helm.sh/chart: {{ include "fleetdm.chart" . }}
{{ include "fleetdm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fleetdm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fleetdm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate MySQL connection string
*/}}
{{- define "fleetdm.mysql.address" -}}
{{- if .Values.mysql.enabled }}
{{- printf "%s-mysql:3306" (include "fleetdm.fullname" .) }}
{{- else }}
{{- .Values.fleetdm.mysql.address }}
{{- end }}
{{- end }}

{{/*
Generate Redis connection string
*/}}
{{- define "fleetdm.redis.address" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s-redis-master:6379" (include "fleetdm.fullname" .) }}
{{- else }}
{{- .Values.fleetdm.redis.address }}
{{- end }}
{{- end }}

{{/*
Generate MySQL password secret name
*/}}
{{- define "fleetdm.mysql.secretName" -}}
{{- if .Values.mysql.enabled }}
{{- printf "%s-mysql" (include "fleetdm.fullname" .) }}
{{- else }}
{{- printf "%s-mysql-secret" (include "fleetdm.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Generate Redis password secret name
*/}}
{{- define "fleetdm.redis.secretName" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s-redis" (include "fleetdm.fullname" .) }}
{{- else }}
{{- printf "%s-redis-secret" (include "fleetdm.fullname" .) }}
{{- end }}
{{- end }}

