# Интеграция Quantum-PCI с различными системами

## Обзор

Данное руководство описывает интеграцию Quantum-PCI с популярными системами контейнеризации, оркестрации и мониторинга.

## Интеграция с Kubernetes

### Создание DaemonSet для PTP синхронизации

```yaml
# ptp-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ptp-sync
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: ptp-sync
  template:
    metadata:
      labels:
        name: ptp-sync
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: ptp4l
        image: quantum-pci/ptp4l:latest
        securityContext:
          privileged: true
        volumeMounts:
        - name: dev
          mountPath: /dev
        - name: sys
          mountPath: /sys
        - name: config
          mountPath: /etc/ptp4l.conf
          subPath: ptp4l.conf
        command: ["/usr/sbin/ptp4l"]
        args: ["-f", "/etc/ptp4l.conf", "-i", "eth0"]
      - name: phc2sys
        image: quantum-pci/phc2sys:latest
        securityContext:
          privileged: true
        volumeMounts:
        - name: dev
          mountPath: /dev
        command: ["/usr/sbin/phc2sys"]
        args: ["-s", "/dev/ptp0", "-c", "CLOCK_REALTIME", "-O", "0"]
      volumes:
      - name: dev
        hostPath:
          path: /dev
      - name: sys
        hostPath:
          path: /sys
      - name: config
        configMap:
          name: ptp-config
```

### Применение конфигурации

```bash
kubectl apply -f ptp-daemonset.yaml
kubectl get daemonset -n kube-system ptp-sync
```

## Интеграция с Docker

### Docker Compose для PTP стека

```yaml
# docker-compose.ptp.yml
version: '3.8'

services:
  ptp4l:
    build:
      context: .
      dockerfile: Dockerfile.ptp
    container_name: ptp4l
    privileged: true
    network_mode: host
    volumes:
      - /dev:/dev
      - /sys:/sys
    environment:
      - PTP_INTERFACE=eth0
      - PTP_DOMAIN=0
    command: ["ptp4l", "-i", "eth0", "-f", "/etc/ptp4l.conf"]

  phc2sys:
    build:
      context: .
      dockerfile: Dockerfile.ptp
    container_name: phc2sys
    privileged: true
    network_mode: host
    volumes:
      - /dev:/dev
    depends_on:
      - ptp4l
    command: ["phc2sys", "-s", "/dev/ptp0", "-c", "CLOCK_REALTIME", "-O", "0"]
```

### Запуск Docker Compose

```bash
docker-compose -f docker-compose.ptp.yml up -d
docker-compose -f docker-compose.ptp.yml logs -f
```

## Интеграция с Prometheus/Grafana

### Prometheus конфигурация

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'quantum-pci'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/api/metrics'
    scrape_interval: 5s

  - job_name: 'ptp4l'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 10s
```

### Настройка Grafana

1. Добавьте Prometheus как источник данных
2. Импортируйте дашборд Quantum-PCI
3. Настройте алерты на основе метрик PTP

## Интеграция с Ansible

### Ansible playbook для развертывания

```yaml
# quantum-pci-deploy.yml
---
- name: Deploy Quantum-PCI TimeCard
  hosts: timecard_servers
  become: yes
  vars:
    ptp_domain: 0
    ptp_interface: eth0

  tasks:
    - name: Install dependencies
      apt:
        name:
          - build-essential
          - linux-headers-{{ ansible_kernel }}
          - linuxptp
          - chrony
          - ethtool
          - pciutils
        state: present

    - name: Load PTP driver
      modprobe:
        name: ptp_ocp
        state: present

    - name: Start and enable PTP services
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop:
        - ptp4l
        - phc2sys
        - chrony
```

### Запуск Ansible playbook

```bash
ansible-playbook -i inventory.ini quantum-pci-deploy.yml
```

## Дополнительные ресурсы

- [Документация Kubernetes](https://kubernetes.io/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Ansible Documentation](https://docs.ansible.com/)

