# DriveGo Reverse Proxy & TLS Termination Architecture

This directory provides the production-grade reverse proxy and TLS termination configuration for DriveGo backend services.

## Architecture Options

### Option A: Local / VM Compose Deployment (Nginx In-Container)
In this deployment model, docker-compose.production.yml launches the 
ginx container:
- **Port 80**: Listens for HTTP traffic and issues a 301 Moved Permanently redirect to https://System.Management.Automation.Internal.Host.InternalHost.
- **Port 443**: Terminates TLS with modern TLSv1.2 and TLSv1.3 ciphers.
- **HSTS Enforcement**: Sends Strict-Transport-Security: max-age=31536000; includeSubDomains; preload.
- **Reverse Proxy**: Forwards traffic internally to http://backend:3000 via the Docker internal bridge network. The backend's port 3000 is **not** exposed to the public internet.
- **SSL Certificates**: Place ullchain.pem and privkey.pem into ./nginx/ssl/live/ (e.g. from Let's Encrypt Certbot).

### Option B: Cloud-Managed Load Balancer (AWS ALB / GCP Cloud LB / Cloudflare)
In cloud production environments with managed ingress:
1. **TLS Termination**: Terminates at the Cloud Load Balancer with an ACM (AWS Certificate Manager) or Cloudflare Edge certificate.
2. **HSTS & HTTPS Redirect**: The Cloud Load Balancer listener rule for port 80 redirects to port 443 with HSTS enabled.
3. **Internal Forwarding**: The load balancer routes traffic into the target group or VPC private subnet containing the DriveGo ECS/EKS/Docker instances.
4. **Proxy Headers**: The ALB injects X-Forwarded-For, X-Forwarded-Proto: https, and X-Forwarded-Port: 443.