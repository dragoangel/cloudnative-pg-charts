{{- define "cluster.bootstrap.initdb.block" -}}
{{- with .Values.cluster.initdb }}
  {{- with (omit . "postInitApplicationSQL" "owner" "import") }}
    {{- . | toYaml | nindent 2 }}
  {{- end }}
{{- end }}
{{- if .Values.cluster.initdb.owner }}
owner: {{ tpl .Values.cluster.initdb.owner . }}
{{- end }}
{{- if or (eq .Values.type "postgis") (eq .Values.type "timescaledb") (not (empty .Values.cluster.initdb.postInitApplicationSQL)) }}
postInitApplicationSQL:
  {{- if eq .Values.type "postgis" }}
  - CREATE EXTENSION IF NOT EXISTS postgis;
  - CREATE EXTENSION IF NOT EXISTS postgis_topology;
  - CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
  - CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
  {{- else if eq .Values.type "timescaledb" }}
  - CREATE EXTENSION IF NOT EXISTS timescaledb;
  {{- end }}
  {{- with .Values.cluster.initdb }}
    {{- range .postInitApplicationSQL }}
      {{- printf "- %s" . | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "cluster.bootstrap" -}}
{{- if (eq .Values.mode "standalone") }}
bootstrap:
  initdb:
    {{- include "cluster.bootstrap.initdb.block" . | indent 4 }}
{{- else if (eq (include "cluster.recovery.enabled" .) "true") }}
bootstrap:
  {{- if (eq (include "cluster.replica.topology.distributed.primary" .) "true")}}
  initdb:
    {{- include "cluster.bootstrap.initdb.block" . | indent 4 }}
  {{- else if (eq (include "cluster.import.enabled" .) "true") }}
  initdb:
    {{- if and (eq (include "cluster.import.type.microservice.enabled" .) "true") }}
    {{- with .Values.import.typeSettings.microservice.owner }}
    owner: {{ . }}
    {{- end }}
    {{- with .Values.import.typeSettings.microservice.ownerSecret }}
    secret:
      name: {{ . }}
    {{- end }}
    {{- end }}
    import:
      {{- if (eq (include "cluster.import.type.microservice.enabled" .) "true") }}
      type: microservice
      databases:
        - {{ .Values.import.typeSettings.microservice.database }}
      {{- with .Values.import.typeSettings.microservice.schemaOnly }}
      schemaOnly: {{ . }}
      {{- end }}
      {{- with .Values.import.typeSettings.microservice.postImportApplicationSQL }}
      postImportApplicationSQL:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- else if (eq (include "cluster.import.type.monolith.enabled" .) "true") }}
      type: monolith
      {{- with .Values.import.typeSettings.monolith.databases }}
      databases:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.import.typeSettings.monolith.roles }}
      roles:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
      source:
        externalCluster: {{ include "cluster.replica.source" . }}
  {{- else if eq .Values.recovery.method "pgBasebackup" }}
  pg_basebackup:
    source: {{ include "cluster.replica.source" . }}
  {{- if and (eq .Values.mode "recovery") (not (empty .Values.recovery.methodSettings.pgBasebackup.database)) }}
    {{- with .Values.recovery.methodSettings.pgBasebackup.database }}
    database: {{ . }}
    {{- end }}
    {{- with .Values.recovery.methodSettings.pgBasebackup.owner }}
    owner: {{ . }}
    {{- end }}
    {{- with .Values.recovery.methodSettings.pgBasebackup.ownerSecret }}
    secret:
      name: {{ . }}
    {{- end }}
  {{- end }}
  {{- else }}
  recovery:
    {{- if and (eq .Values.mode "recovery") (has .Values.recovery.method (list "backup" "objectStorage" "volumeSnapshot")) }}
    {{- with .Values.recovery.pitrTarget.time }}
    recoveryTarget:
      targetTime: {{ . }}
    {{- end }}
    {{- end }}
    {{- if eq .Values.recovery.method "backup" }}
    backup:
      name: {{ required ".Values.recovery.methodSettings.backup.name is required, but not specified." .Values.recovery.methodSettings.backup.name }}
    {{- else if eq .Values.recovery.method "objectStorage" }}
    source: {{ include "cluster.replica.source" . }}
    {{- else if eq .Values.recovery.method "volumeSnapshot" }}
    source: {{ include "cluster.replica.source" . }}
    volumeSnapshots:
      storage:
        apiGroup: snapshot.storage.k8s.io
        kind: VolumeSnapshot
        name: {{ required ".Values.recovery.methodSettings.volumeSnapshot.storageSnapshotName is required, but not specified." .Values.recovery.methodSettings.volumeSnapshot.storageSnapshotName }}
      {{- with .Values.recovery.methodSettings.volumeSnapshot.walSnapshotName }}
      walStorage:
        apiGroup: snapshot.storage.k8s.io
        kind: VolumeSnapshot
        name: {{ . }}
      {{- end }}
    {{- end }}
  {{- end }}
{{ if (eq (include "cluster.replica.enabled" .) "true") }}
replica:
  {{- if (eq (include "cluster.replica.topology.standalone.enabled" .) "true") }}
  enabled: true
  {{- else if (eq (include "cluster.replica.topology.distributed.enabled" .) "true") }}
  self: {{ include "cluster.fullname" . }}
  {{- if .Values.replica.topologySettings.distributed.primary }}
  primary: {{ include "cluster.fullname" . }}
  {{- else }}
  primary: {{ include "cluster.replica.source" . }}
  {{- end }}
  {{- end }}
  source: {{ include "cluster.replica.source" . }}
  {{- if not (empty .Values.replica.topologySettings.distributed.promotionToken) }}
  promotionToken: {{ .Values.replica.topologySettings.distributed.promotionToken }}
  {{- end }}
  {{- if not (empty .Values.replica.minApplyDelay) }}
  minApplyDelay: {{ .Values.replica.minApplyDelay }}
  {{- end }}
{{- end }}
{{- else }}
  {{- fail "Invalid cluster mode!" }}
{{- end }}
{{- end -}}
