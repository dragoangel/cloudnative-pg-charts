{{- define "cluster.barmanObjectStoreConfig" -}}
{{- if not (empty .scope.endpointURL) }}
endpointURL: {{ .scope.endpointURL | quote }}
{{- end }}
{{- if or (.scope.endpointCA.create) (.scope.endpointCA.name) }}
endpointCA:
  {{- if .scope.endpointCA.create }}
  name: {{ printf "%s-%s-ca-bundle" .chartFullname .secretPrefix }}
  {{- else }}
  name: {{ .scope.endpointCA.name }}
  {{- end }}
  key: {{ .scope.endpointCA.key }}
{{- end }}
{{- if eq .scope.provider "s3" }}
{{- if empty .scope.endpointURL }}
endpointURL: "https://s3.{{ required "You need to specify S3 region if endpointURL is not specified." .scope.providerSettings.s3.region }}.amazonaws.com"
{{- end }}
{{- if empty .scope.destinationPath }}
destinationPath: "s3://{{ required "You need to specify S3 bucket if destinationPath is not specified." .scope.providerSettings.s3.bucket }}{{ .scope.providerSettings.s3.path }}"
{{- end }}
{{- $secretName := coalesce .existingSecret.name (printf "%s-%s-creds-s3" .chartFullname .secretPrefix) }}
s3Credentials:
  {{- if .scope.providerSettings.s3.inheritFromIAMRole }}
    inheritFromIAMRole: true
  {{- else }}
  accessKeyId:
    name: {{ $secretName }}
    key: ACCESS_KEY_ID
  secretAccessKey:
    name: {{ $secretName }}
    key: ACCESS_SECRET_KEY
  {{- end }}
{{- else if eq .scope.provider "azure" }}
{{- if empty .scope.destinationPath }}
destinationPath: "https://{{ required "You need to specify Azure storageAccount if destinationPath is not specified." .scope.providerSettings.azure.storageAccount }}.{{ .scope.providerSettings.azure.serviceName }}.core.windows.net/{{ .scope.providerSettings.azure.containerName }}{{ .scope.providerSettings.azure.path }}"
{{- end }}
{{- $secretName := coalesce .existingSecret.name (printf "%s-%s-creds-azure" .chartFullname .secretPrefix) }}
azureCredentials:
{{- if .scope.providerSettings.azure.inheritFromAzureAD }}
  inheritFromAzureAD: true
{{- else if .scope.providerSettings.azure.connectionString }}
  connectionString:
    name: {{ $secretName }}
    key: AZURE_CONNECTION_STRING
{{- else }}
  storageAccount:
    name: {{ $secretName }}
    key: AZURE_STORAGE_ACCOUNT
  {{- if .scope.providerSettings.azure.storageKey }}
  storageKey:
    name: {{ $secretName }}
    key: AZURE_STORAGE_KEY
  {{- else }}
  storageSasToken:
    name: {{ $secretName }}
    key: AZURE_STORAGE_SAS_TOKEN
  {{- end }}
{{- end }}
{{- else if eq .scope.provider "google" }}
{{- if empty .scope.destinationPath }}
destinationPath: "gs://{{ required "You need to specify Google storage bucket if destinationPath is not specified." .scope.providerSettings.google.bucket }}{{ .scope.providerSettings.google.path }}"
{{- end }}
{{- $secretName := coalesce .existingSecret.name (printf "%s-%s-creds-google" .chartFullname .secretPrefix) }}
googleCredentials:
  gkeEnvironment: {{ .scope.providerSettings.google.gkeEnvironment }}
{{- if not .scope.providerSettings.google.gkeEnvironment }}
  applicationCredentials:
    name: {{ $secretName }}
    key: APPLICATION_CREDENTIALS
{{- end }}
{{- end }}
{{- with .scope.wal }}
wal:
  {{- with .compression }}
  compression: {{ . }}
  {{- end }}
  {{- with .encryption }}
  encryption: {{ . }}
  {{- end }}
  {{- with .maxParallel }}
  maxParallel: {{ . }}
  {{- end }}
{{- end }}
{{- with .scope.data }}
data:
  {{- with .compression }}
  compression: {{ . }}
  {{- end }}
  {{- with .encryption }}
  encryption: {{ . }}
  {{- end }}
  {{- with .jobs }}
  jobs: {{ . }}
  {{- end }}
{{- end }}
{{- with .scope.tags }}
tags:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .scope.historyTags }}
historyTags:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
