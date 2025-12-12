
#1. Install Grafana
rm -rf /local/mon/grafana-data
mkdir -p /local/mon/grafana-data
chmod 1777 /local/mon/grafana-data/
docker rm -f grafana
docker run -d -p 3000:3000 --name=grafana \
  -v /local/mon/grafana-data:/var/lib/grafana \
  grafana/grafana-enterprise
docker ps -a
#E.g: http://10.6.131.68:3000 
# username: admin, password: admin

#3. Install dcgm exporter on GPU nodes
# https://catalog.ngc.nvidia.com/orgs/nvidia/teams/k8s/containers/dcgm-exporter/tags
## L20-GPU-29: 10.6.131.60
## L20-GPU-30: 10.6.131.61
docker rm -f dcgm-exporter node-exporter
docker run -itd --name dcgm-exporter --restart=always \
--gpus all \
--runtime=nvidia \
--cap-add SYS_ADMIN \
-p 9400:9400 \
nvcr.io/nvidia/k8s/dcgm-exporter:4.4.2-4.7.1-ubuntu22.04
docker run -itd --name node-exporter --restart=always \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter:latest \
  --path.rootfs=/host
docker ps -a


#Check the readiness of dcgm exporter from Grafana node
#E.g: 
curl http://10.6.131.61:9400/metrics
curl http://10.6.131.60:9400/metrics

#4. Install Prometheus
rm -rf /local/mon/prometheus
mkdir -p /local/mon/prometheus
cat > /local/mon/prometheus/node_targets.json <<- EOF
[
  { "targets": ["10.6.131.60:9100"], "labels": { "instance": "L20-GPU-29", "cluster": "raplab" } },
  { "targets": ["10.6.131.61:9100"], "labels": { "instance": "L20-GPU-30", "cluster": "raplab" } }
]
EOF
cat > /local/mon/prometheus/dcgm_targets.json <<- EOF
[
  { "targets": ["10.6.131.60:9400"], "labels": { "instance": "L20-GPU-29", "cluster": "raplab" } },
  { "targets": ["10.6.131.61:9400"], "labels": { "instance": "L20-GPU-30", "cluster": "raplab" } }
]
EOF
cat > /local/mon/prometheus/prometheus.yml <<- 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 30s

scrape_configs:
  - job_name: "node_exporter"
    file_sd_configs:
      - files:
          - 'node_targets.json'
  - job_name: "dcgm_exporter"
    file_sd_configs:
      - files:
          - 'dcgm_targets.json'
EOF
docker rm -f prometheus
docker run -itd \
--name=prometheus \
-p 9090:9090 \
-v /local/mon/prometheus:/etc/prometheus \
--user root \
prom/prometheus
docker ps -a
#Check: http://10.6.131.68:9090/service-discovery

#5. Configure data source in Grafana portal
# Grafana UI -> Connections > Add new connection -> Data Sources -> Search Prometheus -> Add new data source -> Connection: http://10.6.131.68:9090 -> Save&test

#6. Create Grafana
# Grafana UI -> Dashboards -> Create dashboard ->  Import dashboard -> Load: 12239/1860/23823/24180 -> prometheus: prometheus -> Import
