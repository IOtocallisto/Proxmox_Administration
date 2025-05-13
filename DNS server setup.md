Below is the updated, full comprehensive guide reflecting the local network specifics (172.16.10.0/24) and the designated local host (172.16.10.17):

---

# **Comprehensive Guide: Redundant Split-Horizon BIND DNS Server Setup with Docker and Cloud Integration**

## **Overview**

This guide walks you through setting up a **redundant, split-horizon BIND DNS server** using **Docker containers**. You’ll configure local zones (e.g., for `callisto.io`) for internal clients within the 172.16.10.0/24 network—where the primary local DNS host is 172.16.10.17—and public zones for external clients (serving domains like `callisto.top` and `j3scandjove.com.ng`). The external records will delegate authority to Cloudflare nameservers. This setup is ideal for integrating on-premises and cloud environments.

---

## **Table of Contents**

1. Prerequisites

2. Architecture

3. Directory Structure

4. BIND Configuration Files

5. Zone File Examples

6. Docker Container Setup

7. Automation & CI/CD

8. Cloudflare Integration

9. Monitoring & Security

10. Disaster Recovery & Backups

11. Appendix & Resources

---

## **1\. Prerequisites**

| Tool / File | Description |
| ----- | ----- |
| **Docker \+ Docker Compose** | Container runtime & orchestration |
| **BIND9** | DNS server software inside container |
| **Ansible / Git** | Automation and configuration versioning |
| **Cloudflare API Token (optional)** | For managing public DNS records via API |
| **Prometheus \+ bind\_exporter** | Monitoring the DNS service |
| **Linux host** | Host machine (e.g., Ubuntu, Debian, CentOS) |

---

## **2\. Architecture**

**Split-Horizon DNS** enables different DNS views:

* **Internal Clients:** Resolve local names for `callisto.io` using the network 172.16.10.0/24.

* **External Clients:** Resolve public records for `callisto.top` and `j3scandjove.com.ng`, with NS records delegating to Cloudflare.

* **Redundant Deployment:** Run multiple BIND instances in Docker containers with shared volumes and synchronized configurations for high availability.

---

## **3\. Directory Structure**

bind/  
├── config/  
│   ├── named.conf  
│   ├── named.conf.options  
│   ├── named.conf.local  
├── zones/  
│   ├── internal/  
│   │   └── callisto.io.db  
│   └── external/  
│       ├── callisto.top.db  
│       └── j3scandjove.com.ng.db  
├── logs/  
└── Dockerfile

---

## **4\. BIND Configuration Files**

### **named.conf**

include "/etc/bind/named.conf.options";  
include "/etc/bind/named.conf.local";

### **named.conf.options**

options {  
    directory "/var/cache/bind";  
    version "Not disclosed";  
    listen-on { any; };  
    allow-query { any; };  
    recursion no;  
};

acl "internal" {  
    172.16.10.0/24;  // Local network range  
};

### **named.conf.local**

// Internal View: for local devices in the 172.16.10.0/24 network  
view "internal" {  
    match-clients { "internal"; };  
    recursion yes;  
    zone "callisto.io" {  
        type master;  
        file "/etc/bind/zones/internal/callisto.io.db";  
        allow-transfer { none; };  
    };  
};

// External View: for public DNS resolution  
view "external" {  
    match-clients { any; };  
    recursion no;  
    zone "callisto.top" {  
        type master;  
        file "/etc/bind/zones/external/callisto.top.db";  
        allow-transfer { none; };  
    };  
    zone "j3scandjove.com.ng" {  
        type master;  
        file "/etc/bind/zones/external/j3scandjove.com.ng.db";  
        allow-transfer { none; };  
    };  
};

---

## **5\. Zone File Examples**

### **Internal Zone File: callisto.io (for local devices)**

Located at: `/etc/bind/zones/internal/callisto.io.db`

$TTL 86400  
@   IN  SOA ns1.callisto.io. admin.callisto.io. (  
        2025040901 ; Serial (update as needed)  
        3600       ; Refresh  
        900        ; Retry  
        604800     ; Expire  
        86400      ; Minimum TTL  
)  
    IN  NS  ns1.callisto.io.  
ns1 IN  A   172.16.10.17   ; Local host running the DNS service  
host1 IN A   172.16.10.20  
host2 IN A   172.16.10.21

### **External Zone File: callisto.top**

Located at: `/etc/bind/zones/external/callisto.top.db`

$TTL 86400  
@   IN  SOA ns1.callisto.top. admin.callisto.top. (  
        2025040901 ; Serial  
        3600       ; Refresh  
        900        ; Retry  
        604800     ; Expire  
        86400      ; Minimum TTL  
)  
    IN  NS  ns1.cloudflare.com.  
    IN  NS  ns2.cloudflare.com.  
www IN  A   203.0.113.10  
mail IN A   203.0.113.11

### **External Zone File: j3scandjove.com.ng**

Located at: `/etc/bind/zones/external/j3scandjove.com.ng.db`

$TTL 86400  
@   IN  SOA ns1.j3scandjove.com.ng. admin.j3scandjove.com.ng. (  
        2025040901 ; Serial  
        3600       ; Refresh  
        900        ; Retry  
        604800     ; Expire  
        86400      ; Minimum TTL  
)  
    IN  NS  ns1.cloudflare.com.  
    IN  NS  ns2.cloudflare.com.  
www IN  A   203.0.113.20

---

## **6\. Docker Container Setup**

### **Dockerfile**

FROM ubuntu:20.04  
RUN apt-get update && apt-get install \-y bind9 dnsutils  
COPY config /etc/bind  
COPY zones /etc/bind/zones

### **docker-compose.yml**

version: '3.8'  
services:  
  bind:  
    build: ./bind  
    container\_name: bind\_dns  
    restart: always  
    ports:  
      \- "53:53/udp"  
      \- "53:53/tcp"  
    volumes:  
      \- ./bind/config:/etc/bind  
      \- ./bind/zones:/etc/bind/zones  
      \- ./bind/logs:/var/log/bind  
    networks:  
      \- internal\_net  
      \- external\_net

networks:  
  internal\_net:  
    driver: bridge  
  external\_net:  
    driver: bridge

---

## **7\. Automation & CI/CD**

* **Configuration Management:**  
   Use **Ansible** to template and deploy updated zone files with automatic serial bumping.

* **CI/CD Integration:**  
   Incorporate your BIND configuration into a **GitHub Actions** or **GitLab CI** pipeline to test, validate (e.g., using `named-checkzone`), and deploy changes.

* **Version Control:**  
   Store your configuration files and zone templates in **Git** for rollback and auditing.

---

## **8\. Cloudflare Integration**

**NS Record Delegation:**  
 In your external zone files, delegate authority to Cloudflare:

 @  IN NS ns1.cloudflare.com.  
@  IN NS ns2.cloudflare.com.

* 

**API Automation:**  
 Use the Cloudflare API to automatically update DNS records if necessary:

 curl \-X POST "https://api.cloudflare.com/client/v4/zones/ZONE\_ID/dns\_records" \\  
     \-H "Authorization: Bearer $CF\_API\_TOKEN" \\  
     \-H "Content-Type: application/json" \\  
     \--data '{"type":"A","name":"www.callisto.top","content":"203.0.113.10","ttl":3600}'

* 

---

## **9\. Monitoring & Security**

* **Monitoring:**  
   Deploy `bind_exporter` with **Prometheus** and visualize with **Grafana**.

* **Security Enhancements:**

  * Enable detailed query logging (adjust log files under `/var/log/bind`).

  * Disable recursion in external view to prevent abuse.

  * Run containers as a non-root user.

* **Periodic Auditing:**  
   Regularly run `named-checkzone` to validate zone files.

---

## **10\. Disaster Recovery & Backups**

**Regular Backups:**  
 Schedule daily backups of your configuration and zone files:

 0 2 \* \* \* tar \-czf /backups/bind-$(date \+\\%F).tar.gz /etc/bind

* 

**Cloud Sync:**  
 Sync backups to a cloud storage bucket (e.g., AWS S3):

 aws s3 sync /backups s3://your-dns-backup-bucket/

* 

---

## **11\. Appendix & Resources**

* **BIND9 Administrator Manual:** [ISC BIND Administrator Reference Manual](https://bind9.readthedocs.io)

* **Cloudflare API Documentation:** [Cloudflare API Docs](https://developers.cloudflare.com/api/)

* **Docker Compose Documentation:** [Docker Compose Docs](https://docs.docker.com/compose/)

* **Prometheus Bind Exporter:** [Prometheus Bind Exporter](https://github.com/prometheus-community/bind_exporter)

---

**Last Updated:** 2025-04-09  
 **Maintainer:** Guide @ Callisto

This guide is now fully configured for a local network of 172.16.10.0/24 with the primary DNS host at 172.16.10.17. It details both internal and external DNS setups, Docker container deployment, automation, and integration with Cloudflare for a robust, redundant solution.

Happy configuring, guide\!

