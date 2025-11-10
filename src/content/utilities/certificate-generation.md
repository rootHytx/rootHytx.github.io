---
title: "Certificate Generation"
description: "SSL certificate generation using Certbot with DNS challenge validation"
category: "security"
tags: ["ssl", "certbot", "letsencrypt", "docker", "dns"]
created: 2024-11-10
---

# SSL Certificate Generation

Generate SSL certificates using Certbot with DNS challenge validation. This method is ideal for automated certificate generation and wildcard certificates.

## Docker Certbot Command

```bash
docker run -it --rm --name certbot \
  -v "./certs:/etc/letsencrypt" \
  certbot/certbot certonly --manual \
  --preferred-challenges dns \
  -d DOMAIN
```

## Manual DNS Challenge Steps

```bash
# 1. Run the Docker command above
# 2. Certbot will prompt you to create DNS TXT records
# 3. Add the TXT records to your DNS provider
# 4. Wait for DNS propagation (usually 1-5 minutes)
# 5. Press Enter to continue validation
# 6. Certificates will be saved in ./certs/
```

## Example Usage

```bash
# Generate certificate for example.com
docker run -it --rm --name certbot -v "./certs:/etc/letsencrypt" certbot/certbot certonly --manual --preferred-challenges dns -d example.com -d *.example.com

# Generate wildcard certificate
docker run -it --rm --name certbot -v "./certs:/etc/letsencrypt" certbot/certbot certonly --manual --preferred-challenges dns -d "*.example.com"
```

## Certificate Locations

```bash
# Generated certificates will be in:
./certs/live/DOMAIN/fullchain.pem
./certs/live/DOMAIN/privkey.pem
./certs/live/DOMAIN/cert.pem
./certs/live/DOMAIN/chain.pem
```

## Automation Tips

```bash
# Use DNS provider APIs for automated validation
# Set up cron jobs for automatic renewal
# Use --dry-run to test without generating real certificates
# Combine with Docker Compose for easier management
```

## DNS Provider Integration

### Cloudflare
```bash
# Use Cloudflare API token with DNS challenge
docker run -it --rm --name certbot \
  -v "./certs:/etc/letsencrypt" \
  -e CLOUDFLARE_API_TOKEN=your_token \
  certbot/dns-cloudflare certonly \
  --dns-cloudflare \
  -d example.com -d *.example.com
```

### Route53
```bash
# Use AWS credentials for Route53
docker run -it --rm --name certbot \
  -v "./certs:/etc/letsencrypt" \
  -e AWS_ACCESS_KEY_ID=your_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret \
  certbot/dns-route53 certonly \
  --dns-route53 \
  -d example.com
```

## Renewal Commands

```bash
# Test renewal (dry run)
docker run -it --rm --name certbot \
  -v "./certs:/etc/letsencrypt" \
  certbot/certbot renew --dry-run

# Actual renewal
docker run -it --rm --name certbot \
  -v "./certs:/etc/letsencrypt" \
  certbot/certbot renew
```

## Certificate Types

- **Single Domain**: Certificate for one specific domain
- **Multiple Domains**: Certificate covering multiple domains
- **Wildcard**: Certificate for all subdomains (*.example.com)
- **SAN (Subject Alternative Name)**: Certificate with multiple domain names

## Best Practices

- Use wildcard certificates for subdomains
- Set up automatic renewal (certificates expire every 90 days)
- Test with --dry-run before production use
- Store certificates securely with proper permissions
- Use environment variables for sensitive data
- Monitor certificate expiration dates