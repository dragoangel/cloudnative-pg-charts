{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts
*/}}
{{- define "cluster.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cluster.fullname" -}}
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
{{- define "cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cluster.labels" -}}
helm.sh/chart: {{ include "cluster.chart" . }}
{{ include "cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: cloudnative-pg
{{- end }}

{{/*
Whether we need to use TimescaleDB defaults
*/}}
{{- define "cluster.useTimescaleDBDefaults" -}}
{{ and (eq .Values.type "timescaledb") .Values.imageCatalog.create (empty .Values.cluster.imageCatalogRef.name) (empty .Values.imageCatalog.images) (empty .Values.cluster.imageName) }}
{{- end -}}

{{/*
Get the PostgreSQL major version from .Values.version.postgresql
*/}}
{{- define "cluster.postgresqlMajor" -}}
{{ index (regexSplit "\\." (toString .Values.version.postgresql) 2) 0 }}
{{- end -}}

{{/*
Cluster Image Name
If a custom imageName is available, use it, otherwise use the defaults based on the .Values.type
*/}}
{{- define "cluster.imageName" -}}
    {{- if .Values.cluster.imageName -}}
        {{- .Values.cluster.imageName -}}
    {{- else if eq .Values.type "postgresql" -}}
        {{- printf "ghcr.io/cloudnative-pg/postgresql:%s" .Values.version.postgresql -}}
    {{- else if eq .Values.type "postgis" -}}
        {{- printf "ghcr.io/cloudnative-pg/postgis:%s-%s" .Values.version.postgresql .Values.version.postgis -}}
    {{- else -}}
        {{ fail "Invalid cluster type!" }}
    {{- end }}
{{- end -}}

{{/*
Cluster Image
If imageCatalogRef defined, use it, otherwise calculate ordinary imageName.
*/}}
{{- define "cluster.image" }}
{{- if .Values.cluster.imageCatalogRef.name }}
imageCatalogRef:
  apiGroup: postgresql.cnpg.io
  {{- toYaml .Values.cluster.imageCatalogRef | nindent 2 }}
  major: {{ include "cluster.postgresqlMajor" . }}
{{- else if and .Values.imageCatalog.create (not (empty .Values.imageCatalog.images )) }}
imageCatalogRef:
  apiGroup: postgresql.cnpg.io
  kind: ImageCatalog
  name: {{ include "cluster.fullname" . }}
  major: {{ include "cluster.postgresqlMajor" . }}
{{- else if eq (include "cluster.useTimescaleDBDefaults" .) "true" -}}
imageCatalogRef:
  apiGroup: postgresql.cnpg.io
  kind: ImageCatalog
  name: {{ include "cluster.fullname" . }}-timescaledb-ha
  major: {{ include "cluster.postgresqlMajor" . }}
{{- else }}
imageName: {{ include "cluster.imageName" . }}
{{- end }}
{{- end }}

{{/*
Postgres UID
*/}}
{{- define "cluster.postgresUID" -}}
  {{- if ge (int .Values.cluster.postgresUID) 0 -}}
    {{- .Values.cluster.postgresUID }}
  {{- else if and (eq (include "cluster.useTimescaleDBDefaults" .) "true") (eq .Values.type "timescaledb") -}}
    {{- 1000 -}}
  {{- else -}}
    {{- 26 -}}
  {{- end -}}
{{- end -}}

{{/*
Postgres GID
*/}}
{{- define "cluster.postgresGID" -}}
  {{- if ge (int .Values.cluster.postgresGID) 0 -}}
    {{- .Values.cluster.postgresGID }}
  {{- else if and (eq (include "cluster.useTimescaleDBDefaults" .) "true") (eq .Values.type "timescaledb") -}}
    {{- 1000 -}}
  {{- else -}}
    {{- 26 -}}
  {{- end -}}
{{- end -}}

{{/*
Recovery enabled
Verify that recovery method is set to one of supported methods in methodSettings
Definition assume we have recovery enabled also in import and replication modes, if need to know
for sure that mode is set to recovery: use (eq .Values.mode "recovery")
*/}}
{{- define "cluster.recovery.enabled" -}}
  {{- if and (or (eq .Values.mode "recovery") (eq .Values.mode "replica") (eq .Values.mode "import")) }}
    {{- if empty .Values.recovery.method }}
      {{- fail (printf ".Values.recovery.method is required, but not specified.") }}
    {{- else if not (hasKey .Values.recovery.methodSettings .Values.recovery.method) }}
      {{- fail (printf "The specified method '%s' does not match any of the supported in .Values.recovery.methodSettings" .Values.recovery.method) }}
    {{- end }}
    {{- hasKey .Values.recovery.methodSettings .Values.recovery.method }}
  {{- end }}
{{- end }}

{{/*
Recovery objectStorage enabled
Verify that provider is set to one of supported providers in providerSettings
*/}}
{{- define "cluster.recovery.method.objectStorage.enabled" -}}
  {{- if and (eq (include "cluster.recovery.enabled" .) "true") (eq .Values.recovery.method "objectStorage") }}
    {{- if empty .Values.recovery.methodSettings.objectStorage.provider }}
      {{- fail (printf ".Values.recovery.methodSettings.objectStorage.provider is required, but not specified.") }}
    {{- else if not (hasKey .Values.recovery.methodSettings.objectStorage.providerSettings .Values.recovery.methodSettings.objectStorage.provider) }}
      {{- fail (printf "The specified provider '%s' does not match any of the supported in .Values.recovery.methodSettings.objectStorage.providerSettings" .Values.recovery.methodSettings.objectStorage.provider) }}
    {{- end }}
    {{- hasKey .Values.recovery.methodSettings.objectStorage.providerSettings .Values.recovery.methodSettings.objectStorage.provider }}
  {{- end }}
{{- end }}

{{/*
Recovery pgBasebackup enabled
*/}}
{{- define "cluster.recovery.method.pgBasebackup.enabled" -}}
  {{- if (eq (include "cluster.recovery.method.pgBasebackup.auth.enabled" .) "true") }}
    {{- and (eq (include "cluster.recovery.enabled" .) "true") (eq .Values.recovery.method "pgBasebackup") }}
  {{- end }}
{{- end }}

{{/*
Recovery pgBasebackup auth enabled
Verify that pgBasebackup auth is set to one of supported options in authDetails
*/}}
{{- define "cluster.recovery.method.pgBasebackup.auth.enabled" -}}
  {{- if empty .Values.recovery.methodSettings.pgBasebackup.auth }}
    {{- fail (printf ".Values.recovery.methodSettings.pgBasebackup.auth is required, but not specified.") }}
  {{- else if not (hasKey .Values.recovery.methodSettings.pgBasebackup.authDetails .Values.recovery.methodSettings.pgBasebackup.auth) }}
    {{- fail (printf "The specified auth '%s' does not match any of the supported in .Values.recovery.methodSettings.pgBasebackup.authDetails" .Values.recovery.methodSettings.pgBasebackup.auth) }}
  {{- end }}
  {{- hasKey .Values.recovery.methodSettings.pgBasebackup.authDetails .Values.recovery.methodSettings.pgBasebackup.auth }}
{{- end }}

{{/*
Import enabled
Verify that import type is set to one of supported in typeSettings
*/}}
{{- define "cluster.import.enabled" -}}
  {{- if eq .Values.mode "import" }}
    {{- if empty .Values.import.type }}
      {{- fail (printf ".Values.import.type is required, but not specified.") }}
    {{- else if not (hasKey .Values.import.typeSettings .Values.import.type) }}
      {{- fail (printf "The specified type '%s' does not match any of the supported in .Values.import.typeSettings" .Values.import.type) }}
    {{- end }}
    {{- hasKey .Values.import.typeSettings .Values.import.type }}
  {{- end }}
{{- end }}

{{/*
Import type microservice enabled
Verify that recovery method is set to pgBasebackup
*/}}
{{- define "cluster.import.type.microservice.enabled" -}}
{{- if and (eq (include "cluster.import.enabled" .) "true") (eq .Values.import.type "microservice") }}
  {{- if (eq (include "cluster.recovery.method.pgBasebackup.enabled" .) "true") }}
    {{- if (empty .Values.import.typeSettings.microservice.database) }}
      {{- fail (printf ".Values.import.typeSettings.microservice.database is required, but not specified.") }}
    {{- else }}
      {{- true }}
    {{- end }}
  {{- else }}
    {{- fail (printf "Import mode requires recovery mode to be set to 'pgBasebackup'") }}
  {{- end }}
{{- else }}
  {{- false }}
{{- end }}
{{- end }}

{{/*
Import type monolith enabled
Verify that recovery method is set to pgBasebackup
*/}}
{{- define "cluster.import.type.monolith.enabled" -}}
{{- if and (eq (include "cluster.import.enabled" .) "true") (eq .Values.import.type "monolith") }}
  {{- if (eq (include "cluster.recovery.method.pgBasebackup.enabled" .) "true") }}
    {{- if (eq (len .Values.import.typeSettings.monolith.databases) 0) }}
      {{- fail (printf ".Values.import.typeSettings.monolith.databases is required, but not specified.") }}
    {{- else }}
      {{- true }}
    {{- end }}
  {{- else }}
    {{- fail (printf "Import mode requires recovery mode to be set to 'pgBasebackup'") }}
  {{- end }}
{{- else }}
  {{- false }}
{{- end }}
{{- end }}

{{/*
Replica enabled
Verify that replica topology is set to one of supported in topologySettings
*/}}
{{- define "cluster.replica.enabled" -}}
  {{- if eq .Values.mode "replica" }}
    {{- if empty .Values.replica.topology }}
      {{- fail (printf ".Values.replica.topology is required, but not specified.") }}
    {{- else if not (hasKey .Values.replica.topologySettings .Values.replica.topology) }}
      {{- fail (printf "The specified topology '%s' does not match any of the supported in .Values.replica.topologySettings" .Values.replica.topology) }}
    {{- end }}
    {{- hasKey .Values.replica.topologySettings .Values.replica.topology }}
  {{- end }}
{{- end }}

{{/*
Replica topology standalone enabled
Verify that at both recovery and backups method is set to objectStorage or pgBasebackup
*/}}
{{- define "cluster.replica.topology.standalone.enabled" -}}
{{- if and (eq (include "cluster.replica.enabled" .) "true") (eq .Values.replica.topology "standalone") }}
  {{- if and (or (eq (include "cluster.recovery.method.pgBasebackup.enabled" .) "true") (eq (include "cluster.recovery.method.objectStorage.enabled" .) "true")) }}
    {{- true }}
  {{- else }}
    {{- fail (printf "Replica in standalone topology mode requires recovery mode to be set to 'pgBasebackup' or 'objectStorage'") }}
  {{- end }}
{{- else }}
  {{- false }}
{{- end }}
{{- end }}

{{/*
Replica topology distributed enabled
Validate that both recovery and backups method is set to objectStorage in distributed topology
*/}}
{{- define "cluster.replica.topology.distributed.enabled" -}}
{{- if and (eq (include "cluster.replica.enabled" .) "true") (eq .Values.replica.topology "distributed") }}
  {{- if and (eq (include "cluster.recovery.method.objectStorage.enabled" .) "true") (eq (include "cluster.backups.objectStorage.enabled" .) "true") }}
    {{- if (empty .Values.recovery.methodSettings.objectStorage.clusterName) }}
      {{- fail (printf ".Values.recovery.methodSettings.objectStorage.clusterName is required, but not specified. Replica in distributed topology mode requires setting it up to the name of second cluster.") }}
    {{- else if (eq .Values.recovery.methodSettings.objectStorage.clusterName (include "cluster.fullname" .)) }}
      {{- fail (printf ".Values.recovery.methodSettings.objectStorage.clusterName is set to current cluster name, while replica in distributed topology mode requires setting it up to the name of second cluster.") }}
    {{- end }}
    {{- if .Values.replica.topologySettings.distributed.primary }}
      {{- if ne (include "cluster.backups.objectStorage.walArchiverEnabled" .) "true" -}}
        {{- fail (printf "Replica topology 'distributed' with distributed.primary=true requires WAL archiving to be enabled. Please set .Values.backups.objectStorage.walArchiverEnabled=true.") -}}
      {{- end -}}
    {{- end }}
    {{- true }}
  {{- else }}
    {{- fail (printf "Replica in distributed topology mode requires setting up both recovery and backups to objectStorage") }}
  {{- end }}
{{- else }}
  {{- false }}
{{- end }}
{{- end }}

{{/*
Replica distributed primary helper
Returns true when this release is a distributed topology replica configuration AND marked as primary (producer) side.
*/}}
{{- define "cluster.replica.topology.distributed.primary" -}}
{{- and (eq (include "cluster.replica.topology.distributed.enabled" .) "true") .Values.replica.topologySettings.distributed.primary -}}
{{- end }}

{{/*
Replica source
Defines which source to use
*/}}
{{- define "cluster.replica.source" -}}
{{- if (eq (include "cluster.recovery.method.objectStorage.enabled" .) "true") }}
  {{- print "objectStoreRecoveryCluster" }}
{{- else if (eq (include "cluster.recovery.method.pgBasebackup.enabled" .) "true") }}
  {{- print "pgBasebackupRecoveryCluster" }}
{{- end }}
{{- end }}

{{/*
Replica readonly
Defines if we can't change anything in cluster
*/}}
{{- define "cluster.replica.readonly" -}}
{{- or (and (not .Values.replica.topologySettings.distributed.primary) (eq (include "cluster.replica.topology.distributed.enabled" .) "true")) (eq (include "cluster.replica.topology.standalone.enabled" .) "true") }}
{{- end }}

{{/*
Backups objectStorage enabled
Validate that provider is set to one of supported providers in providerSettings
*/}}
{{- define "cluster.backups.objectStorage.enabled" -}}
{{- $provider := .Values.backups.objectStorage.provider -}}
{{- $ps := default (dict) .Values.backups.objectStorage.providerSettings -}}
{{- if and (not (empty $provider)) (not (hasKey $ps $provider)) }}
  {{- fail (printf "The specified provider '%s' does not match any of the supported in .Values.backups.objectStorage.providerSettings" $provider) }}
{{- end }}
{{- $enabled := and (not (empty $provider)) (hasKey $ps $provider) -}}
{{- if $enabled }}
  {{- if eq (include "cluster.barman.integrationType" .) "plugin" -}}
    {{- if not (.Capabilities.APIVersions.Has "barmancloud.cnpg.io/v1/ObjectStore") -}}
      {{- fail "Backups with objectStorage plugin enabled but required CRD ObjectStore (barmancloud.cnpg.io/v1) is missing. Please install the Barman Cloud Plugin." -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $enabled -}}
{{- end }}

{{/*
VolumeSnapshot enabled
*/}}
{{- define "cluster.backups.volumeSnapshot.enabled" -}}
{{- $vsEnabled := not (empty .Values.backups.volumeSnapshot.className) -}}
{{- if $vsEnabled -}}
  {{- if not (.Capabilities.APIVersions.Has "snapshot.storage.k8s.io/v1/VolumeSnapshotClass") -}}
    {{- fail "VolumeSnapshot backups enabled but VolumeSnapshotClass CRD (snapshot.storage.k8s.io/v1) is missing." -}}
  {{- end -}}
{{- end -}}
{{- $vsEnabled -}}
{{- end }}

{{/*
Backups enabled
*/}}
{{- define "cluster.backups.enabled" -}}
{{- or (eq (include "cluster.backups.objectStorage.enabled" .) "true") (eq (include "cluster.backups.volumeSnapshot.enabled" .) "true") -}}
{{- end }}

{{/*
Default ObjectStore names for backup and recovery
*/}}
{{- define "cluster.objectStore.backup.name" -}}
{{- default (printf "%s-backup" (include "cluster.fullname" .)) .Values.backups.objectStorage.name -}}
{{- end -}}

{{- define "cluster.objectStore.recovery.name" -}}
{{- default (printf "%s-recovery" (include "cluster.fullname" .)) .Values.recovery.methodSettings.objectStorage.name -}}
{{- end -}}

{{/*
Whether WAL archiver plugin should be enabled
*/}}
{{- define "cluster.backups.objectStorage.walArchiverEnabled" -}}
{{- and (eq (include "cluster.backups.objectStorage.enabled" .) "true") .Values.backups.objectStorage.walArchiverEnabled -}}
{{- end -}}

{{/*
Generic Kubernetes version comparison helper.
*/}}
{{- define "cluster.kube.compare" -}}
  {{- $constraint := index . 0 -}}
  {{- $ctx := index . 1 -}}
  {{- /* Use .Capabilities.KubeVersion.Version which generally looks like v1.28.3 */ -}}
  {{- $v := $ctx.Capabilities.KubeVersion.Version -}}
  {{- /* Masterminds semver tolerates leading v */ -}}
  {{- if semverCompare $constraint $v }}true{{ else }}false{{ end -}}
{{- end -}}

{{/*
Determine if we should use the Barman Cloud integration plugin or the built-in integration.
*/}}
{{- define "cluster.barman.integrationType" -}}
{{- $force := .Values.barman.forceUseOf -}}
{{- if empty $force }}
  {{- if (semverCompare ">=1.29-0" .Capabilities.KubeVersion.Version) -}}
    plugin
  {{- else -}}
    buildin
  {{- end -}}
{{- else if eq $force "plugin" -}}
  plugin
{{- else if eq $force "buildin" -}}
  buildin
{{- else }}
  {{- fail (printf "Invalid .Values.barman.forceUseOf value: %s, allowed: buildin, plugin or empty." ($force | quote)) }}
{{- end }}
{{- end }}

{{/*
ObjectStores validation
Ensure each element in .Values.objectStores has a unique non-empty name and a supported provider.
Supported providers: s3, azure, google
*/}}
{{- define "cluster.objectStores.validate" }}
  {{- $supported := dict "s3" true "azure" true "google" true }}
  {{- $names := dict }}
  {{- $caNames := dict }}
  {{- range $i, $os := .Values.objectStores }}
    {{- if or (not (hasKey $os "name")) (empty $os.name) }}
      {{- fail (printf ".Values.objectStores[%d].name is required and must be non-empty" $i) }}
    {{- end }}
    {{- if hasKey $names $os.name }}
      {{- fail (printf "Duplicate objectStores name '%s' found, but names must be unique" $os.name) }}
    {{- else }}
      {{- $_ := set $names $os.name true }}
    {{- end }}
    {{- if or (not (hasKey $os "provider")) (empty $os.provider) }}
      {{- fail (printf ".Values.objectStores[%s].provider is required and must be one of: s3, azure or google" $os.name) }}
    {{- else if not (hasKey $supported $os.provider) }}
      {{- fail (printf ".Values.objectStores[%s].provider '%s' is not supported, must be one of: s3, azure or google" $os.name $os.provider) }}
    {{- end }}
    {{- $endpointCA := default (dict) $os.endpointCA -}}
    {{- $create := (and (hasKey $endpointCA "create") $endpointCA.create) }}
    {{- if $create }}
      {{- $effectiveName := default (printf "%s-barman-%s-ca-bundle" (include "cluster.fullname" $) $os.name) $endpointCA.name }}
      {{- if hasKey $caNames $effectiveName }}
        {{- fail (printf "endpointCA secret name collision: multiple objectStores define endpointCA.create=true with the same name '%s'" $effectiveName) }}
      {{- else }}
        {{- $_ := set $caNames $effectiveName true }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Validate unique database names
Usage: {{ include "cluster.databases.validate" . }}
*/}}
{{- define "cluster.databases.validate" }}
  {{- if .Values.databases }}
    {{- $names := dict }}
    {{- range $i, $db := .Values.databases }}
      {{- if or (not (hasKey $db "name")) (empty $db.name) }}
        {{- fail (printf ".Values.databases[%d].name is required and must be non-empty" $i) }}
      {{- end }}
      {{- if hasKey $names $db.name }}
        {{- fail (printf "Duplicate database name '%s' found, but names must be unique" $db.name) }}
      {{- else }}
        {{- $_ := set $names $db.name true }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Validate unique externalCluster names
Usage: {{ include "cluster.externalClusters.validate" . }}
*/}}
{{- define "cluster.externalClusters.validate" -}}
{{- $replicaSource := include "cluster.replica.source" . -}}
{{- $names := dict -}}
{{- range .Values.externalClusters -}}
  {{- if eq .name $replicaSource -}}
    {{- fail (printf "External cluster name '%s' cannot match the replica source name '%s'." .name $replicaSource) -}}
  {{- end }}
  {{- if hasKey $names .name -}}
    {{- fail (printf "Duplicate external cluster name '%s' found. Names must be unique." .name) -}}
  {{- else -}}
    {{- $_ := set $names .name true -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Generate a unique hash string based on the combination of `.name`, `.dbname`, `.publicationName`.
Usage: {{ include "cluster.subscription.hash" . }}
*/}}
{{- define "cluster.subscription.hash" -}}
{{- $data := printf "%s-%s-%s" (default "subscriber" .name) (default "app" .dbname) (default "publisher" .publicationName) -}}
{{- $hash := sha256sum $data | trunc 8 -}}
{{- $hash -}}
{{- end -}}
